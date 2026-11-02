extends RefCounted
## Request-local essential completion survives the disposable physical presenter.
const Bridge := preload("res://scripts/social/talk/dialogue_bridge.gd")
var origin: RefCounted
var ui: WeakRef
var area: WeakRef
var actor: WeakRef
var npc: String
var page: Dictionary = {}
var settled := false
var finished := false
var admitted_terminal := false

func current(ticket: RefCounted) -> bool:
	var screen: Variant = ui.get_ref()
	if not admitted_terminal or not _live(screen) or not origin.current(false) or PlayerRegistry.acting_id() != origin.pid: return false
	if area != null:
		var original_area: Variant = area.get_ref()
		if not _live(original_area): return false
		var presenter: Variant = actor.get_ref()
		if _live(presenter) and presenter.area != original_area: return false
	return screen.completion_effects_current(ticket)

static func _live(value: Variant) -> bool:
	return is_instance_valid(value) and value is Node and value.is_inside_tree() and not value.is_queued_for_deletion()

## Only callback-free Living work belongs before UI teardown. Authored flags and
## social observers remain after close so an old close cannot clobber a new UI.
func commit(ticket: RefCounted, result: Dictionary) -> void:
	var presenter: Variant = actor.get_ref()
	if not _live(presenter): return
	# Freeze original-area eligibility while the actor still exists. A later
	# close observer may free it, but cannot erase an earlier area mismatch.
	if area != null and (not _live(area.get_ref()) or presenter.area != area.get_ref()): return
	admitted_terminal = presenter._commit_talk(ticket, result)

func settle(ticket: RefCounted, result: Dictionary) -> void:
	if settled: return
	settled = true
	PlayerRegistry.for_player(origin.pid, func():
		var guard := current.bind(ticket)
		if current(ticket): NpcDialogue.finish(npc, page, result, guard)
		var presenter: Variant = actor.get_ref()
		if _live(presenter): presenter._settle_talk(ticket, result)
		var earned: bool = result.get("completed", false) and int(result.get("lines_shown", 0)) >= page.get("lines", []).size()
		var screen: Variant = ui.get_ref()
		if current(ticket) and (earned or (origin.current() and screen.valid_owner(ticket))):
			SocialManager.on_conversation_finished(npc, int(result.get("lines_shown", 0)), bool(result.get("completed", false)), guard))

func after(ticket: RefCounted, result: Dictionary) -> void:
	if finished: return
	finished = true
	PlayerRegistry.for_player(origin.pid, func():
		if not current(ticket): return
		Bridge.finish_topic_owned(npc, page, bool(result.get("completed", false)), int(result.get("lines_shown", 0)), current.bind(ticket)))
	var presenter: Variant = actor.get_ref()
	if _live(presenter): presenter._after_talk(ticket, result)
