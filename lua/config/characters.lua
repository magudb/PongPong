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

kind = "config"

config = {
  characters = {

    -- The three races of "Vaelg figur". default_skin is what a new game of that race starts with;
    -- name_key / perk_key are the texts of the race card (localization CSVs).
    races = {
      animal = { name_key = "CHAR_ANIMAL_NAME", perk_key = "CHAR_ANIMAL_PERK", default_skin = "animal_fox" },
      fairy = { name_key = "CHAR_FAIRY_NAME", perk_key = "CHAR_FAIRY_PERK", default_skin = "fairy_meadow" },
      hobbit = { name_key = "CHAR_HOBBIT_NAME", perk_key = "CHAR_HOBBIT_PERK", default_skin = "hobbit_pip" },
    },

    -- Player skins. visual = the id the player body asks for first = the wardrobe-ready base (A2, naked body that
    -- WardrobeLayers dresses); the chain behind it (fallbacks) is e.g. squirrel_base -> squirrel -> monkey.
    -- fallback = the pack character that stands in at the END of the chain. wardrobe_body = the bodies.json hero id.
    skins = {
      animal_fox = { race = "animal", name_key = "SPECIES_FOX", visual = "fox_base", fallback = "fox", wardrobe_body = "fox" },
      animal_rabbit = { race = "animal", name_key = "SPECIES_RABBIT", visual = "rabbit_base", fallback = "rabbit", wardrobe_body = "rabbit" },
      animal_hedgehog = { race = "animal", name_key = "SPECIES_HEDGEHOG", visual = "hedgehog_base", fallback = "hedgehog", wardrobe_body = "hedgehog" },
      animal_squirrel = { race = "animal", name_key = "SPECIES_SQUIRREL", visual = "squirrel_base", fallback = "monkey", wardrobe_body = "squirrel" },
      fairy_meadow = { race = "fairy", name_key = "SKIN_FAIRY_MEADOW", visual = "fairy_base", fallback = "fairy", wardrobe_body = "fairy" },
      fairy_stardust = { race = "fairy", name_key = "SKIN_FAIRY_STARDUST", visual = "fairy_stardust_base", fallback = "fairy", wardrobe_body = "fairy_stardust" },
      fairy_dusk = { race = "fairy", name_key = "SKIN_FAIRY_DUSK", visual = "fairy_dusk_base", fallback = "fairy", wardrobe_body = "fairy_dusk" },
      hobbit_pip = { race = "hobbit", name_key = "SKIN_HOBBIT_PIP", visual = "hobbit_pip_base", fallback = "raccoon", wardrobe_body = "hobbit_pip" },
      hobbit_moss = { race = "hobbit", name_key = "SKIN_HOBBIT_MOSS", visual = "hobbit_moss_base", fallback = "raccoon", wardrobe_body = "hobbit_moss" },
      hobbit_bramble = { race = "hobbit", name_key = "SKIN_HOBBIT_BRAMBLE", visual = "hobbit_bramble_base", fallback = "raccoon", wardrobe_body = "hobbit_bramble" },
    },

    -- The four species chips of the animal card (Fox, Rabbit, Hedgehog, Squirrel); each picks the skin of the same name.
    species = {
      { id = "fox", name_key = "SPECIES_FOX", skin = "animal_fox" },
      { id = "rabbit", name_key = "SPECIES_RABBIT", skin = "animal_rabbit" },
      { id = "hedgehog", name_key = "SPECIES_HEDGEHOG", skin = "animal_hedgehog" },
      { id = "squirrel", name_key = "SPECIES_SQUIRREL", skin = "animal_squirrel" },
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

      -- new player skins (P21), pack stand-ins
      squirrel = "monkey",
      fairy_stardust = "fairy",
      fairy_dusk = "fairy",
      hobbit_pip = "raccoon",
      hobbit_moss = "raccoon",
      hobbit_bramble = "raccoon",

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
