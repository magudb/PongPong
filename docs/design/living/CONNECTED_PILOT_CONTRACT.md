# Connected Living pilot: loaded fountain exchange

Status: P1/P2 implementation handoff, **not LC5/full-cast completion**. No commits,
publication, renderer changes, new assets, map posts, goods or economic rewards.
The original Thorin mining/bench tracer remains separate and unchanged.

## Playable causal loop

On a dry ordinary day, Rosmarin (`baker_maja`), Birk and Thorin can communicate
at their existing adjacent fountain seats. The loaded director's minute observer
checks actual live actors at their assigned seats, free of unrelated holds,
inside the common compiled ordinary `sit` stay. An active-ticket-only physics
guard checks these three retained actors and at most four retained participant
bodies, so a brief between-minute departure also breaks continuous attendance.
It does not move or spawn anyone.
An initial physical sample retains exact weak actors/area/director and model
identity. One consecutive minute delivers Rosmarin's invitation; another records
Birk and Thorin's agreement (or their communicated timing mismatch). Five further
consecutive eligible minutes complete their quiet pause. Their remembered pair
state then changes both citizens' ordinary conversation. No player interaction
is necessary. Face direction uses existing actor art; this is not a new voiced
NPC-to-NPC cinematic or speech renderer.

The measured Tuesday common stay starts at **18.682995951417** (Thorin's actual
compiled arrival, approximately 18:41) and ends at **19.0** (Birk's departure).
Rosmarin arrives at 18.1457489878543; Birk at 17.8456590193432. Their later 19:15
personal bench activity is deliberately NOT used as joint attendance. The live
observer computes the intersection rather than prescribing 18:45. All movement,
return legs, work and services remain authored routines. The communication radius
is 360 ground pixels across the existing adjacent fountain posts; each actor must
be within 24 ground pixels of its director-assigned seat.

If the communicated proposal cannot fit before departure, the pair remembers
`needs_clarification`. At the next genuinely loaded co-presence they autonomously
acknowledge shorter timing. That produces a separate `clarification` terminal and
sets the next pause to **two** minutes. A player can also choose the clarification
entry while both recipients are physically available; this records only
`clarification_pending`. A subsequent actual bilateral minute, not the button,
resolves it. If neither path can happen today, ordinary solo leisure continues;
there is no remotely manufactured substitute accomplishment or player penalty.

## Player conversation

All three actors expose “Your pause today?” after existing service/story choices,
using the existing More pagination. Help records optional intent, not attendance.
The real registered body must remain near **all three actors** throughout the
joint pause. Only then is acknowledgement offered; reading/selecting it creates
the private terminal acknowledgement and changes that player's later reply.
Defer sets a next-day boundary. Decline closes only today's private invitation.
Cancel/unread pages do nothing. NPCs continue without the player. No Living
branch changes hearts, items, currency or quest rewards.

The actor retains its actual immutable completing receipt before its authored
completion callbacks. `SocialManager.living_settle_encounter(actor, ticket)` reads
that exact owned actor record; it accepts no result dictionary from the public
choice bus. It validates the captured world/model/day/profile, weak originating
area/director, exact actor generation, live physical body and current UI ticket.
It validates a detached candidate and commits without callbacks before the
legacy completion/public choice suffix. Earned intent therefore survives a
subsequent genuine complete failed-apply rollback/body departure; successful
replacement revokes the old suffix. Departure does not grant attendance.
No player scope crosses an await. SaveManager and DialogueUI are unchanged.

## Persistence and bounds

Living codec v3 is additive. V1/v2 private mining receipts, durable producer
watermarks (including their wider day range), existing Thorin selection and
cooldowns are preserved without scanning private history for NPC knowledge.
`world.pairs` has one closed pilot key `beekeeper_birk:smith_thorin`, containing
`day`, `status`, `phase`, `outcome_day`, `pause_minutes`. Separate `responses`
contains at most four explicit player rows, each with `day`, `choice`,
`not_before_day`, `attended_day`, `ack_day`. There is only one current pilot
invitation per player. These compact durable rows do not depend on a detail TTL
or ring. Unknown/removed pilot members cannot execute; retained terminal facts
prevent same-day replay on reappearance. No getter settles or awards anything.
No transient actor reference/dwell is saved or restored by equal-valued loads.
Authenticated complete Social rollback retains its original Living model but
**never** restores physical dwell tickets. Successful loads clear them.
The existing 262144-byte total and 65536-byte orphan bounds remain unchanged;
empty legacy serialization remains sparse. Invalid current Living state still
refuses the real save gather rather than omitting the section.

## API/caller inventory

- `living_pair.gd`: closed codec, response codec, compiled-window predicate,
  actor/source authentication, physical observer and contextual reply.
- `SocialManager.living_observe_pairs(source)`: existing TownDirector `_clock`
  only; no EventBus payload reducer or per-frame world search.
- `living_encounter_origin(pid)`: captured by Npc2D before builders/callbacks.
- `living_settle_encounter(actor, ticket)`: Npc2D `_settle_talk` only.
- `living_pair_reply(npc)`: pure DialogueBridge decoration.
- `LivingDialogue.pause_choice/pause_page`: existing NPC followup route and More.

## Verification boundaries

New runtime sections: `living_pairs`, `living_encounters`,
`living_encounter_lifecycle`. Raw RED/GREEN, exact commands, source/preimage
manifests and report reconciliation live in the scratch `living-completion1/pilot`
handoff. The negative corrupt-current-state save intentionally expects exactly
one existing gather-refusal error; no blanket allowance was added.

The old `living_memory` fixture hardcodes v3 as a future version. Its three
assertions must migrate their **input version to v4** now that v3 is real; they
are preserved as failing, not waived. This frozen worker did not change that
inherited fixture. The new section independently checks v4 refusal.

Remaining: full 34-citizen executable motivations, general bindings beyond this
closed trio, exhaustive lifecycle/retirement/max-populated/performance matrix,
new-pilot parsed-controller/native-windowed input, export/build smoke and fresh
independent cumulative review. The existing headless mining/bench journey is not
native or controller acceptance for these new branches. Draft Danish/English
copy has no human/editorial/voice signoff.
