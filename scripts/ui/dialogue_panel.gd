extends Control
const UI = preload("res://scripts/ui/ui_helpers.gd")
signal choice_selected(id: String, token: int)
signal close_requested
signal reset_requested
var speaker: Label
var body: Label
var choices: VBoxContainer
var speaker_badge: Label
var generation: int = 0
var body_scroll: ScrollContainer

func _ready() -> void:
	var box = UI.panel(self, 112, 96, 112, 28)
	var header = HBoxContainer.new()
	header.add_theme_constant_override("separation", 16)
	box.add_child(header)
	var badge = PanelContainer.new()
	badge.custom_minimum_size = Vector2(52, 52)
	badge.add_theme_stylebox_override("panel", UI.style(Color("172219"), UI.GOLD, 6, 8))
	header.add_child(badge)
	speaker_badge = UI.title("", 26)
	speaker_badge.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	speaker_badge.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	speaker_badge.add_theme_color_override("font_color", UI.GOLD)
	badge.add_child(speaker_badge)
	var identity = VBoxContainer.new()
	identity.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(identity)
	identity.add_child(UI.caption("正在交谈", 13))
	speaker = UI.title("", 27)
	identity.add_child(speaker)
	var key_hint = UI.caption("Tab 切换选项  ·  Enter 确认", 14)
	key_hint.custom_minimum_size.x = 242
	key_hint.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	header.add_child(key_hint)
	box.add_child(UI.separator())
	body_scroll = ScrollContainer.new()
	body_scroll.custom_minimum_size.y = 208
	body_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	box.add_child(body_scroll)
	body = UI.label("", 19)
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("line_spacing", 5)
	body_scroll.add_child(body)
	box.add_child(UI.caption("选择回应", 14))
	var scroll = ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.follow_focus = true
	box.add_child(scroll)
	choices = VBoxContainer.new()
	choices.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	choices.add_theme_constant_override("separation", 8)
	scroll.add_child(choices)
	box.add_child(UI.separator())
	var footer = HBoxContainer.new()
	footer.add_theme_constant_override("separation", 10)
	box.add_child(footer)
	var close_button = UI.button("Esc · 结束交谈", func(): close_requested.emit())
	close_button.add_theme_font_size_override("font_size", 15)
	footer.add_child(close_button)
	var reset_button = UI.button("完整重置", func(): reset_requested.emit())
	reset_button.flat = true
	reset_button.add_theme_font_size_override("font_size", 15)
	footer.add_child(reset_button)
	var hint = UI.caption("结束交谈后可保存、读取或修改阶段", 14)
	hint.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	hint.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	footer.add_child(hint)

func show_view(view: Dictionary) -> void:
	generation = view.token
	speaker.text = view.speaker
	speaker_badge.text = view.speaker.left(1)
	body.text = view.text
	body_scroll.custom_minimum_size.y = 132 if view.choices.size() >= 4 else (176 if view.choices.size() == 3 else 208)
	body_scroll.scroll_vertical = 0
	UI.clear_children(choices)
	var first: Button = null
	for index in range(view.choices.size()):
		var choice = view.choices[index]
		var button = UI.button("%02d   %s%s" % [index + 1, choice.text, "  · 已处理" if choice.disabled else ""], _choose.bind(choice.id, view.token))
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.custom_minimum_size.y = 48
		button.add_theme_font_size_override("font_size", 18)
		button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		button.set_meta("choice_id", choice.id)
		button.disabled = choice.disabled
		choices.add_child(button)
		if first == null and not button.disabled: first = button
	show()
	if first != null: first.grab_focus()

func _choose(id: String, token: int) -> void:
	if token != generation: return
	for button in choices.get_children(): button.disabled = true
	choice_selected.emit(id, token)
