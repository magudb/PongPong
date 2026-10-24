# Living Characters — purpose, memory and community

Status: in progress after verified stage-2 merge `eb42f27a`; authoritative roster and integration contracts are being established before the first production slice. No Living Characters gameplay completion is claimed. Samlerbog remains next after this stage.

## Owner decisions

- Tone: cozy motivations, friendships, disagreements and reconciliation.
- Order: finish the current stage-2 progression/quest fixes first, then implement this system, then resume the original stages 3–6.
- Intent: every character has a reason to exist and act, rather than functioning only as a shop, quest dispenser or scheduled background actor.
- Inspiration: enRAGE's persistent living-world idea, not its violence or a copied revenge hierarchy. Build original code/data/art. No runtime LLM or network service is required by this direction.

The original six stages keep their numbers. This is an additional named stage, `living_characters`, between 2 and 3. It overlaps stage 6's social/narrative work: reconcile that work instead of implementing competing social systems twice. The current release and quest fixes must not be replaced or quietly abandoned.

## Existing foundations to reuse

At the inspected main revision c2a1b35c:

- `lua/config/npcs.lua` owns existing identity, art, voice, home and shop facts.
- `lua/social/citizens.lua` adds authored archetypes, birthdays, social tiers and partner eligibility.
- `lua/routines/` already authors work/rest/activity schedules.
- `scripts/towns/routines.gd` resolves presence from calendar/weather/context; parked areas do not simulate live actors.
- `scripts/towns/town_director.gd` drives navigation and a bounded loaded-area population.
- `scripts/social/social_manager.gd` owns per-player friendship, gifts, event history and social serialization. Existing hearts never decrease.
- SaveManager, EventBus, the dialogue layer and authored quests already exist. Stage 2 is repairing real-meeting versus synthetic-offer semantics: use its final verified contract rather than a second, unchecked interpretation of dialogue events.

The missing layer is persistent motivation, meaningful memory and NPC-to-NPC causal relationships. Do not rebuild existing navigation, identity, romance, save transactions or routine evaluation.

## Product contract

For every authored interactable citizen, including non-romance and minor citizens, explicitly answer:

1. What does this person contribute to the community?
2. What do they want for themselves?
3. What matters to them, and what concerns them?
4. Who matters to them, and why?
5. What are they trying to do today?
6. What might change their mind or their next action?

A generic fallback can keep an old save loading, but it does not satisfy final authored-character coverage. Preserve established names, roles, backstories and relationships; do not randomly overwrite named characters with generated families or personalities. Generated background people, if introduced later, are separate scope.

## State and ownership

### Authored profile

Each citizen has a community purpose, personal aspiration, a small set of values/temperament traits, existing occupations/commitments, explicit social ties, and a bounded set of eligible goals. Reuse existing registry IDs and localization conventions. Traits must influence a choice or response; unused biography fields do not establish a working feature.

### Shared world state

Persist NPC-to-NPC relationships, community projects and selected goal/outcome state once per world. The future multiplayer host is the sole simulation writer. A guest cannot advance another player's promises or mutate world state by sending arbitrary NPC identifiers.

### Player-scoped memory

Remember consequential interactions separately for each player: fulfilled promises, help, shared celebrations, disagreements and reconciliation. Keep event identity and actual actor attribution, plus bounded retention/deduplication. Witnessed facts and explicitly communicated information can travel through social connections; characters do not acquire omniscient knowledge of remote private events.

New trust/mood/conflict state must not silently subtract legacy friendship hearts. Migration is additive, preserves old saves, and tolerates missing/retired content through explicit defaults/orphans.

## Decision and consequence loop

Committed gameplay event -> validated, attributed memory -> eligible goal evaluation -> selected action/request -> actual world or player-facing outcome -> recorded resolution -> changed future choice.

A displayed line, stored goal string or passing selector test is not a complete loop. At least one later visible activity, request, dialogue branch or reciprocal action must change because the earlier event actually happened.

Use deterministic, explainable utility selection over a small authored goal set. Inputs can include role obligations, calendar/weather, goal urgency, resources, personal values, relationships and relevant memories. Stable tie-breaking and cooldowns keep behavior reproducible. Do not fabricate a black-box personality simulation or require online generated dialogue.

Goals can fail, be deferred, be resolved by an alternative, or be reconciled. NPCs continue living without the player; the whole community must not freeze while waiting for unaccepted requests. Missing several game days must not punish ordinary casual play.

## Cozy safeguards

- No permanent citizen death, revenge promotion ladder, hostile ambush system or inherited violence from the reference mod.
- Disagreements are recoverable; reconciliation is a real available path.
- Protect shop hours, essential services, fixed quest NPC availability, story scenes, festivals and authored relationship commitments. Goal overrides cannot strand progression.
- Do not manufacture free items or uncapped currency. Resource requests/rewards use existing validated transactions and bounded goal budgets.
- Do not treat opening a notice board, reading mail or dismissing an offer as fulfilling a physical task or promise.
- Authored stories have explicit priority over optional emergent incidents. Missing an optional incident cannot corrupt main quests or rewards.
- Keep optional requests limited and understandable, rather than filling the journal with repeated errands.

## First playable slice

Proposed connected pilot: Maja, Birk and Thorin, using their existing identities and resources. Their individual purposes and exact written content must be authored from current character material before implementation; these examples are not claims about existing gameplay.

Prove one complete chain: a citizen pursues a contextual goal; the player may help, defer or decline; an actual committed action changes remembered state; a subsequent conversation/activity/request or reciprocal action changes; a disagreement can be reconciled. Include an independent NPC-to-NPC consequence and an autonomous fallback when the player does nothing.

Once this works, extend explicit purpose/goal/tie coverage to every authored interactable citizen. The pilot is an implementation milestone, not permission to declare all characters finished.

## Work packages and gates

LC1 — Profiles and contracts
- Enumerate the authoritative citizen roster; reconcile existing authored facts and social scope.
- Define validated profiles, goal/action/outcome vocabulary and ownership contracts.
- Coverage validator rejects missing purposes, unknown ties, dangling resource/localization references and goals without reachable resolutions.

LC2 — Persistent memory and relationships
- Add bounded, actor-scoped memories and shared NPC relationships with additive save/load support.
- Regress duplicate events, cancellations, new-game reset, old saves, retired content and cross-player isolation.

LC3 — Decisions and real activities
- Connect deterministic goal selection to existing routine/director behavior through explicit priority rules.
- Preserve shop/story/festival commitments and safe off-screen catch-up. No per-frame whole-world population simulation.

LC4 — Player-visible encounters
- Wire actual committed actions, requests, authored dialogue reactions and reconciliation.
- Prove the pilot's entire causal chain through real NPC/UI paths, not synthetic callback strings alone.
- Cover keyboard/controller cancellation and distinguish real meetings from board/mail offers.

LC5 — Full cast and acceptance
- Author and validate every citizen's purpose, goal variety and meaningful connections.
- Test persistence, sleep/time jumps, travel, unaccepted/failed goals, restoration after reconciliation, and single-player parity.
- Measure simulation/save cost against existing budgets; include bounded state growth and long-session coverage.
- Integrate through reviewed PRs and the full strict hero/windowed/build matrix. Keep human copy/listening/device acceptance distinct.

Use vertical RED/GREEN development for production behavior and independent pre-commit review. Package names here are proposed work units, not existing implementation or completed acceptance.

## Definition of done

Every scoped citizen has an explicitly authored purpose and usable motivations/connections. Meaningful interactions persist and affect future observable behavior. NPCs can pursue alternatives without player intervention, and conflicts have reachable reconciliation. Old saves and core progression remain safe, behavior is bounded/deterministic, and real-input plus integration tests support the claims. Human editorial/art/licensing approval is not inferred from those tests.

## Reference

Inspected enRAGE description: https://www.nexusmods.com/reddeadredemption2/mods/10967
The reference describes identities, temperament, remembered interactions and recurring relationships/conflicts. Its source/assets are not part of this design or implementation.
