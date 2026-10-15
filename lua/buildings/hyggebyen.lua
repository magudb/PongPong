-- lua/buildings/hyggebyen.lua - the CORE buildings (doors) of Hyggebyen: function, interior, keeper, opening hours (package T-towns-core)
-- Same schema and rules as lua/buildings/traetoppen.lua (kind = "registry", registry = "buildings"; hours are GAME HOURS on the axis 6..26, weekday 0 = Monday).
-- The four EXTENDED houses of this town (fekongens_hus, hyldeblomsts_hus, pippins_hus, birks_bistade) have door markers on the map but their rows live in
-- lua/buildings/ext.lua (T-ext-content): a door without a row is a locked nameplate (Door2D), labelled with the convention key BLD_<BUILDING_ID> of towns.csv.
kind = "registry"
registry = "buildings"

buildings = {
  froebutikken = {
    area = "hyggebyen", kind = "shop", name_key = "BLD_FROEBUTIKKEN",
    interior = "int_froebutikken", size = "M",
    shop = "seed_shop",
    keeper = "merchant_pip",
    post = "int_froebutikken.counter",
    emblem = "seed",
    hours = { open = 8, close = 18, closed = { 6 } },
    wave = "core",
  },
  bageriet = {
    area = "hyggebyen", kind = "shop", name_key = "BLD_BAGERIET",
    interior = "int_bageriet", size = "M",
    shop = "bakery",
    keeper = "baker_maja",
    post = "int_bageriet.counter",
    emblem = "loaf",
    hours = { open = 7, close = 17, closed = { 0 } },
    wave = "core",
  },
  smedjen = {
    area = "hyggebyen", kind = "shop", name_key = "BLD_SMEDJEN",
    interior = "int_smedjen", size = "M",
    shop = "smithy",
    keeper = "smith_thorin",
    post = "int_smedjen.counter",
    emblem = "anvil",
    hours = { open = 9, close = 17, closed = { 6 } },
    wave = "core",
  },
  dyrehuset = {
    area = "hyggebyen", kind = "shop", name_key = "BLD_DYREHUSET",
    interior = "int_dyrehuset", size = "L",
    shop = "animal_store",
    keeper = "farmer_rosa",
    post = "int_dyrehuset.counter",
    emblem = "paw",
    hours = { open = 9, close = 17, closed = { 3 } },
    wave = "core",
  },
  troldmandstaarnet = {
    area = "hyggebyen", kind = "shop", name_key = "BLD_TROLDMANDSTAARNET",
    interior = "int_troldmandstaarnet", size = "M",
    shop = "magic_store",
    keeper = "fairy_wizard",
    post = "int_troldmandstaarnet.counter",
    emblem = "crystal",
    hours = { open = 11, close = 19, closed = { 1 } },
    wave = "core",
  },
  moebelbutikken = {
    area = "hyggebyen", kind = "shop", name_key = "BLD_MOEBELBUTIKKEN",
    interior = "int_moebelbutikken", size = "L",
    shop = "furniture_shop",
    keeper = "fairy_furnisher",
    post = "int_moebelbutikken.counter",
    emblem = "chair",
    hours = { open = 9, close = 17, closed = { 2 } },
    wave = "core",
  },
  skraedderiet = {
    area = "hyggebyen", kind = "shop", name_key = "BLD_SKRAEDDERIET",
    interior = "int_skraedderiet", size = "M",
    shop = "tailor_shop",
    keeper = "fairy_tailor",
    post = "int_skraedderiet.counter",
    emblem = "thread",
    hours = { open = 9, close = 17, closed = { 0 } },
    wave = "core",
  },
  toemmerhandlen = {
    area = "hyggebyen", kind = "shop", name_key = "BLD_TOEMMERHANDLEN",
    interior = "int_toemmerhandlen", size = "M",
    shop = "builder_yard",
    keeper = "fairy_builder",
    post = "int_toemmerhandlen.counter",
    emblem = "plank",
    hours = { open = 8, close = 16, closed = { 4 } },
    wave = "core",
  },
  loppeloftet = {
    area = "hyggebyen", kind = "shop", name_key = "BLD_LOPPELOFTET",
    interior = "int_loppeloftet", size = "S",
    shop = "flea_market",
    keeper = "pippin_boegeknop",
    post = "int_loppeloftet.counter",
    emblem = "junk",
    hours = { open = 10, close = 16, closed = { 0, 1, 2, 3, 4 } },     -- a weekend shop: Saturday and Sunday only (the shop def says the same: open_weekdays 5, 6)
    wave = "core",
  },
  pingvinens_hus = {
    area = "hyggebyen", kind = "home", name_key = "BLD_PINGVINENS_HUS",
    owner = "penguin_postman",
    wave = "core",
  },
}
