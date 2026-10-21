"""Which file the game draws for a prop id, and which historical copies are superseded (review REND-10).

ArtCatalog (scripts/world2d/art_catalog.gd) reads assets/iso_props/props.json, then the props.json of every
pack in its PROP_PACKS list, in that order; the last pack that defines an id wins. The copies a later pack
replaced are not kept. Their fixture recipes stay in fixture_recipes.json, marked "superseded", because the
painted bakers still read their measured geometry (fixtures.geometry_source). The geometry-stage pipelines
(P22 build_all.sh, V5 build_city.sh, N03 build_farm.sh) use this module to leave those copies out.
Standard library only.
"""
from __future__ import annotations

import json
import re
from functools import lru_cache
from pathlib import Path

ROOT = Path(__file__).resolve().parents[3]


@lru_cache(maxsize=None)
def prop_packs(root: Path = ROOT) -> tuple[str, ...]:
    """ArtCatalog.PROP_PACKS, the override order of the pack folders under assets/iso_props."""
    src = (Path(root) / "scripts/world2d/art_catalog.gd").read_text()
    return tuple(re.findall(r'"([^"]+)"', re.search(r"const PROP_PACKS: Array\[String\] = \[(.*?)\]", src, re.S)[1]))


@lru_cache(maxsize=None)
def catalog(root: Path = ROOT) -> dict:
    """ArtCatalog's prop entries, id -> entry, each with "_dir": the Path of the pack folder it comes from."""
    props = Path(root) / "assets/iso_props"
    out = {}
    for folder in [props] + [props / pack for pack in prop_packs(root)]:
        manifest = folder / "props.json"
        if not manifest.is_file():
            continue
        for pid, e in json.loads(manifest.read_text()).items():
            if not pid.startswith("_") and isinstance(e, dict):
                out[pid] = dict(e, _dir=folder)
    return out


def drawn_file(pid: str, root: Path = ROOT) -> Path:
    """The file the game draws for a prop id."""
    e = catalog(root)[pid]
    return e["_dir"] / e["file"]


@lru_cache(maxsize=None)
def _superseded(root: Path) -> frozenset:
    path = Path(root) / "tools/art/drawn/fixture_recipes.json"
    if not path.is_file():   # a scratch project of a tool's selftest: nothing is superseded there
        return frozenset()
    recipes = json.loads(path.read_text())["assets"]
    return frozenset(name for name, rec in recipes.items() if rec.get("superseded"))


def superseded(path, root: Path = ROOT) -> bool:
    """True when `path` (repo-relative, or absolute inside `root`) is a copy a later art pack replaced: not kept."""
    path = Path(path)
    rel = path.resolve().relative_to(Path(root).resolve()) if path.is_absolute() else path
    return rel.as_posix() in _superseded(Path(root))
