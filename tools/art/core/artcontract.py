#!/usr/bin/env python3
"""The Traetoppen art contract as data (plan section 6.2). Pure Python: no numpy, no VTK, safe to import anywhere.

One place for the numbers the baker, the exporter and the validators must agree on.  If a number here changes, every
baked asset changes: do not edit it casually (tools/art/README.md explains each value).
"""
from __future__ import annotations
import re

# --- camera / scale -------------------------------------------------------------------------------------------------
ELEV_DEG = 36.0                       # orthographic camera elevation of every world sprite
CAM_HALF_HEIGHT_M = 1.47              # vtk parallel scale of a 256 px character cell
CELL = 256                            # character cell edge in px
PX_PER_M = CELL / (2 * CAM_HALF_HEIGHT_M)   # 87.074 px per metre (props, tiles and characters share it)
PIVOT = (128, 200)                    # ground pivot inside a character cell
BUST_ELEV_DEG = 14.0                  # portrait (bust) camera elevation
DIRECTIONS = ['S', 'SW', 'W', 'NW', 'N', 'NE', 'E', 'SE']   # row order of every sheet, clockwise from the camera
ANGLES = [0, 45, 90, 135, 180, 225, 270, 315]                # camera azimuth of each row

# --- outlines: world sprites use the pack outline, ink is for icons and UI only -------------------------------------
OUTLINE = {'color': (75, 60, 73), 'alpha': .55, 'kernel': 5}   # pack default (warm grey-violet at 55 %)
INK = {'color': (43, 35, 64), 'alpha': .92, 'kernel': 5}       # guide ink #2b2340 (--outline ink; icons/UI)

# --- clips: (name, frames, fps, loop) -------------------------------------------------------------------------------
SPEC = [('idle', 4, 5, True), ('walk', 6, 9, True), ('run', 6, 12, True),
        ('jump', 4, 10, False), ('fall', 3, 6, True), ('land', 3, 11, False),
        ('celebrate', 6, 9, False), ('interact', 4, 9, False), ('hit', 3, 11, False),
        ('sleep', 4, 3, True), ('talk', 4, 6, True)]
FLIGHT = [('takeoff', 4, 10, False), ('hover', 5, 8, True), ('fly', 6, 12, True), ('flight_land', 4, 10, False)]
EXTRA = {'attack': (5, 12, False), 'spin': (8, 14, True)}      # Traetoppen clips, baked only when the rig lists them
FULL_CLIPS = [c[0] for c in SPEC]
FLIGHT_CLIPS = [c[0] for c in FLIGHT]

# clip set -> baked clips (None = every clip of the model); the key is m.clip_set of a builder
CLIP_SETS = {'full': None,
             'npc': ['idle', 'walk', 'talk', 'celebrate', 'interact'],
             'npc_flyer': ['idle', 'hover', 'talk', 'celebrate', 'interact'],
             'farm_animal': ['idle', 'walk', 'run', 'interact', 'sleep', 'hit', 'celebrate'],
             'enemy': ['idle', 'walk', 'run', 'attack', 'hit'],
             'boss': ['idle', 'walk', 'attack', 'hit', 'spin'],
             'critter': ['idle', 'walk', 'run', 'hit', 'sleep'],
             'villager': ['idle', 'walk', 'talk', 'celebrate', 'interact', 'sleep']}
# clip set -> role written to animations.json (plan 6.2: player|npc|enemy|boss|critter|farm_animal)
ROLE_OF_CLIP_SET = {'full': 'player', 'npc': 'npc', 'npc_flyer': 'npc', 'villager': 'npc', 'farm_animal': 'farm_animal',
                    'enemy': 'enemy', 'boss': 'boss', 'critter': 'critter'}

# --- the shipped 12 character pack: never rebuilt into the game tree, never touched by the exporter ------------------
PACK_IDS = ['bat', 'cat', 'bear', 'rabbit', 'fairy', 'monkey', 'capybara', 'fox', 'raccoon', 'penguin', 'hedgehog', 'frog']
ID_PATTERN = r'[a-z0-9_]+'            # a character id is a folder name: lower-case ASCII only (APFS is case-insensitive by default)


def valid_id(name) -> bool:
    """True for a syntactically valid character id: lower-case ASCII [a-z0-9_]+ (pack ids included, `Fox` is not valid)."""
    return re.fullmatch(ID_PATTERN, str(name)) is not None


def classify_id(name) -> str:
    """'pack' (one of the 12 shipped characters, whatever the letter case), 'new' (a valid new id) or 'invalid'.

    The pack check is case-INSENSITIVE on purpose: on a default (case-insensitive) APFS volume `Fox` and `FOX` are the same
    folder as the shipped `fox`.  Anything that is not `[a-z0-9_]+` is 'invalid' (path separators, dots, spaces, capitals).
    """
    s = str(name)
    if s.casefold() in PACK_IDS:
        return 'pack'
    return 'new' if valid_id(s) else 'invalid'

# --- bust portraits (14 degree camera, head and shoulders) ------------------------------------------------------------
# Per-id framing of the 12 pack busts (assets/portraits/<id>.webp).  m.portrait of a builder ({dy, half, dx}) wins over this
# table; an id that is in neither is framed automatically by bake_sprite_atlases.Renderer.fit_bust() (the default window
# half = max(.85, 1.25 k), dy = dx = 0, zoomed out / shifted only as far as needed to clear the top and side borders).
#   half : vtk parallel scale = half the visible HEIGHT in metres (bigger = further away)
#   dy   : focus shift up (+) / down (-) in units of the rig's scale k
#   dx   : focus shift to the camera's right (+) in metres, so the figure moves left in the cell
BUST_FRAMING = {
    # FROZEN results of Renderer.fit_bust() for the six pack busts the default window cut at a border (bat and fairy wings, the
    # tails of cat, fox, raccoon, monkey), rounded; kept here so the shipped busts cannot move when the fit is ever tuned.  The other
    # six (bear rabbit capybara penguin hedgehog frog) are clear of the borders with the default window and stay unlisted.
    # The bat is additionally centred vertically (dy): with the 2.8 m wingspan the whole bat is in view.
    'bat':     {'half': 1.49, 'dy': -0.28, 'dx': 0.03},    # wingspan 2.83 m: whole bat in view, vertically centred
    'fairy':   {'half': 1.02, 'dx': 0.06},                 # wings
    'monkey':  {'dx': 0.16},                               # curled tail
    'fox':     {'dx': 0.20},                               # big tail
    'cat':     {'dx': 0.09},                               # tail
    'raccoon': {'dx': 0.11},                               # ringed tail
}
BUST_MARGIN_M = 0.07                   # clearance fit_bust() keeps to the top and side borders (metres, about 9 px)
BORDER_ALPHA_MAX = 24                  # alpha above this on a checked cell border means the figure is cut by its cell
PORTRAIT_CHECKED_EDGES = ('top', 'left', 'right')   # a bust is cut at the torso by design: only the bottom edge may be opaque

# --- res://assets destinations the exporter may write (plan 6.2).  Nothing else, ever. -------------------------------
# key = path under assets/ ; value = what may live there
CONTRACT_DIRS = {
    'isometric_characters': 'new character folders <id>/ (clip sheets, portrait.webp, animations.json) + manifest_traetoppen.json',
    'portraits': 'bust portraits <id>.webp of the 12 pack characters (plan 6.1/6.2)',
    'iso_tiles': 'terrain atlases + tiles.json',
    'iso_props': 'props + props.json + glow halos',
    'icons/items': 'item icons <item_id>.webp (+ icons.json)',
    'ui/keyart': 'title.webp + title_layers/',
}

# --- encoding -------------------------------------------------------------------------------------------------------
WEBP_QUALITY = 97     # sprites, portraits, key art
WEBP_METHOD = 4       # method 6 is ~2.5x slower for < 2 % smaller files (measured by the art spike)


if __name__ == '__main__':
    import sys
    if len(sys.argv) >= 2 and sys.argv[1] == 'classify':
        for n in sys.argv[2:]:
            print(classify_id(n))                       # one word per id: pack | new | invalid  (produce_all.sh uses this)
    else:
        raise SystemExit('usage: artcontract.py classify ID...   (prints pack | new | invalid for every id)')
