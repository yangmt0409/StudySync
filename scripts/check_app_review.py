#!/usr/bin/env python3
r"""
Umbrella runner for all App Store review pre-flight checks.

Run before every `git push` to TestFlight or App Store Connect upload to
catch the same classes of issues Apple has flagged on this codebase before:

  1. Localizations           — every String(localized:) / Text(...) literal
                                has en/ja/ko/zh-Hant translations.
  2. Info.plist localizations — every NS*UsageDescription has translations.
  3. Review killers           — no "TestFlight"/"测试版"/"sandbox"/"localhost"
                                /TODO/Lorem ipsum in user-visible strings.
  4. ATS compliance           — every http:// URL has an NSExceptionDomains
                                entry in Info.plist.
  5. Required submission keys — Info.plist has ITSAppUsesNonExemptEncryption,
                                PrivacyInfo.xcprivacy has the four required
                                top-level keys + well-formed entries.

Each sub-check is a standalone script with its own exit code and rationale
in its docstring. This umbrella runs them sequentially, prints each phase
with a delimiter, and returns non-zero if any phase failed (exit code = 1).

Usage:
  python3 scripts/check_app_review.py
  python3 scripts/check_app_review.py --quiet   # only show failures + summary

Exit codes:
  0  every check passed
  1  one or more checks failed
  2  script-level failure (a sub-check is missing, etc.)
"""

import argparse
import subprocess
import sys
from pathlib import Path


# (display name, script filename) — order is from cheapest to most-expensive,
# so a fast catch-all-the-easy-stuff style failure surfaces quickly.
CHECKS: list[tuple[str, str]] = [
    ("Required submission keys", "check_required_keys.py"),
    ("Info.plist localizations", "check_infoplist_localizations.py"),
    ("ATS compliance",           "check_ats_compliance.py"),
    ("Review-killer phrases",    "check_review_killers.py"),
    ("Localizations",            "check_localizations.py"),
]


def main() -> int:
    parser = argparse.ArgumentParser(description="Run all App Store review pre-flight checks.")
    parser.add_argument("--quiet", "-q", action="store_true",
                        help="Suppress passing-check output. Only show failures + summary.")
    args = parser.parse_args()

    scripts_dir = Path(__file__).resolve().parent

    # Sanity-check that every sub-script exists before running anything.
    for _, script in CHECKS:
        if not (scripts_dir / script).exists():
            print(f"error: sub-check missing: {script}", file=sys.stderr)
            return 2

    results: list[tuple[str, int]] = []
    for name, script in CHECKS:
        if not args.quiet:
            print(f"\n━━━ {name} ━━━")
            # Flush so the header lands before the subprocess's output —
            # otherwise Python's buffered stdout shows headers AFTER the
            # checks they label.
            sys.stdout.flush()
        proc = subprocess.run(
            [sys.executable, str(scripts_dir / script)],
            capture_output=args.quiet,
            text=True,
        )
        if args.quiet and proc.returncode != 0:
            # Surface the failure output that we suppressed
            print(f"\n━━━ {name} (FAILED) ━━━")
            sys.stdout.write(proc.stdout)
            sys.stderr.write(proc.stderr)
        results.append((name, proc.returncode))

    print("\n" + "═" * 60)
    print("App Store review pre-flight summary")
    print("═" * 60)
    all_ok = True
    for name, code in results:
        if code == 0:
            print(f"  ✓ {name}")
        else:
            all_ok = False
            print(f"  ✗ {name}  (exit {code})")
    print()

    if all_ok:
        print("✅  ready to ship.")
        return 0
    print("❌  fix the above before TestFlight / App Store upload.")
    return 1


if __name__ == "__main__":
    sys.exit(main())
