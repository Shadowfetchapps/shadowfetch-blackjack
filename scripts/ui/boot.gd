extends Control

var _leaving := false


func _ready() -> void:
	set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	SettingsStore.apply_display()
	SettingsStore.apply_audio()
	var bg := ColorRect.new()
	bg.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	bg.color = Color(0.02, 0.022, 0.028, 1)
	add_child(bg)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	add_child(center)
	var box := VBoxContainer.new()
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	center.add_child(box)
	var brand := Label.new()
	brand.text = "SHADOWFETCH"
	brand.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	brand.add_theme_font_size_override("font_size", 28)
	brand.add_theme_color_override("font_color", Color(0.82, 0.68, 0.36))
	box.add_child(brand)
	var title := Label.new()
	title.text = "BLACKJACK"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 72)
	title.add_theme_color_override("font_color", Color(0.96, 0.90, 0.72))
	box.add_child(title)
	var note := Label.new()
	note.text = "Fictional currency  ·  No real-money gambling"
	note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	note.add_theme_font_size_override("font_size", 16)
	note.add_theme_color_override("font_color", Color(0.62, 0.58, 0.48))
	box.add_child(note)
	modulate.a = 0.0
	var fade := create_tween()
	fade.tween_property(self, "modulate:a", 1.0, 0.35)
	var t := get_tree().create_timer(1.25)
	t.timeout.connect(_go_table)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_accept") or (event is InputEventKey and event.pressed):
		_go_table()


func _go_table() -> void:
	if _leaving:
		return
	_leaving = true
	get_tree().change_scene_to_file("res://scenes/table.tscn")
