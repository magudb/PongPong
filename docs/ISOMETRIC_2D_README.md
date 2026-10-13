# PongPong — Isometric 2D character pack

This is a **new isometric 2D starter inside the supplied PongPong project**. It uses the 12 prior character designs, with baked transparent 2D sprites and character-body movement. The previous game's 3D logic, quests, 3D world, NPC interaction and farming systems have NOT been ported to 2D; they remain in the project as reference code. No 3D models are required by the *new 2D scenes* at runtime.

## Open and play

1. Open `project.godot` in **Godot 4.7** (the target version from the submitted project). The project starts in `res://scenes/isometric/demo_isometric_2d.tscn`.
2. Wait for Godot to import the PNG atlases. Press F5.
3. Walk with **WASD / arrows**, hold **Shift** to run, **Space** to jump, **Tab** to cycle characters. Press **C** to cheer or **E** to try an action.
4. With **Bat** or **Fairy**, press **F** to toggle flight, **Space** to rise, and **Ctrl** to descend.
5. The green diamonds are a demonstration drawn by `isometric_ground_2d.gd`; they are **not** the full game map or a production TileMapLayer.

## Assets and scenes

- `assets/isometric_characters/<character>/idle.png` ... `<clip>.png` — RGBA PNG sprite sheets, **8 directions** in rows and **animation frames** in columns. Each frame is 256×256 with a common pivot at pixel **(128, 200)**. Transparent background. Atlases are untrimmed and consistent across every animation, preventing pivot jitter.
- `assets/isometric_characters/<character>/animations.json` — per-clip frame count, FPS and loop flag.
- `assets/isometric_characters/manifest.json` — normalized manifest for the whole pack.
- `assets/isometric_characters/shadow.png` — ground-contact shadow used by all sprites.
- `scenes/isometric/characters/<character>.tscn` — **drop-in visual**, with preview visible inside Godot's 2D editor. Root `IsoChibiSprite2D` and `Sprite2D` atlas-region animator.
- `scenes/isometric/player_2d.tscn` — standalone playable `CharacterBody2D`, circle collider, camera and sprite visual. Script: `scripts/isometric/iso_player_controller_2d.gd`.
- `scenes/isometric/npc_2d.tscn` — walking `CharacterBody2D` preview actor. Script: `scripts/isometric/iso_wanderer_2d.gd`.
- `scenes/isometric/demo_isometric_2d.tscn` — playable test area with Y-sorted sprites.
- `docs/isometric_previews/` — rendered contact sheets to inspect characters and directions without Godot.

## Import into an existing 2D world

1. Copy `assets/isometric_characters/`, `scripts/isometric/`, and `scenes/isometric/characters/` into the other project under the same `res://` locations.
2. Instantiate `scenes/isometric/characters/fox.tscn` (or another `.tscn`) as a **child of your 2D player controller**. Choose any `character_id` through `load_character("fox")`.
3. Place characters under a `Node2D` with `y_sort_enabled = true`. Their **node positions correspond to the ground contact point**, not the geometric center of the image.
4. In your `CharacterBody2D._physics_process` after `move_and_slide()`, call `visual.update_motion(velocity, is_running, is_in_air, is_flying)`. For jumps or attacks, call `visual.play_action(&"jump")`, `visual.play_action(&"hit")`, etc.
5. `visual.set_altitude(height_in_pixels)` raises the character's drawing while leaving its shadow at ground level; it does not introduce a separate Z-level physics layer.
6. Directions are screen-relative with rows `S, SW, W, NW, N, NE, E, SE`. `set_facing_direction` maps 2D velocity to these rows. To use grid-relative W/A/S/D, turn on `use_diamond_grid_axes` in the player controller.

## Animations / frame counts

| Clip | Standard animals | Fairy / bat |
| --- | --- | --- |
| idle | 4 | 4 |
| walk | 6 | 6 |
| run | 6 | 6 |
| jump | 4 | 4 |
| fall | 3 | 3 |
| land | 3 | 3 |
| celebrate | 6 | 6 |
| interact | 4 | 4 |
| hit | 3 | 3 |
| sleep | 4 | 4 |
| talk | 4 | 4 |
| takeoff / hover / fly / flight_land | — | 4 / 5 / 6 / 4 |

All clips include eight distinct viewing directions. Frame counts are intentionally limited for a lightweight cartoony feel. Non-looping clips return automatically to idle; locomotion then takes over on the next physics frame.

## Design decisions

**Style:** Soft hand-drawn-like chibi visuals preserved from the original animal sketches. These are actual 2D renders of textured, skinned geometry, baked once offline; **no real-time 3D rendering** in the new scenes.

**Dimensions:** 256×256 pixels for every sprite. Animated atlases are `256 * frame_count` wide and 2048 high (8 rows). For an on-screen pixel scale of ~96px tall, set the scene's `Visual.scale` around `0.6` (depending on zoom).

**Movement:** Orthogonal screen-relative WASD by default. The diamond tiles are purely visual. Jump and flight are **fake-height 2D animations**: physics stays in the XY plane. If the final game needs elevation-based hit detection, ramps, or flight through walls, those systems need to be added.

**Collision:** Circle collider on 2D player and NPC prefabs. Gameplay systems should add their own 2D collision layers and tile collision mapping. Existing 3D collision masks are not used by the new demo.

**Textures:** RGBA PNG with alpha and anti-aliased silhouette, baked from original UV textured characters. For memory-constrained platforms, consider converting sheets to compressed `.webp` or reducing frame size; update atlas code if the size changes.

**Animations aren't bone-based at runtime.** They are animated sprite sheets, which is the point of converting to 2D.

## Original PongPong 3D game

The original project was 3D (`CharacterBody3D`, `Node3D`, 3D camera, 3D world). Switching the character sprites does not automatically convert the rest of the game: farms, NPCs, physics triggers, raycasts, 3D interaction systems, saving world coordinates and map content must be migrated separately. The old main menu is still at `res://scenes/main/main_menu.tscn` if needed.

## Verification

The atlas generator script is preserved in the additional build-tools archive. Output atlases were programmatically validated for dimensions, frame changes and transparency; previews were generated and reviewed. **No Godot executable was available in the build environment, so a live Godot import/run test could not be completed.** Run the included `tests/validate_isometric.py` and locally launch the demo before shipping the assets in production.
