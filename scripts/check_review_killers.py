#!/usr/bin/env python3
r"""
Scan user-visible string literals for words that have historically failed
App Store review.

────────────────────────────────────────────────────────────────────────────
Why this exists
────────────────────────────────────────────────────────────────────────────
Per CHANGELOG.md, v1.0.2 had to remove a `测试版 / TestFlight` banner from
PaywallView because the reviewer (who tests in the StoreKit sandbox) would
have seen it and reflexively bounced the build under Guideline 2.3
(Performance — Accurate Metadata) or 2.1 (App Completeness).

This script catches a string like that BEFORE you ship.

────────────────────────────────────────────────────────────────────────────
What it checks
────────────────────────────────────────────────────────────────────────────
Every literal inside `String(localized:)`, `Text("...")`, `Label("...", ...)`,
`navigationTitle(...)`, `alert(...)`, `confirmationDialog(...)` etc., for
forbidden review-killer phrases. Checks both the source literal AND every
translated value in Localizable.xcstrings — a phrase that's clean in the
zh-Hans source but slipped into a JP translation would still ship.

We deliberately do NOT scan code comments or identifiers — flagging
"// Apple sandbox semantics" comments would be noise.

Exit codes:
  0  no review-killer phrases in user-visible strings
  1  flagged at least one
  2  script-level failure
"""

import json
import re
import sys
from pathlib import Path

SCAN_ROOT_REL = "StudySync"
XCSTRINGS_REL = "StudySync/Localizable.xcstrings"
INFOPLIST_XCSTRINGS_REL = "StudySync/InfoPlist.xcstrings"

EXCLUDE_DIR_NAMES = {".build", "Build", "DerivedData", ".swiftpm"}

# Each tuple: (compiled-regex, human-readable reason)
# Patterns are case-insensitive unless they contain CJK.
# Keep this list TIGHT — a too-eager pattern (e.g. plain `\bDEBUG\b`) would
# match harmless strings. Stick to phrases that have actually appeared in
# rejected builds or are obvious red flags.
FORBIDDEN: list[tuple[re.Pattern[str], str]] = [
    (re.compile(r"\bTestFlight\b", re.I),
     "TestFlight reference (Guideline 2.3)"),
    (re.compile(r"测试版|測試版"),
     "测试版 / 測試版 label (Guideline 2.3)"),
    (re.compile(r"\bsandbox\b", re.I),
     "sandbox label (Guideline 2.1)"),
    (re.compile(r"沙盒|沙箱"),
     "沙盒 / 沙箱 label (Guideline 2.1)"),
    (re.compile(r"\blocalhost\b|127\.0\.0\.1"),
     "localhost / 127.0.0.1 URL (Guideline 2.5)"),
    (re.compile(r"内测|內測"),
     "内测 / 內測 label (Guideline 2.3)"),
    (re.compile(r"开发版|開發版"),
     "开发版 / 開發版 label (Guideline 2.3)"),
    (re.compile(r"测试中|測試中"),
     "测试中 / 測試中 label (Guideline 2.3)"),
    # `Beta` alone is too lossy (e.g. "beta carotene"); only flag obvious uses.
    (re.compile(r"\b(?:Beta|β)\s*(?:build|version|release|tester)", re.I),
     "Beta build/release label (Guideline 2.3)"),
    # Lorem ipsum / placeholder copy
    (re.compile(r"\blorem\s+ipsum\b", re.I),
     "Lorem ipsum placeholder copy (Guideline 4)"),
    (re.compile(r"\b(TODO|FIXME|XXX|HACK)\b"),
     "TODO/FIXME marker leaked into user copy"),
]

# Same body grammar as in check_localizations.py.
USER_VISIBLE_PATTERNS = [
    re.compile(
        r'String\(\s*localized:\s*"((?:[^"\\]|\\.)*)"',
        re.DOTALL,
    ),
    re.compile(
        r'(?<!verbatim:)\bText\(\s*"((?:[^"\\]|\\.)*)"',
        re.DOTALL,
    ),
    re.compile(
        r'\bLabel\(\s*"((?:[^"\\]|\\.)*)"',
        re.DOTALL,
    ),
    re.compile(
        r'\.navigationTitle\(\s*"((?:[^"\\]|\\.)*)"',
        re.DOTALL,
    ),
]


def _excluded(path: Path) -> bool:
    return any(part in EXCLUDE_DIR_NAMES for part in path.parts)


def scan_swift(root: Path) -> list[tuple[str, str, Path, int]]:
    """Yield (literal, reason, file, line) for each match."""
    flagged: list[tuple[str, str, Path, int]] = []
    for swift in root.rglob("*.swift"):
        if _excluded(swift):
            continue
        try:
            content = swift.read_text(encoding="utf-8")
        except UnicodeDecodeError:
            continue
        for pat in USER_VISIBLE_PATTERNS:
            for m in pat.finditer(content):
                literal = m.group(1)
                for forbidden_re, reason in FORBIDDEN:
                    if forbidden_re.search(literal):
                        line = content[: m.start()].count("\n") + 1
                        flagged.append((literal, reason, swift, line))
                        break  # one reason per literal is enough
    return flagged


def scan_xcstrings(path: Path) -> list[tuple[str, str, str, str]]:
    """
    Scan translated values in xcstrings — a clean source can still ship a
    bad translation. Yields (key, locale, value, reason).
    """
    if not path.exists():
        return []
    flagged: list[tuple[str, str, str, str]] = []
    with path.open() as f:
        data = json.load(f)
    for key, entry in data.get("strings", {}).items():
        for locale, loc_entry in entry.get("localizations", {}).items():
            value = loc_entry.get("stringUnit", {}).get("value", "")
            if not value:
                continue
            for forbidden_re, reason in FORBIDDEN:
                if forbidden_re.search(value):
                    flagged.append((key, locale, value, reason))
                    break
    return flagged


def main() -> int:
    repo = Path(__file__).resolve().parent.parent
    scan_root = repo / SCAN_ROOT_REL

    swift_hits = scan_swift(scan_root)
    xc_hits = scan_xcstrings(repo / XCSTRINGS_REL)
    info_hits = scan_xcstrings(repo / INFOPLIST_XCSTRINGS_REL)

    total = len(swift_hits) + len(xc_hits) + len(info_hits)
    if total == 0:
        print("✓ no review-killer phrases in user-visible strings")
        return 0

    print(f"\n✗ {total} review-killer phrase(s) found in user-visible text:\n")

    for literal, reason, file, line in swift_hits:
        rel = file.relative_to(repo)
        preview = literal if len(literal) <= 80 else literal[:77] + "…"
        print(f"  • {reason}")
        print(f"      at: {rel}:{line}")
        print(f"      string: {preview!r}")
        print()

    for key, locale, value, reason in xc_hits + info_hits:
        preview = value if len(value) <= 80 else value[:77] + "…"
        print(f"  • {reason}")
        print(f"      in xcstrings: key {key!r} / locale {locale}")
        print(f"      value: {preview!r}")
        print()

    print(
        "Fix: remove the offending phrases from user-visible strings.\n"
        "     If you genuinely need a debug-only label, gate it behind\n"
        "     `#if DEBUG` so it never reaches release/TestFlight builds."
    )
    return 1


if __name__ == "__main__":
    sys.exit(main())
