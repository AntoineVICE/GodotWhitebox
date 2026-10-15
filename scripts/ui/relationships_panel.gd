extends Control
const UI = preload("res://scripts/ui/ui_helpers.gd")
signal close_requested
var content
var rows: Dictionary = {}
var values: Dictionary = {}
var search: LineEdit

func setup(db) -> void:
	content = db
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var box = UI.panel(self, 170, 54, 170, 54)
	box.add_child(UI.title("人物关系", 28))
	box.add_child(UI.caption("每个人的好感分别记录 · 数值仅供测试", 15))
	search = LineEdit.new()
	search.placeholder_text = "查找人物"
	search.custom_minimum_size.y = 40
	box.add_child(search)
	search.text_changed.connect(_filter)
	var scroll = ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.follow_focus = true
	box.add_child(scroll)
	var list = VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation", 8)
	scroll.add_child(list)
	for id in content.data.npcs:
		var card = PanelContainer.new()
		card.add_theme_stylebox_override("panel", UI.style(UI.SURFACE, UI.BORDER, 6, 12))
		list.add_child(card)
		var row = HBoxContainer.new()
		card.add_child(row)
		var name_label = UI.label(content.data.npcs[id].label, 19)
		name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(name_label)
		var value = UI.caption("", 16)
		value.custom_minimum_size = Vector2(330, 28)
		row.add_child(value)
		rows[id] = card
		values[id] = value
	box.add_child(UI.button("Esc · 返回", func(): close_requested.emit()))
	hide()

func refresh(snapshot: Dictionary) -> void:
	for id in values:
		var location = content.data.phases[snapshot.phase_id].npcs.get(id, {})
		var place = content.data.rooms[location.room_id].label if not location.is_empty() else "当前未登场"
		values[id].text = "%s  ·  好感 %s" % [place, snapshot.affinities[id]]

func _filter(query: String) -> void:
	for id in rows:
		rows[id].visible = query.is_empty() or query.to_lower() in str(content.data.npcs[id].label).to_lower() or query.to_lower() in id.to_lower()
