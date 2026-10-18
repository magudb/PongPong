# Diagnostic evidence

These reports are partial runs, failure probes and superseded complete runs used while developing the long journey and its movement controller. They are not the final fresh-save acceptance results.

`ghost-route.json` and its native captures reproduce a walker sidestep into a bridge rail, followed by a successful real-input replan to the garden. `ghost-route-fixed.json` verifies the corrected centre-line controller on the same earned checkpoint. `route_probe.gd.txt` retains the replay source; it is not an installed test section. The other early reports include intermediate controller and fixture failures.

`pond-route-before.*` records repeated backwards dodges with no swings; `crowded-route-fixed.json` completes the earned-save continuation after choosing the dodge side along the route and replanning crowded walks. `iva-replay.json` records an E press that did not start the intended encounter; `iva-replay-fixed.json` waits for actions/movement to settle, confirms the opened encounter and completes the earned-save continuation. Neither repair changes the game or grants progression.

The parent directory's `fresh-animal.json` and `fresh-ghost.json`, each ending in a `verified_fresh_journey` trace event, are the uninterrupted acceptance runs. The separate before-defect reports in that directory document the actual gameplay bugs.
