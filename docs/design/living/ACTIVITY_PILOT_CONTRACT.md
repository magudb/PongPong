# Thorin activity tracer (initial implementation; review pending)

This adapter adds one observable slice to the pure selector described in
`GOAL_SELECTOR_CONTRACT.md`; it does not change that component's pure API.
It is not full LC3/LC4 acceptance, a whole-cast engine, NPC-to-NPC autonomy,
reconciliation, new requests, or a new reward system.

## Authority and persistence

Only the existing physically attributed committed
`dark_forest_mining/return_to_smith` source reducer creates Thorin's shared
pending-help day. No event claim, choice payload, legacy hearts, board/mail
presentation, or scan of private player rows creates that fact. Private receipts
retain their original day range 1–2147483647. The optional activity horizon is
1–1000000; receipts beyond it remain valid private memories without creating
an out-of-range shared trigger. Unsupported real multiplayer peers fail closed.

Living-state v2 adds a bounded `world.pilot` row: pending/consumed day, attempted
day, selected immutable goal record and at most four historical cooldowns.
V1 loads preserve private receipts without inventing shared knowledge. Retired
content uses the bounded orphan bucket. Save validation/decoding, public reads,
`to_dict` and `from_dict` are pure with respect to settlement. Reset/load/rollback
invalidate deferred generations; only committed lifecycle settlement writes a
new day's attempt. The attempted day includes empty/blocked days, so weather or
content reappearance cannot reroll today's choice. Offscreen skipped days do
not generate historical incidents or rewards.

## Schedule and encounter

Only Thorin's selected personal goal on the matching attempted day can replace
his authored ordinary fountain leisure stay with travel to the existing
`hyggebyen.torv_bench2` sit post and return to the fountain. The entire outbound,
dwell and return must fit inside authored leisure, including keeper-hours
protection across both legs. Existing work, service, home, sleep, festival,
absence/gate and hero-twin constraints remain authoritative. The loaded
TownDirector uses its existing soft resync; held/talking actors are not teleported
or despawned. No new animation, map anchor or renderer behavior is introduced.

The small cached public snapshot exposes no private receipt/player payload and
is recursively read-only. An informational localized choice uses the existing
More pagination without dropping service choices. Its action validates the
actual live Npc2D/session and registered owner before ending that session; a
choice-supplied NPC/goal/player is not authority. Reading/cancelling the followup
writes no living state and pays no reward.

## Verification and limits

Focused sections: `living_activities`, `living_activity_safety`,
`living_activity_journey`, `living_memory`, `living_profiles`, `living_goals`.
The journey's `run_windowed` uses a native window and captures actual PNGs;
headless results alone are not window evidence. Inventory/exploration prerequisites
are fixture grants, but delivery, sleep, director travel/activity and contextual
NPC UI use real entrypoints and keyboard/controller input. This does not prove
manual mining collection, a physical controller device, human copy/listening
approval, all heroes, exports or hosted CI.

The living CSV retains all 245 previous rows unchanged plus two new bilingual
rows, 247 total, all honestly `draft`, without reviewer/date/voice freeze.
Scratch handoff reports retain original REDs, script errors, native timing misses
and separately labeled documented CI-scale measurements. No budget, skip,
rendering or physics changes belong to this implementation.
