# Forest dressing

`ForestDress.attach(area, {fireflies, mist, unshaded})` is the single entry point for orthogonal forest/cave areas. D2 calls it after generated-floor arrival. The registered `forest_dress` marker defers the same call until all authored markers are built. Attachment is idempotent; isometric farm/town areas keep their own lighting.

`hulen_keeper npc=mapseller_natteblik` freezes the entry's day/night decision. At night it builds the real NPC handler with its normal dialogue/services. Daytime builds the approved hanging-bat painting and a repeatable sleeping whisper; it consumes no story evidence.

Actor lighting preserves each wardrobe ShaderMaterial instance and its animation/palette/occlusion uniforms, switching only to a cached unshaded shader variant. Plain sprites use a shared unshaded material; additive sprites retain their blend mode. Leaving the forest restores the original shader/material and lantern texture. Newly created clothing layers and loot are discovered at 10 Hz. No character or environment painting is modified.

Soft ground uses three grid-derived technical masks and the approved seamless path, water and moss paintings. Collision, terrain IDs, generator output and minimap cells remain unchanged; normal tiles stay underneath as a fallback. One trigger per connected pond component gives the documented fishing placeholder once per generated floor/day, persisted through the existing cell state.

Native inspection caught that the historical `floor_patch_a/b/c` props resolve to timber planks. Forest glow decals therefore use the approved effective `forest_floor_glow_o` painting instead. The older assets are retained byte-for-byte; no wooden platforms are introduced around forest mushrooms by this feature.

One 40-particle CPU field follows the camera. Two approved mist paintings drift on GroundFx at low opacity. Lights are checked at build using disk intersections and centers: twelve map lights may overlap, with a conservative fifteen-map-light limit reserving the sixteenth slot for the player's lantern. A rejected light is disabled and recorded as `forest_light_budget` in the map's build errors. Glow mushrooms use additive artwork and need no individual PointLight2D.

Numbers are in `lua/config/forest_look.lua`. Native evidence and measured limits are recorded under `docs/qa/mechanics/dungeon/look/`; the original prototype's flat-vector sketch is a composition reference, while the approved painted assets remain authoritative.
