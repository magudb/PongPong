#!/bin/bash
# Arguments are separate argv values from ReleaseUpdates, never evaluated as shell code.
set -euo pipefail
parent_pid=$1
archive=$2
target=$3
expected_sha=$4
result=$5
no_launch=${6:-}
[[ "$parent_pid" =~ ^[0-9]+$ && "$expected_sha" =~ ^[0-9a-f]{64}$ ]]
[[ "$target" == /*/Traetoppen.app && -d "$target" && ! -L "$target" && -w "$(dirname "$target")" ]]
[[ "$(/usr/bin/shasum -a 256 "$archive" | /usr/bin/awk '{print $1}')" == "$expected_sha" ]]
/usr/bin/zipinfo -1 "$archive" | /usr/bin/awk '/(^\/|(^|\/)\.\.(\/|$)|\\)/ {exit 1}'
stage=$(/usr/bin/mktemp -d "$(dirname "$target")/.Traetoppen-update.XXXXXX")
backup="$stage/previous.app"
moved=0
installed=0
finish() {
  code=$?
  if [[ "$installed" == 0 && "$moved" == 1 ]]; then
    if [[ -d "$target" ]]; then /bin/rm -rf "$target"; fi
    /bin/mv "$backup" "$target" || exit 1
    printf '{"status":"rolled_back"}\n' > "$result"
    if [[ "$no_launch" != --no-launch ]]; then /usr/bin/open -n "$target" || true; fi
  elif [[ "$installed" == 0 ]]; then
    printf '{"status":"failed"}\n' > "$result"
  fi
  /bin/rm -rf "$stage"
  exit "$code"
}
trap finish EXIT
/usr/bin/ditto -x -k "$archive" "$stage"
replacement="$stage/Traetoppen.app"
[[ -x "$replacement/Contents/MacOS/Traetoppen" ]]
[[ -z "$(/usr/bin/find "$replacement" -type l -print -quit)" ]]
[[ "$(/usr/libexec/PlistBuddy -c 'Print CFBundleIdentifier' "$replacement/Contents/Info.plist")" == io.github.magudb.traetoppen ]]
/usr/bin/codesign --verify --deep --strict "$replacement"
printf ready > "$result.ready"
for ((attempt=0; attempt<300; attempt++)); do
  if [[ "$parent_pid" == 0 ]] || ! /bin/kill -0 "$parent_pid" 2>/dev/null; then break; fi
  /bin/sleep 0.2
done
if [[ "$parent_pid" != 0 ]] && /bin/kill -0 "$parent_pid" 2>/dev/null; then exit 1; fi
/bin/mv "$target" "$backup"
moved=1
/bin/mv "$replacement" "$target"
if [[ "$no_launch" != --no-launch ]]; then /usr/bin/open -n "$target"; fi
printf '{"status":"installed"}\n' > "$result"
installed=1
