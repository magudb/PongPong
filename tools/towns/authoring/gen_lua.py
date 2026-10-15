"""Writes the Lua data of the proposal: lua/routines/<id>.lua (one registry entry per file), lua/routines_all.lua (the same 30 in ONE file, for the load-cost
comparison), lua/buildings/<area>.lua and lua/towns.lua (config constants). Lift source of packages T-routines-data / T-buildings-data.
"""
from __future__ import annotations
import os, sys, json
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import model as M
import plans as PL

HERE = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.join(HERE, "lua")


PROTO_VISUAL = {"bear_brumme": "bear", "hedgehog_pip": "hedgehog", "capybara_sofus": "capybara", "owl_fru_ugle": "penguin", "bat_natteblik": "bat", "fairy_birk_npc": "fairy",
                "hobbit_bodil": "hobbit_pip"}   # art that does not exist yet draws as its pack stand-in (lua/config/characters.lua fallbacks)


def fnum(x: float) -> str:
    s = ("%.4f" % x).rstrip("0").rstrip(".")
    return s if "." in s else s + ".0" if False else s


def lua_val(v, ind=0) -> str:
    if isinstance(v, bool):
        return "true" if v else "false"
    if isinstance(v, (int, float)):
        return fnum(float(v)) if isinstance(v, float) else str(v)
    if isinstance(v, str):
        return '"%s"' % v
    if isinstance(v, (list, tuple)):
        return "{ " + ", ".join(lua_val(x) for x in v) + " }"
    if isinstance(v, dict):
        return "{ " + ", ".join(f"{k} = {lua_val(x)}" for k, x in v.items()) + " }"
    raise TypeError(v)


def alias_place(npc: str, place: str) -> str:
    """Own rooms become the logical places `home.<post>` / `work.<post>` (they degrade to the door when the room is not built); visits to the rooms of EXTENDED buildings that are not
    the citizen's own become OPTIONAL places (`...?`: the block is dropped when the room does not exist)."""
    c = M.CITIZENS[npc]
    if place.startswith("int_"):
        room, post = place.split(".", 1)
        b = room[4:]
        if b == c["home"]:
            return "home." + post
        if b == c["work"]:
            return "work." + post
        if M.BUILDINGS[b]["wave"] == "ext":
            return place + "?"
    return place


def block_lua(b, npc: str = "") -> str:
    t, place, act, until = b
    place = alias_place(npc, place) if npc else place
    parts = []
    if t is not None:
        parts.append(f"from = {fnum(t)}")
    parts.append(f'at = "{place}"')
    parts.append(f'act = "{act}"')
    if isinstance(until, tuple):
        parts.append(f"stay = {fnum(until[1])}")
    elif until is not None:
        parts.append(f"leave = {fnum(until)}")
    return "{ " + ", ".join(parts) + " }"


def routine_lua(npc: str) -> str:
    c = M.CITIZENS[npc]
    lines = [f"    {npc} = {{"]
    lines.append(f'      home = "{c["home"]}", home_area = "{c["home_area"]}",')
    if c["work"]:
        lines.append(f'      work = "{c["work"]}", work_area = "{c["work_area"]}",')
    lines.append(f'      priority = {c["priority"]},')
    for field, value in PL.EXTRAS.get(npc, {}).items():
        lines.append(f"      {field} = {lua_val(value)},")
    lines.append(f'      shelter = "{alias_place(npc, PL.SHELTER[npc])}",')
    if c["hero_twin"]:
        lines.append(f'      hero_twin = "{c["hero_twin"]}",')
    if c["gates"]:
        g = c["gates"]
        parts = []
        if "done_quest" in g:
            parts.append(f'done_quest = "{g["done_quest"]}"')
        if "or_day" in g:
            parts.append(f'or_day = {g["or_day"]}')
        lines.append("      gate = { " + ", ".join(parts) + " },")
    lines.append("      plans = {")
    for pname, blocks in PL.PLANS[npc].items():
        lines.append(f"        {pname} = {{ blocks = {{")
        for b in blocks:
            lines.append("          " + block_lua(b, npc) + ",")
        lines.append("        } },")
    lines.append("      },")
    lines.append("      select = {")
    for r in PL.RULES[npc]:
        w = r.get("when")
        if w:
            wl = ", ".join(f"{k} = {lua_val(v)}" for k, v in w.items())
            lines.append(f'        {{ plan = "{r["plan"]}", when = {{ {wl} }} }},')
        else:
            lines.append(f'        {{ plan = "{r["plan"]}" }},')
    lines.append("      },")
    lines.append("    },")
    return "\n".join(lines)


def header(name: str, doc: str) -> str:
    return f'-- {doc}\nkind = "registry"\nregistry = "{name}"\n'


def write_routines():
    d = os.path.join(OUT, "routines")
    import shutil
    shutil.rmtree(d, ignore_errors=True)
    allparts = []
    for npc in PL.PLANS:
        sub = os.path.join(d, M.CITIZENS[npc]["wave"] if M.CITIZENS[npc]["wave"] == "core" else "ext")
        os.makedirs(sub, exist_ok=True)
        txt = header("routines", f"lua/routines/{M.CITIZENS[npc]['wave']}/{npc}.lua - the daily routine of {npc} (towns track; see docs: routine schema)") + "\nroutines = {\n" + routine_lua(npc) + "\n}\n"
        open(os.path.join(sub, f"{npc}.lua"), "w").write(txt)
        allparts.append(routine_lua(npc))
    open(os.path.join(OUT, "routines_all.lua.txt"), "w").write(header("routines", "all 30 routines in one file (load-cost comparison)") + "\nroutines = {\n" + "\n".join(allparts) + "\n}\n")


def building_lua(b) -> list[str]:
    lines = [f'  {b["id"]} = {{']
    lines.append(f'    area = "{b["area"]}", kind = "{b["kind"]}", name_key = "BLD_{b["id"].upper()}",')
    if b["interior"]:
        lines.append(f'    interior = "{b["interior"]}", size = "{b["size"]}",')
    if b["shop"]:
        lines.append(f'    shop = "{b["shop"]}",')
    if b["keeper"]:
        lines.append(f'    keeper = "{b["keeper"]}",')
    if b["post"]:
        lines.append(f'    post = "{b["post"]}",')
    if b["owner"]:
        lines.append(f'    owner = "{b["owner"]}",')
    if b["hours"]:
        cl = ", ".join(str(x) for x in b["closed"])
        short = ", short_ok = true" if b["id"] == "natteblik_vinduet" else ""
        ov = ""
        if b["overrides"]:
            parts = []
            for o in b["overrides"]:
                wl = ", ".join(str(x) for x in o["weekday"])
                parts.append(f'{{ weekday = {{ {wl} }}, open = {fnum(float(o["open"]))}, close = {fnum(float(o["close"]))} }}')
            ov = ", overrides = { " + ", ".join(parts) + " }"
        lines.append(f'    hours = {{ open = {fnum(float(b["hours"][0]))}, close = {fnum(float(b["hours"][1]))}, closed = {{ {cl} }}{ov}{short} }},')
    lines.append(f'    wave = "{b["wave"]}",')
    lines.append("  },")
    return lines


def write_buildings():
    d = os.path.join(OUT, "buildings")
    os.makedirs(d, exist_ok=True)
    for f in os.listdir(d):
        os.remove(os.path.join(d, f))
    for area in ("traetoppen", "hyggebyen"):
        lines = [header("buildings", f"lua/buildings/{area}.lua - the CORE buildings (doors) of {area}: function, interior, keeper, opening hours"), "buildings = {"]
        for b in M.BUILDINGS.values():
            if b["area"] == area and b["wave"] == "core":
                lines += building_lua(b)
        lines.append("}")
        open(os.path.join(d, f"{area}.lua"), "w").write("\n".join(lines) + "\n")
    lines = [header("buildings", "lua/buildings/ext.lua - the EXTENDED buildings: the inn, the king's house and the ten homes that open to a friend"), "buildings = {"]
    for b in M.BUILDINGS.values():
        if b["wave"] == "ext":
            lines += building_lua(b)
    lines.append("}")
    open(os.path.join(d, "ext.lua"), "w").write("\n".join(lines) + "\n")


def write_towns_config():
    txt = '''-- lua/towns.lua - constants of the town simulation (config key `towns`)
kind = "config"

config = {
  towns = {
    npc_speed = 0.65,              -- fraction of the player's walk speed on a scheduled leg (185 px/s of 285)
    portal_seconds = 0.5,          -- time to pass a door or a bridge end
    max_live_visuals = 16,         -- HARD cap: distinct NPC sprite sheets live in one area (9 MB VRAM each; the integration plan's 16)
    plan_visual_peak = 14,         -- what the ROUTINES may ask on an ordinary day (validator towns.visual_budget); the 2 left are for festival guests and scripted scenes
    live_min_dwell = 0.05,         -- game hours a citizen stays at a place at least
    rain_shelter = { acts = { "sit", "tend", "play", "fish" }, from = 8.0, to = 19.0 },
    closing_whisper_minutes = 30,  -- whisper in a shop this long before closing time
    curfew = { enabled = true, whisper = 23.5, go_home = 23.75 },
    carrot_max_speed = 1.6,        -- a follower may catch up at 1.6 x the leg speed
  },
}
'''
    open(os.path.join(OUT, "towns.lua"), "w").write(txt)


def write_citizens_json():
    out = {}
    for c in M.CITIZENS.values():
        out[c["id"]] = {k: c[k] for k in ("visual", "species", "age", "role", "home", "work", "hover", "priority", "hero_twin", "family", "existing", "scale")}
        out[c["id"]]["proto_visual"] = PROTO_VISUAL.get(c["visual"], c["visual"])
    os.makedirs(os.path.join(HERE, "proto"), exist_ok=True)
    json.dump(out, open(os.path.join(HERE, "proto", "citizens.json"), "w"), indent=1)


if __name__ == "__main__":
    write_citizens_json()
    write_routines()
    write_buildings()
    write_towns_config()
    n = 0
    tot = 0
    for root, _, files in os.walk(os.path.join(OUT, "routines")):
        for f in files:
            n += 1
            tot += os.path.getsize(os.path.join(root, f))
    print("routine files", n, "bytes", tot, "| buildings files", len(os.listdir(os.path.join(OUT, "buildings"))))
