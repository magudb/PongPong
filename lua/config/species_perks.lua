-- config/species_perks.lua
-- The SPECIES layer of the perks (package V1-cast-data, Style Guide v2): per-SKIN overrides of the race perks of
-- lua/config/race_perks.lua.  Top-level table of this file: species_perks.
--
-- One table per SKIN id (lua/config/characters.lua).  A key a skin does not list FALLS THROUGH to race_perks.<race>.<key> of the
-- skin's race, and a key that neither lists falls through to the default the caller passes.  Nobody reads this table directly: the
-- ONLY place the species layer is resolved is the static class SpeciesPerks (scripts/data/species_perks.gd):
--   SpeciesPerks.value(skin, key, default)   the value for one skin (the ladder above)
--   SpeciesPerks.current(key, default)       the same for GameManager.character_skin (what Player2D, V3's ClimbLane, V6's CrownCache call)
--
-- Keys used so far (a skin may override any key of race_perks, the rest are new species-only keys):
--   dig_speed tool_cost_mult harvest_bonus_chance   the three race perks of the animal card
--   climb_speed_mult   ladder and trunk climbs take 1/this of their time (the monkey 2.2: the ladder 1.1 s -> 0.5 s)
--   chest_sense_px     hidden chests glint from this many ground px in the dungeon (700 = 7 cells, one lantern radius plus margin)
--   crown_caches       true = the city's hidden crown caches show for this skin (one cache a day in Traetoppen)
--
-- Rasmus (animal_fox) is the race baseline: he lists nothing, so he gets dig 1.3, tool cost 0.75 and harvest +20% exactly as
-- CHAR_ANIMAL_PERK promises.  Every other hero lists nothing either.  The ghost's perk layer is race_perks.ghost (the fall-through).

kind = "config"

config = {
  species_perks = {
    -- Kiki the monkey: no race perk of the fox (her own perks are the climb, the chest sense and the crown caches).
    animal_monkey = {
      dig_speed = 1.0,
      tool_cost_mult = 0.9,
      harvest_bonus_chance = 0.0,
      climb_speed_mult = 2.2,
      chest_sense_px = 700,
      crown_caches = true,
    },
    animal_fox = {},
    fairy_meadow = {},
    fairy_birk = {},
    hobbit_pip = {},
    hobbit_bodil = {},
  },
}
