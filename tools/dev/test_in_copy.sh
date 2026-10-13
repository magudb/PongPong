#!/usr/bin/env bash
# Run the playtest harness against the CURRENT shared tree inside a disposable APFS-clone copy (plan R.7, 7.2 rule 2).
#
#   tools/dev/test_in_copy.sh <package-id> [options] [harness args...]
#   tools/dev/test_in_copy.sh P14-npc-dialogue --only=npc --character=fairy
#   tools/dev/test_in_copy.sh P04-area-framework --keep --only=area
#   tools/dev/test_in_copy.sh P09-test-harness --selftest
#
# Why: parallel package builders must verify against the shared tree without racing on the real directory's .godot
# import cache (never run `--import` in the canonical directory while others work there). A full S3TC cache is
# ~1.2 GB and a first import takes ~5 minutes, so the copy is seeded as an APFS CLONE of the canonical repo
# INCLUDING .godot (`cp -Rc` shares the blocks; the import cache is path-relative and md5-keyed, so it stays valid),
# then only the changes are rsynced in, the harness runs there, and the copy is DELETED again.
#
# Options (everything else is passed to tests/run_playtest.sh):
#   --keep         keep the copy afterwards. Default: delete it, except for the art packages P21 P22 P23 A1 A2, whose copies
#                  persist because their imports are expensive (TT_KEEP_COPY_RE overrides the pattern). Godot writes the
#                  .uid/.import files of NEW scripts/assets only into the copy: the script warns when it deletes such
#                  files; use --keep and copy them back (the lead's pull_meta.sh) if they belong to your package.
#   --docs         also sync docs/ (excluded by default: 30 MB of audio/art, not needed by tests; the `docs` section does)
#   --selftest     run tools/dev/selftest_harness.sh in the copy instead of the playtest
#   --no-run       only seed/sync and print the copy path (the caller runs Godot there; delete it with rm -rf)
#   --wipe         throw an existing copy away and seed again
# Environment:
#   SCRATCH        parent directory of the copies (default $TMPDIR/traetoppen-copies); the copy is $SCRATCH/copy-<package-id>
#   TT_REPO        canonical repository (default: the checkout this script lives in)
#   GODOT          engine binary
# Exit code: the harness's (0 pass, 1 failed checks / engine messages, 2 usage or infrastructure, 124 timeout).

PKG="${1:-}"
if [ -z "$PKG" ] || [ "${PKG#-}" != "$PKG" ]; then
	echo "usage: tools/dev/test_in_copy.sh <package-id> [--keep] [--docs] [--selftest] [--no-run] [--wipe] [harness args...]" >&2
	exit 2
fi
shift
case "$PKG" in
	*/*|*..*) echo "test_in_copy: the package id must be a plain name like P14-npc-dialogue (got '$PKG')" >&2; exit 2 ;;
esac

REPO="${TT_REPO:-$(cd "$(dirname "$0")/../.." && pwd)}"
TMP_BASE="${TMPDIR:-/tmp}"
SCRATCH="${SCRATCH:-${TMP_BASE%/}/traetoppen-copies}"
COPY="$SCRATCH/copy-$PKG"
KEEP=0
DOCS=0
SELFTEST=0
NO_RUN=0
WIPE=0
ARGS=()
for a in "$@"; do
	case "$a" in
		--keep) KEEP=1 ;;
		--docs) DOCS=1 ;;
		--selftest) SELFTEST=1 ;;
		--no-run) NO_RUN=1; KEEP=1 ;;
		--wipe) WIPE=1 ;;
		*) ARGS+=("$a") ;;
	esac
done
if [ "$COPY" = "$REPO" ]; then
	echo "test_in_copy: refusing to use the canonical repository as its own copy" >&2
	exit 2
fi
if [ ! -f "$REPO/project.godot" ]; then
	echo "test_in_copy: $REPO is not a Godot project (no project.godot)" >&2
	exit 2
fi
KEEP_RE="${TT_KEEP_COPY_RE:-^(P21|P22|P23|A1|A2)-}"
if echo "$PKG" | grep -Eq "$KEEP_RE"; then KEEP=1; fi

mkdir -p "$SCRATCH" || exit 2

# one run per package at a time (two imports in one directory corrupt the cache)
LOCK="$COPY.lock"
if ! mkdir "$LOCK" 2>/dev/null; then
	OTHER="$(cat "$LOCK/pid" 2>/dev/null)"
	if [ -n "$OTHER" ] && kill -0 "$OTHER" 2>/dev/null; then
		echo "test_in_copy: another run for $PKG is active (pid $OTHER); wait for it or use another package id" >&2
		exit 2
	fi
	rm -rf "${LOCK:?}"
	mkdir "$LOCK" || exit 2
fi
echo $$ >"$LOCK/pid"
cleanup() {
	cd "$SCRATCH" 2>/dev/null || cd /
	rm -rf "${LOCK:?}"
	if [ "$KEEP" = 0 ] && [ "$NO_RUN" = 0 ]; then
		# Godot-generated .uid / .import files of NEW files exist only in the copy: say so before they are deleted
		LOST=0
		if [ -d "$COPY" ]; then
			while IFS= read -r f; do
				[ -e "$REPO/${f#"$COPY"/}" ] || LOST=$((LOST + 1))
			done < <(find "$COPY" \( -path "$COPY/.godot" -o -path "$COPY/docs" \) -prune -o -type f \( -name '*.uid' -o -name '*.import' \) -print 2>/dev/null)
		fi
		if [ "$LOST" -gt 0 ]; then
			echo "test_in_copy: NOTE $LOST generated .uid/.import file(s) exist only in the copy and are deleted with it;" >&2
			echo "test_in_copy:      run again with --keep and copy them back (the lead's pull_meta.sh) if they belong to your package" >&2
		fi
		rm -rf "${COPY:?}"
		echo "test_in_copy: copy deleted ($COPY)"
	else
		echo "test_in_copy: copy kept at $COPY"
	fi
}
trap cleanup EXIT
trap 'exit 130' INT TERM

T0=$(date +%s)

# ---------------------------------------------------------------- seed: APFS clone including .godot
[ "$WIPE" = 1 ] && rm -rf "${COPY:?}"
# a copy without the marker is the leftover of an interrupted seeding
[ -d "$COPY" ] && [ ! -f "$COPY/.test_in_copy_seeded" ] && rm -rf "${COPY:?}"
if [ ! -d "$COPY" ]; then
	mkdir -p "$COPY" || exit 2
	# clone entry by entry so .git, docs and the art staging area (can be GBs) are never even cloned
	for e in "$REPO"/* "$REPO"/.[!.]*; do
		[ -e "$e" ] || continue
		n="$(basename "$e")"
		case "$n" in
			.git|.playwright-mcp|.mimocode|.selftest|.DS_Store|project.godot.lock) continue ;;
			docs) [ "$DOCS" = 1 ] || continue ;;
			tools)
				mkdir -p "$COPY/tools"
				for t in "$e"/* "$e"/.[!.]*; do
					[ -e "$t" ] || continue
					tn="$(basename "$t")"
					if [ "$tn" = art ]; then
						mkdir -p "$COPY/tools/art"
						for ta in "$t"/* "$t"/.[!.]*; do
							[ -e "$ta" ] || continue
							case "$(basename "$ta")" in _stage|.venv) continue ;; esac
							cp -Rc "$ta" "$COPY/tools/art/" 2>/dev/null || cp -R "$ta" "$COPY/tools/art/"
						done
					else
						cp -Rc "$t" "$COPY/tools/" 2>/dev/null || cp -R "$t" "$COPY/tools/"
					fi
				done
				continue
				;;
		esac
		cp -Rc "$e" "$COPY/" 2>/dev/null || cp -R "$e" "$COPY/"
	done
	if [ ! -d "$REPO/.godot" ]; then
		echo "test_in_copy: note: the canonical repo has no .godot cache; the first run in the copy imports everything"
	fi
	touch "$COPY/.test_in_copy_seeded"
	echo "test_in_copy: seeded $COPY (APFS clone) in $(( $(date +%s) - T0 )) s"
fi

# ---------------------------------------------------------------- sync only the changes
RSYNC_EXCLUDES=(--exclude=/.git --exclude=/.godot --exclude=/.playwright-mcp --exclude=/.mimocode --exclude=/.selftest
	--exclude=/tools/art/_stage --exclude=/tools/art/.venv --exclude=.DS_Store --exclude=project.godot.lock --exclude=/.test_in_copy_seeded)
[ "$DOCS" = 1 ] || RSYNC_EXCLUDES+=(--exclude=/docs)
T1=$(date +%s)
rsync -a --delete "${RSYNC_EXCLUDES[@]}" "$REPO/" "$COPY/" || { echo "test_in_copy: rsync failed" >&2; exit 2; }
echo "test_in_copy: synced changes in $(( $(date +%s) - T1 )) s (total $(( $(date +%s) - T0 )) s)"

if [ "$NO_RUN" = 1 ]; then
	echo "$COPY"
	exit 0
fi

# ---------------------------------------------------------------- run
cd "$COPY" || exit 2
if [ "$SELFTEST" = 1 ]; then
	tools/dev/selftest_harness.sh "${ARGS[@]}"
else
	tests/run_playtest.sh "${ARGS[@]}"
fi
RC=$?
echo "test_in_copy: $PKG finished with exit code $RC after $(( $(date +%s) - T0 )) s"
exit "$RC"
