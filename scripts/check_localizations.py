#!/usr/bin/env python3
r"""
Verify every user-visible localized string in the Swift source has
translations for all required locales in `Localizable.xcstrings`.

────────────────────────────────────────────────────────────────────────────
Why this exists
────────────────────────────────────────────────────────────────────────────
Apple has rejected this app under Guideline 4 (Design) more than once
because reviewer-test devices in JP/KR locale rendered Chinese fallbacks for
strings whose translations were missing in the xcstrings catalog. Catching
this locally — before TestFlight upload — costs <1s; catching it via App
Store review costs days of round-trip.

────────────────────────────────────────────────────────────────────────────
What it checks
────────────────────────────────────────────────────────────────────────────
1. Every `String(localized: "…")` literal in `.swift` files under SCAN_ROOT.
2. Every `Text("…\(expr)…")` literal that contains string-interpolation
   (a strong signal the literal is a user-facing sentence rather than a
   code identifier or visual symbol like "→").

For each found key the script verifies that `Localizable.xcstrings` has a
`stringUnit.state == "translated"` entry for every locale in
REQUIRED_LOCALES.

Pure-formatting keys (no CJK characters AND no 3+-letter English words —
e.g. "%@/%@", "%@%", "$%@") are skipped because they render the same in
every locale and aren't what gets the app rejected. Anything with real
words — Chinese/Japanese/Korean OR English ≥3 letters — gets checked.

────────────────────────────────────────────────────────────────────────────
Usage
────────────────────────────────────────────────────────────────────────────
  python3 scripts/check_localizations.py            # exits 0 / 1
  python3 scripts/check_localizations.py --verbose  # show summary even on success

Exit codes:
  0  all required locales translated
  1  at least one missing translation (script lists them)
  2  script-level failure (xcstrings unreadable, etc.)

Wire it into git via `scripts/install-git-hooks.sh`, or add as an Xcode
Run Script build phase (Build Phases → + → New Run Script Phase →
`python3 "$SRCROOT/../scripts/check_localizations.py"`).
"""

import argparse
import json
import re
import sys
from collections import defaultdict
from pathlib import Path

# Source-of-truth locale (matches `sourceLanguage` in xcstrings).
SOURCE_LOCALE = "zh-Hans"
# Locales we ship in the App Store. Apple's reviewer rotates through these.
REQUIRED_LOCALES = ["en", "ja", "ko", "zh-Hant"]

XCSTRINGS_REL = "StudySync/Localizable.xcstrings"
SCAN_ROOT_REL = "StudySync"

# Directories under SCAN_ROOT we never want to scan (build artifacts).
EXCLUDE_DIR_NAMES = {".build", "Build", "DerivedData", ".swiftpm"}


# ──────────────────────────────────────────────────────────────────────────
# Pattern matching
# ──────────────────────────────────────────────────────────────────────────

# `String(localized: "…")` — the body matches any non-quote-non-backslash
# char OR a backslash-escape pair, so embedded `\"` and `\\` work. Captures
# the literal content as group 1.
STRING_LOCALIZED_RE = re.compile(
    r'String\(\s*localized:\s*"((?:[^"\\]|\\.)*)"',
    re.DOTALL,
)

# `Text("…")`. Same body grammar. We post-filter to keep only literals
# with `\(` interpolation. The negative lookbehind avoids `Text(verbatim:`.
TEXT_RE = re.compile(
    r'(?<!verbatim:)\bText\(\s*"((?:[^"\\]|\\.)*)"',
    re.DOTALL,
)


def replace_interpolations(swift_literal: str) -> str:
    """
    Replace every Swift `\\(expr)` with `%@`, correctly handling nested
    parentheses inside the interpolation expression (e.g.
    `\\(arr.filter { $0 }.count)` — naive `[^)]*` regex stops at the first
    inner `)`).
    """
    out: list[str] = []
    i = 0
    n = len(swift_literal)
    while i < n:
        if i + 1 < n and swift_literal[i] == "\\" and swift_literal[i + 1] == "(":
            depth = 1
            j = i + 2
            while j < n and depth > 0:
                ch = swift_literal[j]
                if ch == "(":
                    depth += 1
                elif ch == ")":
                    depth -= 1
                    if depth == 0:
                        j += 1  # consume the closing paren
                        break
                j += 1
            if depth == 0:
                out.append("%@")
                i = j
                continue
        out.append(swift_literal[i])
        i += 1
    return "".join(out)


# Real printf format specifier — anything else `%` in the literal is a
# percent sign that xcstrings stores escaped as `%%`.
FORMAT_SPECIFIER_RE = re.compile(r"%(?:\d+\$)?(?:lld|[@disfxXougeGu])")


def _escape_percent_literals(s: str) -> str:
    """
    Double every `%` that is NOT part of a printf format specifier — but
    only when the key already contains at least one real format specifier.

    xcstrings only treats an entry as a printf format string when it has
    at least one `%@`/`%lld`/etc. specifier; otherwise plain `%` is kept
    as-is. So `"100%"` lives in the catalog as `"100%"`, but
    `"还有 %@ %"` is stored as `"还有 %@ %%"`.
    """
    if not FORMAT_SPECIFIER_RE.search(s):
        return s
    out: list[str] = []
    i = 0
    while i < len(s):
        m = FORMAT_SPECIFIER_RE.match(s, i)
        if m:
            out.append(m.group(0))
            i = m.end()
        elif s[i] == "%":
            out.append("%%")
            i += 1
        else:
            out.append(s[i])
            i += 1
    return "".join(out)


def normalize_key(swift_literal: str) -> str:
    """
    Convert a Swift string-interpolation literal into the form used as the
    key in `Localizable.xcstrings`.

    Examples:
      `"未配置 \\(provider.displayName) API 密钥"` → `"未配置 %@ API 密钥"`
      `"还有 \\(days)% 完成"`                      → `"还有 %@%% 完成"`

    Xcode normalizes integer interpolations to `%lld` and others to `%@`.
    We can't tell types from the literal alone — we generate the all-`%@`
    canonical form and the lookup path also probes `%lld` variants.
    """
    out = replace_interpolations(swift_literal)
    out = (
        out.replace('\\"', '"')
        .replace("\\\\", "\\")
        .replace("\\n", "\n")
        .replace("\\t", "\t")
    )
    return _escape_percent_literals(out)


def lookup_candidates(normalized: str) -> list[str]:
    """
    Permutations of the key to probe in xcstrings. Generates 2^N variants
    where N is the count of `%@` placeholders, swapping each between
    `%@` and `%lld`. Capped at 16 variants for safety.
    """
    placeholders = [m.start() for m in re.finditer(r"%@", normalized)]
    if not placeholders:
        return [normalized]
    if len(placeholders) > 4:
        return [normalized, normalized.replace("%@", "%lld")]

    variants: set[str] = set()
    n = len(placeholders)
    for mask in range(1 << n):
        chars = list(normalized)
        # Replace from the end so earlier indices stay valid.
        for i in reversed(range(n)):
            if mask & (1 << i):
                pos = placeholders[i]
                chars[pos:pos + 2] = list("%lld")
        variants.add("".join(chars))
    return list(variants)


def needs_translation(key: str) -> bool:
    """
    A key needs translation only if it contains real words. Pure-formatting
    keys like "%@/%@", "$%@", "%@%", "→" render identically in every locale
    and aren't what gets the app rejected.

    Rule:
      • any CJK character (Chinese / Japanese kana / Korean Hangul) → yes
      • any run of ≥3 alphabetic ASCII letters → yes (likely a word)
      • otherwise → no
    """
    for ch in key:
        cp = ord(ch)
        if (
            0x4E00 <= cp <= 0x9FFF        # CJK Unified Ideographs
            or 0x3040 <= cp <= 0x309F     # Hiragana
            or 0x30A0 <= cp <= 0x30FF     # Katakana
            or 0xAC00 <= cp <= 0xD7AF     # Hangul Syllables
            or 0x3400 <= cp <= 0x4DBF     # CJK Extension A
        ):
            return True
    if re.search(r"[A-Za-z]{3,}", key):
        return True
    return False


# ──────────────────────────────────────────────────────────────────────────
# Scanners
# ──────────────────────────────────────────────────────────────────────────

def _excluded(path: Path) -> bool:
    return any(part in EXCLUDE_DIR_NAMES for part in path.parts)


def scan_swift_sources(root: Path) -> dict[str, list[tuple[Path, int]]]:
    """
    Walk Swift sources and return a map:
        normalized-key  →  [(file, line-number), ...]
    Only includes keys that pass `needs_translation`.
    """
    found: dict[str, list[tuple[Path, int]]] = defaultdict(list)
    for swift in root.rglob("*.swift"):
        if _excluded(swift):
            continue
        try:
            content = swift.read_text(encoding="utf-8")
        except UnicodeDecodeError:
            continue

        # `String(localized:)` — always check.
        for m in STRING_LOCALIZED_RE.finditer(content):
            key = normalize_key(m.group(1))
            if _looks_truncated(key) or not needs_translation(key):
                continue
            line = content[: m.start()].count("\n") + 1
            found[key].append((swift, line))

        # `Text("…")` — only when the literal contains interpolation. Plain
        # `Text("foo")` is also localized at runtime but tends to be either
        # an English/Chinese label that already lives in xcstrings as part
        # of L10n, or a non-translatable visual ("→", " · ") that needs_translation
        # would filter out anyway.
        for m in TEXT_RE.finditer(content):
            raw = m.group(1)
            if "\\(" not in raw:
                continue
            key = normalize_key(raw)
            if _looks_truncated(key) or not needs_translation(key):
                continue
            line = content[: m.start()].count("\n") + 1
            found[key].append((swift, line))
    return found


def _looks_truncated(key: str) -> bool:
    """
    Detect a key whose Swift-literal capture got cut short — typically
    because the regex's outer string-body matcher stopped at a quote inside
    an interpolation expression (e.g. `Text("$\\(x, specifier: "%.2f")")`).
    Such captures still contain an unprocessed `\\(` that wasn't replaced
    with `%@`. We skip them rather than report bogus misses.
    """
    return "\\(" in key


# ──────────────────────────────────────────────────────────────────────────
# xcstrings inspection
# ──────────────────────────────────────────────────────────────────────────

def load_xcstrings(path: Path) -> dict:
    return json.loads(path.read_text(encoding="utf-8"))


def find_missing(
    swift_keys: dict[str, list[tuple[Path, int]]],
    xcstrings: dict,
) -> list[tuple[str, list[str], list[tuple[Path, int]]]]:
    """
    Returns triples of (key, missing-locales, locations).
    `missing-locales` may include the sentinel "(key not in xcstrings)" if
    the key itself is absent from the catalog.
    """
    strings = xcstrings.get("strings", {})
    missing: list[tuple[str, list[str], list[tuple[Path, int]]]] = []

    for key, locations in sorted(swift_keys.items()):
        entry = next(
            (strings[c] for c in lookup_candidates(key) if c in strings),
            None,
        )
        if entry is None:
            missing.append((key, ["(key not in xcstrings)"], locations))
            continue

        locs = entry.get("localizations", {})
        bad = [
            loc for loc in REQUIRED_LOCALES
            if locs.get(loc, {}).get("stringUnit", {}).get("state") != "translated"
        ]
        if bad:
            missing.append((key, bad, locations))
    return missing


# ──────────────────────────────────────────────────────────────────────────
# Reporter
# ──────────────────────────────────────────────────────────────────────────

def report_missing(
    repo: Path,
    missing: list[tuple[str, list[str], list[tuple[Path, int]]]],
) -> None:
    print(
        f"\n✗ {len(missing)} localized "
        f"{'key needs' if len(missing) == 1 else 'keys need'} "
        f"translations for one or more of {REQUIRED_LOCALES}:\n"
    )
    for key, bad, locations in missing:
        truncated = key if len(key) <= 80 else key[:77] + "…"
        print(f"  • {truncated!r}")
        print(f"      missing: {bad}")
        for f, line in locations[:3]:
            try:
                rel = f.relative_to(repo)
            except ValueError:
                rel = f
            print(f"      at: {rel}:{line}")
        if len(locations) > 3:
            print(f"      … and {len(locations) - 3} more locations")
        print()

    print(
        "Fix: open Localizable.xcstrings in Xcode and provide translations,\n"
        "     or batch-edit the JSON directly. See CHANGELOG.md for the\n"
        "     prior Apple-review rejections that motivated this check."
    )


# ──────────────────────────────────────────────────────────────────────────
# Entry point
# ──────────────────────────────────────────────────────────────────────────

def main(argv: list[str]) -> int:
    parser = argparse.ArgumentParser(
        description="Check that all user-visible strings have translations."
    )
    parser.add_argument(
        "--verbose", "-v", action="store_true",
        help="Print summary even on success.",
    )
    args = parser.parse_args(argv)

    repo = Path(__file__).resolve().parent.parent
    xc_path = repo / XCSTRINGS_REL
    scan_root = repo / SCAN_ROOT_REL

    if not xc_path.exists():
        print(f"error: xcstrings not found: {xc_path}", file=sys.stderr)
        return 2
    if not scan_root.exists():
        print(f"error: scan root not found: {scan_root}", file=sys.stderr)
        return 2

    swift_keys = scan_swift_sources(scan_root)
    xcstrings = load_xcstrings(xc_path)
    missing = find_missing(swift_keys, xcstrings)

    if args.verbose:
        print(f"scanned {len(swift_keys)} localizable keys after filtering.")

    if not missing:
        if args.verbose:
            print(
                f"✓ all {len(swift_keys)} keys are translated for "
                f"{REQUIRED_LOCALES}."
            )
        else:
            print(f"✓ localizations OK ({len(swift_keys)} keys checked).")
        return 0

    report_missing(repo, missing)
    return 1


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
