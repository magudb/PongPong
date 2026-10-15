#!/usr/bin/env python3
"""Pack equipment design studies for review; no gameplay catalog is modified."""
from __future__ import annotations

import json
from pathlib import Path

from PIL import Image

from pack import extract, ROOT, HERE

OUT = ROOT / "assets/art_studies/equipment"
SOURCE = "tools/art/drawn/sources/"
PRESET = '[remap]\nimporter="texture"\ntype="CompressedTexture2D"\n\n[params]\ncompress/mode=0\nmipmaps/generate=false\nprocess/fix_alpha_border=true\n'
HEROES = [
    ("rasmus", "Rasmus", "animal_fox", "fox", "Ear openings; tail stays outside the lower layer."),
    ("kiki", "Kiki", "animal_monkey", "monkey", "Round ear openings; curled tail stays clear of the belt."),
    ("kloevermynte", "Kløvermynte", "fairy_meadow", "fairy", "Hair buns and lavender wings remain visible."),
    ("bertil", "Bertil", "hobbit_pip", "hobbit_pip", "Curls, pointed ears and bare toes; fitted ankle-wrap footwear."),
    ("birk", "Birk", "fairy_birk", "fairy_birk", "Blue wing roots clear; the stock leaf cap is removable clothing."),
    ("bodil", "Bodil", "hobbit_bodil", "hobbit_bodil", "Braids outside the collar; front hair over the hat brim."),
    ("bu", "Pedro", "ghost_bu", "ghost_bu", "Floating wisp and hands; footwear becomes hem tabs, with no legs."),
    ("hviske", "Hviske", "ghost_hviske", "ghost_hviske", "Pink/lilac ghost material stays distinct from worn fabric."),
]
OUTFITS = [("work", "Work"), ("forest", "Forest"), ("festival", "Festival")]
HELD_ITEMS = ["iron_sword", "hoe_wooden", "staff_branch", "spear_twig",
              "axe_wooden", "watering_can", "club_spruce", "dagger_thorn"]
# References establish design intent. They do not assert that a flattened look
# implements every named garment, or add future dungeon weapons to the live game.
ITEMS = [
    ("hat_straw", "Straw hat", "clothing", "hat_straw_plain", "existing", "hat"),
    ("hat_forest", "Woodland cap", "clothing", "hat_cap_green", "existing", "hat"),
    ("shirt_linen", "Linen shirt", "clothing", "shirt_linen_cream", "existing", "shirt"),
    ("dress_petal", "Petal dress", "clothing", "dress_gown_lavender", "existing", "dress"),
    ("shoes_boots", "Soft boots", "clothing", "shoes_boots_brown", "existing", "shoes"),
    ("sword_rusty", "Rusty sword", "weapon", "sword_rusty", "existing", "weapon"),
    ("iron_sword", "Iron sword", "weapon", "iron_sword", "existing", "weapon"),
    ("dagger_thorn", "Thorn dagger", "weapon", "wpn_dagger_thorn", "planned", "weapon"),
    ("spear_twig", "Twig spear", "weapon", "wpn_spear_twig", "planned", "weapon"),
    ("staff_branch", "Hazel staff", "weapon", "wpn_staff_branch", "planned", "weapon"),
    ("club_spruce", "Spruce club", "weapon", "wpn_club_spruce", "planned", "weapon"),
    ("hoe_wooden", "Wooden hoe", "tool", "hoe_wooden", "existing", "tool_hoe"),
    ("axe_wooden", "Wooden axe", "tool", "axe_wooden", "existing", "tool_axe"),
    ("pickaxe_copper", "Copper pickaxe", "tool", "pickaxe_copper", "existing", "tool_pickaxe"),
    ("watering_can", "Copper watering can", "tool", "watering_can_copper", "existing", "tool_watering"),
    ("fishing_rod", "Fishing rod", "tool", "fishing_rod", "existing", "hotbar_action"),
    ("lantern", "Hand lantern", "system_prop", "", "presentation_only", "action"),
    ("health_tonic", "Health tonic", "consumable", "health_tonic", "existing", "action"),
    ("turnip_seeds", "Seed packet", "consumable", "turnip_seeds", "existing", "action"),
    ("necklace_leaf", "Leaf necklace", "clothing", "necklace_leaf", "existing", "necklace"),
]


def export(name: str, image: Image.Image, source: str, canvas: tuple[int, int]) -> dict:
    """Trim/fit the generated drawing for the native review UI; retain the master."""
    image = image.copy()
    image.thumbnail((canvas[0] - 16, canvas[1] - 16), Image.Resampling.LANCZOS)
    frame = Image.new("RGBA", canvas)
    frame.alpha_composite(image, ((canvas[0] - image.width) // 2, canvas[1] - image.height - 8))
    frame.save(OUT / (name + ".webp"), lossless=True, method=4, exact=True)
    preset = OUT / (name + ".webp.import")
    if not preset.exists():
        preset.write_text(PRESET)
    return {"file": str((OUT / (name + ".webp")).relative_to(ROOT)), "size": list(canvas),
            "source": SOURCE + source, "status": "concept", "views": ["front_three_quarter"]}


def main() -> None:
    OUT.mkdir(parents=True, exist_ok=True)
    manifest = {
        "version": 1,
        "scope": "Flattened outfit concepts and equipment shape studies. No fitted animation layers or gameplay changes.",
        "heroes": [{"id": id_, "name": name, "skin": skin, "body": body, "fit": fit}
                   for id_, name, skin, body, fit in HEROES],
        "outfits": [{"id": id_, "name": name} for id_, name in OUTFITS],
        "review_modes": [{"id": id_, "name": name} for id_, name in OUTFITS] + [{"id": "held", "name": "In hand"}],
        "looks": {}, "held_examples": {}, "items": {},
    }
    for sheet, heroes in [("a", HEROES[:4]), ("b", HEROES[4:])]:
        source = f"equipment_looks_{sheet}.png"
        drawings = extract(HERE / "sources" / source, 3, 4)
        for row, (outfit, _) in enumerate(OUTFITS):
            for column, hero in enumerate(heroes):
                name = hero[0] + "_" + outfit
                manifest["looks"][name] = export(name, drawings[row * 4 + column], source, (256, 320))
    source = "equipment_held_examples.png"
    for hero, item, drawing in zip(HEROES, HELD_ITEMS, extract(HERE / "sources" / source, 2, 4), strict=True):
        rec = export(hero[0] + "_held", drawing, source, (256, 320))
        rec["equipment"] = item
        manifest["held_examples"][hero[0]] = rec
    source = "equipment_kit.png"
    for entry, drawing in zip(ITEMS, extract(HERE / "sources" / source, 4, 5), strict=True):
        id_, name, kind, ref, state, slot = entry
        rec = export(id_, drawing, source, (160, 160))
        rec.update(name=name, kind=kind, reference_id=ref, reference_status=state, presentation_slot=slot)
        manifest["items"][id_] = rec
    (OUT / "manifest.json").write_text(json.dumps(manifest, ensure_ascii=False, indent=2) + "\n")
    print("Packed 24 outfit concepts, 8 equipped-pose concepts and 20 equipment studies; no gameplay catalogs changed")


if __name__ == "__main__":
    main()
