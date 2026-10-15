"""Markdown tables of the proposal (buildings, citizens, interiors, hours) written to out/tables.md; the design doc quotes them."""
import sys, os, json
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import model as M
import plans as PL
import interiors as I

WD = ["man", "tir", "ons", "tor", "fre", "lør", "søn"]
def fh(h):
    hh = int(h); mm = int(round((h - hh) * 60)); return "%02d:%02d" % (hh, mm)
def days(closed):
    return ", ".join(WD[i] for i in closed) if closed else "-"

geo = json.load(open("proto/towns_geo.json"))
rooms = I.build_all()
SPECIES = {"bjoern": "bjørn", "vaskebjoern": "vaskebjørn", "raev": "ræv", "frog": "frø"}
out = []
out.append("### B1 buildings\n")
out.append("| id | area | kind | name (da) | door | room | keeper / owner | hours (closed) | wave |")
out.append("|---|---|---|---|---|---|---|---|---|")
for b in M.BUILDINGS.values():
    if b["id"] == "gaarden_postkasse":
        continue
    door = ""
    if b["area"] == "traetoppen":
        door = ("hut %d" % (b["door_hut"] + 1)) if b["door_hut"] is not None else ("upper deck (%d,%d)" % b["door_xy"] if b["door_xy"] else "outdoor")
    elif b["area"] == "hyggebyen":
        hh = M.HYG_HOUSES.get(b["id"])
        door = "cell (%d,%d)" % (hh[1], hh[2] + 1) if hh else "-"
    room = ""
    if b["interior"]:
        c, r = M.room_size(b["id"])
        room = "%s %dx%d" % (b["size"], c, r)
    else:
        room = {"stall": "stall (no room)", "decor": "decor", "home": "locked nameplate door"}.get(b["kind"], "-")
    hrs = ""
    if b["hours"]:
        hrs = "%s-%s (%s)" % (fh(b["hours"][0]), fh(b["hours"][1]), days(b["closed"]))
        for o in b["overrides"]:
            hrs += "; %s %s-%s" % (",".join(WD[i] for i in o["weekday"]), fh(o["open"]), fh(o["close"]))
    elif b["owner"]:
        hrs = "owner at home + hearts"
    who = b["keeper"] or b["owner"] or ""
    out.append(f"| `{b['id']}` | {b['area']} | {b['kind']} | {b['name_da']} | {door} | {room} | {who} | {hrs} | {b['wave']} |")
out.append("")
out.append("### B2 citizens\n")
out.append("| id | name | look (art id) | species | age | role | home | work | closed / rest days | hover | prio | twin / family |")
out.append("|---|---|---|---|---|---|---|---|---|---|---|---|")
for c in M.CITIZENS.values():
    out.append(f"| `{c['id']}` | {c['name_da']} | `{c['visual']}` | {SPECIES.get(c['species'], c['species'])} | {c['age']} | {c['role']} | {c['home']} | {c['work'] or '-'} | {days(c['closed_days'])} | {'yes' if c['hover'] else '-'} | {c['priority']} | {c['hero_twin'] or '-'} / {c['family'] or '-'} |")
out.append("")
out.append("### B3 interiors\n")
out.append("| room | size | cols x rows | zoom_fit | wall / floor | pieces | posts | hatch cells | stand-ins (art asks) | wave |")
out.append("|---|---|---|---|---|---|---|---|---|---|")
for bid, r in rooms.items():
    s = r.spec()
    st = sorted({it["id"] for it in r.items if "stand_in" in it})
    wave = M.BUILDINGS[bid]["wave"]
    out.append(f"| `int_{bid}` | {s['size']} | {s['cols']}x{s['rows']} | {s['zoom_fit']} | {s['wall_style']} / {s['floor']} | {len(r.items)} | {len(r.posts)} | {len(r.hatch)} | {', '.join(st) or '-'} | {wave} |")
out.append("")
out.append("### B5 pieces per room\n")
out.append("| room | back wall + customer zone (furniture.json ids; `*` = stand-in) | counter |")
out.append("|---|---|---|")
for bid, r in rooms.items():
    ids = []
    cnt = ""
    for it in r.items:
        if it.get("role") == "counter":
            cnt = it["id"]
            continue
        ids.append(it["id"] + ("*" if "stand_in" in it else "") + ("(w)" if it.get("wall") else ""))
    out.append(f"| `int_{bid}` | {', '.join(ids)} | {cnt or '-'} |")
out.append("")
out.append("### B4 one-line days\n")
out.append("| citizen | weekday plan | rest / closed-day plan | other plans |")
out.append("|---|---|---|---|")
def short(blocks):
    parts = []
    for (t, place, act, until) in blocks:
        ps = place.replace("traetoppen.", "T.").replace("hyggebyen.", "H.").replace("farm.", "F.")
        parts.append(("%s " % fh(t) if t is not None else "→ ") + ps.split(".")[-1] if False else ((fh(t) + " " if t is not None else "→ ") + ps))
    return "; ".join(parts)
for npc, pl in PL.PLANS.items():
    names = list(pl.keys())
    main = names[0]
    rest = [n for n in names if n in ("rest", "mon", "sun", "field", "stall", "weekend")]
    other = [n for n in names if n != main and n not in rest]
    out.append(f"| `{npc}` | {main}: {short(pl[main])} | {', '.join(rest) or '-'} | {', '.join(other) or '-'} |")
open("out/tables.md", "w").write("\n".join(out))
print("rows", len(out))
