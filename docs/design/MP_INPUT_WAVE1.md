# MP1 / MP2 input prerequisite implementation

This is offline wave-1 identity/input work, **not a finished LAN mode**. No peer transport, host/join, replication, host intent validation, guest write gate, connected-session save, sleep vote or rejoin is provided by this slice. Existing payload-v3 `players.rows`, roster staging, signal signatures and legacy host projections are retained.

## Sources and authority

Each `PlayerBody2D` owns `PlayerInput` as `controls`. The default local source owns keyboard/mouse plus **pad device 0**, preserving the historical one-machine single-player controls. `bind_pad(id)` accepts exactly that nonnegative device and refuses keyboard/mouse and synthetic `InputEventAction`, even if an Action claims that device number. Bind a nonzero SDL device explicitly; do not infer player identity from group order, `InputEventAction.device`, `GameData.eco()` or an ambient acting-player scope. This routing is not couch/split-screen support.

Overlapping bindings fail closed to the **lowest live registered slot**. Default/default, default/pad-0 and equal explicit devices overlap; a losing source accepts no physical events or continuous input. Default/pad-2 remain disjoint. Binding, locality and attachment changes synchronously revoke losing samples, with a bounded four-slot authority check at reads. A successor requires a fresh sample; old source instances, departed/queued bodies and same-id replacements cannot transfer holds. Arbitration does not activate another camera or add couch support.

`move_vector`, `action_strength`, `is_action_pressed`, `is_action_released`, `aim_position`, `handle_event` and `consume_if_handled` are the input boundary. Bound-device continuous state comes from that source's raw event samples, not the globally aggregated pad actions. A small `PROCESS_MODE_ALWAYS` child captures samples/releases while a modal pauses the body; it never dispatches gameplay or consumes viewport input. Body gameplay, visuals and simulation remain pausable.

`action_strength` preserves the InputMap deadzone-adjusted analog response (including partial stick zoom); `action_raw_strength` supplies movement's radial deadzone reconstruction and pressed thresholds. The capture child's lifetime-owned `joy_connection_changed(device, connected)` listener removes revoked pad axis/button samples and clears body tool/combat/climb buffers, without revoking another device or retained keyboard samples. Reconnect does not restore old holds. Signal-contract tests replay the installed engine's notification; they are **not physical-unplug acceptance**. Godot 4.7.2 clears device state at disconnect and schedules the notification without dispatching matching neutral raw events.

The default source also retains the existing programmatic `Input.action_press/release` single-player automation contract. The first observed foreign pad permanently disables that source's aggregate fallback; its own physical events still work. Binding, detachment and locality changes clear body latches and require release of previously aggregated holds. No global input is polled for a remote body. Remote gameplay ticking and direct input-triggered tool/combat actions are intentionally blocked until host validation/replication exists.

The HUD's consumed mouse slot click uses trusted owner-resolved dispatch, not a forged global Action. Deferred dispatch retains the physical body, source revision, hotbar, area, profile row and HUD load/reset epoch; both origin and delivery must pass normal world/modal/travel restrictions. A foreign pad does not break that GUI path or reopen Action impersonation for pad/remote sources. The passive-frame simulation guard covers `PlayerBody2D` / `PlayerStub2D` as well as the ordinary `Player2D` override; standalone local area fixtures remain supported.

`submit_remote_frame` is a passive, offline, latest-only sample contract: exactly four String keys (`sequence`, `move`, `aim`, `actions`), increasing integer sequence 0..2147483647, two finite numeric move components in [-1,1], two finite aim components within +/-10000000, and at most the twelve explicitly allowed boolean actions. It copies bounded scalars, clamps diagonal movement to unit length and expires after 250 wall-clock milliseconds. Invalid frames do not replace the accepted sample. No RPC is exposed; accepting a sample grants **no world-write authority**.

World registration wins over group order. A live, nonqueued registered local body is required when a world exists. Only without a world can the historical plain-Node `player` group fixture satisfy idle/local lookup; it is never physical-body action authority. Null-event lookup retains that idle contract. Unknown/foreign physical devices return null. Detached, queued and unregistered lookalikes cannot borrow a profile.

Body input actions bind synchronous work to `registered_id(body)`, restore nested caller scopes and never retain a scope across an await. Tools, farm repeats, combat, hotbar counts and equipment reads use the actual body owner. Consumables deliver to the registered body corresponding to the inventory row, not to the HUD hero. Body-local outfit/character and hotbar-assignment consumers filter their owner. Farm/forest HUDs and current-item badges do not rebind to remote spawns or accept another owner's hotbar/vitals. Forest inventory labels resolve the live registered local body and scope their reads to that owner even when genuine batched notifications flush under another acting player; initial/translation refreshes use the same reader, with explicit shared-p0 fallback only without a world. These are narrow input-path corrections, not completion of the remaining actor-aware manager/UI migration.

## Pad bindings and conflict policy

Keyboard/mouse bindings are unchanged. Existing pad aliases are retained:

| Action | Primary | Historical alias |
|---|---|---|
| Run | L3 | LT |
| Flight toggle | R3 | Y on non-action areas |
| Descend in flight | D-pad down | LT |
| Hotbar cycle | Bare D-pad left/right | unchanged |
| Drink | RB alone in action areas | unchanged |

Direct hotbar selection is a **modifier-first** chord: hold **LB first**, then press D-pad up/right/down/left for slots 1/2/3/4. While LB remains held, add RB and use those directions for slots 5/6/7/8. LB+RB never drinks; chorded down does not descend, and chorded left/right does not also cycle. RB pressed alone before LB retains its ordinary drink action; that order is not the modifier chord. In a modal, the same shoulders remain normal page navigation and the D-pad remains focus navigation. Controls-page labels follow pad family and show the chord.

X/E/pad target the facing cell; an actual mouse click targets its clicked cell. Cursor buffering, held farm repeat, sword buffer, dodge ground heading, trackpad/stick zoom, flight/climb, HUD marker suppression and ortho/iso projection retain the existing production paths. The two existing binding-display assertions keep their identities but now expect the additive L3/R3/down labels; the prior LT/Y actions remain positive controls.

## Verification boundary

Production-path regressions live in `tests/sections/multiplayer_input.gd`; compatibility sections include `core`, `multiplayer_registry`, `multiplayer_state`, `player`, `player_input`, `mouse_targeting` and `farm_controls`. The delegated evidence bundle retains the original 230-check baseline, vertical behavioral RED/GREEN reports, source pins, exact commands/statuses, later affected-family and four-hero runs, static checks and native-window captures. Injected events and inspected captures are not physical-controller, multi-machine, exported-build, aesthetic or editorial approval. A fresh independent review and parent verification remain required before integration.

MP3 has already-merged state/save/signal work, but its broader actor-consumer migration is not certified here. MP4-9 networking, synchronization, host validation, LAN UI, sleep/disconnect/rejoin and connected acceptance remain future work; RM1's obsolete array sketch does not replace the implemented `players.rows` codec.

Review correction cycle **1/2** adds clean runtime RED→GREEN for five input findings, otherwise-eligible remote-tool/chord controls, distinct worn outfits/materials under conflicting scopes, replay/unknown-action samples, modal capture, source and roster lifetime tracers. Final cycle **2/2** narrowly corrects the inherited ForestHUD ambient inventory reader exposed by the body-action scope: an actual eligible p0 tonic action inside batched notifications under p1 has observed clean RED→GREEN, with ordinary local, nested genuine notification, backpack-threshold, initial/translation and no-world controls. No further automatic correction cycle remains; parent execution and fresh independent review are still required. Prior evidence is retained separately. Native menu-golden RED remains excluded from repair. The earlier native held-mouse repeat failure remains a repeatability blocker unless its original cause is established; a later passing selection is not closure or whole-branch acceptance.
