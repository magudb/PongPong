#!/usr/bin/env python3
"""Python mirror of scripts/social/social_rng.gd (FNV-1a 32 + murmur3 fmix32). The balance Monte Carlo, the validators and the GDScript section share these
vectors, so a result that is reproducible in Python is the same number in the game.

    python3 -I tools/social/core/social_rng_mirror.py            prints the six pinned vectors (human readable)
    python3 -I tools/social/core/social_rng_mirror.py --json     the same as JSON (tests/sections/social.gd compares it with SocialRng)

mix = fmix32(fnv1a32("<seed>|<part>|<part>|..."))  - NEVER str.hash / String.hash (measured: 'a|1'.hash() and 'a|2'.hash() differ by 1, so hash % 100 walks
1, 2, 3 over consecutive days) and never randf (a reload would re-roll). The seed is the saved world seed of SocialManager (below 2^53).
"""
import json
import sys

M32 = 0xFFFFFFFF


def fnv1a32(text):
    h = 2166136261
    for b in text.encode('utf-8'):
        h = ((h ^ b) * 16777619) & M32
    return h


def fmix32(x):
    h = x & M32
    h ^= h >> 16
    h = (h * 0x85ebca6b) & M32
    h ^= h >> 13
    h = (h * 0xc2b2ae35) & M32
    h ^= h >> 16
    return h & M32


def hash_parts(seed, parts):
    s = str(seed)
    for p in parts:
        s += '|' + str(p)
    return fmix32(fnv1a32(s))


def roll(seed, parts):
    return hash_parts(seed, parts) / 4294967296.0


def pick(seed, parts, n):
    if n <= 1:
        return 0
    return min(int(roll(seed, parts) * n), n - 1)


VECTORS = [
    (777, ['gardener_hoppe', 112, 'greet']),
    (777, ['gardener_hoppe', 113, 'greet']),
    (777, ['carpenter_brumme', 112, 'greet']),
    (1, ['x']),
    (9007199254740991, ['æøå', 3]),
    (424242, ['a', 'b', 'c', 1, 2, 3]),
]


def uniform_hits():
    """The 25 % roll over 10080 (npc, day) pairs: the number the section compares (python and GDScript must agree)."""
    return sum(1 for d in range(280) for i in range(36) if roll(7777, ['npc_%02d' % i, d, 'x']) < 0.25)


def vectors():
    return [{'seed': seed, 'parts': parts, 'hash': hash_parts(seed, parts), 'pick10': pick(seed, parts, 10)} for seed, parts in VECTORS]


if __name__ == '__main__':
    if '--json' in sys.argv:
        print(json.dumps({'vectors': vectors(), 'uniform_25pct_hits': uniform_hits()}, ensure_ascii=False))
    else:
        for v in vectors():
            print('%d %s -> hash %d roll %.9f pick10 %d' % (v['seed'], v['parts'], v['hash'], v['hash'] / 4294967296.0, v['pick10']))
        hits = uniform_hits()
        print('25%% roll over 10080 pairs: %d %.2f%%' % (hits, 100.0 * hits / 10080))
