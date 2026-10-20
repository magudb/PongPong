#!/bin/bash
# Arguments are separate argv values from ReleaseUpdates, never evaluated as shell code.
# The result file always ends as {"status":"installed|rolled_back|failed","reason":"..."}: the game reads a
# failure while it waits for "ready", and the next start of the game reports the outcome of the swap.
set -euo pipefail
parent_pid=$1
archive=$2
target=$3
expected_sha=$4
result=$5
no_launch=${6:-}
reason=arguments
ready=0
moved=0
installed=0
stage=""
report() {
  printf '{"status":"%s","reason":"%s"}\n' "$1" "$2" > "$result"
}
launch() {
  if [[ "$no_launch" != --no-launch ]]; then /usr/bin/open -n "$target"; fi
}
parent_running() {
  [[ "$parent_pid" != 0 ]] && /bin/kill -0 "$parent_pid" 2>/dev/null
}
finish() {
  code=$?
  if [[ "$installed" == 0 && "$moved" == 1 ]]; then
    if [[ -d "$target" ]]; then /bin/rm -rf "$target"; fi
    # Keep the stage (it holds the backup) when even the restore fails.
    /bin/mv "$backup" "$target" || { report failed restore || true; exit 1; }
    report rolled_back "$reason" || true
    launch || true
  elif [[ "$installed" == 0 ]]; then
    report failed "$reason" || true
    # After "ready" the game has quit: bring the unchanged installation back.
    if [[ "$ready" == 1 ]] && ! parent_running; then launch || true; fi
  fi
  if [[ -n "$stage" ]]; then /bin/rm -rf "$stage"; fi
  exit "$code"
}
trap finish EXIT
# Bash 3.2 (shipped with macOS) can ignore errexit for [[ ]] containing command
# substitutions. Reject failed validation explicitly before touching the installation.
[[ "$parent_pid" =~ ^[0-9]+$ && "$expected_sha" =~ ^[0-9a-f]{64}$ ]] || exit 1
reason=folder
[[ "$target" == /*/Traetoppen.app && -d "$target" && ! -L "$target" && -w "$(dirname "$target")" ]] || exit 1
reason=checksum
[[ "$(/usr/bin/shasum -a 256 "$archive" | /usr/bin/awk '{print $1}')" == "$expected_sha" ]] || exit 1
reason=package
/usr/bin/zipinfo -1 "$archive" | /usr/bin/awk '/(^\/|(^|\/)\.\.(\/|$)|\\)/ {exit 1}'
stage=$(/usr/bin/mktemp -d "$(dirname "$target")/.Traetoppen-update.XXXXXX")
backup="$stage/previous.app"
/usr/bin/ditto -x -k "$archive" "$stage"
replacement="$stage/Traetoppen.app"
[[ -x "$replacement/Contents/MacOS/Trætoppen" ]] || exit 1
[[ -z "$(/usr/bin/find "$replacement" -type l -print -quit)" ]] || exit 1
[[ "$(/usr/libexec/PlistBuddy -c 'Print CFBundleIdentifier' "$replacement/Contents/Info.plist")" == io.github.magudb.traetoppen ]] || exit 1
/usr/bin/codesign --verify --deep --strict "$replacement"
printf ready > "$result.ready"
ready=1
reason=game_running
for ((attempt=0; attempt<300; attempt++)); do
  if ! parent_running; then break; fi
  /bin/sleep 0.2
done
if parent_running; then exit 1; fi
reason=locked
# Indexers and antivirus scanners can briefly hold a bundle the game has just closed.
for delay in 0.25 0.5 1 2 4 0; do
  if /bin/mv "$target" "$backup"; then break; fi
  if [[ "$delay" == 0 ]]; then exit 1; fi
  /bin/sleep "$delay"
done
moved=1
/bin/mv "$replacement" "$target"
# The outcome is written before the new build starts, so a failed write never rolls back a running game.
reason=unknown
report installed ""
reason=launch
launch
installed=1
