Boardwalk and climb transitions — 2026-10-16

Implemented on codex-walkway-transitions from main 7ad11d6.
Source commits: 9ccf4ee (movement/pose/lifecycle) and d5bd13f (landing stride).
Merged main b8c78e4 passes 312 strict transition/loop/budget checks with zero
failures and unexpected engine messages. All 1,163 bound inputs match the
worktree; current extension/mutant proofs, style and imports pass on main.
merge-verification.json records finished-branch ancestry and exact scope.

The shipped vertical connector is the painted ladder between torvet and upper.
The same ClimbLane controller also handles Kiki's perk-only trunk connector.
The horizontal boardwalk network has nine bridges and eighteen platform joins.

The player now walks from the interaction point to the ladder entrance using
physics and collision, keeps the current deck's collision/draw level on that
approach, and switches levels at the climb and landing. The walk loop actually
runs while normal player input is locked. Facing and animation stride survive
the landing, so held input continues without a turn or a one-frame idle reset.
Blocked approaches cancel; reparenting/area changes cancel the tween and restore
the actor immediately. Explicitly forced prior clips are restored after end_talk.
The existing 1.1-second climb and Kiki's 2.2x multiplier remain; the short walk
to the entrance adds its actual movement time. No asset, layout or railing edit.

Coverage

- Each race report has 153 strict checks, zero failures/skips/engine messages.
  All eighteen joins are crossed in both directions at three lateral offsets:
  108 physical crossings per race. Both climb directions are exercised with
  the default skin and its alternate, covering all eight playable heroes,
  including Kiki's real speed perk. Also checks blocked entry and cancellation.
- regression.json: 313 checks across walkway_transitions, city_levels, city_map
  and player. Zero failures/engine messages; three named later-feature skips.
- native-transitions.json: 59 checks with real render/physics timing. Thirty-six
  centerline crossings, both climb directions, animation and held-input landing.
  Screenshot readback can advance physics, so exact landing checks snapshot
  the climbed signal, before held input moves the actor onwards.
- native-city-tour.json: 64 checks including the complete city_map physical tour
  with all nine bridges and ten landmarks. Uses the movement implementation
  in 9ccf4ee with an earlier capture fixture; the final native run additionally
  covers recording and the clip-only stride correction.
- before-control.json/log intentionally FAIL: the same 149-check pre-stride
  fixture against ClimbLane from 7ad11d6 produces twenty behavioral failures,
  zero engine messages. It reproduces entry snaps, frozen animation, facing,
  blocked-entry and cancellation defects. It is a negative control, not an
  unresolved failure. The final fixture adds four landing-stride checks.
- NPC collisions are disabled only in the dedicated join fixture to isolate
  authored seams. The existing city tour and TownLoop use production crowds.
  A platform-bound seam probe stops after stable level handover: several huts
  stand just beyond a join; city_map covers the onward turns around them.

Town safety and performance

TownLoop/budgets and all wave-5b gates pass with extension and seven producer
mutant proofs renewed against the final source/data/test binding. The original
M1b proof files were archived at ../m1b-milestone/source-proof-75a4d779/ and its
acceptance.json now points there. Current root proofs are live gate inputs.
The historical full 44,779-check milestone run was not repeated or relabelled.
One final run narrowly missed the unchanged where_is_sweep benchmark at 305us
against 300us after the proof runs. The identical isolated run passes at 267us;
both reports/logs are retained. No test threshold was changed or waived.

The native town run at source 9ccf4ee passes 177 checks with zero engine messages.
Twelve named capability skips cover later features. Apple M3, macOS, Godot4.7.2,
Compatibility GL4.1/Metal90.5: loop 106.452s <=110s, save p95 14.840ms <=25ms,
city crowd 247 draw calls <=250, mean frame 2.381ms <=6ms, 280.65MB for sixteen
warmed looks, 316.652MB for twenty festival looks, cold twelve-citizen travel
566.964ms. These are source-project native measurements, not packaged exports.
The subsequent correction only retains the walk loop for the landing frame;
final native transition and headless town checks cover that correction.

Visual evidence

native/ holds ascending/descending GIF previews, timestamped frame contacts,
all eighteen join close-ups in both directions, six original 1280x720 PNGs,
original timeline JSONs and a SHA-256 manifest of all 63 capture files.
GIFs are sampled, resized, palette-limited previews. Contacts cover sixteen
sampled climb frames, not every frame. The manifest names the reviewed images.
All 2,562 visual/theme assets still match the explicit style approval ledger;
import settings also pass. No new asset-generation prompt was needed.

Reproduce from the repository root, one Godot process at a time

  for hero in animal fairy hobbit ghost; do
    tests/run_playtest.sh --fast --strict --no-boot --character="$hero" --only=walkway_transitions
  done
  tests/run_playtest.sh --fast --strict --no-boot --only=walkway_transitions,city_levels,city_map,player
  tools/dev/run_windowed.sh --strict --no-boot --only=walkway_transitions --out=.godot/qa/walkway-native
  python3 tools/town/prove_extension.py
  python3 tools/town/prove_mutants.py
  TOWN_LOOP_WAVE=5b tests/run_playtest.sh --fast --strict --no-boot --only=town_loop,town_budgets
  TOWN_LOOP_WAVE=5b tools/dev/run_windowed.sh --strict --no-boot --only=town_loop,town_budgets
  tools/art/.venv/bin/python tools/art/drawn/style_audit_current.py --check
  python3 tools/import/write_import_stubs.py --check

Reports, raw logs and acceptance.json retain exact check counts and source scope.
