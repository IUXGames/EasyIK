@tool
extends EditorPlugin

## EasyIK — editor plugin entry point.
## The runtime node (EasyIKManager) self-registers via its `class_name` + `@icon()`.
## Here we register the inspector plugin that swaps the chain fields for the
## "Manage Bone Chain" button/window.

var _inspector_plugin: EditorInspectorPlugin


func _enter_tree() -> void:
	var plugin_script := preload("nodes/editor/ik_inspector_plugin.gd")
	_inspector_plugin = plugin_script.new(self)
	add_inspector_plugin(_inspector_plugin)


func _exit_tree() -> void:
	if _inspector_plugin != null:
		remove_inspector_plugin(_inspector_plugin)
		_inspector_plugin = null


func _enable_plugin() -> void:
	print("EasyIK plugin enabled.")


func _disable_plugin() -> void:
	print("EasyIK plugin disabled.")
