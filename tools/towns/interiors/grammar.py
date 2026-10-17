"""Room layout grammars of the walk-in interiors (package T-towns-core; lifted from D3/towns_scripts/interiors.py and extended by the SE1 / SE2 / R-I1 amendments).

Three grammars, seed-free and deterministic (the same input gives the same bytes):
  shop band   a shop: the counter band (3 x 1 counter on row 2, hatch bars to the side walls, keeper one row behind it, the `shop` host in front of the counter middle,
              the two `talk` hosts in front of the counter ENDS, the builder yard's `desk`), shelves along the back wall, display pieces, customer posts;
  service     the same band for a place that is not a shop (post office, bathhouse, town hall, Uglehulen, the inn, the king's house): another centre host
              (post_counter, bath, board, appraisal, bar), staff posts, the post office's mailbox;
  home        a bed, a wardrobe, a hearth, a table with seats and a rug; no counter, no hatch.

Pieces: ids of the kit (data/interiors/kit_footprints.json: footprint and layer of the 104 kit ids) or of furniture.json (A1, 130 pieces). The footprint and layer of a kit id come from
the kit table, so a room validates before the art exists and does not change the day the art lands; the room JSON carries NO `stand_in` field (PieceCatalog resolves the art).
"""
from __future__ import annotations

import json
import os
import sys
from pathlib import Path

sys.dont_write_bytecode = True                        # the tools never leave a __pycache__ in the repository, however they are started
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import model as M  # noqa: E402

ROOT = Path(__file__).resolve().parents[3]
FURNITURE_JSON = ROOT / "assets" / "iso_props" / "furniture" / "furniture.json"
KIT_JSON = ROOT / "data" / "interiors" / "kit_footprints.json"

_FURN: dict | None = None
_KIT: dict | None = None


def furniture() -> dict:
    global _FURN
    if _FURN is None:
        _FURN = json.loads(FURNITURE_JSON.read_text(encoding="utf-8"))["items"]
    return _FURN


def kit() -> dict:
    """id -> {footprint, layer, ...} of the kit pieces (not the emblems)."""
    global _KIT
    if _KIT is None:
        _KIT = json.loads(KIT_JSON.read_text(encoding="utf-8"))["pieces"]
    return _KIT


def reset_caches() -> None:
    global _FURN, _KIT
    _FURN = None
    _KIT = None


def piece(item_id: str) -> tuple[str, tuple[int, int]] | None:
    """(layer, (w, d)) of an item id at rotation 0: the kit table first, then furniture.json; None for an unknown id."""
    k = kit().get(item_id)
    if k is not None:
        return str(k["layer"]), (int(k["footprint"][0]), int(k["footprint"][1]))
    f = furniture().get(item_id)
    if f is not None:
        return str(f["layer"]), (int(f["footprint"][0]), int(f["footprint"][1]))
    return None


def fp(item: str, rot: int = 0) -> tuple[int, int]:
    p = piece(item)
    if p is None:
        raise KeyError(f"unknown piece {item}")
    w, d = p[1]
    return (w, d) if rot % 2 == 0 else (d, w)


def layer(item: str) -> str:
    p = piece(item)
    if p is None:
        raise KeyError(f"unknown piece {item}")
    return p[0]


SOLID_LAYERS = ("floor",)
FLAT_LAYERS = ("rug", "tabletop")       # on the floor but not solid


class Room:
    def __init__(self, bid: str):
        self.bid = bid
        self.cols, self.rows = M.room_size(bid)
        self.items: list[dict] = []
        self.posts: list[dict] = []
        self.markers: list[dict] = []
        self.occ: set[tuple[int, int]] = set()        # floor cells blocked by solid items
        self.hatch: set[tuple[int, int]] = set()      # blocked for the player only
        self.reserved: set[tuple[int, int]] = set()   # cells that stay free of floor pieces (door lane, counter front, keeper corridor, host cells)
        self.hosts: set[tuple[int, int]] = set()      # cells of the counter hosts (shop / talk / desk / mailbox): no piece, no post
        self.door = (self.cols // 2, self.rows - 1)
        self.spawn = (self.cols // 2, self.rows - 2)
        self.m = self.cols // 2                       # the keeper's column = the counter's middle
        self.problems: list[str] = []
        self.notes: list[str] = []
        for z in range(3, self.rows):
            self.reserved.add((self.door[0], z))      # the door lane

    # ---- placement
    def fits(self, item: str, x: int, z: int, rot: int = 0) -> bool:
        w, d = fp(item, rot)
        if layer(item) != "floor":
            return 0 <= x and x + w <= self.cols and 0 <= z and z + d <= self.rows
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

    def _commit(self, item: str, x: int, z: int, rot: int, role: str = "", wall: bool = False) -> None:
        if layer(item) == "floor":
            w, d = fp(item, rot)
            self.occ.update((x + i, z + j) for i in range(w) for j in range(d))
        e: dict = {"id": item, "cell": [x, z], "rot": rot}
        if role:
            e["role"] = role
        if wall:
            e["wall"] = True
        self.items.append(e)

    def wall_piece(self, item: str, x: int) -> None:
        """A piece hung on the back wall (layer wall): row 0, rotation 0."""
        w, _ = fp(item)
        if x + w > self.cols:
            self.notes.append(f"wall piece {item} does not fit at {x}, dropped")
            return
        self._commit(item, x, 0, 0, wall=True)

    def reach(self, npc: bool) -> set[tuple[int, int]]:
        return flood(self, self.spawn, npc)

    def connected(self) -> bool:
        npc = self.reach(True)
        if any(c not in npc for c in self.reserved if c not in self.occ):
            return False
        player = self.reach(False)
        return all(c in player for c in self.reserved if c[1] >= 3 and c not in self.occ)

    def pack_back(self, items: list[str]) -> None:
        """Along the back wall (row 0): every piece takes the first free spot from the left (first fit), so a small piece fills a gap a wide one could not use;
        a piece that fits nowhere is dropped with a note (the validator reports the notes)."""
        for it in items:
            w, _ = fp(it)
            for x in range(0, self.cols - w + 1):
                if self.fits(it, x, 0):
                    self._commit(it, x, 0, 0)
                    break
            else:
                self.notes.append(f"back wall full, {it} dropped")

    def scatter(self, items: list[str]) -> None:
        """Customer zone: edges first (left / right columns), then inwards; every placement must keep the room connected."""
        cand = [(x, z) for z in range(3, self.rows - 1) for x in range(self.cols)]
        mid = (self.cols - 1) / 2.0
        cand.sort(key=lambda c: (-abs(c[0] - mid), c[1], c[0]))
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
        """The nearest free reachable cell (never a host cell, the door, or a cell another post uses)."""
        reach = self.reach(npc)
        used = {(int(round(p["cell"][0])), int(round(p["cell"][1]))) for p in self.posts}
        best, bd = None, 1e9
        for c in sorted(reach):
            if c in self.occ or c[1] < zmin or c == self.door or c in used or c in self.hosts:
                continue
            d = (c[0] - x) ** 2 + (c[1] - z) ** 2
            if d < bd:
                best, bd = c, d
        return best or (int(x), int(z))

    def post(self, name: str, x: int, z: int, act: str = "stand", facing: str = "S", cap: int = 1, kind: str = "") -> None:
        p: dict = {"id": name, "cell": [int(x), int(z)], "act": act, "facing": facing, "capacity": cap}
        if kind:
            p["kind"] = kind
        self.posts.append(p)

    def snap_post(self, name: str, x: float, z: float, act: str, facing: str, kind: str, zmin: int = 0, npc: bool = False, cap: int = 1) -> tuple[int, int]:
        c = self.free_near(x, z, zmin, npc)
        self.post(name, c[0], c[1], act, facing, cap, kind)
        return c

    def spec(self) -> dict:
        b = M.ROOMS[self.bid]
        wall, flo = M.STYLE.get(self.bid, ("plank", "floor_plank"))
        windows = {"z": [1, self.cols - 3] if self.cols >= 8 else [1], "x": [2] if self.rows < 7 else [1, self.rows - 3]}
        return {
            "id": "int_" + self.bid, "building": self.bid, "size": b["size"], "cols": self.cols, "rows": self.rows, "wall_style": wall, "floor": flo,
            "door": {"cell": list(self.door), "dir": [0, 1]}, "spawn_cell": list(self.spawn), "windows": windows,
            "exit": {"area": b["area"], "spawn": "from_int_" + self.bid},
            "zoom_fit": round(M.zoom_fit(self.cols, self.rows), 3),
            "items": self.items, "posts": self.posts, "markers": self.markers, "notes": self.notes,
        }


STYLE = M.STYLE


# ------------------------------------------------------------------------------------------------------------------------------
# grammar 1 + 2: the counter band (shop band and service)
# ------------------------------------------------------------------------------------------------------------------------------
CENTRE_TYPES = ("shop", "post_counter", "bar", "appraisal", "bath", "board")


def _band(bid: str, back: list[str], display: list[str], *, centre: dict | None, counter_item: str = "counter_pine", keeper_post: str = "counter", assistant: bool = False,
          wall_items: list[str] | None = None, extra_posts: list | None = None, hatch: bool = True, desk: bool = False, mailbox: bool = False) -> Room:
    """The counter band: a 3 x 1 counter in the middle of row 2 (hatch bars from both ends to the side walls: the player is blocked, citizens pass), the keeper one row behind it,
    the centre host in front of the counter middle, a `talk` host on each of the two cells in front of the counter ENDS (m - 1 and m + 1), shelves along the back wall,
    display pieces in the customer zone. `desk` adds the builder yard's second door of the Husbyggeri at m + 2."""
    r = Room(bid)
    x0 = r.cols // 2 - 1
    m = r.m
    keeper = M.ROOMS[bid]["keeper"]
    # the staff corridor (rows 0 - 1 of the counter columns) and the host cells stay free of display pieces
    for x in range(x0, x0 + 3):
        r.reserved.add((x, 3))
        r.reserved.add((x, 1))
    r.hosts.update({(m, 3), (m - 1, 3), (m + 1, 3)})
    if desk:
        r.hosts.add((m + 2, 3))
        r.reserved.add((m + 2, 3))
    r.put(counter_item, x0, 2, 0, role="counter")
    if hatch:
        for x in list(range(0, x0)) + list(range(x0 + 3, r.cols)):
            r.hatch.add((x, 2))
        r.markers.append({"type": "hatch", "cells": [list(c) for c in sorted(r.hatch)]})
    # a piece of layer `wall` hangs on the back wall above the counter columns; a clock of the A1 set is a standing (floor) piece and goes to the back-wall packing
    hung = [wi for wi in (wall_items or []) if layer(wi) == "wall"]
    standing = [wi for wi in (wall_items or []) if layer(wi) != "wall"]
    r.pack_back(back + standing)
    for k, wi in enumerate(hung):
        r.wall_piece(wi, x0 + k)
    r.scatter(display)
    r.post(keeper_post, m, 1, act="work", facing="S", kind="keeper")
    if assistant:
        r.snap_post("work", 0, 1, "work", "E", "staff", npc=True)
    if centre is not None:
        mk = dict(centre)
        mk["cell"] = [m, 3]
        r.markers.append(mk)
        if hatch:
            # the talk hosts exist wherever a keeper stands behind a band: the shop panel is the middle, the keeper's own dialogue the two cells beside it
            for dx in (-1, 1):
                r.markers.append({"type": "talk", "keeper": keeper, "cell": [m + dx, 3]})
            if desk:
                r.markers.append({"type": "desk", "keeper": keeper, "cell": [m + 2, 3]})
    if mailbox:
        mc = _mailbox_cell(r)
        r.hosts.add(mc)
        r.markers.append({"type": "mailbox", "cell": list(mc)})
    r.markers.append({"type": "door", "cell": list(r.door), "to": M.ROOMS[bid]["area"], "spawn": "from_int_" + bid})
    r.snap_post("cust1", 1, 3, "stand", "N", "customer", zmin=3)
    r.snap_post("cust2", r.cols - 2, 3, "stand", "N", "customer", zmin=3)
    r.snap_post("cust3", r.cols // 2 + 2, r.rows - 3, "stand", "N", "customer", zmin=3)
    for ep in (extra_posts or []):
        r.snap_post(*ep)
    return r


def _mailbox_cell(r: Room) -> tuple[int, int]:
    """The post office's mailbox (V6's PostBox2D): the free customer cell nearest to the front-left corner, never beside the counter hosts."""
    reach = r.reach(False)
    best, bd = None, 1e9
    for c in sorted(reach):
        if c in r.occ or c in r.hosts or c in r.reserved or c[1] < 4 or abs(c[0] - r.m) < 3:
            continue
        d = c[0] ** 2 + (c[1] - (r.rows - 2)) ** 2
        if d < bd:
            best, bd = c, d
    return best or (0, r.rows - 2)


def grammar_shop(bid: str, back: list[str], display: list[str], **kw) -> Room:
    """A shop: the centre host is the `shop` counter of the building's shop id."""
    b = M.ROOMS[bid]
    centre = {"type": "shop", "id": b["shop"], "keeper": b["keeper"]}
    return _band(bid, back, display, centre=centre, **kw)


def grammar_service(bid: str, back: list[str], display: list[str], centre_type: str, **kw) -> Room:
    """A service or a public room: the centre host is of another type (post_counter, bath, board, appraisal, bar); a throne room has none (centre_type "")."""
    b = M.ROOMS[bid]
    centre = {"type": centre_type, "keeper": b["keeper"]} if centre_type else None
    return _band(bid, back, display, centre=centre, **kw)


def grammar_home(bid: str, bed: str = "bed_pine", extra: list[str] | None = None) -> Room:
    r = Room(bid)
    c, rw = r.cols, r.rows
    bw = fp(bed)[0]
    r.put(bed, c - bw, 0, 0, role="bed")
    r.put("wardrobe_pine", 0, 0, 0)
    r.pack_back(["fireplace_granite"])
    r.scatter((extra or []) + ["table_round_pine", "plant_fern", "floor_lamp_iron", "chair_pine", "chair_birch"])
    r._commit("rug_round_red", 2, 3, 0)
    r.snap_post("bed", c - 1, 3, "sleep", "N", "bed", npc=True, cap=2)
    t = [i for i in r.items if i["id"] == "table_round_pine"]
    tx, tz = (t[0]["cell"] if t else (2, 3))
    r.snap_post("table", tx + 1, tz + 1, "sit", "N", "seat", npc=True, cap=3)
    r.snap_post("hearth", 3, 2, "stand", "N", "", npc=True, cap=2)
    r.snap_post("visit", c // 2 + 1, rw - 2, "stand", "N", "customer")
    r.markers.append({"type": "door", "cell": list(r.door), "to": M.ROOMS[bid]["area"], "spawn": "from_int_" + bid})
    return r


# ------------------------------------------------------------------------------------------------------------------------------
# the 24 rooms (design_towns.md 4.3: pieces per room)
# ------------------------------------------------------------------------------------------------------------------------------
def build_all() -> dict[str, Room]:
    R: dict[str, Room] = {}
    # ---- shops (core)
    R["froebutikken"] = grammar_shop("froebutikken", back=["bookshelf_pine", "bookshelf_birch", "chest_pine"], wall_items=["shelf_pine", "clock_pine"],
                                     display=["table_round_pine", "plant_fern", "floor_lamp_birch", "chest_oak"])
    R["bageriet"] = grammar_shop("bageriet", back=["brick_oven", "bread_rack", "bread_rack", "bookshelf_birch"],
                                 display=["clock_pine", "table_round_mint", "table_round_mint", "chair_birch", "plant_rose_pot", "floor_lamp_honey"], assistant=True)
    R["smedjen"] = grammar_shop("smedjen", back=["forge", "shelf_oak", "shelf_oak", "forge"], display=["anvil", "chest_oak", "bookshelf_oak_narrow", "floor_lamp_iron"])
    R["troldmandstaarnet"] = grammar_shop("troldmandstaarnet", back=["bookshelf_lavender_narrow", "bookshelf_mint", "cauldron_stand"], wall_items=["clock_owl"],
                                          display=["table_round_mint", "floor_lamp_glowshroom", "plant_teapot_bonsai"])
    R["moebelbutikken"] = grammar_shop("moebelbutikken", back=["wardrobe_oak", "bookshelf_birch", "clock_pine", "piano_pine"],
                                       display=["sofa_pine_two", "sofa_oak_three", "table_dining_oak", "bed_birch_single", "chair_oak", "floor_lamp_honey", "plant_fern"])
    R["skraedderiet"] = grammar_shop("skraedderiet", back=["wardrobe_pine", "wardrobe_rose", "mannequin", "mannequin"],
                                     display=["table_round_pine", "mannequin", "chair_honey", "floor_lamp_honey"])
    R["toemmerhandlen"] = grammar_shop("toemmerhandlen", back=["plank_stack", "plank_stack", "shelf_pine", "chest_pine", "chest_oak"],
                                       display=["table_dining_oak", "chest_birch", "chest_pine", "floor_lamp_iron"], desk=True)
    R["dyrehuset"] = grammar_shop("dyrehuset", back=["hay_bale", "feed_sack_stack", "feed_sack_stack", "shelf_pine", "shelf_birch"],
                                  display=["table_dining_oak", "feed_sack_stack", "plant_fern", "chest_pine", "floor_lamp_birch"])
    R["loppeloftet"] = grammar_shop("loppeloftet", back=["wardrobe_birch_narrow", "chest_sky", "bookshelf_oak_narrow"],
                                    display=["chair_mossy", "table_stump", "clock_sky", "plant_rose_pot"])
    # ---- services (core)
    R["postkontoret"] = grammar_service("postkontoret", back=["mail_sack", "mail_sack", "parcel_stack", "chest_pine"], wall_items=["pigeonhole_wall"], centre_type="post_counter",
                                        display=["letter_desk", "chair_pine", "plant_fern", "clock_pine"], extra_posts=[("bed", 6, 1, "sleep", "S", "bed", 0, True)], mailbox=True)
    R["badehuset"] = grammar_service("badehuset", back=["wooden_tub", "wooden_tub", "wardrobe_birch_narrow", "plant_flowering"], centre_type="bath",
                                     display=["chair_birch", "plant_fern", "floor_lamp_honey"], keeper_post="tub", extra_posts=[("bed", 8, 1, "sleep", "S", "bed", 0, True)])
    R["raadhuset"] = grammar_service("raadhuset", back=["bookshelf_pine", "notice_board_indoor", "throne_honey", "bookshelf_birch"], centre_type="board",
                                     display=["sofa_oak_three", "sofa_oak_three", "clock_sky", "floor_lamp_brass", "plant_flowering"], counter_item="table_long_walnut",
                                     extra_posts=[("mayor_desk", 7, 1, "work", "S", "staff", 0, True)])
    R["uglehulen"] = grammar_service("uglehulen", back=["bookshelf_oak_narrow", "clock_owl", "chest_snail"], wall_items=["shelf_birdhouse"], centre_type="appraisal",
                                     display=["table_round_pine", "plant_teapot_bonsai", "floor_lamp_glowshroom"], extra_posts=[("perch", 5, 1, "perch", "S", "bed", 0, True)])
    R["brummes_vaerksted"] = grammar_shop("brummes_vaerksted", back=["plank_stack", "plank_stack", "shelf_oak", "chest_oak", "workbench"],
                                          display=["table_dining_oak", "plank_stack", "chest_pine", "floor_lamp_iron", "chair_stump"], assistant=True)
    # ---- public (ext)
    R["torvekroen"] = grammar_service("torvekroen", back=["fireplace_granite"], centre_type="bar",
                                      display=["table_round_pine", "table_round_pine", "chair_pine", "chair_pine", "chair_oak", "chair_oak", "piano_pine"],
                                      extra_posts=[("bed", 7, 1, "sleep", "S", "bed", 0, True), ("stage", 3, 4, "play", "N", "stage", 3, False),
                                                   ("seat_a", 1, 3, "sit", "E", "seat", 3, False, 3), ("seat_b", 6, 3, "sit", "W", "seat", 3, False, 3),
                                                   ("seat_c", 2, 3, "sit", "S", "seat", 3, False, 3), ("seat_d", 5, 3, "sit", "S", "seat", 3, False, 3),
                                                   ("seat_e", 1, 4, "sit", "E", "seat", 3, False, 3), ("seat_f", 6, 4, "sit", "W", "seat", 3, False, 3)])
    R["fekongens_hus"] = grammar_service("fekongens_hus", back=["bookshelf_pine", "throne_king", "bookshelf_birch"], centre_type="", counter_item="table_long_walnut",
                                         keeper_post="throne", display=["sofa_oak_three", "sofa_oak_three", "clock_walnut", "floor_lamp_brass", "plant_flowering"], hatch=False)
    # ---- homes (ext)
    R["hoppe_hut"] = grammar_home("hoppe_hut", bed="bed_birch_single", extra=["bookshelf_oak_narrow"])
    R["brummes_hus"] = grammar_home("brummes_hus", bed="bed_pine", extra=["bookshelf_pine"])
    R["vagthytten"] = grammar_home("vagthytten", bed="bed_oak_single", extra=["chest_oak"])
    R["kikis_hytte"] = grammar_home("kikis_hytte", bed="bed_rose_single", extra=["plant_flowering"])
    R["musikstuen"] = grammar_home("musikstuen", bed="bed_birch_single", extra=["piano_sky"])
    R["hyldeblomsts_hus"] = grammar_home("hyldeblomsts_hus", bed="bed_pine", extra=["bookshelf_mint", "bed_rose_single"])
    R["pippins_hus"] = grammar_home("pippins_hus", bed="bed_oak_single", extra=["bookshelf_oak_narrow", "sofa_pine_two"])
    R["birks_bistade"] = grammar_home("birks_bistade", bed="bed_birch_single", extra=["shelf_birdhouse"])
    return R


def flood(r: Room, start: tuple[int, int], npc: bool) -> set[tuple[int, int]]:
    """4-neighbour flood fill over the cells that are not solid; the hatch bars block the player only."""
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
