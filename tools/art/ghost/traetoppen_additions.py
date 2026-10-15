"""SHIM of the ghost package: the module name tools/art/generator/build_assets.py imports (`from traetoppen_additions import BUILDERS, EXTRA_PATTERNS, EXTRA_CLIPS`).

Why a shim and not an edit: the generator finds its extra builders through the module NAME `traetoppen_additions` on PYTHONPATH, and the caller's PYTHONPATH wins
(tools/art/produce_all.sh header; core/artpaths.py appends its own folders AFTER it).  tools/art/characters/traetoppen_additions.py is P21's (36 characters),
tools/art/features/home/characters/ the feature package's; this one is put FIRST by tools/art/ghost/produce_ghost.sh and exposes only the two ghost builders:

  BUILDERS         {'ghost_bu': ..., 'ghost_hviske': ...}         (ghost_model.BUILDERS)
  EXTRA_PATTERNS   {'sheet': a quiet cloth weave with long folds, no fur strokes}
  EXTRA_CLIPS      the glide hooks of the BASE clips walk / run (ghost_model.GHOST_CLIP_HOOKS): a no-op for every model whose family is not 'ghost'

Nothing of P21 is re-exported on purpose: a produce_ghost.sh run builds exactly the two ghosts (and the hook-identity check proves that with this shim
FIRST on the path the fox, the bat and the fairy come out byte-identical).  A package that needs the ghost model imports `ghost_model` (this folder on
PYTHONPATH, AFTER its own `traetoppen_additions`), it never imports this shim.
"""
import ghost_model as _gm

BUILDERS = dict(_gm.BUILDERS)
EXTRA_PATTERNS = dict(_gm.GHOST_PATTERNS)
EXTRA_CLIPS = dict(_gm.GHOST_CLIP_HOOKS)
