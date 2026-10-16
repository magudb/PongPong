class_name DungeonRng
extends RefCounted
## ANALYST 6 prototype: the OWN deterministic PRNG of the dungeon generator (sfc32 + FNV-1a seed hash).
## Why own: the engine RNG is PCG32 but its derived outputs (randf, randfn, shuffle, rand_weighted) are implementation details
## that may change between engine versions (see tech_gen.md section 1). This file uses ONLY integer + - ^ << >> & | on values kept in
## [0, 2^32), so no 64-bit overflow, no float, no libm: the stream is identical on every platform and every engine version.
## Seed derivation hash_key(save_id, day, floor) is FNV-1a (UTF-8 bytes) + murmur3 fmix32 with an overflow-free 32-bit multiply.

const M32: int = 0xFFFFFFFF

var a: int = 0
var b: int = 0
var c: int = 0
var d: int = 1


func _init(seed_value: int = 0) -> void:
	seed_with(seed_value)


## (x * y) mod 2^32 for x, y in [0, 2^32) without ever leaving the signed 64-bit range (xl * y < 2^48, xh * y < 2^48).
static func mul32(x: int, y: int) -> int:
	return (((x & 0xFFFF) * y) + ((((x >> 16) * y) & 0xFFFF) << 16)) & 0xFFFFFFFF


static func fmix32(h0: int) -> int:
	var h: int = h0 & 0xFFFFFFFF
	h ^= h >> 16
	h = mul32(h, 0x85EBCA6B)
	h ^= h >> 13
	h = mul32(h, 0xC2B2AE35)
	h ^= h >> 16
	return h


## The seed of floor `floor_no` of day `day` in save `save_id`: 62 bit, non-negative. save_id is the per-save world seed as text.
## FNV-1a over the UTF-8 bytes (two lanes with different offset bases), then day and floor are folded into BOTH lanes through fmix32 and
## lane 1 is chained into lane 2, so changing the day, the floor or one character of the save id flips about half of the 62 bits.
static func hash_key(save_id: String, day: int, floor_no: int) -> int:
	var h1: int = 0x811C9DC5
	var h2: int = 0x9747B28C
	for byte in save_id.to_utf8_buffer():
		h1 = ((h1 ^ byte) * 16777619) & 0xFFFFFFFF
		h2 = ((h2 ^ byte) * 16777619) & 0xFFFFFFFF
	var d_lo: int = day & 0xFFFFFFFF
	var d_hi: int = (day >> 32) & 0xFFFFFFFF
	var f_lo: int = floor_no & 0xFFFFFFFF
	h1 = fmix32(h1 ^ mul32(d_lo, 0x9E3779B1))
	h1 = fmix32(h1 ^ mul32(f_lo, 0x85EBCA77) ^ d_hi)
	h2 = fmix32(h2 ^ mul32(d_lo, 0xC2B2AE3D) ^ h1)
	h2 = fmix32(h2 ^ mul32(f_lo, 0x27D4EB2F) ^ mul32(h1, 0x165667B1))
	return (((h2 & 0x3FFFFFFF) << 32) | h1) & 0x3FFFFFFFFFFFFFFF


func seed_with(s: int) -> void:
	a = s & 0xFFFFFFFF
	b = (s >> 32) & 0xFFFFFFFF
	c = 0xB7E15162
	d = 1
	for i in 16:
		next_u32()


func next_u32() -> int:
	var t: int = (a + b + d) & 0xFFFFFFFF
	d = (d + 1) & 0xFFFFFFFF
	a = b ^ (b >> 9)
	b = (c + (c << 3)) & 0xFFFFFFFF
	c = (((c << 21) & 0xFFFFFFFF) | (c >> 11))
	c = (c + t) & 0xFFFFFFFF
	return t


## Uniform integer in [0, n), n in [1, 2^32]: rejection sampling, so there is no modulo bias.
func below(n: int) -> int:
	if n <= 1:
		return 0
	var limit: int = 4294967296 - (4294967296 % n)
	var x: int = next_u32()
	while x >= limit:
		x = next_u32()
	return x % n


## Uniform integer in [lo, hi] (inclusive).
func range_i(lo: int, hi: int) -> int:
	if hi <= lo:
		return lo
	return lo + below(hi - lo + 1)


## True with probability permille / 1000 (integer, exact).
func chance(permille: int) -> bool:
	return below(1000) < permille


## True with probability bp / 10000 (basis points, the unit of lua/data/loot_tables.lua).
func chance_bp(bp: int) -> bool:
	return below(10000) < bp


func pick(arr: Array) -> Variant:
	return arr[below(arr.size())]


## Fisher-Yates, deterministic (the engine's Array.shuffle uses the GLOBAL generator and cannot be seeded per call).
func shuffle(arr: Array) -> void:
	for i in range(arr.size() - 1, 0, -1):
		var j: int = below(i + 1)
		var tmp: Variant = arr[i]
		arr[i] = arr[j]
		arr[j] = tmp


## Index drawn with integer weights (weights >= 0, sum > 0).
func weighted(weights: Array) -> int:
	var total: int = 0
	for w in weights:
		total += int(w)
	var r: int = below(total)
	for i in weights.size():
		r -= int(weights[i])
		if r < 0:
			return i
	return weights.size() - 1


## Smooth 1-D value noise in [-1000, 1000] (integer only): lattice values from a hash of (stream, index), cubic smoothstep, integer lerp.
## `x_milli` is the position in 1/1000 lattice units. Same output everywhere (no float, no sin).
@warning_ignore("integer_division")
static func noise1(stream: int, x_milli: int) -> int:
	var i: int = x_milli / 1000
	var f: int = x_milli - i * 1000            # 0..999
	var s: int = (f * f * (3000 - 2 * f)) / 1000000    # smoothstep(f) * 1000, 0..1000
	var v0: int = (fmix32((stream ^ mul32(i & 0xFFFFFFFF, 0x9E3779B1)) & 0xFFFFFFFF) % 2001) - 1000
	var v1: int = (fmix32((stream ^ mul32((i + 1) & 0xFFFFFFFF, 0x9E3779B1)) & 0xFFFFFFFF) % 2001) - 1000
	return v0 + ((v1 - v0) * s) / 1000
