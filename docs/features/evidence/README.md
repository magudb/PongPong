# Evidence for later reviewers (feature content, package F1)

Pictures and numbers that the review of the feature addendum relied on.  They are NOT produced by this repo's build: they are copies of the review artifacts (`PongPong_lift/features/FR/shots`, `.../S/shots`,
`.../FD/schemas`), kept so that F5 (wardrobe runtime), F6 (home world), F7 / F8 (screens), A2 (garment art) and the QA package can see what the claims were measured on.  The folder is under `docs/`, which has a
`.gdignore`: Godot neither imports nor exports these files.  What each file shows (I looked at every picture):

| file | what it shows | which decision rests on it |
|---|---|---|
| `shader/mirror_stock.png` | three foxes in a straw hat and a lilac shirt: standing, mid dodge-roll with the stock layers (the hat floats above the body and the shirt stays UPRIGHT while the body rolls away), and the roll with the layers container that mirrors position / rotation / scale / modulate: clothes now roll with the body, but hat and shirt keep their un-flashed colours while the body flashes pink | V6 / RV-A1: the container mirror fixes the SPIN, not the TINT |
| `shader/mirror_fixed.png` | the same three foxes with the shader fix (`varying vec4 vmod = COLOR` in `vertex()`, `* vmod` in `fragment()` of the layer and halo shaders): in the right fox the hat and the shirt take the damage flash with the body | RV-A1 / DF13: both shaders must multiply the inherited modulate; F5 task 1 |
| `shader/fade_halo_fixed.png` | a fairy in a pale-yellow dress and a gold circlet at alpha 1, 0.5 and 0.15 with the halo: body, clothes, crown and halo fade together | RV-A1: `wardrobe.layers_tint_and_fade_with_hero` |
| `shader/ladder_aura4_compare_z0.4_x2.png` | LEFT: the five rarities of one garment set on a fox, a mushroom-hat figure and a fairy with ONE palette, game zoom 0.4, shader effects only: almost no difference; RIGHT: with the hero-level RarityAura (unique soft pale-pink, legendary gold with a pulse): unique and legendary read at a glance, uncommon and rare stay palette + sheen | RV-A4 / DF25: why rarity of clothes in the world is carried by the item's palette (rule R20) and, for unique / legendary, by the aura |
| `icons/family_check_cast_vs_furniture.png` | two rows of icons on parchment tiles: the 12 cast / material icons above, 12 furniture icons below (chair, bed, round table, chest, grandfather clock, tray, plant, ...): same outline weight, same soft light, no ground shadow | RV-A3: the 130 furniture icons were re-made in the contract style (ink ring 2 px, no shadow, fill 0.91-0.92) |
| `icons/furniture_130_fixed.png` | the 130 re-made furniture icons on a 13 x 10 contact sheet: beds, tables, chairs, sofas, wardrobes, bookshelves, rugs, lamps, fireplaces, chests, plants, clocks, thrones, pianos, paintings, shelves, curtains, sconces, vases, candelabras, chandeliers, ladders of five rarities per template where they exist | RV-A3, RV-A6: 91 of 110 (template, rarity) cells exist; big pieces change shape up the ladder, small decor is palette only |
| `icons/legendary_sticker_variant.png` | the 11 legendary furniture icons on the night tile `2f3654` with the pale 4 px die-cut rim `e4eff5`: the dark pieces (chest_rune, clock_moon, piano_star, bookshelf_floating, chandelier_star) read clearly | RV-A2 / DF26: ink on the night tile is 1.25:1, ink vs rim 12.4:1, rim vs night 10.1:1 |
| `walk/walk8_720_z0.4.png` | 8 directions x 4 heroes (fox with hat and shirt, a hobbit in a berry cap, two fairies) at the 1280 x 720 base and zoom 0.4: no rectangles, halos or seams of the packed layer sheets after minification | V7: remains the windowed regression `wardrobe.minify_no_bleed` (F5) |
| `walk/crop_z0.3.png` | a 4x crop at zoom 0.3 of the same render | V7 |
| `colour_check.json` | CIEDE2000 distances of the legendary ring: the spike home honey (min 7.6 under tritanopia, 7.6 to the focus gold), the spike wardrobe berry (12.4 / 26.0), and the CHOSEN Himmel ring on the night fill: normal 23.4, protan 13.8, deutan 16.9, tritan 19.8, 26.0 from the focus gold | DF2 / CD1: the legendary colours; only SIMULATED, a human colour-blind check is still open |

## The design mocks (not copied: they are the lift sources of F7 / F8 / F9 and of P07)

All under `PongPong_lift/features/FD/shots/`, static renders of the design pack's UI mock (`FD/ui_mock`), rebuilt as live screens by the packages named:

| mock | screen | package | diff target (windowed) |
|---|---|---|---|
| `ui_husbyggeri.png`, `ui_husbyggeri_bygger.png`, `ui_husbyggeri_confirm.png` | Husbyggeri: the ladder of ten steps, the builder state, the confirm dialog | F7 | mean diff <= 18 |
| `ui_indretning.png` | Indretning (placement mode): the ghost, the valid / invalid cue, the hygge card | F7 | <= 22 |
| `ui_boligmagasin.png` | the furniture shop with rarity tabs | P18 | - |
| `ui_garderobe.png` | Garderobe: seven cells, live preview, perks, sets | F8 | <= 20 |
| `ui_rarity.png`, `ui_rarity_cvd.png` | the rarity components and their colour-blind simulations (deuteranopia, protanopia, tritanopia, greyscale) | P07 (RaritySlot, RarityPips, LadderRow) | pixel assertion: five fills, pip counts, legendary the only dark tile |
| `ui_samlerbog.png` | the optional Samlerbog | F9 | - |
