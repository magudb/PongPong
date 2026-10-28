extends RefCounted
## Focused admission-only review counterexamples; no movement replication.
const SECTION := "multiplayer_corrections"
const TIMEOUT_S := 90.0

class ApplyObserver extends Node:
	var snapshot: Callable
	var mutation: Callable
	var refuse := false
	func to_dict() -> Dictionary:
		if snapshot.is_valid(): snapshot.call()
		return {"value": 1}
	func from_dict(_data: Dictionary) -> bool:
		if mutation.is_valid(): mutation.call()
		return not refuse
	func reset() -> void: pass

func run(t) -> void:
	var saves: Node = t.autoload("SaveManager")
	var prior: String = saves.save_dir
	t.on_cleanup(func(): saves.save_dir = prior)
	var selected := OS.get_environment("MP4_CORRECTION_CASE")
	var cases: Array = [selected] if selected in ["save", "quit", "loaded", "reward", "load", "midloaded", "helpers", "completion", "navigation", "audio_navigation", "guest_navigation"] else ["save", "quit", "loaded", "reward", "load", "midloaded", "helpers", "completion", "navigation", "audio_navigation", "guest_navigation"]
	for scenario: String in cases:
		if not await t.start_world(): return
		saves.save_dir = "user://mp4-corrections-" + scenario
		DirAccess.make_dir_recursive_absolute(saves.save_dir)
		match scenario:
			"quit": await _quit_owner(t, saves)
			"midloaded": await _midloaded_rewards(t, saves)
			"loaded": await _loaded_rewards(t, saves)
			"reward": await _reward_revocation(t)
			"load": await _load_admission(t, saves)
			"helpers": await _helper_admission(t, saves)
			"completion": await _completion_rewards(t, saves)
			"navigation": await _navigation_replacement(t)
			"audio_navigation": await _audio_navigation(t)
			"guest_navigation": await _guest_navigation(t)
			_: await _save_revocation(t, saves)
		await t.go_menu()

func _save_revocation(t, saves: Node) -> void:
	t.check("damaged_manual_positive", saves.save_game(0) and saves.save_game(0), "real primary and backup")
	t.check("damaged_auto_positive", saves.autosave(), "eligible offline autosave")
	var auto: String = saves.slot_path(saves.AUTO_SLOT)
	# Retain a complete inventory, including interrupted-write siblings and old quarantines.
	for suffix in [".tmp", ".old"]: _write(auto + suffix, "retained-" + suffix)
	_write(saves.slot_path(saves.PREV_AUTO_SLOT), "retained-prev")
	for i in range(saves.QUARANTINE_KEEP + 2):
		_write(saves.save_dir.path_join("save_auto.damaged-%d.json" % (100 + i)), "old-quarantine-%d" % i)
	_write(auto, "{ damaged")
	var at_callback := {}
	var observed: Array = []
	var world: Node = PlayerRegistry.world(t.tree)
	var callback := func(_title: String, _message: String, _icon: String):
		world.free()
		var guest: Node = load("res://scripts/world2d/world_2d.gd").new()
		guest.name = "World"
		guest.guest_bootstrap = true
		t.tree.root.add_child(guest)
		t.tree.current_scene = guest
		at_callback.merge(_files(saves.save_dir))
		observed.append(not NetAuthority.can_write())
	EventBus.notification_posted.connect(callback, CONNECT_ONE_SHOT)
	var saved: bool = saves.autosave()
	t.check("quarantine_observer_revoked_writer", observed == [true] and not at_callback.is_empty(), "real notification replaces world with guest")
	t.check("quarantine_stale_save_refused", not saved, "old save must stop after synchronous notification")
	t.check("quarantine_callback_inventory_unchanged", _files(saves.save_dir) == at_callback, "all primary/backup/auto/prev/tmp/old/quarantine names and hashes at callback equal old-call return")
	await t.go_menu()
	if not await t.start_world(): return
	# Same damaged-auto path with unchanged authority must still quarantine, prune and save.
	_write(auto, "{ damaged again")
	t.check("quarantine_current_writer_recovers", saves.autosave() and not saves.get_save_summary(saves.AUTO_SLOT).is_empty(), "legitimate damaged auto recovery")
	var count := 0
	for name in _files(saves.save_dir):
		if name.begins_with("save_auto.damaged-"): count += 1
	t.check("quarantine_current_writer_prunes", count == saves.QUARANTINE_KEEP, "existing retention policy preserved")

func _quit_owner(t, saves: Node) -> void:
	var game: Node = t.autoload("GameManager")
	var world: Node = PlayerRegistry.world(t.tree)
	var session: Node = world.session
	var port := _port()
	t.check("quit_host_bind_positive", session.host(port, 4, "127.0.0.1") == OK, "real otherwise-eligible host")
	var codes: Array = []
	game.quit_seam = func(code: int): codes.append(code)
	t.on_cleanup(func(): game.quit_seam = Callable())
	var replacements: Array = []
	var callback := func(_slot: int):
		session.close(&"replace_on_save")
		replacements.append(session.host(port, 4, "127.0.0.1"))
	EventBus.save_completed.connect(callback, CONNECT_ONE_SHOT)
	await game.quit_game(17)
	t.check("quit_success_replacement_bound", replacements == [OK], "save_completed closed/rehosted exact session")
	t.check("quit_success_stale_owner_refused", codes.is_empty() and session.state == &"hosting", "old quit cannot close replacement or reach exit seam")
	codes.clear() # independent same-owner/failure controls after the stale trace
	await game.quit_game(18)
	t.check("quit_success_current_owner_allowed", codes == [18] and session.state == &"ended", "same-owner successful autosave reaches actual quit seam")
	DirAccess.make_dir_recursive_absolute(saves.slot_path(saves.AUTO_SLOT) + ".tmp")
	var asking := func(): await game.quit_game(19)
	asking.call()
	await t.frames(3)
	t.check("quit_failure_question_positive", game.top_modal() == UiConfirm.MODAL, "real disk failure asks")
	t.tap_key(KEY_ENTER)
	await t.frames(3)
	t.check("quit_failure_cancel_survives", codes == [18] and not game.is_modal_open(), "default Cancel does not exit")
	DirAccess.remove_absolute(saves.slot_path(saves.AUTO_SLOT) + ".tmp")

func _midloaded_rewards(t, saves: Node) -> void:
	var quests: Node = t.autoload("QuestManager")
	var eco: Node = t.autoload("EconomyManager")
	var old: RefCounted = PlayerRegistry.peek_state(&"p0")
	var other: RefCounted = PlayerRegistry.state(&"p1")
	# Warm the real codecs' default fields before comparing the unrelated disk row.
	PlayerRegistry.for_player(&"p1", func():
		eco.from_dict(eco.to_dict())
		quests.from_dict(quests.to_dict()))
	var other_before: Dictionary = other.to_dict().duplicate(true)
	quests.active_quests.clear()
	var wood_before: int = eco.count_item(&"wood")
	var seed_before: int = eco.count_item(&"turnip_seeds")
	quests.pending_rewards = {"mp4_midloaded": {"wood": 3}}
	t.check("midload_deliverable_positive", eco.can_add_item(&"wood", 3) and eco.can_add_item(&"turnip_seeds", 1), "both owners otherwise eligible")
	t.check("midload_valid_disk_positive", saves.save_game(0), "no active quests; real owed reward save")
	quests.pending_rewards = {"mp4_origin": {"turnip_seeds": 1, "wood": 7}}
	var observed: Array = []
	var committed_origin := {}
	var callback := func(id: StringName, item: StringName, amount: int):
		if item != &"turnip_seeds": return
		observed.append([id, item, amount, saves.load_game(0)])
		committed_origin.merge(old.to_dict().duplicate(true))
	EventBus.item_gained.connect(callback)
	quests._queue_reward_claim()
	await t.frames(4)
	EventBus.item_gained.disconnect(callback)
	var current: RefCounted = PlayerRegistry.peek_state(&"p0")
	t.check("midload_real_delivery_loaded", observed == [[&"p0", &"turnip_seeds", 1, true]] and current != old, "successful disk load inside the first actual delivery callback")
	t.check("midload_origin_commit_preserved", _row_count(old, &"turnip_seeds") == seed_before + 1 and _row_count(old, &"wood") == wood_before and old.quests.pending_rewards.get("mp4_origin") == {"wood": 7} and old.to_dict() == committed_origin, "first grant accounted, old second grant refused")
	t.check("midload_replacement_automatically_progresses", eco.count_item(&"wood") == wood_before + 3 and eco.count_item(&"turnip_seeds") == seed_before and quests.pending_rewards.is_empty(), "no additional inventory event required")
	t.check("midload_unrelated_loaded_row_unchanged", PlayerRegistry.peek_state(&"p1").to_dict() == other_before and other.to_dict() == other_before, "unrelated origin and replacement rows")
	await t.frames(4)
	t.check("midload_exactly_once_and_guard_released", eco.count_item(&"wood") == wood_before + 3 and not quests._claiming_rewards and not quests._reward_claim_queued and quests._reward_owners.is_empty(), "settled without deferred busy loop")

func _loaded_rewards(t, saves: Node) -> void:
	var quests: Node = t.autoload("QuestManager")
	var eco: Node = t.autoload("EconomyManager")
	var old: RefCounted = PlayerRegistry.peek_state(&"p0")
	var wood_before: int = eco.count_item(&"wood")
	quests.pending_rewards = {"mp4_loaded": {"wood": 3}}
	t.check("loaded_reward_eligible", eco.can_add_item(&"wood", 3), "otherwise deliverable backlog")
	t.check("loaded_reward_disk_positive", saves.save_game(0), "real valid save with pending reward")
	quests.pending_rewards = {"mp4_stale": {"turnip_seeds": 7}}
	quests._queue_reward_claim()
	var old_state: Dictionary = old.to_dict().duplicate(true)
	t.check("loaded_reward_load_positive", saves.load_game(0), "public load before old deferred ticket runs")
	var current: RefCounted = PlayerRegistry.peek_state(&"p0")
	t.check("loaded_reward_row_replaced", current != old, "actual roster incarnation replacement")
	await t.frames(3)
	t.check("loaded_reward_delivered_once", eco.count_item(&"wood") == wood_before + 3 and quests.pending_rewards.is_empty(), "new loaded row must rearm without another inventory event")
	t.check("loaded_reward_stale_row_unchanged", old.to_dict() == old_state, "obsolete queued reward never delivers to old row")
	await t.frames(3)
	t.check("loaded_reward_no_duplicate", eco.count_item(&"wood") == wood_before + 3, "deferred tickets deliver once")
	quests.pending_rewards = {"mp4_current": {"wood": 2}}
	quests._queue_reward_claim()
	await t.frames(3)
	t.check("loaded_reward_current_control", eco.count_item(&"wood") == wood_before + 5 and quests.pending_rewards.is_empty(), "ordinary current owner still delivers")

func _reward_revocation(t) -> void:
	var quests: Node = t.autoload("QuestManager")
	var eco: Node = t.autoload("EconomyManager")
	var wood_before: int = eco.count_item(&"wood")
	var seeds_before: int = eco.count_item(&"turnip_seeds")
	t.check("reward_two_items_eligible", eco.can_add_item(&"wood", 2) and eco.can_add_item(&"turnip_seeds", 2), "both backpack rewards fit")
	quests.pending_rewards = {"mp4_positive": {"wood": 2, "turnip_seeds": 2}}
	quests._queue_reward_claim()
	await t.frames(3)
	t.check("reward_two_items_current_positive", eco.count_item(&"wood") == wood_before + 2 and eco.count_item(&"turnip_seeds") == seeds_before + 2 and quests.pending_rewards.is_empty(), "ordinary deferred claim delivers both once")
	var old: RefCounted = PlayerRegistry.peek_state(&"p0")
	var other: RefCounted = PlayerRegistry.state(&"p1")
	var other_before: Dictionary = other.to_dict().duplicate(true)
	quests.pending_rewards = {"mp4_revoke": {"wood": 1, "turnip_seeds": 1}}
	var world: Node = PlayerRegistry.world(t.tree)
	var replacement := PlayerState.new(&"p0", 1)
	replacement.reset_profile("Replacement", 0, &"animal_fox")
	var replacement_before: Dictionary = replacement.to_dict().duplicate(true)
	var seen: Array = []
	var callback := func(id: StringName, item: StringName, amount: int):
		seen.append([id, item, amount])
		world.free()
		var guest: Node = load("res://scripts/world2d/world_2d.gd").new()
		guest.name = "World"
		guest.guest_bootstrap = true
		t.tree.root.add_child(guest)
		t.tree.current_scene = guest
		PlayerRegistry._states[&"p0"] = replacement
	EventBus.item_gained.connect(callback, CONNECT_ONE_SHOT)
	quests._queue_reward_claim()
	await t.frames(3)
	t.check("reward_real_callback_revoked", seen == [[&"p0", &"wood", 1]] and not NetAuthority.can_write(), "first real backpack delivery replaces world and profile")
	t.check("reward_first_commit_retained", _row_count(old, &"wood") == wood_before + 3 and _row_count(old, &"turnip_seeds") == seeds_before + 2 and old.quests.pending_rewards.get("mp4_revoke") == {"turnip_seeds": 1}, "first grant is accounted, second remains owed in origin")
	t.check("reward_replacement_untouched", replacement.to_dict() == replacement_before, "no stale second grant or accounting on new row")
	t.check("reward_unrelated_untouched", other.to_dict() == other_before, "other row unchanged")
	t.check("reward_guest_claim_refused", not quests.claim_rewards(), "remote authority cannot deliver")

func _guest_navigation(t) -> void:
	var game: Node = t.autoload("GameManager")
	var codes: Array = []
	game.quit_seam = func(code: int): codes.append(code)
	t.on_cleanup(func(): game.quit_seam = Callable())
	for quitting: bool in [true, false]:
		if not quitting:
			await t.go_menu()
			if not await t.start_world(): return
		var replacement: Node = PlayerRegistry.world(t.tree)
		var replacement_ref: WeakRef = weakref(replacement)
		# Keep a genuinely booted ready offline replacement, not a fake host.
		t.tree.current_scene = null
		t.tree.root.remove_child(replacement)
		var guest: Node = load("res://scripts/world2d/world_2d.gd").new()
		guest.name = "World"
		guest.guest_bootstrap = true
		t.tree.root.add_child(guest)
		t.tree.current_scene = guest
		var session: Node = guest.session
		var port := _port()
		t.check("guest_navigation_join_positive_" + str(quitting), session.join("127.0.0.1", port) == OK and not NetAuthority.can_write(), "real guest ENet entry, never forged role")
		# Keep the actual menu alive through guest destruction to reach its old
		# continuation (the counterexample is not masked by a freed UI WeakRef).
		var menu: Node = load("res://scenes/ui/pause_menu.tscn").instantiate()
		t.tree.root.add_child(menu)
		var rebound: Array = []
		var guest_ref: WeakRef = weakref(guest)
		var callback := func(state: StringName):
			if state != &"ended" or not rebound.is_empty(): return
			var origin_guest: Variant = guest_ref.get_ref()
			if not is_instance_valid(origin_guest): return
			origin_guest.free()
			t.tree.root.add_child(replacement)
			t.tree.current_scene = replacement
			game.change_phase(game.GamePhase.PLAYING)
			rebound.append(replacement.session.host(port, 4, "127.0.0.1"))
		EventBus.net_session_changed.connect(callback)
		codes.clear()
		await menu._leave(quitting)
		EventBus.net_session_changed.disconnect(callback)
		await t.frames(2)
		var live: Variant = replacement_ref.get_ref()
		t.check("guest_navigation_replacement_bound_" + str(quitting), rebound == [OK], "actual ended observer installs ready replacement and real host")
		t.check("guest_navigation_stale_menu_refused_" + str(quitting), live != null and t.tree.current_scene == live and live.session.state == &"hosting" and game.current_phase == game.GamePhase.PLAYING and codes.is_empty() and not game.is_modal_open(), "guest quit/title must not navigate replacement or ask to save")
		menu.queue_free()
		if live != null: live.session.close()
	game.quit_seam = Callable()

func _audio_navigation(t) -> void:
	var game: Node = t.autoload("GameManager")
	var audio: Node = t.autoload("AudioManager")
	var world: Node = PlayerRegistry.world(t.tree)
	var session: Node = world.session
	var port := _port()
	t.check("audio_navigation_host_positive", session.host(port, 4, "127.0.0.1") == OK, "real original host")
	# Retain a REAL engine playback through its normal bounded mixer-drain await.
	# This makes the continuation deterministic, without replacing AudioManager.
	var stream := AudioStreamGenerator.new()
	audio._music_player.stream = stream
	audio._play(audio._music_player)
	var playback: RefCounted = audio._music_player.get_stream_playback()
	t.check("audio_navigation_actual_playback", playback != null and not audio._playbacks.is_empty(), "real AudioStreamPlayback is tracked by the production shutdown")
	var replacements: Array = []
	var callback := func():
		if audio._shutting_down and replacements.is_empty(): replacements.append(session.host(port, 4, "127.0.0.1"))
	t.tree.process_frame.connect(callback)
	game.quit_seam = Callable()
	await game.quit_game(41, false)
	t.tree.process_frame.disconnect(callback)
	t.check("audio_navigation_replacement_survives", replacements == [OK] and session.state == &"hosting" and t.tree.current_scene == world and not game._quitting and not t.tree.paused, "real no-seam quit must cancel after actual asynchronous shutdown")
	# A cancelled quit must leave the real persistent service usable, with no
	# fixture resetting its private shutdown flag.
	audio.play_music("city_theme", 0.0)
	t.check("audio_navigation_public_playback_recovers", not audio._shutting_down and audio._music_player.playing and audio._music_player.has_stream_playback() and audio._music_player.stream == audio._load_stream(audio.MUSIC_DIR, "city_theme"), "actual public playback after stale quit, not merely process survival")
	LocalizationManager.set_locale("da", false)
	for round_index in 2:
		audio.play_ambience("town_day", 0.0)
		audio.play_rain(true)
		audio._music_player.stream = AudioStreamGenerator.new()
		audio._play(audio._music_player)
		var retained: RefCounted = audio._music_player.get_stream_playback()
		var requests: Array = []
		var during := func():
			if not audio._shutting_down or not requests.is_empty(): return
			requests.append(session.host(port, 4, "127.0.0.1"))
			audio.play_music("city_theme", 0.0)
			audio.play_ambience("town_day", 0.0)
			audio.play_rain(true)
			audio.play_sfx("door_open_wood")
			audio.play_voice("voice/mayor_lyra/greet_2")
			requests.append(_audio_channels_live(audio))
		t.tree.process_frame.connect(during)
		await game.quit_game(41, false)
		t.tree.process_frame.disconnect(during)
		t.check("audio_navigation_repeated_requests_" + str(round_index), retained != null and requests == [OK, true] and _audio_channels_live(audio) and not audio._shutting_down and session.state == &"hosting", "replacement's actual music/ambience/rain/SFX/voice during await remain alive after old quit unwinds")
	# Two actual overlapping drains: obsolete recovery cannot undo the newer one.
	var first_origin: Dictionary = game.navigation_origin()
	audio._music_player.stream = AudioStreamGenerator.new()
	audio._play(audio._music_player)
	var held: RefCounted = audio._music_player.get_stream_playback()
	var finished: Array = []
	var first := func():
		await audio.prepare_shutdown(game.navigation_current.bind(first_origin))
		finished.append("old")
	first.call()
	session.close()
	t.check("audio_navigation_new_shutdown_host", session.host(port, 4, "127.0.0.1") == OK, "supported newer owner")
	var next_origin: Dictionary = game.navigation_origin()
	var second := func():
		await audio.prepare_shutdown(game.navigation_current.bind(next_origin))
		finished.append("new")
	second.call()
	await t.frames(2)
	audio.play_music("farm_theme", 0.0)
	t.check("audio_navigation_stale_recovery_cannot_reopen_new_shutdown", held != null and finished == ["old"] and audio._shutting_down and not audio._music_player.playing, "older await returned, current legitimate drain still blocks playback")
	session.close()
	t.check("audio_navigation_final_rehost", session.host(port, 4, "127.0.0.1") == OK, "cancels only second obsolete drain")
	audio.play_music("city_theme", 0.0)
	await t.frames(2)
	t.check("audio_navigation_new_playback_ledger_retained", finished == ["old", "new"] and audio._music_player.playing and audio._music_player.has_stream_playback() and not audio._playbacks.is_empty() and not audio._shutting_down, "neither stale drain clears replacement playback tracking")
	session.close()

func _audio_channels_live(audio: Node) -> bool:
	return audio._music_player.playing and audio._music_player.has_stream_playback() and audio._music_player.stream == audio._load_stream(audio.MUSIC_DIR, "city_theme") and audio._ambient_players[audio._ambient_slot].playing and audio._ambient_players[audio._ambient_slot].has_stream_playback() and audio._rain_player.playing and audio._rain_player.has_stream_playback() and audio._voice_player.playing and audio._voice_player.has_stream_playback() and audio._sfx_pool.any(func(player): return player.playing and player.has_stream_playback())

func _navigation_replacement(t) -> void:
	var game: Node = t.autoload("GameManager")
	var codes: Array = []
	game.quit_seam = func(code: int): codes.append(code)
	t.on_cleanup(func(): game.quit_seam = Callable())
	for mode: String in ["quit_save", "quit_nosave", "title_close", "title_modal", "title_phase"]:
		if mode != "quit_save":
			await t.go_menu()
			if not await t.start_world(): return
		var world: Node = PlayerRegistry.world(t.tree)
		var lifetime: WeakRef = weakref(world)
		var session: Node = world.session
		var session_ref: WeakRef = weakref(session)
		var port := _port()
		t.check(mode + "_host_positive", session.host(port, 4, "127.0.0.1") == OK, "genuine host before navigation")
		var replacements: Array = []
		var replacement_state := {}
		var rehost := func():
			replacements.append(session.host(port, 4, "127.0.0.1"))
			game.change_phase(game.GamePhase.PLAYING)
			replacement_state["phase"] = game.current_phase
			replacement_state["modals"] = game.modal_stack()
		var ended := func(state: StringName):
			if state == &"ended" and replacements.is_empty(): rehost.call()
		var modal_calls: Array = []
		var modal := func(stack: Array):
			if not stack.is_empty(): return
			modal_calls.append(true)
			if mode == "title_phase" and modal_calls.size() == 1:
				game.push_modal(&"mp4_second_phase_boundary", false)
			elif replacements.is_empty(): rehost.call()
		var menu: Node = world.game_ui.get_screen(&"pause_menu")
		if mode.begins_with("title"):
			menu.open()
			await t.frames(2)
		if mode in ["title_modal", "title_phase"]:
			EventBus.modal_changed.connect(modal)
		else:
			EventBus.net_session_changed.connect(ended)
		codes.clear()
		if mode.begins_with("quit"):
			await game.quit_game(23, mode == "quit_save")
		else:
			await menu._leave(false)
		if EventBus.net_session_changed.is_connected(ended): EventBus.net_session_changed.disconnect(ended)
		if EventBus.modal_changed.is_connected(modal): EventBus.modal_changed.disconnect(modal)
		await t.frames(3)
		t.check(mode + "_replacement_bound", replacements == [OK], "supported actual close/rehost at named public seam")
		var live: Variant = lifetime.get_ref()
		var live_session: Variant = session_ref.get_ref()
		t.check(mode + "_stale_navigation_cancelled", live != null and live_session != null and t.tree.current_scene == live and live_session.state == &"hosting" and codes.is_empty() and game.current_phase == replacement_state.get("phase") and game.modal_stack() == replacement_state.get("modals"), "replacement survives old quit/title continuation")
		if live_session != null: live_session.close()
		if live != null: game.pop_all_modals()
	# Ordinary close/rehost remains supported outside navigation.
	await t.go_menu()
	if not await t.start_world(): return
	var session: Node = PlayerRegistry.world(t.tree).session
	var port := _port()
	t.check("navigation_nonnav_host_positive", session.host(port, 4, "127.0.0.1") == OK, "real host")
	var ordinary: Array = []
	var callback := func(state: StringName):
		if state == &"ended" and ordinary.is_empty(): ordinary.append(session.host(port, 4, "127.0.0.1"))
	EventBus.net_session_changed.connect(callback)
	session.close(&"ordinary_close")
	EventBus.net_session_changed.disconnect(callback)
	t.check("navigation_nonnav_rehost_preserved", ordinary == [OK] and session.state == &"hosting", "not a global ban on close/rehost")
	codes.clear()
	await game.quit_game(24, false)
	t.check("navigation_normal_nosave_quit", codes == [24] and session.state == &"ended", "updater/save=false path still exits")
	game.quit_seam = Callable()

func _completion_rewards(t, saves: Node) -> void:
	var quests: Node = t.autoload("QuestManager")
	var eco: Node = t.autoload("EconomyManager")
	var social: Node = t.autoload("SocialManager")
	for mode: String in ["normal_gold", "gold_guest", "gold_load", "normal_friend", "friend_guest", "friend_load"]:
		if mode != "normal_gold":
			await t.go_menu()
			if not await t.start_world(): return
		var qid: StringName = &"secret_garden" if "friend" in mode else &"lost_cat"
		var def: Dictionary = quests.get_quest_def(qid)
		var reward: Dictionary = def.get("rewards", {})
		var friends: Dictionary = reward.get("friendship", {})
		var eligible := not friends.is_empty()
		var initial_hearts := {}
		for npc in friends:
			eligible = eligible and social.befriend_reason(npc) == "" and social.hearts(npc) + int(friends[npc]) <= social.heart_cap()
			initial_hearts[npc] = social.hearts(npc)
		t.check(mode + "_authored_reward_eligible", eligible and int(reward.get("gold", 0)) == 150 and (friends.size() == 2 if "friend" in mode else reward.get("items", {}).get("catnip_seeds") == 3), "actual loaded authored quest, eligible SocialManager recipients")
		quests.active_quests.clear()
		var old: RefCounted = PlayerRegistry.peek_state(&"p0")
		var other: RefCounted = PlayerRegistry.state(&"p1")
		var other_before: Dictionary = other.to_dict().duplicate(true)
		var gold_before: int = eco.gold
		var social_before: Dictionary = social.to_dict().duplicate(true)
		if mode.ends_with("load"):
			t.check(mode + "_disk_positive", saves.save_game(0), "valid replacement with no active or owed quest")
		var terminals: Array = []
		var terminal := func(id: StringName, quest: StringName):
			if quest == qid: terminals.append(id)
		EventBus.quest_completed.connect(terminal)
		var notifications: Array = []
		var notify := func(_a, _b, icon):
			if icon == "quest_done": notifications.append(icon)
		EventBus.notification_posted.connect(notify)
		var observed: Array = []
		var replacement_at_callback := {}
		var social_at_callback := {}
		var old_at_callback := {}
		var world: Node = PlayerRegistry.world(t.tree)
		var revoke := func():
			if mode.ends_with("load"):
				observed.append(saves.load_game(0))
			else:
				world.free()
				var guest: Node = load("res://scripts/world2d/world_2d.gd").new()
				guest.name = "World"
				guest.guest_bootstrap = true
				t.tree.root.add_child(guest)
				t.tree.current_scene = guest
				var replacement := PlayerState.new(&"p0", 1)
				replacement.reset_profile("CompletionReplacement", 0, &"animal_fox")
				PlayerRegistry._states[&"p0"] = replacement
				observed.append(not NetAuthority.can_write())
			replacement_at_callback.merge(PlayerRegistry.peek_state(&"p0").to_dict().duplicate(true))
			social_at_callback.merge(social.to_dict().duplicate(true))
			old_at_callback.merge(old.to_dict().duplicate(true))
		if mode.begins_with("gold"):
			var on_gold := func(_id, _gold, delta):
				if delta == 150: revoke.call()
			EventBus.gold_changed.connect(on_gold, CONNECT_ONE_SHOT)
		elif mode.begins_with("friend"):
			var on_friend := func(_id, _npc, _hearts): revoke.call()
			EventBus.friend_changed.connect(on_friend, CONNECT_ONE_SHOT)
		quests.accept_quest(qid)
		t.check(mode + "_real_quest_active", quests.is_active(qid), "accepted before terminal objective")
		for objective: Dictionary in def.get("objectives", []):
			quests.update_objective(qid, StringName(str(objective.id)), int(objective.target))
		EventBus.quest_completed.disconnect(terminal)
		EventBus.notification_posted.disconnect(notify)
		if mode.begins_with("normal"):
			var correct := true
			for npc in friends:
				correct = correct and social.hearts(npc) == initial_hearts[npc] + int(friends[npc])
			t.check(mode + "_all_rewards_once", correct and eco.gold == gold_before + 150 and terminals == [&"p0"] and notifications == ["quest_done"] and quests.pending_rewards.is_empty(), "same owner gets authored completion and every friendship")
			quests.complete_quest(qid)
			t.check(mode + "_no_replay", eco.gold == gold_before + 150 and terminals == [&"p0"], "completed quest cannot replay")
		else:
			t.check(mode + "_actual_callback_replaced", observed == [true] and PlayerRegistry.peek_state(&"p0") != old, "real gold or first friendship observer replaces incarnation")
			t.check(mode + "_committed_completion_retained", old.gold == gold_before + 150 and qid in old.quests.completed and old.to_dict() == old_at_callback, "completion/gold and original owed accounting are retained")
			t.check(mode + "_replacement_untouched", PlayerRegistry.peek_state(&"p0").to_dict() == replacement_at_callback and social.to_dict() == social_at_callback, "no later friendship, item, flag or row mutation")
			t.check(mode + "_old_terminal_refused", terminals.is_empty() and notifications.is_empty(), "old completion notification/Lua consequence cannot run")
			if mode.begins_with("gold"):
				t.check(mode + "_friendship_not_started", social_at_callback == social_before and old.quests.pending_rewards.get(str(qid)) == reward.get("items", {}), "gold is committed; all friendship/items remain ungranted")
			else:
				var gained := 0
				# Flags on the captured origin record the committed first friend grant.
				for npc in friends:
					if int(old.flags.get("friend_" + str(npc), 0)) == initial_hearts[npc] + int(friends[npc]): gained += 1
				t.check(mode + "_only_first_friend_committed", gained == 1, "second authored friendship must not borrow the replacement")
			t.check(mode + "_unrelated_origin_unchanged", other.to_dict() == other_before, "unrelated player row is not a reward owner")

func _helper_admission(t, saves: Node) -> void:
	var world: Node = PlayerRegistry.world(t.tree)
	var session: Node = world.session
	var port := _port()
	t.check("helper_bind_positive", session.host(port, 4, "127.0.0.1") == OK, "independent real bind premise")
	session.close()
	var observer := ApplyObserver.new()
	t.tree.root.add_child(observer)
	t.check("helper_observer_registered", saves.register_section("mp4_helper_observer", observer, 999), "actual callback seam")
	t.check("helper_save_positive", saves.save_game(0), "real valid disk payload")
	var payload: Dictionary = saves.inspect_slot(0).payload
	var attempts: Array = []
	var admit := func():
		attempts.append(session.host(port, 4, "127.0.0.1"))
		# Preserve the baseline's successful bind evidence without letting this
		# diagnostic transport contaminate later controls or mixed-model applies.
		session.close()
	if saves.has_method("_apply_payload_offline"):
		observer.snapshot = admit
		saves.call("_apply_payload_offline", payload)
		observer.snapshot = Callable()
		t.check("helper_direct_apply_excluded_or_removed", attempts == [ERR_BUSY], "actual=%s" % [attempts])
	else:
		t.check("helper_direct_apply_excluded_or_removed", true, "unsafe whole-operation helper eliminated")
	attempts.clear()
	if saves.has_method("load_game_offline"):
		var completed := func(_slot: int): admit.call()
		EventBus.load_completed.connect(completed, CONNECT_ONE_SHOT)
		saves.call("load_game_offline", 0)
		t.check("helper_direct_load_completion_excluded_or_removed", attempts == [ERR_BUSY], "actual=%s" % [attempts])
	else:
		t.check("helper_direct_load_completion_excluded_or_removed", true, "unsafe whole-operation helper eliminated")
	attempts.clear()
	var prior_scene: String = saves.world_scene
	saves.world_scene = "res://missing-mp4-helper-world.tscn"
	if saves.has_method("load_and_enter_offline"):
		var failed := func(_a, _b, _c): admit.call()
		EventBus.notification_posted.connect(failed, CONNECT_ONE_SHOT)
		saves.call("load_and_enter_offline", 0)
		t.check("helper_direct_enter_excluded_or_removed", attempts == [ERR_BUSY], "actual=%s" % [attempts])
	else:
		t.check("helper_direct_enter_excluded_or_removed", true, "unsafe whole-operation helper eliminated")
	saves.world_scene = prior_scene
	attempts.clear()
	var prior_dir: String = saves.save_dir
	saves.save_dir = prior_dir + "-empty-continue"
	DirAccess.make_dir_recursive_absolute(saves.save_dir)
	if saves.has_method("continue_latest_offline"):
		var failed := func(_a, _b, _c): admit.call()
		EventBus.notification_posted.connect(failed, CONNECT_ONE_SHOT)
		saves.call("continue_latest_offline")
		t.check("helper_direct_continue_excluded_or_removed", attempts == [ERR_BUSY], "actual=%s" % [attempts])
	else:
		t.check("helper_direct_continue_excluded_or_removed", true, "unsafe whole-operation helper eliminated")
	saves.save_dir = prior_dir
	t.check("helper_postreturn_admission_positive", session.host(port, 4, "127.0.0.1") == OK and not saves.network_admission_blocked(), "real return releases occupancy")
	session.close()
	saves.unregister_section("mp4_helper_observer")
	observer.queue_free()

func _load_admission(t, saves: Node) -> void:
	var world: Node = PlayerRegistry.world(t.tree)
	var session: Node = world.session
	var game: Node = t.autoload("GameManager")
	var port := _port()
	t.check("load_bind_eligible_positive", session.host(port, 4, "127.0.0.1") == OK, "real bind available before loading")
	t.check("load_existing_host_refused", not saves.load_game(0) and not saves._apply_payload({}).ok, "existing session retains lifecycle")
	session.close()
	var observer := ApplyObserver.new()
	t.tree.root.add_child(observer)
	t.check("load_observer_registered", saves.register_section("mp4_apply_observer", observer, 999), "actual rollback serializer/mutator")
	t.on_cleanup(func(): saves.unregister_section("mp4_apply_observer"); observer.queue_free())
	game.player_name = "SavedName"
	t.check("load_valid_disk_positive", saves.save_game(0) and saves.save_game(1), "real valid independent primary slots")
	var payload: Dictionary = saves.inspect_slot(0).payload
	var attempts: Array = []
	observer.snapshot = func(): attempts.append(session.host(port, 4, "127.0.0.1"))
	game.player_name = "BeforeDirect"
	var applied: Dictionary = saves._apply_payload(payload)
	t.check("load_direct_snapshot_admission_refused", attempts == [ERR_BUSY], "direct apply owns rollback snapshot callback; actual=%s" % [attempts])
	t.check("load_direct_same_owner_applies", applied.ok and game.player_name == "SavedName", "no mixed host/game/roster apply")
	session.close()
	attempts.clear()
	var completions: Array = []
	var completed := func(_slot: int): completions.append(session.host(port, 4, "127.0.0.1"))
	EventBus.load_completed.connect(completed, CONNECT_ONE_SHOT)
	game.player_name = "BeforePublic"
	var loaded: bool = saves.load_game(0)
	t.check("load_public_snapshot_admission_refused", attempts == [ERR_BUSY], "public load covers snapshots too; actual=%s" % [attempts])
	t.check("load_completion_admission_refused", completions == [ERR_BUSY], "load owns synchronous completion observers")
	t.check("load_public_same_owner_applies", loaded and game.player_name == "SavedName", "normal offline load preserved")
	session.close()
	observer.snapshot = Callable()
	attempts.clear()
	observer.mutation = func(): attempts.append(session.host(port, 4, "127.0.0.1"))
	observer.refuse = true
	game.player_name = "BeforeFailure"
	var failure_attempts: Array = []
	var failed := func(_title, _message, _icon): failure_attempts.append(session.host(port, 4, "127.0.0.1"))
	EventBus.notification_posted.connect(failed, CONNECT_ONE_SHOT)
	var rejected: bool = saves.load_game(1)
	t.check("load_mutation_rollback_admission_refused", attempts == [ERR_BUSY, ERR_BUSY], "failing mutator plus rollback both exclude new host; actual=%s" % [attempts])
	t.check("load_failure_notification_admission_refused", failure_attempts == [ERR_BUSY], "failure completion remains owned")
	t.check("load_failure_rolls_back", not rejected and game.player_name == "BeforeFailure", "legitimate late rejection restores offline game")
	session.close()
	observer.mutation = Callable()
	observer.refuse = false
	t.check("load_after_failure_admission_released", session.host(port, 4, "127.0.0.1") == OK, "no leaked busy fence")
	session.close()
	t.check("load_after_success_positive", saves.load_game(0) and session.host(port, 4, "127.0.0.1") == OK, "admission becomes available after real successful load returns")
	session.close()

func _row_count(row: RefCounted, id: StringName) -> int:
	var count := 0
	for entry: Dictionary in row.inventory:
		if StringName(entry.id) == id: count += int(entry.amount)
	return count

func _port() -> int:
	var transport := ENetMultiplayerPeer.new()
	transport.set_bind_ip("127.0.0.1")
	if transport.create_server(0, 1) != OK: return 0
	var port := transport.host.get_local_port()
	transport.close()
	return port

func _write(path: String, text: String) -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string(text)

func _files(directory: String) -> Dictionary:
	var out := {}
	for name in DirAccess.get_files_at(directory): out[name] = FileAccess.get_sha256(directory.path_join(name))
	return out
