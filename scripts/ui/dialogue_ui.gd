extends TTScreen
## One UI-owned claim ledger. Broadcast signals are observation, never waiters.
signal session_finished(result: Dictionary)
signal choice_selected(action: String, data: Dictionary)
const Portraits := preload("res://scripts/ui/theme/tt_portraits.gd")
const Lease := preload("res://scripts/ui/dialogue_lease.gd")
var _incarnation := RefCounted.new()
var _revision := 0
var _epoch := 0
var _records: Dictionary = {}
var _active: RefCounted
var _pending: RefCounted
var _barrier := 0
var _draining := false
var _disposing := false
var _suspended := false
var _load_fence: RefCounted
var _load_effects: Dictionary = {}
var _resetting := false
var _permit: RefCounted
var _permit_record: Dictionary = {}
## Accept / interact presses are ignored this long after the choices appear (UX-12): a player tapping E through the lines must SEE the
## choices before a press can answer one, instead of the next tap committing the first choice unseen. Mouse clicks on a choice are aimed
## and are never delayed.
const CHOICE_GRACE_SECONDS := 0.25
var _speaker: Dictionary = {}
var _lines: Array = []
var _choices: Array = []
var _buttons: Array[Button] = []
var _line := -1
var _shown := 0
var _typing := false
var _elapsed := 0.0
var _generation := 0
var _session := false
var _voice_key := ""
var _has_voice := false
var _line_name_key := ""
var _choice_grace := 0.0
var chars_per_second := 40.0

func _init() -> void:
	super._init()
	screen_id = &"dialogue_ui"
	modal_name = &"dialogue"
	pauses_tree = false

func _ready() -> void:
	super._ready()
	add_to_group("dialogue_ui")
	%NextButton.focus_mode = Control.FOCUS_NONE
	%NextButton.set_meta("tt_audit_ignore", "Mouse alternative to interact/ui_accept; dialogue text deliberately has no focus owner (S11)")
	%NextButton.pressed.connect(_advance)
	%TextLabel.focus_mode = Control.FOCUS_NONE
	%TextLabel.selection_enabled = false
	UiNav.watcher().device_changed.connect(func(_device):
		_refresh_hint()
		if _session:
			_refresh_texts())
	chars_per_second = float(LuaRuntime.get_config("ui.dialogue_chars_per_second", 40.0))
	preload("res://scripts/ui/dev/ui_fixtures.gd").register_setup("dialogue", Callable(get_script(), &"fixture_setup"))
	preload("res://scripts/ui/dev/ui_fixtures.gd").register_setup("intro", Callable(get_script(), &"fixture_intro"))
	preload("res://scripts/ui/dev/ui_fixtures.gd").register_setup("dialogue_guide", Callable(get_script(), &"fixture_guide"))

func _wants_focus() -> bool:
	return not _buttons.is_empty() and %ChoicesBox.visible

func _initial_focus() -> Control:
	return _buttons[0] if not _buttons.is_empty() else null

func show_lines(speaker: Dictionary, lines: Array, choices: Array = []) -> Dictionary:
	var ticket := request_page(null, speaker, lines, choices, {"replace": true})
	return await ticket.wait()

## A request is admitted only after validation. One pending slot, never a FIFO.
## Callbacks are synchronous; no acting-player scope or barrier crosses an await.
func request_page(owner: Variant, speaker: Dictionary, lines: Array, choices: Array = [], options: Dictionary = {}) -> RefCounted:
	var ticket := Lease.new()
	var body: Variant = options.get("body")
	var pid := PlayerRegistry.registered_id(body) if _live(body) else &""
	var nested := StringName(options.get("nested_under", &""))
	var replacing := bool(options.get("replace", false))
	if _disposing or _suspended or _resetting or not is_inside_tree() or is_queued_for_deletion() or (owner != null and not _live(owner)) or (body != null and pid == &"") or (GameManager.is_modal_open() and GameManager.top_modal() != modal_name and GameManager.top_modal() != nested) or (_pending != null and not replacing) or (_active != null and _barrier == 0 and not replacing):
		ticket.resolve({"completed": false, "lines_shown": 0, "choice": {}, "refused": true})
		return ticket
	_revision += 1
	_permit = null
	_permit_record = {}
	var record := {"revision": _revision, "epoch": 0, "incarnation": _incarnation,
		"owner": weakref(owner) if owner != null else null, "body": weakref(body) if body != null else null, "pid": pid,
		"speaker": speaker.duplicate(true), "lines": lines.duplicate(true), "choices": choices.duplicate(true),
		"options": options.duplicate(), "state": "pending", "started": false, "optional": true, "effects": true,
		"nested": nested, "id": RefCounted.new()}
	_records[ticket] = record
	_barrier += 1
	if _pending != null:
		var superseded := _pending
		_pending = null
		_refuse(superseded, "replaced")
	_pending = ticket
	_barrier -= 1
	_drain()
	return ticket

static func _live(value: Variant) -> bool:
	return is_instance_valid(value) and value is Node and value.is_inside_tree() and not value.is_queued_for_deletion()

func valid_owner(ticket: RefCounted) -> bool:
	if not _records.has(ticket) or _disposing or _suspended or _resetting: return false
	return _records[ticket].effects and _valid_record(_records[ticket])

## A read page's essential effect can finish after same-run body departure or
## replacement, but not across reset/successful load/UI destruction. Rollback
## restores this exact record's effects; mutable flags/payloads cannot confer it.
func completion_effects_current(ticket: RefCounted) -> bool:
	if not _records.has(ticket) or _disposing or _suspended or _resetting: return false
	var record: Dictionary = _records[ticket]
	return record.state == "completing" and record.incarnation == _incarnation and record.effects

func completion_result(ticket: RefCounted) -> Dictionary:
	if not completion_effects_current(ticket): return {}
	return _records[ticket].get("terminal", {})

func _valid_record(record: Dictionary) -> bool:
	if record.incarnation != _incarnation: return false
	if record.owner != null and not _live(record.owner.get_ref()): return false
	if record.body != null:
		var body: Variant = record.body.get_ref()
		if not _live(body) or PlayerRegistry.registered_id(body) != record.pid or PlayerRegistry.by_id(record.pid) != body: return false
	return true

func _refuse(ticket: RefCounted, reason: String) -> void:
	_records.erase(ticket)
	ticket.resolve({"completed": false, "lines_shown": 0, "choice": {}, "refused": true, "reason": reason})

func _drain() -> void:
	if _barrier > 0 or _draining or _suspended: return
	_draining = true
	# Bound synchronous callback storms as well as retained requests.
	for _i in 2:
		if _pending == null: break
		if _active != null: _finish(false, {}, "replaced")
		if _pending == null: break
		var next := _pending
		_pending = null
		_activate(next)
	_draining = false
	if _pending != null: _drain.call_deferred()

func _activate(ticket: RefCounted) -> void:
	if not valid_owner(ticket):
		_refuse(ticket, "owner")
		return
	var record: Dictionary = _records[ticket]
	_active = ticket
	_epoch += 1
	record.epoch = _epoch
	record.state = "claimed"
	_barrier += 1
	var prepare: Callable = record.options.get("prepare", Callable())
	if prepare.is_valid():
		var content: Dictionary = prepare.call(ticket)
		if not content.is_empty():
			record.lines = LuaData.arr(content.get("lines", []))
			record.choices = LuaData.arr(content.get("choices", []))
	if _active == ticket and valid_owner(ticket):
		_generation += 1
		_speaker = record.speaker
		_lines = record.lines
		_choices = record.choices
		_line = -1
		_line_name_key = ""
		_shown = 0
		_session = true
		%TextLabel.text = ""
		_clear_choices()
		nested_under = record.nested
		super.open()
		if not is_open():
			_finish(false, {}, "refused")
		elif _active == ticket and valid_owner(ticket):
			record.state = "open"
			if bool(record.options.get("events", false)):
				record.started = true
				_scoped(record, func():
					EventBus.dialogue_session_started.emit(_snapshot(record))
					EventBus.dialogue_started.emit(StringName(str(record.speaker.get("id", ""))), StringName(str(record.options.get("module", record.speaker.get("id", ""))))))
			var started: Callable = record.options.get("started", Callable())
			if started.is_valid() and _active == ticket and valid_owner(ticket): started.call(ticket)
			if _active == ticket and valid_owner(ticket):
				mouse_filter = Control.MOUSE_FILTER_IGNORE
				_next_line()
	if _active == ticket and not valid_owner(ticket): _finish(false, {}, "owner")
	_barrier -= 1

## Teardown from an old owner never means close whichever page is current.
func close_owned(ticket: RefCounted, reason := "cancelled") -> void:
	if ticket == null or not _records.has(ticket): return
	var record: Dictionary = _records[ticket]
	record.optional = false
	if _pending == ticket:
		_pending = null
		_refuse(ticket, reason)
	elif _active == ticket:
		_finish(false, {}, reason)

func continuation(ticket: RefCounted, kind: String, payload: Dictionary = {}) -> RefCounted:
	if not _records.has(ticket): return null
	var record: Dictionary = _records[ticket]
	if not record.optional or not record.effects or record.revision != _revision or not _valid_record(record): return null
	_permit = RefCounted.new()
	_permit_record = {"origin": record, "kind": kind, "payload": payload.duplicate(true)}
	return _permit

func dispatch_continuation(permit: RefCounted) -> Dictionary:
	if permit == null or permit != _permit: return {}
	var captured := _permit_record
	_permit = null
	_permit_record = {}
	var record: Dictionary = captured.origin
	if _disposing or _suspended or _active != null or _pending != null or _barrier > 0 or record.revision != _revision or not _valid_record(record) or GameManager.is_modal_open(): return {}
	return captured

func optional_allowed(ticket: RefCounted) -> bool:
	return valid_owner(ticket) and _records[ticket].optional and _records[ticket].effects and _records[ticket].revision == _revision

func _snapshot(record: Dictionary) -> Dictionary:
	return Lease.freeze({"session_id": record.id, "npc": str(record.speaker.get("id", "")), "module": str(record.options.get("module", "")), "effects": record.effects})

func _scoped(record: Dictionary, operation: Callable) -> void:
	if record.body != null and _valid_record(record): PlayerRegistry.for_player(record.pid, operation)
	else: operation.call()

func acquire_hold(ticket: RefCounted, point: Vector2) -> void:
	if not valid_owner(ticket): return
	var record: Dictionary = _records[ticket]
	if record.body == null or bool(record.get("held", false)): return
	record.held = true
	var body: Variant = record.body.get_ref()
	if body.has_method("begin_talk"): body.begin_talk(point)

func release_hold(ticket: RefCounted) -> void:
	if not _records.has(ticket): return
	var record: Dictionary = _records[ticket]
	if not bool(record.get("held", false)): return
	record.held = false
	var body: Variant = record.body.get_ref() if record.body != null else null
	if _live(body) and body.has_method("end_talk"): body.end_talk()

## Narrow new-game fence: revoke before reset mutations, never settle old effects.
func begin_reset() -> void:
	if _load_fence != null:
		_load_fence = null
		_load_effects = {}
		_suspended = false
		_barrier -= 1
	_resetting = true
	_barrier += 1
	_revision += 1
	_permit = null
	_permit_record = {}
	for record in _records.values():
		record.effects = false
		record.optional = false
	if _pending != null:
		var pending := _pending
		_pending = null
		_refuse(pending, "lifecycle")
	_finish(false, {}, "lifecycle")

func end_reset() -> void:
	_resetting = false
	_barrier -= 1
	_drain()

## Snapshot refusal never enters this seam. Suspension is synchronous and keeps
## the exact page/hold intact until apply commits or real rollback completes.
func suspend_load() -> RefCounted:
	if _load_fence != null: return null
	_load_fence = RefCounted.new()
	_suspended = true
	_barrier += 1
	_revision += 1
	_permit = null
	_permit_record = {}
	for ticket in _records:
		_load_effects[ticket] = _records[ticket].effects
		_records[ticket].effects = false
		_records[ticket].optional = false
	return _load_fence

func finish_load(fence: RefCounted, restored: bool) -> void:
	if fence == null or fence != _load_fence: return
	_load_fence = null
	_suspended = false
	if restored:
		for ticket in _load_effects:
			if not _records.has(ticket): continue
			var record: Dictionary = _records[ticket]
			# Complete rollback authenticates the same run. Already-read essential
			# effects outlive a physical owner; optional work still uses valid_owner.
			var earned: bool = record.state == "completing" and record.incarnation == _incarnation
			if earned or _valid_record(record): record.effects = _load_effects[ticket]
	_load_effects = {}
	if not restored or (_active != null and not valid_owner(_active)):
		if _pending != null:
			var pending := _pending
			_pending = null
			_refuse(pending, "lifecycle")
		_finish(false, {}, "lifecycle")
	_barrier -= 1
	_drain()

func start_dialogue(speaker: Dictionary, lines: Array, choices: Array = []) -> Dictionary:
	return await show_lines(speaker, lines, choices)

func _process(delta: float) -> void:
	if _suspended: return
	super._process(delta)
	_choice_grace = maxf(0.0, _choice_grace - delta)
	if _typing:
		_elapsed += delta
		%TextLabel.visible_characters = mini(int(_elapsed * maxf(chars_per_second, 1.0)), %TextLabel.get_total_character_count())
		_typing = %TextLabel.visible_characters < %TextLabel.get_total_character_count()
	%VoiceGroup.visible = _has_voice and AudioManager.is_voice_playing()

func _input(event: InputEvent) -> void:
	if _suspended: return
	if is_open() and is_top() and not _wants_focus() and event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		get_viewport().set_input_as_handled()
		_advance()
		return
	if is_open() and is_top() and event.is_pressed() and not event.is_echo() and (event.is_action_pressed(&"interact") or event.is_action_pressed(&"ui_accept")):
		get_viewport().set_input_as_handled()
		if _wants_focus():
			if _choice_grace > 0.0:
				return
			var focused := get_viewport().gui_get_focus_owner()
			if focused is Button and focused in _buttons:
				_pick(focused.get_meta("choice"))
		else:
			_advance()
		return
	super._input(event)

func _next_line() -> void:
	_clear_choices()
	_line += 1
	if _line >= _lines.size():
		if _choices.is_empty():
			_finish_empty.call_deferred(_generation)
		else:
			_show_choices()
		return
	var row: Dictionary = LuaData.dict(_lines[_line])
	_line_name_key = str(row.get("name_key", row.get("speaker_name_key", "")))
	var text := _line_text(row)
	%TextLabel.text = text
	%TextLabel.visible_characters = 0
	_elapsed = 0
	_typing = not text.is_empty()
	_shown += 1
	_voice_key = str(row.get("voice_key", ""))
	_has_voice = LocalizationManager.is_da() and _voice_key != "" and AudioManager.voice_exists(_voice_key)
	AudioManager.stop_voice()
	if _has_voice:
		AudioManager.play_voice(_voice_key)
	%NextButton.visible = true
	_refresh_texts()
	EventBus.dialogue_line_shown.emit(%SpeakerLabel.text, text, _voice_key)
	var focus := get_viewport().gui_get_focus_owner()
	if focus != null:
		focus.release_focus()

func _finish_empty(generation: int) -> void:
	if _session and generation == _generation:
		_finish(true)

func _advance() -> void:
	if not _session or not is_top():
		return
	if _typing:
		_typing = false
		%TextLabel.visible_characters = -1
	else:
		if _wants_focus():
			var focused := get_viewport().gui_get_focus_owner()
			_pick(focused.get_meta("choice") if focused is Button and focused in _buttons else _choices[0])
		else:
			_next_line()

func _show_choices() -> void:
	_typing = false
	%TextLabel.visible_characters = -1
	# The "continue" button would answer a choice the player did not pick: the choices are the only way on.
	%NextButton.visible = false
	%ChoicesBox.visible = true
	_choice_grace = CHOICE_GRACE_SECONDS
	for choice in _choices:
		var button := Button.new()
		button.name = "Choice" + str(_buttons.size())
		button.theme_type_variation = &"ChoiceRow"
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.text = _choice_text(choice)
		button.icon = preload("res://assets/ui/icons/caret.svg")
		button.set_meta("choice", choice)
		%ChoicesBox.add_child(button)
		button.pressed.connect(_pick_owned.bind(choice, _active, _epoch))
		_buttons.append(button)
	UiNav.wire_ring(_buttons)
	if not _buttons.is_empty():
		_buttons[0].grab_focus()

func _pick(choice: Dictionary) -> void:
	if not _session or not is_top():
		return
	_finish(true, choice)

func _pick_owned(choice: Dictionary, ticket: RefCounted, epoch: int) -> void:
	if ticket == _active and epoch == _epoch: _pick(choice)

func close() -> void:
	_finish(false)

## A dropped stack must still resolve the awaited session, or the NPC that waits on it stays in its talk forever.
func _force_closed() -> void:
	_finish(false)

func _on_cancel() -> void:
	if GameManager.is_modal_open(&"event"):
		EventBus.game_event.emit(&"event_skip_requested",{})
	else:
		close()

func _finish(completed: bool, choice: Dictionary = {}, reason := "") -> void:
	if _active == null or _suspended:
		return
	var ticket := _active
	var record: Dictionary = _records[ticket]
	var result: Dictionary = Lease.freeze({"completed": completed, "lines_shown": _shown if _session else 0, "choice": choice.duplicate(true), "reason": reason})
	record.state = "completing"
	record["terminal"] = result
	_active = null
	_barrier += 1
	_session = false
	_generation += 1
	_typing = false
	_has_voice = false
	# NPC's private validated Living commit is callback-free. It precedes voice,
	# focus/choice and modal teardown; ordinary callbackful settlers stay below.
	var commit: Callable = record.options.get("commit", Callable())
	if commit.is_valid(): _scoped(record, func(): commit.call(ticket, result))
	AudioManager.stop_voice()
	_clear_choices()
	super.close()
	_scoped(record, func():
		var settle: Callable = record.options.get("settle", Callable())
		if settle.is_valid(): settle.call(ticket, result)
		release_hold(ticket)
		if record.started:
			record.started = false
			EventBus.dialogue_session_ended.emit(_snapshot(record), result, reason)
			EventBus.dialogue_ended.emit())
	if completed and not choice.is_empty():
		choice_selected.emit(str(choice.get("action", "close")), choice.duplicate(true))
	var after: Callable = record.options.get("after", Callable())
	if after.is_valid(): after.call(ticket, result)
	record.state = "terminal"
	ticket.resolve(result)
	session_finished.emit(result)
	_records.erase(ticket)
	_barrier -= 1
	_drain()

func _exit_tree() -> void:
	_disposing = true
	_revision += 1
	_incarnation = RefCounted.new()
	_permit = null
	_suspended = false
	if _pending != null:
		var pending := _pending
		_pending = null
		_refuse(pending, "ui_exit")
	_finish(false)
	super._exit_tree()

func _clear_choices() -> void:
	_buttons.clear()
	if not is_node_ready():
		return
	for child in %ChoicesBox.get_children():
		%ChoicesBox.remove_child(child)
		child.queue_free()
	%ChoicesBox.visible = false

func _refresh_hint() -> void:
	if is_node_ready():
		%NextButton.text = UiHints.format("HINT_CONTINUE", &"interact")

func _refresh_texts() -> void:
	if not is_node_ready():
		return
	%SpeakerLabel.text = tr(_line_name_key if _line_name_key != "" else str(_speaker.get("name_key", _speaker.get("speaker_name_key", ""))))
	%PortraitTexture.texture = _speaker.get("portrait", Portraits.portrait(StringName(str(_speaker.get("id", "")))))
	%VoiceIndicator.text = tr("DIALOGUE_VOICE_DA")
	_refresh_hint()
	var shown_line := mini(_line, _lines.size() - 1)
	if shown_line >= 0 and _lines[shown_line].has("text_key"):
		%TextLabel.text = _line_text(_lines[shown_line])
	for button in _buttons:
		button.text = _choice_text(button.get_meta("choice"))

func _choice_text(choice: Dictionary) -> String:
	var text := tr(str(choice.get("text_key", "")))
	if text.contains("%s") and choice.has("title_quest"):
		text = text % QuestManager.get_title(str(choice.title_quest))
	return text

static func fixture_setup(node: Node, _host: Node) -> void:
	node.show_lines({"id": "mayor_lyra", "name_key": "NPC_MAYOR_LYRA"}, [{"text_key": "DLG_LYRA_HELLO"}], [{"text_key": "REL_TALK_GOODBYE", "action": "close"}])
	node._typing = false
	node.get_node("%TextLabel").visible_characters = -1
	node._advance()

static func fixture_intro(node: Node, _host: Node) -> void:
	node.show_lines({"id": "fairy_king", "name_key": "NPC_FAIRY_KING"}, [{"text_key": "DLG_KING_LETTER"}], [])
	node._typing = false
	node.get_node("%TextLabel").visible_characters = -1

static func fixture_guide(node: Node, _host: Node) -> void:
	# Section 03 is a 660px component crop; production viewport captures retain 880px.
	var background := _host.get_node("Backdrop")
	background.color_a = Color("efede5")
	background.color_b = Color("efede5")
	background.queue_redraw()
	node.get_node("%Box").custom_minimum_size.x = 660
	node.show_lines({"id": "mayor_lyra", "name_key": "NPC_MAYOR_LYRA"}, [{"text_key": "GUIDE_DLG_1"}], [{"text_key": "GUIDE_CH_1", "action": "close"}, {"text_key": "GUIDE_CH_2", "action": "close"}])
	node._typing = false
	node.get_node("%TextLabel").visible_characters = -1
	node._advance()


func _line_text(row: Dictionary) -> String:
	return UiHints.format_line(row)
