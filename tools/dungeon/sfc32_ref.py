#!/usr/bin/env python3
"""Independent Python implementation of dg_rng.gd (sfc32 + FNV-1a/fmix32 hash_key) - proves the stream is a pure integer specification:
the same numbers come out of GDScript (arm64 and x86_64) and out of Python.  Compares against rng_probe_arm64.txt OWN lines."""
import re, sys
M = 0xFFFFFFFF
def mul32(x, y): return (x * y) & M
def fmix32(h):
    h &= M; h ^= h >> 16; h = mul32(h, 0x85EBCA6B); h ^= h >> 13; h = mul32(h, 0xC2B2AE35); h ^= h >> 16; return h
def hash_key(save_id, day, floor_no):
    h1, h2 = 0x811C9DC5, 0x9747B28C
    for b in save_id.encode('utf-8'):
        h1 = ((h1 ^ b) * 16777619) & M
        h2 = ((h2 ^ b) * 16777619) & M
    d_lo, d_hi, f_lo = day & M, (day >> 32) & M, floor_no & M
    h1 = fmix32(h1 ^ mul32(d_lo, 0x9E3779B1))
    h1 = fmix32(h1 ^ mul32(f_lo, 0x85EBCA77) ^ d_hi)
    h2 = fmix32(h2 ^ mul32(d_lo, 0xC2B2AE3D) ^ h1)
    h2 = fmix32(h2 ^ mul32(f_lo, 0x27D4EB2F) ^ mul32(h1, 0x165667B1))
    return (((h2 & 0x3FFFFFFF) << 32) | h1) & 0x3FFFFFFFFFFFFFFF
class Sfc32:
    def __init__(self, s):
        self.a = s & M; self.b = (s >> 32) & M; self.c = 0xB7E15162; self.d = 1
        for _ in range(16): self.next()
    def next(self):
        t = (self.a + self.b + self.d) & M
        self.d = (self.d + 1) & M
        self.a = self.b ^ (self.b >> 9)
        self.b = (self.c + (self.c << 3)) & M
        self.c = ((self.c << 21) & M) | (self.c >> 11)
        self.c = (self.c + t) & M
        return t
    def below(self, n):
        if n <= 1: return 0
        limit = 4294967296 - (4294967296 % n)
        x = self.next()
        while x >= limit: x = self.next()
        return x % n
    def range_i(self, lo, hi): return lo if hi <= lo else lo + self.below(hi - lo + 1)
def main():
    ok = bad = 0
    for line in open(sys.argv[1]):
        m = re.match(r'OWN\.sfc32 seed=(\d+) (.*)', line)
        if m:
            r = Sfc32(int(m.group(1)))
            want = ' '.join('%08x' % r.next() for _ in range(8))
            if want == m.group(2).strip(): ok += 1
            else: bad += 1; print('MISMATCH sfc32', m.group(1), want, m.group(2))
        m = re.match(r'OWN\.hash save_a\|12\|3 = (\d+)  save_a\|12\|4 = (\d+)  save_b\|12\|3 = (\d+)', line)
        if m:
            got = [hash_key('save_a', 12, 3), hash_key('save_a', 12, 4), hash_key('save_b', 12, 3)]
            if got == [int(m.group(i)) for i in (1, 2, 3)]: ok += 1
            else: bad += 1; print('MISMATCH hash', got, m.groups())
        m = re.match(r'OWN\.range_i\(0,99\) seed=42 (.*)', line)
        if m:
            r = Sfc32(42)
            if ' '.join(str(r.range_i(0, 99)) for _ in range(12)) == m.group(1).strip(): ok += 1
            else: bad += 1; print('MISMATCH range_i')
    print('sfc32_ref: %d OWN lines identical to the Python implementation, %d mismatches' % (ok, bad))
    return 1 if bad else 0

if __name__ == "__main__":
    raise SystemExit(main())
