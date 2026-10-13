class_name Iso
extends RefCounted
## Single source of truth for 2D world geometry (plan 3.1 / 3.7, decisions D3 and D4). Every system that touches the ground
## plane goes through here, and every number lives in THIS file.
##
## CAMERA FACT (asset contract 6.2): all sprites are baked by an orthographic camera at 36 degrees elevation, 87.074 px per
## metre. A circle on the ground therefore appears as an ellipse whose height / width ratio is sin(36 deg) = 0.588. We call
## that ratio the GROUND SQUASH. Floors are drawn with the same ratio (a diamond W x H with H = W * squash), so a sprite that
## walks "along a tile edge" moves exactly parallel to it.
##
## Gameplay maths (speeds, ranges, swing arcs, enemy detection) is written in GROUND units and converted with
## to_screen() / to_ground(). Ground units == screen pixels horizontally, screen pixels / squash vertically.
##
## Sprites are NEVER scaled individually (D4): there is no SPRITE_SCALE. The camera zoom is the only scale.

## Diamond floor tile of the iso areas (farm, Hyggebyen): the true 36 degree diamond (the art is 128 x 75.2).
const TILE_W := 128
const TILE_H := 76
## Atlas cell of a periodic terrain tile: the diamond plus about 1.4 px overscan on every side (asset contract).
const TILE_CELL_W := 144
const TILE_CELL_H := 84
## Periodic variants per terrain atlas (water: 2 x 2): atlas coords = Vector2i(cell.x % VARIANTS, cell.y % VARIANTS).
const TILE_VARIANTS := 4
## Orthogonal (rectangular) floor tile of the action areas (Moerkeskoven, caves).
const ORTHO_W := 96
const ORTHO_H := 56

## Camera zoom in the 1280 x 720 base viewport. DEFAULT_ZOOM 0.4 is identical on screen to the art spike's 0.6 at 1920 x 1080.
const DEFAULT_ZOOM := 0.4
const ZOOM_MIN := 0.3
const ZOOM_MAX := 0.7

## Review R.12 helper: a sprite-space literal that was tuned while the world spike drew its figures at scale 0.6
## becomes `literal * Iso.S` now that sprites are unscaled (Player2D hurtbox, lantern texture scale, dust offsets ...).
const S := 1.0 / 0.6

## Collision layers as bit VALUES (plan 3.3). The layer names live in project.godot; code uses these constants.
const LAYER_WORLD := 1
const LAYER_PLAYER := 2
const LAYER_NPC := 4
const LAYER_INTERACTABLE := 8
const LAYER_ENEMY := 16
const LAYER_FARM_PLOT := 32
const LAYER_RESOURCE_NODE := 64
const LAYER_GROUND_BLOCK := 128
const LAYER_PLAYER_ATTACK := 256
const LAYER_ENEMY_ATTACK := 512
const LAYER_PICKUP := 1024
## What a walking figure collides with (world + npc + resource nodes + ground blocks) and what a flier collides with.
const MASK_WALKING := 1 + 4 + 64 + 128
const MASK_FLYING := 1 + 4 + 64

## z_index of the layers of an area (plan 3.7).
const Z_BACKDROP := -20
const Z_GROUND := -10
const Z_GROUND_FX := -9
const Z_SKIRTS := -9
const Z_FLYING := 20

# The pack's 8 direction rows: S, SW, W, NW, N, NE, E, SE (screen-relative).
const DIR8_NAMES: Array[String] = ["S", "SW", "W", "NW", "N", "NE", "E", "SE"]
# Tile step (layout DIAMOND_DOWN: +x = screen SE, +y = screen SW) to the tile "in front" per direction row.
const DIR8_TO_CELL_STEP: Array[Vector2i] = [
	Vector2i(1, 1),    # S
	Vector2i(0, 1),    # SW
	Vector2i(-1, 1),   # W
	Vector2i(-1, 0),   # NW
	Vector2i(-1, -1),  # N
	Vector2i(0, -1),   # NE
	Vector2i(1, -1),   # E
	Vector2i(1, 0),    # SE
]
# Same for orthogonal areas (plain screen-axis neighbours + diagonals).
const DIR8_TO_ORTHO_STEP: Array[Vector2i] = [
	Vector2i(0, 1), Vector2i(-1, 1), Vector2i(-1, 0), Vector2i(-1, -1),
	Vector2i(0, -1), Vector2i(1, -1), Vector2i(1, 0), Vector2i(1, 1),
]


## Ground squash: TILE_H / TILE_W (0.59375; sin 36 deg is 0.5878, the difference is the 1.1 percent of the art contract).
static func squash() -> float:
	return float(TILE_H) / float(TILE_W)


static func to_screen(ground: Vector2) -> Vector2:
	return Vector2(ground.x, ground.y * squash())


static func to_ground(screen: Vector2) -> Vector2:
	return Vector2(screen.x, screen.y / squash())


static func dir8_of(screen_dir: Vector2) -> int:
	## Same maths as IsoChibiSprite2D.set_facing_direction (S=0, then clockwise: SW, W, NW, N, NE, E, SE).
	var cw: float = fposmod(-atan2(screen_dir.x, screen_dir.y), TAU)
	return wrapi(int(round(cw / (PI / 4.0))), 0, 8)


static func dir8_vector(index: int) -> Vector2:
	## Unit SCREEN vector of a direction row.
	var a: float = float(index) * (PI / 4.0)
	return Vector2(-sin(a), cos(a))


static func ground_dist(a: Vector2, b: Vector2) -> float:
	return to_ground(b - a).length()


# ------------------------------------------------------------------ cell maths (no TileMapLayer needed)

## Centre of an iso cell in layer-local coordinates, layout DIAMOND_DOWN. Equals TileMapLayer.map_to_local.
static func iso_center(c: Vector2i) -> Vector2:
	return Vector2(float(c.x - c.y + 1) * TILE_W * 0.5, float(c.x + c.y + 1) * TILE_H * 0.5)


## Inverse of iso_center: the cell whose diamond contains the layer-local point. Equals TileMapLayer.local_to_map.
static func iso_cell(p: Vector2) -> Vector2i:
	var u: float = p.x / (TILE_W * 0.5)
	var v: float = p.y / (TILE_H * 0.5)
	return Vector2i(floori((u + v) * 0.5 - 1.0 + 0.5), floori((v - u) * 0.5 + 0.5))


static func ortho_center(c: Vector2i) -> Vector2:
	return Vector2((float(c.x) + 0.5) * ORTHO_W, (float(c.y) + 0.5) * ORTHO_H)


static func ortho_cell(p: Vector2) -> Vector2i:
	return Vector2i(floori(p.x / ORTHO_W), floori(p.y / ORTHO_H))


## Diamond corners of one iso cell: top, right, bottom, left.
static func iso_diamond(c: Vector2i, grow: float = 0.0) -> PackedVector2Array:
	var p: Vector2 = iso_center(c)
	var hw: float = TILE_W * 0.5 + grow
	var hh: float = TILE_H * 0.5 + grow * squash()
	return PackedVector2Array([p + Vector2(0, -hh), p + Vector2(hw, 0), p + Vector2(0, hh), p + Vector2(-hw, 0)])


## Parallelogram footprint of fx x fy cells whose FRONT (south-most, largest x and y) cell is `front`.
## Corners: top (north), right (east), bottom (south), left (west). L, B, R of the strips formula are left, bottom, right.
static func iso_footprint(front: Vector2i, fx: int, fy: int) -> PackedVector2Array:
	var mn := Vector2i(front.x - fx + 1, front.y - fy + 1)
	var top: Vector2 = iso_center(mn) + Vector2(0, -TILE_H * 0.5)
	var right: Vector2 = iso_center(Vector2i(front.x, mn.y)) + Vector2(TILE_W * 0.5, 0)
	var bottom: Vector2 = iso_center(front) + Vector2(0, TILE_H * 0.5)
	var left: Vector2 = iso_center(Vector2i(mn.x, front.y)) + Vector2(-TILE_W * 0.5, 0)
	return PackedVector2Array([top, right, bottom, left])


## Centre of that footprint: where a prop's ground-origin pivot sits (props.json: "pivot = ground origin = footprint centre").
static func iso_footprint_center(front: Vector2i, fx: int, fy: int) -> Vector2:
	var fp: PackedVector2Array = iso_footprint(front, fx, fy)
	return (fp[0] + fp[2]) * 0.5


static func ortho_rect(c: Vector2i, cw: int = 1, ch: int = 1) -> PackedVector2Array:
	var o := Vector2(float(c.x) * ORTHO_W, float(c.y) * ORTHO_H)
	var s := Vector2(float(cw) * ORTHO_W, float(ch) * ORTHO_H)
	return PackedVector2Array([o, o + Vector2(s.x, 0), o + s, o + Vector2(0, s.y)])


## Periodic atlas coordinate of a cell (asset contract: Vector2i(cell.x % 4, cell.y % 4); water uses 2).
static func atlas_coords(c: Vector2i, variants: Vector2i = Vector2i(TILE_VARIANTS, TILE_VARIANTS)) -> Vector2i:
	return Vector2i(posmod(c.x, maxi(variants.x, 1)), posmod(c.y, maxi(variants.y, 1)))
