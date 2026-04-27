#!/usr/bin/env bash
#
# One-shot installer for repo-local git hooks. Run once after cloning:
#
#   ./scripts/install-git-hooks.sh
#
# Hooks installed:
#   pre-commit  →  runs scripts/check_app_review.py, the umbrella that
#                  bundles every Apple-review pre-flight check
#                  (localizations, Info.plist localizations, ATS, review-
#                  killer phrases, required submission keys). Blocks the
#                  commit if any check fails.
#
# `.git/hooks/` isn't versioned, so this bootstrap step is per-checkout.
# The hook itself is short and self-contained — re-running this installer
# overwrites it, which is what you want when the hook contents change.
#
# To bypass the check on a one-off commit (don't make a habit of it):
#   git commit --no-verify

set -euo pipefail

repo_root="$(git rev-parse --show-toplevel)"
hooks_dir="$repo_root/.git/hooks"
target="$hooks_dir/pre-commit"

mkdir -p "$hooks_dir"

cat > "$target" <<'HOOK'
#!/usr/bin/env bash
# Auto-installed by scripts/install-git-hooks.sh. Do not edit by hand —
# changes will be overwritten on the next install run.

# Only run when the change touches files our checks care about. Pure
# documentation / asset / config commits skip the gate.
if ! git diff --cached --name-only --diff-filter=ACMR \
        | grep -qE '\.(swift|xcstrings|plist|xcprivacy)$'; then
    exit 0
fi

repo_root="$(git rev-parse --show-toplevel)"
exec python3 "$repo_root/scripts/check_app_review.py" --quiet
HOOK

chmod +x "$target"

echo "✓ installed pre-commit hook → $target"
echo
echo "Test it now:"
echo "  python3 scripts/check_localizations.py"
