"""SHIM (A1-art-home): the generator hooks of build_assets.py, empty on purpose.

tools/art/features/home/characters comes FIRST on PYTHONPATH, so `from traetoppen_additions import BUILDERS, EXTRA_PATTERNS, EXTRA_CLIPS`
in the generator finds this module and not the 965-line one of P21 (tools/art/characters).  The home art needs none of the character builders;
home_kit.install() adds its own painters to EXTRA_PATTERNS at import time.  This keeps A1 independent of P21/P22 (wave 2 rule).
"""
BUILDERS: dict = {}
EXTRA_PATTERNS: dict = {}
EXTRA_CLIPS: dict = {}
