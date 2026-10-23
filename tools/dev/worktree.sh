#!/usr/bin/env bash
# tools/dev/worktree.sh - branches and worktrees for Traetoppen.
#
# Model: this folder (branch `main`) is THE project and stays green. Work happens on a branch in its own worktree,
# a sibling folder next to the repo (default ../PongPong-worktrees/<name>, override with TT_WORKTREES=DIR). One branch =
# one worktree = one Godot project directory with its own .godot cache; the git history and objects are shared.
#
#   tools/dev/worktree.sh new <name> [base]   create branch <name> (from base, default main) and its worktree; links the
#                                             art venv and runs two headless imports so the worktree starts warm
#   tools/dev/worktree.sh list                all worktrees (path, branch, clean/dirty)
#   tools/dev/worktree.sh path <name>         print the worktree path
#   tools/dev/worktree.sh refresh <name>      re-link the venv and re-import (after switching base or a failed import)
#   tools/dev/worktree.sh remove <name> [--delete-branch]
#                                             remove a CLEAN worktree; the branch stays unless --delete-branch and it is merged
#
# Merge a finished branch from the main worktree (not from here): `git merge --no-ff <name>`, then `remove <name> --delete-branch`.
# Never open the same worktree in two Godot instances (or the editor and a headless run) at once: each writes .godot and .uid/.import files.
set -euo pipefail

GODOT="${GODOT:-/Applications/Godot.app/Contents/MacOS/Godot}"
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
COMMON="$(git -C "$HERE" rev-parse --path-format=absolute --git-common-dir)"
MAIN="$(cd "$COMMON/.." && pwd)"                 # the main worktree (the folder that owns the .git directory)
WT_ROOT="${TT_WORKTREES:-$(cd "$MAIN/.." && pwd)/$(basename "$MAIN")-worktrees}"

die() { echo "worktree.sh: $*" >&2; exit 1; }

valid_name() { [[ "$1" =~ ^[a-z0-9][a-z0-9._-]*$ ]] || die "name '$1' must be lowercase letters, digits, . _ - (it is a folder name and a branch name)"; }

link_and_warm() {   # $1 = worktree path, $2 = "import" | "noimport"
  local wt="$1"
  if [ -d "$MAIN/tools/art/.venv" ] && [ ! -e "$wt/tools/art/.venv" ]; then
    ln -s "$MAIN/tools/art/.venv" "$wt/tools/art/.venv"
  fi
  # No cloned cache: main's .godot can be stale, and a stale cache makes Godot rewrite tracked files (props.json) on the first
  # import. A fresh import is slower (about a minute) but leaves the worktree clean.
  if [ "$2" = import ] && [ -x "$GODOT" ]; then
    "$GODOT" --headless --path "$wt" --import >/dev/null 2>&1 || true
    "$GODOT" --headless --path "$wt" --import >/dev/null 2>&1 || true
  fi
}

cmd="${1:-}"; shift || true
case "$cmd" in
  new)
    [ $# -ge 1 ] || die "usage: worktree.sh new <name> [base]"
    name="$1"; base="${2:-main}"; valid_name "$name"
    wt="$WT_ROOT/$name"
    [ ! -e "$wt" ] || die "$wt already exists"
    mkdir -p "$WT_ROOT"
    if git -C "$MAIN" show-ref --verify --quiet "refs/heads/$name"; then
      git -C "$MAIN" worktree add "$wt" "$name"
    else
      git -C "$MAIN" worktree add -b "$name" "$wt" "$base"
    fi
    link_and_warm "$wt" import
    echo "worktree ready: $wt  (branch $name, from $base)"
    echo "  tests:   (cd '$wt' && tests/run_playtest.sh --strict --no-boot --only=<section>)   gate: tools/dev/ci_local.sh"
    echo "  editor:  open $wt in Godot (only one Godot per worktree at a time)"
    ;;
  list)
    git -C "$MAIN" worktree list --porcelain | awk '/^worktree /{p=$2} /^branch /{b=$2; sub("refs/heads/","",b)} /^$/{if(p!=""){print p"\t"b; p=""; b=""}} END{if(p!="")print p"\t"b}' | while IFS=$'\t' read -r p b; do
      if [ -n "$(git -C "$p" status --porcelain 2>/dev/null | head -1)" ]; then s=dirty; else s=clean; fi
      printf '%-8s %-24s %s\n' "$s" "${b:-detached}" "$p"
    done
    ;;
  path)
    [ $# -ge 1 ] || die "usage: worktree.sh path <name>"
    valid_name "$1"; [ -d "$WT_ROOT/$1" ] || die "no worktree $WT_ROOT/$1"; echo "$WT_ROOT/$1" ;;
  refresh)
    [ $# -ge 1 ] || die "usage: worktree.sh refresh <name>"
    valid_name "$1"; [ -d "$WT_ROOT/$1" ] || die "no worktree $WT_ROOT/$1"
    link_and_warm "$WT_ROOT/$1" import; echo "refreshed $WT_ROOT/$1" ;;
  remove)
    [ $# -ge 1 ] || die "usage: worktree.sh remove <name> [--delete-branch]"
    name="$1"; valid_name "$name"; wt="$WT_ROOT/$name"
    [ -d "$wt" ] || die "no worktree $wt"
    [ -z "$(git -C "$wt" status --porcelain)" ] || die "$wt has uncommitted changes: commit or stash them first"
    rm -f "$wt/tools/art/.venv" 2>/dev/null || true       # the symlink only, never the real venv
    git -C "$MAIN" worktree remove "$wt"
    if [ "${2:-}" = "--delete-branch" ]; then
      git -C "$MAIN" branch -d "$name"                    # refuses an unmerged branch
    fi
    echo "removed $wt" ;;
  ""|-h|--help|help)
    sed -n '2,19p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//' ;;
  *) die "unknown command '$cmd' (try --help)" ;;
esac
