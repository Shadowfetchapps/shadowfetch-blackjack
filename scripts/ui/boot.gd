extends Control
## Brand splash while the table scene loads in the background.

const ThemeFactory = preload("res://scripts/ui/theme_factory.gd")
const TABLE_SCENE := "res://scenes/table.tscn"

var _leaving := false
var _min_time_done := false


func _ready() -> void:
	set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	theme = ThemeFactory.theme()
	var bg := ColorRect.new()
	bg.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	bg.color = Color(0.012, 0.014, 0.013)
	add_child(bg)
	var glow := TextureRect.new()
	var grad := Gradient.new()
	grad.set_color(0, Color(0.10, 0.30, 0.20, 0.55))
	grad.set_color(1, Color(0, 0, 0, 0))
	var gt := GradientTexture2D.new()
	gt.gradient = grad
	gt.fill = GradientTexture2D.FILL_RADIAL
	gt.fill_from = Vector2(0.5, 0.5)
	gt.fill_to = Vector2(1.0, 0.5)
	gt.width = 512
	gt.height = 512
	glow.texture = gt
	glow.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	glow.stretch_mode = TextureRect.STRETCH_SCALE
	add_child(glow)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	add_child(center)
	var box := VBoxContainer.new()
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 6)
	center.add_child(box)
	var icon := TextureRect.new()
	icon.texture = load("res://icon.svg")
	icon.custom_minimum_size = Vector2(132, 132)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	box.add_child(icon)
	box.add_child(ThemeFactory.spacer(18))
	var brand := ThemeFactory.label("SHADOWFETCH", "Caps")
	brand.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	brand.add_theme_font_size_override("font_size", 18)
	box.add_child(brand)
	var title := ThemeFactory.label("Blackjack", "Title")
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 84)
	title.add_theme_color_override("font_color", ThemeFactory.CREAM)
	box.add_child(title)
	var note := ThemeFactory.label("Fictional chips only  ·  no real-money gambling", "Muted")
	note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(note)
	modulate.a = 0.0
	create_tween().tween_property(self, "modulate:a", 1.0, 0.45)
	ResourceLoader.load_threaded_request(TABLE_SCENE)
	get_tree().create_timer(1.4).timeout.connect(func() -> void: _min_time_done = true)


func _process(_delta: float) -> void:
	if _min_time_done and not _leaving:
		if ResourceLoader.load_threaded_get_status(TABLE_SCENE) == ResourceLoader.THREAD_LOAD_LOADED:
			_go_table()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_pressed() and not event.is_echo():
		_min_time_done = true


func _go_table() -> void:
	_leaving = true
	var packed := ResourceLoader.load_threaded_get(TABLE_SCENE) as PackedScene
	var tw := create_tween()
	tw.tween_property(self, "modulate:a", 0.0, 0.3)
	tw.tween_callback(func() -> void:
		if packed:
			get_tree().change_scene_to_packed(packed)
		else:
			get_tree().change_scene_to_file(TABLE_SCENE)
	)
