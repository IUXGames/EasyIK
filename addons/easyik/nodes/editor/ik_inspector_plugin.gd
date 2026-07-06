@tool
extends EditorInspectorPlugin

## Replaces the `manage_chain` anchor of an EasyIKManager with a single "Manage Bone Chain"
## button that opens the chain manager window.

const IKChainButton := preload("ik_chain_button.gd")

var _editor_plugin: EditorPlugin


func _init(plugin: EditorPlugin) -> void:
	_editor_plugin = plugin


func _can_handle(object: Object) -> bool:
	return object is EasyIKManager


func _parse_property(object: Object, _type: Variant.Type, name: String,
		_hint_type: PropertyHint, _hint_string: String,
		_usage_flags: int, _wide: bool) -> bool:
	# Replace the `manage_chain` anchor with the "Manage Bone Chain" button.
	if name == "manage_chain":
		var button := IKChainButton.new()
		button.setup(object as EasyIKManager, _editor_plugin)
		add_custom_control(button)
		return true
	return false
