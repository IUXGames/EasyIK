@tool
extends Button

## Inspector button that opens the EasyIK "Manage Bone Chain" window for one manager.
## There is a single shared window (any number of managers can exist); clicking a button
## rebinds that window to the button's manager, so it always shows the one you clicked.

const IKChainManagerWindow := preload("ik_chain_manager_window.gd")
const WINDOW_NAME := "EasyIKChainWindow"

var _node: EasyIKManager
var _editor_plugin: EditorPlugin


func setup(node: EasyIKManager, plugin: EditorPlugin) -> void:
	_node = node
	_editor_plugin = plugin
	text = "  Manage Bone Chain"
	tooltip_text = "Edit the bone chain and its per-joint angle limits."
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var theme := EditorInterface.get_editor_theme()
	if theme != null and theme.has_icon("Bone2D", "EditorIcons"):
		icon = theme.get_icon("Bone2D", "EditorIcons")
	pressed.connect(_on_pressed)


func _on_pressed() -> void:
	if not is_instance_valid(_node):
		return
	var base := EditorInterface.get_base_control()
	var existing := base.get_node_or_null(NodePath(WINDOW_NAME))
	if existing != null and is_instance_valid(existing):
		existing.rebind(_node)  # Reuse the one window; point it at this manager.
		return
	var window := IKChainManagerWindow.new()
	window.name = WINDOW_NAME
	base.add_child(window)
	window.setup(_node, _editor_plugin)
