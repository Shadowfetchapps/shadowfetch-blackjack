class_name ThemeFactory
extends RefCounted
## The Shadowfetch interface theme (black glass, gold accents, ivory type) plus a few
## widget helpers. Built once and shared by the HUD and every menu page.

const BJFonts = preload("res://scripts/ui/fonts.gd")

const GOLD := Color(0.87, 0.72, 0.42)
const GOLD_BRIGHT := Color(0.99, 0.86, 0.56)
const GOLD_DIM := Color(0.87, 0.72, 0.42, 0.45)
const CREAM := Color(0.95, 0.93, 0.87)
const MUTED := Color(0.68, 0.65, 0.59)
const DIM := Color(0.46, 0.44, 0.41)
const INK := Color(0.07, 0.06, 0.05)
const PANEL := Color(0.030, 0.030, 0.034, 0.88)
const PANEL_SOFT := Color(0.07, 0.068, 0.072, 0.78)
const GOOD := Color(0.45, 0.85, 0.58)
const BAD := Color(0.94, 0.42, 0.38)
const INFO := Color(0.55, 0.75, 0.98)
const EMERALD := Color(0.07, 0.34, 0.21)

static var _theme: Theme


static func theme() -> Theme:
	if _theme != null:
		return _theme
	var t := Theme.new()
	var ui := BJFonts.ui("medium")
	var ui_semi := BJFonts.ui("semibold")
	var ui_bold := BJFonts.ui("bold")
	var disp := BJFonts.display("bold")
	var disp_semi := BJFonts.display("semibold")
	var caps := FontVariation.new()
	caps.base_font = ui_semi
	caps.spacing_glyph = 2
	t.default_font = ui
	t.default_font_size = 18

	t.set_color("font_color", "Label", CREAM)
	_label_var(t, "Title", disp, 60, GOLD)
	_label_var(t, "Heading", disp_semi, 34, GOLD)
	_label_var(t, "Subheading", caps, 13, MUTED)
	_label_var(t, "Caps", caps, 15, GOLD)
	_label_var(t, "Muted", ui, 16, MUTED)
	_label_var(t, "Body", ui, 17, CREAM)
	_label_var(t, "Value", disp, 36, CREAM)
	_label_var(t, "ValueSmall", disp_semi, 24, CREAM)
	_label_var(t, "KeyCap", ui_bold, 11, GOLD)
	var key := _box(Color(0, 0, 0, 0.35), GOLD_DIM, 1, 5)
	key.content_margin_left = 5
	key.content_margin_right = 5
	key.content_margin_top = 1
	key.content_margin_bottom = 1
	t.set_stylebox("normal", "KeyCap", key)

	# Panels.
	var panel := _box(PANEL, Color(GOLD, 0.30), 1, 16)
	panel.shadow_color = Color(0, 0, 0, 0.55)
	panel.shadow_size = 24
	_margins(panel, 28, 24)
	t.set_stylebox("panel", "PanelContainer", panel)
	t.set_stylebox("panel", "Panel", panel)
	var card := _box(PANEL_SOFT, Color(1, 1, 1, 0.06), 1, 12)
	_margins(card, 18, 14)
	t.set_type_variation("Card", "PanelContainer")
	t.set_stylebox("panel", "Card", card)
	var hud := _box(Color(0.02, 0.02, 0.024, 0.72), Color(GOLD, 0.22), 1, 14)
	_margins(hud, 18, 12)
	t.set_type_variation("HudPanel", "PanelContainer")
	t.set_stylebox("panel", "HudPanel", hud)
	var clear := StyleBoxEmpty.new()
	t.set_type_variation("Bare", "PanelContainer")
	t.set_stylebox("panel", "Bare", clear)

	# Buttons.
	_button(t, "Button", ui_semi, 17,
		_box(Color(0.06, 0.058, 0.055, 0.92), Color(GOLD, 0.55), 1, 10),
		_box(Color(0.15, 0.12, 0.07, 0.96), GOLD, 1, 10),
		_box(Color(0.24, 0.18, 0.08, 1.0), GOLD_BRIGHT, 1, 10),
		_box(Color(0.05, 0.05, 0.05, 0.55), Color(1, 1, 1, 0.08), 1, 10),
		CREAM, GOLD_BRIGHT, Color(0.42, 0.40, 0.37))
	t.set_type_variation("PrimaryButton", "Button")
	_button(t, "PrimaryButton", ui_bold, 18,
		_box(Color(0.80, 0.64, 0.33), Color(1.0, 0.88, 0.6), 1, 10),
		_box(Color(0.92, 0.76, 0.42), Color(1.0, 0.92, 0.7), 1, 10),
		_box(Color(0.70, 0.54, 0.26), GOLD_BRIGHT, 1, 10),
		_box(Color(0.24, 0.21, 0.16, 0.7), Color(1, 1, 1, 0.06), 1, 10),
		INK, INK, Color(0.5, 0.47, 0.42))
	t.set_type_variation("GhostButton", "Button")
	var ghost := _box(Color(0, 0, 0, 0), Color(0, 0, 0, 0), 0, 8)
	ghost.content_margin_left = 4
	var ghost_h := _box(Color(GOLD, 0.08), Color(0, 0, 0, 0), 0, 8)
	ghost_h.content_margin_left = 4
	ghost_h.border_width_left = 3
	ghost_h.border_color = GOLD
	_button(t, "GhostButton", disp_semi, 30, ghost, ghost_h, ghost_h, ghost, CREAM, GOLD_BRIGHT, DIM)
	t.set_constant("h_separation", "GhostButton", 12)
	t.set_type_variation("DangerButton", "Button")
	_button(t, "DangerButton", ui_semi, 17,
		_box(Color(0.12, 0.04, 0.04, 0.9), Color(BAD, 0.6), 1, 10),
		_box(Color(0.25, 0.06, 0.06, 0.95), BAD, 1, 10),
		_box(Color(0.35, 0.08, 0.08, 1.0), BAD, 1, 10),
		_box(Color(0.05, 0.05, 0.05, 0.55), Color(1, 1, 1, 0.08), 1, 10),
		CREAM, Color(1, 0.8, 0.78), DIM)
	t.set_type_variation("TabButton", "Button")
	var tab_n := _box(Color(0, 0, 0, 0), Color(0, 0, 0, 0), 0, 0)
	tab_n.content_margin_left = 14
	tab_n.content_margin_right = 14
	tab_n.content_margin_bottom = 8
	var tab_s: StyleBoxFlat = tab_n.duplicate()
	tab_s.border_width_bottom = 2
	tab_s.border_color = GOLD
	_button(t, "TabButton", ui_semi, 16, tab_n, tab_s, tab_s, tab_n, MUTED, GOLD_BRIGHT, DIM)
	t.set_color("font_pressed_color", "TabButton", GOLD)
	t.set_stylebox("pressed", "TabButton", tab_s)

	# Toggles.
	t.set_icon("checked", "CheckButton", _pill(true))
	t.set_icon("unchecked", "CheckButton", _pill(false))
	t.set_icon("checked_disabled", "CheckButton", _pill(true, 0.4))
	t.set_icon("unchecked_disabled", "CheckButton", _pill(false, 0.4))
	t.set_font("font", "CheckButton", ui)
	t.set_font_size("font_size", "CheckButton", 17)
	for s in ["normal", "hover", "pressed", "hover_pressed", "focus", "disabled"]:
		var e := StyleBoxFlat.new()
		e.bg_color = Color(GOLD, 0.06) if s in ["hover", "hover_pressed"] else Color(0, 0, 0, 0)
		if s == "focus":
			e.bg_color = Color(0, 0, 0, 0)
			e.border_color = Color(GOLD, 0.6)
			e.set_border_width_all(1)
		e.set_corner_radius_all(8)
		_margins(e, 10, 6)
		t.set_stylebox(s, "CheckButton", e)
	for c in ["font_color", "font_hover_color", "font_pressed_color", "font_hover_pressed_color", "font_focus_color"]:
		t.set_color(c, "CheckButton", CREAM)

	# Sliders.
	var track := _box(Color(1, 1, 1, 0.10), Color(0, 0, 0, 0), 0, 3)
	track.content_margin_top = 3
	track.content_margin_bottom = 3
	t.set_stylebox("slider", "HSlider", track)
	var fill := _box(GOLD, Color(0, 0, 0, 0), 0, 3)
	fill.content_margin_top = 3
	fill.content_margin_bottom = 3
	t.set_stylebox("grabber_area", "HSlider", fill)
	t.set_stylebox("grabber_area_highlight", "HSlider", fill)
	t.set_icon("grabber", "HSlider", _dot(9, CREAM))
	t.set_icon("grabber_highlight", "HSlider", _dot(10, GOLD_BRIGHT))
	t.set_icon("grabber_disabled", "HSlider", _dot(9, DIM))

	# Option buttons and popups.
	_button(t, "OptionButton", ui_semi, 16,
		_box(Color(0.06, 0.058, 0.055, 0.92), Color(GOLD, 0.4), 1, 8),
		_box(Color(0.12, 0.10, 0.07, 0.96), GOLD, 1, 8),
		_box(Color(0.18, 0.14, 0.08, 1.0), GOLD, 1, 8),
		_box(Color(0.05, 0.05, 0.05, 0.55), Color(1, 1, 1, 0.08), 1, 8),
		CREAM, GOLD_BRIGHT, DIM)
	var popup := _box(Color(0.05, 0.05, 0.055, 0.98), Color(GOLD, 0.4), 1, 8)
	_margins(popup, 6, 6)
	t.set_stylebox("panel", "PopupMenu", popup)
	t.set_stylebox("hover", "PopupMenu", _box(Color(GOLD, 0.18), Color(0, 0, 0, 0), 0, 6))
	t.set_font("font", "PopupMenu", ui)
	t.set_font_size("font_size", "PopupMenu", 16)
	t.set_color("font_color", "PopupMenu", CREAM)
	t.set_color("font_hover_color", "PopupMenu", GOLD_BRIGHT)
	t.set_constant("v_separation", "PopupMenu", 8)

	# Scrollbars.
	var sb_bg := _box(Color(1, 1, 1, 0.04), Color(0, 0, 0, 0), 0, 4)
	sb_bg.content_margin_left = 3
	sb_bg.content_margin_right = 3
	var sb_grab := _box(Color(GOLD, 0.45), Color(0, 0, 0, 0), 0, 4)
	var sb_grab_h := _box(Color(GOLD, 0.75), Color(0, 0, 0, 0), 0, 4)
	for kind in ["VScrollBar", "HScrollBar"]:
		t.set_stylebox("scroll", kind, sb_bg)
		t.set_stylebox("grabber", kind, sb_grab)
		t.set_stylebox("grabber_highlight", kind, sb_grab_h)
		t.set_stylebox("grabber_pressed", kind, sb_grab_h)

	# Tooltips and rich text.
	var tip := _box(Color(0.04, 0.04, 0.045, 0.96), Color(GOLD, 0.5), 1, 6)
	_margins(tip, 10, 6)
	t.set_stylebox("panel", "TooltipPanel", tip)
	t.set_font("font", "TooltipLabel", ui)
	t.set_font_size("font_size", "TooltipLabel", 15)
	t.set_color("font_color", "TooltipLabel", CREAM)
	t.set_font("normal_font", "RichTextLabel", ui)
	t.set_font("bold_font", "RichTextLabel", ui_bold)
	t.set_font("italics_font", "RichTextLabel", BJFonts.ui("regular"))
	t.set_font_size("normal_font_size", "RichTextLabel", 17)
	t.set_font_size("bold_font_size", "RichTextLabel", 17)
	t.set_color("default_color", "RichTextLabel", CREAM)
	t.set_constant("line_separation", "RichTextLabel", 4)
	_theme = t
	return t


# --- helpers ----------------------------------------------------------------

static func label(text: String, variation: String = "Body") -> Label:
	var l := Label.new()
	l.text = text
	l.theme_type_variation = variation
	return l


static func button(text: String, variation: String = "", min_w: int = 150, min_h: int = 48) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(min_w, min_h)
	if not variation.is_empty():
		b.theme_type_variation = variation
	b.focus_mode = Control.FOCUS_ALL
	b.mouse_entered.connect(func() -> void:
		if not b.disabled:
			AudioManager.play("ui_hover")
	)
	return b


static func keycap(text: String) -> Label:
	var k := label(text, "KeyCap")
	k.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	return k


static func spacer(h: float = 0.0, w: float = 0.0) -> Control:
	var c := Control.new()
	c.custom_minimum_size = Vector2(w, h)
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return c


static func expander() -> Control:
	var c := Control.new()
	c.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	c.size_flags_vertical = Control.SIZE_EXPAND_FILL
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return c


static func hsep() -> ColorRect:
	var r := ColorRect.new()
	r.color = Color(GOLD, 0.18)
	r.custom_minimum_size = Vector2(0, 1)
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return r


static func money_color(cents: int) -> Color:
	if cents > 0:
		return GOOD
	if cents < 0:
		return BAD
	return MUTED


static func _label_var(t: Theme, name: String, font: Font, size: int, color: Color) -> void:
	t.set_type_variation(name, "Label")
	t.set_font("font", name, font)
	t.set_font_size("font_size", name, size)
	t.set_color("font_color", name, color)


static func _button(t: Theme, type: String, font: Font, size: int, n: StyleBox, h: StyleBox, p: StyleBox, d: StyleBox, fc: Color, fh: Color, fd: Color) -> void:
	for sb in [n, h, p, d]:
		if sb is StyleBoxFlat and sb.content_margin_left < 0:
			_margins(sb, 18, 8)
	var focus := _box(Color(0, 0, 0, 0), GOLD_BRIGHT, 2, 10)
	focus.draw_center = false
	focus.expand_margin_left = 3
	focus.expand_margin_right = 3
	focus.expand_margin_top = 3
	focus.expand_margin_bottom = 3
	t.set_stylebox("normal", type, n)
	t.set_stylebox("hover", type, h)
	t.set_stylebox("pressed", type, p)
	t.set_stylebox("hover_pressed", type, p)
	t.set_stylebox("disabled", type, d)
	t.set_stylebox("focus", type, focus)
	t.set_font("font", type, font)
	t.set_font_size("font_size", type, size)
	t.set_color("font_color", type, fc)
	t.set_color("font_hover_color", type, fh)
	t.set_color("font_focus_color", type, fh)
	t.set_color("font_pressed_color", type, fh)
	t.set_color("font_hover_pressed_color", type, fh)
	t.set_color("font_disabled_color", type, fd)


static func _box(bg: Color, border: Color, bw: int, radius: int) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = border
	s.set_border_width_all(bw)
	s.set_corner_radius_all(radius)
	s.corner_detail = 8
	s.anti_aliasing = true
	return s


static func _margins(s: StyleBox, h: float, v: float) -> void:
	s.content_margin_left = h
	s.content_margin_right = h
	s.content_margin_top = v
	s.content_margin_bottom = v


## Anti-aliased toggle pill drawn into a small texture.
static func _pill(on: bool, alpha: float = 1.0) -> Texture2D:
	var w := 46
	var h := 26
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	var track := Color(0.80, 0.64, 0.33, alpha) if on else Color(1, 1, 1, 0.14 * alpha)
	var knob := Color(0.07, 0.06, 0.05, alpha) if on else Color(0.85, 0.82, 0.76, alpha)
	var r := h * 0.5
	var kx := w - r if on else r
	for y in h:
		for x in w:
			var px := Vector2(x + 0.5, y + 0.5)
			var cx := clampf(px.x, r, w - r)
			var d := px.distance_to(Vector2(cx, r)) - r
			var a := clampf(0.5 - d, 0.0, 1.0)
			var col := Color(track, track.a * a)
			var dk := px.distance_to(Vector2(kx, r)) - (r - 4.0)
			var ak := clampf(0.5 - dk, 0.0, 1.0)
			if ak > 0.0:
				col = Color(knob, maxf(col.a, knob.a * ak)).lerp(knob, ak) if a > 0.0 else Color(knob, knob.a * ak)
			img.set_pixel(x, y, col)
	return ImageTexture.create_from_image(img)


static func _dot(radius: int, color: Color) -> Texture2D:
	var s := radius * 2 + 2
	var img := Image.create(s, s, false, Image.FORMAT_RGBA8)
	var c := Vector2(s * 0.5, s * 0.5)
	for y in s:
		for x in s:
			var d := Vector2(x + 0.5, y + 0.5).distance_to(c) - radius
			img.set_pixel(x, y, Color(color, color.a * clampf(0.5 - d, 0.0, 1.0)))
	return ImageTexture.create_from_image(img)
