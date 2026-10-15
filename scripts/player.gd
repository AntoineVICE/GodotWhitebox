extends CharacterBody2D
signal target_changed(id: String)
signal request_interaction(id: String)
@export var speed: float = 290.0
var locked: bool = false
var current_target: String = ""
var candidates: Array = []

func _physics_process(_delta: float) -> void:
	velocity = Vector2.ZERO if locked else Vector2(Input.get_axis("move_left", "move_right") * speed, 0)
	move_and_slide()
	refresh_target()

func refresh_target() -> void:
	candidates.clear()
	if not locked:
		for area in $InteractionArea.get_overlapping_areas():
			if is_instance_valid(area) and not area.is_queued_for_deletion() and area.is_in_group("interactables") and area.is_visible_in_tree():
				candidates.append(area)
	candidates.sort_custom(func(a, b):
		var da = global_position.distance_squared_to(a.global_position)
		var db = global_position.distance_squared_to(b.global_position)
		return a.interactable_id < b.interactable_id if is_equal_approx(da, db) else da < db)
	var selected = "" if candidates.is_empty() else str(candidates[0].interactable_id)
	if selected != current_target:
		current_target = selected
		target_changed.emit(current_target)

func clear_target() -> void:
	candidates.clear()
	current_target = ""
	target_changed.emit("")

func _unhandled_input(event: InputEvent) -> void:
	if not locked and event.is_action_pressed("interact") and not event.is_echo():
		refresh_target()
		if not current_target.is_empty(): request_interaction.emit(current_target)
		get_viewport().set_input_as_handled()
