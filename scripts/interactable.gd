extends Area2D
@export var interactable_id: String = ""

func _ready() -> void:
	add_to_group("interactables")

func configure(definition: Dictionary) -> void:
	$Label.text = definition.label
	$Body.color = Color(definition.get("color", "#8996a5"))
	if definition.action == "collect_clue":
		$Body.scale = Vector2(0.65, 0.45)
		$Label.position.y = -66
