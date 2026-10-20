# Developing Trætoppen

There is **one project**: this folder (`PongPong/`, git branch `main`). Everything else is a branch.

## Branches and worktrees

* `main` is always green: it imports with zero errors/warnings and the complete strict CI matrix passes for all four heroes
  (`--character=animal|fairy|hobbit|ghost`).
  Nothing is committed to `main` directly except merges and small docs fixes.
* Work happens on a branch in its **own worktree**, a sibling folder `../PongPong-worktrees/<branch>/` (override with
  `TT_WORKTREES=DIR`). A worktree is a normal Godot project folder with its own `.godot` cache; history and objects are shared.

```sh
tools/dev/worktree.sh new wave-4           # branch + worktree from main, venv linked, import cache cloned, warm import done
tools/dev/worktree.sh list                 # every worktree: clean/dirty, branch, path
cd ../PongPong-worktrees/wave-4            # work, commit, run the tests here
tests/run_playtest.sh --strict             # headless harness (all sections), exit code 0 = green
tests/run_playtest.sh --fast --only=area   # the same, with physics and frames running ahead of the wall clock (see Tests)
tools/dev/run_windowed.sh --only=area      # real 1280x720 window sections (one window at a time)
# when the branch is done and green, from THIS folder (main):
git merge --no-ff wave-4 && tools/dev/worktree.sh remove wave-4 --delete-branch
```

Rules of thumb: one Godot instance per worktree at a time (the editor and a headless run both write `.godot` and the
`.uid`/`.import` files); never edit a worktree from two places; `git worktree list` shows what exists; if a folder was
moved by hand run `git worktree repair`. Saves live in Godot's `user://` of the project name, which all worktrees share:
play-test with a throwaway profile (the harness does this automatically).

## Trying the game by hand

`tools/dev/play.sh` opens the game in a 1280x720 window (add `--throwaway` for a temporary profile). Controls today: WASD or arrows move,
Shift runs, E interacts, mouse wheel zooms, Esc pauses, Space jumps (F toggles flight for the fairy). Until the playable waves land the
world is a test platform (title -> New game -> pick a hero -> a floating farm island with a stub player). Close the Godot editor first.

## Tests

`tests/run_playtest.sh` is the harness (see its header): headless sections in `tests/sections/`, `--only=a,b`,
`--character=animal|fairy|hobbit|ghost`, `--strict`. It imports the project first when needed. Windowed sections
(`run_windowed(t)` in a section) are run with `tools/dev/run_windowed.sh`; they open a real window for a few seconds.
`tools/dev/test_in_copy.sh NAME` runs the harness in an APFS clone, so a half-edited tree is never imported.

**`--fast`** makes a headless run cheap in wall time: the wrapper passes `--fixed-fps 60` to Godot (it is the same as
`GODOT_EXTRA_ARGS="--fixed-fps 60"`, which the wrapper forwards to the engine in any case). Without it the engine paces every
physics tick and frame by the wall clock, so a test that walks for 5.3 game seconds with real key events costs 3-5 s; with it the
same walk costs about 0.05 s, because the frames run back to back and every frame still advances game time by 1/60 s.
`Engine.time_scale` is not a substitute: physics ticks stay real-time. Things to know:

* sections see game time, not wall time: use `t.physics(n)` / `t.seconds(s)` (game time) for anything the game animates, measure a
  duration with `t.game_seconds()` (never `Time.get_ticks_msec()`, which stays behind), and wait on the wall clock
  (`t.until(cond, timeout)`) only for things outside the engine loop (a thread, a child process);
* the harness watchdogs (`TIMEOUT_S` of a section, `--section-timeout=`, `--max-seconds=`) count wall-clock seconds in both modes;
* `--fast` is ignored by a windowed run (a real window is watched in real time), and an own `--fixed-fps` in `GODOT_EXTRA_ARGS` is kept;
* Ordinary gameplay sections run with normal pacing in CI. The two seeded Monte Carlo sections, `combat_acceptance` and `dungeon_fights`, run with `--fast`: they measure physics-derived game time and simulate more than an hour of play per character. Their full sample counts and game-time assertions stay enabled. The ordinary harness costs about the same
  with it (most of its time is child processes and imports), and a section that times an animation with the wall clock fails under it
  (measured when the flag was added: `city_levels.monkey_climbs_faster` and `city_levels.lift_requests_area_change` read 0.01 s for 1.1 s).

`tools/dev/selftest_harness.sh` is the harness's own test (negative tests: an injected error, an uncompilable section, a hang, `--fast`).

UI screens: every screen has a row in the UI audit's registry (`tests/lib/ui_screens.json`, plus one file per package in
`tests/lib/ui_screens.d/*.json` with the same row schema: the audit merges the folder, a screen id may exist only once; see the
header of `tests/sections/ui_audit.gd`).

## Art

`tools/art/drawn/` packages the painted character, building and outdoor terrain sources into the shipped atlases (see its README).
The other `tools/art/` bakers still supply floors, furniture, icons and source experiments. The Python environment is `tools/art/.venv`
(`tools/art/setup_env.sh`, Python 3.12); worktrees link to the main one. Baked output is committed under `assets/`; the
staging area `tools/art/_stage/` is not.

## Repository size

The repo is 2.4 GB packed, about 1.6 GB of it QA screenshots, review sheets and source paintings (REPO-01). The
history stays as it is until the migration below; these rules stop the growth.

* **Size guard.** `tools/ci/size_guard.py` measures every blob a commit adds or changes; CI runs it on each push and pull
  request (`.github/workflows/repo.yml`, a blobless checkout of a few MB). A plain blob may be at most 1 MiB unless a
  line of `tools/ci/size_allowlist.txt` gives its path more (shipped `assets/` 8 MiB, UI baselines and the style-audit
  ledger 4 MiB). Files committed before the guard are only measured once they change. Raise a limit in the same commit
  that needs it and say why. `tools/dev/install_hooks.sh` installs an optional pre-commit hook with the same check on
  the staged files (`--remove` takes it out again; `git commit --no-verify` skips it once).
* **Git LFS for new media.** The root `.gitattributes` stores new images, audio, video and archives under `docs/` and
  `tools/art/` in Git LFS. Both trees have a `.gdignore`, so Godot never imports a pointer; `assets/` stays plain (the
  game imports it) and so do `docs/qa/ui_baseline/*.png` (the UI sections read and re-record them). Files that existed
  before are grandfathered as plain blobs, one line each, in `docs/.gitattributes` and `tools/art/.gitattributes`: never
  add a line there. A commit made without git-lfs stores a plain blob on an LFS path, which the guard rejects, so run
  `brew install git-lfs && git lfs install` once before committing media there. To move one grandfathered file into
  LFS, delete its line and `git rm --cached <file> && git add <file>`.
* **Not in git at all:** raw QA screenshot runs and long run logs. Keep them as CI artifacts or locally and commit a
  summary and a few small crops.
* **CI.** The playtest jobs pull the LFS files that tests can read (art review sheets, source paintings) from a cache keyed
  by object id, skipping `docs/qa` and `docs/review`, which no test reads. The export jobs need none: gdignored trees are
  never exported. With no LFS file in the tree (today) these steps are skipped.

### Planned history migration (lead, separately)

Only a history rewrite shrinks the clone. Do it in one window, with every branch merged or parked:

1. **Paths:** all media under `docs/` except `docs/qa/ui_baseline/` (about 1.2 GB packed: `docs/qa` 0.92 GB,
   `docs/art` 0.23 GB) and under `tools/art/` (about 0.38 GB, nearly all `tools/art/drawn/sources`); optionally
   `legacy/` (0.09 GB; or tag it `legacy-archive` and delete it from `main`, which does not shrink the history).
   `assets/` (about 0.5 GB) stays plain.
2. **Expected size:** about 1.6 GB moves to LFS storage (check the account's LFS storage and bandwidth quota first);
   the git pack drops from 2.4 GB to about 0.7 GB, and a playtest checkout to about that plus the cached LFS files.
3. **Steps,** in a fresh `git clone --mirror` with git-lfs 3.x and git-filter-repo: drop the grandfather lists from all
   history first (`git filter-repo --invert-paths --path docs/.gitattributes --path tools/art/.gitattributes`; left in,
   they would mark the converted files plain and checkouts would show pointer text), then
   `git lfs migrate import --everything --include="docs/**/*.png,...,tools/art/**/*.png,..." --exclude="docs/qa/ui_baseline/**"`
   with the extensions of the root `.gitattributes`. Verify with `git lfs fsck`, `python3 tools/ci/size_guard.py --audit`
   and a full strict gate on a clone of the result.
4. **Consequences:** every commit and tag gets a new SHA, so `main` and the release tags (`v0.1.0`, `v0.2.0`) are force
   pushed, and their provenance attestations name commits that are no longer on `main` (the released files stay
   byte-identical). Every clone, worktree and open branch must be re-cloned or re-created; old branches cannot be merged
   afterwards. GitHub keeps the old objects reachable through pull request refs until support runs a GC. On the push
   that replaced history the repo workflow checks only the newest commit. Afterwards every clone that touches art or
   QA media needs git-lfs.

## Layout notes

* `legacy/` is an archive of the original package (3D models, old scenes, lossless PNG masters). Godot ignores it
  (`legacy/.gdignore`); nothing depends on it; see `legacy/README.md`.
* `docs/design/` holds the plan the game is built from; `docs/Trætoppen Style Guide Review/` is the UI/look reference.
* Commits: short imperative subject, a body that says what and why, and the `Co-Authored-By` trailer when an assistant wrote it.
  New media under `docs/` and `tools/art/` goes through Git LFS; see Repository size.
