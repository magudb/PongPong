# LC3 pure goal-selector contract (new component, not integration)

`LivingGoals.select(npc: String, profile: Dictionary, inputs: Dictionary, previous: Dictionary = {}) -> Dictionary`

This is a deterministic **decision tracer only**. It does not implement observable NPC activity, schedules, an NPC-to-NPC relationship engine, a receipt authority, persistence, a world reducer, dialogue, actors, UI, quests or economic transfers. No SocialManager/QuestManager/Routines/director/codec integration is included. A selected `role` goal is still optional; it is not permission to replace essential work.

## Profile

Supply the actual LC1 row from `living_citizens`, not canonical `npcs` or a synthetic fallback. Identity must match one of `LivingData.AUDITED_IDS`; missing, unknown or malformed profiles return `{}`. Optional caller tombstone `retired` must be absent or boolean false; true/unknown fails closed. All LC1 values, ties, goals, local resolutions and numeric bounds are checked structurally before any selection, including ineligible goals. Goal IDs must be unique within the row. The special trigger is accepted only on Smith Thorin's personal goal. Targets are allowed only for connect/reconcile goals and must reference an authored tie to another audited resident.

The selector reads only supplied dictionaries and existing LC1 **constants**. It never calls the LC1 runtime readers/validator, resolves files, checks translations/items in services, or consults private player rows. `LivingData.validate` remains the separate catalogue-authoring gate for actual source-file, bilingual-key and item-definition existence. Selector validation is not a replacement for that gate. Unconsumed extension fields are ignored and never traversed or returned. Consumed string scalars must be actual `TYPE_STRING`, as supplied by Lua, including enum values and local resolution references; matching `StringName` values are rejected before membership/lookup, not partially normalized. Consumed strings are bounded (identifiers 1–128 characters, `res://` source strings at most 256); arrays/maps retain LC1 bounds (2–4 values, 1–8 ties, 1–4 goals, 2–3 resolutions, at most four resources). Currency must be zero; pilot resources must be empty. Resource metadata is never returned, consumed or granted.

## Inputs (new interface, not an existing adapter API)

```gdscript
{
    "day": 10,
    "available": true,
    "free_time": true,
    "protected": {
        "essential_work": false,
        "story": false,
        "festival": false,
        "home": false,
    },
    # Optional, default {}:
    "triggers": {"future_committed_mining_help": true},
    "cooldowns": {"lc_smith_thorin_role": 12},
}
```

- `day` is an explicitly validated **total game-day index**, 1–1,000,000 inclusive, never wall time, weekday or inferred calendar. Finite integral JSON floats are accepted alongside integers. Booleans, strings, fractions, NaN and infinity are not numbers here. Arithmetic happens only after validation.
- `available` means the caller has positively confirmed LC1 `existing_availability`, including citizen gates/absence. `free_time` means the caller has positively confirmed optional space. Both must be actual boolean true. All four named `protected` flags must be explicitly boolean false. Missing/unknown/false availability or missing/unknown/true protection means **no optional goal**, even for a latched selection. These flags do not discover or prove a travel/dwell/return envelope. A later schedule adapter must independently protect routes, service coverage and existing story/festival/home obligations; this component invents no slack.
- `triggers` is a per-NPC **trusted caller projection** of confirmed source facts. It is not a receipt/event parser or an authentication scheme. The only accepted key is `future_committed_mining_help`, with an actual boolean value; only true enables a fresh triggered candidate. Missing/false does not. Unknown keys/types fail closed. At most one entry. A future SocialManager adapter must derive the flag from committed, validated owner state and intentionally supply it for this NPC. Public event claims, hearts, arbitrary flags, or scanning every player's private memory are not authority. This selector does none of those things.
- `cooldowns` maps at most four **known goal IDs of this profile** to their exclusive-until total day, 1–1,000,014. Missing entries mean no historical cooldown. A candidate is eligible when `day >= until`. The previous record's own cooldown is also honored, taking the later boundary. The future owner must retain historical cooldowns for *all* prior selections; a single previous record cannot represent that history. Malformed known maps fail closed, not silently clamped/coerced.
- Unknown input fields are inert. Supplying `private_player_rows`, a top-level help flag or an event payload cannot enable the trigger. A literal true supplied by an untrusted caller is not made authoritative by this API.

## Scoring and tie order

For each eligible goal:

`weighted_value = profile.values[goal.value] * goal.weight`

`utility = weighted_value + trigger_bonus`

`trigger_bonus` is 1 for an explicitly enabled special-trigger candidate, otherwise 0. Utility is an integer in 1–26. Both the character's value weight and authored goal weight can change the winning ID. Protection is an eligibility gate, never a utility competition. Highest utility wins; exact ties choose the lexicographically smallest stable goal ID. No RNG, hash order, clock read, caches or mutable static state. Dictionary insertion order and all permutations of the goal list produce equal results.

In the actual LC1 Thorin row the untriggered baseline is `lc_smith_thorin_connect` (quiet 3 × goal weight 2 = 6; ID tie-break against role). Explicit confirmed help on a fresh safe day enables `lc_smith_thorin_personal` (craft 2 × weight 3 + trigger 1 = 7). This is a goal-record difference, **not a visible activity change**.

## Previous selection, latch and expiry

`previous` is either `{}` or the future owner's trusted, previously selected record (including a validated save roundtrip), **not arbitrary client/event payload**. The selector checks known NPC/goal/kind/target, finite bounded dates, value name and internally consistent bounded reason/utility numbers. Nonempty invalid/retired/unknown/future records return `{}` rather than reroll. Unknown fields, including unknown reason payloads, are discarded; no arbitrary deep duplicate is performed. This validates shape/consistency, not provenance.

A valid same-day known selection is reconstructed and latched unchanged, including its original utility/reasons/dates, despite later input-trigger, value-weight, goal-weight or historical cooldown changes. Removing a current trigger flag does not undo a trusted already-selected same-day snapshot. **Availability/protection and structural validity are still checked first.** If these guards block a call, the result is `{}`; the future owner should retain the day's saved selection and not replace it with an empty return. The selector itself owns no state.

On the next day the selector reevaluates rather than continuing yesterday's selection, even if its expiry has not arrived. Expiry is exclusive (`selected_day + expires_days`); it bounds the record's proposed lifetime for later owners, not a multi-day reservation. Cooldown is exclusive (`selected_day + cooldown_days`), begins at selection, and can outlast expiry. Expired prior records still provide their own cooldown history but are never replayed. Historical durations/reason weights need not equal newly authored weights/durations, preserving a valid day's snapshot across compatible content changes; references must still be known. Removing/changing the selected goal's kind/target/value/trigger invalidates that snapshot.

The selector cannot latch an empty day because `{}` carries no day. If integration needs that policy, its owner must separately record the attempted day. No such owner is added here.

## Output

No selection/invalid/blocked: `{}`. A selected result contains **only**:

```gdscript
{
    "npc": "smith_thorin",
    "goal_id": "lc_smith_thorin_personal",
    "kind": "personal",
    # "target": "baker_maja", # only connect/reconcile
    "selected_day": 11,
    "expiry_day": 14,
    "cooldown_until_day": 13,
    "utility": 7,
    "reasons": {
        "value": "craft",
        "value_weight": 2,
        "goal_weight": 3,
        "weighted_value": 6,
        "trigger_bonus": 1,
    },
}
```

All numeric output is integer. Text output, including optional `target` and `reasons.value`, is `TYPE_STRING`. Output and its new reasons dictionary are read-only; no nested mutable profile/input/previous reference, runtime object, raw payload, source row, authored costs or grants escapes. Profiles/inputs/previous are not modified. The output contains at most nine top-level fields and five scalar reason fields. It can be serialized by a future owner, but this component does not write a save or mutate a game manager.

## Verification scope

`tests/sections/living_goals.gd` uses the **real LuaRuntime LC1 catalogue** and canonical 34-ID roster, not a mocked table/parser. It checks the Thorin counterfactual, weighting/ties, same-day latch, next-day/expiry/cooldown boundaries, malformed/retired/absent cases, typed negative inputs, JSON numeric roundtrips, purity, every authored goal alone and every permutation of each roster goal list with recursively reordered dictionaries. Focused command:

```sh
tests/run_playtest.sh --strict --no-boot --only=living_goals,living_profiles,contracts,social_data
```

The scratch delivery report records actual RED/GREEN, native and separately labeled documented CI `TT_PERF_SCALE=4` results. No windowed or complete-engine acceptance is claimed; no test/budget/registry/skip policy is relaxed.
