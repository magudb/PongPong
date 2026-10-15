-- config/characters.lua
-- Who looks like what (DATA, package P05). Game code asks this table (CharacterCatalog in
-- scripts/isometric/character_catalog.gd, IsoChibiSprite2D.create) and never names a stand-in itself.
--
-- A character id is the folder name under assets/isometric_characters/<id>/ (it exists when animations.json does).
-- `fallbacks` says which id draws instead while an id has no art yet: the chain is followed until a folder exists, so
-- when the real art lands (P21 hobbits, squirrel, NPCs, animals, forest creatures; A2 wardrobe bases) the first id of
-- the chain simply starts to win - no code change. Every chain ends at one of the 12 pack characters
-- (bat cat bear rabbit fairy monkey capybara fox raccoon penguin hedgehog frog).
-- Role and clip sets live in each animations.json, not here.
-- ONE source of truth for stand-ins: the per-NPC `fallback` field of lua/config/npcs.lua is documentation only and must
-- equal the entry of that NPC's visual in `fallbacks` below (tests/sections/characters.gd npc_fallbacks_match_characters_lua).
--
-- v2 (package V1-cast-data, Style Guide v2 "Figurer"): the player chooses between HEROES, two per race (table `heroes`);
-- the cards are LOOKS, the player still types a name. The ghost (the fourth race) has its two heroes at the end of the table.
-- The seven skins of the first guide (animal_rabbit animal_hedgehog animal_squirrel fairy_stardust fairy_dusk hobbit_moss
-- hobbit_bramble) are RETIRED: they stay as rows (`retired = true`) because old saves and built tests name them, but no screen
-- offers them and no wardrobe base is baked for them (their wardrobe_body points at a live hero body).

kind = "config"

config = {
  characters = {

    -- The four races of "Vaelg figur". default_skin is what a new game of that race starts with;
    -- name_key / perk_key are the texts of the race card (localization CSVs).
    races = {
      animal = { name_key = "CHAR_ANIMAL_NAME", perk_key = "CHAR_ANIMAL_PERK", default_skin = "animal_fox" },
      fairy = { name_key = "CHAR_FAIRY_NAME", perk_key = "CHAR_FAIRY_PERK", default_skin = "fairy_meadow" },
      hobbit = { name_key = "CHAR_HOBBIT_NAME", perk_key = "CHAR_HOBBIT_PERK", default_skin = "hobbit_pip" },
      ghost = { name_key = "CHAR_GHOST_NAME", perk_key = "CHAR_GHOST_PERK", default_skin = "ghost_bu" },
    },

    -- Player skins. visual = the id the player body asks for first = the wardrobe-ready base (A2, naked body that
    -- WardrobeLayers dresses); the chain behind it (fallbacks) is e.g. monkey_base -> monkey. A skin whose own art is not
    -- baked yet simply draws through its chain (Bodil: hobbit_bodil_base -> hobbit_pip -> raccoon).
    -- fallback = the pack character that stands in at the END of the chain. wardrobe_body = the bodies.json hero id.
    -- retired = true: kept for old saves and tests, never offered (see the header).
    skins = {
      animal_fox = { race = "animal", name_key = "SPECIES_FOX", visual = "fox_base", fallback = "fox", wardrobe_body = "fox" },
      animal_monkey = { race = "animal", name_key = "HERO_KIKI_NAME", visual = "monkey_base", fallback = "monkey", wardrobe_body = "monkey" },
      fairy_meadow = { race = "fairy", name_key = "SKIN_FAIRY_MEADOW", visual = "fairy_base", fallback = "fairy", wardrobe_body = "fairy" },
      fairy_birk = { race = "fairy", name_key = "HERO_BIRK_NAME", visual = "fairy_birk_base", fallback = "fairy", wardrobe_body = "fairy_birk" },
      hobbit_pip = { race = "hobbit", name_key = "SKIN_HOBBIT_PIP", visual = "hobbit_pip_base", fallback = "raccoon", wardrobe_body = "hobbit_pip" },
      hobbit_bodil = { race = "hobbit", name_key = "HERO_BODIL_NAME", visual = "hobbit_bodil_base", fallback = "raccoon", wardrobe_body = "hobbit_bodil" },
      ghost_bu = { race = "ghost", name_key = "SKIN_GHOST_BU", visual = "ghost_bu_base", fallback = "rabbit", wardrobe_body = "ghost_bu" },
      ghost_hviske = { race = "ghost", name_key = "SKIN_GHOST_HVISKE", visual = "ghost_hviske_base", fallback = "rabbit", wardrobe_body = "ghost_hviske" },

      -- retired (the looks of the first guide)
      animal_rabbit = { race = "animal", name_key = "SPECIES_RABBIT", visual = "rabbit_base", fallback = "rabbit", wardrobe_body = "fox", retired = true },
      animal_hedgehog = { race = "animal", name_key = "SPECIES_HEDGEHOG", visual = "hedgehog_base", fallback = "hedgehog", wardrobe_body = "fox", retired = true },
      animal_squirrel = { race = "animal", name_key = "SPECIES_SQUIRREL", visual = "squirrel_base", fallback = "monkey", wardrobe_body = "monkey", retired = true },
      fairy_stardust = { race = "fairy", name_key = "SKIN_FAIRY_STARDUST", visual = "fairy_stardust_base", fallback = "fairy", wardrobe_body = "fairy", retired = true },
      fairy_dusk = { race = "fairy", name_key = "SKIN_FAIRY_DUSK", visual = "fairy_dusk_base", fallback = "fairy", wardrobe_body = "fairy", retired = true },
      hobbit_moss = { race = "hobbit", name_key = "SKIN_HOBBIT_MOSS", visual = "hobbit_moss_base", fallback = "raccoon", wardrobe_body = "hobbit_pip", retired = true },
      hobbit_bramble = { race = "hobbit", name_key = "SKIN_HOBBIT_BRAMBLE", visual = "hobbit_bramble_base", fallback = "raccoon", wardrobe_body = "hobbit_pip", retired = true },
    },

    -- The two species chips of the animal card (Rasmus the fox, Kiki the monkey); each picks the skin it names.
    -- The other races have their two heroes in `heroes` only; this table is the animal chip row of the select screen.
    species = {
      { id = "fox", name_key = "HERO_RASMUS_KIND", skin = "animal_fox" },
      { id = "monkey", name_key = "HERO_KIKI_KIND", skin = "animal_monkey" },
    },

    -- The playable HEROES of the Figurer v2 sheet, two per race, in card order (CharacterCatalog.heroes(race), hero_of_skin(skin)).
    -- name_key / kind_key / blurb_key are the card texts (localization/cast.csv, the ghost's in localization/ghost.csv): the hero
    -- NAME, the KIND line under it (Ræv, Abe, Fe, Halvling, Spøgelse) and the card blurb. The first hero of a race is its default
    -- (races.<race>.default_skin).
    heroes = {
      { id = "rasmus", race = "animal", skin = "animal_fox", name_key = "HERO_RASMUS_NAME", kind_key = "HERO_RASMUS_KIND", blurb_key = "HERO_RASMUS_BLURB" },
      { id = "kiki", race = "animal", skin = "animal_monkey", name_key = "HERO_KIKI_NAME", kind_key = "HERO_KIKI_KIND", blurb_key = "HERO_KIKI_BLURB" },
      { id = "kloevermynte", race = "fairy", skin = "fairy_meadow", name_key = "HERO_KLOEVERMYNTE_NAME", kind_key = "HERO_KLOEVERMYNTE_KIND", blurb_key = "HERO_KLOEVERMYNTE_BLURB" },
      { id = "birk", race = "fairy", skin = "fairy_birk", name_key = "HERO_BIRK_NAME", kind_key = "HERO_BIRK_KIND", blurb_key = "HERO_BIRK_BLURB" },
      { id = "bertil", race = "hobbit", skin = "hobbit_pip", name_key = "HERO_BERTIL_NAME", kind_key = "HERO_BERTIL_KIND", blurb_key = "HERO_BERTIL_BLURB" },
      { id = "bodil", race = "hobbit", skin = "hobbit_bodil", name_key = "HERO_BODIL_NAME", kind_key = "HERO_BODIL_KIND", blurb_key = "HERO_BODIL_BLURB" },
      { id = "bu", race = "ghost", skin = "ghost_bu", name_key = "HERO_BU_NAME", kind_key = "HERO_BU_KIND", blurb_key = "HERO_BU_BLURB" },
      { id = "hviske", race = "ghost", skin = "ghost_hviske", name_key = "HERO_HVISKE_NAME", kind_key = "HERO_HVISKE_KIND", blurb_key = "HERO_HVISKE_BLURB" },
    },

    -- Farm animals (species id of AnimalHusbandry -> baby / adult sprite and the display scale of each stage).
    animals = {
      chicken = { baby = "chick", adult = "hen", baby_scale = 0.7, adult_scale = 1.0 },
      rabbit = { baby = "bunny", adult = "bunny", baby_scale = 0.7, adult_scale = 1.0 },
      duck = { baby = "duck", adult = "duck", baby_scale = 0.7, adult_scale = 1.0 },
      cat = { baby = "kitten", adult = "kitten", baby_scale = 0.7, adult_scale = 1.0 },
      dog = { baby = "puppy", adult = "puppy", baby_scale = 0.7, adult_scale = 1.0 },
      sheep = { baby = "lamb", adult = "lamb", baby_scale = 0.7, adult_scale = 1.0 },
      cow = { baby = "calf", adult = "calf", baby_scale = 0.7, adult_scale = 1.0 },
      deer = { baby = "fawn", adult = "fawn", baby_scale = 0.7, adult_scale = 1.0 },
      fox = { baby = "fox_cub", adult = "fox_cub", baby_scale = 0.7, adult_scale = 1.0 },
      owl = { baby = "owl", adult = "owl", baby_scale = 0.7, adult_scale = 1.0 },
    },

    -- Enemy kind (lua/config/enemies.lua) -> sprite. The pack bat is the normal flier and is NEVER scaled up into a boss
    -- (its W and E rows are edge-on); the boss is its own baked character.
    enemies = {
      bat = { visual = "bat" },
      ugleoje = { visual = "ugleoje" },
      tornebusk = { visual = "tornebusk" },
      lysesvamp = { visual = "lysesvamp" },
      snurresvamp = { visual = "snurresvamp" },
    },

    -- id -> the id that draws while it has no art. Followed until a folder with an animations.json is found.
    fallbacks = {
      -- wardrobe-ready bases (A2): the stock sheet of the same body until the base is baked
      fox_base = "fox",
      rabbit_base = "rabbit",
      hedgehog_base = "hedgehog",
      squirrel_base = "squirrel",
      fairy_base = "fairy",
      fairy_stardust_base = "fairy_stardust",
      fairy_dusk_base = "fairy_dusk",
      hobbit_pip_base = "hobbit_pip",
      hobbit_moss_base = "hobbit_moss",
      hobbit_bramble_base = "hobbit_bramble",

      -- The v2 hero bases use their own dressed character while A2's wardrobe bodies are pending.
      monkey_base = "monkey",
      fairy_birk_base = "fairy_birk",
      hobbit_bodil_base = "hobbit_bodil",
      fairy_birk = "fairy",
      ghost_bu_base = "ghost_bu",
      ghost_hviske_base = "ghost_hviske",

      -- new player skins (P21), pack stand-ins
      squirrel = "monkey",
      fairy_stardust = "fairy",
      fairy_dusk = "fairy",
      hobbit_pip = "raccoon",
      hobbit_moss = "raccoon",
      hobbit_bramble = "raccoon",

      -- the ghost (G-ghost-art bakes the stock sheets): the pack rabbit stands in while they are missing
      ghost_bu = "rabbit",
      ghost_hviske = "rabbit",

      -- named NPC fairies (P21)
      fairy_lily = "fairy",
      fairy_mayor = "fairy",
      fairy_baker = "fairy",
      fairy_shopkeeper = "fairy",
      fairy_king = "fairy",
      fairy_wizard = "fairy",
      fairy_builder = "fairy_shopkeeper",
      fairy_furnisher = "fairy_shopkeeper",
      fairy_tailor = "fairy_shopkeeper",

      -- named villagers (P21)
      mouse_pippin = "rabbit",
      cat_morfar_mis = "cat",
      bear_guard = "bear",
      rabbit_farmer = "rabbit",
      raccoon_smith = "raccoon",
      penguin_postman = "penguin",

      -- the v2 cast (V2-cast-art bakes the folders; until then the pack body stands in). Hoppe needs no entry: he IS the pack rabbit.
      -- Fru Ugle's nearest upright pack bird is the penguin (the data.gd rule: an NPC chain ends at a PACK character within four hops).
      bear_brumme = "bear",
      bat_natteblik = "bat",
      hedgehog_pip = "hedgehog",
      owl_fru_ugle = "penguin",
      capybara_sofus = "capybara",
      fairy_birk_npc = "fairy",
      hobbit_bodil = "hobbit_pip",

      -- farm animals (P21)
      chick = "penguin",
      hen = "penguin",
      duck = "penguin",
      kitten = "cat",
      bunny = "rabbit",
      puppy = "fox",
      fox_cub = "fox",
      lamb = "capybara",
      calf = "capybara",
      fawn = "capybara",
      owl = "penguin",

      -- forest creatures (P21)
      ugleoje = "bat",
      tornebusk = "hedgehog",
      lysesvamp = "frog",
      snurresvamp = "capybara",
    },
  },
}
