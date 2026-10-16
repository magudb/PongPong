# Painted Natlys family

The four NPCs use generated painted turnarounds, the existing drawn packer and
an offline glide/hover deformation. All sprite cells are 256² at pivot128,200.
Their six villager clips contain 28 frames per direction. Camera zoom controls
world size. The ghost heroes retain their approved painted sheets.

From the repo root:

```
tools/art/.venv/bin/python tools/art/ghost_family/check_sources.py
tools/art/.venv/bin/python tools/art/ghost_family/pack_family.py
tools/art/.venv/bin/python tools/art/ghost_family/measure_family.py assets/isometric_characters --painted --check
python3 tools/import/write_import_stubs.py --only characters
```

`pack_family.py --only ghostfam_silke` rebuilds one member. Source filenames
and exact prompts are recorded in docs/art/prompts/ghost-family/. Silke uses
her refined five-view source. The other three use family_turnarounds and
family_rears. All files preserve generated transparency.

`review.py` builds QA contact sheets: every idle direction and the middle frame
of each clip in every direction. The real-window ghostfam_data section adds
dawn, the shop/guest beds, the Wednesday fire, the late lamp vigil and midnight.
Style approval follows those inspections and the numeric source/cast gates.

The glide, hover and measurement code is adapted from Claude's design6 family
handoff. The shared drawn packer remains the atlas contract. No 3D bake or
storybook filter is applied to these painted sources.
