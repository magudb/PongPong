"""Art data tables of the 10 home tiers: ids, the visual brief, platform stage, interior room shapes and the camera fit.

A1-art-home keeps ONLY art numbers here.  Names and flavour text live in localization/home.csv (F1: HOME_TIER_n), costs, days, materials and gates in
lua/data/home_tiers.lua (F1) - the spike's Danish texts and its `upgrade_to_this_tier` money table were dropped on lift (one source, plan CD6).
The numbers that must agree with the content (capacity, floor, wall style, platform rows) are checked against specs/content_contract.json by
validate_features_home.py and tests/sections/art_home.gd; F1's validator rule R19 proves the snapshot against the Lua.
"""
from __future__ import annotations
import math

# (id, what_changes_visually)  - ids are the art ids of the content (lua/data/home_tiers.lua)
TIERS = [
    ('skur', 'lean-to boards, patched tarp, stovepipe'),
    ('hytte', 'honey log walls, stone chimney, porch roof'),
    ('straatag', 'cream plaster, golden thatch, eyebrow window'),
    ('bindingsvaerk', 'half-timber frame, red clay tiles, cross gable'),
    ('gaarden', 'two storeys, yellow plaster, barn wing, dormers'),
    ('taarnhus', 'stone ground floor, round tower, balcony, slate roof'),
    ('landsted', 'symmetrical villa, columns + pediment, mansard roof'),
    ('herregaard', 'brick manor, copper roofs, clock tower'),
    ('borg', 'stone fortress, gatehouse, keep, banners'),
    ('slot', 'cream palace, gold domes, lavender + teal spires'),
]

# platform growth: rows ADDED BEHIND the door row (towards -z); the front/visible edges and all farm coordinates stay identical
PLATFORM_STAGE = [0, 0, 0, 0, 1, 1, 1, 2, 2, 3]            # extra back rows per tier
PLATFORM_STAGES = {0: dict(back_rows=0, tiers=[1, 2, 3, 4]), 1: dict(back_rows=1, tiers=[5, 6, 7]), 2: dict(back_rows=2, tiers=[8, 9]), 3: dict(back_rows=3, tiers=[10])}

FLOOR = {1: 'floor_stone', 2: 'floor_stone', 3: 'floor_plank', 4: 'floor_plank', 5: 'floor_parquet', 6: 'floor_parquet', 7: 'floor_parquet', 8: 'floor_marble', 9: 'floor_marble', 10: 'floor_marble'}
WALL = {1: 'plank', 2: 'plank', 3: 'plank', 4: 'plank', 5: 'paper', 6: 'paper', 7: 'paper', 8: 'marble', 9: 'marble', 10: 'marble'}
# interior floor shape: widths per row z = 0.. (a staircase of non-increasing widths -> only the two back walls are ever needed)
ROWS = {1: [5] * 4, 2: [6] * 5, 3: [7] * 5, 4: [8] * 5 + [4] * 2, 5: [9] * 5 + [5] * 2, 6: [10] * 6 + [5] * 2, 7: [11] * 6 + [6] * 3,
        8: [12] * 7 + [7] * 3, 9: [13] * 7 + [8] * 3 + [4], 10: [14] * 7 + [9] * 3 + [5] * 2}
MAX_FURNITURE = {t: int(sum(ROWS[t]) * .55) for t in ROWS}


def zoom_fit(rows):
    """default camera zoom of the interior at the 1280x720 base: 0.85 x min(1280/W, 720/H), W = (cols+rows) x 64, H = (cols+rows) x 38 + 280 (plan 2.2).
    Tier 1..10: 0.98 0.88 0.83 0.72 0.69 0.63 0.59 0.55 0.51 0.48 (the spike's hand fit 1.55 / 1.0 / 0.72 at 1080p = 1.03 / 0.67 / 0.48 at 720p)."""
    n = max(rows) + len(rows)
    return round(.85 * min(1280 / (n * 64), 720 / (n * 38 + 280)), 2)


ROOM_CONTRACT = {
    'cells': 'floor cells [x, z]: x = column (0 at the left end of a row), z = row (0 = the back row, the door row is the last). +x = screen right-down, +z = screen left-down',
    'windows': 'KEYS NAMED BY THE WALL, VALUES ARE THE OTHER AXIS: windows.z = the x indices of the windows on the z = 0 wall (the back-RIGHT wall, along the first row, so 0 < v < rows[0] - 1); '
               'windows.x = the z indices of the windows on the x = 0 wall (the back-LEFT wall, along the first column, so 0 < v < len(rows) - 1). '
               'windows_by_wall repeats the same two lists under unambiguous names: back_right_z0 (= windows.z), back_left_x0 (= windows.x)',
    'numbers': 'every number is a JSON number and arrives as a FLOAT in Godot (JSON.parse_string): compare with int(v), Array.has(int) is false',
    'door': 'door.cell = [x, z] on the last row, door.dir = [0, 1] (the door faces +z); spawn_cell is the cell in front of it',
    'zoom_fit': 'default interior camera zoom at the 1280x720 base: 0.85 x min(1280/W, 720/H), W = (cols + rows) x 64, H = (cols + rows) x 38 + 280',
}


def room(t):
    rows = ROWS[t]; D = len(rows)
    cells = [[x, z] for z, w in enumerate(rows) for x in range(w)]
    # door: centre of the last row's front edge
    dz = D - 1; dx = rows[-1] // 2
    # windows every 3rd back segment, offset so they never sit in a corner
    wz = [x for x in range(1, rows[0] - 1) if x % 3 == 1]        # x indices of the windows on the z = 0 wall (back-right)  -> stored as windows.z
    wx = [z for z in range(1, D - 1) if z % 3 == 1]              # z indices of the windows on the x = 0 wall (back-left)   -> stored as windows.x
    return {'_contract': ROOM_CONTRACT,
            'tier': t, 'rows': rows, 'cells': cells, 'floor': FLOOR[t], 'wall_style': WALL[t], 'door': {'cell': [dx, dz], 'dir': [0, 1]},
            'spawn_cell': [dx, dz - 1], 'windows': {'z': wz, 'x': wx}, 'windows_by_wall': {'back_right_z0': wz, 'back_left_x0': wx},
            'max_furniture': MAX_FURNITURE[t], 'zoom_fit': zoom_fit(rows)}


def tiers_json(sprite_meta, scaffold_meta):
    """home.json `tiers[]` (addendum 3.5): exterior{day,night,size,pivot,ysort[,night_offset,night_size]}, footprint_*, door_column, height_m, interior, platform,
    scaffold_from_previous{file,size,pivot,ysort}.  No gold, no materials, no Danish text."""
    out = []
    for i, (tid, vis) in enumerate(TIERS, 1):
        m = sprite_meta[str(i)]
        night = m.get('night') or {}
        ext = dict(day=m['file'], night=night.get('file'), size=m['size'], pivot=m['pivot'], ysort=m['ysort'])
        if night:
            ext.update(night_offset=night['offset'], night_size=night['size'], night_blend='add')
        e = dict(tier=i, id=tid, visual_note=vis,
                 footprint_tiles=m['footprint_tiles'], footprint_rect=m['footprint_rect'], door_column=m['door_column'], height_m=m['height_m'],
                 exterior=ext,
                 interior=dict(room=f'rooms/room_t{i:02d}.json', floor=FLOOR[i], wall_style=WALL[i], max_furniture=MAX_FURNITURE[i]),
                 platform=dict(stage=PLATFORM_STAGE[i - 1], back_rows=PLATFORM_STAGE[i - 1]))
        if str(i) in scaffold_meta:
            e['scaffold_from_previous'] = {k: v for k, v in scaffold_meta[str(i)].items() if k in ('file', 'size', 'pivot', 'ysort')}
        out.append(e)
    return out
