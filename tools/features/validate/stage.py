#!/usr/bin/env python3
"""Assembles the STAGE TREE of the feature content validator (review RV-P2, docs/features/STAGES.md).

The feature content lives scattered over the repo (lua/items, lua/recipes, lua/shops, lua/data, lua/quests, lua/dialogue, localization/, data/features, art specs, tools/loc).
The validator, the Lua evaluation and the balance sim want ONE tree in the shape of the reviewed pack (lua/, localization/, data/).  This script builds it from
tools/features/validate/stage.manifest, so every rule runs against a COMPLETE tree and nothing is skipped on a half-built repo:

    stage f1    F1's own files + the PENDING references for what later packages finish (quests lost_cat, fix_roof, birthday_cake, math_wizard_quiz with the reviewed rewards;
                dialogues guard_oak, fairy_wizard, fairy_king with the quest_accept branches)
    stage p13   the four quests come from the REAL repo (P13 merged the rewards: rule Q3), dialogues still pending
    stage p14   quests AND dialogues come from the real repo (rule S13 on the real files)
    stage full  same as p14 (F10, wave 7)

    python3 stage.py --repo DIR [--src DIR] --stage f1|p13|p14|full --out DIR [--manifest FILE] [--list]

--src is the tree under test (default = --repo): a file is taken from SRC when it exists there, else from the repo.  The mutation test uses it to apply one defect to a copy.
--list prints the repo-relative source paths of the stage instead of copying (the mutation test copies exactly those).
Exit 5 with "stage <s> needs <file>" when a file the stage requires is missing (a stage never degrades silently).
"""
from __future__ import annotations
import argparse
import json
import re
import shutil
import sys
from pathlib import Path

RANK = {'f1': 1, 'p13': 2, 'p14': 3, 'full': 3}
GLOBCH = re.compile(r'[*?\[]')


def brace_expand(pat: str) -> list[str]:
    m = re.search(r'\{([^{}]*)\}', pat)
    if not m:
        return [pat]
    out = []
    for alt in m.group(1).split(','):
        out += brace_expand(pat[:m.start()] + alt + pat[m.end():])
    return out


def split_glob(pat: str) -> tuple[str, str]:
    """(fixed directory prefix, rest) of a glob pattern"""
    m = GLOBCH.search(pat)
    if not m:
        return pat, ''
    head = pat[:m.start()]
    cut = head.rfind('/') + 1
    return pat[:cut], pat[cut:]


class Stage:
    def __init__(self, repo: Path, src: Path, stage: str):
        self.repo, self.src, self.stage = repo, src, stage
        self.items: dict[str, dict] = {}          # dst -> {src, origin}
        self.missing: list[str] = []

    def find(self, rel: str) -> Path | None:
        for base in (self.src, self.repo):
            p = base / rel
            if p.is_file():
                return p
        return None

    def expand(self, pattern: str) -> list[str]:
        """repo-relative file paths matching a pattern, looking in SRC and the repo (SRC wins per path)"""
        out: dict[str, None] = {}
        for pat in brace_expand(pattern):
            if not GLOBCH.search(pat):
                if self.find(pat):
                    out[pat] = None
                continue
            for base in (self.src, self.repo):
                for p in sorted(base.glob(pat)):
                    if p.is_file() and '__pycache__' not in p.parts:
                        out[p.relative_to(base).as_posix()] = None
        return list(out)

    def add(self, src_rel: str, dst_rel: str, origin: str) -> None:
        self.items[dst_rel] = {'src': src_rel, 'origin': origin}

    def map_pattern(self, src_pat: str, dst_pat: str | None, origin: str, required_msg: str | None = None) -> int:
        n = 0
        for rel in self.expand(src_pat):
            if dst_pat is None:
                dst = rel
            elif GLOBCH.search(src_pat):
                prefix, _ = split_glob(brace_expand(src_pat)[0])
                dprefix = split_glob(dst_pat)[0]
                dst = dprefix + rel[len(prefix):]
            else:
                dst = dst_pat
            self.add(rel, dst, origin)
            n += 1
        return n


def parse_manifest(path: Path):
    for ln, raw in enumerate(path.read_text(encoding='utf-8').splitlines(), 1):
        line = raw.split('#', 1)[0].strip()
        if not line:
            continue
        yield ln, line


def build(repo: Path, src: Path, stage: str, manifest: Path) -> Stage:
    st = Stage(repo, src, stage)
    rank = RANK[stage]
    for ln, line in parse_manifest(manifest):
        kind, rest = line.split(None, 1)
        fallback = None
        if '??' in rest:
            rest, fallback = (x.strip() for x in rest.split('??', 1))
        dst = None
        if '->' in rest:
            rest, dst = (x.strip() for x in rest.split('->', 1))
        if kind in ('own', 'repo'):
            # own = a file of this package (F1), repo = a file of another package that the rules read; both: SRC first, then the repo
            n = st.map_pattern(rest, dst, kind)
            if n == 0 and fallback:
                n = st.map_pattern(fallback, dst or rest, 'pending')
            if n == 0:
                st.missing.append(f'{rest} (manifest line {ln})')
        elif kind == 'staged':
            # staged <from-stage> <real path> ?? <pending path>: the real file once the owner's stage is reached, the pending reference before
            frm, real = rest.split(None, 1)
            if rank >= RANK[frm]:
                if st.map_pattern(real, dst, 'real') == 0:
                    st.missing.append(real)
            else:
                if not fallback or st.map_pattern(fallback, dst or real, 'pending') == 0:
                    st.missing.append(fallback or real)
        else:
            raise SystemExit(f'{manifest}:{ln}: unknown directive {kind!r}')
    return st


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument('--repo', required=True)
    ap.add_argument('--src')
    ap.add_argument('--stage', default='f1', choices=sorted(RANK))
    ap.add_argument('--out')
    ap.add_argument('--manifest', default=str(Path(__file__).with_name('stage.manifest')))
    ap.add_argument('--list', action='store_true')
    a = ap.parse_args()
    repo = Path(a.repo).resolve()
    src = Path(a.src).resolve() if a.src else repo
    st = build(repo, src, a.stage, Path(a.manifest))
    if st.missing:
        for m in st.missing:
            print(f'stage {a.stage} needs {m}', file=sys.stderr)
        return 5
    if a.list:
        for dst, info in sorted(st.items.items()):
            print(info['src'])
        return 0
    if not a.out:
        print('--out is required', file=sys.stderr)
        return 2
    out = Path(a.out)
    if out.exists():
        shutil.rmtree(out)
    out.mkdir(parents=True)
    for dst, info in st.items.items():
        p = st.find(info['src'])
        d = out / dst
        d.parent.mkdir(parents=True, exist_ok=True)
        shutil.copyfile(p, d)
    (out / '_stage.json').write_text(json.dumps({'stage': a.stage, 'files': st.items}, indent=1, sort_keys=True), encoding='utf-8')
    by = {}
    for info in st.items.values():
        by[info['origin']] = by.get(info['origin'], 0) + 1
    print(f"stage {a.stage}: {len(st.items)} files assembled into {out}  ({', '.join(f'{k} {v}' for k, v in sorted(by.items()))})")
    return 0


if __name__ == '__main__':
    sys.exit(main())
