# Dark Forest story and the search for our mother

Status: the user confirmed the premise and reference on 2026-10-16. Mørkeskoven's central story is a journey to discover what happened to the playable character's mother, inspired by *The Hazel Wood* by Melissa Albert. The chapter treatment below is a proposed original story. The mother's final fate remains open.

This addendum governs narrative motivation, story progression and family continuity. [DUNGEON_V2_ADDENDUM.md](DUNGEON_V2_ADDENDUM.md) still governs the twelve floors, runestones, bosses, resources and Skovlift. [The art style guide](../art/style-guide.txt) governs all paintings. The [Secret Garden implementation](SECRET_GARDEN_ADDENDUM.md) supplies the first mother letter, post-route account, lift record and forest-edge trace as a playable restoration quest. The deeper forest chapters below remain proposed content.

## The story we are telling

Our mother disappeared into Mørkeskoven before we arrived at the farm. We remember her, but we do not know why she went into the forest or why she never returned. A watermarked letter in her handwriting gives us the first trace. We make a home above the trees while following her path below them.

The forest holds places inside unfinished tales. A path can lead to a remembered kitchen. An empty chair can be waiting for someone whose name has slipped away. Familiar voices repeat something said years ago. As we travel deeper, the stories our mother told us become clues to what she was doing there.

The proposed mystery is that she was restoring routes home for people caught in these tales. She discovered that the forest was beginning to forget those routes. Her last attempt to keep a way open bound her own story to the wood. We must establish what she chose, what the forest demanded, and what became of her. Her surviving notes record her actions; they do not prove that she is still alive.

Farming gives us a home to return to. Preparing food, learning a neighbour's story, repairing equipment and carrying a lantern all help the journey. Mining and rare loot remain useful side activities. The reason to descend is personal: **what happened to our mother?**

## What we take from The Hazel Wood

The creative reference is the unsettling meeting of family history and fairy tales: a missing mother, a journey beyond familiar life, and stories whose rules have real consequences. The [publisher's synopsis](https://us.macmillan.com/books/9781250147912/thehazelwood/) establishes that reference.

Our treatment uses Trætoppen's own cast, a home above the forest, the Skovlift, lanterns, remembered paths and the changing twelve-floor wood. The proposed places, encounters and resolution below belong to this game. Write new dialogue in the game's short Danish voice, with complete English counterparts.

## The emotional shape

The towns offer warmth and ordinary life. The forest is beautiful, strange and increasingly unsettling. Its danger comes from impossible hospitality, repeating places, unreliable memories and rules that almost make sense. Keep the existing painted chibi bodies, tactile materials and readable paths as the surroundings become stranger.

Give the player room to be curious and afraid. Quiet scenes can carry the unease: two cups on a table where nobody lives; a lamp that was recently filled; a footprint that ends at an unmarked door. The player can return home and resume later. Nothing bad happens to the mother because the player spent a week farming or helping a neighbour.

The investigation reveals the mother's intentions as well as her absence. She made choices and left practical work behind. Town friends help us understand that work. Their incomplete memories are gaps in knowledge, not a reveal that every friendly character has been deceiving us.

## How the forest behaves

These are proposed narrative rules for authored encounters. Teach each one safely before asking the player to rely on it.

| Rule | First example | Later use |
|---|---|---|
| A familiar voice can be an old echo. | A whisper repeats the same sentence while the scene resets around it. | An echo can reveal what our mother once said, but cannot tell us where she is now. |
| A place remembers what was done there. | A repaired lamp reveals the next mark on a path. | Restore a small act of care to uncover a route hidden by an unfinished tale. |
| A tale tries to give its visitors a role. | An empty house sets a place for an unnamed guest. | We can question the role offered to us and learn whose place was left empty. |
| The route home needs a witness. | A runestone records a path after we reach it. | Carry a discovered account back to a trusted person, then use it to recognise the real route. |

Memory puzzles expose their clues in pictures and text. They do not require hearing a particular voice, recalling an exact sentence from hours earlier, or choosing a perfect answer in one attempt. A wrong interpretation gives another clue and can be retried.

## Chapters and discoveries

Depths are narrative targets within the existing four bands. They do not change floor geometry, boss locations or the unlock day. Each chapter has one question, an observable discovery and a clear next lead. The companion [chapter data](dark-forest-story/chapters.json) names dependencies, evidence and proposed completion conditions.

| Chapter | Where | What we do | What we learn |
|---|---|---|---|
| S01 The letter without a sender | Farm and Posthuset | Read a watermarked letter. Ask Postbud Pip to inspect its route. | The handwriting is our mother's. Its last leg came through the forest lift; its date cannot be read. |
| S02 The last descent | Trætoppen and Skovkanten | Compare Oak's lift record with the mark on the letter. Take the Skovlift and inspect the trailhead. | Mother entered with a lantern and surveying tools. We have a specific path to follow. |
| S03 A path missing from the map | Floors 1–4 | Find a marked lamp and compare the recovered map with Natteblik's account. Resolve the first depth checkpoint. | Mother and Natteblik once charted safe paths. She marked a route that does not appear on his map. |
| S04 The house that remembers | Floors 5–6 | Enter an authored memory clearing. Restore the lamp and inspect the table, sewing basket and unfinished map. | She sheltered lost travellers here. This is a preserved scene from her journey, not evidence that she is in the next room. |
| S05 The names in the roots | Floors 7–8 | Follow traces of people whose names have been replaced by roles. Help one recover their own account. Resolve the second checkpoint. | The forest's unfinished tales are holding people in place. Mother's work was about getting them home. |
| S06 What she promised | Floors 9–10 | Match her recorded words with a damaged route stone and a witnessed account. | She chose to keep a return path open. The forest attached a condition to that choice; her last note stops before the outcome. |
| S07 Beyond the last light | Floors 11–12 | Assemble the accounts and reach the source of the broken routes. Resolve the final depth checkpoint. | We can reconstruct her last journey and confront the force that bound her story to the wood. |
| S08 What happened to our mother | Final story clearing and return home | Follow the last confirmed trace and resolve the mother's story. | The ending must answer what happened, why she could not return, and what happens now. Her fate is a pending creative decision. |

The proposed force at the heart of the forest is **Rodskriveren / the Root Scribe**: something that keeps trying to complete people's lives as fixed tales. Its presence appears first in repaired signs that change wording, then in roots that frame a room like a page. The name, form and exact encounter remain proposals. Existing bosses guard depth progression; they do not each become a new version of this character.

S04 uses an authored clearing with room-like props inside the forest, rather than pretending the current house-interior system already supports a new story house. A later production choice may make it a separate room if its travel and save behavior are implemented and tested.

S08 follows S07 as part of the complete released arc. An undecided authoring ending must never become an in-game quest that strands the player at the final door. The authoring package is incomplete until the revelation and return scene are written.

## The people who help us

| Character | Role in the investigation | Continuity |
|---|---|---|
| Postbud Pip | Establishes where the first letter came from and keeps later discoveries readable at home. | Uses the existing post-office and mail identity. The letter does not replace the first-morning farm letter. |
| Vagten Oak | Provides the last reliable lift record and practical advice for the first descent. | The Skovlift remains the only route into and out of the forest. |
| Natteblik | Recognises the map and explains how mother's route differs from his. | Keep his established forest locations and night-entry behavior. A missed visit can be retried. |
| Fru Ugle | Helps distinguish a remembered echo from a new message. | She helps every hero; appraisal and her existing services remain available. |
| Smeden Thorin | Repairs useful equipment and supplies expedition side quests. | Ore delivery is a side quest, not the plot reason for searching for our mother. |
| Familien Natlys | Knows how to keep a home light burning for a traveller. | All heroes can ask for help. Ghost heroes also have the established family relationship below. |

Story conversations need a dedicated topic alongside each character's normal services. They must remain available after an unrelated shop, social or repeatable quest conversation. Essential clues require no friendship threshold, festival date, paid appraisal or rare resource roll.

## All eight heroes and the family history

Every playable hero has the same central question and access to the whole story. Species perks can change traversal and optional observations, never whether the player can discover what happened. Use **our mother / mor** and keep her personal name open. Her design follows the selected hero's species; a single fixed human or ghost portrait cannot stand in for every mother.

For the two ghost heroes, the mother is **Dyne's youngest child and Silke's sibling**. Silke is Blund's mother, not the playable hero's missing mother. The player remains Dyne's grandchild and Blund's cousin. For animal, fairy and hobbit heroes, the Natlys family are friends, not newly assigned biological relatives. Ghost identity is a species choice and does not establish anyone's fate in the mystery.

Mother disappeared after the hero was born and knew her, before the farm arrival. This replaces the old design chronology that put Dyne's youngest in the forest before the hero's birth. The hero's gender stays unspecified; identifying the missing parent as their mother does not gender the hero.

Two unvoiced localization rows were revised with the Secret Garden integration:

| Existing key | New meaning |
|---|---|
| `DLG_GHOSTFAM_DYNE_KIN_1_4` | Dyne identifies her youngest as the hero's mother, says she entered the forest, and leaves her fate unknown. |
| `DLG_GHOSTFAM_SILKE_KIN_1_1` | Silke identifies the hero's mother as her sibling; the cousin relationship stays the same. |

The target text is in [draft copy](dark-forest-story/copy.csv). The runtime rows now use these draft targets. Frozen voiced rows are unchanged. After finding the garden letter, existing saves can revisit the relationship through the repeatable family garden topic even if their first-meeting flags are already set.

The Fairy King's farm lottery remains genuine. It gives us a home from which to search; it is not secretly a trap, a reward for finishing the mystery, or proof that the king knows the ending.

## Journey and return

The playable S01 introduction comes through the communal garden's seed basket after its flowers open. The garden quest is available after the first-morning introduction and can be left for later. It does not replace the farm mail or require waiting until week two. S02 respects the configured Skovlift unlock. A player who has already visited the hub can still begin the story.

Every descent should offer a useful trace or a comprehensible route to the next one. Reaching deeper layers matters, but clues are authored evidence rather than ordinary loot. Give each clue a stable story ID separate from a generated floor's cell or daily seed. Put it on a reachable required route, not in a random chest or behind a paid optional service.

Discoveries belong in a persistent journal section: the observation, the person or place that supports it, and the next lead. Distinguish **seen**, **remembered** and **suspected** so an echo is not silently promoted into proof. Reading or collecting a clue and recording its story flag must commit together. Re-reading can repeat text but cannot grant a reward twice.

Changing day, leaving a run, fainting or loading a save keeps confirmed evidence. If a daily layout changes, the next unrecovered clue is placed again through its story ID. Already resolved depth bosses do not need to be defeated again solely for a story flag; conversely, reading a clue does not bypass an undefeated boss or a locked rune.

The player may find a later trace early. Record it, keep its text available, and resolve prerequisites when the earlier chapters catch up. A missed first encounter, a full inventory, an already-met relative, or the wrong entry hour must never consume the only copy of an essential clue.

## The final revelation

The user's confirmed goal is to discover what happened to our mother. Her fate has not been chosen. Keep the setup compatible with a hopeful reunion or a bittersweet discovery; echoes and old notes must not assert that she is currently alive or dead.

A hopeful treatment would let us free her from the role the forest has given her and choose a way home together. A bittersweet treatment would reveal her fate clearly and give the player a meaningful return scene with what she left behind. These are alternatives for the authoring decision, not a player menu that decides retrospectively whether their mother lived.

Whichever ending is chosen, answer the mystery in this game. Do not replace the answer with another unsigned note or a sequel tease. Let the mother have a voice and intentions in the revelation. Return to the farm and the people who helped; leave free play, friendship and ordinary forest expeditions available afterwards.

## Art and sound

The approved matte gouache and watercolor style stays. Use night blue, shadow moss, quiet teal and small owl-gold lights from the [style guide](../art/style-guide.txt). Make the forest strange through composition, repetition, impossible arrangements and small familiar objects. Preserve hero faces, silhouettes, walkability and lantern contrast.

Proposed story assets are the watermarked letter, a recognisable lamp repair, the memory-table arrangement and the Root Scribe's root-and-paper motif. [Saved prompts](../art/dark-forest-story/prompts.txt) describe source paintings and reference roles. They are ungenerated proposals; no approved asset needs replacing simply because the story changed.

Use restrained wind, a distant latch, an interrupted tune and the return of familiar ambient sounds. Any sound clue needs a text or visual counterpart. New Danish and English text stays draft; there are no new recordings or changes to frozen voice lines in this design pass.

## Implementation handoff

1. **Story state and journal.** Define a versioned, saved evidence record and the distinction between observation and interpretation. Extend the existing quest, dialogue and save services where appropriate; the data in this directory is an authoring contract, not a supported new Lua API.
2. **First playable chapter, implemented.** The `secret_garden` quest integrates the first letter, Pip's account, Oak's lift record and the forest-edge trace, plus the two family copy revisions and an existing-save catch-up topic. Normal mail, family greetings, shops and the lift gate remain in place. Its runtime copy is draft, with registered key ownership.
3. **Forest chapters.** Add guaranteed reachable clue anchors to the dungeon generator and authored encounters. Bind existing depth checkpoints to narrative progress without replacing the original boss/rune rules. Deliver S03–S07 with the persistent journal.
4. **Finale.** Settle the mother's fate, write S08 and its return scene, then connect the complete arc. No partial finale is advertised as a finished playable story.
5. **Story art.** Generate only the approved asset requests, using the saved references, then inspect them beside all hero species and in dark native scenes. Preserve the existing placement, alpha, sorting and memory contracts.

Acceptance for the implementation includes all eight heroes, new and existing saves, family first meetings already consumed, out-of-order clues, full packs, repeated reads, daytime/night-entry Natteblik, leaving and re-entering, new daily layouts, fainting and save/load between discovery and reward. Every chosen ending must resolve the mother's fate and leave post-story play usable.

The pending deeper dungeon, final narrative scenes and proposed new art are not implemented by the garden quest. M1b's original acceptance remains historical; current town proofs are renewed for the changed runtime.
