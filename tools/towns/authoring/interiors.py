"""Interior room specs (data/interiors/<id>.json) generated from layout grammars + validated by flood fill.
Cells: x = column (+x = screen lower-right), z = row (+z = screen lower-left); z = 0 is the BACK row (wall side), the door is on the last row.
Item ids are ids of assets/iso_props/furniture/furniture.json (130 pieces, A1); `stand_in` marks a missing piece drawn by an existing one.
"""
from __future__ import annotations
import json, sys, os
sys.path.insert(0, os.path.dirname(__file__))
import model as M

FURN = json.load(open("/Users/magnusudbjorg/Documents/projects/PongPong/assets/iso_props/furniture/furniture.json"))["items"]

# art that does not exist yet: stand-ins (honest stubs; validator rule `interiors.stand_ins_listed` reports them)
STAND_IN = {
    "anvil": "table_stump", "forge": "fireplace_granite", "brick_oven": "fireplace_chalk", "wooden_tub": "rug_round_rose", "mannequin": "floor_lamp_birch",
    "mail_sack": "chest_oak", "parcel_stack": "chest_birch", "pigeonhole_wall": "shelf_pine", "letter_desk": "table_dining_oak", "bread_rack": "shelf_birch", "plank_stack": "bookshelf_oak_narrow", "feed_sack_stack": "chest_oak",
    "notice_board_indoor": "painting_wide_pine", "workbench": "table_long_walnut", "hay_bale": "rug_natural", "cauldron_stand": "fireplace_cauldron",
}


def fp(item: str, rot: int = 0) -> tuple[int, int]:
    base = FURN[STAND_IN.get(item, item)]["footprint"]
    return (base[0], base[1]) if rot % 2 == 0 else (base[1], base[0])


def layer(item: str) -> str:
    return FURN[STAND_IN.get(item, item)]["layer"]


class Room:
    def __init__(self, bid: str):
        self.bid = bid
        self.cols, self.rows = M.room_size(bid)
        self.items: list[dict] = []
        self.posts: list[dict] = []
        self.markers: list[dict] = []
        self.occ: set[tuple[int, int]] = set()       # floor cells blocked by solid items
        self.hatch: set[tuple[int, int]] = set()     # blocked for the player only
        self.reserved: set[tuple[int, int]] = set()  # cells that stay free (door lane, counter front, keeper corridor)
        self.door = (self.cols // 2, self.rows - 1)
        self.spawn = (self.cols // 2, self.rows - 2)
        self.problems: list[str] = []
        self.notes: list[str] = []
        for z in range(3, self.rows):
            self.reserved.add((self.door[0], z))

    # ---- placement
    def fits(self, item: str, x: int, z: int, rot: int = 0) -> bool:
        w, d = fp(item, rot)
        if layer(item) != "floor":
            return 0 <= x < self.cols and 0 <= z < self.rows
        for i in range(w):
            for j in range(d):
                c = (x + i, z + j)
                if not (0 <= c[0] < self.cols and 0 <= c[1] < self.rows) or c in self.occ or c in self.reserved:
                    return False
        return True

    def put(self, item: str, x: int, z: int, rot: int = 0, role: str = "") -> bool:
        if not self.fits(item, x, z, rot):
            self.problems.append(f"{self.bid}: {item} does not fit at {x},{z}")
            return False
        self._commit(item, x, z, rot, role)
        return True

    def _commit(self, item: str, x: int, z: int, rot: int, role: str = "") -> None:
        if layer(item) == "floor":
            w, d = fp(item, rot)
            self.occ.update((x + i, z + j) for i in range(w) for j in range(d))
        e = {"id": item, "cell": [x, z], "rot": rot}
        if item in STAND_IN:
            e["stand_in"] = STAND_IN[item]
        if role:
            e["role"] = role
        self.items.append(e)

    def connected(self) -> bool:
        seen = flood(self, self.spawn, npc=True)
        need = [c for c in self.reserved if c not in self.occ]
        return all(c in seen for c in need)

    def pack_back(self, items: list[str]) -> None:
        """Along the back wall (row 0): left to right, wide pieces first come first served; a piece that does not fit is dropped with a note."""
        x = 0
        for it in items:
            w, d = fp(it)
            while x < self.cols and not self.fits(it, x, 0):
                x += 1
            if x + w > self.cols:
                self.notes.append(f"back wall full, {it} dropped")
                continue
            self._commit(it, x, 0, 0)
            x += w

    def scatter(self, items: list[str]) -> None:
        """Customer zone: edges first (left / right columns), then inwards; every placement must keep the room connected."""
        cand = [(x, z) for z in range(3, self.rows - 1) for x in range(self.cols)]
        mid = (self.cols - 1) / 2.0
        cand.sort(key=lambda c: (-abs(c[0] - mid), c[1]))
        for it in items:
            for c in cand:
                if not self.fits(it, c[0], c[1]):
                    continue
                w, d = fp(it)
                cells = [(c[0] + i, c[1] + j) for i in range(w) for j in range(d)] if layer(it) == "floor" else []
                self.occ.update(cells)
                ok = self.connected()
                self.occ.difference_update(cells)
                if ok:
                    self._commit(it, c[0], c[1], 0)
                    break
            else:
                self.notes.append(f"no room for {it}")

    def free_near(self, x: float, z: float, zmin: int = 0, npc: bool = False) -> tuple[int, int]:
        reach = flood(self, self.spawn, npc=npc)
        used = {(int(round(p["cell"][0])), int(round(p["cell"][1]))) for p in self.posts}
        best, bd = None, 1e9
        for c in reach:
            if c in self.occ or c[1] < zmin or c == self.door or c in used:
                continue
            d = (c[0] - x) ** 2 + (c[1] - z) ** 2
            if d < bd:
                best, bd = c, d
        return best or (int(x), int(z))

    def post(self, name: str, x: float, z: float, act: str = "stand", facing: str = "S", cap: int = 1, kind: str = "") -> None:
        p = {"id": name, "cell": [x, z], "act": act, "facing": facing, "capacity": cap}
        if kind:
            p["kind"] = kind
        self.posts.append(p)

    def snap_post(self, name: str, x: float, z: float, act: str, facing: str, kind: str, zmin: int = 0, npc: bool = False, cap: int = 1) -> tuple[int, int]:
        c = self.free_near(x, z, zmin, npc)
        self.post(name, float(c[0]), float(c[1]), act, facing, cap, kind)
        return c

    def spec(self) -> dict:
        b = M.BUILDINGS[self.bid]
        wall, flo = STYLE.get(self.bid, ("plank", "floor_plank"))
        windows = {"z": [1, self.cols - 3] if self.cols >= 8 else [1], "x": [2] if self.rows < 7 else [1, self.rows - 3]}
        return {
            "id": "int_" + self.bid, "building": self.bid, "size": b["size"], "cols": self.cols, "rows": self.rows, "wall_style": wall, "floor": flo,
            "door": {"cell": list(self.door), "dir": [0, 1]}, "spawn_cell": list(self.spawn), "windows": windows,
            "exit": {"area": b["area"], "spawn": "from_int_" + self.bid},
            "zoom_fit": round(M.zoom_fit(self.cols, self.rows), 3),
            "items": self.items, "posts": self.posts, "markers": self.markers, "notes": self.notes,
        }


STYLE = {   # building -> (wall style, floor atlas)
    "froebutikken": ("plank", "floor_plank"), "bageriet": ("paper", "floor_parquet"), "smedjen": ("plank", "floor_stone"), "dyrehuset": ("plank", "floor_plank"),
    "troldmandstaarnet": ("paper", "floor_parquet"), "moebelbutikken": ("paper", "floor_parquet"), "skraedderiet": ("paper", "floor_parquet"),
    "toemmerhandlen": ("plank", "floor_stone"), "loppeloftet": ("plank", "floor_plank"), "postkontoret": ("plank", "floor_plank"), "badehuset": ("marble", "floor_marble"),
    "raadhuset": ("marble", "floor_marble"), "uglehulen": ("plank", "floor_plank"), "brummes_vaerksted": ("plank", "floor_stone"), "torvekroen": ("plank", "floor_plank"),
    "fekongens_hus": ("marble", "floor_marble"), "hoppe_hut": ("plank", "floor_plank"), "brummes_hus": ("plank", "floor_plank"), "vagthytten": ("plank", "floor_plank"),
    "kikis_hytte": ("plank", "floor_plank"), "musikstuen": ("paper", "floor_parquet"), "hyldeblomsts_hus": ("paper", "floor_parquet"), "pippins_hus": ("plank", "floor_plank"),
    "birks_bistade": ("paper", "floor_parquet"),
}


def shop_room(bid: str, back: list[str], display: list[str], counter_item: str = "table_long_pine", marker: dict | None = None, keeper_post: str = "counter",
              assistant: bool = False, wall_items: list[str] | None = None, extra_posts: list | None = None, hatch: bool = True) -> Room:
    """The counter band: a 3 x 1 table in the middle of row 2 (hatch bars from both ends to the side walls: the player is blocked, citizens pass),
    the keeper one row behind it, the interactable on the front row, shelves along the back wall, display pieces in the customer zone."""
    r = Room(bid)
    x0 = r.cols // 2 - 1
    # keep the staff corridor (rows 0-1 of the counter columns, and the lane from the hatch to it) free of display pieces
    for x in range(x0, x0 + 3):
        r.reserved.add((x, 3))
        r.reserved.add((x, 1))
    r.put(counter_item, x0, 2, 0, role="counter")
    if hatch:
        for x in list(range(0, x0)) + list(range(x0 + 3, r.cols)):
            r.hatch.add((x, 2))
        r.markers.append({"type": "hatch", "cells": sorted([list(c) for c in r.hatch])})
    r.pack_back(back)
    for wi in (wall_items or []):
        r.items.append({"id": wi, "cell": [x0 + (1 if wi.startswith("clock") else 0), 0], "rot": 0, "wall": True})
    r.scatter(display)
    r.post(keeper_post, x0 + 1.0, 1.0, act="work", facing="S", kind="keeper")
    if assistant:
        a = r.snap_post("work", 0.0, 1.0, "work", "E", "staff", npc=True)
    m = marker if marker is not None else {"type": "shop", "id": M.BUILDINGS[bid]["shop"], "keeper": M.BUILDINGS[bid]["keeper"]}
    if m:
        m = dict(m)
        m["cell"] = [x0 + 1, 3]
        r.markers.append(m)
    r.markers.append({"type": "door", "cell": list(r.door), "to": M.BUILDINGS[bid]["area"], "spawn": "from_int_" + bid})
    r.snap_post("cust1", 1, 3, "stand", "N", "customer", zmin=3)
    r.snap_post("cust2", r.cols - 2, 3, "stand", "N", "customer", zmin=3)
    r.snap_post("cust3", r.cols // 2 + 2, r.rows - 3, "stand", "N", "customer", zmin=3)
    for ep in (extra_posts or []):
        r.snap_post(*ep)
    return r


def home_room(bid: str, bed: str = "bed_pine", extra: list[str] | None = None) -> Room:
    r = Room(bid)
    c, rw = r.cols, r.rows
    bw = fp(bed)[0]
    r.put(bed, c - bw, 0, 0, role="bed")
    r.put("wardrobe_pine", 0, 0, 0)
    r.pack_back(["fireplace_granite"])
    r.scatter((extra or []) + ["table_round_pine", "plant_fern", "floor_lamp_iron", "chair_pine", "chair_birch"])
    r.items.append({"id": "rug_round_red", "cell": [2, 3], "rot": 0})
    r.snap_post("bed", c - 1.0, 3.0, "sleep", "N", "bed", npc=True, cap=2)
    t = [i for i in r.items if i["id"] == "table_round_pine"]
    tx, tz = (t[0]["cell"] if t else (2, 3))
    r.snap_post("table", tx + 1.0, tz + 1.0, "sit", "N", "seat", npc=True, cap=3)
    r.snap_post("hearth", 3.0, 2.0, "stand", "N", "", npc=True, cap=2)
    r.snap_post("visit", c // 2 + 1.0, rw - 2.0, "stand", "N", "customer")
    r.markers.append({"type": "door", "cell": list(r.door), "to": M.BUILDINGS[bid]["area"], "spawn": "from_int_" + bid})
    return r


def build_all() -> dict[str, Room]:
    R: dict[str, Room] = {}
    # ------------------------------------------------------------------ shops (core)
    R["froebutikken"] = shop_room("froebutikken", back=["bookshelf_pine", "bookshelf_birch", "chest_pine"], wall_items=["shelf_pine", "clock_pine"],
                                  display=["table_round_pine", "plant_fern", "floor_lamp_birch", "chest_oak"])
    R["bageriet"] = shop_room("bageriet", back=["brick_oven", "bread_rack", "bread_rack", "bookshelf_birch"], wall_items=["clock_pine"],
                              display=["table_round_mint", "table_round_mint", "chair_birch", "plant_rose_pot", "floor_lamp_honey"], assistant=True)
    R["smedjen"] = shop_room("smedjen", back=["forge", "shelf_oak", "shelf_oak", "forge"], display=["anvil", "chest_oak", "bookshelf_oak_narrow", "floor_lamp_iron"])
    R["troldmandstaarnet"] = shop_room("troldmandstaarnet", back=["bookshelf_lavender_narrow", "bookshelf_mint", "cauldron_stand"], wall_items=["clock_owl"],
                                       display=["table_round_mint", "floor_lamp_glowshroom", "plant_teapot_bonsai"])
    R["moebelbutikken"] = shop_room("moebelbutikken", back=["wardrobe_oak", "bookshelf_birch", "clock_pine", "piano_pine"],
                                    display=["sofa_pine_two", "sofa_oak_three", "table_dining_oak", "bed_birch_single", "chair_oak", "floor_lamp_honey", "plant_fern"])
    R["skraedderiet"] = shop_room("skraedderiet", back=["wardrobe_pine", "wardrobe_rose", "mannequin", "mannequin"],
                                  display=["table_round_pine", "mannequin", "chair_honey", "floor_lamp_honey"])
    R["toemmerhandlen"] = shop_room("toemmerhandlen", back=["plank_stack", "plank_stack", "shelf_pine", "chest_pine", "chest_oak"],
                                    display=["table_dining_oak", "chest_birch", "chest_pine", "floor_lamp_iron"])
    R["dyrehuset"] = shop_room("dyrehuset", back=["hay_bale", "feed_sack_stack", "feed_sack_stack", "shelf_pine", "shelf_birch"],
                               display=["table_dining_oak", "feed_sack_stack", "plant_fern", "chest_pine", "floor_lamp_birch"])
    R["loppeloftet"] = shop_room("loppeloftet", back=["wardrobe_birch_narrow", "chest_sky", "bookshelf_oak_narrow"],
                                 display=["chair_mossy", "table_stump", "clock_sky", "plant_rose_pot"])
    # ------------------------------------------------------------------ services (core)
    R["postkontoret"] = shop_room("postkontoret", back=["mail_sack", "mail_sack", "parcel_stack", "chest_pine"], wall_items=["pigeonhole_wall"], marker={"type": "post_counter", "keeper": "postman_pip"},
                                  display=["letter_desk", "chair_pine", "plant_fern", "clock_pine"], extra_posts=[("bed", 6.0, 1.0, "sleep", "S", "bed", 0, True)])
    R["badehuset"] = shop_room("badehuset", back=["wooden_tub", "wooden_tub", "wardrobe_birch_narrow", "plant_flowering"], marker={"type": "bath", "keeper": "bathkeeper_sofus"},
                               display=["chair_birch", "plant_fern", "floor_lamp_honey"], keeper_post="tub", extra_posts=[("bed", 8.0, 1.0, "sleep", "S", "bed", 0, True)])
    R["raadhuset"] = shop_room("raadhuset", back=["bookshelf_pine", "notice_board_indoor", "throne_honey", "bookshelf_birch"], marker={"type": "board", "keeper": "clerk_fjerpen"},
                               display=["sofa_oak_three", "sofa_oak_three", "clock_sky", "floor_lamp_brass", "plant_flowering"], counter_item="table_long_walnut",
                               extra_posts=[("mayor_desk", 7.0, 1.0, "work", "S", "staff", 0, True)])
    R["uglehulen"] = shop_room("uglehulen", back=["bookshelf_oak_narrow", "clock_owl", "chest_snail"], wall_items=["shelf_birdhouse"], marker={"type": "shop", "id": "fru_ugle_vurdering", "keeper": "appraiser_fru_ugle"},
                               display=["table_round_pine", "plant_teapot_bonsai", "floor_lamp_glowshroom"],
                               extra_posts=[("perch", 5.0, 1.0, "perch", "S", "bed", 0, True)])
    R["brummes_vaerksted"] = shop_room("brummes_vaerksted", back=["plank_stack", "plank_stack", "shelf_oak", "chest_oak", "workbench"],
                                       display=["table_dining_oak", "plank_stack", "chest_pine", "floor_lamp_iron", "chair_stump"], assistant=True)
    # ------------------------------------------------------------------ public (ext)
    R["torvekroen"] = shop_room("torvekroen", back=["bookshelf_pine", "fireplace_granite", "clock_pine"], marker={"type": "bar", "keeper": "innkeeper_kvak"},
                                display=["table_round_pine", "table_round_pine", "chair_pine", "chair_pine", "chair_oak", "chair_oak", "piano_pine"],
                                extra_posts=[("bed", 7.0, 1.0, "sleep", "S", "bed", 0, True), ("stage", 3.0, 4.0, "play", "N", "stage", 3, False),
                                             ("seat_a", 1.0, 3.0, "sit", "E", "seat", 3, False, 3), ("seat_b", 6.0, 3.0, "sit", "W", "seat", 3, False, 3),
                                             ("seat_c", 2.0, 3.0, "sit", "S", "seat", 3, False, 3), ("seat_d", 5.0, 3.0, "sit", "S", "seat", 3, False, 3),
                                             ("seat_e", 1.0, 4.0, "sit", "E", "seat", 3, False, 3), ("seat_f", 6.0, 4.0, "sit", "W", "seat", 3, False, 3)])
    R["fekongens_hus"] = shop_room("fekongens_hus", back=["bookshelf_pine", "throne_king", "bookshelf_birch"], marker={}, counter_item="table_long_walnut", keeper_post="throne",
                                   display=["sofa_oak_three", "sofa_oak_three", "clock_walnut", "floor_lamp_brass", "plant_flowering"], hatch=False)
    # ------------------------------------------------------------------ homes (ext)
    R["hoppe_hut"] = home_room("hoppe_hut", bed="bed_birch_single", extra=["bookshelf_oak_narrow"])
    R["brummes_hus"] = home_room("brummes_hus", bed="bed_pine", extra=["bookshelf_pine"])
    R["vagthytten"] = home_room("vagthytten", bed="bed_oak_single", extra=["chest_oak"])
    R["kikis_hytte"] = home_room("kikis_hytte", bed="bed_rose_single", extra=["plant_flowering"])
    R["musikstuen"] = home_room("musikstuen", bed="bed_birch_single", extra=["piano_sky"])
    R["hyldeblomsts_hus"] = home_room("hyldeblomsts_hus", bed="bed_pine", extra=["bookshelf_mint", "bed_rose_single"])
    R["pippins_hus"] = home_room("pippins_hus", bed="bed_oak_single", extra=["bookshelf_oak_narrow", "sofa_pine_two"])
    R["birks_bistade"] = home_room("birks_bistade", bed="bed_birch_single", extra=["shelf_birdhouse"])
    return R


# ------------------------------------------------------------------------------------------------------------------------------
# validation (python flood fill; the Godot section re-proves it with the real colliders)
# ------------------------------------------------------------------------------------------------------------------------------
def flood(r: Room, start: tuple[int, int], npc: bool) -> set[tuple[int, int]]:
    blocked = set(r.occ) | (set() if npc else set(r.hatch))
    seen = {start}
    stack = [start]
    while stack:
        x, z = stack.pop()
        for dx, dz in ((1, 0), (-1, 0), (0, 1), (0, -1)):
            n = (x + dx, z + dz)
            if 0 <= n[0] < r.cols and 0 <= n[1] < r.rows and n not in blocked and n not in seen:
                seen.add(n)
                stack.append(n)
    return seen


def validate(r: Room) -> list[str]:
    out = list(r.problems)
    if not r.items:
        out.append("no items")
    player = flood(r, r.spawn, npc=False)
    npc = flood(r, r.spawn, npc=True)
    for m in r.markers:
        if m["type"] in ("shop", "post_counter", "bath", "bar", "board"):
            c = tuple(m["cell"])
            if c not in player:
                out.append(f"{r.bid}: the player cannot reach the {m['type']} interactable at {c}")
    keeper = [p for p in r.posts if p.get("kind") == "keeper"]
    for p in r.posts:
        c = (int(round(p["cell"][0])), int(round(p["cell"][1])))
        if p.get("kind") in ("customer",) and c not in player:
            out.append(f"{r.bid}: customer post {p['id']} {c} not reachable by the player")
        if c not in npc and p.get("kind") not in ("bed", "keeper", "staff") and p.get("kind") != "stage":
            out.append(f"{r.bid}: post {p['id']} {c} not reachable by a citizen")
        if p.get("kind") in ("keeper", "staff", "bed") and c not in npc and c in r.occ:
            out.append(f"{r.bid}: post {p['id']} {c} is inside a solid piece")
    for p in keeper:
        c = (int(round(p["cell"][0])), int(round(p["cell"][1])))
        if r.hatch and c in player:
            out.append(f"{r.bid}: the player can walk behind the counter to {p['id']} {c} (hatch leaks)")
    return out


if __name__ == "__main__":
    rooms = build_all()
    os.makedirs("out/interiors", exist_ok=True)
    tot = 0
    for bid, r in rooms.items():
        probs = validate(r)
        s = r.spec()
        json.dump(s, open(f"out/interiors/int_{bid}.json", "w"), indent=1)
        n_items = len(r.items)
        stand = sorted({it["id"] for it in r.items if "stand_in" in it})
        print(f"{bid:20s} {r.cols}x{r.rows} items {n_items:2d} posts {len(r.posts)} hatch {len(r.hatch):2d} stand-ins {stand} {'OK' if not probs else probs}")
        tot += len(probs)
    print("total problems", tot)
