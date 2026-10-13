extends SceneTree
## Lists every action of the live InputMap with its events and verifies the result against the
## input contract (PLAN 3.2 + addendum 3.3, tests/tools/input_contract.gd). Exit code 0 only when
## the map matches the contract exactly.
##
##   godot --headless --path . -s res://tests/tools/print_inputmap.gd [-- --all]
##
## The focus-navigation actions of PLAN 3.2's last row (ui_accept and ui_cancel with the project's
## pad override, the four D-pad carrying actions) are always listed and verified. --all also lists
## every other built-in ui_* action (Godot defaults, not part of the contract).

const Contract := preload("res://tests/tools/input_contract.gd")


func _initialize() -> void:
	var show_all: bool = "--all" in OS.get_cmdline_user_args()
	var all_actions: Array = []
	for a: StringName in InputMap.get_actions():
		all_actions.append(String(a))
	all_actions.sort()

	var custom: Array = []
	var builtin: Array = []
	for s: String in all_actions:
		if s.begins_with("ui_"):
			builtin.append(s)
		else:
			custom.append(s)

	print("== InputMap: %d custom actions, %d built-in ui_* actions ==" % [custom.size(), builtin.size()])
	# contract order first (the order of PLAN 3.2), then anything unexpected
	var ordered: Array = []
	for a: String in Contract.ACTIONS:
		if custom.has(a):
			ordered.append(a)
	for a: String in custom:
		if not ordered.has(a):
			ordered.append(a)
	for a: String in ordered:
		_print_action(a, Contract.ADDENDUM.has(a))
	print("== focus navigation (PLAN 3.2 last row: Godot defaults + D-pad, joy A/B; project override on ui_accept, ui_cancel) ==")
	var ui_listed: Array = []
	for a: String in Contract.UI_OVERRIDES:
		ui_listed.append(a)
	for a: String in Contract.UI_DPAD:
		ui_listed.append(a)
	for a: String in ui_listed:
		_print_action(a, false)
	if show_all:
		print("== other built-in ui_* actions (Godot defaults) ==")
		for a: String in builtin:
			if not ui_listed.has(a):
				_print_action(a, false)

	print("== shared bindings (one input, several actions; intended, the context decides) ==")
	var shared: Dictionary = Contract.shared_bindings()
	var sigs: Array = shared.keys()
	sigs.sort()
	for sig: String in sigs:
		print("  %-10s -> %s" % [sig, ", ".join(shared[sig])])

	var errors: Array = Contract.verify()
	var base_count: int = Contract.ACTIONS.size() - Contract.ADDENDUM.size()
	if errors.is_empty():
		print("P01 INPUTMAP OK: ui_accept takes joy A, ui_cancel takes joy B, the D-pad walks focus; no event is modifier-, location- or device-qualified")
		print("P01 INPUTMAP OK: %d actions = %d (PLAN 3.2) + %d (addendum 3.3: %s); no unintended clash" % [
			Contract.ACTIONS.size(), base_count, Contract.ADDENDUM.size(), ", ".join(Contract.ADDENDUM)])
		quit(0)
		return
	for e: String in errors:
		printerr("P01 INPUTMAP FAIL: " + e)
	print("P01 INPUTMAP FAIL: %d problem(s)" % errors.size())
	quit(1)


func _print_action(action: String, addendum: bool) -> void:
	var events: Array[InputEvent] = InputMap.action_get_events(action)
	print("%s%s  (deadzone %.2f, %d events)" % [action, " [addendum]" if addendum else "", InputMap.action_get_deadzone(action), events.size()])
	for ev: InputEvent in events:
		print("    %s   <%s>" % [ev.as_text(), Contract.signature(ev)])
