@tool
extends Window

## "Manage Bone Chain" window for an EasyIKManager.
##
## The chain is an explicit ordered list of joints — Add / Remove / reorder, one Bone2D per
## joint (picked from the scene tree), each with its own angle limits — mirroring Godot's native
## SkeletonModification2DCCDIK workflow. Every edit goes through the editor's undo/redo.
##
## Shown as a regular (non-popup) embedded window so opening the native node selector does not
## dismiss it, and reused via a stable name so it survives inspector rebuilds.

var _node: EasyIKManager
var _editor_plugin: EditorPlugin
var _theme: Theme

# True while the native node selector is open, so its exclusive dialog can't close this window.
var _picking: bool = false

var _summary: Label
var _twobone_note: Label
var _joints_box: VBoxContainer
var _add_joint_btn: Button
var _solver_section: VBoxContainer
var _solver_sep: HSeparator
var _iterations_spin: SpinBox


func setup(node: EasyIKManager, plugin: EditorPlugin) -> void:
	_node = node
	_editor_plugin = plugin
	_theme = EditorInterface.get_editor_theme()
	exclusive = false
	transient = false
	unresizable = false
	size = Vector2i(540, 680)
	min_size = Vector2i(480, 520)
	close_requested.connect(_on_close_requested)
	_build_ui()
	_refresh()
	_center_on_editor()
	show()


## Point this (single, shared) window at a different manager and refresh.
func rebind(node: EasyIKManager) -> void:
	_node = node
	if not is_instance_valid(_node):
		queue_free()
		return
	_refresh()
	show()
	grab_focus()


## Free the window if the manager it edits is gone (deleted, or its scene closed), so a stale
## window never lingers or binds to a freed node. Robust with any number of managers.
func _process(_delta: float) -> void:
	if not is_instance_valid(_node):
		queue_free()


## Close on the title-bar X — unless a node selector is open (its exclusive dialog fires this).
func _on_close_requested() -> void:
	if _picking:
		return
	queue_free()


## Brings the window back to the front (e.g. after the modal node selector closes).
func _restore() -> void:
	if is_inside_tree():
		show()
		grab_focus()


func _center_on_editor() -> void:
	var base := EditorInterface.get_base_control()
	if base != null:
		var pos := (base.size - Vector2(size)) * 0.5
		position = Vector2i(maxf(pos.x, 0.0), maxf(pos.y, 0.0))


# ─── UI CONSTRUCTION ───────────────────────────────────────────────────────────

func _build_ui() -> void:
	var bg := Panel.new()
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var sb := StyleBoxFlat.new()
	sb.bg_color = _base_bg_color()
	bg.add_theme_stylebox_override("panel", sb)
	add_child(bg)

	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "top", "right", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 12)
	add_child(margin)

	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 10)
	margin.add_child(vb)

	# ── Chain section ──
	vb.add_child(_make_header("Bone Chain", "BoneAttachment2D"))
	_summary = _make_muted_label("")
	vb.add_child(_summary)
	_twobone_note = _make_muted_label("2DTwoBoneIK uses the first two joints; angle limits and " \
			+ "iterations do not apply to it.")
	vb.add_child(_twobone_note)

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	vb.add_child(scroll)
	_joints_box = VBoxContainer.new()
	_joints_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_joints_box.add_theme_constant_override("separation", 8)
	scroll.add_child(_joints_box)

	_add_joint_btn = Button.new()
	_add_joint_btn.text = "  Add Joint"
	var add_icon := _editor_icon("Add")
	if add_icon != null:
		_add_joint_btn.icon = add_icon
	_add_joint_btn.pressed.connect(_add_joint)
	vb.add_child(_add_joint_btn)

	# ── Solver section ──
	_solver_sep = HSeparator.new()
	vb.add_child(_solver_sep)
	_solver_section = VBoxContainer.new()
	_solver_section.add_theme_constant_override("separation", 6)
	vb.add_child(_solver_section)
	_solver_section.add_child(_make_header("Solver"))
	var solver_grid := GridContainer.new()
	solver_grid.columns = 2
	solver_grid.add_theme_constant_override("h_separation", 10)
	_solver_section.add_child(solver_grid)
	solver_grid.add_child(_make_label("Iterations"))
	_iterations_spin = SpinBox.new()
	_iterations_spin.min_value = 1
	_iterations_spin.max_value = 16
	_iterations_spin.step = 1
	_iterations_spin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_iterations_spin.tooltip_text = "Solver passes per frame (convergence speed) — not the bone count."
	_iterations_spin.value_changed.connect(_on_iterations_changed)
	solver_grid.add_child(_iterations_spin)

	# ── Footer ──
	vb.add_child(HSeparator.new())
	var footer := HBoxContainer.new()
	footer.alignment = BoxContainer.ALIGNMENT_END
	vb.add_child(footer)
	var close_btn := Button.new()
	close_btn.text = "Close"
	close_btn.pressed.connect(queue_free)
	footer.add_child(close_btn)


func _base_bg_color() -> Color:
	var settings := EditorInterface.get_editor_settings()
	if settings != null:
		var c: Variant = settings.get_setting("interface/theme/base_color")
		if c is Color:
			return (c as Color).darkened(0.06)
	return Color(0.15, 0.16, 0.19)


func _make_header(text: String, icon_name: String = "") -> Control:
	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", 6)
	var tex := _editor_icon(icon_name)
	if tex != null:
		var rect := TextureRect.new()
		rect.texture = tex
		rect.custom_minimum_size = Vector2(16, 16)
		rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		hb.add_child(rect)
	var label := Label.new()
	label.text = text
	if _theme != null and _theme.has_font("bold", "EditorFonts"):
		label.add_theme_font_override("font", _theme.get_font("bold", "EditorFonts"))
	if _theme != null and _theme.has_color("accent_color", "Editor"):
		label.add_theme_color_override("font_color", _theme.get_color("accent_color", "Editor"))
	hb.add_child(label)
	return hb


func _make_label(text: String) -> Label:
	var label := Label.new()
	label.text = text
	label.custom_minimum_size = Vector2(80, 0)
	return label


func _make_muted_label(text: String) -> Label:
	var label := Label.new()
	label.text = text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.modulate = Color(1, 1, 1, 0.62)
	return label


func _editor_icon(icon_name: String) -> Texture2D:
	if icon_name != "" and _theme != null and _theme.has_icon(icon_name, "EditorIcons"):
		return _theme.get_icon(icon_name, "EditorIcons")
	return null


func _mini_button(text: String, tip: String) -> Button:
	var b := Button.new()
	b.text = text
	b.tooltip_text = tip
	b.custom_minimum_size = Vector2(28, 0)
	return b


# ─── REFRESH ───────────────────────────────────────────────────────────────────

func _refresh() -> void:
	if not is_instance_valid(_node):
		queue_free()
		return
	title = "EasyIK — Manage Bone Chain  (%s)" % _node.name
	_summary.text = "Chain:  %s" % _node.get_chain_summary()
	_twobone_note.visible = _node.modification_type == EasyIKEnums.ModificationType.TWO_BONE_IK

	var uses := _node.uses_joint_constraints()
	_solver_section.visible = uses
	_solver_sep.visible = uses
	if uses:
		_iterations_spin.set_value_no_signal(_node.iterations)
	_rebuild_joints_ui()


func _rebuild_joints_ui() -> void:
	for child in _joints_box.get_children():
		child.queue_free()

	var count := _node.get_joint_count()
	if count == 0:
		_joints_box.add_child(_make_muted_label("No joints yet — click \"Add Joint\" and assign a bone to each."))
		return
	for i in count:
		_joints_box.add_child(_make_joint_panel(i, count))


func _make_joint_panel(index: int, count: int) -> PanelContainer:
	var data := _node.get_joint_data(index)
	var enabled: bool = data.get("enabled", false)

	var panel := PanelContainer.new()
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 4)
	panel.add_child(vbox)

	# Header: index + bone picker + reorder + remove.
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 4)
	vbox.add_child(head)

	var idx_label := Label.new()
	idx_label.text = "Joint %d" % index
	idx_label.custom_minimum_size = Vector2(54, 0)
	if _theme != null and _theme.has_font("bold", "EditorFonts"):
		idx_label.add_theme_font_override("font", _theme.get_font("bold", "EditorFonts"))
	head.add_child(idx_label)

	var bone_btn := Button.new()
	bone_btn.clip_text = true
	bone_btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
	bone_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bone_btn.text = "  " + _node.get_joint_bone_name(index)
	bone_btn.tooltip_text = "Pick this joint's Bone2D from the scene."
	if _node.get_joint_bone_path(index).is_empty():
		bone_btn.modulate = Color(1, 1, 1, 0.7)
	else:
		var bone_icon := _editor_icon("Bone2D")
		if bone_icon != null:
			bone_btn.icon = bone_icon
	bone_btn.pressed.connect(_pick_joint_bone.bind(index))
	head.add_child(bone_btn)

	var up := _mini_button("↑", "Move up")
	up.disabled = index == 0
	up.pressed.connect(_move_joint.bind(index, -1))
	head.add_child(up)

	var down := _mini_button("↓", "Move down")
	down.disabled = index == count - 1
	down.pressed.connect(_move_joint.bind(index, 1))
	head.add_child(down)

	var remove := _mini_button("✕", "Remove joint")
	remove.pressed.connect(_remove_joint.bind(index))
	head.add_child(remove)

	# Angle limits (CCDIK / FABRIK only).
	if _node.uses_joint_constraints():
		var limit_row := HBoxContainer.new()
		vbox.add_child(limit_row)
		limit_row.add_child(_make_flag_checkbox(index, "enabled", "Limit angle", enabled, true))

		if enabled:
			var grid := GridContainer.new()
			grid.columns = 2
			grid.add_theme_constant_override("h_separation", 10)
			grid.add_theme_constant_override("v_separation", 4)
			vbox.add_child(grid)
			grid.add_child(_make_label("Angle Min"))
			grid.add_child(_make_angle_row(index, "min", data.get("min", -PI)))
			grid.add_child(_make_label("Angle Max"))
			grid.add_child(_make_angle_row(index, "max", data.get("max", PI)))

			var flags := HBoxContainer.new()
			flags.add_theme_constant_override("separation", 16)
			vbox.add_child(flags)
			flags.add_child(_make_flag_checkbox(index, "invert", "Invert range", data.get("invert", false)))
			flags.add_child(_make_flag_checkbox(index, "localspace", "Local space", data.get("localspace", true)))

	return panel


## Slider + spin box pair for an angle (degrees), synced. Easy to drag, precise to type.
func _make_angle_row(index: int, key: String, radians: float) -> HBoxContainer:
	var hb := HBoxContainer.new()
	hb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hb.add_theme_constant_override("separation", 6)

	var slider := HSlider.new()
	slider.min_value = -180.0
	slider.max_value = 180.0
	slider.step = 1.0
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slider.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	slider.custom_minimum_size = Vector2(110, 0)

	var spin := SpinBox.new()
	spin.min_value = -180.0
	spin.max_value = 180.0
	spin.step = 0.5
	spin.suffix = "°"
	spin.custom_minimum_size = Vector2(78, 0)

	var deg := rad_to_deg(radians)
	slider.set_value_no_signal(deg)
	spin.set_value_no_signal(deg)

	slider.value_changed.connect(func(v: float) -> void:
		spin.set_value_no_signal(v)
		_commit_joint_angle(index, key, v))
	spin.value_changed.connect(func(v: float) -> void:
		slider.set_value_no_signal(v)
		_commit_joint_angle(index, key, v))

	hb.add_child(slider)
	hb.add_child(spin)
	return hb


func _make_flag_checkbox(index: int, key: String, text: String, value: bool, rebuild: bool = false) -> CheckBox:
	var cb := CheckBox.new()
	cb.text = text
	cb.button_pressed = value
	cb.toggled.connect(_toggle_joint_field.bind(index, key, rebuild))
	return cb


# ─── NODE SELECTION (native scene-tree picker) ─────────────────────────────────

func _pick_joint_bone(index: int) -> void:
	if not is_instance_valid(_node):
		queue_free()
		return
	if not EditorInterface.has_method("popup_node_selector"):
		push_warning("EasyIK: native node selector unavailable in this Godot version.")
		return
	var current: Node = _node.get_node_or_null(_node.get_joint_bone_path(index))
	var valid_types: Array[StringName] = [&"Bone2D"]
	_picking = true  # Guard against the exclusive selector dialog closing this window.
	EditorInterface.popup_node_selector(_on_joint_bone_picked.bind(index), valid_types, current)


func _on_joint_bone_picked(picked: Variant, index: int) -> void:
	_picking = false
	_restore()  # The modal selector may have sent us to the back / requested close.
	var path := _to_node_path(picked)
	if path.is_empty():
		return  # Cancelled.
	var scene_root := EditorInterface.get_edited_scene_root()
	if scene_root == null:
		return
	var bone := scene_root.get_node_or_null(path)
	if not (bone is Bone2D):
		return
	var joints := _node.get_joints_copy()
	if index < joints.size():
		joints[index]["bone"] = _node.get_path_to(bone)
		_apply_joints(joints, "EasyIK: Assign Joint Bone")


## popup_node_selector may hand back either a NodePath or an Array — normalize both.
func _to_node_path(picked: Variant) -> NodePath:
	if picked is NodePath:
		return picked
	if picked is Array and not (picked as Array).is_empty():
		var first: Variant = (picked as Array)[0]
		if first is NodePath:
			return first
	return NodePath()


# ─── EDIT ACTIONS (through undo/redo) ──────────────────────────────────────────

func _add_joint() -> void:
	var joints := _node.get_joints_copy()
	joints.append(_node.new_joint_dict())
	_apply_joints(joints, "EasyIK: Add Joint")


func _remove_joint(index: int) -> void:
	var joints := _node.get_joints_copy()
	if index >= 0 and index < joints.size():
		joints.remove_at(index)
		_apply_joints(joints, "EasyIK: Remove Joint")


func _move_joint(index: int, delta: int) -> void:
	var other := index + delta
	var joints := _node.get_joints_copy()
	if index < 0 or index >= joints.size() or other < 0 or other >= joints.size():
		return
	var tmp: Variant = joints[index]
	joints[index] = joints[other]
	joints[other] = tmp
	_apply_joints(joints, "EasyIK: Reorder Joint")


func _toggle_joint_field(pressed: bool, index: int, key: String, rebuild: bool) -> void:
	var joints := _node.get_joints_copy()
	if index < joints.size():
		joints[index][key] = pressed
		_apply_joints(joints, "EasyIK: Edit Joint", UndoRedo.MERGE_ENDS, rebuild)


func _commit_joint_angle(index: int, key: String, degrees: float) -> void:
	var joints := _node.get_joints_copy()
	if index < joints.size():
		joints[index][key] = deg_to_rad(degrees)
		_apply_joints(joints, "EasyIK: Edit Joint Angle", UndoRedo.MERGE_ENDS, false)


func _on_iterations_changed(value: float) -> void:
	if not is_instance_valid(_node):
		queue_free()
		return
	var ur := _editor_plugin.get_undo_redo()
	ur.create_action("EasyIK: Set Iterations", UndoRedo.MERGE_ENDS, _node)
	ur.add_do_property(_node, "iterations", int(value))
	ur.add_undo_property(_node, "iterations", _node.iterations)
	ur.commit_action()


## Single mutation entry point: swaps the whole joint list with undo/redo, then refreshes.
func _apply_joints(new_joints: Array, action_name: String, merge: int = UndoRedo.MERGE_DISABLE, do_refresh: bool = true) -> void:
	if not is_instance_valid(_node):
		queue_free()
		return
	var old_joints := _node.get_joints_copy()
	var ur := _editor_plugin.get_undo_redo()
	ur.create_action(action_name, merge, _node)
	ur.add_do_method(_node, "set_joints", new_joints)
	ur.add_undo_method(_node, "set_joints", old_joints)
	ur.commit_action()
	if do_refresh:
		_refresh()
