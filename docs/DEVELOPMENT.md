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

**Timing budgets** (the policy in the header of `tests/lib/t.gd`; the `timing_lint` section runs `tests/tools/timing_lint.py`, which
fails on a raw wall-clock comparison and on a frame-count wait that ends in `t.fail()`):

* a wall-clock budget is a check of its own, `t.check(name, t.perf_ok(name, measured, reference), detail)`; the functional conditions
  around it are separate checks, so a failure names what broke;
* `measured` must survive a preemption: `t.median_usec(work, batches, per_batch)` for a per-call or per-frame cost, the best (minimum)
  of repeated builds or visits, a single sample only for a one-off cold cost;
* `reference` is the native budget, about 1.5-2x what a quiet machine measures. `TT_PERF_SCALE` (CI and the local gate set 4) lets a
  timing pass up to that multiple and lists everything over the reference as SLOW (summary, JSON report, GitHub notice): drift is
  reported, only a regression fails. A section whose own wall budget grows with it keeps its `TIMEOUT_S` above the scaled budget;
* a game-time scene (a festival opening, a dialogue that types, a tween) is waited for with `t.until_game(cond, game_seconds, each)`,
  never a frame count: an uncapped headless run draws thousands of frames per second, so 1500 frames took 0.2 s on a Mac, less than
  one camera move of the scene. A wall-clock comparison that is not a budget carries `# raw-time-ok: <reason>` on its line.

`tools/dev/selftest_harness.sh` is the harness's own test (negative tests: an injected error, an uncompilable section, a hang, `--fast`).

UI screens: every screen has a row in the UI audit's registry (`tests/lib/ui_screens.json`, plus one file per package in
`tests/lib/ui_screens.d/*.json` with the same row schema: the audit merges the folder, a screen id may exist only once; see the
header of `tests/sections/ui_audit.gd`).

## Art

`tools/art/drawn/` packages the painted character, building and outdoor terrain sources into the shipped atlases (see its README).
The other `tools/art/` bakers still supply floors, furniture, icons and source experiments. The Python environment is `tools/art/.venv`
(`tools/art/setup_env.sh`, Python 3.12); worktrees link to the main one. Baked output is committed under `assets/`; the
staging area `tools/art/_stage/` is not.

## Layout notes

* `legacy/` is an archive of the original package (3D models, old scenes, lossless PNG masters). Godot ignores it
  (`legacy/.gdignore`); nothing depends on it; see `legacy/README.md`.
* `docs/design/` holds the plan the game is built from; `docs/Trætoppen Style Guide Review/` is the UI/look reference.
* Commits: short imperative subject, a body that says what and why, and the `Co-Authored-By` trailer when an assistant wrote it.
  Large art is stored as plain git blobs (Git LFS is not enabled).
