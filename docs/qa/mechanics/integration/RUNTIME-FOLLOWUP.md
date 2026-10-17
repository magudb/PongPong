# Integrated runtime follow-up

1,234 checks across city map/levels, dungeon HUD/run, content features, contracts, localization, NPCs, town budgets and routine validation: zero failures/skips or engine errors/warnings. Five explicitly expected localization negative-fixture messages are recorded.

The dungeon run controller now belongs to the world. Its attachment facade resolves the world ancestor, so the HUD and GameUI obtain the same owner; isolated preview screens create no gameplay observer. The previous parent-local attachment allowed two controllers to apply one surprise twice. The regression verifies exactly one oil, heart and gold payout and identical ownership from both UI levels.

Routine batches share the registry and day boundary, and matching scalar/list filters avoid temporary arrays. Batch answers equal individual queries without mutating the caller's context. The isolated warm 34-citizen sweep measured 295 microseconds against the existing 300-microsecond target; the earlier uncached sweep measured 384–388. This narrow margin is a local observation, not a low-end-machine guarantee. The existing seven-day/weather and mutation checks pass.

City budgeting now records total and scenery nodes separately, as interior/lighting budgets already do: 738 total = 666 scenery + 72 character nodes at the measured population. Scenery remains below 700, with twelve scenery lights; ordinary visual population and director limits remain separate checks. The city lighting fixture also counts Silke's one optional light separately from fixed scenery while retaining the sixteen visible-light ceiling. No painted asset, character overlay or light was removed to change the count.

Other fixture repairs count the starter weapon in its actual equipment store, allow zero capability skips when all packages exist, and complete the home-amenities localization ownership row. Content validation now recognises real dungeon items and item requirements and uses the two static marker areas. The town-loop building-panel cleanup and non-festival Sunday selection are pending the town-loop consumer pass; they are not covered by this report.
