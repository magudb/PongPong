"""farm_common.py - paths, the id lists and the contract numbers shared by the N03-farm-art scripts (tools/art/environment/farm).

Every N03 script starts with `import farm_common` (the scripts live next to it, so Python finds it without a path change) and calls prepare_path() BEFORE it imports anything of
P22's environment folder: this folder contains a props_farm.py of its own, and a script run from here has this folder as sys.path[0], where it would shadow P22's props_farm.py
(registered by bake_props.py).  prepare_path() therefore removes this folder from sys.path again and loads our builders by path (load_kit()).
"""
from __future__ import annotations
import importlib.util
import os
import sys
from pathlib import Path

HERE = Path(__file__).resolve().parent                  # tools/art/environment/farm
ENV = HERE.parent                                        # tools/art/environment
ART = ENV.parent                                         # tools/art
REPO = ART.parent.parent                                 # project root (the folder with project.godot)
ASSETS = REPO / 'assets'

KIT_IDS = ['trunk_giant_a', 'trunk_giant_b', 'trunk_under_a', 'trunk_under_b', 'tool_shed', 'shipping_bin', 'stake_sign', 'rope_stake_x', 'rope_stake_z', 'build_stake']
TRUNK_IDS = ['trunk_giant_a', 'trunk_giant_b', 'trunk_under_a', 'trunk_under_b']
# prototype ids that exist in design3/farm/art/out but are NOT shipped by this package (no map uses them / another package bakes them)
NOT_SHIPPED = ['warp_gate_stone', 'dock_x', 'farm_sky']

PROPS_DIR = ASSETS / 'iso_props' / 'farm'                # assets/iso_props/farm/<id>.png + props.json (ArtCatalog reads iso_props/*/props.json)
BACKDROP_DIR = ASSETS / 'backdrops'
TILES_DIR = ASSETS / 'iso_tiles'
BACKDROP_FILES = ['farm_far.webp', 'farm_canopy.webp']   # NEVER farm_sky.*: Codex's painted farm_sky.png (main) is the farm sky, a .webp would shadow it (lead amendment M1a)
TILE_FILES = ['field_grass.png', 'tiles_farm.json']
DEFAULT_STAGE = ART / '_stage' / 'n03'


def prepare_path() -> None:
    """Make P22's environment folder importable and ours NOT (see the module docstring); idempotent."""
    sys.path[:] = [p for p in sys.path if not (p == '' or Path(p).resolve() == HERE)]
    core = str(ART / 'core')
    if core not in sys.path:
        sys.path.insert(0, core)
    import artpaths   # noqa: F401  (adds tools/art/generator, core, characters, environment to sys.path)
    env = str(ENV)
    if env not in sys.path:
        sys.path.append(env)


def load_kit():
    """Our props_farm.py, loaded by path under the name n03_props_farm (never the name P22's module has)."""
    prepare_path()
    spec = importlib.util.spec_from_file_location('n03_props_farm', HERE / 'props_farm.py')
    mod = importlib.util.module_from_spec(spec)
    sys.modules['n03_props_farm'] = mod
    spec.loader.exec_module(mod)
    return mod


def stage_root(arg=None) -> Path:
    """The N03 stage: the argument, else $TT_ART_STAGE/n03 when TT_ART_STAGE is set, else tools/art/_stage/n03 (gitignored, hidden from Godot by tools/art/.gdignore)."""
    prepare_path()
    import artpaths
    if arg:
        root = Path(arg)
    elif os.environ.get('N03_STAGE'):
        root = Path(os.environ['N03_STAGE'])
    else:
        root = DEFAULT_STAGE
    return artpaths.assert_stage_dir(root, 'N03 stage directory')


def masters(stage: Path) -> dict:
    return {'props': stage / 'masters' / 'iso_props_farm', 'tiles': stage / 'masters' / 'iso_tiles', 'backdrops': stage / 'masters' / 'backdrops',
            'previews': stage / 'previews'}
