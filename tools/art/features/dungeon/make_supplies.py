#!/usr/bin/env python3
"""Contain the five saved supply paintings; preserve their painted colours."""
import argparse
import hashlib
import json
import re
import sys
from PIL import Image
from make_weapons import ROOT, ICONS, PRESET, contained, trimmed, encoded

HERE = ROOT / 'tools/art/features/dungeon'
sys.path.insert(0, str(ROOT / 'tools/dungeon_loot'))
from live_data import snapshot


def build():
    live = snapshot()
    definitions = live['lua/items/dungeon_supplies.lua']['items']
    tiers = live['lua/config/rarity.lua']['config']['rarity_tiers']
    files = {}
    manifest = {'version': 1, 'size': [128, 128], 'source_tool': 'built-in imagegen', 'items': {}}
    for item, definition in sorted(definitions.items()):
        source = ROOT / 'tools/art/drawn/sources/dungeon_supplies' / (item + '.png')
        rarity = definition.get('rarity', 'normal')
        assert rarity == 'normal', 'review a night variant before changing supply rarity'
        target = ICONS / (item + '.webp')
        files[target] = encoded(contained(trimmed(Image.open(source).convert('RGBA')), 108))
        files[target.with_suffix('.webp.import')] = PRESET.encode()
        manifest['items'][item] = {
            'file': target.name, 'rarity': rarity,
            'source': str(source.relative_to(ROOT)),
            'source_sha256': hashlib.sha256(source.read_bytes()).hexdigest(),
            'ring': tiers[rarity]['ui']['ring'],
        }
    assert len(manifest['items']) == 5
    files[HERE / 'supplies.json'] = (json.dumps(manifest, indent=2) + '\n').encode()
    return files


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--check', action='store_true')
    args = parser.parse_args()
    stale = []
    for path, data in build().items():
        if args.check:
            if path.suffix == '.import' and path.exists():
                if not all(re.search(r'^' + re.escape(line) + r'\s*$', path.read_text(), re.M) for line in
                           ['compress/mode=0', 'mipmaps/generate=false', 'process/fix_alpha_border=true']):
                    stale.append(str(path.relative_to(ROOT)))
            elif not path.exists() or path.read_bytes() != data:
                stale.append(str(path.relative_to(ROOT)))
        else:
            path.parent.mkdir(parents=True, exist_ok=True)
            if path.suffix != '.import' or not path.exists():
                path.write_bytes(data)
    if stale:
        raise SystemExit('stale: ' + ', '.join(stale))
    print('Five painted supply icons ' + ('verified' if args.check else 'packed'))


if __name__ == '__main__':
    main()
