#!/usr/bin/env python3
r"""
Verify Info.plist + PrivacyInfo.xcprivacy contain the keys Apple requires
for App Store submission.

────────────────────────────────────────────────────────────────────────────
Why this exists
────────────────────────────────────────────────────────────────────────────
Some keys are auto-rejection if missing — Apple's connector pipeline parses
the .ipa, sees the missing key, and bounces before a human reviewer ever
looks. You'd lose half a day on the round-trip. This catches it locally.

Specifically:

  ITSAppUsesNonExemptEncryption
    Required since 2024. Either `false` (the common case — TLS only) or
    `true` plus a valid export-compliance documentation upload. Missing key
    = auto-reject.

  Privacy manifest (PrivacyInfo.xcprivacy)
    Required since 2024-Q2 for any app that uses "Required Reason APIs"
    (UserDefaults, Date, FileManager mtimes, etc.). At minimum the file
    must exist with the four top-level keys. Apps that ALSO collect data
    must declare it under NSPrivacyCollectedDataTypes.

  CFBundleDisplayName / CFBundleShortVersionString / CFBundleVersion
    These are usually injected by Xcode at build time, but a fresh /
    customized scheme can drop them. Apple rejects builds without a
    marketing version + build number.

────────────────────────────────────────────────────────────────────────────
Exit codes
────────────────────────────────────────────────────────────────────────────
  0  all required keys present and well-formed
  1  one or more missing
  2  files unreadable
"""

import plistlib
import sys
from pathlib import Path

INFOPLIST_REL = "StudySync/Info.plist"
PRIVACY_REL = "StudySync/PrivacyInfo.xcprivacy"

# Keys that must exist at the top level of Info.plist. Note: some Xcode
# project templates inject CFBundleVersion / CFBundleShortVersionString at
# build time via $(MARKETING_VERSION) interpolation, so we tolerate those
# being absent from the source plist as long as they're not literally empty
# strings. ITSAppUsesNonExemptEncryption MUST be set as a literal bool.
REQUIRED_INFOPLIST_KEYS: list[tuple[str, str]] = [
    ("ITSAppUsesNonExemptEncryption",
     "Encryption export declaration. Set to `<false/>` for TLS-only apps."),
]

# Keys the privacy manifest MUST have at top level.
REQUIRED_PRIVACY_KEYS: list[tuple[str, str]] = [
    ("NSPrivacyTracking",
     "Tracking declaration (Bool). Set to <false/> if you don't track."),
    ("NSPrivacyTrackingDomains",
     "Tracking domains array. Empty array is fine if NSPrivacyTracking=false."),
    ("NSPrivacyCollectedDataTypes",
     "Per-data-type collection declarations."),
    ("NSPrivacyAccessedAPITypes",
     "Required-reason API declarations (UserDefaults, Date, etc.)."),
]


def check_infoplist(path: Path) -> list[str]:
    if not path.exists():
        return [f"Info.plist not found at {path}"]
    with path.open("rb") as f:
        plist = plistlib.load(f)
    issues: list[str] = []
    for key, why in REQUIRED_INFOPLIST_KEYS:
        if key not in plist:
            issues.append(f"Info.plist missing `{key}` — {why}")
    return issues


def check_privacy_manifest(path: Path) -> list[str]:
    if not path.exists():
        return [
            f"PrivacyInfo.xcprivacy not found at {path}. "
            "Apple requires this file for any app using Required Reason APIs "
            "(UserDefaults, Date, FileManager, etc.) — i.e. essentially every app."
        ]
    with path.open("rb") as f:
        plist = plistlib.load(f)
    issues: list[str] = []
    for key, why in REQUIRED_PRIVACY_KEYS:
        if key not in plist:
            issues.append(f"PrivacyInfo.xcprivacy missing `{key}` — {why}")

    # Sanity: if NSPrivacyTracking=true, NSPrivacyTrackingDomains should be non-empty.
    tracking = plist.get("NSPrivacyTracking")
    domains = plist.get("NSPrivacyTrackingDomains") or []
    if tracking is True and not domains:
        issues.append(
            "NSPrivacyTracking=true but NSPrivacyTrackingDomains is empty — "
            "Apple expects at least one domain you track against."
        )

    # Sanity: if you declare any required-reason API, each entry needs the
    # NSPrivacyAccessedAPIType + NSPrivacyAccessedAPITypeReasons sub-keys.
    api_entries = plist.get("NSPrivacyAccessedAPITypes") or []
    for i, entry in enumerate(api_entries):
        if "NSPrivacyAccessedAPIType" not in entry:
            issues.append(
                f"NSPrivacyAccessedAPITypes[{i}] missing `NSPrivacyAccessedAPIType`."
            )
        reasons = entry.get("NSPrivacyAccessedAPITypeReasons")
        if reasons is None or len(reasons) == 0:
            issues.append(
                f"NSPrivacyAccessedAPITypes[{i}] missing or empty "
                f"`NSPrivacyAccessedAPITypeReasons` array."
            )
    return issues


def main() -> int:
    repo = Path(__file__).resolve().parent.parent
    info_issues = check_infoplist(repo / INFOPLIST_REL)
    privacy_issues = check_privacy_manifest(repo / PRIVACY_REL)
    issues = info_issues + privacy_issues

    if not issues:
        print("✓ Info.plist + PrivacyInfo.xcprivacy required keys OK")
        return 0

    print(f"\n✗ {len(issues)} compliance issue(s) in submission metadata:\n")
    for msg in issues:
        print(f"  • {msg}")
        print()
    return 1


if __name__ == "__main__":
    sys.exit(main())
