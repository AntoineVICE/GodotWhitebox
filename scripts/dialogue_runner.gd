extends Node
## Ink adapter: text/branching in Ink, rule execution on one staged GameState copy.
const Session = preload("res://scripts/ink_session.gd")
signal view_changed(view: Dictionary)
signal closed
signal diagnostic(message: String)
signal checked(details: Dictionary)
var content
var conditions
var effects
var state
var commit: Callable
var session = Session.new()
var active: bool = false
var busy: bool = false
var dialogue_id: String = ""
var node_id: String = ""
var context_id: String = ""
var token: int = 0
var displayed_text: String = ""
var _view: Dictionary = {}
var _before: Dictionary = {}
var _staged: Dictionary = {}
var _allow_actions: bool = false
var _turn_error: String = ""
var _checks: Array = []

func setup(db, evaluator, executor, state_node, commit_callback: Callable) -> void:
	content = db
	conditions = evaluator
	effects = executor
	state = state_node
	commit = commit_callback
	session.setup(db.compiled_json, self)

func start(id: String, speaker_context: String = "") -> bool:
	if busy or active or id not in content.data.dialogue_routes: return false
	dialogue_id = id
	context_id = speaker_context
	if context_id.is_empty():
		for npc in content.data.npcs:
			if content.data.npcs[npc].dialogue_id == id:
				context_id = npc
				break
	node_id = content.route_entry(id, state.snapshot(), conditions)
	if node_id.is_empty(): return false
	if not _begin_turn(false): return false
	session.story.choose_path_string(node_id)
	return _finish_turn("开始交谈 " + id)

func current_view() -> Dictionary:
	return _view.duplicate(true) if active else {}

func choose(choice_id: String, expected_token: int = -1) -> bool:
	if not active or busy or (expected_token != -1 and expected_token != token): return false
	var index = -1
	for choice in _view.choices:
		if choice.id == choice_id and not choice.disabled: index = choice.index
	if index < 0: return false
	if not _begin_turn(true): return false
	session.story.choose_choice_index(index)
	return _finish_turn("选择 " + choice_id)

func _begin_turn(allow_actions: bool) -> bool:
	busy = true
	_before = state.snapshot()
	_staged = _before.duplicate(true)
	_allow_actions = allow_actions
	_turn_error = ""
	_checks.clear()
	if not session.restore(_before.narrative.ink_state):
		busy = false
		diagnostic.emit("无法恢复 Ink 进度")
		return false
	return true

func _finish_turn(reason: String) -> bool:
	var lines: Array = []
	var speaker = "narrator"
	var steps = 0
	while session.story.can_continue and _turn_error.is_empty():
		steps += 1
		if steps > 200:
			_turn_error = "一次交谈输出过长，请在 Ink 中增加选项或结束段落"
			break
		var text: String = session.story.continue_story().strip_edges()
		for tag in session.story.current_tags:
			if str(tag).begins_with("speaker:"): speaker = str(tag).trim_prefix("speaker:").strip_edges()
		if speaker == "self": speaker = context_id
		if speaker not in content.data.characters:
			_turn_error = "未登记的说话人：" + speaker
			break
		if not text.is_empty(): lines.append({"speaker_id":speaker, "text":text})
		if not session.errors.is_empty() or session.runtime.has_raised_exceptions:
			_turn_error = "Ink 运行错误：" + "\n".join(session.errors)
	var choices: Array = []
	var ids: Array = []
	for choice in session.story.current_choices:
		var id = ""
		if choice.tags != null:
			for tag in choice.tags:
				if str(tag).begins_with("id:"): id = str(tag).trim_prefix("id:").strip_edges()
		if id.is_empty() or id in ids:
			_turn_error = "Ink 选项缺少固定 ID 或当前菜单 ID 重复"
			break
		ids.append(id)
		choices.append({"id":id, "index":choice.index, "text":choice.text.strip_edges(), "disabled":false, "reason":""})
	if not _turn_error.is_empty(): return _rollback()
	var participants: Array = []
	var text_lines: Array = []
	for line in lines:
		var label: String = content.data.characters[line.speaker_id].label
		if line.speaker_id != "narrator" and label not in participants: participants.append(label)
		text_lines.append(line.text if line.speaker_id == "narrator" else label + "：" + line.text)
	displayed_text = "\n".join(text_lines)
	_staged.narrative.ink_state = session.serialize()
	_staged.narrative.state_hash = _staged.narrative.ink_state.sha256_text()
	if _staged.selected_outcome != null: _staged.narrative.result_text = displayed_text
	if not commit.call(_staged, reason):
		_turn_error = "剧情提交失败，世界与 Ink 进度均已回退"
		return _rollback()
	busy = false
	for detail in _checks: checked.emit(detail)
	if choices.is_empty():
		close()
	else:
		active = true
		token += 1
		_view = {"speaker":" / ".join(participants) if not participants.is_empty() else content.data.characters[speaker].label,
			"speaker_id":speaker, "context_id":context_id, "text":displayed_text, "lines":lines, "choices":choices, "token":token}
		view_changed.emit(current_view())
	return true

func _rollback() -> bool:
	session.restore(_before.narrative.ink_state)
	busy = false
	diagnostic.emit(_turn_error)
	return false

func close() -> void:
	token += 1
	active = false
	busy = false
	dialogue_id = ""
	node_id = ""
	context_id = ""
	displayed_text = ""
	_view.clear()
	closed.emit()

func _ink_flag(id: String) -> bool:
	if id not in content.data.flags:
		_turn_error = "未知剧情标记：" + id
		return false
	return _staged.flags.get(id, false)

func _ink_condition(id: String) -> bool:
	if id not in content.data.conditions:
		_turn_error = "未知剧情条件：" + id
		return false
	return conditions.evaluate(content.data.conditions[id], _staged).ok

func _ink_available(id: String) -> bool:
	if id not in content.data.actions:
		_turn_error = "未知剧情动作：" + id
		return false
	var action = content.data.actions[id]
	return action.get("once_key", "") not in _staged.consumed_once_keys and conditions.evaluate(action.get("condition", {}), _staged).ok

func _ink_check(id: String) -> bool:
	if not _allow_actions or id not in content.data.checks:
		_turn_error = "检定只能在选择后调用已登记的 check：" + id
		return false
	var definition = content.data.checks[id]
	var result = conditions.evaluate(definition, _before)
	_checks.append({"trait":definition.id, "actual":result.actual, "threshold":result.expected, "passed":result.ok})
	return result.ok

func _ink_action(id: String) -> bool:
	if not _allow_actions:
		_turn_error = "动作必须由玩家选择触发：" + id
		return false
	if not _ink_available(id): return false
	var action = content.data.actions[id]
	var applied = effects.apply(action.get("effects", []), _staged)
	if not applied.ok:
		_turn_error = applied.error
		return false
	_staged = applied.state
	var once: String = action.get("once_key", "")
	if not once.is_empty(): _staged.consumed_once_keys.append(once)
	return true
