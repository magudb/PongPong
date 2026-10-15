# Claude worktree art coverage

Updated `PongPong-worktrees/m1a` on 2026-10-14. Merge `df5d641` brings in the
drawn characters, painted buildings, ground contact and painted outdoor tiles
from main. Claude's later commit `38b78ce` and unfinished feature work are
preserved. The coverage additions remain in this working tree.

The original 420 changed or untracked files were copied and hash-verified before
the merge. Recovery snapshot:
`../.codex-backups/m1a-art-sync-20261014-202636/snapshot.json`.

The [runtime audit](coverage.json) reports **zero gaps**:

| Content | Checked |
| --- | ---: |
| Character folders, with drawn sources and portraits | 58 |
| Character animation sheets | 474 |
| Registered NPCs resolving to their own artwork | 30 |
| Skin chains | 15 |
| Animal and enemy visual references | 25 |
| Registered item icons | 345 |
| Effective painted terrain types | 29 |
| Declared, authored or mapped prop resources | 253 |

The audit uses the live Lua registry, actual character resolution, loaded art
manifests and map references. It checks the effective texture paths, including
late-sorting farm and interior overrides. No active hero resolves to a different
character. Birk and Bodil have their own dressed stock art while wardrobe bases
are pending.

The additional pass draws the six new cast NPCs and both ghosts, updates Morfar
Mis and Kløvermynte, and fills 183 missing item pictures, including 96 wardrobe
variants. Existing illustrated home icons remain available. All 25 outdoor and
four interior floor materials now come from painted sources. Five missing
orthographic wall pictures and five exact visual aliases remove the remaining
prop placeholders. Prop coverage verifies resources; it does not claim that
every existing city or farm structure was repainted in this pass.

The Natlys family members Dyne, Gnist, Silke and Blund remain design entries,
outside the registered runtime cast. Future wardrobe-base assets are likewise
separate content packages.

The [strict headless report](validation-headless.json) passes 618 checks across
13 sections, including art, catalogs, area construction, city integration and
ghost startup. There are no unexpected engine errors or warnings. Ten skips
remain from existing prototype and feature-package checks; some P22 messages
describe older placeholders, while the live coverage audit verifies the installed
resources. The [area render report](validation-area-render.json) passes 15 checks,
including tile seams and building/character depth sorting. The
[farm render report](validation-farm-render.json)
passes all nine checks, including mixed field/grass seams at zoom 0.3, 0.4 and
0.7 and a planted-hairline negative control. The farm uses 16.2 MB of its 20 MB
texture budget. Environment exports use 21.18 MB of the existing 22 MB disk
budget; the six new NPC folders use 7.6 MB. No budget or seam limit was raised.

The ghost silhouette control now verifies distinct visible RGB palettes while
allowing exact alpha equality. The shared silhouette tolerance and neck-line
constraint remain. Birk/Bodil fallback expectations and their simulated stock
fixtures include the newly authored canonical art.

Review the imported engine captures: [cast](cast.png), [terrain](terrain.png),
[world close view](world-close.png), [building alignment](world-footprints.png),
and all item pages: [1](items-1.png), [2](items-2.png), [3](items-3.png), [4](items-4.png).
Icon extraction removes neighbouring-cell fragments while preserving paired
earrings; cloth variants recolour the actual painted pigments.

New artwork was generated with the built-in imagegen tool. Masters, exact
prompts, item recipes, rebuilding commands and the audit command are documented
in [the drawn art tooling](../../../tools/art/drawn/README.md). Full-colour
environment masters are retained; exported sky textures use the existing S3TC
background preset. Legacy tile exports retain identical visible RGBA and alpha.
