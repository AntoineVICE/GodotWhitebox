extends Node2D
const Actor = preload("res://scenes/interactable.tscn")
var content
var conditions
var room
var loaded_room: String = ""
var loaded_phase: String = ""
var transitioning: bool = false

func setup(db, evaluator) -> void:
	content = db
	conditions = evaluator

func load_room(room_id: String, spawn_id: String) -> bool:
	if room_id not in content.data.rooms: return false
	var packed = load(content.data.rooms[room_id].scene)
	if not packed is PackedScene: return false
	var next_room = packed.instantiate()
	var spawn = next_room.get_node_or_null("Markers/" + spawn_id)
	if spawn == null:
		next_room.free()
		return false
	transitioning = true
	$Player.clear_target()
	if is_instance_valid(room):
		$RoomRoot.remove_child(room)
		room.queue_free()
	room = next_room
	$RoomRoot.add_child(room)
	loaded_room = room_id
	loaded_phase = ""
	$Player.position = spawn.position
	$Player.velocity = Vector2.ZERO
	for object in room.get_node("Objects").get_children():
		object.configure(content.data.interactables[object.interactable_id])
	transitioning = false
	return true

func sync(snapshot: Dictionary, force_reload: bool = false) -> bool:
	if loaded_room != snapshot.room_id or force_reload:
		if not load_room(snapshot.room_id, snapshot.spawn_id): return false
	if loaded_phase != snapshot.phase_id: refresh_actors(snapshot.phase_id)
	for object in room.get_node("Objects").get_children():
		var definition = content.data.interactables[object.interactable_id]
		object.visible = conditions.evaluate(definition.get("visible_if", {}), snapshot).ok
	$Player.clear_target()
	return true

func refresh_actors(phase_id: String) -> void:
	$Player.clear_target()
	var actors = room.get_node("Actors")
	for actor in actors.get_children():
		actors.remove_child(actor)
		actor.queue_free()
	for id in content.data.phases[phase_id].npcs:
		var location = content.data.phases[phase_id].npcs[id]
		if location.room_id != loaded_room: continue
		var marker = room.get_node_or_null("Markers/" + location.marker_id)
		if marker == null:
			push_error("Missing NPC marker: " + location.marker_id)
			continue
		var actor = Actor.instantiate()
		actor.interactable_id = id
		actor.name = id
		actor.position = marker.position
		actors.add_child(actor)
		actor.configure(content.data.interactables[id])
	loaded_phase = phase_id

func has_interactable(id: String) -> bool:
	if not is_instance_valid(room): return false
	for parent in [room.get_node("Actors"), room.get_node("Objects")]:
		for object in parent.get_children():
			if object.interactable_id == id and object.visible: return true
	return false
