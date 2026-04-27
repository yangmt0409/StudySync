#!/usr/bin/env python3
r"""
Verify every user-facing key in Info.plist has translations in
InfoPlist.xcstrings for all required locales.

────────────────────────────────────────────────────────────────────────────
Why this exists
────────────────────────────────────────────────────────────────────────────
This is the EXACT issue that got v1.0.1 rejected by Apple under Guideline 4
(Design): the reviewer's iPad was set to a non-Chinese locale, the camera
permission prompt rendered the Chinese fallback because no JP/KR translation
existed in InfoPlist.xcstrings, and the app got bounced. The fix landed in
v1.0.2 — this check ensures it stays fixed.

────────────────────────────────────────────────────────────────────────────
What it checks
────────────────────────────────────────────────────────────────────────────
For each Info.plist key whose name matches one of USER_FACING_SUFFIXES
(e.g. NSCameraUsageDescription), verify the same key exists in
InfoPlist.xcstrings with `state: "translated"` for every locale in
REQUIRED_LOCALES.

CFBundleName + CFBundleDisplayName are also checked because the system
display name can be localized too.

Exit codes:
  0  all permission keys are fully translated
  1  one or more keys missing translations
  2  files unreadable / missing
"""

import json
import plistlib
import sys
from pathlib import Path

INFOPLIST_REL = "StudySync/Info.plist"
XCSTRINGS_REL = "StudySync/InfoPlist.xcstrings"

REQUIRED_LOCALES = ["en", "ja", "ko", "zh-Hant"]

# Substrings in Info.plist key names that mean "user-facing string".
# Permission strings are obvious; we also pick up app display names.
USER_FACING_SUFFIXES = (
    "UsageDescription",   # NSCameraUsageDescription, etc.
    "UsageReason",        # newer privacy reason keys
    "UsageExplanation",
)
USER_FACING_EXACT = {
    "CFBundleDisplayName",
    "CFBundleName",
    "CFBundleSpokenName",
    # Shortcut titles + 3D-touch app shortcuts also appear in Info.plist
    # via UIApplicationShortcutItems[].UIApplicationShortcutItemTitle.
    # Those are checked separately because they're array entries, not
    # top-level keys.
}


def collect_user_facing_keys(plist: dict) -> list[str]:
    """Top-level Info.plist keys that surface text to the user."""
    keys = [
        k for k in plist.keys()
        if k.endswith(USER_FACING_SUFFIXES) or k in USER_FACING_EXACT
    ]
    # UIApplicationShortcutItems → each entry has a UIApplicationShortcutItemTitle
    # that goes into the long-press home-screen menu. Pull those titles out
    # so they're checked too.
    for shortcut in plist.get("UIApplicationShortcutItems", []) or []:
        title = shortcut.get("UIApplicationShortcutItemTitle")
        if title:
            keys.append(title)
    return sorted(set(keys))


def main() -> int:
    repo = Path(__file__).resolve().parent.parent
    info_path = repo / INFOPLIST_REL
    xc_path = repo / XCSTRINGS_REL

    if not info_path.exists():
        print(f"error: {info_path} not found", file=sys.stderr)
        return 2

    with info_path.open("rb") as f:
        plist = plistlib.load(f)

    user_facing = collect_user_facing_keys(plist)

    if not xc_path.exists():
        print(
            f"✗ InfoPlist.xcstrings is missing — {len(user_facing)} keys "
            f"won't be localized:\n  " + "\n  ".join(user_facing),
            file=sys.stderr,
        )
        return 1

    with xc_path.open() as f:
        xc = json.load(f)
    strings = xc.get("strings", {})

    missing: list[tuple[str, list[str], str]] = []
    for key in user_facing:
        # In InfoPlist.xcstrings the lookup key is the Info.plist key name
        # itself (e.g. "NSCameraUsageDescription"). Shortcut titles are
        # stored by their string value, which we pulled into the same list.
        entry = strings.get(key)
        source_value = plist.get(key, "(shortcut title)") if key in plist else key
        if entry is None:
            missing.append((key, ["(key not in InfoPlist.xcstrings)"], source_value))
            continue
        locs = entry.get("localizations", {})
        bad = [
            l for l in REQUIRED_LOCALES
            if locs.get(l, {}).get("stringUnit", {}).get("state") != "translated"
        ]
        if bad:
            missing.append((key, bad, source_value))

    if not missing:
        print(f"✓ Info.plist localizations OK ({len(user_facing)} keys checked)")
        return 0

    print(f"\n✗ {len(missing)} Info.plist key(s) missing translations for {REQUIRED_LOCALES}:\n")
    for key, bad, source in missing:
        print(f"  • {key}")
        print(f"      missing locales: {bad}")
        if isinstance(source, str):
            preview = source if len(source) <= 80 else source[:77] + "…"
            print(f"      source value: {preview!r}")
        print()
    print(
        "Fix: open StudySync/InfoPlist.xcstrings in Xcode and translate "
        "these keys. This is exactly the v1.0.1 → v1.0.2 Apple Guideline 4 "
        "rejection — don't let it ship again."
    )
    return 1


if __name__ == "__main__":
    sys.exit(main())
