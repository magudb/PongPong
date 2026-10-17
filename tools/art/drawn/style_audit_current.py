#!/usr/bin/env python3
"""Refresh the complete art inventory and expose additions for visual review.

--check verifies the explicitly reviewed snapshot; scanning never approves art.
Existing byte-identical assets keep their earlier documented visual evidence.
"""
from __future__ import annotations

import argparse
import collections
import csv
import hashlib
import json
import re
import xml.etree.ElementTree as ET
from pathlib import Path

ROOT = Path(__file__).resolve().parents[3]
OUT = ROOT / "docs/art/style-audit/current"
BASELINE = ROOT / "docs/art/style-audit/inventory-after.csv"
VISUAL = {".png", ".webp", ".svg", ".ttf", ".tres"}


def sha(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def read(path: Path) -> dict:
    return json.loads(path.read_text())


def roles(catalog: dict) -> tuple[dict, dict]:
    from style_audit import asset_roles, local
    selected = asset_roles(catalog)
    sources = {}
    # The seasonal emitter consumes these directly, outside ArtCatalog props.
    for name in ["leaf_a", "leaf_b", "petal", "snowflake"]:
        path = ROOT / "assets/iso_props/farm_dress" / (name + ".webp")
        if path.is_file():
            selected[path.resolve()] = "painted-farm-season-particle"
            sources[path.resolve()] = "docs/art/farm-seasons/review.md"
    farm = ROOT / "assets/iso_props/farm_completion"
    if (farm / "props.json").is_file():
        for name, spec in read(farm / "props.json").items():
            path = (farm / spec["file"]).resolve()
            selected[path] = "painted-farm-prop-or-crop"
            sources[path] = spec["illustration"]
        for path in (ROOT / "assets/icons/items").glob("*.webp"):
            name = path.stem
            source = ""
            if name in ["sprinkler", "quality_sprinkler", "preserves_jar", "keg"]:
                source = "sprinkler" if name == "quality_sprinkler" else name
            elif name.startswith("preserve_"):
                source = "preserves_jar"
            elif name.startswith("juice_"):
                source = "juice_bottle"
            elif name in ["snow_turnip", "snowdrop"]:
                source = name + "_stages"
            elif name in ["snow_turnip_seeds", "snowdrop_seeds"]:
                source = name + "_icon"
            if source:
                selected[path.resolve()] = "painted-farm-item-icon"
                sources[path.resolve()] = "tools/art/drawn/sources/farm_completion/" + source + ".png"
    for row in catalog.get("icon_variants", []):
        selected[local(row["path"]).resolve()] = "item-base-or-night-icon"
    for row in catalog.get("backdrops", []):
        for part in ["sky", "far"]:
            selected[local(row[part]).resolve()] = "selected-backdrop-" + part
    for row in catalog["props"]:
        for part in row.get("auxiliary", []):
            selected[local(part["path"]).resolve()] = "technical-" + part["role"]
    selected[(ROOT / "assets/art/watercolor_paper.png").resolve()] = "shared-ui-paper-texture"
    # These are separately consumed art kits; ArtCatalog alone does not see them.
    for directory, filename, role in [("shops/core", "shops.json", "core-shop-view"),
                                       ("shops/special", "shops.json", "specialist-shop-view"),
                                       ("festival", "festival.json", "festival-view")]:
        folder = ROOT / "assets/iso_props" / directory
        for item in read(folder / filename)["items"].values():
            for view in item["rot"].values():
                path = (folder / view["file"]).resolve()
                selected[path] = role
                sources[path] = view["illustration"]
                if "night" in view:
                    selected[(folder / view["night"]).resolve()] = "technical-painted-light-mask"
    folder = ROOT / "assets/iso_props/shops/core"
    for emblem in read(folder / "emblems.json")["emblems"].values():
        path = (folder / emblem["file"]).resolve()
        selected[path] = "painted-profession-emblem"
        sources[path] = emblem["illustration"]
    folder = ROOT / "assets/art_studies/equipment_fit"
    for body in read(folder / "manifest.json")["bodies"].values():
        for clip in body["clips"].values():
            path = (folder / clip["file"]).resolve()
            selected[path] = "fitted-pose-atlas"
            sources[path] = body["base_source"]
    held = ROOT / "assets/held_equipment"
    if (held / "manifest.json").is_file():
        path = (held / "tools.webp").resolve()
        selected[path] = "fitted-held-equipment"
        sources[path] = read(held / "manifest.json")["source"]
    dungeon_weapons = held / "dungeon/manifest.json"
    if dungeon_weapons.is_file():
        for item, spec in read(dungeon_weapons)["items"].items():
            path = (ROOT / spec["atlas"].removeprefix("res://")).resolve()
            selected[path] = "painted-dungeon-held-equipment"
            sources[path] = spec["source"]
            for suffix in [".webp", "_night.webp"]:
                icon = ROOT / "assets/icons/items" / (item + suffix)
                if icon.is_file():
                    selected[icon.resolve()] = "painted-dungeon-weapon-icon"
                    sources[icon.resolve()] = spec["source"]
    dungeon_icons = ROOT / "tools/art/features/dungeon/manifest.json"
    if dungeon_icons.is_file():
        for item, spec in read(dungeon_icons)["items"].items():
            for part in ["file", "night"]:
                if part not in spec:
                    continue
                path = (ROOT / "assets/icons/items" / spec[part]).resolve()
                selected[path] = "painted-dungeon-weapon-icon" if item.startswith("wpn_") else "painted-dungeon-loot-icon"
                sources[path] = spec["source"]
    story = ROOT / "assets/iso_props/forest_mother"
    if (story / "props.json").is_file():
        for item, spec in read(story / "props.json").items():
            path = (story / spec["file"]).resolve()
            selected[path] = "painted-forest-story-prop"
            sources[path] = spec["source"]
    supplies = ROOT / "tools/art/features/dungeon/supplies.json"
    if supplies.is_file():
        for spec in read(supplies)["items"].values():
            path = (ROOT / "assets/icons/items" / spec["file"]).resolve()
            selected[path] = "painted-dungeon-supply-icon"
            sources[path] = spec["source"]
    wardrobe = ROOT / "assets/wardrobe"
    if (wardrobe / "manifest.json").is_file():
        manifest = read(wardrobe / "manifest.json")
        for body in manifest["bodies"].values():
            for filename in body["layers"].values():
                selected[(wardrobe / filename).resolve()] = "fitted-painted-clothing"
            selected[(wardrobe / body["mask"]).resolve()] = "technical-clothing-occlusion-mask"
            if body["base"]:
                selected[(wardrobe / body["base"]).resolve()] = "painted-wardrobe-safe-body"
    technical_source = (ROOT / "tests/sections/art_style_consistency.gd").read_text()
    technical = re.findall(r'"([^"]+)"', re.search(r"const TECHNICAL := \[(.*?)\]", technical_source, re.S)[1])
    for row in catalog["props"]:
        if row["id"] in technical:
            selected[local(row["path"]).resolve()] = "technical-effect-or-readability-mask"
    for name, rec in read(ROOT / "tools/art/drawn/fixture_recipes.json")["assets"].items():
        path = (ROOT / name).resolve()
        family = "terrain" if "/iso_tiles/" in name else "backdrop" if "/backdrops/" in name else "city" if "/city/" in name else "interior" if "/interior/" in name else "props"
        selected[path] = "technical-historical-light-kernel" if rec["mode"] == "technical" else "painted-fixture-" + family
        sources[path] = rec.get("source", "")
    return selected, sources


def scan() -> None:
    from PIL import Image, ImageFont
    from style_audit import pages
    OUT.mkdir(parents=True, exist_ok=True)
    catalog = read(OUT / "catalog.json")
    baseline = {r["path"]: r for r in csv.DictReader(BASELINE.open())}
    selected, sources = roles(catalog)
    inventory, problems = [], []
    new_pages = collections.defaultdict(list)
    for path in sorted((ROOT / "assets").rglob("*")):
        if not path.is_file():
            continue
        name = str(path.relative_to(ROOT))
        previous = baseline.get(name)
        digest = sha(path)
        state = "new" if previous is None else "unchanged" if previous["sha256"] == digest else "changed"
        role = selected.get(path.resolve(), "")
        width, height = "", ""
        try:
            if path.suffix in [".png", ".webp"]:
                with Image.open(path) as im:
                    im.load()
                    width, height = im.size
                if not role:
                    if previous and state == "unchanged" and previous["role"] == "retained-export":
                        role = "retained-unselected-prototype"
                    else:
                        role = "UNCLASSIFIED"
                        problems.append("unclassified raster: " + name)
                if state != "unchanged" and role != "fitted-pose-atlas":
                    new_pages[role].append((path.stem, path))
            elif path.suffix == ".json":
                read(path)
                role = "asset-contract-or-manifest"
            elif path.suffix == ".svg":
                ET.parse(path)
                role = "theme-vector-symbol"
            elif path.suffix == ".ttf":
                ImageFont.truetype(str(path), 20)
                role = "bundled-typeface"
            else:
                role = "import-license-or-theme-metadata"
        except Exception as exc:
            problems.append(f"{name}: {exc}")
        source = sources.get(path.resolve(), "")
        if source and not (ROOT / source).is_file():
            problems.append("missing selected painting: " + source)
        inventory.append({"path": name, "bytes": path.stat().st_size, "sha256": digest, "kind": path.suffix,
                          "width": width, "height": height, "role": role, "change_since_prior_audit": state,
                          "selected_source": source})
    with (OUT / "inventory.csv").open("w", newline="") as file:
        writer = csv.DictWriter(file, fieldnames=list(inventory[0]), lineterminator="\n")
        writer.writeheader()
        writer.writerows(inventory)
    saved = []
    for role, entries in sorted(new_pages.items()):
        saved += pages(role, entries, OUT)
    kernels = [(r["path"].removeprefix("assets/"), ROOT / r["path"]) for r in inventory if r["role"] == "technical-historical-light-kernel"]
    saved += pages("technical-historical-light-kernel", kernels, OUT)
    report = {"status": "requires explicit visual review; scan is not an aesthetic approval",
              "files": len(inventory), "raster_files": sum(r["kind"] in [".png", ".webp"] for r in inventory),
              "vectors": sum(r["kind"] == ".svg" for r in inventory), "fonts": sum(r["kind"] == ".ttf" for r in inventory),
              "raster_changes": dict(collections.Counter(r["change_since_prior_audit"] for r in inventory if r["kind"] in [".png", ".webp"])),
              "roles": dict(collections.Counter(r["role"] for r in inventory if r["kind"] in [".png", ".webp"])),
              "problems": problems, "review_pages": saved,
              "baseline": str(BASELINE.relative_to(ROOT)),
              "new_fit_pose_review": "docs/art/equipment-fit/native-review.json"}
    (OUT / "scan.json").write_text(json.dumps(report, indent=2) + "\n")
    print(json.dumps({k: v for k, v in report.items() if k != "review_pages"}, indent=2))
    if problems:
        raise SystemExit(1)


def check() -> None:
    approval_path = OUT / "approval.json"
    if not approval_path.is_file():
        raise SystemExit("No explicit visual approval recorded; inspect the generated review pages first.")
    approval = read(approval_path)
    if approval.get("status") != "reviewed":
        raise SystemExit("The current snapshot has not completed its visual review.")
    expected = approval["reviewed_assets"]
    actual = {str(p.relative_to(ROOT)): p for p in (ROOT / "assets").rglob("*") if p.is_file() and p.suffix in VISUAL}
    problems = ["unreviewed asset: " + p for p in sorted(actual.keys() - expected.keys())]
    problems += ["reviewed asset removed: " + p for p in sorted(expected.keys() - actual.keys())]
    problems += ["reviewed asset changed: " + p for p in sorted(expected.keys() & actual.keys()) if sha(actual[p]) != expected[p]["sha256"]]
    dispositions = {"accepted-painted", "accepted-design-study", "accepted-theme-asset", "technical-exception"}
    problems += ["unresolved visual disposition: " + p for p in expected if expected[p].get("disposition") not in dispositions]
    if problems:
        print("\n".join(problems[:25]))
        raise SystemExit(1)
    print(f"STYLE REVIEW SNAPSHOT PASS: {len(actual)} visual/theme assets match explicit reviewed dispositions; technical exceptions are named, not automatically approved illustrations.")


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--check", action="store_true")
    args = parser.parse_args()
    check() if args.check else scan()
