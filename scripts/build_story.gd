extends SceneTree
func _initialize() -> void:
	var result = preload("res://scripts/story_compiler.gd").new().build()
	if result.ok: print(result.message)
	else: printerr(result.error)
	quit(0 if result.ok else 1)
