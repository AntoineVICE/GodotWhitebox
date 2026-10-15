extends Node
const DB = preload("res://scripts/content_db.gd")
const Conditions = preload("res://scripts/condition_evaluator.gd")
const Effects = preload("res://scripts/effect_executor.gd")
const UI = preload("res://scripts/ui/ui_helpers.gd")
const Relationships = preload("res://scripts/ui/relationships_panel.gd")
const Save = preload("res://scripts/save_service.gd")
var content = DB.new()
var conditions = Conditions.new()
var effects
var saves = Save.new()
var state
var busy: bool = false
var logs: Array = []
var recent_check: Dictionary = {}
var result_generation: int = 0
var state_line: Label
var task_line: Label
var notice: Label
var objective_label: Label
var trait_labels: Dictionary = {}
var affinity_label: Label
var affinity_context: String = ""
var relationships_panel
var save_button: Button
var load_button: Button
@onready var world = $World
@onready var player = $World/Player
@onready var runner = $DialogueRunner
@onready var dialogue_panel = $UI/DialoguePanel
@onready var debug_panel = $UI/DebugPanel
@onready var result_panel = $UI/ResultPanel

func _ready() -> void:
	player.locked = true
	await get_tree().process_frame # Root is now ready for the ordinary Ink runtime service node.
	state = get_node("/root/GameState")
	_install_theme()
	var loaded = content.load_content()
	if not loaded.ok:
		var error_label = UI.label("内容校验失败\n" + loaded.error)
		error_label.position = Vector2(40, 40)
		error_label.size = Vector2(1200, 620)
		$UI.add_child(error_label)
		player.locked = true
		push_error(loaded.error)
		return
	effects = Effects.new(content, conditions)
	var initial_check = saves.validate_snapshot(content.data.initial_state, content)
	if not initial_check.ok:
		push_error("初始状态无效: " + initial_check.error)
		player.locked = true
		return
	world.setup(content, conditions)
	runner.setup(content, conditions, effects, state, commit_snapshot)
	_build_hud()
	relationships_panel = Relationships.new()
	$UI.add_child(relationships_panel)
	relationships_panel.theme = dialogue_panel.theme
	relationships_panel.setup(content)
	relationships_panel.close_requested.connect(toggle_relationships)
	$World/Player/Label.text = content.data.ui.get("player_label", "PLAYER")
	debug_panel.setup(content)
	_connect_signals()
	reset_game()
	show_notice(content.data.ui.start_notice)

func _install_theme() -> void:
	var theme = UI.make_theme()
	for child in $UI.get_children():
		if child is Control: child.theme = theme

func _build_hud() -> void:
	var hud = $UI/HUD
	UI.card(hud, Rect2(24, 20, 1232, 84))
	UI.card(hud, Rect2(24, 114, 1232, 60))
	UI.card(hud, Rect2(24, 190, 746, 112))
	UI.card(hud, Rect2(784, 190, 472, 112))
	UI.card(hud, Rect2(24, 638, 1232, 70))
	var heading = UI.title(content.data.ui.title, 30)
	heading.position = Vector2(46, 30)
	heading.size = Vector2(420, 36)
	hud.add_child(heading)
	var subtitle = UI.caption(content.data.ui.subtitle, 13)
	subtitle.position = Vector2(48, 72)
	subtitle.size = Vector2(400, 20)
	hud.add_child(subtitle)
	state_line = UI.label("", 17)
	state_line.add_theme_color_override("font_color", UI.GOLD)
	state_line.position = Vector2(524, 48)
	state_line.size = Vector2(310, 26)
	hud.add_child(state_line)
	var index = 0
	for id in content.data.traits:
		var value_label = UI.caption("", 17)
		value_label.position = Vector2(48 + index * 106, 134)
		value_label.size = Vector2(104, 27)
		hud.add_child(value_label)
		trait_labels[id] = value_label
		index += 1
	affinity_label = UI.caption("靠近人物查看好感", 16)
	affinity_label.position = Vector2(738, 134)
	affinity_label.size = Vector2(352, 27)
	hud.add_child(affinity_label)
	var people = UI.button("人物关系", toggle_relationships)
	people.position = Vector2(1100, 124)
	people.custom_minimum_size = Vector2(134, 40)
	people.add_theme_font_size_override("font_size", 15)
	hud.add_child(people)
	var objective_heading = UI.caption("当前目标", 13)
	objective_heading.add_theme_color_override("font_color", UI.GOLD)
	objective_heading.position = Vector2(44, 206)
	objective_heading.size = Vector2(200, 22)
	hud.add_child(objective_heading)
	var journal_heading = UI.caption("调查笔记", 13)
	journal_heading.add_theme_color_override("font_color", UI.GOLD)
	journal_heading.position = Vector2(804, 206)
	journal_heading.size = Vector2(200, 22)
	hud.add_child(journal_heading)
	task_line = UI.caption("", 14)
	task_line.position = Vector2(804, 230)
	task_line.size = Vector2(430, 68)
	task_line.add_theme_constant_override("line_spacing", 1)
	hud.add_child(task_line)
	objective_label = UI.label(content.data.ui.guide, 18)
	objective_label.position = Vector2(44, 234)
	objective_label.size = Vector2(704, 64)
	objective_label.add_theme_constant_override("line_spacing", 3)
	hud.add_child(objective_label)
	notice = UI.caption("", 14)
	notice.position = Vector2(44, 681)
	notice.size = Vector2(1188, 24)
	hud.add_child(notice)
	$UI/InteractionHint.position = Vector2(44, 648)
	$UI/InteractionHint.size = Vector2(760, 29)
	$UI/InteractionHint.add_theme_font_size_override("font_size", 19)
	$UI/InteractionHint.add_theme_color_override("font_color", UI.GOLD)
	var movement_hint = UI.caption("A / D 移动   ·   E 交互   ·   Esc 返回", 14)
	movement_hint.position = Vector2(887, 651)
	movement_hint.size = Vector2(344, 24)
	movement_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	hud.add_child(movement_hint)
	var buttons = HBoxContainer.new()
	buttons.position = Vector2(898, 40)
	buttons.add_theme_constant_override("separation", 8)
	hud.add_child(buttons)
	save_button = UI.button("保存", save_game)
	load_button = UI.button("读取", load_game)
	buttons.add_child(save_button)
	buttons.add_child(load_button)
	buttons.add_child(UI.button("重置", reset_game))
	buttons.add_child(UI.button("F3 调试", toggle_debug))
	for button in buttons.get_children():
		button.custom_minimum_size.y = 40
		button.add_theme_font_size_override("font_size", 15)

func _connect_signals() -> void:
	state.state_changed.connect(_state_changed)
	player.request_interaction.connect(interact)
	player.target_changed.connect(_target_changed)
	runner.view_changed.connect(func(view):
		dialogue_panel.show_view(view)
		affinity_context = view.get("context_id", "")
		_refresh_affinity(state.snapshot())
		_refresh_locks())
	runner.closed.connect(func():
		dialogue_panel.hide()
		_refresh_locks())
	runner.diagnostic.connect(log_message)
	runner.checked.connect(func(details):
		recent_check = details
		log_message("检定: " + str(details)))
	dialogue_panel.choice_selected.connect(func(id, token):
		if not runner.choose(id, token) and runner.active: dialogue_panel.show_view(runner.current_view()))
	dialogue_panel.close_requested.connect(runner.close)
	dialogue_panel.reset_requested.connect(reset_game)
	debug_panel.edit_requested.connect(debug_edit)
	debug_panel.phase_requested.connect(debug_phase)
	debug_panel.save_requested.connect(save_game)
	debug_panel.load_requested.connect(load_game)
	debug_panel.reset_requested.connect(reset_game)
	debug_panel.close_requested.connect(toggle_debug)

func commit_snapshot(next: Dictionary, reason: String) -> bool:
	if busy: return false
	busy = true
	_refresh_locks()
	var prepared = next.duplicate(true)
	for id in content.data.tasks:
		prepared.task_states[id] = "complete" if conditions.evaluate(content.data.tasks[id].condition, prepared).ok else "active"
	var validated = saves.validate_snapshot(prepared, content)
	if not validated.ok:
		busy = false
		show_notice(validated.error)
		_refresh_locks()
		return false
	prepared = validated.state
	if not world.sync(prepared):
		busy = false
		show_notice("场景恢复失败，状态未提交")
		_refresh_locks()
		return false
	state.replace_state(prepared)
	log_message(reason)
	busy = false
	_refresh_locks()
	return true

func apply_effects(batch: Array, reason: String) -> bool:
	var applied = effects.apply(batch, state.snapshot())
	if not applied.ok:
		show_notice(applied.error)
		return false
	return commit_snapshot(applied.state, reason)

func interact(id: String) -> void:
	if player.locked or busy or not world.has_interactable(id): return
	var item = content.data.interactables[id]
	var available = conditions.evaluate(item.get("available_if", {}), state.snapshot())
	if not available.ok:
		log_message("条件未满足: " + available.reason)
		show_notice(item.get("unavailable_text", "暂不可用 · " + available.reason))
		return
	match item.action:
		"dialogue": runner.start(item.target_id, id)
		"collect_clue":
			if apply_effects([{"type":"add_clue", "id":item.target_id}], "收集 " + item.target_id): show_notice(content.data.clues[item.target_id].title + " · " + content.data.clues[item.target_id].description)
		"change_room": change_room(item.target_id, item.spawn_id)
		"set_phase":
			if apply_effects([{"type":"set_phase", "id":item.target_id}], "推进阶段 " + item.target_id):
				show_notice(item.get("completed_text", "阶段已推进"))
	_refresh_locks()

func change_room(id: String, spawn: String) -> bool:
	if not lock_reason().is_empty() or id not in content.data.rooms or spawn not in content.data.rooms[id].spawns: return false
	var next = state.snapshot()
	next.room_id = id
	next.spawn_id = spawn
	return commit_snapshot(next, "换房间 " + id)

func debug_edit(table: String, id: String, value: int) -> void:
	if not lock_reason().is_empty() or state.snapshot().selected_outcome != null: return
	if table not in ["traits", "affinities"] or id not in state.snapshot()[table]: return
	var amount = value - state.snapshot()[table][id]
	apply_effects([{"type":"add_trait" if table == "traits" else "add_affinity", "id":id, "amount":amount}], "调试设定 %s = %s" % [id, value])

func debug_phase(id: String) -> void:
	if not lock_reason().is_empty() or state.snapshot().selected_outcome != null: return
	apply_effects([{"type":"set_phase", "id":id}], "调试阶段 " + id)

func lock_reason() -> String:
	if runner.active: return "请先结束对话"
	if busy or world.transitioning: return "状态提交 / 场景加载中"
	if result_panel.visible and state.snapshot().get("selected_outcome") == null: return "请先关闭结算选择"
	return ""

func _refresh_locks() -> void:
	if state == null or state.snapshot().is_empty() or save_button == null: return
	var reason = lock_reason()
	player.locked = not reason.is_empty() or debug_panel.visible or relationships_panel.visible or result_panel.visible or state.snapshot().selected_outcome != null
	save_button.disabled = not reason.is_empty()
	load_button.disabled = not reason.is_empty()
	save_button.tooltip_text = reason
	load_button.tooltip_text = reason
	_refresh_debug()

func _state_changed(snapshot: Dictionary) -> void:
	for id in content.data.traits:
		trait_labels[id].text = "%s   %s" % [content.data.traits[id], snapshot.traits[id]]
		trait_labels[id].add_theme_color_override("font_color", UI.GOLD if snapshot.traits[id] != 0 else UI.MUTED)
	_refresh_affinity(snapshot)
	relationships_panel.refresh(snapshot)
	state_line.text = "%s  /  %s" % [content.data.rooms[snapshot.room_id].label, content.data.phases[snapshot.phase_id].label]
	var tasks: Array = []
	for id in content.data.tasks:
		tasks.append("%s · %s" % [content.data.tasks[id].title, "已结束" if snapshot.task_states[id] == "complete" else "进行中"])
	var clue_names: Array = []
	for id in snapshot.clues: clue_names.append(content.data.clues[id].title)
	task_line.text = "%s\n线索：%s" % [" / ".join(tasks), "尚未发现" if clue_names.is_empty() else "、".join(clue_names)]
	for entry in content.data.ui.get("status_entries", []):
		if conditions.evaluate(entry.condition, snapshot).ok:
			task_line.text += "\n" + entry.text
			break
	objective_label.text = content.data.ui.guide
	for objective in content.data.ui.get("objectives", []):
		if conditions.evaluate(objective.condition, snapshot).ok:
			objective_label.text = objective.text
			break
	if snapshot.selected_outcome != null: _show_result(snapshot.selected_outcome)
	_refresh_locks()

func _target_changed(id: String) -> void:
	if content.data.is_empty(): return
	if not runner.active:
		affinity_context = id
		_refresh_affinity(state.snapshot())
	$UI/InteractionHint.text = content.data.ui.idle_hint if id.is_empty() else "E · " + content.data.interactables[id].label
	_refresh_debug()

func _refresh_affinity(snapshot: Dictionary) -> void:
	if affinity_label == null or snapshot.is_empty(): return
	affinity_label.text = "%s · 好感 %s" % [content.data.npcs[affinity_context].label, snapshot.affinities[affinity_context]] if affinity_context in content.data.npcs else "靠近人物查看好感"

func toggle_relationships() -> void:
	relationships_panel.visible = not relationships_panel.visible
	if relationships_panel.visible: relationships_panel.refresh(state.snapshot())
	_refresh_locks()

func log_message(message: String) -> void:
	if logs.is_empty() or logs.back() != message: logs.append(message)
	while logs.size() > 12: logs.pop_front()
	_refresh_debug()

func show_notice(message: String) -> void:
	if notice != null: notice.text = message
	log_message(message)

func _refresh_debug() -> void:
	if debug_panel.content != null and state != null and not state.snapshot().is_empty():
		debug_panel.refresh(state.snapshot(), logs, recent_check, lock_reason(), player.current_target)

func toggle_debug() -> void:
	debug_panel.visible = not debug_panel.visible
	_refresh_locks()

func _input(event: InputEvent) -> void:
	if effects == null: return
	if event.is_action_pressed("toggle_debug") and not event.is_echo():
		toggle_debug()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("ui_cancel") and not event.is_echo():
		if debug_panel.visible: toggle_debug()
		elif relationships_panel.visible: toggle_relationships()
		elif runner.active: runner.close()
		elif result_panel.visible and state.snapshot().selected_outcome == null: _close_outcomes()
		get_viewport().set_input_as_handled()

func reset_game() -> void:
	busy = true
	result_generation += 1
	runner.close()
	result_panel.hide()
	UI.clear_children(result_panel)
	debug_panel.hide()
	relationships_panel.hide()
	player.clear_target()
	logs.clear()
	recent_check.clear()
	var initial = content.data.initial_state.duplicate(true)
	world.sync(initial, true)
	state.reset(initial)
	notice.text = content.data.ui.start_notice
	busy = false
	_refresh_locks()

func _show_result(id: String) -> void:
	result_generation += 1
	UI.clear_children(result_panel)
	var box = UI.panel(result_panel, 200, 78, 200, 78)
	box.add_child(UI.caption(content.data.ui.result_done, 14))
	box.add_child(UI.title(content.data.outcomes[id].title, 30))
	box.add_child(UI.separator())
	var result_text = UI.label(state.snapshot().narrative.result_text, 20)
	result_text.add_theme_constant_override("line_spacing", 4)
	box.add_child(result_text)
	var values: Array = []
	for trait_id in content.data.traits: values.append("%s %s" % [content.data.traits[trait_id], state.snapshot().traits[trait_id]])
	for npc_id in content.data.npcs:
		if state.snapshot().affinities[npc_id] == 0: continue
		values.append("%s 好感 %s" % [content.data.npcs[npc_id].label, state.snapshot().affinities[npc_id]])
	box.add_child(UI.caption("本次测试：" + " · ".join(values), 15))
	box.add_child(UI.button("读取单槽存档", load_game))
	box.add_child(UI.button("完整重置 · 再次测试", reset_game))
	result_panel.show()

func _close_outcomes() -> void:
	result_generation += 1
	result_panel.hide()
	_refresh_locks()

func save_game() -> void:
	var reason = lock_reason()
	if not reason.is_empty():
		show_notice(reason)
		return
	busy = true
	_refresh_locks()
	var saved = saves.save(state.snapshot())
	busy = false
	show_notice("单槽保存成功" if saved.ok else saved.error)
	_refresh_locks()

func load_game() -> void:
	var reason = lock_reason()
	if not reason.is_empty():
		show_notice(reason)
		return
	busy = true
	_refresh_locks()
	var loaded = saves.load_validated(content)
	if not loaded.ok:
		busy = false
		show_notice(loaded.error + " · 当前进度保持不变")
		_refresh_locks()
		return
	# Restore scene first; no old dialogue or reward is replayed.
	if not world.sync(loaded.state, true):
		busy = false
		show_notice("存档场景恢复失败 · 当前进度保持不变")
		_refresh_locks()
		return
	result_generation += 1
	runner.close()
	result_panel.hide()
	UI.clear_children(result_panel)
	debug_panel.hide()
	relationships_panel.hide()
	logs.clear()
	recent_check.clear()
	state.replace_state(loaded.state)
	busy = false
	show_notice("读取成功 · 已恢复到房间记录的出生点")
	_refresh_locks()
