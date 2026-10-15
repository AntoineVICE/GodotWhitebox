@tool
extends EditorPlugin
const Compiler = preload("res://scripts/story_compiler.gd")
func _enter_tree() -> void:
	add_tool_menu_item("编译 Ink 剧本", _compile)
func _exit_tree() -> void:
	remove_tool_menu_item("编译 Ink 剧本")
func _build() -> bool:
	return _compile()
func _compile() -> bool:
	var result = Compiler.new().build()
	if not result.ok:
		push_error(result.error)
		return false
	print(result.message)
	get_editor_interface().get_resource_filesystem().scan()
	return true
