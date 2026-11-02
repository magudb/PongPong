extends RefCounted
const SECTION := "persistence_consequential_updates"
const TIMEOUT_S := 180.0
# SEC-TEST-PID-KILL-UNVERIFIED-1 identity constants. The probe helper_command
# execs `/bin/sleep 30`; /bin/ps -o command= renders exactly these literals for
# argv [/bin/sleep, <seconds>] (Godot 4.7 OS.create_process builds argv with the
# executable path as argv[0], drivers/unix/os_unix.cpp create_process).
const PROBE_COMMAND := "/bin/sleep 30"
const BYSTANDER_COMMAND := "/bin/sleep 10"
const GONE_PID := 4194303 # ps rejects it ("process id too large"); kern.maxproc is 4000
# Real install dispatch, write_helper and superclass handshake. Only the existing
# command boundary is overridden: an inert sleeper, never an installer.
class UpdateProbe extends "res://scripts/release/release_updates.gd":
	var target := ""
	var commands := []
	var pid_files := []
	var target_action: Callable
	func install_target() -> String:
		if target_action.is_valid(): target_action.call()
		return target
	func helper_command(platform: String, helper: String, destination: String, result: String, parent_pid := OS.get_process_id(), launch := true) -> Array:
		var real: Array = super.helper_command(platform,helper,destination,result,parent_pid,launch)
		commands.append({"result":result,"real_command":real})
		var pidfile := result+".pid"
		pid_files.append(pidfile)
		return ["/bin/bash", PackedStringArray(["-c", "printf '%s' $$ > \"$1\"; exec /bin/sleep 30", "inert-update-probe", pidfile])]

func _write(path: String, text: String) -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string(text); file.close()

# Read-only ps argv observation: the ONLY kill-identity gate. PID-file
# provenance is never identity. Returns the exact rendered command line
# ("" when no such process; stderr is diagnostics, not the command).
func _ps_command(pid: int) -> String:
	if pid <= 0: return ""
	var output := []
	OS.execute("/bin/ps", PackedStringArray(["-p", str(pid), "-o", "command="]), output, false)
	var text := ""
	for line in output:
		text += str(line)
	return text.strip_edges()

# Authenticating kill (SEC-TEST-PID-KILL-UNVERIFIED-1): before ANY signal the
# process must be observed by ps as alive with EXACTLY the expected command,
# never a loose match. Returns "killed" (signalled), "gone" (no such process)
# or "refused" (wrong identity: nothing is signalled).
func _authentic_kill(pid: int, expected_command: String) -> String:
	if pid <= 0: return "gone"
	var observed := _ps_command(pid)
	if observed == "":
		return "gone"
	if observed != expected_command:
		print("[security] _authentic_kill refused pid=", pid, " expected=", expected_command, " observed=", observed)
		return "refused"
	var output := []
	# Godot's child-status API reports an error if production already reaped it.
	if OS.execute("/bin/kill", PackedStringArray(["-0", str(pid)]), output, true) != 0:
		return "gone"
	OS.execute("/bin/kill", PackedStringArray([str(pid)]), output, true)
	return "killed"

func _stop(probe: UpdateProbe) -> void:
	for path in probe.pid_files:
		if not FileAccess.file_exists(path): continue
		var pid := FileAccess.get_file_as_string(path).to_int()
		# PID-file provenance is never identity: authenticate the exact probe
		# command line via ps before any signal (killed/gone/refused).
		_authentic_kill(pid, PROBE_COMMAND)
		DirAccess.remove_absolute(path) # test-owned pidfile removed after handling

func run(t) -> void:
	var sm: Node = t.autoload("SaveManager")
	var gm: Node = t.autoload("GameManager")
	var bus: Node = t.autoload("EventBus")
	var previous_dir: String = sm.save_dir
	t.on_cleanup(func():
		sm.save_dir = previous_dir
		gm.quit_seam = Callable())
	# SEC-TEST-PID-KILL-UNVERIFIED-1 frozen checks. The bystander is this
	# test's OWN OS.create_process child with a DIFFERENT command line; the
	# raw pidfile kill destroys it (RED), an authenticating _stop refuses it.
	var bystander_pid := OS.create_process("/bin/sleep", PackedStringArray(["10"]))
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("user://consequential/security/"))
	var bystander_pidfile := ProjectSettings.globalize_path("user://consequential/security/bystander.pid")
	_write(bystander_pidfile, str(bystander_pid))
	var bystander_probe := UpdateProbe.new()
	bystander_probe.pid_files.append(bystander_pidfile)
	_stop(bystander_probe)
	bystander_probe.free()
	var observed_bystander := _ps_command(bystander_pid)
	var bystander_running := OS.is_process_running(bystander_pid)
	print("[security] bystander=", bystander_pid, " observed=", observed_bystander, " running=", bystander_running, " pidfile_exists=", FileAccess.file_exists(bystander_pidfile))
	t.check("SEC1_wrong_identity_refusal_keeps_unrelated_child_and_clears_pidfile",
		bystander_running and not FileAccess.file_exists(bystander_pidfile))
	t.check("SEC2_bystander_command_line_is_exactly_the_different_sleeper", observed_bystander == BYSTANDER_COMMAND)
	t.check("SEC3_wrong_identity_probe_expectation_returns_refused", _authentic_kill(bystander_pid, PROBE_COMMAND) == "refused")
	var exact_pid := OS.create_process("/bin/sleep", PackedStringArray(["30"]))
	await t.until(func(): return _ps_command(exact_pid) == PROBE_COMMAND, 2.0)
	var exact_outcome := _authentic_kill(exact_pid, PROBE_COMMAND)
	print("[security] exact_probe=", exact_pid, " outcome=", exact_outcome)
	t.check("SEC4_exact_match_probe_cleanup_killed_or_gone", exact_outcome == "killed" or exact_outcome == "gone")
	t.check("SEC5_gone_pid_returns_gone_without_error", _authentic_kill(GONE_PID, PROBE_COMMAND) == "gone")
	var cleanup_outcome := _authentic_kill(bystander_pid, BYSTANDER_COMMAND)
	print("[security] bystander_cleanup=", cleanup_outcome)
	t.check("SEC6_bystander_authenticated_cleanup_returns_killed", cleanup_outcome == "killed")
	for mode in ["validation", "postcommit", "pending", "pending_successor", "pending_quit", "normal"]:
		await t.start_world()
		sm.autosave_enabled = false
		sm.save_dir = "user://consequential/updates/"+mode
		var p := UpdateProbe.new()
		t.root.add_child(p)
		p.target = ProjectSettings.globalize_path("user://consequential/update-target/"+mode+"/Traetoppen.app")
		DirAccess.make_dir_recursive_absolute(p.target.get_base_dir())
		p.downloaded_path = p.target.get_base_dir().path_join("inert-input.zip")
		_write(p.downloaded_path,"not an archive; helper command is controlled and cannot install")
		p.available = {"sha256":FileAccess.get_sha256(p.downloaded_path)}
		p.state = "ready"
		DirAccess.make_dir_recursive_absolute(p.CACHE) # real helper-copy prerequisite, no installer execution
		var codes := []
		gm.quit_seam = func(code): codes.append(code)
		var completed := []
		var committed := []
		var supersede := func(slot):
			if slot != sm.AUTO_SLOT: return
			committed.append(sm._read_json_file(sm.slot_path(slot)).get("state") == "ok")
			PlayerRegistry.reset_states()
		if mode == "postcommit": bus.save_completed.connect(supersede)
		if mode == "validation": p.target_action = func(): PlayerRegistry.reset_states()
		var install := func(): completed.append(await p.install())
		install.call()
		await t.until(func(): return not completed.is_empty() or p.state == "installing", 5.0)
		if mode == "validation":
			t.check("CU12_origin_captured_BEFORE_virtual_validation_and_no_stale_status", completed == [false] and p.commands.is_empty() and p.state == "ready" and codes.is_empty())
		elif mode == "postcommit":
			bus.save_completed.disconnect(supersede)
			t.check("CU01_real_committed_bytes_before_raw_model_replacement", committed == [true])
			t.check("CU02_postcommit_supersession_refuses_BEFORE_helper_launch", completed == [false] and p.commands.is_empty() and codes.is_empty())
		else:
			t.check("CU03_"+mode+"_real_production_handoff_pending", p.state == "installing" and completed.is_empty() and p.commands.size() == 1 and not gm.lifecycle_busy())
			if mode == "pending":
				t.check("CU04_model_only_load_slot_before_pending_replacement", sm.save_game(2))
				var world: Node = t.world()
				t.check("CU05_actual_pending_model_only_load_leaves_world", sm.load_game(2) and world == t.world() and not gm.lifecycle_busy())
			if mode == "pending_successor":
				await t.start_world()
				sm.autosave_enabled = false
				p.state = "ready"
				install.call()
				await t.until(func(): return p.commands.size() == 2, 5.0)
				t.check("CU08_new_install_supersedes_old_pending_request_without_lockout", p.commands.size() == 2 and p.commands[0].result != p.commands[1].result and p.state == "installing")
			if mode == "pending_quit":
				DirAccess.make_dir_recursive_absolute(sm.slot_path(sm.AUTO_SLOT)+".tmp")
				gm.quit_game(71)
				await t.frames(3)
				t.check("CU09_independent_real_quit_confirmation_during_handoff", gm._quit_asking and not gm.lifecycle_busy())
		# Complete the real ready-file handshake, including the baseline's unsafe
		# postcommit launch, to release every original coroutine diagnostically.
		for command in p.commands: _write(command.result+".ready", "ready")
		await t.until(func(): return completed.size() == (2 if mode == "pending_successor" else 1), 5.0)
		if mode == "pending_successor":
			t.check("CU10_old_handshake_tail_cannot_adopt_new_status_result_or_quit", completed == [false,true] and codes == [0] and p.state == "installing" and not FileAccess.file_exists(p.commands[-1].result+".ready"))
		if mode == "pending_quit":
			t.check("CU11_refused_quit_handoff_returns_false_without_clobbering_question", completed == [false] and codes.is_empty() and gm._quit_asking and p.state != "installing")
			var host: Node = t.root.find_child("QuitQuestion",true,false)
			if host != null:
				for dialog in host.find_children("*","UiConfirm",true,false):
					if dialog.is_open(): dialog._cancel_button.pressed.emit()
			await t.frames(3)
			DirAccess.remove_absolute(sm.slot_path(sm.AUTO_SLOT)+".tmp")
		if mode == "pending":
			t.check("CU06_old_successful_handshake_cannot_quit_replacement", completed == [false] and codes.is_empty() and p.state != "installing")
		if mode == "normal":
			t.check("CU07_same_origin_actual_handoff_and_handshake_quit", completed == [true] and codes == [0] and not gm._quitting)
		_stop(p)
		p.free()
	t.check("SEC7_no_live_test_owned_child_remains_at_section_end",
		not OS.is_process_running(bystander_pid) and not OS.is_process_running(exact_pid))
