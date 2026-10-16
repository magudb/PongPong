# Natlys family data

M1b includes four residents, their schedules, cousin scenes, social copy and
tastes, the guest room and the 17:00–01:00 lantern shop (closed Wednesday).
The counted hide-and-seek game, special glow and festival scenes belong to M3;
the hook dispatches to those consumers when installed. Silke's clues and Blund's
two daily hiding posts are ordinary M1b dialogue/routine data.

The runtime Lua/room drafts come from design6/FINAL/family. Their integration
uses the current schema: integer cells, a staff table post, item notes at room
level, a default Sunday plan and the resident/customer distinction in hours
validation. The real route bake supplies distances. Silke has speed_mult = 1.10
to retain her 22:55/01:45 pins with a 40% walking-time margin on those real routes.

`prepare_copy.py --write` regenerates 168 draft rows from the authored source.
It separates six topic questions/answers, shortens five English voice hooks,
a bark and the English story popup to their shipped UI contracts. The source
rows and authored original copy are retained under authoring/.
`check_copy.py` checks tone without an allow-list, ungendered cousin/child copy,
3–5-word barks, popup length and literal dialogue keys. Normal copy/loc/voice
validators apply too. No recordings have been generated or changed.

`tests/sections/ghostfam_data.gd` exercises data, real Lua branches, all eight
hero contexts, raw-hour night presence, the 40% route margin, actual cousin
conversations/rewards, unique gathering positions, clues and optional hooks.
The regular towns routes/routines/rooms/director and social/cast checks run
against the expanded 34-citizen/15-room data as well.
