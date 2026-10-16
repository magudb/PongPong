-- config/farm_site.lua  (N02 production data)
-- The treetop farm "Min Traekronsgaard" as DATA: the five stages of the estate, the expansion price table, the shipping bin rules and the
-- particle budgets. The map (data/maps/farm.map) carries the geometry; the numbers that designers tune live here.
-- Lua subset: literals only, no arithmetic; lists are { a, b }.
kind = "config"

config = {
  farm_site = {
    -- Reserved cells use the final map's south-east anchor convention.
    slot_footprints = { coop = { 3, 2 }, barn = { 4, 3 }, house = { 3, 2 }, greenhouse = { 4, 3 } },
    -- stage = f(home tier); `rows` = IsoArea.set_growth_stage(rows) (assets/iso_props/home/home.json platform.back_rows). The dress markers of the map
    -- (tier=N) switch on at the first tier of a stage that has them.
    stages = {
      { id = "spiren", name_key = "FARMSITE_STAGE_1", tiers = { 1, 2 }, rows = 0 },
      { id = "kvisten", name_key = "FARMSITE_STAGE_2", tiers = { 3, 4 }, rows = 0 },
      { id = "grenen", name_key = "FARMSITE_STAGE_3", tiers = { 5, 6, 7 }, rows = 1 },
      { id = "kronen", name_key = "FARMSITE_STAGE_4", tiers = { 8, 9 }, rows = 2 },
      { id = "slottet", name_key = "FARMSITE_STAGE_5", tiers = { 10 }, rows = 3 },
    },
    -- field expansion zones: the PRICE is the one in the map marker (`field_expansion id=east ... price=800`); this table is what the validator
    -- cross-checks (farm_site.expansion_price_matches_map) and what the HUD / journal read for their texts
    expansions = {
      east = { price = 800, cells = 42, name_key = "FARMSITE_ZONE_EAST" },
    },
    -- the shipping bin: crops, products and forage go in; the gold arrives the next morning
    bin = {
      pay_ratio = 1.0,
      categories = { "crop", "product", "forage" },
      morning_toast = true,
    },
    -- ambient particles of the farm (CPUParticles2D, on CanvasLayers below the weather overlay): hard caps of live particles
    fx = {
      leaves_max = 16,
      petals_max = 20,
      snow_max = 40,
      fireflies_max = 14,
      canopy_frame = true,
    },
    -- the lights budget of the map (PointLight2D: lantern_post props + `light` markers); the engine caps 16 per canvas item
    lights_max = 12,
  },
}
