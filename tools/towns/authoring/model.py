"""Towns track (design3, designer B) - the DATA MODEL of the proposal: buildings, posts, citizens and their routines.
Everything the Lua / JSON / map generators and the validators read lives here, so the numbers in design_towns.md and the
files in lua/ (the lift source of the content packages) cannot drift apart.

Time is in game hours (6.0 = 06:00, 17.5 = 17:30). Weekday 0 = Monday ... 6 = Sunday. All ids are ascii (D11: ids are stable,
names come from the CSVs).
"""
from __future__ import annotations

# --------------------------------------------------------------------------------------------------------------------------
# BUILDINGS  (registry `buildings`, one row per door of the two towns + the farm)
#   kind: shop | service | public | home | stall | decor
#   interior: None = no walk-in room (locked nameplate door / stall counter / decor hut)
#   size: S 6x5, M 8x6, L 10x7 (the InteriorRoom size classes; exact cols x rows in INTERIORS below)
#   hours: open/close in game hours, closed = weekdays (0 = Monday), festivals closed = list of festival ids (data of the social track)
#   wave: core = needed for the first playable town loop, ext = social / flavour layer
# --------------------------------------------------------------------------------------------------------------------------
BUILDINGS: dict[str, dict] = {}


def B(id, area, kind, name_da, *, interior=True, size="M", shop=None, keeper=None, owner=None, hours=None, closed=(), wave="core",
      door_hut=None, door_xy=None, note="", post=None, overrides=()):
    BUILDINGS[id] = dict(id=id, area=area, kind=kind, name_da=name_da, interior=("int_" + id) if interior else None, size=size if interior else None,
                         shop=shop, keeper=keeper, owner=owner, hours=hours, closed=list(closed), wave=wave if interior else ("core" if kind in ("stall", "decor") else wave),
                         door_hut=door_hut, door_xy=door_xy, note=note, overrides=list(overrides),
                         post=post if post else (("int_" + id + ".counter") if (interior and keeper) else None))


# --- Traetoppen (hut index = index in design2 v2_city_extract.json `huts`, 0..12; the Raadhus is the 14th building)
B("hoppe_hut", "traetoppen", "home", "Hoppes hytte", size="S", owner="gardener_hoppe", wave="ext", door_hut=0)
B("uglehulen", "traetoppen", "service", "Uglehulen", size="S", keeper="appraiser_fru_ugle", hours=(12, 20), closed=(0, 3), door_hut=1,
  note="appraisal counter (shop fru_ugle_vurdering of the experience track); closed Mon + Thu = her field days in Moerkeskoven")
B("postkontoret", "traetoppen", "service", "Postkontoret", size="M", keeper="postman_pip", hours=(9, 17), closed=(6,), door_hut=2,
  note="post counter: letters, parcels, mail from friends; Pip lives in the back room (bed post)")
B("vagthytten", "traetoppen", "home", "Vagthytten", size="S", owner="guard_oak", wave="ext", door_hut=3)
B("brummes_vaerksted", "traetoppen", "shop", "Brummes værksted", size="L", shop="timber_yard", keeper="carpenter_brumme", hours=(8, 16), closed=(5, 6), door_hut=4,
  note="weekends the same shop is sold at the Torvet stall")
B("brummes_hus", "traetoppen", "home", "Brummes hus", size="S", owner="carpenter_brumme", wave="ext", door_hut=5)
B("kikis_hytte", "traetoppen", "home", "Kikis hytte", size="S", owner="lamplighter_kiki", wave="ext", door_hut=6)
B("torvekroen", "traetoppen", "public", "Torvekroen", size="L", keeper="innkeeper_kvak", hours=(11, 23), closed=(), overrides=[{"weekday": [0], "open": 17, "close": 23}], wave="ext", door_hut=7,
  note="the evening meeting place; Kvak lives upstairs; Mondays he opens late (17:00) after a day at the pond")
B("fjerpens_hytte", "traetoppen", "home", "Fjerpens hytte", interior=False, owner="clerk_fjerpen", door_hut=8, note="locked nameplate door")
B("badehuset", "traetoppen", "service", "Badehuset", size="M", keeper="bathkeeper_sofus", hours=(10, 21), closed=(), door_hut=9, post="int_badehuset.tub",
  note="service bath (30 game minutes, once per day); Sofus lives in the back")
B("musikstuen", "traetoppen", "home", "Musikstuen", size="S", owner="fiddler_strimmel", wave="ext", door_hut=10)
B("gaestehytten", "traetoppen", "decor", "Gæstehytten", interior=False, door_hut=11, note="decor hut: lit window, no door marker (honest: nobody lives there yet)")
B("koekkenhave_skuret", "traetoppen", "home", "Køkkenhave-skuret", interior=False, owner="bertil", door_hut=12, note="locked nameplate door; Bertil tends the planters")
B("raadhuset", "traetoppen", "public", "Rådhuset", size="L", keeper="clerk_fjerpen", hours=(9, 15), closed=(5, 6), door_xy=(993.0, 480.0),
  note="notice board + the mayor's office (weekdays); upper deck, reached by the ladder")
B("torvestanden", "traetoppen", "stall", "Torvestanden", interior=False, shop="timber_yard", keeper="carpenter_brumme", hours=(10, 16), closed=(0, 1, 2, 3, 4), post="traetoppen.t_stall",
  note="outdoor counter of the timber yard, Saturday + Sunday (decision DV19 of design2)")
B("natteblik_vinduet", "traetoppen", "stall", "Natteblik-vinduet", interior=False, shop="natteblik_maps", keeper="mapseller_natteblik", hours=(20, 23.5), post="traetoppen.e_bat_window",
  note="window counter at the bat house, night only (the maps come from the experience track)")

# --- Hyggebyen (zone `city`)
B("froebutikken", "hyggebyen", "shop", "Kløvermyntes Frø", size="M", shop="seed_shop", keeper="merchant_pip", hours=(8, 18), closed=(6,))
B("bageriet", "hyggebyen", "shop", "Rosmarins Bageri", size="M", shop="bakery", keeper="baker_maja", hours=(7, 17), closed=(0,))
B("smedjen", "hyggebyen", "shop", "Thorins Smedje", size="M", shop="smithy", keeper="smith_thorin", hours=(9, 17), closed=(6,))
B("dyrehuset", "hyggebyen", "shop", "Dyrehuset", size="L", shop="animal_store", keeper="farmer_rosa", hours=(9, 17), closed=(3,))
B("troldmandstaarnet", "hyggebyen", "shop", "Zephyrs Tårn", size="M", shop="magic_store", keeper="fairy_wizard", hours=(11, 19), closed=(1,))
B("moebelbutikken", "hyggebyen", "shop", "Stokroses Møbler", size="L", shop="furniture_shop", keeper="fairy_furnisher", hours=(9, 17), closed=(2,))
B("skraedderiet", "hyggebyen", "shop", "Fingerbøls Skrædderi", size="M", shop="tailor_shop", keeper="fairy_tailor", hours=(9, 17), closed=(0,))
B("toemmerhandlen", "hyggebyen", "shop", "Hasselnøds Tømmerhandel", size="M", shop="builder_yard", keeper="fairy_builder", hours=(8, 16), closed=(4,),
  note="also the Husbyggeri desk (dialogue action home_upgrade)")
B("loppeloftet", "hyggebyen", "shop", "Pippins Loppeloft", size="S", shop="flea_market", keeper="pippin_boegeknop", hours=(10, 16), closed=(0, 1, 2, 3, 4),
  note="Saturday + Sunday only (open_weekdays 5,6 of the shop def)")
B("fekongens_hus", "hyggebyen", "public", "Fekongens træhus", size="L", keeper="fairy_king", hours=(10, 16), closed=(6,), wave="ext", post="int_fekongens_hus.throne")
B("hyldeblomsts_hus", "hyggebyen", "home", "Hyldeblomsts hus", size="S", owner="mayor_lyra", wave="ext", note="the mayor and the child Lily")
B("pippins_hus", "hyggebyen", "home", "Pippins hus", size="S", owner="pippin_boegeknop", wave="ext", note="Pippin and (after lost_cat) Morfar Mis")
B("birks_bistade", "hyggebyen", "home", "Birks bistade", size="S", owner="beekeeper_birk", wave="ext")
B("pingvinens_hus", "hyggebyen", "home", "Postpingvinens hus", interior=False, owner="penguin_postman", note="locked nameplate door")

# --- the farm (the farm track owns the map; the towns track only needs these anchors)

INTERIORS_NONE = [b for b in BUILDINGS.values() if b["interior"] is None]

# interior size classes (cols x rows) and the zoom_fit of the F6 formula
SIZES = {"S": (6, 5), "M": (8, 6), "L": (10, 7)}
SIZE_OVERRIDE = {"postkontoret": (8, 5), "uglehulen": (7, 5), "loppeloftet": (8, 5), "badehuset": (9, 7), "dyrehuset": (9, 7), "troldmandstaarnet": (7, 6),
                 "toemmerhandlen": (9, 6), "brummes_vaerksted": (9, 7), "raadhuset": (10, 8), "fekongens_hus": (10, 8)}


def room_size(bid: str) -> tuple[int, int]:
    return SIZE_OVERRIDE.get(bid) or SIZES[BUILDINGS[bid]["size"]]


def zoom_fit(cols: int, rows: int) -> float:
    n = float(cols + rows)
    return 0.85 * min(1280.0 / (n * 64.0), 720.0 / (n * 38.0 + 280.0))


# --------------------------------------------------------------------------------------------------------------------------
# CITIZENS
# --------------------------------------------------------------------------------------------------------------------------
CITIZENS: dict[str, dict] = {}
PLANS: dict[str, dict] = {}     # npc -> {plan name: [(from, place, act)]}
RULES: dict[str, list] = {}     # npc -> select rules


def C(id, name_da, visual, species, age, role, home, work, *, hover=False, priority=3, existing=False, shop=None, closed_days=(), twin=None, family=None,
      likes=(), note="", gates=None, speed=1.0, scale=1.0):
    CITIZENS[id] = dict(id=id, name_da=name_da, visual=visual, species=species, age=age, role=role, home=home, work=work, hover=hover, priority=priority,
                        existing=existing, shop=shop, closed_days=list(closed_days), hero_twin=twin, family=family, likes=list(likes), note=note,
                        gates=gates or {}, speed=speed, scale=scale)


# existing roster (lua/config/npcs.lua, 15)
C("mayor_lyra", "Borgmester Hyldeblomst", "fairy_mayor", "fe", "adult", "mayor", "hyldeblomsts_hus", "raadhuset", hover=True, priority=4, existing=True,
  closed_days=(0, 4, 5, 6), family="hyldeblomst", likes=("hyggebyen.torv_bench1", "traetoppen.u_terrace"), note="commutes Hyggebyen <-> Raadhuset Tue-Thu (78 game minutes each way)")
C("baker_maja", "Bagerfe Rosmarin", "fairy_baker", "fe", "adult", "baker", "bageriet", "bageriet", hover=True, priority=5, existing=True, shop="bakery", closed_days=(0,),
  likes=("hyggebyen.bakery_terrace",))
C("merchant_pip", "Butiksfe Kløvermynte", "fairy_shopkeeper", "fe", "adult", "shopkeeper", "froebutikken", "froebutikken", hover=True, priority=5, existing=True,
  shop="seed_shop", closed_days=(6,), family="kloevermynte", likes=("hyggebyen.blossom_bench1",))
C("pippin_boegeknop", "Pippin Bøgeknop", "mouse_pippin", "mus", "adult", "villager", "pippins_hus", "loppeloftet", priority=4, existing=True, shop="flea_market",
  closed_days=(0, 1, 2, 3, 4), likes=("hyggebyen.pond_dock",))
C("fairy_king", "Fekongen", "fairy_king", "fe", "elder", "king", "fekongens_hus", "fekongens_hus", hover=True, priority=3, existing=True, closed_days=(6,))
C("fairy_lily", "Fe-barnet Lily", "fairy_lily", "fe", "child", "child", "hyldeblomsts_hus", None, hover=True, priority=3, existing=True, family="hyldeblomst",
  likes=("hyggebyen.torv_playground",))
C("smith_thorin", "Smeden Thorin", "raccoon_smith", "vaskebjoern", "adult", "smith", "smedjen", "smedjen", priority=4, existing=True, shop="smithy", closed_days=(6,))
C("guard_oak", "Vagten Oak", "bear_guard", "bjoern", "adult", "guard", "vagthytten", "vagthytten", priority=3, existing=True, family="oak",
  note="the Skovlift post; patrol")
C("farmer_rosa", "Dyrehandler Rosa", "rabbit_farmer", "kanin", "adult", "animal_keeper", "dyrehuset", "dyrehuset", priority=4, existing=True, shop="animal_store",
  closed_days=(3,))
C("fairy_wizard", "Fe-troldmanden Zephyr", "fairy_wizard", "fe", "elder", "wizard", "troldmandstaarnet", "troldmandstaarnet", hover=True, priority=4, existing=True,
  shop="magic_store", closed_days=(1,))
C("cat_morfar_mis", "Morfar Mis", "cat_morfar_mis", "kat", "elder", "elder", "pippins_hus", None, priority=2, existing=True,
  gates={"done_quest": "lost_cat", "or_day": 60}, note="not in town before lost_cat is done (design2) or day 60")
C("penguin_postman", "Postpingvinen", "penguin_postman", "pingvin", "adult", "villager", "pingvinens_hus", None, priority=2, existing=True,
  note="delivers inside Hyggebyen; picks the bag up at the post office")
C("fairy_builder", "Tømrerfe Hasselnød", "fairy_builder", "fe", "adult", "builder", "toemmerhandlen", "toemmerhandlen", hover=True, priority=4, existing=True,
  shop="builder_yard", closed_days=(4,))
C("fairy_furnisher", "Møbelfe Stokrose", "fairy_furnisher", "fe", "adult", "furnisher", "moebelbutikken", "moebelbutikken", hover=True, priority=4, existing=True,
  shop="furniture_shop", closed_days=(2,))
C("fairy_tailor", "Skrædderfe Fingerbøl", "fairy_tailor", "fe", "adult", "tailor", "skraedderiet", "skraedderiet", hover=True, priority=4, existing=True,
  shop="tailor_shop", closed_days=(0,))
# the v2 cast (design2 V1): ids as in design_v2.md 3.5
C("gardener_hoppe", "Gartner Hoppe", "rabbit", "kanin", "adult", "gardener", "hoppe_hut", None, priority=4, closed_days=(6,), likes=("traetoppen.a_bench",))
C("carpenter_brumme", "Tømrer Brumme", "bear_brumme", "bjoern", "adult", "carpenter", "brummes_hus", "brummes_vaerksted", priority=4, shop="timber_yard", closed_days=(5, 6))
C("postman_pip", "Postbud Pip", "hedgehog_pip", "pindsvin", "adult", "postman", "postkontoret", "postkontoret", priority=5, closed_days=(6,), likes=("traetoppen.t_fire_n",))
C("bathkeeper_sofus", "Sofus", "capybara_sofus", "kapivar", "adult", "bathkeeper", "badehuset", "badehuset", priority=4)
C("appraiser_fru_ugle", "Fru Ugle", "owl_fru_ugle", "ugle", "elder", "appraiser", "uglehulen", "uglehulen", priority=4, closed_days=(0, 3),
  note="Mon + Thu: field days at Moerkeskoven floor 1 (the experience track places her there)")
C("mapseller_natteblik", "Natteblik", "bat_natteblik", "flagermus", "adult", "mapseller", "natteblik_vinduet", "natteblik_vinduet", hover=True, priority=3,
  note="awake 20:00 - 23:30 at the bat house; the rest of the day he is a sleeping bat (decor), i.e. absent")
C("beekeeper_birk", "Birk", "fairy_birk_npc", "fe", "adult", "beekeeper", "birks_bistade", None, hover=True, priority=3, family="kloevermynte")
# hero twins + the four new citizens of this track
C("rasmus", "Rasmus", "fox", "raev", "adult", "apprentice", "brummes_hus", "brummes_vaerksted", priority=3, closed_days=(6,), twin="rasmus",
  note="hero twin: absent when the player chose Rasmus")
C("lamplighter_kiki", "Kiki", "monkey", "abe", "adult", "lamplighter", "kikis_hytte", None, priority=3, twin="kiki", note="hero twin; the lamp round at dusk")
C("bertil", "Bertil Bøgeknop", "hobbit_pip", "halvling", "adult", "gardener", "koekkenhave_skuret", None, priority=3, family="boegeknop", twin="bertil")
C("bodil", "Bodil Bøgeknop", "hobbit_bodil", "halvling", "adult", "baker_helper", "bageriet", None, priority=3, family="boegeknop", twin="bodil",
  note="sprite = hobbit_pip stock until the A2/V2 bake of hobbit_bodil exists")
C("innkeeper_kvak", "Værten Kvak", "frog", "frog", "adult", "innkeeper", "torvekroen", "torvekroen", priority=4, closed_days=(0,))
C("cub_bamse", "Bamse", "bear", "bjoern", "child", "child", "vagthytten", None, priority=2, family="oak", scale=0.72)
C("clerk_fjerpen", "Skriver Fjerpen", "cat", "kat", "adult", "clerk", "fjerpens_hytte", "raadhuset", priority=3, closed_days=(5, 6))
C("fiddler_strimmel", "Spillemand Strimmel", "hedgehog", "pindsvin", "adult", "musician", "musikstuen", None, priority=2)

assert len(CITIZENS) == 30, len(CITIZENS)
# EXTENDED citizens: the 7 new ones (design2's cast and the 15 existing are CORE; Fjerpen keeps the Raadhus counter, so he is CORE too). Their routine files live in lua/routines/ext/.
EXT_CITIZENS = {"rasmus", "lamplighter_kiki", "bertil", "bodil", "innkeeper_kvak", "cub_bamse", "fiddler_strimmel"}
for _c in CITIZENS.values():
    _c["wave"] = "ext" if _c["id"] in EXT_CITIZENS else "core"
    _c["home_area"] = BUILDINGS[_c["home"]]["area"]
    _c["work_area"] = BUILDINGS[_c["work"]]["area"] if _c["work"] else ""


# --------------------------------------------------------------------------------------------------------------------------
# POSTS  (named positions of the areas; the generator writes `post` markers of the map / entries of the city json / the interiors)
#   grid areas: (name, cell x, cell y, act, facing, capacity)
#   city: (name, level index, sketch x, sketch y, act, facing, capacity)
# --------------------------------------------------------------------------------------------------------------------------
LEVELS = ["a", "b", "c", "torvet", "upper", "e", "f", "g"]      # index = platform index of the city extract

CITY_POSTS = [
    # name, level, sx, sy, act
    ("a_beds1", 0, 505, 250, "tend"), ("a_beds2", 0, 448, 262, "tend"), ("a_bench", 0, 470, 150, "sit"), ("a_ugle_perch", 0, 560, 300, "perch"),
    ("a_lamp", 0, 349, 200, "lamp"),
    ("b_mailbox", 1, 1352, 300, "stand"), ("b_lift", 1, 1370, 305, "guard"), ("b_bench", 1, 1290, 300, "sit"), ("b_lamp", 1, 1111, 250, "lamp"),
    ("c_logs", 2, 118, 650, "work"), ("c_bench", 2, 300, 700, "sit"), ("c_lamp", 2, 325, 546, "lamp"),
    ("t_fire_n", 3, 880, 698, "sit"), ("t_fire_e", 3, 928, 742, "sit"), ("t_fire_s", 3, 880, 778, "sit"), ("t_fire_w", 3, 835, 742, "sit"),
    ("t_stall", 3, 720, 690, "work"), ("t_bench1", 3, 1000, 705, "sit"), ("t_bench2", 3, 800, 800, "sit"), ("t_ladder", 3, 835, 692, "stand"), ("t_lamp", 3, 977, 505, "lamp"),
    ("u_ladder", 4, 835, 512, "stand"), ("u_board", 4, 905, 525, "stand"), ("u_terrace", 4, 950, 420, "sit"), ("u_lamp", 4, 942, 400, "lamp"),
    ("e_tub", 5, 1454, 626, "stand"), ("e_bench", 5, 1560, 690, "sit"), ("e_bat_window", 5, 1555, 650, "perch"), ("e_lamp", 5, 1437, 724, "lamp"),
    ("f_bench", 6, 640, 1060, "sit"), ("f_lamp", 6, 633, 953, "lamp"),
    ("g_planter1", 7, 1124, 1040, "tend"), ("g_planter2", 7, 1164, 1062, "tend"), ("g_planter3", 7, 1204, 1080, "tend"), ("g_bench", 7, 1250, 1050, "sit"),
    ("g_lamp", 7, 1260, 906, "lamp"),
]
# festival spots of the city (the social track's spots torvet / badehus / raadhus): the standard 20-post set is expanded around (sx, sy) at runtime; only the host is a baked route anchor
CITY_FEST = [("torvet", 3, 880, 735), ("badehus", 5, 1500, 662), ("raadhus", 4, 880, 470)]
# gates of the city (portals to other areas): name, level, sx, sy, to area, to gate
CITY_GATES = [("gate_hyggebyen", 6, 404, 1010, "hyggebyen", "gate_traetoppen"), ("gate_farm", 7, 1408, 970, "farm", "gate_traetoppen"),
              ("gate_skovlift", 1, 1380, 312, "moerkeskoven", "gate_traetoppen")]

# Hyggebyen draft (40 x 40 iso grid). Mushroom houses 2x2: front cell (x, y) = max x / max y of the footprint; the door cell is (x, y + 1).
HYG_HOUSES = {   # building -> (prop art id, front x, front y)
    "froebutikken": ("house_mushroom_rose", 13, 11), "bageriet": ("house_mushroom_mint", 27, 11), "troldmandstaarnet": ("house_mushroom_lavender", 8, 18),
    "hyldeblomsts_hus": ("house_mushroom_rose", 8, 26), "smedjen": ("house_mushroom_lavender", 31, 17), "toemmerhandlen": ("house_mushroom_mint", 31, 26),
    "moebelbutikken": ("house_mushroom_rose", 13, 31), "skraedderiet": ("house_mushroom_lavender", 20, 33), "dyrehuset": ("house_mushroom_mint", 27, 31),
    "loppeloftet": ("house_mushroom_rose", 5, 22), "pippins_hus": ("house_mushroom_lavender", 10, 31), "birks_bistade": ("house_mushroom_mint", 32, 33),
    "pingvinens_hus": ("house_mushroom_rose", 35, 12), "fekongens_hus": ("house_farm", 21, 8),
}
HYG_POSTS = [   # name, x, y, act
    ("torv_fountain_n", 20, 17, "sit"), ("torv_fountain_e", 23, 20, "sit"), ("torv_fountain_s", 20, 23, "sit"), ("torv_fountain_w", 17, 20, "sit"),
    ("torv_bench1", 16, 23, "sit"), ("torv_bench2", 24, 23, "sit"), ("torv_playground", 17, 16, "play"), ("well", 24, 16, "stand"),
    ("blossom_bench1", 12, 15, "sit"), ("blossom_bench2", 28, 15, "sit"), ("bakery_terrace", 29, 14, "sit"), ("forge_front", 33, 19, "work"),
    ("pond_dock", 10, 34, "fish"), ("bees1", 31, 35, "tend"), ("bees2", 33, 36, "tend"), ("rosa_pen", 29, 34, "tend"),
    ("market_row1", 15, 28, "stand"), ("market_row2", 20, 28, "stand"), ("market_row3", 25, 28, "stand"), ("king_balcony", 22, 11, "sit"),
    ("round_n", 20, 13, "patrol"), ("round_e", 30, 21, "patrol"), ("round_s", 20, 29, "patrol"), ("round_w", 11, 21, "patrol"),
]
HYG_BRIDGE = (37, 21)       # warp cell of the bridge to the city (plank cells 34..37)

# farm draft anchors (cells of the 44 x 44 farm of the plan; the farm track owns the real map)
# names = the five `post` markers of the farm track's map (design3/farm/map/farm.map: porch, field_edge, pip_mailbox, hoppe_fence, bench_a)
FARM_POSTS = [("pip_mailbox", 31, 21, "stand"), ("porch", 30, 19, "stand"), ("field_edge", 21, 19, "stand"), ("hoppe_fence", 27, 22, "stand"), ("bench_a", 25, 23, "sit")]
FARM_GATE = (29, 16)        # end of the hængebro towards the city

WEEK = {"mon": 0, "tue": 1, "wed": 2, "thu": 3, "fri": 4, "sat": 5, "sun": 6}


def hm(s: str) -> float:
    h, m = s.split(":")
    return int(h) + int(m) / 60.0
