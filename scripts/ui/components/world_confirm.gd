class_name WorldConfirm
extends RefCounted
## A world actor owns the answer, while an independent UI canvas keeps it in screen space.
static func ask(owner_node: Node, title_key: String, text: String, ok_key: String) -> bool:
	if not is_instance_valid(owner_node) or not owner_node.is_inside_tree():
		return false
	var layer := CanvasLayer.new()
	layer.layer = 11
	layer.process_mode = Node.PROCESS_MODE_ALWAYS
	owner_node.add_child(layer)
	var asker := Control.new()
	asker.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(asker)
	asker.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var answer := await UiConfirm.ask(asker, title_key, text, ok_key)
	if is_instance_valid(layer):
		layer.queue_free()
	return answer
