class_name LoopCaps
extends RefCounted
## Package capabilities, never build/version numbers. Unknown capabilities fail closed.
const PROBES := {
	"farm": ["file", "res://data/maps/farm.map"],
	"city": ["file", "res://data/maps/traetoppen.map"],
	"intro": ["file", "res://scripts/farm/steading/tutorial/tutorial_runner.gd"],
	"npc": ["file", "res://scripts/world2d/npc_2d.gd"],
	"shop": ["file", "res://scenes/ui/shop_ui.tscn"],
	"player": ["file", "res://scripts/world2d/player_2d.gd"],
	"save": ["method", "SaveManager", "save_game"],
	"bed": ["method", "GameManager", "end_day"],
	"social": ["method", "SocialManager", "people_rows"],
	"director": ["file", "res://scripts/towns/town_director.gd"],
	"interiors": ["file", "res://data/interiors/core/int_froebutikken.json"],
	"hours": ["file", "res://scripts/towns/hours.gd"],
	"gifts": ["file", "res://scenes/ui/gift_ui.tscn"],
	"post": ["file", "res://scripts/traetoppen/life/post_box_2d.gd"],
	"audio": ["method", "AudioManager", "cue_log"],
	"copy": ["file", "res://tools/copy/copy_lint.py"],
	"festivals": ["file", "res://scripts/social/events/festival_director.gd"],
	"events": ["file", "res://scenes/ui/event_overlay.tscn"],
	"relationships": ["file", "res://scripts/social/relationships/relationship_flow.gd"],
	"post_ui": ["file", "res://scenes/ui/post.tscn"],
	"visits": ["file", "res://scripts/social/visits/farm_visits.gd"],
	"seasonal": ["file", "res://scripts/towns/decor/seasonal_decor.gd"],
	"window": ["window"],
}

static func has(capability: String, tree: SceneTree) -> bool:
	var probe: Array = PROBES.get(capability, [])
	if probe.is_empty():
		return false
	match str(probe[0]):
		"file":
			return ResourceLoader.exists(str(probe[1])) or FileAccess.file_exists(str(probe[1]))
		"method":
			var node := tree.root.get_node_or_null(str(probe[1]))
			return node != null and node.has_method(str(probe[2]))
		"window":
			return DisplayServer.get_name() != "headless"
	return false

static func missing(needs: Array, tree: SceneTree) -> Array[String]:
	var out: Array[String] = []
	for capability in needs:
		if not has(str(capability), tree):
			out.append(str(capability))
	return out

static func required(wave: String, stack: Array = []) -> Array[String]:
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://tests/lib/town_loop/gates.json"))
	if not data.waves.has(wave) or wave in stack:
		return ["INVALID_WAVE:" + wave]
	var out: Array[String] = []
	for item in data.waves[wave]:
		if str(item).begins_with("@"):
			out.append_array(required(str(item).trim_prefix("@"), stack + [wave]))
		elif str(item) not in out:
			out.append(str(item))
	return out
