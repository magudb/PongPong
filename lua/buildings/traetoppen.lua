-- lua/buildings/traetoppen.lua - the CORE buildings (doors, stalls) of Traetoppen: function, interior, keeper, opening hours (package T-towns-core)
-- kind = "registry", registry = "buildings": KEY = building id, the id is claimed once across lua/buildings/*.lua (ext.lua is T-ext-content's).
-- Row fields: area, kind (shop | service | public | stall | home | decor), name_key BLD_<ID>, interior (the room id; none = a locked nameplate door or a stall),
-- size S | M | L, shop (a ShopSystem shop id; a service has none), keeper, owner (a home), post, emblem (one of the 15 plates of the I3 kit, optional),
-- hours { open, close, closed = { weekdays, 0 = Monday }, overrides = { { weekday = { .. }, open, close } }, short_ok }, wave core | ext.
-- Hours are GAME HOURS on the axis 6..26: 9 = 09:00, 23.5 = 23:30, close < open = after midnight of the SAME game day (close 1 = 25.0 = 01:00).
-- Hours.shop_open asks every row that carries the same shop id: the workshop (Mon-Fri) and the Torvet stall (Sat-Sun) are ONE shop, timber_yard.
kind = "registry"
registry = "buildings"

buildings = {
  uglehulen = {
    area = "traetoppen", kind = "service", name_key = "BLD_UGLEHULEN",
    interior = "int_uglehulen", size = "S",
    keeper = "appraiser_fru_ugle",
    post = "int_uglehulen.counter",
    hours = { open = 12, close = 20, closed = { 0, 3 } },     -- Mon and Thu are her field days in Moerkeskoven
    wave = "core",
  },
  postkontoret = {
    area = "traetoppen", kind = "service", name_key = "BLD_POSTKONTORET",
    interior = "int_postkontoret", size = "M",
    keeper = "postman_pip",
    post = "int_postkontoret.counter",
    emblem = "posthorn",
    hours = { open = 9, close = 17, closed = { 6 } },
    wave = "core",
  },
  brummes_vaerksted = {
    area = "traetoppen", kind = "shop", name_key = "BLD_BRUMMES_VAERKSTED",
    interior = "int_brummes_vaerksted", size = "L",
    shop = "timber_yard",
    keeper = "carpenter_brumme",
    post = "int_brummes_vaerksted.counter",
    emblem = "log",
    hours = { open = 8, close = 16, closed = { 5, 6 } },
    wave = "core",
  },
  fjerpens_hytte = {
    area = "traetoppen", kind = "home", name_key = "BLD_FJERPENS_HYTTE",
    owner = "clerk_fjerpen",
    wave = "core",
  },
  badehuset = {
    area = "traetoppen", kind = "service", name_key = "BLD_BADEHUSET",
    interior = "int_badehuset", size = "M",
    keeper = "bathkeeper_sofus",
    post = "int_badehuset.tub",
    emblem = "tub",
    hours = { open = 10, close = 21, closed = {} },
    wave = "core",
  },
  koekkenhave_skuret = {
    area = "traetoppen", kind = "home", name_key = "BLD_KOEKKENHAVE_SKURET",
    owner = "bertil",
    wave = "core",
  },
  raadhuset = {
    area = "traetoppen", kind = "public", name_key = "BLD_RAADHUSET",
    interior = "int_raadhuset", size = "L",
    keeper = "clerk_fjerpen",
    post = "int_raadhuset.counter",
    emblem = "scroll",
    hours = { open = 9, close = 15, closed = { 5, 6 } },
    wave = "core",
  },
  torvestanden = {
    area = "traetoppen", kind = "stall", name_key = "BLD_TORVESTANDEN",
    shop = "timber_yard",
    keeper = "carpenter_brumme",
    post = "traetoppen.t_stall",
    emblem = "hammer",
    hours = { open = 10, close = 16, closed = { 0, 1, 2, 3, 4 } },     -- Brumme keeps the stall at Torvet on Saturday and Sunday
    wave = "core",
  },
  natteblik_vinduet = {
    area = "traetoppen", kind = "stall", name_key = "BLD_NATTEBLIK_VINDUET",
    shop = "natteblik_maps",
    keeper = "mapseller_natteblik",
    post = "traetoppen.e_bat_window",
    hours = { open = 20, close = 23.5, closed = {}, short_ok = true },     -- a night shop: the window of the bat house, evenings only
    wave = "core",
  },
}
