#!/usr/bin/env bash
# tools/dev/lock.sh - sourced by the dev scripts (play.sh, run_windowed.sh): run a command while holding an exclusive lock file.
#
#   . tools/dev/lock.sh
#   with_lock FILE CMD [ARGS...]     waits until FILE is free, runs CMD with the lock held, returns CMD's exit code
#
# Uses lockf(1) (macOS, the BSDs) or flock(1) (Linux, Homebrew util-linux); both take a flock(2) lock on FILE, so scripts that
# use either one (the lead's windowed.sh uses `lockf -k`) wait for each other. Without either tool it falls back to a lock
# directory FILE.d holding the owner's pid; a directory left behind by a process that no longer runs is taken over.

with_lock() {
	local lock="$1"
	shift
	if [ -x /usr/bin/lockf ]; then
		/usr/bin/lockf -k "$lock" "$@"
	elif command -v flock >/dev/null 2>&1; then
		flock "$lock" "$@"
	else
		local dir="$lock.d" other rc
		until mkdir "$dir" 2>/dev/null; do
			other="$(cat "$dir/pid" 2>/dev/null)"
			if [ -n "$other" ] && ! kill -0 "$other" 2>/dev/null; then
				rm -rf "${dir:?}"
				continue
			fi
			sleep 1
		done
		echo "$$" >"$dir/pid"
		"$@"
		rc=$?
		rm -rf "${dir:?}"
		return "$rc"
	fi
}

# take_checkout_lock ROOT WHO     one Godot per checkout (docs/DEVELOPMENT.md): takes the run lock of the checkout at ROOT without
#                                 waiting, or prints who holds it and returns 1. The lock is a directory under $TMPDIR named after
#                                 a checksum of ROOT (not inside the checkout: an APFS clone of a busy checkout must not inherit it).
# release_checkout_lock           drops it again (call it from the EXIT trap).
CHECKOUT_LOCK=""
take_checkout_lock() {
	local base="${TMPDIR:-/tmp}" other
	local dir
	dir="${base%/}/traetoppen-checkout-$(printf '%s' "$1" | cksum | cut -d' ' -f1).lock"
	if ! mkdir "$dir" 2>/dev/null; then
		other="$(cat "$dir/pid" 2>/dev/null)"
		if [ -z "$other" ] || kill -0 "$other" 2>/dev/null; then
			echo "$2: another run is using this checkout ($(cat "$dir/what" 2>/dev/null || echo "lock $dir"), pid ${other:-?})." >&2
			echo "$2: one Godot per checkout at a time: wait for it, or use an APFS clone (tools/dev/test_in_copy.sh)." >&2
			return 1
		fi
		rm -rf "${dir:?}"
		mkdir "$dir" 2>/dev/null || { echo "$2: could not take the checkout lock $dir" >&2; return 1; }
	fi
	echo "$$" >"$dir/pid"
	echo "$2 in $1" >"$dir/what"
	CHECKOUT_LOCK="$dir"
}

release_checkout_lock() {
	if [ -n "$CHECKOUT_LOCK" ]; then
		rm -rf "${CHECKOUT_LOCK:?}"
		CHECKOUT_LOCK=""
	fi
}
