# Opt-in scoped input evidence (test infrastructure only)

`scoped_input_observer.gd` is a read-only observer, **not input isolation**. It neither consumes events nor changes a gameplay input source. Internal metadata is trusted harness provenance, not an anti-forgery boundary. An unowned mouse/key/pad/gesture packet still reaches normal singleton, Window, Capture, body, GUI and unhandled consumers; its interval is rejected rather than made green by filtering.

## Use a bounded interval

After real world/body setup and an authentic `t.begin_section` performed by the harness:

```gdscript
var observer = load("res://tests/lib/scoped_input_observer.gd").new()
t.root.add_child(observer)
if not observer.begin(t, body, absolute_scratch_jsonl_path):
    # The supervisor must reject; do not run this as accepted evidence.
    return
# Existing selected mouse/drive/MP/player-input injection helpers tag only while active.
# For another owned physical packet:
observer.tag(event, "parse")
Input.parse_input_event(event)
Input.flush_buffered_events()
var result: Dictionary = observer.close()
observer.queue_free()
```

For existing GUI `Viewport.push_input`, use `tag(event, "push")`; do not replace that route with `Input.parse_input_event`. Synthetic `InputEventAction` and `Input.action_press/release` retain their separate legacy contract and are not physical-packet evidence. Missing/wrong/lost/replayed tags are unowned, regardless of device number or whether arrival happened during a flush.

The lifetime is the weak actual registered local body, world, controls/revision, profile row, exact helper `t` and its **actual stats dictionary incarnation created by begin_section**. It is not only player_id, an invented section setter, or a fabricated phase generation. Close **before an intentional body reparent/area change, source rebind, profile replacement or section transition**, then start a new interval after legitimate setup. No acting-player scope spans an await. Scope loss, incomplete tagged delivery, no owned observations, overlapping leases, failed stream writes, stream closure/overflow and owner/observer exit reject. Cleanup is registered through real `t.on_cleanup`; the observer is ALWAYS-process while the body and its production lifetime Capture retain their original processing modes. Closing an old observer cannot clear a newer attachment.

The 4096-row JSONL stream is flushed per record; pending tags are bounded at128. First failure, totals and replay watermark survive detail-bound exhaustion. A truncated/bounded/failed stream cannot pass the supervisor. Endpoint snapshots and complete actual tool_used records are evidence, not a source of gameplay authority.

Startup uses only the already-existing `PlayerRegistry._states` row. A registered local body can outlive that row after `reset_states()`; `begin` refuses it with `missing_profile` before capturing WeakRefs, checking overlap or opening the stream. Observation never creates a profile. The standalone startup controls retain exact row identities and contents across both `begin` and `close`, including missing-profile, overlap, stream-open, invalid-owner and invalid-start refusals.

## Additive result gate

```sh
python3 tests/tools/scoped_input_supervisor.py \
  --raw-report=/absolute/raw.json --raw-exit=0 \
  --ledger=/absolute/interval1.jsonl --ledger=/absolute/interval2.jsonl \
  --output=/absolute/supervised-result.json
```

Enumerate the complete expected interval list in the acceptance contract **before execution**. Never omit a rejected interval or retry until green. This gate returns nonzero even when all raw gameplay assertions passed. Raw logs/reports remain untouched; original exact assertion/skip/allowed-diagnostic/section/actor/mode/scale/source reconciliation is still mandatory and is not replaced by this tool. Negative standalone controls intentionally contain rejected intervals; their separately frozen control contract must check those refusals, not apply a blanket waiver to an acceptance interval.

Close-record `sequence`, `retired`, `owned`, `unowned`, `tools` and `pending` must be present as exact nonnegative integers before totals/watermarks are compared. Booleans (including `false == 0` / `true == 1`), nulls, strings, floats and containers refuse with `invalid_close_counter:<field>`. Unit controls mutate labelled copies of real engine evidence; optionally set `SCOPED_INPUT_MUTANT_DIR` to a scratch directory to retain those variants.

`tests/tools/scoped_input_control.gd` is deliberately outside automatic section discovery. A scratch section can extend it and call `run(t)` for the standalone controls or `_held(t, false)` for the original three-cell held-path positive. `_held(t, true)` is an explicitly injected historical-field replay (452,1068; relative44,-12; velocity-859.0035,139.8378) at50 physics ticks into the unchanged held fixture. It is diagnostic RED: the normal path can produce an extra20,28 action, the original held check must fail, and the guard must reject. This is not naturally occurring hardware input or proof of every historical failure's origin.

The selected tag propagation covers actual engine injection sites in `drive.gd`, `mouse_targeting.gd`, `multiplayer_input.gd`, and `player_input.gd`. Other sections are **not automatically guarded**; direct private-handler tests are not engine-route transport proof. No whole-suite exclusivity or hundred-helper facade is claimed. Default no-scope calls return their original events unchanged.

## Native status

Installed-engine headless transport and production-route controls are distinct from native acceptance. A user-reserved uninterrupted native session has **not been granted**. Full windowed original mouse/GUI/modal suites, native metadata transport/pixels, real hardware/controller, exported build and LAN acceptance remain **PENDING**, not skipped or passed. Reserve a real input session explicitly before using a native acceptance lane. The global one-window lock alone is not an exclusive-input reservation.
