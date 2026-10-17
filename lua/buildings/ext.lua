-- Ten extended town rooms: public meeting places and friend homes
kind = "registry"
registry = "buildings"

buildings = {
  hoppe_hut = {
    area = "traetoppen", kind = "home", name_key = "BLD_HOPPE_HUT",
    interior = "int_hoppe_hut", size = "S",
    owner = "gardener_hoppe",
    wave = "ext",
  },
  vagthytten = {
    area = "traetoppen", kind = "home", name_key = "BLD_VAGTHYTTEN",
    interior = "int_vagthytten", size = "S",
    owner = "guard_oak",
    wave = "ext",
  },
  brummes_hus = {
    area = "traetoppen", kind = "home", name_key = "BLD_BRUMMES_HUS",
    interior = "int_brummes_hus", size = "S",
    owner = "carpenter_brumme",
    wave = "ext",
  },
  kikis_hytte = {
    area = "traetoppen", kind = "home", name_key = "BLD_KIKIS_HYTTE",
    interior = "int_kikis_hytte", size = "S",
    owner = "lamplighter_kiki",
    wave = "ext",
  },
  torvekroen = {
    area = "traetoppen", kind = "public", name_key = "BLD_TORVEKROEN",
    interior = "int_torvekroen", size = "L",
    keeper = "innkeeper_kvak",
    post = "int_torvekroen.counter",
    hours = { open = 11, close = 23, closed = {  }, overrides = { { weekday = { 0 }, open = 17, close = 23 } } },
    wave = "ext",
  },
  musikstuen = {
    area = "traetoppen", kind = "home", name_key = "BLD_MUSIKSTUEN",
    interior = "int_musikstuen", size = "S",
    owner = "fiddler_strimmel",
    wave = "ext",
  },
  fekongens_hus = {
    area = "hyggebyen", kind = "public", name_key = "BLD_FEKONGENS_HUS",
    interior = "int_fekongens_hus", size = "L",
    keeper = "fairy_king",
    post = "int_fekongens_hus.throne",
    hours = { open = 10, close = 16, closed = { 6 } },
    wave = "ext",
  },
  hyldeblomsts_hus = {
    area = "hyggebyen", kind = "home", name_key = "BLD_HYLDEBLOMSTS_HUS",
    interior = "int_hyldeblomsts_hus", size = "S",
    owner = "mayor_lyra",
    wave = "ext",
  },
  pippins_hus = {
    area = "hyggebyen", kind = "home", name_key = "BLD_PIPPINS_HUS",
    interior = "int_pippins_hus", size = "S",
    owner = "pippin_boegeknop",
    wave = "ext",
  },
  birks_bistade = {
    area = "hyggebyen", kind = "home", name_key = "BLD_BIRKS_BISTADE",
    interior = "int_birks_bistade", size = "S",
    owner = "beekeeper_birk",
    wave = "ext",
  },
}
