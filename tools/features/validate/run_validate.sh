#!/bin/bash
# Staged content validation of the feature pack (package F1; docs/features/STAGES.md).
#
#   tools/features/validate/run_validate.sh [--stage f1|p13|p14|full] [--src DIR] [--reports DIR] [--work DIR] [--keep-project]
#
#   --stage    which files stand in for the packages that finish later (default f1):
#                f1   F1's files + the PENDING references (quests lost_cat, fix_roof, birthday_cake, math_wizard_quiz; dialogues guard_oak, fairy_wizard, fairy_king)   (F1's gate, wave 3)
#                p13  the four quests come from the REAL repo lua/quests (rule Q3: their rewards equal the reviewed pending rewards), dialogues still pending            (P13's gate, wave 4)
#                p14  quests AND dialogues come from the real repo (rule S13 runs against P14's real files)                                                              (P14's gate, wave 5)
#                full same as p14                                                                                                                                       (F10, wave 7)
#              A stage never skips a rule: a missing real file stops the run ("stage p14 needs lua/dialogue/fairy_king.lua", exit 5).
#   --src      the tree under test instead of the repo (a repo-shaped directory; the mutation test uses it to apply one defect to a copy)
#   --reports  where the dumps and the report go (default tools/features/reports, gitignored)
#   --work     where the stage tree and the project copy are built (default tools/features/_stage, gitignored)
#
# Needs: lua5.4 + luac5.4 (the real-Lua cross-check: brew install lua), rsync, the art venv python (tools/art/setup_env.sh; numpy for the footprint probes, fontTools), Godot 4.7.2.
# Godot NEVER opens the repo directory: it runs in a project copy ($WORK/project, an overlay of the repo + the stage tree).  Run this script from an APFS clone of the repo
# (impl/tools/clone_run.sh), like every other Godot command of the build.
# Exit 0 only when no rule fails.
set -u
export PYTHONDONTWRITEBYTECODE=1
STAGE=f1
SRC=""
REPORTS=""
WORK=""
KEEP=0
while [ $# -gt 0 ]; do
  case "$1" in
    --stage) STAGE="${2:-f1}"; shift 2 ;;
    --src) SRC="${2:-}"; shift 2 ;;
    --reports) REPORTS="${2:-}"; shift 2 ;;
    --work) WORK="${2:-}"; shift 2 ;;
    --keep-project) KEEP=1; shift ;;
    -h|--help) sed -n 2,22p "$0"; exit 0 ;;
    *) echo "run_validate: unknown argument $1" >&2; exit 2 ;;
  esac
done
case "$STAGE" in f1|p13|p14|full) ;; *) echo "run_validate: unknown stage '$STAGE' (f1|p13|p14|full)" >&2; exit 2 ;; esac

HERE="$(cd "$(dirname "$0")" && pwd)"
FEAT="$(cd "$HERE/.." && pwd)"
REPO="$(cd "$FEAT/../.." && pwd)"
SRC="${SRC:-$REPO}"
WORK="${WORK:-$FEAT/_stage}"
REP="${REPORTS:-$FEAT/reports}"
GODOT="${GODOT:-/Applications/Godot.app/Contents/MacOS/Godot}"
ARTPY="${ARTPY:-$REPO/tools/art/.venv/bin/python}"
[ -x "$ARTPY" ] || ARTPY="python3"
ST="$WORK/$STAGE/tree"
PROJ="${PROJ:-$WORK/project}"
mkdir -p "$REP" "$WORK"

need() { command -v "$1" >/dev/null 2>&1 || { echo "run_validate: '$1' not found ($2)" >&2; exit 6; }; }
need lua5.4 "brew install lua: the real Lua 5.4 evaluates every data file as the reference"
need luac5.4 "brew install lua"
need rsync "macOS ships it"
[ -x "$GODOT" ] || { echo "run_validate: Godot not found at $GODOT (set GODOT=...)" >&2; exit 6; }

run_timeout() { local s="$1"; shift; perl -e 'alarm shift; exec @ARGV' "$s" "$@"; }

echo "== stage '$STAGE': assemble the stage tree ($ST)"
python3 -I "$HERE/stage.py" --repo "$REPO" --src "$SRC" --stage "$STAGE" --out "$ST" || exit $?

echo "== project copy for Godot ($PROJ): repo overlay + the stage tree on top"
mkdir -p "$PROJ"
FRESH=0
[ -d "$PROJ/.godot" ] || FRESH=1
rsync -a --delete --exclude '/.git' --exclude '/.godot' --exclude '/.playwright-mcp' --exclude '/.mimocode' --exclude '/tools' --exclude '/docs' --exclude '/legacy' --exclude '/tests' --exclude '/data/features' \
  --exclude '/project.godot.lock' "$REPO/" "$PROJ/"
rsync -a "$ST/lua/" "$PROJ/lua/"
rsync -a --exclude '*.translation' "$ST/localization/" "$PROJ/localization/"
# the stage tree overlay must not leave a stale file of a mutant behind: lua/ is the repo's plus the stage's (rsync above), nothing else
if [ "$FRESH" = 1 ]; then
  if [ -d "$REPO/.godot" ]; then cp -Rc "$REPO/.godot" "$PROJ/.godot"; else mkdir -p "$PROJ/.godot"; fi
fi
STAMP="$PROJ/.godot/validate_import.stamp"
NEWER=""
if [ -f "$STAMP" ]; then
  NEWER="$(find "$PROJ" \( -path "$PROJ/.godot" \) -prune -o -type f \( -name '*.gd' -o -name '*.gdshader' -o -name '*.import' -o -name 'project.godot' \) -newer "$STAMP" -print 2>/dev/null | head -1)"
fi
if [ ! -f "$STAMP" ] || [ -n "$NEWER" ] || [ ! -f "$PROJ/.godot/global_script_class_cache.cfg" ]; then
  mkdir -p "$WORK/home"
  PASSES=1; [ -f "$PROJ/.godot/global_script_class_cache.cfg" ] || PASSES=2
  for i in $(seq 1 $PASSES); do
    echo "== importing the project copy (pass $i of $PASSES)"
    HOME="$WORK/home" run_timeout 600 "$GODOT" --headless --path "$PROJ" --import > "$REP/import_$i.log" 2>&1 || { echo "run_validate: godot --import failed"; tail -20 "$REP/import_$i.log"; exit 4; }
  done
  touch "$STAMP"
fi

cd "$ST" || exit 3
FILES=$(find lua -name '*.lua' | sort | tr '\n' ' ')
echo "== real Lua 5.4: syntax + evaluation of $(echo $FILES | wc -w | tr -d ' ') stage files"
for f in $FILES; do luac5.4 -p "$f" || { echo "luac FAILED: $f"; exit 3; }; done
lua5.4 "$HERE/ser.lua" "$REP/lua_dump.json" $FILES || exit 3
(cd "$REPO" && lua5.4 "$HERE/ser.lua" "$REP/repo_lua_dump.json" $(find lua -name '*.lua' | sort)) || exit 3
lua5.4 "$HERE/ser.lua" "$REP/pending_lua_dump.json" $(find data/pending/lua -name '*.lua' | sort) || exit 3

echo "== project LuaRuntime (Godot headless, throwaway HOME)"
LIST=$(echo $FILES | tr ' ' ',')
CSVS=$(cd "$ST/localization" && ls *.csv | tr '\n' ',')
rm -rf "$WORK/home"; mkdir -p "$WORK/home"
rm -f "$REP/godot_dump.json"
HOME="$WORK/home" run_timeout 300 "$GODOT" --headless --path "$PROJ" -s "$HERE/validate_godot.gd" -- --out="$REP/godot_dump.json" --files="$LIST" --csvs="$CSVS" > "$REP/godot.log" 2>&1
tail -3 "$REP/godot.log"
rm -rf "$WORK/home"
[ -f "$REP/godot_dump.json" ] || { echo "run_validate: Godot produced no dump"; tail -30 "$REP/godot.log"; exit 4; }

echo "== python checks (stage $STAGE)"
"$ARTPY" -I "$HERE/validate.py" --features "$ST" --repo "$REPO" --stage "$STAGE" --lua-dump "$REP/lua_dump.json" --repo-lua-dump "$REP/repo_lua_dump.json" --pending-lua-dump "$REP/pending_lua_dump.json" \
  --godot-dump "$REP/godot_dump.json" --art-home "$REPO/tools/art/features/home" --art-wardrobe "$REPO/tools/art/features/wardrobe" --art-python "$ARTPY" --fonts "$REPO/assets/fonts" \
  --report "$REP/validation_report_$STAGE.txt"
RC=$?
[ "$KEEP" = 1 ] || rm -rf "$WORK/home"
exit $RC
