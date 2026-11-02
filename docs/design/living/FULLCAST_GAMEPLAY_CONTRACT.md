# Full-cast Living Characters — bounded gameplay contract

## Playable surface

All 34 `LivingData.AUDITED_IDS` have explicit shipped bindings in `lua/social/living_actions.lua`, not a generic profile fallback. Their ordinary physical NPC conversation exposes **What is on your mind?** through the existing More pagination. Protected authored first-meeting scenes retain priority: a ghost hero must read and explicitly close each ghost-family kin introduction before reopening the ordinary social path. The cast fixture performs that prerequisite through the real dialogue UI only for the ghost hero and the four kin actors; it neither forges kin/quest flags nor inserts optional choices into their `social = false` introductions. Animal, fairy and hobbit first-conversation paths are unchanged. Purpose, aspiration, the weighted current conversational motivation, a meaningful authored tie, and an individually written explanation are readable without hearts, romance or a quest.

The registered body's actual request-local immutable completion authorizes these distinct consequences:

- **Repeat back / listen:** acknowledge the specific explanation. A later actual conversation uses that citizen's `LISTENED` reply.
- **Space:** decline further discussion. The later `SPACED` reply respects that response and does not reoffer listening that day.
- **Explain another way:** request a second, individually authored explanation. Only reading that page and explicitly acknowledging it records `clarify`; cancelling either page records no clarification. The later `CLARIFIED` reply uses the corrected distinction.
- Opening, cancelling, a public choice/event, People-book inspection, an NPC name/player ID in a dictionary, or another registered player's ambient scope cannot create a response.

These are actual communication terminals, **not** claims that furniture, cloth, crops, repairs, letters, currency, unlocks or other goods were produced. They do not complete a named NPC tie's attendance. Children, animals and the ghost family use the same non-romantic discovery/response path. Morfar Mis retains his canonical unlock and every hero twin remains absent in its own hero world. The current test fixture places one canonical-definition actor at a time; that is explicitly not proof of every authored map placement.

## Autonomous alternative

The existing TownDirector minute seam examines only loaded actors. A positively authored optional post and native act, exact director/live identity, assigned-seat proximity, actual routine, opening-hour protection, festival/home/hero/unlock restrictions and no hold/talk are prerequisites. No movement, routine interval, essential service or population cap is changed. The general observer waits behind the connected three-citizen pilot.

A value-weighted selected role/personal goal executes a two-game-minute local reflective moment. A connect goal requires its actual named tie at another eligible nearby post, a one-minute authored brief greeting, and continuous exact-actor attendance. Reconciliation is eligible only after a previously witnessed connection to that same named target, and checks the words in another one-minute exchange. If that target is absent, the authored reflective alternative can win; player listening cannot substitute. Active moments reserve their exact actors against other general optional moments. Existing native poses are preserved (ghosts stand, owl perches, children play); facing is the existing communication presentation, not a new voiced cinematic or music performance.

The actor must remain continuously eligible. The per-physics guard checks only retained active weak actors/seats, never a population/catalogue/route scan. Minute checks reject missing targets, protected states, reverse clocks and nonconsecutive time jumps. Unvisited areas do not simulate history. Loading does not resurrect transient dwell. A loaded saved pending occurrence remains uncompleted for that day; there is no inferred historical completion. No historical-day loop or new manager exists.

**Natteblik has no authored leisure post.** His empty safe-post set categorically excludes autonomous completion at the night-sales perch. His route-explanation/repeat-back/correction conversation is the whole-cast semantic path and does not displace the service.

The observer admits and latches a goal at the first feasible loaded optional moment, not by preselecting every absent citizen each dawn. Interrupted occurrences close for that day. This is a deliberate bounded loaded-world implementation; no claim of offscreen autonomous simulation or whole-world dawn planning is made.

## Authority and persistence

`DialogueUI._finish` freezes the actual immutable terminal, then invokes its private `commit` callback in the captured synchronous owner scope **before** voice, choices, focus and modal teardown. `NpcTalkCompletion.commit` checks the originating area and delegates to `Npc2D._commit_talk`; that method authenticates the exact UI result, retains the terminal and calls `SocialManager.living_settle_encounter`. Social validates ticket, actual owner body/registration/profile, model/run origin, originating area, day, exact page/choice and full reading before a callback-free validated commit. `Npc2D._settle_talk` is the later continuation-page/release seam, not this early commit. Callbackful authored flags and essential conversation settlement remain after close, with their retained-origin guards; existing optional continuation checks remain after callbacks. No global EventBus completion consumer is added. The selected persistence-boundary policy and its separately pending integration/verification are described in [PERSISTENCE_BOUNDARY_CONTRACT.md](PERSISTENCE_BOUNDARY_CONTRACT.md); this fixture/documentation migration changes no production code.

Living **v4** is the minimal next compatible schema: v1 mining and v2 selector state, plus the connected v3 pair/four invitation responses, are preserved. Added fields are sparse `world.citizens` (<=34 compact occurrence/cooldown rows), `encounters` (<=4 supported players ×34 compact private response stamps), and bounded matching orphan buckets. No per-citizen heavy history ring is added. Original mining 16-detail ring/28-day TTL/watermarks, day range 2147483647, optional activity horizon 1000000, total 262144-byte cap and orphan 65536-byte cap are unchanged.

The new compact occurrence/response stamps are dedup authority independent of detail TTL. Active/orphan reappearance merges by day/terminal/response phase; pure getters and decode never settle or award. Closed types, enum/ID vocabularies, widths/work/depth and bytes are checked before copying or stringify. Invalid current state retains the existing explicit gather-refusal contract, never successful omission.

The general observer validates a whole proposed codec projection, then installs only its owned citizen field, preserving the root identity retained by the existing connected pilot. Successful load/reset replaces authority; genuine complete failed rollback can preserve an already-earned response prefix through the inherited authenticated accounting contract. Transient physical moments are never restored by rollback.

## Copy and acceptance qualifications

The CSV has 539 bilingual rows; all are draft, with no human/voice signoff. Existing `LC_` ownership already covers the new keys. The Lua binding has a canonical keep-import sidecar and is validated by actual LuaRuntime plus `LivingData.validate_actions`.

Evidence, exact commands, RED/GREEN, per-citizen dispositions and remaining gates live in the frozen fullcast handoff, not in this design file. Headless canonical-actor/UI fixtures and real loaded-map autonomous controls are distinct. Parsed-controller/native/hardware, export, full hero/shard/performance matrix and fresh independent cumulative review are separate pending parent gates. No staging, commit, push, release or cleanup is authorized by this contract.
