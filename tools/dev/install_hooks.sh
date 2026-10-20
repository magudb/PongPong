#!/usr/bin/env bash
# tools/dev/install_hooks.sh - the optional pre-commit size guard (REPO-01; docs/DEVELOPMENT.md, "Repository size").
#
#   tools/dev/install_hooks.sh            install or refresh the pre-commit hook
#   tools/dev/install_hooks.sh --remove   remove it again
#
# The hook runs `tools/ci/size_guard.py --staged`: it refuses a commit that stages a blob over the limits of
# tools/ci/size_allowlist.txt, and warns about (or, with `plain-on-lfs error`, refuses) a plain blob on a Git LFS path
# (git-lfs not installed). CI applies the same rules to
# every push and pull request, so the hook only moves the failure to commit time; `git commit --no-verify` skips it once.
# Hooks live in the shared git directory, so one install covers every worktree of the clone. A pre-commit hook that this
# script did not write is never overwritten (exit 2).
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
MARK="# installed by tools/dev/install_hooks.sh"

die() { echo "install_hooks.sh: $*" >&2; exit 2; }

if hooks_path="$(git -C "$HERE" config --get core.hooksPath)"; then
	case "$hooks_path" in
		/*) HOOKS="$hooks_path" ;;
		*) HOOKS="$HERE/$hooks_path" ;;
	esac
else
	HOOKS="$(git -C "$HERE" rev-parse --path-format=absolute --git-common-dir)/hooks"
fi
HOOK="$HOOKS/pre-commit"

if [ -e "$HOOK" ] && ! grep -qF "$MARK" "$HOOK"; then
	die "$HOOK exists and was not written by this script; merge it by hand (it should run tools/ci/size_guard.py --staged)"
fi

case "${1:-}" in
	--remove)
		rm -f "$HOOK"
		echo "install_hooks.sh: removed $HOOK"
		exit 0 ;;
	"") ;;
	*) die "usage: tools/dev/install_hooks.sh [--remove]" ;;
esac

mkdir -p "$HOOKS"
cat > "$HOOK" <<EOF
#!/bin/sh
$MARK: the repository size guard (docs/DEVELOPMENT.md, "Repository size").
top="\$(git rev-parse --show-toplevel)" || exit 1
# a branch from before the guard has no script: nothing to check
[ -f "\$top/tools/ci/size_guard.py" ] || exit 0
exec python3 "\$top/tools/ci/size_guard.py" --staged
EOF
chmod +x "$HOOK"
echo "install_hooks.sh: installed $HOOK"
