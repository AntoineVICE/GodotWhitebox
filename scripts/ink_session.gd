extends RefCounted
## Owns an Ink execution object, never authoritative game progress.
const Runtime = preload("res://addons/inkgd/ink_runtime.gd")
const Story = preload("res://addons/inkgd/runtime/ink_story.gd")
var story
var runtime: Node
var source: String
var errors: Array[String] = []
var bridge: Object

func setup(compiled: String, host: Object) -> void:
	source = compiled
	bridge = host
	var root = Engine.get_main_loop().root
	runtime = root.get_node_or_null("__InkRuntime")
	if runtime == null:
		runtime = Runtime.new()
		runtime.stop_execution_on_exception = false
		runtime.stop_execution_on_error = false
		root.add_child(runtime) # Runtime service node; not an Autoload or a second game state.
	_new_story()

func _new_story() -> void:
	story = Story.new(source, runtime)
	story.on_error.connect(_on_error)
	story.allow_external_function_fallbacks = false
	for name in ["flag", "condition", "available", "check", "action"]:
		story.bind_external_function("game_" + name, bridge, "_ink_" + name, name in ["flag", "condition", "available"])
	story.state.story_seed = 20260924

func restore(serialized: String) -> bool:
	errors.clear()
	runtime.clear_raised_exceptions()
	story.reset_errors()
	if serialized.is_empty():
		story.reset_state()
		story.state.story_seed = 20260924
	else: story.state.load_json(serialized)
	return errors.is_empty() and not runtime.has_raised_exceptions

func serialize() -> String:
	return story.state.to_json()

func _on_error(message: String, _type: int) -> void:
	errors.append(message)
