class_name SocialRng
extends RefCounted
## Portable deterministic rolls for the social layer (package S-core). NOT String.hash() (djb2-like: "a|1".hash() and "a|2".hash() differ by 1, so
## hash % 100 walks 1,2,3 over consecutive days - measured) and NOT randf() (a reload would re-roll).
##
##   mix = fmix32(fnv1a32("<seed>|<part>|<part>|..."))            (32 bit, identical in GDScript and Python: tools/social/core/social_rng_mirror.py)
##   roll(seed, ["gardener_hoppe", total_day, "greet"]) -> float in [0,1)
##   pick(seed, parts, n) -> int in [0,n)
## Every daily "random" outcome of the social layer (greeting variant, partner chore, festival order, contest jitter) is roll(world_seed, [...]):
## the same save always gives the same answer, a reload cannot re-roll it, and the order in which NPCs are processed is irrelevant.

const M32 := 0xFFFFFFFF


static func fnv1a32(text: String) -> int:
	var h := 2166136261
	for b: int in text.to_utf8_buffer():
		h = ((h ^ b) * 16777619) & M32
	return h


static func fmix32(x: int) -> int:
	var h := x & M32
	h ^= h >> 16
	h = (h * 0x85ebca6b) & M32
	h ^= h >> 13
	h = (h * 0xc2b2ae35) & M32
	h ^= h >> 16
	return h & M32


static func hash_parts(world_seed: int, parts: Array) -> int:
	var s := str(world_seed)
	for p in parts:
		s += "|" + str(p)
	return fmix32(fnv1a32(s))


static func roll(world_seed: int, parts: Array) -> float:
	return float(hash_parts(world_seed, parts)) / 4294967296.0


static func pick(world_seed: int, parts: Array, n: int) -> int:
	if n <= 1:
		return 0
	return mini(int(roll(world_seed, parts) * n), n - 1)


## Weighted pick: weights = Array of non-negative numbers; returns an index (0 when all are zero).
static func pick_weighted(world_seed: int, parts: Array, weights: Array) -> int:
	var total := 0.0
	for w in weights:
		total += maxf(float(w), 0.0)
	if total <= 0.0:
		return 0
	var r := roll(world_seed, parts) * total
	var acc := 0.0
	for i in weights.size():
		acc += maxf(float(weights[i]), 0.0)
		if r < acc:
			return i
	return weights.size() - 1
