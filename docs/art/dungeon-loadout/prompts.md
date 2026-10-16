# Dungeon equipment painting prompts

Generation uses the built-in imagegen tool. The existing paintings are style references, not repaint targets. Each weapon gets its own eight-view source; its inventory icon is manufactured from the same source. Keep the approved character and tool pixels unchanged.

Reference roles:

- `tools/art/drawn/sources/held_equipment/tools.png`: approved eight-direction object turnarounds and matte materials.
- `assets/isometric_characters/fox/idle.webp`: approved chibi proportions, friendly contour and in-game scale.
- `tools/art/drawn/sources/icons_tools.png`: approved hand-painted item finish and readable functional parts.

## wpn_dagger_thorn, first source

Use case: stylized-concept.
Asset type: production 2D game weapon turnaround, one asset with eight directional views.
Primary request: paint a small, friendly thorn dagger for the Trætoppen storybook game, matching the supplied approved equipment and hero paintings. The dagger has a short broad thorn-shaped carved hardwood blade, a tiny twig guard and a wrapped honey-brown grip. It is a humble normal-rarity forest tool, with visible matte wood grain and warm pencil edges.
Input images: image 1 is the approved tool-turnaround style reference; image 2 is the character scale/style reference; image 3 is the approved item-painting reference. None is an edit target.
Composition: transparent landscape canvas, exactly four equal columns and two equal rows. Eight separate views of the SAME physical dagger, row-major in this exact order: S front, SW front-left, W left profile, NW back-left, N back, NE back-right, E right profile, SE front-right. Each view is upright, point at top and handle at bottom, centered in its cell, same physical scale and 15 percent clear gutter. Camera looks slightly down, matching the references. Show credible different fronts, sides and backs; keep blade/guard/grip construction consistent through the turn.
Style: tactile matte gouache and watercolor, gentle warm pencil contours, softly irregular handmade edges. Readable at roughly 65 pixels tall beside the approved chibi character.
Constraints: real transparent alpha background; no floor, no shadow rectangle, no glow, no characters, no hands, no text, no labels, no divider lines, no watermarks. Only the eight views. Preserve the reference palette and material identity; avoid shiny plastic, vector icons, low-poly geometry and neon.
