# Open questions - ghost family (Familien Natlys)

Only decisions that belong to the user. Each has a default; the design is complete and buildable with every default. (Pending reviews that are not decisions, such as the native read of the Danish copy, are in `CHANGELOG.md`.)

1. **Names.** The family *Natlys* (night light), Mormor Dyne (duvet), Far Gnist (spark), Mor Silke (silk), Lille Blund (a nap). None collides with an existing citizen, hero or key. Keep? *Default: keep.* A rename is one CSV column; the ids are `ghostfam_<name>`.
2. **The clock.** The brief says "06-26"; the game runs 06:00-24:00 and passes the player out at 24:00 (`lua/config/game_balance.lua:78-80`). Should the day be extended past midnight so the ghosts get a real night? *Default: no* (the family fits as evening and dawn people).
3. **Is the ghost player related to the family?** Now: a welcome new neighbour, and a Natlys at heart at 10 hearts. A cousin who arrives would need a story scene. *Default: no.*
4. **Hide and seek with Blund:** a pure routine (default) or a reward / counter for finding him (a counted version exists as a heart event in GF-events)? *Default: no reward in M1b.*
5. **Festivals:** should the ghosts ALWAYS attend the five Trætoppen light festivals (one `first` list in the festival file) and visit the four Hyggebyen ones (a guests field and a raised cap)? *Default: about 88 % attendance in Trætoppen, none in Hyggebyen; Gnist attends three of the five and keeps the shop at the other two.*
6. **The look of the six ghosts (Pedro, Hviske and the family).** Main's roster is now PAINTED with imagegen (`1ab4d2b`); the ghosts are 3D bakes with the storybook finish: closer than the first draft, still a different hand (rounder volume, larger dark eyes; see `proto/gamezoom_check_family.png`). Ship the finished 3D bake (*default*: ready now) or paint all six with your imagegen from `proto/prompts_ghosts.json` and the shape references (the painted route through `tools/art/drawn/pack.py` is wired and gated, but only you can generate the sheets)?


## ANSWERED by the user on 2026-10-14 (evening)

1. **Names: "keep".** Familien Natlys: Mormor Dyne, Far Gnist, Mor Silke, Lille Blund.
2. **The clock: "until 2 at night".** The game day runs 06:00 to 02:00 (hours 24 and 25 exist inside the same game day, shown 00:xx / 01:xx); the player passes out at 02:00. Designed in the clock addendum (CLOCK_26, when it lands).
3. **Is the ghost player related to the family: "yes".** A ghost hero (Pedro / Hviske) is a relative (cousin) of the Natlys family: story scene, lines and starting relationship in the family design update.
4. **Hide and seek with Blund: "yes" = a counted game with rewards.**
5. **Festivals: "yes"** = the ghosts always attend the five Trætoppen light festivals and visit the four Hyggebyen ones (ordering list + guests field + a raised cap).
6. **Look: "use the codex style".** The painted route: the six ghosts (and the other new characters) are drawn as imagegen turnaround sheets and packed with tools/art/drawn/pack.py like Codex's roster; the 3D bakes of milestone M1a stay as stand-ins and as shape / pose references until the painted sheets exist.
