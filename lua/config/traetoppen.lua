-- config/traetoppen.lua  (package V3-levels; moved here from V4 by plan review 27)
-- The numbers of the treetop city "Traetoppen" (design DUNGEON_V2_ADDENDUM 7.3, design_v2.md 4.5), read through
-- GameData.cfg("traetoppen.<key>") by the city map (V4), the city art (V5), the city life handlers (V6) and the quest layer (P13).
-- Those packages hand a change request to the owner of this file (V3's owner, the lead); they never edit it.
-- Top-level table of this file: traetoppen.  Geometry (levels, bridges, ladder, lift, buildings) lives in data/traetoppen/traetoppen.json.
-- Lua subset rules: literals only, `{}` is avoided for lists, world flags are ints.

kind = "config"

config = {
  traetoppen = {
    -- scale: world px per sketch px of Miljoeer v2 (ONE constant; the JSON header carries the same value and the section checks they agree)
    scale = 3.0,

    -- zoom: the camera range of the area (the whole composition fits at 0.237 wide / 0.19 high, so the minimum is 0.2)
    zoom = { default = 0.4, min = 0.2, max = 0.7 },

    -- post: Pip's morning letters (V6 PostBox2D); `givers` = the six everyday quest givers, per_day = letters per day
    post = {
      givers = { "mayor_lyra", "baker_maja", "merchant_pip", "farmer_rosa", "fairy_lily", "smith_thorin" },
      per_day = 1,
    },

    -- board: the Raadhus notice board lists up to `max` offerable quests of the same six givers, never the story quests
    board = {
      givers = { "mayor_lyra", "baker_maja", "merchant_pip", "farmer_rosa", "fairy_lily", "smith_thorin" },
      max = 5,
    },

    -- bath: Sofus's warm tub; the bath takes `minutes` game minutes, once per day, and restores energy and hearts
    bath = { minutes = 30, once_per_day = true },

    -- swap: Hoppe's seed basket; `give` is what the basket takes, `table` the rare seeds by weight (moonflower 3 : glow berry 2)
    swap = {
      give = { carrot = 2 },
      table = { moonflower_seeds = 3, glow_berry_seeds = 2 },
      once_per_day = true,
    },

    -- stall: Brumme sells at the Torvet stall on these weekdays (TimeManager.weekday_index, 0 = Monday: 5 = Saturday, 6 = Sunday)
    stall = { weekdays = { 5, 6 } },

    -- caches: Kiki's crown caches (monkey only): `slots` hidden spots, one cache per day, gold between `gold_min` and `gold_max` plus one small item
    caches = {
      slots = 5,
      gold_min = 20,
      gold_max = 50,
      items = { "wild_flower", "apple", "fern", "friendship_token" },
    },

    -- skovlift: the rope basket at the rim of tree B; the ride lasts `seconds`, the target is the forest hub (hand-authored by P11)
    skovlift = { to_area = "moerkeskoven", spawn = "from_traetoppen", seconds = 1.6 },

    -- fast_travel: used only by Rejsestolpen (V6, STRETCH). The rows stay as inert, labelled data when the stretch is cut: nothing else reads them.
    -- stops = signposts at the farm bridge end, the Torvet fire pit, the Hyggebyen gate and the top of the Skovlift; a stop unlocks on the first
    -- arrival there (world flag `flag`, int); `spawn` names a spawn of this area (data/traetoppen/traetoppen.json spawns).
    fast_travel = {
      stops = {
        { id = "farm", flag = "ft_farm", spawn = "from_farm" },
        { id = "torv", flag = "ft_torv", spawn = "default" },
        { id = "hyggebyen", flag = "ft_hyggebyen", spawn = "from_hyggebyen" },
        { id = "skovlift", flag = "ft_skovlift", spawn = "from_skovlift" },
      },
    },
  },
}
