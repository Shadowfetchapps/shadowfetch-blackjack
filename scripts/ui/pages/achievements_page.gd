extends Control
## Every achievement with its unlock date; locked ones are dimmed.

const ThemeFactory = preload("res://scripts/ui/theme_factory.gd")

var overlay
var _grid: GridContainer
var _title: Label


func build(p_overlay) -> void:
	overlay = p_overlay
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var f: Dictionary = overlay.frame("Achievements", "", 1180, 780)
	add_child(f["root"])
	_title = f["title"]
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	(f["body"] as VBoxContainer).add_child(scroll)
	_grid = GridContainer.new()
	_grid.columns = 3
	_grid.add_theme_constant_override("h_separation", 10)
	_grid.add_theme_constant_override("v_separation", 10)
	scroll.add_child(_grid)
	overlay.back_button(f["footer"])


func refresh() -> void:
	_title.text = "Achievements  ·  %d of %d" % [Achievements.unlocked_count(), Achievements.total()]
	for c in _grid.get_children():
		c.queue_free()
	for d in Achievements.DEFS:
		var got: bool = Achievements.is_unlocked(d["id"])
		var card := PanelContainer.new()
		card.theme_type_variation = "Card"
		card.custom_minimum_size = Vector2(362, 92)
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 14)
		card.add_child(row)
		var medal := Label.new()
		medal.text = str(d["icon"])
		medal.custom_minimum_size = Vector2(56, 56)
		medal.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		medal.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		medal.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		medal.theme_type_variation = "ValueSmall"
		medal.add_theme_font_size_override("font_size", 17)
		var ms := StyleBoxFlat.new()
		ms.set_corner_radius_all(28)
		if got:
			ms.bg_color = ThemeFactory.GOLD
			medal.add_theme_color_override("font_color", ThemeFactory.INK)
		else:
			ms.bg_color = Color(1, 1, 1, 0.05)
			ms.border_color = Color(1, 1, 1, 0.12)
			ms.set_border_width_all(1)
			medal.add_theme_color_override("font_color", ThemeFactory.DIM)
		medal.add_theme_stylebox_override("normal", ms)
		row.add_child(medal)
		var v := VBoxContainer.new()
		v.add_theme_constant_override("separation", 0)
		v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(v)
		var t := ThemeFactory.label(str(d["title"]), "Body")
		t.add_theme_color_override("font_color", ThemeFactory.GOLD_BRIGHT if got else ThemeFactory.MUTED)
		v.add_child(t)
		var desc := ThemeFactory.label(str(d["desc"]), "Muted")
		desc.add_theme_font_size_override("font_size", 14)
		desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		desc.custom_minimum_size = Vector2(250, 0)
		v.add_child(desc)
		var when := ThemeFactory.label(_date(int(Achievements.unlocked_at[d["id"]])) if got else "LOCKED", "Subheading")
		when.add_theme_font_size_override("font_size", 10)
		v.add_child(when)
		_grid.add_child(card)


func _date(unix: int) -> String:
	var t := Time.get_datetime_dict_from_unix_time(unix)
	return "UNLOCKED %04d-%02d-%02d" % [t["year"], t["month"], t["day"]]
