Town integration tools
======================

Run from the repository root. The canonical playable loop is
`tests/sections/town_loop.gd`; `town_budgets` measures the installed areas.
Use `tests/run_playtest.sh --strict --no-boot --only=town_loop,town_budgets`.
The four supported characters are animal, fairy, hobbit and ghost.
`GODOT_EXTRA_ARGS='--fixed-fps 60'` accelerates headless time. Normal-speed
physics remains a separate gate. Native captures use `tools/dev/run_windowed.sh`.

Before the final `TOWN_LOOP_WAVE=5b` gate, run these sequentially:

    python3 tools/town/prove_extension.py
    python3 tools/town/prove_mutants.py

Both tools use disposable COW project copies and throwaway save profiles.
They never edit the working checkout. The extension installs one complete
citizen/building/shop/routine/festival/event/mail-quest data change and reruns
the owning town/social checks plus real door, talk, shop and mailbox consumers.
The mutation proof first runs a clean baseline, then changes seven producers
on separate clones. Each must fail its specific behavioural check without an
engine error. Audio's eighth mutant waits explicitly for P24's cue_log hook.
Their saved reports bind all first-party source/data/tests/tools inputs.
A source change makes a proof stale; rerun both once implementation is stable.
Clone/import/bake setup is authoring validation outside the playable timer.

`loop_report.py LOG --wave 5b --out REPORT` turns named check output into a
required/ran/skipped-with-reason/failed table for every wave. Missing required
legs produce a nonzero exit. Wave 6 audio and wave 7 capabilities remain later
work. The 5b table must be green for M1b. Later X01–X09 scenes remain explicit
capability skips; installing their producer fails closed until the matching
loop consumer exists.

`audit_copy.py` checks nonlegacy copy, complete citizens, frozen voiced Danish
hashes and measured font boxes. The voice index is checked separately; draft
hooks are indexed but no recordings are invented.

Use `tools/art/.venv/bin/python tools/town/vram_budget.py` for Pillow-dependent
texture arithmetic. `--paths paths.json` measures an explicit residency set.
The farm kit includes props plus its far, canopy and sky; every imported mip
and S3TC block counts. Historic plan envelopes remain labelled reference rows.
Native `town_budgets` separately compares the actual renderer allocation delta
against newly resident paths (5% tolerance), and measures 20 warmed looks.
That row does not claim to be the later I6 twenty-actor performance scene.

`check_native.py --shots DIR` retains full captures and unmasked scores, then
scores the immutable UI guides. The mask coordinates exclude only superseded
portrait placeholder interiors, hotbar item pictures, and live money digits/energy
fill from chrome comparisons. The matching-content HUD fixture separately
scores the full chip without those masks.
The live-room blur proof uses paired real screenshots, excludes foreground
speech/portrait/panel, and uses normalised Gaussian convolution so those UI
colours cannot leak into background statistics. Budgets remain <=12/255 low
frequency difference and <=0.6 high-frequency energy ratio. Fourteen CORE
captures include the calendar; S14's actual festival scene is explicitly later.
All final captures require visual inspection as well as numeric checks.

Draw-call scope: the original room and farm numbers describe standalone area
prototypes. Native reports retain both area-only calls and the presented screen
including the shared HUD (72–80 calls). Their named area draw gates use the
prototype scope; frame-time gates always measure the full presented screen.
The city additionally retains the stricter full-screen 250-call gate.

The grid's original 4 ms / 94-call row used a small standalone prototype.
The completed painted Hyggebyen keeps the 4 ms frame limit including
the shared HUD. Its area-only timing is retained as an additional diagnostic.
Room/city/farm presented limits remain 4/6/8 ms. Every sampled window is saved.

The painted farm compression check resolves the effective runtime WEBPs.
It retains full-resolution source/import errors and side-by-side crops, then
scores the composited image at the maximum shipped farm zoom (.7). Its reviewed
painted baseline is <=4/255 mean RGB error for large textures and <=7/255 for
small props, with a damaged-texture negative control. The former CG reference
limits were 3/6. Source illustrations, mipmaps and S3TC settings are unchanged;
fine paint grain softens slightly while outlines and colour remain intact.

Staging covers the atlases used by the actual map, automatic bridges, quest
props and ambient owl sheets as well as scenery and scheduled citizens.
Native coverage reads the installed tile sources and owl sprites, checks their
paths against the completed requests and rejects a missing-resource control.
Whole cold transitions remain bounded separately from area construction.

The harness restores the CLI character before each section; sections can still
exercise several characters locally. Each section records its starting choice,
and L00 verifies the actual playable race and default skin. Room fixtures restore
the registry entries they temporarily replace, so later consumers must still
travel into real rooms and meet the live keepers.

The city nav cache verifies geometry and its source algorithm hash. Compiled
exports without raw scripts use the original live bake fallback. These gates
cover source/native project runs; packaged-export timing is not claimed.
