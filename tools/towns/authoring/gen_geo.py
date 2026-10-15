"""Generates the draft maps (Hyggebyen 40x40, farm 44x44) and the anchor sidecars (data/towns/<area>.json shape) for the route baker.
Run: python gen_geo.py  -> proto/hyggebyen_draft.map, proto/farm_draft.map, proto/towns_geo.json
"""
from __future__ import annotations
import json, os, sys
sys.path.insert(0, os.path.dirname(__file__))
import model as M
import interiors as I

HERE = os.path.dirname(os.path.abspath(__file__))


def cap_of(name: str) -> int:
    """capacity of an outdoor post (people at once; the director fans them out on a ring of 36 px): benches 3, fire / fountain / dock / well / terrace / market row / stall 2, the playground 4, the rest 1"""
    if "bench" in name:
        return 3
    if name == "torv_playground":
        return 4
    if any(k in name for k in ("fire", "fountain", "dock", "well", "terrace", "market_row", "stall")):
        return 2
    return 1


POOL = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789" + "\u00e6\u00f8\u00e5\u00c6\u00d8\u00c5\u00e9\u00fc"


class Chars:
    """Allocates the single object chars of `@marker` lines (one char = one marker definition): the pool minus the chars the map already uses.
    The last eight are non-ASCII (ae oe aa AE OE AA e-acute u-umlaut): the map parser takes any single character; the probe b9 proves it in a real area."""
    def __init__(self, reserved):
        self.free = [c for c in POOL if c not in reserved]
        self.lines = []

    def marker(self, o, x, y, mtype, **params):
        ch = self.free.pop(0)
        o[y][x] = ch
        self.lines.append("@marker %s %s %s" % (ch, mtype, " ".join("%s=%s" % (k, v) for k, v in params.items())) if params else "@marker %s %s" % (ch, mtype))
        return ch


def grid(w, h, fill="."):
    return [[fill] * w for _ in range(h)]


def put(g, x, y, ch):
    g[y][x] = ch


def render(g):
    return ["".join(r) for r in g]


FEST_CENTER = (19, 20)      # the `post set=fest spot=hyggetorv` marker cell of the draft (the real map: the P11 author puts it on the green)


def make_hyggebyen() -> tuple[str, dict]:
    W = H = 40
    g = grid(W, H, ".")
    o = grid(W, H, ".")
    for y in range(H):
        for x in range(W):
            if x < 3 or y < 3 or x >= W - 3 or y >= H - 3:
                g[y][x] = "#"
    # torv cobble
    for y in range(14, 27):
        for x in range(14, 27):
            g[y][x] = "c"
    # pond (SW) and flowers
    for y in range(32, 37):
        for x in range(5, 9):
            g[y][x] = "~"
    # paths: torv -> every door cell and the bridge
    doors = {}
    chars = {"house_mushroom_rose": "R", "house_mushroom_lavender": "L", "house_mushroom_mint": "N", "house_farm": "K"}
    props = {}
    for bid, (art, fx, fy) in M.HYG_HOUSES.items():
        ch = chars[art]
        props[ch] = art
        o[fy][fx] = ch
        dx, dy = fx, fy + 1
        doors[bid] = (dx, dy)
    def line(a, b):
        (x0, y0), (x1, y1) = a, b
        x, y = x0, y0
        while (x, y) != (x1, y1):
            if x != x1:
                x += 1 if x1 > x else -1
            elif y != y1:
                y += 1 if y1 > y else -1
            if g[y][x] == ".":
                g[y][x] = "p"
    for bid, (dx, dy) in doors.items():
        # path from the doorstep towards the torv edge (vertical first, then horizontal) - the doorstep itself stays grass/path
        target = (min(max(dx, 14), 26), min(max(dy, 14), 26))
        line((dx, dy), target)
    line((M.HYG_BRIDGE[0], M.HYG_BRIDGE[1]), (26, 21))
    # bridge planks (the last 4 cells towards the east rim)
    for x in range(M.HYG_BRIDGE[0] - 3, M.HYG_BRIDGE[0] + 1):
        g[M.HYG_BRIDGE[1]][x] = "="
    # trees + lanterns + fountain
    trees = [(12, 20), (28, 20), (20, 12), (20, 30), (15, 13), (25, 29), (30, 29), (10, 24)]
    for (x, y) in trees:
        if g[y][x] != "~" and o[y][x] == ".":
            o[y][x] = "t"
    for (x, y) in [(18, 18), (22, 18), (18, 22), (22, 22), (13, 21), (27, 21)]:
        o[y][x] = "l"
    o[20][20] = "O"
    # spawns: default on the torv, from_traetoppen next to the bridge
    o[21][19] = "@"
    mk = ["@marker S spawn name=from_traetoppen", "@marker T town", "@marker W warp to=traetoppen spawn=from_hyggebyen label=ZONE_TRAETOPPEN",
          "@marker F post set=fest spot=hyggetorv"]
    o[M.HYG_BRIDGE[1]][M.HYG_BRIDGE[0] - 1] = "S"
    o[M.HYG_BRIDGE[1] + 1][M.HYG_BRIDGE[0] - 4] = "T"
    o[M.HYG_BRIDGE[1]][M.HYG_BRIDGE[0]] = "W"
    o[FEST_CENTER[1]][FEST_CENTER[0]] = "F"
    ch = Chars(reserved=set("RLNKtlO@SWTF.") | set(props))
    for bid, (dx, dy) in doors.items():
        ch.marker(o, dx, dy, "door", building=bid)
    for (n, x, y, a) in M.HYG_POSTS:
        if o[y][x] != ".":
            raise SystemExit("post %s on an occupied object cell %s" % (n, (x, y)))
        ch.marker(o, x, y, "post", name=n, act=a, cap=cap_of(n))
    text = ["@id hyggebyen_draft", "@title ZONE_CITY", "@projection iso", "@ambient hyggebyen", "@theme hyggebyen", "@zone city", "@flight true"]
    for c_, art in props.items():
        text.append(f"@prop {c_} {art}")
    text += ["@prop t tree_blossom_hyggebyen", "@prop l lantern_post", "@prop O fountain"] + mk + ch.lines
    text += ["@ground"] + render(g) + ["@objects"] + render(o)
    sidecar = {"area": "hyggebyen", "kind": "grid"}
    return "\n".join(text) + "\n", sidecar


def make_farm() -> tuple[str, dict]:
    W = H = 44
    g = grid(W, H, ".")
    o = grid(W, H, ".")
    for y in range(H):
        for x in range(W):
            if x < 3 or y < 3 or x >= W - 3 or y >= H - 3:
                g[y][x] = "#"
    for y in range(12, 19):
        for x in range(9, 21):
            g[y][x] = "f"
    for x in range(M.FARM_GATE[0], 44):
        g[M.FARM_GATE[1]][x] = "="
    o[18][31] = "H"          # house footprint front cell (the farm track places the real marker H home)
    o[20][22] = "@"
    o[M.FARM_GATE[1]][M.FARM_GATE[0] + 1] = "S"
    o[M.FARM_GATE[1]][M.FARM_GATE[0] + 5] = "W"
    o[21][24] = "T"
    ch = Chars(reserved=set("H@SWT."))
    posts = []
    for (n, x, y, a) in M.FARM_POSTS:
        ch.marker(o, x, y, "post", name=n)          # exactly the farm track's form: name only (facing optional): act defaults to `stand`, cap to 1
    text = ["@id farm_draft", "@title ZONE_FARM", "@projection iso", "@ambient farm", "@theme farm", "@zone farm", "@flight true", "@prop H house_farm",
            "@marker S spawn name=from_traetoppen", "@marker W warp to=traetoppen spawn=from_farm label=ZONE_TRAETOPPEN", "@marker T town curfew=false"] + ch.lines
    text += ["@ground"] + render(g) + ["@objects"] + render(o)
    return "\n".join(text) + "\n", {"area": "farm", "kind": "grid"}


def make_city() -> dict:
    city = json.load(open(os.path.join(HERE, "..", "analysis", "areas_scripts", "proto", "city.json")))
    doors = []
    for b in M.BUILDINGS.values():
        if b["area"] != "traetoppen" or b["kind"] in ("decor", "stall") or (b["interior"] is None and b["door_hut"] is None):
            continue
        if b["door_hut"] is not None:
            h = city["huts"][b["door_hut"]]
            doors.append({"building": b["id"], "sx": h["door"]["x"], "sy": h["door"]["y"], "level": h["platform"]})
        elif b["door_xy"] is not None:
            doors.append({"building": b["id"], "sx": b["door_xy"][0], "sy": b["door_xy"][1], "level": 4})
    posts = [{"name": n, "level": l, "sx": sx, "sy": sy, "act": a, "cap": cap_of(n)} for (n, l, sx, sy, a) in M.CITY_POSTS]
    gates = [{"name": n, "level": l, "sx": sx, "sy": sy, "to": to, "to_gate": tg} for (n, l, sx, sy, to, tg) in M.CITY_GATES]
    fest = [{"spot": s, "level": l, "sx": sx, "sy": sy} for (s, l, sx, sy) in M.CITY_FEST]
    return {"area": "traetoppen", "kind": "city", "doors": doors, "posts": posts, "gates": gates, "fest_sets": fest}


def make_interiors() -> dict:
    out = {}
    for bid, r in I.build_all().items():
        out["int_" + bid] = r.spec()
    return out


if __name__ == "__main__":
    os.makedirs(os.path.join(HERE, "proto"), exist_ok=True)
    hm, hs = make_hyggebyen()
    fm, fs = make_farm()
    open(os.path.join(HERE, "proto", "hyggebyen_draft.map"), "w").write(hm)
    open(os.path.join(HERE, "proto", "farm_draft.map"), "w").write(fm)
    geo = {"hyggebyen": hs, "farm": fs, "traetoppen": make_city(), "interiors": make_interiors(), "houses": {k: list(v) for k, v in M.HYG_HOUSES.items()}}
    json.dump(geo, open(os.path.join(HERE, "proto", "towns_geo.json"), "w"), indent=1)
    print("hyggebyen/farm: markers in the draft maps | city doors", len(geo["traetoppen"]["doors"]), "posts", len(geo["traetoppen"]["posts"]), "fest sets", len(geo["traetoppen"]["fest_sets"]), "| interiors", len(geo["interiors"]))
    idir = os.path.join(HERE, "proto", "interiors")
    os.makedirs(idir, exist_ok=True)
    for k, v in geo["interiors"].items():
        json.dump(v, open(os.path.join(idir, k + ".json"), "w"), indent=1)
    tdir = os.path.join(HERE, "proto", "towns")
    os.makedirs(tdir, exist_ok=True)
    for aid in ("hyggebyen", "farm", "traetoppen"):
        json.dump(geo[aid], open(os.path.join(tdir, aid + ".json"), "w"), indent=1)
    # also copy the interior json + city json for the Godot probes
    import shutil
    shutil.copy(os.path.join(HERE, "..", "analysis", "areas_scripts", "proto", "city.json"), os.path.join(HERE, "proto", "city.json"))
