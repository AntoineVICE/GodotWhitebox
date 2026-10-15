extends RefCounted
## Presentation-only factories shared by the three small panels.
const INK = Color("eee8da")
const MUTED = Color("a6ad9e")
const GOLD = Color("c9ae78")
const SURFACE = Color("202720")
const BORDER = Color("4b5545")

static func style(fill: Color, border: Color = BORDER, radius: int = 6, padding: int = 14) -> StyleBoxFlat:
	var box = StyleBoxFlat.new()
	box.bg_color = fill
	box.border_color = border
	box.set_border_width_all(1)
	box.set_corner_radius_all(radius)
	box.set_content_margin_all(padding)
	return box

static func make_theme() -> Theme:
	var theme = Theme.new()
	var font = SystemFont.new()
	font.font_names = PackedStringArray(["Microsoft YaHei", "Noto Sans CJK SC", "sans-serif"])
	theme.default_font = font
	theme.default_font_size = 18
	theme.set_color("font_color", "Label", INK)
	theme.set_color("font_color", "Button", INK)
	theme.set_color("font_hover_color", "Button", Color("fff5dd"))
	theme.set_color("font_focus_color", "Button", Color("fff5dd"))
	theme.set_color("font_pressed_color", "Button", GOLD)
	theme.set_color("font_disabled_color", "Button", Color("858c7f"))
	theme.set_stylebox("normal", "Button", style(Color("293229")))
	theme.set_stylebox("hover", "Button", style(Color("354233"), GOLD))
	theme.set_stylebox("pressed", "Button", style(Color("1c251e"), GOLD))
	theme.set_stylebox("disabled", "Button", style(Color("222821"), Color("353d31")))
	for state in ["normal", "hover", "pressed", "disabled"]:
		var button_style = theme.get_stylebox(state, "Button")
		button_style.content_margin_top = 10
		button_style.content_margin_bottom = 10
	var focus = style(Color(0, 0, 0, 0), GOLD, 6, 0)
	focus.set_border_width_all(2)
	theme.set_stylebox("focus", "Button", focus)
	theme.set_stylebox("normal", "LineEdit", style(Color("151d18")))
	theme.set_stylebox("read_only", "LineEdit", style(Color("202620")))
	theme.set_stylebox("focus", "LineEdit", focus)
	theme.set_color("font_color", "LineEdit", INK)
	theme.set_color("caret_color", "LineEdit", GOLD)
	theme.set_color("selection_color", "LineEdit", Color("516047"))
	var line = StyleBoxLine.new()
	line.color = BORDER
	line.thickness = 1
	theme.set_stylebox("separator", "HSeparator", line)
	var track = style(Color("141b16"), Color("141b16"), 3, 3)
	theme.set_stylebox("scroll", "VScrollBar", track)
	theme.set_stylebox("grabber", "VScrollBar", style(Color("64705a"), Color("64705a"), 3, 3))
	theme.set_stylebox("grabber_highlight", "VScrollBar", style(GOLD, GOLD, 3, 3))
	theme.set_stylebox("grabber_pressed", "VScrollBar", style(GOLD, GOLD, 3, 3))
	theme.set_stylebox("panel", "TooltipPanel", style(Color("151d18"), GOLD))
	theme.set_color("font_color", "TooltipLabel", INK)
	return theme

static func label(text: String, size: int = 20) -> Label:
	var node = Label.new()
	node.text = text
	node.add_theme_font_size_override("font_size", size)
	node.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return node

static func title(text: String, size: int = 28) -> Label:
	var node = label(text, size)
	var font = SystemFont.new()
	font.font_names = PackedStringArray(["Noto Serif CJK SC", "SimSun", "serif"])
	node.add_theme_font_override("font", font)
	node.add_theme_color_override("font_color", INK)
	return node

static func caption(text: String, size: int = 14) -> Label:
	var node = label(text, size)
	node.add_theme_color_override("font_color", MUTED)
	return node

static func separator() -> HSeparator:
	var node = HSeparator.new()
	node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return node

static func card(parent: Control, rect: Rect2) -> Panel:
	var node = Panel.new()
	node.position = rect.position
	node.size = rect.size
	node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	node.add_theme_stylebox_override("panel", style(Color("19221d"), Color("3e493c"), 8, 0))
	parent.add_child(node)
	return node

static func button(text: String, callback: Callable) -> Button:
	var node = Button.new()
	node.text = text
	node.custom_minimum_size.y = 44
	node.pressed.connect(callback)
	return node

static func panel(parent: Control, left: float, top: float, right: float, bottom: float) -> VBoxContainer:
	var backdrop = ColorRect.new()
	backdrop.color = Color(0.025, 0.035, 0.025, 0.78)
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	parent.add_child(backdrop)
	var panel_node = PanelContainer.new()
	panel_node.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	panel_node.offset_left = left
	panel_node.offset_top = top
	panel_node.offset_right = -right
	panel_node.offset_bottom = -bottom
	var panel_style = style(SURFACE, Color("73735a"), 10, 26)
	panel_style.shadow_color = Color(0, 0, 0, 0.4)
	panel_style.shadow_size = 22
	panel_style.shadow_offset = Vector2(0, 9)
	panel_node.add_theme_stylebox_override("panel", panel_style)
	parent.add_child(panel_node)
	var box = VBoxContainer.new()
	box.add_theme_constant_override("separation", 12)
	panel_node.add_child(box)
	var accent = ColorRect.new()
	accent.position = Vector2(left + 26, top)
	accent.size = Vector2(76, 2)
	accent.color = GOLD
	accent.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(accent)
	return box

static func clear_children(parent: Node) -> void:
	for child in parent.get_children():
		parent.remove_child(child)
		child.queue_free()
