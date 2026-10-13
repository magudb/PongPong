#!/usr/bin/env python3
"""Import-path bootstrap of the A1 home tools (package A1-art-home).

Every entry script of tools/art/features/home does `import homepaths` first, so it runs from the repo root (or anywhere) with

    PYTHONPATH = tools/art/features/home/characters : tools/art/features/home/isometric : tools/art/generator : tools/art/core

in exactly this order (the order of the addendum, task 1) whether or not the caller exported PYTHONPATH.  The shim
`traetoppen_additions.py` of this package therefore always wins over a `tools/art/characters/traetoppen_additions.py` of P21
(core/artpaths.py appends its own dirs LAST and never overrides an explicit order), so A1 does not depend on P21/P22.

The generator and the core are used through the path only and are never edited (P08 handoff).  Importing this module also
turns bytecode writing off: __pycache__ folders under tools/ would end up in `git status`.
"""
from __future__ import annotations
import os
import sys
from pathlib import Path

HOME = Path(__file__).resolve().parents[1]          # tools/art/features/home
ART = HOME.parents[1]                                 # tools/art
REPO = ART.parents[1]                                 # project root (the folder with project.godot)
DIRS = [HOME / 'characters', HOME / 'isometric', ART / 'generator', ART / 'core']
SPECS = HOME / 'specs'

sys.dont_write_bytecode = True
os.environ.setdefault('PYTHONDONTWRITEBYTECODE', '1')


def ensure() -> None:
    """Put the four package dirs at the FRONT of sys.path in the contract order (idempotent)."""
    want = [str(d) for d in DIRS]
    sys.path[:] = want + [p for p in sys.path if p not in want]


ensure()


def stage_root() -> Path:
    """tools/art/_stage/features_home (or $TT_ART_STAGE/features_home): the work tree of produce_home.sh, gitignored and hidden from Godot."""
    base = Path(os.environ.get('TT_ART_STAGE') or ART / '_stage')
    return base / 'features_home'


def assert_stage(path) -> Path:
    """Refuse a work/stage folder Godot would scan or git would list (same rule as core/artpaths.assert_stage_dir)."""
    import artpaths
    return artpaths.assert_stage_dir(path, 'A1 work directory')
