#!/usr/bin/env python3
"""Quality-gate composites of the environment art (P22 task 5): scenes built ONLY from the shipped assets (tiles + props + character sheets + backdrops), laid out the way
the Godot area builder lays them, viewed as CONTACT SHEETS (never single frames):

  farm        the treetop farm: deck, field with all eight crops, coop / barn / animal house, orchard, bench, mailbox, lanterns, the hanging bridge, skirts   (1920 x 1080 @ zoom .6)
  hyggebyen   the lavender torv: fountain, the seven new buildings, market stalls, wells, lanterns, blossoms, beehives                                            (1280 x 720 @ zoom .4)
  forest      Moerkeskoven by night: the ortho floor, the lit path, crowns, pond with lilies, runestone, chest, bushes with eyes, the Hulen, lantern light      (1280 x 720)
  tiles       every terrain, mixed in the engine's lattice (seam check): grass + flowers, forest floor + glow, ... with and without the grade

  python tools/art/environment/compose_scenes.py [--root assets] --out DIR [farm hyggebyen forest tiles]

The Pillow compositor is a stand-in for the engine (it mirrors scene.py / the area builder: cell (cx, cy) -> screen ((cx - cy) * 64, (cx + cy) * 38) for iso, (cx * 96, cy * 56)
for ortho, sprites with their pivot on the cell, y-sorted): what it shows is what the baked art looks like, not what the engine does (that is the windowed screenshot).
"""
import argparse, math, os, random, sys
from pathlib import Path
import numpy as np
from PIL import Image, ImageDraw, ImageFont

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE.parent / 'core'))
from scene import IsoScene, Assets, _additive      # noqa: E402

REPO = HERE.parents[2]


def font(sz):
    for p in ['/System/Library/Fonts/Supplemental/Arial Rounded Bold.ttf', '/System/Library/Fonts/Helvetica.ttc']:
        if os.path.exists(p):
            return ImageFont.truetype(p, sz)
    return ImageFont.load_default()


def vignette(im, strength=.35, tint=(0, 0, 0)):
    w, h = im.size
    y, x = np.mgrid[0:h, 0:w].astype(np.float32)
    d = np.sqrt(((x - w / 2) / (w / 2)) ** 2 + ((y - h / 2) / (h / 2)) ** 2)
    a = np.clip((d - .55) / .75, 0, 1) ** 1.6 * strength
    lay = Image.new('RGBA', im.size, tint + (0,)); lay.putalpha(Image.fromarray(np.uint8(a * 255)))
    out = im.convert('RGBA'); out.alpha_composite(lay)
    return out


def multiply(im, rgb, amount=1.0):
    a = np.asarray(im.convert('RGB'), np.float32) / 255
    k = np.array(rgb, np.float32) / 255
    a = a * (1 - amount + amount * k)
    return Image.fromarray(np.uint8(np.clip(a * 255, 0, 255)), 'RGB').convert('RGBA')


def backdrop(root, theme, size, cam_y=.5):
    """sky + far canopy of a theme at `size` (a flat approximation of the two Parallax2D layers)."""
    sk = Image.open(Path(root) / 'backdrops' / f'{theme}_sky.webp').convert('RGBA').resize(size, Image.LANCZOS)
    far = Image.open(Path(root) / 'backdrops' / f'{theme}_far.webp').convert('RGBA')
    sc = size[0] / far.width * 1.2
    far = far.resize((int(far.width * sc), int(far.height * sc)), Image.LANCZOS)
    tile = Image.new('RGBA', (far.width * 2, far.height)); tile.paste(far, (0, 0)); tile.paste(far, (far.width, 0))
    sk.alpha_composite(tile.crop((0, 0, size[0], far.height)), (0, int(size[1] * cam_y)) if False else (0, int(size[1] * .38)))
    return sk


def chars_roots(root):
    return [Path(root) / 'isometric_characters']


def assets(root):
    shadow = Path(root) / 'isometric_characters' / 'shadow.png'
    return Assets(tiles=f'{root}/iso_tiles', props=f'{root}/iso_props', chars=chars_roots(root), shadow=str(shadow) if shadow.exists() else None)


def try_char(sc, cid, *a, **k):
    try:
        sc.char(cid, *a, **k)
    except (FileNotFoundError, KeyError):
        pass


# ---------------------------------------------------------------------------------------------------------------- farm
def farm(root):
    A = assets(root)
    W, H = 3200, 1800
    sc = IsoScene(A, W, H, origin=(1600, 380)); N = 17
    for cx in range(N):
        for cy in range(N):
            edge = cx in (0, N - 1) or cy in (0, N - 1)
            t = 'deck_farm' if edge else ('grass_flowers' if (cx * 5 + cy * 3) % 13 == 0 else 'grass')
            if 8 <= cx <= 13 and 5 <= cy <= 11 and not edge:
                t = 'soil_tilled'
            if 8 <= cx <= 13 and cy == 8:
                t = 'soil_watered'
            if cy in (13, 14) and 3 <= cx <= 15:
                t = 'path_dirt'
            if cx in (4, 5) and 2 <= cy <= 14:
                t = 'path_dirt'
            if 2 <= cx <= 4 and 11 <= cy <= 13 and False:
                t = 'water_0'
            sc.tile(t, cx, cy)
    for cx in range(N):
        sc.prop('platform_sw', cx, N - 1)
    for cy in range(N - 1):
        sc.prop('platform_se', N - 1, cy)
    sc.prop('platform_corner', N - 1, N - 1)
    sc.prop('house_farm', 3.0, 2.2)
    sc.prop('bed', 2.8, 3.9); sc.prop('mailbox_red', 5.4, 3.6); sc.prop('signpost', 6.2, 12.4); sc.prop('bench', 7.0, 12.1)
    for (x, y, v) in [(1.4, 1.6, 'tree_oak_farm'), (14.5, 1.5, 'tree_oak_farm_b'), (1.8, 12.2, 'apple_tree'), (3.4, 14.8, 'apple_tree'), (15.0, 13.2, 'apple_tree'), (15.2, 5.2, 'tree_oak_farm')]:
        sc.prop(v, x, y)
    for (x, y, v) in [(6.4, 1.5, 'bush_farm'), (9.2, 2.2, 'bush_berry'), (3.0, 7.4, 'bush_farm'), (12.5, 14.6, 'rock_mossy'), (15.3, 9.0, 'rock_grey')]:
        sc.prop(v, x, y)
    sc.prop('lantern_post', 6.0, 7.0); sc.prop('lantern_post', 6.0, 13.0); sc.prop('lantern_post', 14.0, 13.0); sc.prop('scarecrow', 11.0, 4.0)
    # animals' corner: coop, barn, animal house with the wander yard in front
    sc.prop('coop_small', 12.4, 16.0 - .4); sc.prop('barn_small', 6.4, 16.0); sc.prop('animal_house', 15.2, 11.6)
    for cx in range(8, 15):
        sc.prop('fence_x', cx, 4.45); sc.prop('fence_x', cx, 11.55)
    for cy in range(5, 12):
        sc.prop('fence_z', 7.45, cy)
    sc.prop('fence_gate_x', 7.5, 4.45)
    kinds = ['turnip', 'carrot', 'strawberry', 'sunflower', 'catnip', 'glow_berry', 'pumpkin', 'moonflower']
    for j, cy in enumerate(range(5, 12)):
        for i, cx in enumerate(range(8, 14)):
            st = (i + j) % 4
            if cy == 8:
                st = 1 if i % 2 else 2
            sc.prop(f'crop_{kinds[(i * 2 + j) % len(kinds)]}_{st}', cx, cy)
    for x, y in ((4.5, 5.5), (4.5, 8.5), (4.5, 11.5)):
        sc.prop('paw_prints', x, y)
    sc.prop('chest_closed', 3.0, 5.8)
    try_char(sc, 'fox', 5.2, 9.0, 'idle', 1, 0)
    try_char(sc, 'hen', 14.0, 12.8, 'idle', 2, 3); try_char(sc, 'chick', 13.2, 12.4, 'idle', 1, 5); try_char(sc, 'lamb', 11.0, 12.6, 'idle', 1, 6)
    try_char(sc, 'fairy_mayor', 7.6, 9.8, 'hover', 2, 7)
    im = sc.render()
    bg = backdrop(root, 'hyggebyen', (W, H))        # the farm's own backdrop is N03's (wave 5): the lavender dusk stands in for the preview
    bg = multiply(bg, (255, 248, 232), .6)
    bg.alpha_composite(im)
    return vignette(multiply(bg.resize((1920, 1080), Image.LANCZOS), (255, 247, 232), .35), .18)


# ---------------------------------------------------------------------------------------------------------------- hyggebyen
def hyggebyen(root):
    A = assets(root)
    W, H = 2560, 1440
    sc = IsoScene(A, W, H, origin=(1280, 150)); N = 17
    for cx in range(N):
        for cy in range(N):
            t = 'grass_hyggebyen_flowers' if (cx * 3 + cy * 5) % 9 == 0 else 'grass_hyggebyen'
            if 5 <= cx <= 11 and 5 <= cy <= 11:
                t = 'cobble_hyggebyen'
            if cx == 8 and cy > 11:
                t = 'cobble_hyggebyen'
            if cy == 8 and (cx < 5 or cx > 11):
                t = 'cobble_hyggebyen'
            sc.tile(t, cx, cy)
    sc.prop('fountain', 8.0, 8.0)
    sc.prop('house_town_hall', 8.4, 2.6)
    sc.prop('house_bakery', 13.6, 3.2); sc.prop('house_seedshop', 3.0, 3.4); sc.prop('house_smithy', 14.8, 8.8)
    sc.prop('house_animalstore', 13.4, 13.4); sc.prop('tower_wizard', 2.4, 9.6); sc.prop('house_king_treetop', 8.4, -0.6)
    sc.prop('market_stall', 5.2, 12.4); sc.prop('market_stall_furniture', 7.2, 13.2); sc.prop('market_stall_tailor', 9.2, 13.2)
    sc.prop('well', 4.4, 6.2); sc.prop('plank_stack', 2.4, 13.6); sc.prop('wheat_sack', 11.6, 13.7); sc.prop('wheat_sack', 12.0, 14.2)
    for (x, y, v) in ((5.0, 4.8, 'lantern_post_rose'), (11.2, 4.8, 'lantern_post_lavender'), (5.0, 11.4, 'lantern_post_mint'), (11.4, 11.4, 'lantern_post_rose')):
        sc.prop(v, x, y)
    for x, y in ((1.2, 6.0), (15.6, 12.0), (1.6, 15.0), (10.4, 0.8), (6.2, 0.6)):
        sc.prop('tree_blossom_hyggebyen', x, y)
    for x, y in ((15.5, 15.3), (15.0, 15.7), (14.4, 16.0)):
        sc.prop('beehive_stand', x, y)
    for x, y in ((7.0, 5.0), (8.0, 5.0), (9.0, 5.0)):
        sc.prop('stone_path_a', x, y)
    sc.prop('stone_path_b', 8.0, 4.0); sc.prop('stone_path_c', 6.0, 2.6)
    sc.prop('bench', 5.6, 8.0); sc.prop('signpost', 9.0, 11.8); sc.prop('roof_patch', 12.6, 4.6); sc.prop('mailbox_red', 4.0, 12.0)
    for (x, y, v) in ((3.4, 14.6, 'bush_berry'), (13.0, 7.6, 'bush_farm')):
        sc.prop(v, x, y)
    cast = [('fairy_mayor', 7.2, 3.6, 'hover', 2, 7), ('fairy_baker', 12.4, 4.4, 'hover', 1, 6), ('fairy_shopkeeper', 4.6, 4.6, 'talk', 1, 4), ('mouse_pippin', 9.6, 9.4, 'talk', 2, 3),
            ('raccoon_smith', 13.4, 9.6, 'idle', 2, 5), ('rabbit_farmer', 12.2, 13.6, 'idle', 1, 6), ('fairy_wizard', 3.8, 9.6, 'hover', 0, 2), ('penguin_postman', 6.2, 9.4, 'walk', 1, 6),
            ('fox', 8.0, 10.4, 'idle', 1, 0), ('fairy_king', 8.6, 1.0, 'hover', 3, 7)]
    for cid, x, y, clip, fr, d in cast:
        try_char(sc, cid, x, y, clip, fr, d)
    im = sc.render()
    bg = backdrop(root, 'hyggebyen', (W, H))
    bg.alpha_composite(im)
    out = bg.resize((1280, 720), Image.LANCZOS)
    return vignette(multiply(out, (255, 240, 246), .25), .2)


# ---------------------------------------------------------------------------------------------------------------- forest (ortho, night)
GRADE = (0x4d / 255, 0x5e / 255, 0x85 / 255)


def tint(im, rgb):
    a = np.asarray(im, np.float32); a[..., :3] *= np.array(rgb, np.float32)[None, None, :]
    return Image.fromarray(np.uint8(np.clip(a, 0, 255)), 'RGBA')


def paste_additive(canvas, im, x, y, strength=1.0):
    _additive(canvas, im, int(x), int(y), strength)


def forest(root):
    A = assets(root)
    COLS, ROWS = 34, 24                                  # cells; 96 x 56 each
    W, H = COLS * 96 + 400, ROWS * 56 + 600
    ox, oy = 200, 420
    canvas = Image.new('RGBA', (W, H), (0x1c, 0x21, 0x38, 255))
    rng = random.Random(8)

    def otile(tid, cx, cy):
        m = A.tmeta[tid]; P = m['variants'][0]; cw, ch = m['cell']
        a = A.img(A.tile_root / m['file']); i, j = cx % P, cy % P
        t = a.crop((i * cw, j * ch, (i + 1) * cw, (j + 1) * ch))
        return tint(t, GRADE)

    # ground: forest floor with glow cells, a winding path (cells), a pond (bog)
    def path_y(cx):
        return 15 + 4.2 * math.sin(cx / 5.2) - cx * .12
    pond = (7.0, 6.0, 4.4, 3.2)
    cells = {}
    for cy in range(ROWS):
        for cx in range(COLS):
            t = 'forest_floor_glow_o' if rng.random() < .13 else 'forest_floor_o'
            if abs(cy - path_y(cx)) < 1.7:
                t = 'moss_path_o'
            if ((cx - pond[0]) / pond[2]) ** 2 + ((cy - pond[1]) / pond[3]) ** 2 < 1:
                t = 'bog_o'
            cells[(cx, cy)] = t
            tt = otile(t, cx, cy)
            canvas.alpha_composite(tt, (ox + cx * 96 + 48 - tt.width // 2, oy + cy * 56 + 28 - tt.height // 2))
    pm = A.pmeta

    def sprite(pid, cx, cy, ox_=0.0, oy_=0.0, emissive=False, additive=False, strength=1.0):
        im, m = A.prop(pid)
        x = ox + (cx + .5 + ox_) * 96; y = oy + (cy + .5 + oy_) * 56
        px, py = m['pivot']
        pos = (int(x - px), int(y - py))
        if additive or m.get('blend') == 'add':
            paste_additive(canvas, im, pos[0], pos[1], strength)
        else:
            canvas.alpha_composite(tint(im, GRADE) if not emissive else im, pos) if pos[0] >= 0 and pos[1] >= 0 else None
        return x, y

    # ground decals first (ring, lilies, ripple, sheen), then y-sorted objects
    sprite('cave_ring', 27.2, 15.5)
    sprite('hulen_eyes', 27.2, 15.0, additive=True, strength=.9)
    sprite('pond_sheen', 6.6, 5.6, additive=True, strength=.7)
    for x, y in ((5.2, 6.6), (7.6, 5.2), (9.0, 7.2)):
        sprite('pond_lily', x, y)
    sprite('pond_ripple', 8.0, 6.4, additive=True, strength=.6)
    objs = []
    # rim crowns around the clearing + a few free ones
    big = ['crown_l_a', 'crown_l_b']
    rim = [(2, 2, 'l'), (8, 1, 'm'), (15, 0, 'l'), (22, 1, 'm'), (29, 2, 'l'), (33, 6, 'm'), (0, 9, 'l'), (1, 18, 'm'), (4, 23, 'l'), (11, 23, 's'), (19, 23, 'l'), (26, 23, 'm'),
           (32, 20, 'l'), (33, 12, 's'), (12, 4, 's'), (23, 6, 'm'), (15, 21, 's')]
    for i, (cx, cy, s) in enumerate(rim):
        objs.append((cy + 1, f'crown_{s}_{"ab"[i % 2]}', cx, cy + 1, False))
    objs += [(11, 'rock_dark', 13.0, 11.0, False), (15, 'rock_dark', 24.4, 18.5, False), (17, 'bush_forest', 6.0, 17.0, False), (12.6, 'bush_eyes_a', 20.5, 12.5, False),
             (16.2, 'bush_eyes_b', 7.2, 16.2, False), (12.3, 'runestone_dormant', 13.0, 12.3, False), (9.1, 'chest_noegle', 10.0, 8.6, True),
             (10, 'cave_stone_a', 25.0, 14.2, False), (10, 'cave_stone_b', 29.4, 14.6, False), (10, 'cave_stone_c', 25.6, 17.6, False), (10, 'cave_stone_d', 29.0, 17.2, False), (10, 'cave_stone_e', 27.2, 18.4, False),
             (11, 'glowmush_teal', 17.6, 14.4, False), (11, 'glowmush_pink', 21.8, 17.4, False), (11, 'glowmush_teal', 6.0, 19.0, False), (11, 'glowmush_blue', 28.0, 9.4, False)]
    objs.sort(key=lambda o: o[0])
    emissive = {'glowmush_teal', 'glowmush_pink', 'glowmush_blue', 'chest_noegle'}
    for _, pid, cx, cy, em in objs:
        sprite(pid, cx - .5, cy - .5, emissive=(pid in emissive))
        if pid.startswith('glowmush'):
            _, m = A.prop(pid)
            if 'glow' in m:
                g = A.img(A.prop_root / m['glow']['file'])
                x = ox + cx * 96; y = oy + cy * 56
                paste_additive(canvas, g, x - m['pivot'][0] + m['glow']['center'][0] - g.width / 2, y - m['pivot'][1] + m['glow']['center'][1] - g.height / 2, .75)
    sprite('rune_glow', 12.5, 11.8, additive=True, strength=.0)         # dormant: dark
    sprite('eyes_glow', 19.6, 11.2, additive=True, strength=.0)
    # the player with the lantern: unshaded fox + lantern light on the path
    px_cell = (16.0, path_y(16))
    x = ox + (px_cell[0] + .5) * 96; y = oy + (px_cell[1] + .5) * 56
    ll = A.img(A.prop_root / A.pmeta['lantern_light']['file'])
    light = ll.resize((int(630 * 2 * .6 * 1.0), int(630 * 2 * .6 * 1.0)), Image.LANCZOS)     # radius 630 world px at the sketch scale, soft
    la = np.asarray(light.convert('RGB'), np.float32)[..., 0] / 255.0
    arr = np.asarray(canvas, np.float32) / 255
    x0, y0 = int(x - light.width / 2), int(y - 40 - light.height / 2)
    sub = arr[max(y0, 0):y0 + light.height, max(x0, 0):x0 + light.width, :3]
    lx0, ly0 = max(-x0, 0), max(-y0, 0)
    mm = la[ly0:ly0 + sub.shape[0], lx0:lx0 + sub.shape[1], None]
    # final = albedo x (ambient + E x lightcolour x v) with E = .10 at ffe9a8: the canvas already holds albedo x ambient, so add albedo x E x colour x v
    base_alb = sub / np.array(GRADE, np.float32)[None, None, :]
    sub += np.clip(base_alb * np.array([1.0, .91, .66], np.float32)[None, None, :] * .10 * mm * 3.2, 0, 1)
    arr[max(y0, 0):y0 + light.height, max(x0, 0):x0 + light.width, :3] = np.clip(sub, 0, 1)
    canvas = Image.fromarray(np.uint8(arr * 255), 'RGBA')
    try:
        fr = A.char_frame('fox', 'idle', 1, 0)
        canvas.alpha_composite(fr, (int(x - 128), int(y - 200)))
    except (FileNotFoundError, KeyError):
        pass
    # fireflies and mist
    ff = A.img(A.prop_root / A.pmeta['firefly_dot']['file'])
    for _ in range(46):
        paste_additive(canvas, ff, rng.uniform(300, W - 300), rng.uniform(500, H - 300), rng.uniform(.4, 1.0))
    mist = A.img(A.prop_root / A.pmeta['mist_patch_a']['file']).copy()
    mist.putalpha(mist.getchannel('A').point(lambda v: int(v * .06)))
    canvas.alpha_composite(mist, (400, 1000)); canvas.alpha_composite(mist, (1200, 700))
    crop = canvas.crop((ox + 5 * 96, oy + 3 * 56 - 200, ox + 5 * 96 + 2560, oy + 3 * 56 - 200 + 1440))
    out = crop.resize((1280, 720), Image.LANCZOS)
    return vignette(out, .55, (8, 10, 24))


# ---------------------------------------------------------------------------------------------------------------- tiles
def tiles_sheet(root):
    A = assets(root)
    ids = [('grass+grass_flowers', 'iso', None), ('grass_hyggebyen+grass_hyggebyen_flowers', 'iso', None), ('forest_floor+forest_floor_glow', 'iso', None),
           ('forest_floor_o+forest_floor_glow_o', 'ortho', GRADE), ('path_dirt+deck_farm', 'iso', None), ('cobble_hyggebyen+grass_hyggebyen', 'iso', None),
           ('moss_path_o+forest_floor_o', 'ortho', GRADE), ('cave_floor_o+crystal_floor_o', 'ortho', (0x34 / 255, 0x3b / 255, 0x5c / 255))]
    cols, rows = 8, 5
    blocks = []
    for ids_s, proj, grade in ids:
        names = ids_s.split('+'); rng = random.Random(3)
        if proj == 'iso':
            w, h = (cols + rows) * 64 + 80, (cols + rows) * 38 + 60
        else:
            w, h = cols * 96 + 16, rows * 56 + 8
        im = Image.new('RGBA', (w, h), (0, 0, 0, 0))
        cells = sorted([(cx, cy) for cy in range(rows) for cx in range(cols)], key=lambda c: (c[0] + c[1], c[0]) if proj == 'iso' else (c[1], c[0]))
        for cx, cy in cells:
            tid = names[rng.randrange(len(names))]
            m = A.tmeta[tid]; P = m['variants'][0]; cw, ch = m['cell']
            a = A.img(A.tile_root / m['file']); t = a.crop(((cx % P) * cw, (cy % P) * ch, (cx % P + 1) * cw, (cy % P + 1) * ch))
            if grade:
                t = tint(t, grade)
            if proj == 'iso':
                x = rows * 64 + 40 + (cx - cy) * 64 - cw // 2; y = 30 + (cx + cy) * 38 + 38 - ch // 2
            else:
                x = 8 + cx * 96 + 48 - cw // 2; y = 4 + cy * 56 + 28 - ch // 2
            im.alpha_composite(t, (int(x), int(y)))
        blocks.append((ids_s, im))
    bw = max(b.width for _, b in blocks); bh = max(b.height for _, b in blocks) + 24
    sheet = Image.new('RGBA', (bw * 2, bh * ((len(blocks) + 1) // 2)), (232, 228, 220, 255)); d = ImageDraw.Draw(sheet); f = font(18)
    for k, (n, b) in enumerate(blocks):
        x, y = (k % 2) * bw, (k // 2) * bh
        d.text((x + 8, y + 3), n, fill=(43, 35, 64, 255), font=f)
        sheet.alpha_composite(b, (x, y + 24))
    return sheet


SCENES = {'farm': (farm, 'compose_farm.png'), 'hyggebyen': (hyggebyen, 'compose_hyggebyen.png'), 'forest': (forest, 'compose_forest.png'), 'tiles': (tiles_sheet, 'compose_tiles.png')}


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument('names', nargs='*', default=list(SCENES)); ap.add_argument('--root', default=str(REPO / 'assets')); ap.add_argument('--out', required=True)
    a = ap.parse_args()
    Path(a.out).mkdir(parents=True, exist_ok=True)
    for n in a.names:
        fn, name = SCENES[n]
        im = fn(a.root)
        im.convert('RGB').save(Path(a.out) / name)
        print(name, im.size, flush=True)


if __name__ == '__main__':
    main()
