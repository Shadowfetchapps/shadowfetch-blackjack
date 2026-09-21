class_name ThemeFactory
extends RefCounted

const GOLD := Color(0.84, 0.70, 0.36)
const CREAM := Color(0.96, 0.92, 0.82)
const MUTED := Color(0.70, 0.66, 0.56)
const PANEL := Color(0.05, 0.045, 0.04, 0.88)
const DANGER := Color(0.82, 0.28, 0.26)
const GOOD := Color(0.45, 0.78, 0.48)


static func panel(parent: Node, full := false) -> Panel:
	var p := Panel.new()
	if full:
		p.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var sb := StyleBoxFlat.new()
	sb.bg_color = PANEL
	sb.border_color = GOLD.darkened(0.25)
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(10)
	sb.content_margin_left = 16
	sb.content_margin_right = 16
	sb.content_margin_top = 12
	sb.content_margin_bottom = 12
	p.add_theme_stylebox_override("panel", sb)
	parent.add_child(p)
	return p


static func label(text: String, size: int = 18, color: Color = CREAM) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	return l


static func button(text: String, min_w: int = 140) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(min_w, 44)
	var n := StyleBoxFlat.new()
	n.bg_color = Color(0.12, 0.10, 0.07, 0.95)
	n.border_color = GOLD
	n.set_border_width_all(1)
	n.set_corner_radius_all(8)
	n.content_margin_left = 14
	n.content_margin_right = 14
	var h := n.duplicate()
	h.bg_color = Color(0.22, 0.17, 0.08, 0.98)
	var p := n.duplicate()
	p.bg_color = Color(0.32, 0.24, 0.10, 1)
	var d := n.duplicate()
	d.bg_color = Color(0.07, 0.06, 0.05, 0.7)
	d.border_color = Color(0.35, 0.30, 0.20)
	b.add_theme_stylebox_override("normal", n)
	b.add_theme_stylebox_override("hover", h)
	b.add_theme_stylebox_override("pressed", p)
	b.add_theme_stylebox_override("disabled", d)
	b.add_theme_color_override("font_color", CREAM)
	b.add_theme_color_override("font_hover_color", GOLD)
	b.add_theme_color_override("font_disabled_color", Color(0.45, 0.42, 0.36))
	b.add_theme_font_size_override("font_size", 16)
	return b


static func dimmer() -> ColorRect:
	var c := ColorRect.new()
	c.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	c.color = Color(0, 0, 0, 0.62)
	return c
