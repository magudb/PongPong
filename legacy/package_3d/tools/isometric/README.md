# Rebuild the PNG sprite sheets (offline authoring tool)

The Godot **game runtime does not need Python, VTK or GLB assets**. This script allows regenerating the transparent 2D PNG atlases from the included 3D character source files, including their skin deformation and UV textures.

```sh
cd PongPong
python -m pip install -r tools/isometric/requirements.txt
python tools/isometric/bake_sprite_atlases.py fox
python tools/isometric/bake_sprite_atlases.py bat cat bear rabbit fairy monkey capybara fox raccoon penguin hedgehog frog
python tests/validate_isometric.py
```

The baked PNGs use eight isometric viewpoints, frame size 256x256 with ground pivot (128,200), and 11 standard clips plus four flyer-only clips. The main game only reads the PNGs and its own Godot scripts and scenes. VTK is used only for offline rendering and is not required for game exports.
