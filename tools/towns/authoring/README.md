# Town routine authoring

The hand-owned Lua routines, installed room JSON and town sidecar are the runtime truth. These Python files preserve the original authoring model for comparison and future additions. They write into this directory; review and validate an output before copying it into the runtime tree. They never generate art.

Use `tools/towns/bake_routes.sh` after changing maps, room footprints, dressing, the city sidecar or navigation code. It runs through the isolated playtest profile and records input hashes in `data/towns/routes.json`; stale inputs fail `towns_routes`.

The current planner uses `LevelRegistry.levels_graph()` and the actual room colliders. It includes polygon holes and correct diagonal walking lengths. The old circular sketch approximation is not used. `LevelNav.snap()` reports positions inside keepouts; the live town director must use the resolved positions and review large shifts against the painted scene.

The original timetable needed three adjustments for the measured routes. Postbud Pip has a courier pace of 1.6 times the town walking pace and a 07:10 mailbox appointment, keeping him at the post counter before its 09:00 opening. Hoppe leaves for the Wednesday farm visit fifteen minutes earlier and keeps a six-minute margin on the return. Rosa keeps a six-minute margin after the seed-shop errand. These values live in the Lua routines; the compiler uses the same pace for normal and festival travel. Keep the authored Python model in sync before regenerating routines.

The day axis is 06:00 to 02:00 (raw 6 to 26). Raw 24 and 25 are part of the same game date. A resumed raw hour below 6 resolves to the final overnight state. Missing house rooms degrade to their outdoor doors; optional visits disappear until their room is installed.
