"""SHIM of package V2-cast-art: a module of the SAME NAME as the generator's extension hook (tools/art/generator/build_assets.py imports
`from traetoppen_additions import BUILDERS, EXTRA_PATTERNS, EXTRA_CLIPS`; the PYTHONPATH of the caller wins, see the header of
tools/art/produce_all.sh).  tools/art/cast_v2/produce_cast_v2.sh puts THIS folder first on PYTHONPATH.

  * the P21 module (tools/art/characters/traetoppen_additions.py, owned by P21-art-characters) is imported from its file under another
    name and is never edited, never written, never mutated: BUILDERS below is a COPY of its table
  * BUILDERS  = P21's 36 builders + the six new cast builders + the RESTYLED fairy_shopkeeper and cat_morfar_mis (same ids, new look; the
    entries of those two ids are replaced in the copy only)
  * EXTRA_PATTERNS / EXTRA_CLIPS are re-exported as they are (no new pattern, no new clip)

Without this folder on PYTHONPATH the generator builds the P21 look of every id, exactly as before.
"""
import cast_v2_models as cv2

_p21 = cv2.p21()

BUILDERS = dict(_p21.BUILDERS)
BUILDERS.update(cv2.CAST_BUILDERS)
EXTRA_PATTERNS = _p21.EXTRA_PATTERNS
EXTRA_CLIPS = _p21.EXTRA_CLIPS

# the ids this package adds or restyles (the callers that list them: produce_cast_v2.sh, measure_cast_v2.py, tests/sections/art_cast_v2.gd)
NEW_IDS = list(cv2.NEW_IDS)
RESTYLE_IDS = list(cv2.RESTYLE_IDS)
