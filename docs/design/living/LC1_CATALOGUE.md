# LC1 catalogue — original proposals, not a playable engine

All `living_citizens` motivations, weighted values, goals and proposed ties are new original authoring for review. Source pointers document identity/availability and established tie evidence; they do not promote the new prose into pre-existing biography. No human editorial signoff has occurred.

## Ownership and schema

`lua/config/npcs.lua`, `lua/social/citizens.lua` and the routine registry retain identity, occupation, age, family, twins, unlocks, partner eligibility, services and availability. This catalogue intentionally does not duplicate or override those fields. It adds no hearts, quests, rewards, inventory, optional errands, schedules or player state. Children, animals, elders and minor citizens belong without a productivity requirement.

`LivingData.profiles()` and `profile(id)` expose shared read-only runtime tables through `Svc.lua_config("living_citizens")`; missing runtime/config and unknown IDs return empty dictionaries. `validate()`/`validate(null)` inspect runtime; `validate({})` reports all missing citizens. Validation has an explicit 34-ID boundary independent of generic SocialData fallbacks. Filesystem and runtime item inspection are read-only.

Each explicit row has matching `id`, `authorship=original_proposal`, identity/availability resource pointers, bilingual purpose/aspiration keys, 2–4 small integer value weights (1–5), 1–8 meaningful ties and 1–4 eligible goals. A tie has `target`, `provenance=established|proposed`, a real source path and localized reason. Established family ties only assert the documented relation; a shared family ID alone does not establish a parent label. Proposed ties point to their owning shipped Lua catalogue as original-authoring provenance (not to this development document, which exports exclude) and are not proof the two citizens already knew each other.

Goals have globally unique `lc_<npc>_<suffix>` IDs, `kind=role|personal|connect|reconcile`, a referenced weighted value, an additional integer utility weight (1–5), cooldown 1–14 days and expiry 1–7 days. These are future selection inputs, not unused personality claims. A future selector can combine the goal weight with the selected value weight; no selector ships in LC1. All goals require free time and existing availability. Story, service, festival, twin absence, unlock and family commitments retain priority. Expiry means defer/choose the autonomous alternative, not punish the player. No accepted player promise is created here.

Each goal names 2–3 local resolution IDs with the closed kinds `autonomous`, `attendance`, `clarification`; `fallback` must reference an autonomous resolution and `reconciliation` a clarification resolution. Localized resolution text declares a feasible outcome or alternative and a way to repair misunderstanding. Attendance requires a future actual co-presence/consent adapter; displaying text is not attendance. Clarification requires a future communicated correction, never deletion of hearts. Resource references must resolve to real item definitions and bounded quantities. All authored rows currently request **zero items and zero currency**; no transactions occur.

## Pilot adapter boundary

Rosmarin (`baker_maja`, not a renamed resident), Birk and Thorin propose a quiet after-work pause. Their links are explicitly new, not established supply contracts, romance or omniscient sharing. Each can pause independently, postpone without debt and clarify a missed time. No routine is overridden and no gift-picker hook is added.

Only Thorin's personal goal declares `trigger=future_committed_mining_help`. This is a declaration reserved for a future commit adapter using Thorin's verified physical mining hand-in. It is not wired here and must not be fired by synthetic quest offers, mail, a board, dialogue dismissal, gift selection, or Rosmarin's cookie delivery (which lacks the required physical-provenance flag). No item/currency grant or consumption is attached to this trigger.

## Separate story continuity ledger (not resident profiles)

- `story:iva`: Iva is the boat-builder named through the traveller account/evidence restoration. No registered citizen/home/routine exists. Preserve her own name and existing restoration, not an invented new shop. Evidence: `localization/forest_mother.csv`, `scripts/world2d/story/mother_memory_work.gd`.
- `story:root_scribe_echo`: bodiless story echo/fixed-role bargain, not a friendly resident. Preserve its authored narrative function without inventing daily social goals. Evidence: `scripts/world2d/story/mother_evidence_marker.gd`, `localization/forest_mother.csv`.
- `story:mother`: historical missing mother whose final account confirms death; not a living citizen or a new death mechanic. For ghost heroes only, she is Dyne's youngest child and Silke's sibling. Other heroes do not gain Natlys biological relatives. Preserve recorded intentions and garden legacy. Evidence: `docs/design/DARK_FOREST_STORY_ADDENDUM.md`, `scripts/world2d/story/mother_story.gd`.

## Review and limitations

34 authored profiles are not 34 completed playable characters. LC1 validates catalogue structure, actual Godot Lua-subset loading, bilingual keys and declarative resolution links. It does not prove navigation, animation, event causality, utility selection, NPC-to-NPC propagation, persistence, real-input UI, multiplayer ownership, human copy approval or LC3–LC5 acceptance. Parent review/integration and later adapter/engine work remain mandatory.
