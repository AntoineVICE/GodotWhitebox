extends RefCounted
## Persistence validates before replacing anything. Test paths are injectable.
const DB = preload("res://scripts/content_db.gd")
const Conditions = preload("res://scripts/condition_evaluator.gd")
var path: String

func _init(save_path: String = "user://whitebox_save.json") -> void:
	path = save_path

func save(snapshot: Dictionary) -> Dictionary:
	var serialized = JSON.stringify(snapshot, "\t")
	var temporary = path + ".tmp"
	var file = FileAccess.open(temporary, FileAccess.WRITE)
	if file == null: return _fail("无法打开存档临时文件: %s" % FileAccess.get_open_error())
	file.store_string(serialized)
	file.flush()
	var error = file.get_error()
	file.close()
	if error != OK:
		return _fail("存档写入失败: %s（旧存档保留）" % error)
	var replaced = DirAccess.rename_absolute(ProjectSettings.globalize_path(temporary), ProjectSettings.globalize_path(path))
	if replaced != OK: return _fail("无法替换存档: %s（旧存档保留）" % replaced)
	return {"ok": true}

func load_validated(content) -> Dictionary:
	var file = FileAccess.open(path, FileAccess.READ)
	if file == null: return _fail("无法读取存档: %s" % FileAccess.get_open_error())
	var json = JSON.new()
	if json.parse(file.get_as_text()) != OK:
		return _fail("存档 JSON 损坏: 第 %s 行 %s" % [json.get_error_line(), json.get_error_message()])
	return validate_snapshot(json.data, content)

func validate_snapshot(raw: Variant, content) -> Dictionary:
	if not raw is Dictionary: return _fail("存档根节点必须为字典")
	var required = ["schema_version", "content_version", "room_id", "spawn_id", "phase_id", "traits", "affinities", "flags", "clues", "task_states", "consumed_once_keys", "selected_outcome", "narrative"]
	for key in required:
		if not raw.has(key): return _fail("存档缺少字段: " + key)
	for key in raw:
		if key not in required: return _fail("存档未知字段: " + str(key))
	if not DB.is_integer(raw.schema_version) or raw.schema_version != 2: return _fail("schema_version 不兼容")
	if not raw.content_version is String or raw.content_version != content.data.content_version: return _fail("存档剧情版本不兼容，请从当前版本重新开始（旧存档保留）")
	for key in ["room_id", "spawn_id", "phase_id"]:
		if not raw[key] is String: return _fail(key + " 必须为字符串")
	if raw.room_id not in content.data.rooms: return _fail("未知房间")
	if raw.spawn_id not in content.data.rooms[raw.room_id].spawns: return _fail("未知出生点")
	if raw.phase_id not in content.data.phases: return _fail("未知阶段")
	var next = raw.duplicate(true)
	next.schema_version = int(raw.schema_version)
	for table in ["traits", "affinities"]:
		if not raw[table] is Dictionary: return _fail(table + " 必须为字典")
		var known = content.data.traits if table == "traits" else content.data.npcs
		if raw[table].size() != known.size(): return _fail(table + " ID 数量不匹配")
		for id in raw[table]:
			if id not in known: return _fail(table + " 未知 ID: " + str(id))
			if not DB.is_integer(raw[table][id]): return _fail(table + " 数值须为有限整数")
			next[table][id] = int(raw[table][id])
	if not raw.flags is Dictionary: return _fail("flags 必须为字典")
	for id in raw.flags:
		if id not in content.data.flags or not raw.flags[id] is bool: return _fail("flag ID 或布尔值无效")
	for table in ["clues", "consumed_once_keys"]:
		if not raw[table] is Array: return _fail(table + " 必须为数组")
		var known = content.data.clues.keys() if table == "clues" else content.once_keys
		next[table] = []
		for id in raw[table]:
			if not id is String or id not in known: return _fail(table + " 未知 ID")
			if id not in next[table]: next[table].append(id)
	if not raw.task_states is Dictionary or raw.task_states.size() != content.data.tasks.size(): return _fail("task_states 格式无效")
	for id in raw.task_states:
		if id not in content.data.tasks or raw.task_states[id] not in ["active", "complete"]: return _fail("任务 ID 或状态无效")
	var evaluator = Conditions.new()
	for id in content.data.tasks:
		var expected = "complete" if evaluator.evaluate(content.data.tasks[id].condition, next).ok else "active"
		if next.task_states[id] != expected: return _fail("任务状态与条件不一致: " + id)
	if raw.selected_outcome != null:
		if not raw.selected_outcome is String or raw.selected_outcome not in content.data.outcomes: return _fail("未知结果")
		if not evaluator.evaluate(content.data.outcomes[raw.selected_outcome].condition, next).ok: return _fail("结果条件不成立")
	var narrative_error = validate_narrative(raw.narrative, content)
	if not narrative_error.is_empty(): return _fail(narrative_error)
	return {"ok": true, "state": next}

func _fail(message: String) -> Dictionary:
	return {"ok": false, "error": message}

func validate_narrative(value: Variant, content) -> String:
	if not value is Dictionary: return "存档缺少 Ink 进度"
	for key in ["story_id", "build_id", "ink_state", "state_hash", "result_text"]:
		if not value.get(key) is String: return "Ink 字段无效：" + key
	if value.story_id != content.data.story.id or value.build_id != content.manifest.build_id:
		return "剧本已经更新，此存档属于另一版 Ink 剧本；请重新开始（旧文件保留）"
	if value.ink_state.is_empty():
		return "" if value.state_hash.is_empty() and value.result_text.is_empty() else "空 Ink 进度不应附带结果"
	if value.state_hash != value.ink_state.sha256_text(): return "Ink 存档校验和不匹配"
	var parsed = JSON.new()
	if parsed.parse(value.ink_state) != OK or not parsed.data is Dictionary: return "Ink 存档 JSON 损坏"
	var ink = parsed.data
	for key in ["inkSaveVersion", "inkFormatVersion", "turnIdx", "storySeed", "previousRandom"]:
		if not DB.is_integer(ink.get(key)): return "Ink 存档整数无效：" + key
	if ink.inkSaveVersion != 10 or ink.inkFormatVersion != 21: return "Ink 存档格式不兼容"
	for key in ["variablesState", "visitCounts", "turnIndices", "flows"]:
		if not ink.get(key) is Dictionary: return "Ink 存档结构无效：" + key
	if not ink.get("evalStack") is Array or ink.flows.size() != 1 or not ink.flows.has("DEFAULT_FLOW"): return "Ink 流程结构无效"
	for flow in ink.flows.values():
		if not flow is Dictionary or not flow.get("callstack") is Dictionary: return "Ink 调用栈无效"
		if not flow.get("outputStream") is Array or not flow.get("currentChoices") is Array: return "Ink 输出结构无效"
		if not flow.callstack.get("threads") is Array or flow.callstack.threads.is_empty(): return "Ink 线程结构无效"
		if not DB.is_integer(flow.callstack.get("threadCounter")): return "Ink 线程计数无效"
		for thread in flow.callstack.threads:
			if not thread is Dictionary or not thread.get("callstack") is Array or thread.callstack.is_empty(): return "Ink 栈帧无效"
			if not DB.is_integer(thread.get("threadIndex")): return "Ink 线程 ID 无效"
			for frame in thread.callstack:
				if not frame is Dictionary or not DB.is_integer(frame.get("type")) or not frame.get("exp") is bool: return "Ink 栈帧格式无效"
	return ""
