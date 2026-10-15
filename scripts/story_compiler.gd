extends RefCounted
## A single build path for the editor, launcher and tests. Never runs at export runtime.
const SOURCE = "res://story/main.ink"
const OUTPUT = "res://story/compiled/main.json"
const MANIFEST = "res://story/compiled/manifest.json"
var sources: Dictionary = {}
var knots: Array = []
var error: String = ""

func build(source: String = SOURCE, output: String = OUTPUT, manifest: String = MANIFEST) -> Dictionary:
	sources.clear()
	knots.clear()
	error = ""
	_collect(source)
	if not error.is_empty(): return _fail(error)
	var rules = _read_json("res://data/story_rules.json")
	var config = _read_json("res://data/demo_content.json")
	var characters = _read_json("res://data/characters.json")
	if rules.is_empty() or config.is_empty() or characters.is_empty(): return _fail("无法读取剧情规则或角色表")
	var refs = RegEx.new()
	refs.compile('game_(flag|condition|available|check|action)\\("([^"\\n]+)"\\)')
	var speaker = RegEx.new()
	speaker.compile('#\\s*speaker:([A-Za-z0-9_]+)')
	for path in sources:
		var text = FileAccess.get_file_as_string(path)
		var line_number = 0
		for line in text.split("\n"):
			line_number += 1
			if line.strip_edges().begins_with("//"): continue
			for found in refs.search_all(line):
				var kind = found.get_string(1)
				var id = found.get_string(2)
				var table = config.flags if kind == "flag" else rules[{"condition":"conditions", "available":"actions", "action":"actions", "check":"checks"}[kind]]
				if id not in table: return _fail("%s:%s 未注册的 %s：%s" % [path, line_number, kind, id])
			for found in speaker.search_all(line):
				if found.get_string(1) != "self" and found.get_string(1) not in characters:
					return _fail("%s:%s 未注册说话人：%s" % [path, line_number, found.get_string(1)])
			var stripped = line.strip_edges()
			if stripped.begins_with("EXTERNAL "):
				var external_name = stripped.trim_prefix("EXTERNAL ").get_slice("(", 0).strip_edges()
				if external_name not in ["game_flag", "game_condition", "game_available", "game_check", "game_action"]:
					return _fail("%s:%s 未支持的外部函数：%s" % [path, line_number, external_name])
			if stripped.begins_with("+") or stripped.begins_with("*"):
				if not "# id:" in line: return _fail("%s:%s 选项需要固定 # id:" % [path, line_number])
				if "game_check(" in line or "game_action(" in line: return _fail("%s:%s 检定与动作必须写在选择之后" % [path, line_number])
	for route_list in rules.dialogue_routes.values():
		for route in route_list:
			if route.entry not in knots: return _fail("入口不存在：" + route.entry)
	var compiler = OS.get_environment("INKLECATE")
	if compiler.is_empty(): compiler = ProjectSettings.globalize_path("res://tools/inklecate/inklecate.exe")
	if not FileAccess.file_exists(compiler): return _fail("缺少 Ink 编译器；请设置 INKLECATE 或使用工程附带的 Windows 编译器")
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(output.get_base_dir()))
	var temp = output + ".tmp"
	var messages: Array = []
	var code = OS.execute(compiler, PackedStringArray(["-o", ProjectSettings.globalize_path(temp), ProjectSettings.globalize_path(source)]), messages, true)
	var output_text = "\n".join(messages)
	if code != 0 or "ERROR:" in output_text or not FileAccess.file_exists(temp): return _fail("Ink 编译失败\n" + output_text)
	var compiled = _read_json(temp)
	if compiled.get("inkVersion", 0) != 21: return _fail("编译结果与固定的 Ink 运行时版本不匹配")
	var metadata = {"compiler":"inklecate 1.1.1", "story_id":config.story.id, "build_id":FileAccess.get_sha256(temp), "sources":sources, "knots":knots}
	var meta_file = FileAccess.open(manifest + ".tmp", FileAccess.WRITE)
	if meta_file == null: return _fail("无法写入剧情构建记录")
	meta_file.store_string(JSON.stringify(metadata, "\t"))
	meta_file.close()
	if DirAccess.rename_absolute(ProjectSettings.globalize_path(temp), ProjectSettings.globalize_path(output)) != OK: return _fail("无法替换编译后的剧本")
	if DirAccess.rename_absolute(ProjectSettings.globalize_path(manifest + ".tmp"), ProjectSettings.globalize_path(manifest)) != OK: return _fail("无法替换剧情构建记录")
	if source == SOURCE: _write_preview(rules, config, characters)
	return {"ok":true, "message":"Ink 编译成功：%s 个文件，%s 个入口" % [sources.size(), knots.size()]}

func _collect(path: String) -> void:
	if path in sources or not error.is_empty(): return
	if not FileAccess.file_exists(path):
		error = "找不到剧本：" + path
		return
	sources[path] = FileAccess.get_sha256(path)
	var knot_pattern = RegEx.new()
	knot_pattern.compile('^={2,}\\s*([A-Za-z0-9_]+)\\s*={0,}\\s*$')
	for line in FileAccess.get_file_as_string(path).split("\n"):
		var clean = line.strip_edges()
		if clean.begins_with("INCLUDE "):
			_collect(path.get_base_dir().path_join(clean.trim_prefix("INCLUDE ").strip_edges()).simplify_path())
		var found = knot_pattern.search(clean)
		if found != null: knots.append(found.get_string(1))

func _read_json(path: String) -> Dictionary:
	var value = JSON.parse_string(FileAccess.get_file_as_string(path)) if FileAccess.file_exists(path) else null
	return value if value is Dictionary else {}

func _fail(message: String) -> Dictionary:
	return {"ok":false, "error":message}

func _preview_condition(c: Dictionary, config: Dictionary) -> String:
	if c.is_empty(): return "true"
	for group in ["all", "any"]:
		if c.has(group):
			var parts: Array = []
			for child in c[group]: parts.append(_preview_condition(child, config))
			return "(" + (" && " if group == "all" else " || ").join(parts) + ")" if not parts.is_empty() else ("true" if group == "all" else "false")
	if c.has("not"): return "!(" + _preview_condition(c["not"], config) + ")"
	var value: String
	match c.kind:
		"phase": return 'mock_phase == "%s"' % c.id
		"task":
			value = _preview_condition(config.tasks[c.id].condition, config)
			return value if c.value == "complete" else "!(" + value + ")"
		"once_unused": value = "!mock_once_" + c.id
		_: value = "mock_" + c.kind + "_" + c.id
	var op = {"eq":"==", "gte":">=", "lte":"<="}[c.get("op", "eq")]
	return "(%s %s %s)" % [value, op, JSON.stringify(c.get("value", true))]

func _write_preview(rules: Dictionary, config: Dictionary, characters: Dictionary) -> void:
	var lines: Array = ["// GENERATED from data/*.json. Change the source configuration, then rebuild.", "// Inky-only game simulation. Production binds every EXTERNAL to real state."]
	for id in config.traits: lines.append("VAR mock_trait_%s = %s" % [id, int(config.initial_state.traits[id])])
	for id in characters:
		if characters[id].kind == "npc": lines.append("VAR mock_affinity_%s = %s" % [id, int(characters[id].initial_affinity)])
	for id in config.flags: lines.append("VAR mock_flag_%s = false" % id)
	for id in config.clues: lines.append("VAR mock_clue_%s = false" % id)
	lines.append('VAR mock_phase = "%s"' % config.initial_state.phase_id)
	lines.append('VAR mock_outcome = ""')
	var once: Array = []
	for action in rules.actions.values():
		if action.get("once_key", "") != "" and action.once_key not in once:
			once.append(action.once_key)
			lines.append("VAR mock_once_%s = false" % action.once_key)
	lines.append("\n=== function game_flag(id) ===")
	for id in config.flags: lines.append('{ id == "%s":\n    ~ return mock_flag_%s\n}' % [id, id])
	lines.append("~ return false")
	for kind in ["condition", "check"]:
		lines.append("\n=== function game_%s(id) ===" % kind)
		for id in rules[kind + "s"]: lines.append('{ id == "%s":\n    ~ return %s\n}' % [id, _preview_condition(rules[kind + "s"][id], config)])
		lines.append("~ return false")
	lines.append("\n=== function game_available(id) ===")
	for id in rules.actions:
		var action = rules.actions[id]
		var expression = _preview_condition(action.get("condition", {}), config)
		if not action.get("once_key", "").is_empty():
			expression = ("" if expression == "true" else expression + " && ") + "!mock_once_" + action.once_key
		lines.append('{ id == "%s":\n    ~ return %s\n}' % [id, expression])
	lines.append("~ return false")
	lines.append("\n=== function game_action(id) ===\n{not game_available(id):\n    ~ return false\n}")
	for id in rules.actions:
		lines.append('{id == "%s":' % id)
		var action = rules.actions[id]
		for effect in action.get("effects", []):
			match effect.type:
				"add_trait": lines.append("    ~ mock_trait_%s += %s" % [effect.id, int(effect.amount)])
				"add_affinity": lines.append("    ~ mock_affinity_%s += %s" % [effect.id, int(effect.amount)])
				"set_flag": lines.append("    ~ mock_flag_%s = %s" % [effect.id, str(effect.value)])
				"add_clue": lines.append("    ~ mock_clue_%s = true" % effect.id)
				"set_phase": lines.append('    ~ mock_phase = "%s"' % effect.id)
				"select_outcome": lines.append('    ~ mock_outcome = "%s"' % effect.id)
		if not action.get("once_key", "").is_empty(): lines.append("    ~ mock_once_%s = true" % action.once_key)
		lines.append("    ~ return true\n}")
	lines.append("~ return false")
	var file = FileAccess.open("res://story/preview/fallbacks.ink", FileAccess.WRITE)
	if file != null: file.store_string("\n".join(lines) + "\n")

	var preview: Array = ["// GENERATED entry: open this file in Inky.", "-> preview_menu"]
	for path in sources:
		if path != SOURCE: preview.append("INCLUDE ../" + path.trim_prefix("res://story/"))
	preview.append("INCLUDE fallbacks.ink")
	preview.append("INCLUDE menu.ink")
	var entry = FileAccess.open("res://story/preview/main.ink", FileAccess.WRITE)
	if entry != null: entry.store_string("\n".join(preview) + "\n")
