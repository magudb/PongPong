# Developing Trætoppen

There is **one project**: this folder (`PongPong/`, git branch `main`). Everything else is a branch.

## Branches and worktrees

* `main` is always green: it imports with zero errors/warnings and `tests/run_playtest.sh --strict` passes for all three heroes.
  Nothing is committed to `main` directly except merges and small docs fixes.
* Work happens on a branch in its **own worktree**, a sibling folder `../PongPong-worktrees/<branch>/` (override with
  `TT_WORKTREES=DIR`). A worktree is a normal Godot project folder with its own `.godot` cache; history and objects are shared.

```sh
tools/dev/worktree.sh new wave-4           # branch + worktree from main, venv linked, import cache cloned, warm import done
tools/dev/worktree.sh list                 # every worktree: clean/dirty, branch, path
cd ../PongPong-worktrees/wave-4            # work, commit, run the tests here
tests/run_playtest.sh --strict             # headless harness (all sections), exit code 0 = green
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
`--character=animal|fairy|hobbit`, `--strict`. It imports the project first when needed. Windowed sections
(`run_windowed(t)` in a section) are run with `tools/dev/run_windowed.sh`; they open a real window for a few seconds.
`tools/dev/test_in_copy.sh NAME` runs the harness in an APFS clone, so a half-edited tree is never imported.

## Art

`tools/art/drawn/` packages the painted character and building sources into the shipped sprite sheets (see its README).
The other `tools/art/` bakers still supply floors, furniture, icons and source experiments. The Python environment is `tools/art/.venv`
(`tools/art/setup_env.sh`, Python 3.12); worktrees link to the main one. Baked output is committed under `assets/`; the
staging area `tools/art/_stage/` is not.

## Layout notes

* `legacy/` is an archive of the original package (3D models, old scenes, lossless PNG masters). Godot ignores it
  (`legacy/.gdignore`); nothing depends on it; see `legacy/README.md`.
* `docs/design/` holds the plan the game is built from; `docs/Trætoppen Style Guide Review/` is the UI/look reference.
* Commits: short imperative subject, a body that says what and why, and the `Co-Authored-By` trailer when an assistant wrote it.
  Large art is stored as plain git blobs (Git LFS is not enabled).
