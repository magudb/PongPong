extends RefCounted
## Tiny DSL for generating .tscn Control trees from code (tools/ui/build_scenes.gd).
## After generation the .tscn files are normal editor scenes; this kit only exists so that
## ~900 nodes of guide-exact layout don't have to be typed by hand.

const NO_THEME := &""

var root: Node = null
## "" = write to the path the builder names (res://scenes/...); else the directory every res:// path is re-rooted into
## (reference builds of the screen builders, tools/ui/build_scenes.gd --out=DIR)
var out_root: String = ""


func begin(type: String, nm: String, script_path: String = "") -> Node:
	var n: Node = ClassDB.instantiate(type)
	n.name = nm
	if script_path != "":
		n.set_script(load(script_path))
	root = n
	return n


func add(parent: Node, type: String, nm: String, props: Dictionary = {}, unique: bool = false) -> Node:
	var n: Node = ClassDB.instantiate(type)
	n.name = nm
	parent.add_child(n)
	n.owner = root
	if unique:
		n.unique_name_in_owner = true
	apply(n, props)
	return n


func apply(n: Object, props: Dictionary) -> void:
	for k in props:
		var v = props[k]
		match k:
			"script":
				n.set_script(load(v))
			"variation":
				n.set("theme_type_variation", StringName(v))
			"min":
				n.set("custom_minimum_size", v)
			"sep":
				n.add_theme_constant_override("separation", v)
			"font_color":
				n.add_theme_color_override("font_color", v)
			"font_size":
				n.add_theme_font_size_override("font_size", v)
			"hsep":
				n.add_theme_constant_override("h_separation", v)
			"vsep":
				n.add_theme_constant_override("v_separation", v)
			"expand_h":
				n.set("size_flags_horizontal", Control.SIZE_EXPAND_FILL if v else Control.SIZE_FILL)
			"expand_v":
				n.set("size_flags_vertical", Control.SIZE_EXPAND_FILL if v else Control.SIZE_FILL)
			"shrink_end_h":
				n.set("size_flags_horizontal", Control.SIZE_SHRINK_END)
			"shrink_end_v":
				n.set("size_flags_vertical", Control.SIZE_SHRINK_END)
			"shrink_begin_h":
				n.set("size_flags_horizontal", Control.SIZE_SHRINK_BEGIN)
			"shrink_begin_v":
				n.set("size_flags_vertical", Control.SIZE_SHRINK_BEGIN)
			"shrink_center_h":
				n.set("size_flags_horizontal", Control.SIZE_SHRINK_CENTER)
			"shrink_center_v":
				n.set("size_flags_vertical", Control.SIZE_SHRINK_CENTER)
			"ignore":
				n.set("mouse_filter", Control.MOUSE_FILTER_IGNORE if v else Control.MOUSE_FILTER_STOP)
			"pass":
				n.set("mouse_filter", Control.MOUSE_FILTER_PASS)
			_:
				n.set(k, v)


# ---------------------------------------------------------------- layout helpers
func full(n: Control) -> Control:
	n.anchor_left = 0.0
	n.anchor_top = 0.0
	n.anchor_right = 1.0
	n.anchor_bottom = 1.0
	n.offset_left = 0.0
	n.offset_top = 0.0
	n.offset_right = 0.0
	n.offset_bottom = 0.0
	n.grow_horizontal = Control.GROW_DIRECTION_BOTH
	n.grow_vertical = Control.GROW_DIRECTION_BOTH
	return n


## Pin a shrink-wrapped control to a screen corner with CSS-like inset (px).
## corner: "tl","tr","bl","br","tc" (top centre),"bc" (bottom centre),"c" (centre)
func pin(n: Control, corner: String, inset_x: float = 0.0, inset_y: float = 0.0) -> Control:
	var ax := 0.0
	var ay := 0.0
	match corner:
		"tl": ax = 0.0; ay = 0.0
		"tr": ax = 1.0; ay = 0.0
		"bl": ax = 0.0; ay = 1.0
		"br": ax = 1.0; ay = 1.0
		"tc": ax = 0.5; ay = 0.0
		"bc": ax = 0.5; ay = 1.0
		"c": ax = 0.5; ay = 0.5
		"lc": ax = 0.0; ay = 0.5
		"rc": ax = 1.0; ay = 0.5
	n.anchor_left = ax
	n.anchor_right = ax
	n.anchor_top = ay
	n.anchor_bottom = ay
	var sx := 1.0 if ax == 0.0 else (-1.0 if ax == 1.0 else 0.0)
	var sy := 1.0 if ay == 0.0 else (-1.0 if ay == 1.0 else 0.0)
	n.offset_left = inset_x * sx
	n.offset_right = inset_x * sx
	n.offset_top = inset_y * sy
	n.offset_bottom = inset_y * sy
	n.grow_horizontal = Control.GROW_DIRECTION_END if ax == 0.0 else (Control.GROW_DIRECTION_BEGIN if ax == 1.0 else Control.GROW_DIRECTION_BOTH)
	n.grow_vertical = Control.GROW_DIRECTION_END if ay == 0.0 else (Control.GROW_DIRECTION_BEGIN if ay == 1.0 else Control.GROW_DIRECTION_BOTH)
	return n


## Fixed rect in design px from the top-left corner.
func rect(n: Control, x: float, y: float, w: float, h: float) -> Control:
	n.anchor_left = 0.0
	n.anchor_top = 0.0
	n.anchor_right = 0.0
	n.anchor_bottom = 0.0
	n.offset_left = x
	n.offset_top = y
	n.offset_right = x + w
	n.offset_bottom = y + h
	return n


# ---------------------------------------------------------------- widgets
func lbl(parent: Node, nm: String, text: String, variation: String = "", props: Dictionary = {}, unique: bool = false) -> Label:
	var l: Label = add(parent, "Label", nm, {"text": text}, unique)
	if variation != "":
		l.theme_type_variation = StringName(variation)
	apply(l, props)
	return l


func btn(parent: Node, nm: String, text: String, variation: String = "", props: Dictionary = {}, unique: bool = false) -> Button:
	var b: Button = add(parent, "Button", nm, {"text": text}, unique)
	if variation != "":
		b.theme_type_variation = StringName(variation)
	apply(b, props)
	return b


func panel(parent: Node, nm: String, variation: String = "", props: Dictionary = {}, unique: bool = false) -> PanelContainer:
	var p: PanelContainer = add(parent, "PanelContainer", nm, {}, unique)
	if variation != "":
		p.theme_type_variation = StringName(variation)
	apply(p, props)
	return p


func hbox(parent: Node, nm: String, sep: int = 0, props: Dictionary = {}, unique: bool = false) -> HBoxContainer:
	var b: HBoxContainer = add(parent, "HBoxContainer", nm, {}, unique)
	b.add_theme_constant_override("separation", sep)
	apply(b, props)
	return b


func vbox(parent: Node, nm: String, sep: int = 0, props: Dictionary = {}, unique: bool = false) -> VBoxContainer:
	var b: VBoxContainer = add(parent, "VBoxContainer", nm, {}, unique)
	b.add_theme_constant_override("separation", sep)
	apply(b, props)
	return b


func margin(parent: Node, nm: String, l: int, t: int, r: int, b: int, props: Dictionary = {}, unique: bool = false) -> MarginContainer:
	var m: MarginContainer = add(parent, "MarginContainer", nm, {}, unique)
	m.add_theme_constant_override("margin_left", l)
	m.add_theme_constant_override("margin_top", t)
	m.add_theme_constant_override("margin_right", r)
	m.add_theme_constant_override("margin_bottom", b)
	apply(m, props)
	return m


func spacer(parent: Node, nm: String = "Spacer", w: float = 0.0, h: float = 0.0, expand_h: bool = false, expand_v: bool = false) -> Control:
	var c: Control = add(parent, "Control", nm, {"min": Vector2(w, h), "mouse_filter": Control.MOUSE_FILTER_IGNORE})
	if expand_h:
		c.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if expand_v:
		c.size_flags_vertical = Control.SIZE_EXPAND_FILL
	return c


func stripes(parent: Node, nm: String, a: Color, b: Color, band: float = 14.0, props: Dictionary = {}) -> ColorRect:
	var r: ColorRect = add(parent, "ColorRect", nm)
	r.set_script(load("res://scripts/ui/components/tt_stripes.gd"))
	r.set("color_a", a)
	r.set("color_b", b)
	r.set("band", band)
	apply(r, props)
	return r


func inst(parent: Node, scene_path: String, nm: String, props: Dictionary = {}, unique: bool = false) -> Node:
	var ps: PackedScene = load(scene_path)
	var n: Node = ps.instantiate()
	n.name = nm
	parent.add_child(n)
	n.owner = root
	if unique:
		n.unique_name_in_owner = true
	apply(n, props)
	return n


func coin(parent: Node, nm: String, ink_border: bool = false) -> PanelContainer:
	return panel(parent, nm, "CoinInk" if ink_border else "Coin", {"min": Vector2(24, 24), "shrink_center_v": true})


func save(path: String) -> int:
	if out_root != "":
		path = out_root.path_join(path.trim_prefix("res://"))
		DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	var ps := PackedScene.new()
	var err := ps.pack(root)
	if err != OK:
		push_error("pack failed for %s: %d" % [path, err])
		return err
	err = ResourceSaver.save(ps, path)
	print("saved ", path, " err=", err, " nodes=", _count(root))
	root.free()
	root = null
	return err


func _count(n: Node) -> int:
	var c := 1
	for ch in n.get_children():
		if ch.owner == root or ch.owner == null:
			c += _count(ch)
	return c
