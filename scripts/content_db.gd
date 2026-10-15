extends RefCounted
## Static world/character/rule data. Story text and branches live in real Ink.
const TRAIT_IDS = ["innovation", "tradition", "piety", "secularity", "cruelty", "mercy"]
var data: Dictionary = {}
var errors: Array[String] = []
var once_keys: Array = []
var manifest: Dictionary = {}
var compiled_json: String = ""

func load_content(path: String = "res://data/demo_content.json") -> Dictionary:
	errors.clear()
	data = _read_dictionary(path)
	if data.is_empty(): return {"ok":false, "error":"无法读取内容配置：" + path}
	data.characters = _read_dictionary(data.get("characters_file", ""))
	var rules = _read_dictionary(data.get("rules_file", ""))
	for key in ["conditions", "checks", "actions", "dialogue_routes"]:
		data[key] = rules.get(key, {})
	manifest = _read_dictionary(data.story.manifest)
	if not FileAccess.file_exists(data.story.compiled): return {"ok":false, "error":"缺少编译后的 Ink，请先编译剧本"}
	compiled_json = FileAccess.get_file_as_string(data.story.compiled)
	if manifest.get("build_id", "") != FileAccess.get_sha256(data.story.compiled):
		return {"ok":false, "error":"Ink 剧本与构建记录不一致，请重新编译"}
	for source in manifest.get("sources", {}):
		if not FileAccess.file_exists(source) or FileAccess.get_sha256(source) != manifest.sources[source]:
			return {"ok":false, "error":"Ink 源文件已变化，请使用「项目 → 工具 → 编译 Ink 剧本」后运行：" + source}
	assemble_characters()
	data.initial_state.narrative.build_id = manifest.get("build_id", "")
	var result = validate_content()
	if result.ok:
		data.initial_state.schema_version = int(data.initial_state.schema_version)
		for table in ["traits", "affinities"]:
			for id in data.initial_state[table]: data.initial_state[table][id] = int(data.initial_state[table][id])
	return result

func _read_dictionary(path: String) -> Dictionary:
	if not FileAccess.file_exists(path): return {}
	var parsed = JSON.new()
	if parsed.parse(FileAccess.get_file_as_string(path)) != OK or not parsed.data is Dictionary: return {}
	return parsed.data

func assemble_characters() -> void:
	data.npcs = {}
	data.initial_state.affinities = {}
	for id in data.characters:
		var character = data.characters[id]
		if not character is Dictionary or character.get("kind") != "npc": continue
		data.npcs[id] = character
		var initial = character.get("initial_affinity", 0)
		data.initial_state.affinities[id] = int(initial) if is_integer(initial) else initial
		data.interactables[id] = {"label":character.get("label", id), "action":"dialogue", "target_id":character.get("dialogue_id", ""), "color":character.get("color", "#859aaf")}

static func is_integer(value: Variant) -> bool:
	return value is int or (value is float and is_finite(value) and value == floor(value) and abs(value) <= 9007199254740991.0)

func validate_content() -> Dictionary:
	errors.clear()
	once_keys.clear()
	for key in ["traits", "initial_state", "characters", "npcs", "rooms", "interactables", "conditions", "checks", "actions", "dialogue_routes", "clues", "tasks", "phases", "outcomes", "flags", "ui"]:
		if not data.get(key) is Dictionary: errors.append("缺少字典：" + key)
	if not errors.is_empty(): return _validation_result()
	if data.get("test_only") != true or not data.get("content_version") is String: errors.append("需要 test_only 和 content_version")
	if data.traits.size() != 6: errors.append("必须恰好包含六维")
	for id in TRAIT_IDS:
		if not data.traits.get(id) is String: errors.append("缺少属性 " + id)
	for action in data.actions.values():
		if not action is Dictionary:
			errors.append("action 必须为字典")
			continue
		var once = action.get("once_key", "")
		if not once is String: errors.append("once_key 必须为字符串")
		elif not once.is_empty() and once not in once_keys: once_keys.append(once)
	for id in data.characters:
		var character = data.characters[id]
		if not character is Dictionary or not character.get("label") is String or character.get("kind") not in ["npc", "player", "narrator"]:
			errors.append("角色定义无效：" + id)
			continue
		if character.get("portrait", "") != "" and not ResourceLoader.exists(character.portrait): errors.append("头像资源不存在：" + id)
		if character.kind == "npc":
			if not is_integer(character.get("initial_affinity")): errors.append("角色初始好感必须为整数：" + id)
			if character.get("dialogue_id") not in data.dialogue_routes: errors.append("角色对话入口无效：" + id)
	for id in data.rooms:
		var room = data.rooms[id]
		if not room is Dictionary or not room.get("scene") is String or not room.get("spawns") is Array:
			errors.append("房间格式无效：" + id)
			continue
		if not ResourceLoader.exists(room.scene, "PackedScene"): errors.append("场景不存在：" + room.scene)
		if room.get("default_spawn") not in room.spawns: errors.append("默认出生点无效：" + id)
	for phase in data.phases.values():
		if not phase is Dictionary or not phase.get("npcs") is Dictionary:
			errors.append("阶段缺少 npcs")
			continue
		for id in phase.npcs:
			var location = phase.npcs[id]
			if id not in data.npcs or location.get("room_id") not in data.rooms or not location.get("marker_id") is String: errors.append("NPC 阶段位置无效：" + id)
	for id in data.interactables:
		var item = data.interactables[id]
		if not item is Dictionary or not item.get("label") is String:
			errors.append("交互定义无效：" + id)
			continue
		_record(validate_condition(item.get("available_if", {})), id)
		_record(validate_condition(item.get("visible_if", {})), id)
		var target = item.get("target_id", "")
		match item.get("action"):
			"dialogue":
				if target not in data.dialogue_routes: errors.append("未知对话路由：" + id)
			"collect_clue":
				if target not in data.clues: errors.append("未知线索：" + id)
			"set_phase":
				if target not in data.phases: errors.append("未知阶段：" + id)
			"change_room":
				if target not in data.rooms or item.get("spawn_id") not in data.rooms.get(target, {}).get("spawns", []): errors.append("门目标无效：" + id)
			_: errors.append("未知交互动作：" + id)
	for id in data.conditions: _record(validate_condition(data.conditions[id], true), id)
	for id in data.checks:
		_record(validate_condition(data.checks[id]), id)
		if data.checks[id].get("kind") != "trait": errors.append("检定必须为单个属性阈值：" + id)
	for id in data.actions:
		var action = data.actions[id]
		if not action is Dictionary: continue
		_record(validate_condition(action.get("condition", {}), true), id)
		_record(validate_effects(action.get("effects", [])), id)
	for id in data.dialogue_routes:
		var routes = data.dialogue_routes[id]
		if not routes is Array or routes.is_empty():
			errors.append("对话路由需要有序数组：" + id)
			continue
		for route in routes:
			if not route is Dictionary or route.get("entry") not in manifest.get("knots", []):
				errors.append("Ink 入口不存在：" + id)
				continue
			_record(validate_condition(route.get("condition", {}), true), id)
		if not routes.back().get("condition", {}).is_empty(): errors.append("路由最后需要无条件后备入口：" + id)
	for table in ["tasks", "outcomes"]:
		for entry in data[table].values(): _record(validate_condition(entry.get("condition", {})), table)
	for list_id in ["objectives", "status_entries"]:
		if not data.ui.get(list_id, []) is Array:
			errors.append(list_id + " 必须为数组")
			continue
		for entry in data.ui.get(list_id, []):
			_record(validate_passage(entry), list_id)
			if entry is Dictionary: _record(validate_condition(entry.get("condition")), list_id)
	_validate_initial()
	if errors.is_empty(): _validate_scene_references()
	return _validation_result()

func route_entry(dialogue_id: String, snapshot: Dictionary, evaluator) -> String:
	for route in data.dialogue_routes.get(dialogue_id, []):
		if evaluator.evaluate(route.get("condition", {}), snapshot).ok: return route.entry
	return ""

func validate_passage(passage: Variant) -> String:
	if not passage is Dictionary or not passage.get("text") is String: return "段落需要 text 字符串"
	return ""

func _validate_initial() -> void:
	var initial = data.initial_state
	if not is_integer(initial.get("schema_version")) or initial.get("schema_version") != 2: errors.append("初始 schema_version 无效")
	if initial.get("content_version") != data.content_version: errors.append("初始内容版本不匹配")
	for table in ["traits", "affinities"]:
		if not initial.get(table) is Dictionary:
			errors.append("初始 " + table + " 必须为字典")
			continue
		var known = data.traits if table == "traits" else data.npcs
		if initial[table].size() != known.size(): errors.append("初始 " + table + " ID 数量无效")
		for id in initial[table]:
			if id not in known or not is_integer(initial[table][id]): errors.append("初始整数 / ID 无效：" + str(id))

func _validate_scene_references() -> void:
	for room_id in data.rooms:
		var packed = load(data.rooms[room_id].scene)
		if not packed is PackedScene:
			errors.append("房间必须为 PackedScene: " + room_id)
			continue
		var room = packed.instantiate()
		for node_name in ["Markers", "Actors", "Objects", "Boundaries"]:
			if not room.has_node(node_name): errors.append("房间缺少节点: " + node_name)
		for spawn in data.rooms[room_id].spawns:
			if not spawn is String or not room.get_node_or_null("Markers/" + str(spawn)) is Marker2D: errors.append("出生点 Marker 无效: " + str(spawn))
		for phase in data.phases.values():
			for location in phase.npcs.values():
				if location.room_id == room_id and not room.get_node_or_null("Markers/" + location.marker_id) is Marker2D:
					errors.append("NPC Marker 无效: " + location.marker_id)
		if room.has_node("Objects"):
			for object in room.get_node("Objects").get_children():
				if object.get("interactable_id") not in data.interactables: errors.append("场景物体 ID 无效")
		room.free()

func validate_condition(c: Variant, forbid_traits: bool = false) -> String:
	if not c is Dictionary: return "条件必须为字典"
	if c.is_empty(): return ""
	for group in ["all", "any", "not"]:
		if c.has(group):
			if c.size() != 1: return "组合条件只能有一个运算符"
			var children = [c[group]] if group == "not" else c[group]
			if not children is Array: return "组合条件需要数组"
			for child in children:
				var error = validate_condition(child, forbid_traits)
				if not error.is_empty(): return error
			return ""
	var kind = c.get("kind", "")
	var table = {"trait": "traits", "affinity": "npcs", "flag": "flags", "clue": "clues", "phase": "phases", "task": "tasks"}
	if kind == "once_unused":
		if c.get("id") not in once_keys: return "未知 once_key"
	elif kind not in table: return "未知条件类型: " + str(kind)
	elif c.get("id") not in data[table[kind]]: return "条件引用无效: " + str(c.get("id"))
	if forbid_traits and kind == "trait": return "visible_if 禁止属性门槛（含嵌套）"
	if c.get("op", "eq") not in ["gte", "lte", "eq"]: return "比较运算符无效"
	if kind in ["trait", "affinity"]:
		if not is_integer(c.get("value")): return "阈值须为整数"
	else:
		if c.get("op", "eq") != "eq": return "非数值只支持 eq"
		if kind == "task" and c.get("value") not in ["active", "complete"]: return "任务状态无效"
		if kind in ["flag", "clue", "once_unused"] and not c.get("value", true) is bool: return "条件值须为布尔值"
	return ""

func validate_effects(effects: Variant) -> String:
	if not effects is Array: return "effects 必须为数组"
	var tables = {"add_trait": "traits", "add_affinity": "npcs", "set_flag": "flags", "add_clue": "clues", "set_phase": "phases", "select_outcome": "outcomes"}
	for effect in effects:
		if not effect is Dictionary or effect.get("type") not in tables: return "未知效果"
		if effect.get("id") not in data[tables[effect.type]]: return "效果引用无效: " + str(effect.get("id"))
		if effect.type in ["add_trait", "add_affinity"] and not is_integer(effect.get("amount")): return "amount 须为整数"
		if effect.type == "set_flag" and not effect.get("value") is bool: return "flag 须为布尔值"
	return ""

func _record(error: String, context: String) -> void:
	if not error.is_empty(): errors.append(context + ": " + error)

func _validation_result() -> Dictionary:
	return {"ok": errors.is_empty(), "error": "\n".join(errors)}
