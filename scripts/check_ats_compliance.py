#!/usr/bin/env python3
r"""
Verify every plain-`http://` URL in the Swift sources is exempted by an
Info.plist `NSExceptionDomains` entry.

────────────────────────────────────────────────────────────────────────────
Why this exists
────────────────────────────────────────────────────────────────────────────
App Transport Security (ATS) blocks plain HTTP by default. If a request
fires unblocked, the app *appears* to silently fail at runtime — Apple's
reviewer sees "feature doesn't work" and rejects under Guideline 2.1
(App Completeness).

This codebase already has one HTTP URL (AviationStack free tier is HTTP-only)
with the matching ATS exception. This check makes sure any future HTTP URL
also gets paired with its exception.

Allowed forms in Info.plist:
    NSAppTransportSecurity
      NSExceptionDomains
        api.example.com → { NSIncludesSubdomains, ... }

A URL like http://api.aviationstack.com/foo matches the entry
"api.aviationstack.com". A URL like http://sub.api.aviationstack.com/foo
matches only if NSIncludesSubdomains=true on that entry.

Exit codes:
  0  every http:// URL has a matching ATS exception
  1  one or more URLs without exception
  2  files unreadable
"""

import plistlib
import re
import sys
from pathlib import Path
from urllib.parse import urlparse

SCAN_ROOT_REL = "StudySync"
INFOPLIST_REL = "StudySync/Info.plist"
EXCLUDE_DIR_NAMES = {".build", "Build", "DerivedData", ".swiftpm"}

# Match `http://...` up to the first whitespace, quote, paren, or angle.
# We deliberately don't match `https://` since those don't need ATS exceptions.
HTTP_URL_RE = re.compile(r"http://[^\s\"'`<>\\]+")


def _excluded(path: Path) -> bool:
    return any(part in EXCLUDE_DIR_NAMES for part in path.parts)


def find_http_urls(root: Path) -> list[tuple[str, Path, int]]:
    """Yield (host, file, line) for each plain-http URL in Swift sources."""
    hits: list[tuple[str, Path, int]] = []
    for swift in root.rglob("*.swift"):
        if _excluded(swift):
            continue
        try:
            content = swift.read_text(encoding="utf-8")
        except UnicodeDecodeError:
            continue
        for m in HTTP_URL_RE.finditer(content):
            url = m.group(0).rstrip(".,;:)\"'")
            host = urlparse(url).hostname
            if not host:
                continue
            line = content[: m.start()].count("\n") + 1
            hits.append((host, swift, line))
    return hits


def load_ats_exceptions(plist_path: Path) -> dict[str, bool]:
    """
    Returns {domain: includes_subdomains} for every entry in
    NSAppTransportSecurity → NSExceptionDomains.
    """
    with plist_path.open("rb") as f:
        plist = plistlib.load(f)
    ats = plist.get("NSAppTransportSecurity", {}) or {}
    domains = ats.get("NSExceptionDomains", {}) or {}
    return {
        domain: bool(cfg.get("NSIncludesSubdomains", False))
        for domain, cfg in domains.items()
    }


def is_exempted(host: str, exceptions: dict[str, bool]) -> bool:
    """
    Does any NSExceptionDomains entry cover `host`?
    Direct match always works; subdomain match only when
    NSIncludesSubdomains=true on the parent entry.
    """
    for domain, includes_subs in exceptions.items():
        if host == domain:
            return True
        if includes_subs and host.endswith("." + domain):
            return True
    return False


def main() -> int:
    repo = Path(__file__).resolve().parent.parent
    scan_root = repo / SCAN_ROOT_REL
    info_path = repo / INFOPLIST_REL

    if not info_path.exists():
        print(f"error: {info_path} not found", file=sys.stderr)
        return 2

    exceptions = load_ats_exceptions(info_path)
    hits = find_http_urls(scan_root)

    bad: list[tuple[str, Path, int]] = [
        (host, file, line)
        for host, file, line in hits
        if not is_exempted(host, exceptions)
    ]

    if not bad:
        print(
            f"✓ ATS compliance OK ({len(hits)} http URL(s) checked, "
            f"{len(exceptions)} exception domain(s) declared)"
        )
        return 0

    print(f"\n✗ {len(bad)} http:// URL(s) lack a matching ATS exception:\n")
    seen: set[tuple[str, Path]] = set()
    for host, file, line in bad:
        rel = file.relative_to(repo)
        key = (host, rel)
        if key in seen:
            continue
        seen.add(key)
        print(f"  • {host}")
        print(f"      at: {rel}:{line}")
        print()
    print(
        "Fix: either switch to https://, or add an entry under\n"
        "     NSAppTransportSecurity → NSExceptionDomains in Info.plist.\n"
        "     See `api.aviationstack.com` in Info.plist for the template."
    )
    return 1


if __name__ == "__main__":
    sys.exit(main())
