Ghost clothing repair

The rejected fit placed compact human shirts and flat footwear strips over a wisp. The replacement uses painted flowing ponchos, robes and under-hem sashes. Footwear becomes two small hanging hem charms. The head, hands, curl, wisp silhouette, existing character animations and eight-direction clock remain the shipped character art.

`prompts.json` contains the exact imagegen requests, reference roles and saved output paths. All four selected raw masters are retained in `tools/art/drawn/sources/wardrobe/ghost-drape/`. The first upper sheet supplied seven directions; the separate SE row completes it. The rear repair replaces NW/N/NE with back surfaces and rear strap joins. Front pockets and buttons stay on front views.

Rebuild with `tools/art/.venv/bin/python tools/art/drawn/ghost_drape.py`, or run the full `wardrobe.py` pipeline, which applies the same ghost repair at the end. The packer crops and registers paintings; it does not repaint them. Every charm is registered separately at its original proportions. Source pigments are recorded for these ghost paintings instead of borrowing the human clothing palette calibration.

The runtime registers these garments directly to the round wisp canvas. It does not apply the human shoulder/waist squeeze. Independent clothing slots, ownership, outfit exclusions, saved presets and equipment remain with their existing owners.

Native review evidence is in `docs/qa/ghost-city-review/`. Review includes both ghosts, all 96 catalogue variants, mixed outfits, eight directions and walking with held equipment. This is a review of the new clothing, not a new frame-by-frame approval of the original ghost animations.
