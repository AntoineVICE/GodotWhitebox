extends Control
const UI = preload("res://scripts/ui/ui_helpers.gd")
signal edit_requested(table: String, id: String, value: int)
signal phase_requested(id: String)
signal save_requested
signal load_requested
signal reset_requested
signal close_requested
var content
var status: Label
var lock_reason: Label
var controls: Array = []
var fields: Dictionary = {}
var log_label: Label
var check_label: Label
var state_label: Label

func setup(db) -> void:
	content = db
	var box = UI.panel(self, 90, 36, 90, 36)
	box.add_child(UI.title(content.data.ui.debug_notice, 25))
	box.add_child(UI.separator())
	status = UI.caption("", 16)
	box.add_child(status)
	lock_reason = UI.label("", 17)
	lock_reason.add_theme_color_override("font_color", UI.GOLD)
	box.add_child(lock_reason)
	var scroll = ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	box.add_child(scroll)
	var body = VBoxContainer.new()
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 12)
	scroll.add_child(body)
	var grid = GridContainer.new()
	grid.columns = 4
	grid.add_theme_constant_override("h_separation", 10)
	body.add_child(grid)
	for table in ["traits", "affinities"]:
		var definitions = content.data.traits if table == "traits" else content.data.npcs
		for id in definitions:
			var cell = PanelContainer.new()
			cell.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			cell.add_theme_stylebox_override("panel", UI.style(Color("19221c"), UI.BORDER, 6, 12))
			grid.add_child(cell)
			var cell_box = VBoxContainer.new()
			cell_box.add_theme_constant_override("separation", 6)
			cell.add_child(cell_box)
			var row = HBoxContainer.new()
			row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			var title = content.data.traits[id] if table == "traits" else content.data.npcs[id].label
			cell_box.add_child(UI.caption(title, 14))
			cell_box.add_child(row)
			var spin = SpinBox.new()
			spin.allow_greater = true
			spin.allow_lesser = true
			spin.step = 1
			spin.custom_minimum_size.x = 95
			spin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			row.add_child(spin)
			fields[table + ":" + id] = spin
			var apply_button = UI.button("设定", _apply.bind(table, id, spin))
			row.add_child(apply_button)
			controls.append(apply_button)
			controls.append(spin)
	var phase_row = HBoxContainer.new()
	body.add_child(phase_row)
	for id in content.data.phases:
		var button = UI.button("调试 → " + content.data.phases[id].label, func(): phase_requested.emit(id))
		phase_row.add_child(button)
		controls.append(button)
	check_label = UI.label("", 17)
	body.add_child(check_label)
	state_label = UI.label("", 17)
	body.add_child(state_label)
	log_label = UI.caption("", 16)
	body.add_child(log_label)
	var footer = HBoxContainer.new()
	footer.add_theme_constant_override("separation", 8)
	box.add_child(footer)
	var save_button = UI.button("保存单槽", func(): save_requested.emit())
	var load_button = UI.button("读取单槽", func(): load_requested.emit())
	footer.add_child(save_button)
	footer.add_child(load_button)
	controls.append(save_button)
	controls.append(load_button)
	footer.add_child(UI.button("完整重置", func(): reset_requested.emit()))
	footer.add_child(UI.button("F3 / Esc · 关闭调试", func(): close_requested.emit()))

func _apply(table: String, id: String, spin: SpinBox) -> void:
	spin.apply()
	edit_requested.emit(table, id, int(spin.value))

func refresh(snapshot: Dictionary, logs: Array, recent_check: Dictionary, reason: String, target: String) -> void:
	if content == null: return
	status.text = "房间 %s · 阶段 %s · 交互 %s" % [snapshot.room_id, snapshot.phase_id, target if not target.is_empty() else "—"]
	lock_reason.text = "操作就绪" if reason.is_empty() else reason
	for control in controls:
		if control is SpinBox: control.editable = reason.is_empty()
		else: control.disabled = not reason.is_empty()
	for key in fields:
		var parts = key.split(":")
		if not fields[key].get_line_edit().has_focus(): fields[key].set_value_no_signal(snapshot[parts[0]][parts[1]])
	check_label.text = "最近检定：" + ("尚无" if recent_check.is_empty() else str(recent_check))
	state_label.text = "flags: %s\n线索: %s\n任务: %s\nonce_key: %s\n结果: %s" % [snapshot.flags, snapshot.clues, snapshot.task_states, snapshot.consumed_once_keys, snapshot.selected_outcome]
	log_label.text = "最近操作 / 条件原因\n" + "\n".join(logs)
