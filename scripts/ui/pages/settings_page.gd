extends Control
## Settings with live apply, grouped into tabs: Display, Audio, Gameplay,
## Appearance and Accessibility.

const ThemeFactory = preload("res://scripts/ui/theme_factory.gd")
const CardTextures = preload("res://scripts/table/card_textures.gd")

var overlay
var _tabs: Dictionary = {}
var _tab_buttons: Dictionary = {}
var _controls: Dictionary = {}
var _syncing := false
var _back_preview: TextureRect


func build(p_overlay) -> void:
	overlay = p_overlay
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var f: Dictionary = overlay.frame("Settings", "Changes apply immediately and are saved automatically.", 900, 700)
	add_child(f["root"])
	var body: VBoxContainer = f["body"]
	var tab_row := HBoxContainer.new()
	tab_row.add_theme_constant_override("separation", 4)
	body.add_child(tab_row)
	var group := ButtonGroup.new()
	var stack := MarginContainer.new()
	stack.size_flags_vertical = Control.SIZE_EXPAND_FILL
	stack.add_theme_constant_override("margin_top", 10)
	body.add_child(stack)
	for name in ["Display", "Audio", "Gameplay", "Appearance", "Accessibility"]:
		var b := ThemeFactory.button(name.to_upper(), "TabButton", 0, 40)
		b.toggle_mode = true
		b.button_group = group
		b.pressed.connect(_show_tab.bind(name))
		tab_row.add_child(b)
		_tab_buttons[name] = b
		var scroll := ScrollContainer.new()
		scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
		var v := VBoxContainer.new()
		v.add_theme_constant_override("separation", 6)
		v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		scroll.add_child(v)
		stack.add_child(scroll)
		_tabs[name] = {"scroll": scroll, "box": v}
	_build_display(_tabs["Display"]["box"])
	_build_audio(_tabs["Audio"]["box"])
	_build_gameplay(_tabs["Gameplay"]["box"])
	_build_appearance(_tabs["Appearance"]["box"])
	_build_access(_tabs["Accessibility"]["box"])
	var footer: HBoxContainer = f["footer"]
	overlay.add_button(footer, "RESET DEFAULTS", func() -> void:
		SettingsStore.reset_defaults()
		_apply_all()
		refresh()
	, "", 190)
	footer.add_child(ThemeFactory.expander())
	overlay.back_button(footer)
	_show_tab("Display")


func refresh() -> void:
	_syncing = true
	_set_toggle("fullscreen", SettingsStore.fullscreen)
	_set_option("resolution", SettingsStore.resolution)
	_set_toggle("vsync", SettingsStore.vsync)
	_set_option("quality", SettingsStore.quality)
	_set_option("aa", SettingsStore.aa)
	_set_toggle("shadows", SettingsStore.shadows)
	for k in ["master_volume", "music_volume", "fx_volume", "ambient_volume", "animation_speed", "ui_scale"]:
		_set_slider(k, float(SettingsStore.get(k)))
	_set_toggle("muted", SettingsStore.muted)
	_set_option("coach_mode", SettingsStore.coach_mode)
	_set_toggle("show_totals", SettingsStore.show_totals)
	_set_toggle("show_count", SettingsStore.show_count)
	_set_option("felt_color", SettingsStore.felt_color)
	_set_option("card_back", SettingsStore.card_back)
	_set_toggle("four_color", SettingsStore.four_color)
	_set_option("camera_mode", SettingsStore.camera_mode)
	_set_toggle("reduced_motion", SettingsStore.reduced_motion)
	_set_toggle("camera_sway", SettingsStore.camera_sway)
	_update_back_preview()
	_syncing = false


func _show_tab(name: String) -> void:
	for k in _tabs:
		(_tabs[k]["scroll"] as Control).visible = k == name
	(_tab_buttons[name] as Button).button_pressed = true


# --- tabs -------------------------------------------------------------------

func _build_display(box: VBoxContainer) -> void:
	_toggle(box, "fullscreen", "Fullscreen", "Borderless fullscreen on the current monitor.", func(v): SettingsStore.fullscreen = v; _display())
	var res: Array = []
	for r in SettingsStore.RESOLUTIONS:
		res.append(["%d × %d" % [r.x, r.y], r])
	_option(box, "resolution", "Window size", "Used when not fullscreen.", res, func(v): SettingsStore.resolution = v; _display())
	_toggle(box, "vsync", "Vertical sync", "Prevents tearing; caps frame rate to the display.", func(v): SettingsStore.vsync = v; _display())
	_option(box, "quality", "Graphics quality", "Low · Medium add bloom · High adds ambient occlusion and depth of field · Ultra adds global illumination and volumetric light.",
		[["Low", "low"], ["Medium", "medium"], ["High", "high"], ["Ultra", "ultra"]], func(v): SettingsStore.quality = v; _display(); _quality())
	_option(box, "aa", "Anti-aliasing", "Multisample anti-aliasing for the 3D table.",
		[["Off", 0], ["MSAA 2×", 2], ["MSAA 4×", 4], ["MSAA 8×", 8]], func(v): SettingsStore.aa = v; _display())
	_toggle(box, "shadows", "Shadows", "Soft shadows from the pendant lamp.", func(v): SettingsStore.shadows = v; _quality())


func _build_audio(box: VBoxContainer) -> void:
	_slider(box, "master_volume", "Master volume", 0.0, 1.0, 0.01, "%", func(v): SettingsStore.master_volume = v; _audio())
	_slider(box, "music_volume", "Music", 0.0, 1.0, 0.01, "%", func(v): SettingsStore.music_volume = v; _audio())
	_slider(box, "fx_volume", "Table effects", 0.0, 1.0, 0.01, "%", func(v): SettingsStore.fx_volume = v; _audio())
	_slider(box, "ambient_volume", "Room ambience", 0.0, 1.0, 0.01, "%", func(v): SettingsStore.ambient_volume = v; _audio())
	_toggle(box, "muted", "Mute all", "Silence everything without losing your levels.", func(v): SettingsStore.muted = v; _audio())


func _build_gameplay(box: VBoxContainer) -> void:
	_slider(box, "animation_speed", "Dealing speed", 0.5, 2.5, 0.05, "x", func(v): SettingsStore.animation_speed = v; _save())
	_option(box, "coach_mode", "Strategy coach", "Hints: the HINT button shows the basic-strategy play. Coach: every decision is graded as you make it.",
		[["Off", "off"], ["Hints on request", "hints"], ["Coach every decision", "coach"]], func(v): SettingsStore.coach_mode = v; _save(); overlay.settings_changed.emit())
	_toggle(box, "show_totals", "Show hand totals", "Floating totals above each hand.", func(v): SettingsStore.show_totals = v; _save())
	_toggle(box, "show_count", "Card counting trainer", "Shows the Hi-Lo running count and true count of every card you have seen.", func(v): SettingsStore.show_count = v; _save(); overlay.settings_changed.emit())
	var row := HBoxContainer.new()
	box.add_child(row)
	var l := ThemeFactory.label("First-time tour", "Body")
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(l)
	overlay.add_button(row, "REPLAY TUTORIAL", func() -> void: overlay.replay_tutorial.emit(), "", 220)


func _build_appearance(box: VBoxContainer) -> void:
	_option(box, "felt_color", "Felt", "Colour of the table cloth.",
		[["Emerald", "emerald"], ["Midnight", "midnight"], ["Crimson", "crimson"], ["Charcoal", "charcoal"]], func(v): SettingsStore.felt_color = v; _appearance())
	_option(box, "card_back", "Card backs", "Design on the back of every card.",
		[["Emerald", "emerald"], ["Onyx", "onyx"], ["Crimson", "crimson"], ["Sapphire", "sapphire"]], func(v): SettingsStore.card_back = v; _appearance(); _update_back_preview())
	_back_preview = TextureRect.new()
	_back_preview.custom_minimum_size = Vector2(80, 112)
	_back_preview.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_back_preview.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_back_preview.size_flags_horizontal = Control.SIZE_SHRINK_END
	box.add_child(_back_preview)
	_toggle(box, "four_color", "Four-colour deck", "Diamonds blue and clubs green, so all four suits differ at a glance.", func(v): SettingsStore.four_color = v; _appearance())
	_option(box, "camera_mode", "Camera", "Seated at the table, or an overhead view for maximum readability (toggle any time with C).",
		[["Seated", "seated"], ["Overhead", "overhead"]], func(v): SettingsStore.camera_mode = v; _appearance())


func _build_access(box: VBoxContainer) -> void:
	_slider(box, "ui_scale", "Interface scale", 0.8, 1.5, 0.05, "%", func(v): SettingsStore.ui_scale = v; _display())
	_toggle(box, "reduced_motion", "Reduce motion", "Removes camera sway, push-ins, lamp flashes and the menu orbit.", func(v): SettingsStore.reduced_motion = v; _save())
	_toggle(box, "camera_sway", "Camera breathing and parallax", "A gentle living-camera drift that follows the mouse.", func(v): SettingsStore.camera_sway = v; _save())
	var note := ThemeFactory.label("The four-colour deck (Appearance) and larger interface scale help with colour vision and small screens. Every action has a keyboard shortcut and gamepad button.", "Muted")
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(note)


# --- appliers ---------------------------------------------------------------

func _save() -> void:
	if not _syncing:
		SettingsStore.save_settings()


func _display() -> void:
	if _syncing:
		return
	SettingsStore.apply_display()
	_save()


func _audio() -> void:
	if _syncing:
		return
	SettingsStore.apply_audio()
	_save()


func _quality() -> void:
	if _syncing:
		return
	_save()
	overlay.settings_changed.emit()


func _appearance() -> void:
	if _syncing:
		return
	SettingsStore.notify_appearance()
	overlay.appearance_changed.emit()


func _apply_all() -> void:
	SettingsStore.apply_display()
	SettingsStore.apply_audio()
	SettingsStore.notify_appearance()
	overlay.settings_changed.emit()
	overlay.appearance_changed.emit()


func _update_back_preview() -> void:
	if _back_preview:
		var t := CardTextures.new()
		_back_preview.texture = t.back_texture(SettingsStore.card_back)


# --- widgets ----------------------------------------------------------------

func _row(box: VBoxContainer, title: String, help: String) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 16)
	box.add_child(row)
	var v := VBoxContainer.new()
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.add_theme_constant_override("separation", 0)
	row.add_child(v)
	v.add_child(ThemeFactory.label(title, "Body"))
	if not help.is_empty():
		var h := ThemeFactory.label(help, "Muted")
		h.add_theme_font_size_override("font_size", 13)
		h.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		h.custom_minimum_size = Vector2(420, 0)
		v.add_child(h)
	return row


func _toggle(box: VBoxContainer, key: String, title: String, help: String, setter: Callable) -> void:
	var row := _row(box, title, help)
	var t := CheckButton.new()
	t.focus_mode = Control.FOCUS_ALL
	t.toggled.connect(func(v: bool) -> void:
		if _syncing:
			return
		AudioManager.play("ui_click")
		setter.call(v)
	)
	row.add_child(t)
	_controls[key] = t


func _option(box: VBoxContainer, key: String, title: String, help: String, items: Array, setter: Callable) -> void:
	var row := _row(box, title, help)
	var o := OptionButton.new()
	o.custom_minimum_size = Vector2(240, 42)
	for it in items:
		o.add_item(str(it[0]))
		o.set_item_metadata(o.item_count - 1, it[1])
	o.item_selected.connect(func(i: int) -> void:
		if _syncing:
			return
		AudioManager.play("ui_click")
		setter.call(o.get_item_metadata(i))
	)
	row.add_child(o)
	_controls[key] = o


func _slider(box: VBoxContainer, key: String, title: String, lo: float, hi: float, step: float, unit: String, setter: Callable) -> void:
	var row := _row(box, title, "")
	var s := HSlider.new()
	s.min_value = lo
	s.max_value = hi
	s.step = step
	s.custom_minimum_size = Vector2(260, 30)
	s.focus_mode = Control.FOCUS_ALL
	var val := ThemeFactory.label("", "Muted")
	val.custom_minimum_size = Vector2(60, 0)
	val.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	var fmt := func(v: float) -> String:
		return "%d%%" % int(round(v * 100.0)) if unit == "%" else "%.2f×" % v
	s.value_changed.connect(func(v: float) -> void:
		val.text = fmt.call(v)
		if _syncing:
			return
		setter.call(v)
	)
	row.add_child(s)
	row.add_child(val)
	_controls[key] = s
	s.set_meta("value_label", val)
	s.set_meta("fmt", fmt)


func _set_toggle(key: String, v: bool) -> void:
	if _controls.has(key):
		(_controls[key] as CheckButton).button_pressed = v


func _set_slider(key: String, v: float) -> void:
	if _controls.has(key):
		var s: HSlider = _controls[key]
		s.value = v
		(s.get_meta("value_label") as Label).text = (s.get_meta("fmt") as Callable).call(v)


func _set_option(key: String, v: Variant) -> void:
	if not _controls.has(key):
		return
	var o: OptionButton = _controls[key]
	for i in o.item_count:
		if o.get_item_metadata(i) == v:
			o.select(i)
			return
