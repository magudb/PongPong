#!/usr/bin/env python3
"""Paths, stage layout, import-path bootstrap and the Godot-scan guard of the Traetoppen art pipeline (P08 core).

Everything lives under tools/art (hidden from Godot by tools/art/.gdignore):

  tools/art/.venv/            python 3.12 venv (setup_env.sh), gitignored
  tools/art/_stage/           ALL generated output, gitignored; never export/ (Godot would import that folder).  Inside the project
                              ONLY this folder (and anything below it) is accepted as a stage; any other stage must be outside the project
      glb/                    generated GLB rigs + textures + <id>_rig.json     (generator/build_assets.py)
      masters/                lossless PNG masters, mirrors res://assets        (bakers)
      assets/                 game-ready tree (WebP q97 sprites, lossless icons), mirrors res://assets   (exporter)
      previews/               contact sheets and compare images
  assets/<contract dirs>      only produce_all.sh / export/install_assets.py write here (CONTRACT_DIRS)

Importing this module appends tools/art/generator and tools/art/core (and, when present, the package-owned builder
dirs tools/art/characters, environment, icons) to sys.path AFTER whatever PYTHONPATH already holds, so an explicit
PYTHONPATH (for example the feature packages' shims) always wins.  Module names in tools/art are ASCII on purpose.
"""
from __future__ import annotations
import os
import sys
from pathlib import Path

ART = Path(__file__).resolve().parents[1]          # tools/art
REPO = ART.parents[1]                               # project root (the folder with project.godot)
GENERATOR = ART / 'generator'
CORE = ART / 'core'
OPTIONAL_BUILDER_DIRS = [ART / 'characters', ART / 'environment', ART / 'icons']   # P21 / P22 / P23, may not exist yet
DEFAULT_STAGE = ART / '_stage'


def ensure_import_path():
    for d in [GENERATOR, CORE] + [p for p in OPTIONAL_BUILDER_DIRS if p.is_dir()]:
        s = str(d)
        if s not in sys.path:
            sys.path.append(s)


ensure_import_path()


def godot_scanned(path) -> bool:
    """True when Godot would scan `path`: inside the project and no .gdignore in it or in any parent up to the project root."""
    p = Path(path).resolve()
    try:
        p.relative_to(REPO)
    except ValueError:
        return False                                   # outside the project folder
    cur = p
    while True:
        if (cur / '.gdignore').exists():
            return False
        if cur == REPO:
            return True
        cur = cur.parent


def assert_not_scanned(path, what='stage directory'):
    if godot_scanned(path):
        raise SystemExit(f'ERROR: {what} {path} is inside the Godot project and not hidden by a .gdignore '
                         f'(Godot would import it). Use tools/art/_stage or a folder outside the project.')
    return Path(path).resolve()


def stage_allowed(path) -> bool:
    """True when `path` may be a stage: outside the project folder, or tools/art/_stage itself / anything below it.

    Inside the project ONLY tools/art/_stage qualifies: it is the one stage folder that .gitignore lists (a folder next to it,
    like tools/art/_stage2, is hidden from Godot by tools/art/.gdignore but would put hundreds of MB of bake output into git's
    untracked files).
    """
    p = Path(path).resolve()
    try:
        p.relative_to(REPO)
    except ValueError:
        return True
    try:
        p.relative_to(DEFAULT_STAGE.resolve())
        return True
    except ValueError:
        return False


def assert_stage_dir(path, what='stage directory'):
    """The guard of every stage / staging destination: hidden from Godot AND (inside the project) the gitignored tools/art/_stage."""
    p = assert_not_scanned(path, what)
    if not stage_allowed(p):
        raise SystemExit(f'ERROR: {what} {path} is inside the project but not under tools/art/_stage (the only staging folder that '
                         f'.gitignore lists: output anywhere else lands in git as untracked files). Use tools/art/_stage[/name] or '
                         f'a folder outside the project.')
    return p


def stage_root() -> Path:
    """The stage root: $TT_ART_STAGE, else tools/art/_stage."""
    return Path(os.environ.get('TT_ART_STAGE') or DEFAULT_STAGE)


class Stage:
    """The stage tree (default tools/art/_stage, or $TT_ART_STAGE, or the path passed on the command line)."""

    def __init__(self, root=None):
        r = Path(root) if root else stage_root()
        self.root = assert_stage_dir(r)
        self.glb = Path(os.environ.get('TT_ART_GLB') or self.root / 'glb')
        self.masters = Path(os.environ.get('TT_ART_MASTERS') or self.root / 'masters')
        for p, label in ((self.glb, 'GLB folder ($TT_ART_GLB)'), (self.masters, 'masters folder ($TT_ART_MASTERS)')):
            assert_not_scanned(p, label)               # an override must never point where Godot scans
        self.assets = self.root / 'assets'
        self.previews = self.root / 'previews'

    def make(self):
        for d in (self.glb, self.masters, self.assets, self.previews):
            d.mkdir(parents=True, exist_ok=True)
        return self


def glb_dir() -> Path:
    """Where generated GLB rigs live (the default for build_assets.py and bake_sprite_atlases.py)."""
    p = Path(os.environ.get('TT_ART_GLB') or stage_root() / 'glb')
    assert_not_scanned(p, 'GLB folder')
    return p


def masters_dir() -> Path:
    p = Path(os.environ.get('TT_ART_MASTERS') or stage_root() / 'masters')
    assert_not_scanned(p, 'masters folder')
    return p


def find_pack_character(char_id='fox'):
    """Locate the shipped pack folder of a character (the visual reference of the gate), or None.

    Search order: the final home (P05), the nested pack project that P05 deletes later, the moved docs copy.
    """
    for rel in ('assets/isometric_characters', 'docs/PongPong_Isometric2D/assets/isometric_characters',
                'docs/art/isometric_pack/assets/isometric_characters'):
        d = REPO / rel / char_id
        if (d / 'animations.json').exists():
            return d
    return None


def pack_hint():
    return "no pack folder found (tried assets/isometric_characters, docs/PongPong_Isometric2D, docs/art/isometric_pack)"
