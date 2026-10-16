# The Secret Garden and the main restoration story

The user selected *The Secret Garden* by Frances Hodgson Burnett as the foundation for the main farm-and-town story on 2026-10-16. Restoring a neglected place, accepting help and making a home now connect the everyday game to the search for our mother. *The Hazel Wood* remains the reference for the Dark Forest mystery.

The playable implementation is the `secret_garden` quest and a communal garden north of Hyggebyen's square. Its twelve objectives cover restoration, conversations, overnight growth, the mother's letter, a confirmed trail at Skovkanten and a return to the restored garden. The deeper forest chapters and the mother's final fate remain separate work.

## The story

You win your treetop farm and make a life among the neighbours while looking for traces of your mother. A forgotten communal garden offers somewhere to begin helping. Hoppe kept its seeds; Brumme saved the materials for its bench. Together you make a place worth returning to.

The flowers reveal an old letter in your mother's handwriting. Pip recognises the seed box's route through the Skovlift, and Oak finds her name in the lift record. At Skovkanten, the same stitched mark identifies a box with a scrap of map leading deeper into Mørkeskoven.

The garden has its own satisfying conclusion. Its path is clear, its bench repaired and its beds in flower. The letter and trail remain readable. None of these traces establishes whether the mother is currently alive or dead.

Burnett's restoration and friendship structure is the creative foundation; the cast, place and mother investigation are original to Trætoppen. [The publisher's synopsis](https://www.panmacmillan.com/authors/frances-hodgson-burnett/the-secret-garden/9781035058600) describes the novel's abandoned garden and the friendships involved in restoring it.

## How to play

After the opening, accept the garden quest from Hoppe or the notice board inside the garden. Walk through the painted gate north of Hyggebyen's central square. The return gate leads back to town, with its arrival cell outside the trigger.

| Objective | Action |
|---|---|
| Clear the path | Inspect the overgrown path and choose to clear it. |
| Ask Hoppe | Select the garden topic in Hoppe's normal conversation. |
| Ask Brumme | Select the garden topic in Brumme's normal conversation. |
| Restore the bench | Use the materials Brumme left beside the bench. |
| Plant the beds | Plant the communal seeds kept in the garden. |
| Water the beds | Use the garden's watering can. |
| Check the blossoms | Return after the next morning and inspect the beds. |
| Read the letter | Inspect the seed basket; the letter reveals the first mother clue. |
| Ask Pip | Read the garden topic in Postbud Pip's conversation. |
| Ask Oak | Read the garden topic in Vagten Oak's conversation. |
| Follow the trace | Take the Skovlift and inspect the marked box at Skovkanten. |
| Return to the garden | Inspect the restored bench and open the garden for everyone. |

Each world interaction requires a confirmed choice. Cancelling a work page or a story conversation leaves progress unchanged. The garden supplies its own materials, seeds and watering can: the story has no purchase, rare-drop, inventory-capacity or friendship gate. The flowers grow in every season and need one morning after watering. There is no deadline, deterioration or penalty for spending time elsewhere.

Conversations use the existing topic pagination. Shop, gift and other services remain available. Accounts become available when the player reaches their place in the story; Pip and Oak do not reveal later clues in advance. A read topic can be revisited without repeating its quest progress.

The completion reward is 150 gold and one friendship heart each with Hoppe and Brumme, once. The completed garden stays open. Its final page and letter can be reread through the world, and the quest remains in the journal.

## Mother clues and the ghost family

The saved evidence IDs are `letter_watermark`, `post_route`, `lift_record` and `garden_trail`. They are derived from completed quest objectives. They are not inventory items, generated cell IDs or a second unsaved story counter.

For the two ghost heroes, the mother is Dyne's youngest child and Silke's sibling. The two unvoiced first-meeting rows now say so. An optional garden topic repeats that relationship after the letter is found, including for existing saves whose first meetings are already consumed. The other six heroes receive neighbourly support from the Natlys family. The hero's gender stays unspecified, and every frozen voice line stays intact.

This implements the introductory evidence of S01–S02 from [the Dark Forest story](DARK_FOREST_STORY_ADDENDUM.md), through the garden rather than an automatic first-morning letter. S03–S08, including the final revelation, are still proposed adventure content. Completing this quest does not claim that those floors or scenes exist.

## Implementation and saves

`lua/quests/secret_garden.lua` defines the quest. `SecretGardenStory` derives the current step from QuestManager's saved objectives, validates order and finishes explicit NPC story pages. `SecretGardenMarker` supplies the garden work, physical evidence and painted before/after decoration. `DialogueBridge` adds the topic alongside existing services.

The only extra saved scalar is the monotonic day on which the beds were watered. It is written before the watering objective publishes its completion. A day change, area change or save/load cannot erase confirmed evidence. New games reset it through GameManager's existing flag reset.

The marker releases the actor, closes its own dialogue and disconnects listeners on leaving the scene. Parked areas recreate their pictures when re-entered. This avoids stale sprite references and prevents hidden areas from handling progress updates.

There is no new autoload, signal, inventory keepsake, custom save section or replacement journal screen. Existing saves with no garden quest simply see an available quest. Ordinary forest travel still uses the Skovlift and its configured unlock.

## Art and copy

The garden reuses approved painted bushes, blossom trees, wooden fencing, seed baskets, moonflower stages, timber, bench, well, lanterns and notice board. Four planting beds change together from overgrowth to tilled soil, watered seedlings and flowers. The existing non-solid `fence_gate_x` prop marks the walkable entrance in Hyggebyen.

No painting or approved asset bytes changed. World and conversation copy is Danish with English fallback in `localization/secret_garden.csv`; it is draft and unrecorded. The garden pages use the existing parchment dialogue theme, keyboard/controller choices and native text layout.

Validation and any remaining visual-review limits are recorded in `docs/qa/secret-garden/`.
