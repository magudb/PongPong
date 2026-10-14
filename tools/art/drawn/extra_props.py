"""Fill legacy wall and collider-only prop names without runtime placeholders."""
from __future__ import annotations

import json
from pathlib import Path

import numpy as np
from PIL import Image

from terrain import HERE, ROOT, OW, OH, periodic, sample


def build() -> None:
    sheet = Image.open(HERE / "sources/terrain.png").convert("RGB")
    materials = []
    for index in (8, 10):
        row, col = divmod(index, 3)
        box = (round(col * sheet.width / 3) + 4, round(row * sheet.height / 4) + 4,
               round((col + 1) * sheet.width / 3) - 4, round((row + 1) * sheet.height / 4) - 4)
        materials.append(periodic(sheet.crop(box)))
    folder = ROOT / "assets/iso_props/drawn_extra"
    folder.mkdir(exist_ok=True)
    manifest = {"_source": "Painted terrain materials for orthographic walls; collision-only names reuse their exact visual source."}
    yy, xx = np.mgrid[:OH + 70, :OW]
    for kind, count, material in (("forest", 3, materials[1]), ("cave", 2, materials[0])):
        for index in range(count):
            top = 13 + 4 * np.sin(xx * np.pi * 2 / OW) - 8 * np.abs(np.sin(xx * np.pi * (3 + index) / OW))
            rgb = sample(material, xx / OW + index * .23, yy / (OH + 70))
            shade = .91 - .23 * np.clip(yy / (OH + 70), 0, 1)
            rgb *= shade[:, :, None]
            ink = np.clip(2.5 - (yy - top), 0, 1) * .5
            rgb = rgb * (1 - ink[:, :, None]) + np.array([55, 48, 55]) * ink[:, :, None]
            alpha = np.clip(yy - top + .5, 0, 1)
            image = Image.fromarray(np.dstack((np.clip(rgb, 0, 255), alpha * 255)).astype("uint8"))
            name = f"{kind}_wall_{chr(97 + index)}"
            image.save(folder / (name + ".webp"), lossless=True)
            manifest[name] = {"file": name + ".webp", "size": list(image.size), "pivot": [OW / 2, 70 + OH / 2],
                              "footprint": [1, 1], "proj": "ortho"}
    original = json.loads((ROOT / "assets/iso_props/props.json").read_text())
    aliases = {"cave_stone": "cave_stone_a", **{name + "_solid": name for name in
              ("crown_s_a", "crown_s_b", "crown_m_a", "crown_m_b")}}
    for alias, name in aliases.items():
        entry = dict(original[name])
        entry["file"] = "../" + entry["file"]
        entry["visual_alias_of"] = name
        manifest[alias] = entry
    (folder / "props.json").write_text(json.dumps(manifest, indent=2) + "\n")
    print("Packed 5 painted orthographic walls and 5 exact visual aliases")


if __name__ == "__main__":
    build()
