extends Node
## The only Autoload. No node references, static content, UI or save logic.
signal state_changed(snapshot: Dictionary)
var _state: Dictionary = {}
var revision: int = 0

func snapshot() -> Dictionary:
	return _state.duplicate(true)

func replace_state(validated_state: Dictionary) -> void:
	_state = validated_state.duplicate(true)
	revision += 1
	state_changed.emit(snapshot())

func reset(initial_state: Dictionary) -> void:
	replace_state(initial_state)
