"""The building table the room generator reads (package T-towns-core; lifted from D3/towns_scripts/model.py, reduced to what rooms need).

The source of truth of the buildings is the Lua registry (lua/buildings/{traetoppen,hyggebyen,ext}.lua: area, kind, size, shop, keeper, owner, hours).
This table repeats the room-relevant fields of the 24 buildings that have a walk-in room (14 CORE + 10 EXTENDED); `python3 generate.py --buildings` prints it as JSON and the
section towns_data compares it with the loaded registry row by row, so the two cannot drift apart.

Cells of a room: x = column (+x = screen lower-right), z = row (+z = screen lower-left), z = 0 is the BACK wall row, the door sits on the last row.
"""
from __future__ import annotations

# id -> {area, kind, size, shop, keeper, owner, wave}; `shop` is a ShopSystem shop id ("" = none: services, public rooms, homes), `keeper` the citizen behind the counter,
# `owner` the citizen of a home. kind: shop | service | public | home.
ROOMS: dict[str, dict] = {}


def _r(bid: str, area: str, kind: str, size: str, *, shop: str = "", keeper: str = "", owner: str = "", wave: str = "core") -> None:
    ROOMS[bid] = {"area": area, "kind": kind, "size": size, "shop": shop, "keeper": keeper, "owner": owner, "wave": wave}


# --- Traetoppen
_r("hoppe_hut", "traetoppen", "home", "S", owner="gardener_hoppe", wave="ext")
_r("uglehulen", "traetoppen", "service", "S", keeper="appraiser_fru_ugle")
_r("postkontoret", "traetoppen", "service", "M", keeper="postman_pip")
_r("vagthytten", "traetoppen", "home", "S", owner="guard_oak", wave="ext")
_r("brummes_vaerksted", "traetoppen", "shop", "L", shop="timber_yard", keeper="carpenter_brumme")
_r("brummes_hus", "traetoppen", "home", "S", owner="carpenter_brumme", wave="ext")
_r("kikis_hytte", "traetoppen", "home", "S", owner="lamplighter_kiki", wave="ext")
_r("torvekroen", "traetoppen", "public", "L", keeper="innkeeper_kvak", wave="ext")
_r("badehuset", "traetoppen", "service", "M", keeper="bathkeeper_sofus")
_r("musikstuen", "traetoppen", "home", "S", owner="fiddler_strimmel", wave="ext")
_r("raadhuset", "traetoppen", "public", "L", keeper="clerk_fjerpen")
# --- Hyggebyen
_r("froebutikken", "hyggebyen", "shop", "M", shop="seed_shop", keeper="merchant_pip")
_r("bageriet", "hyggebyen", "shop", "M", shop="bakery", keeper="baker_maja")
_r("smedjen", "hyggebyen", "shop", "M", shop="smithy", keeper="smith_thorin")
_r("dyrehuset", "hyggebyen", "shop", "L", shop="animal_store", keeper="farmer_rosa")
_r("troldmandstaarnet", "hyggebyen", "shop", "M", shop="magic_store", keeper="fairy_wizard")
_r("moebelbutikken", "hyggebyen", "shop", "L", shop="furniture_shop", keeper="fairy_furnisher")
_r("skraedderiet", "hyggebyen", "shop", "M", shop="tailor_shop", keeper="fairy_tailor")
_r("toemmerhandlen", "hyggebyen", "shop", "M", shop="builder_yard", keeper="fairy_builder")
_r("loppeloftet", "hyggebyen", "shop", "S", shop="flea_market", keeper="pippin_boegeknop")
_r("fekongens_hus", "hyggebyen", "public", "L", keeper="fairy_king", wave="ext")
_r("hyldeblomsts_hus", "hyggebyen", "home", "S", owner="mayor_lyra", wave="ext")
_r("pippins_hus", "hyggebyen", "home", "S", owner="pippin_boegeknop", wave="ext")
_r("birks_bistade", "hyggebyen", "home", "S", owner="beekeeper_birk", wave="ext")

assert len(ROOMS) == 24, len(ROOMS)

# size classes (cols x rows) and the per-building exceptions of the design (design_towns.md 4.3)
SIZES = {"S": (6, 5), "M": (8, 6), "L": (10, 7)}
SIZE_OVERRIDE = {"postkontoret": (8, 5), "uglehulen": (7, 5), "loppeloftet": (8, 5), "badehuset": (9, 7), "dyrehuset": (9, 7), "troldmandstaarnet": (7, 6),
                 "toemmerhandlen": (9, 6), "brummes_vaerksted": (9, 7), "raadhuset": (10, 8), "fekongens_hus": (10, 8)}

# building -> (wall style, floor terrain); styles and floors are those of assets/iso_props/interior/interior.json and assets/iso_tiles/tiles_floors.json
STYLE = {
    "froebutikken": ("plank", "floor_plank"), "bageriet": ("paper", "floor_parquet"), "smedjen": ("plank", "floor_stone"), "dyrehuset": ("plank", "floor_plank"),
    "troldmandstaarnet": ("paper", "floor_parquet"), "moebelbutikken": ("paper", "floor_parquet"), "skraedderiet": ("paper", "floor_parquet"),
    "toemmerhandlen": ("plank", "floor_stone"), "loppeloftet": ("plank", "floor_plank"), "postkontoret": ("plank", "floor_plank"), "badehuset": ("marble", "floor_marble"),
    "raadhuset": ("marble", "floor_marble"), "uglehulen": ("plank", "floor_plank"), "brummes_vaerksted": ("plank", "floor_stone"), "torvekroen": ("plank", "floor_plank"),
    "fekongens_hus": ("marble", "floor_marble"), "hoppe_hut": ("plank", "floor_plank"), "brummes_hus": ("plank", "floor_plank"), "vagthytten": ("plank", "floor_plank"),
    "kikis_hytte": ("plank", "floor_plank"), "musikstuen": ("paper", "floor_parquet"), "hyldeblomsts_hus": ("paper", "floor_parquet"), "pippins_hus": ("plank", "floor_plank"),
    "birks_bistade": ("paper", "floor_parquet"),
}


def room_size(bid: str) -> tuple[int, int]:
    return SIZE_OVERRIDE.get(bid) or SIZES[ROOMS[bid]["size"]]


def zoom_fit(cols: int, rows: int) -> float:
    """The camera zoom that fits the room (F6's own formula): 0.85 * min(1280 / (n * 64), 720 / (n * 38 + 280)), n = cols + rows."""
    n = float(cols + rows)
    return 0.85 * min(1280.0 / (n * 64.0), 720.0 / (n * 38.0 + 280.0))
