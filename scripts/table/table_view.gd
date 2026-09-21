class_name TableView
extends Node3D

const BJCard = preload("res://scripts/engine/bj_card.gd")
const CardTextures = preload("res://scripts/table/card_textures.gd")
const CardView = preload("res://scripts/table/card_view.gd")
const ChipFactory = preload("res://scripts/table/chip_factory.gd")
const TableBuilder = preload("res://scripts/table/table_builder.gd")
const BJMoney = preload("res://scripts/engine/bj_money.gd")
const PLAYER_TILT := 49.0
const DEALER_TILT := 44.0

signal chip_clicked(cents: int)

var textures: CardTextures
var camera: Camera3D
var world_env: WorldEnvironment
var _cards: Array[Node3D] = []
var _bet_chips: Array[Node3D] = []
var _tray_chips: Array[Node3D] = []
var _anchors: Dictionary = {}
var _light: DirectionalLight3D
var _spot: SpotLight3D


func build() -> void:
	textures = CardTextures.new()
	textures.build()
	_anchors = TableBuilder.build(self)
	_build_lights()
	_build_camera()
	_build_tray_chips()
	_build_env()


func _build_env() -> void:
	world_env = WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.025, 0.022, 0.02)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.22, 0.27, 0.20)
	env.ambient_light_energy = 0.48
	env.tonemap_mode = Environment.TONE_MAPPER_ACES
	env.tonemap_exposure = 1.05
	env.glow_enabled = SettingsStore.bloom_enabled()
	env.glow_bloom = 0.035
	env.glow_intensity = 0.18
	env.glow_hdr_threshold = 1.35
	env.ssao_enabled = SettingsStore.quality in ["high", "ultra"]
	env.ssao_radius = 0.8
	env.ssao_intensity = 0.45
	env.adjustment_enabled = true
	env.adjustment_saturation = 1.06
	world_env.environment = env
	add_child(world_env)


func apply_quality() -> void:
	if world_env and world_env.environment:
		world_env.environment.glow_enabled = SettingsStore.bloom_enabled()
		world_env.environment.ssao_enabled = SettingsStore.quality in ["high", "ultra"]
	if _light:
		var sz := SettingsStore.shadow_size()
		_light.shadow_enabled = sz > 0
	if _spot:
		_spot.shadow_enabled = SettingsStore.shadows and SettingsStore.quality != "low"


func _build_lights() -> void:
	_light = DirectionalLight3D.new()
	_light.rotation_degrees = Vector3(-48, -28, 8)
	_light.light_color = Color(1.0, 0.93, 0.82)
	_light.light_energy = 1.45
	_light.shadow_enabled = SettingsStore.shadows
	_light.directional_shadow_max_distance = 8.0
	add_child(_light)
	_spot = SpotLight3D.new()
	_spot.position = Vector3(0.0, 1.55, -0.55)
	_spot.light_color = Color(1.0, 0.82, 0.55)
	_spot.light_energy = 2.4
	_spot.spot_range = 3.2
	_spot.spot_angle = 42.0
	_spot.shadow_enabled = SettingsStore.shadows
	add_child(_spot)
	_spot.look_at(Vector3(0, 0.75, -0.1))
	var fill := OmniLight3D.new()
	fill.position = Vector3(-0.4, 1.3, 0.6)
	fill.light_color = Color(0.55, 0.7, 1.0)
	fill.light_energy = 0.35
	fill.omni_range = 3.0
	add_child(fill)
	var rim := OmniLight3D.new()
	rim.position = Vector3(0.8, 1.1, -0.2)
	rim.light_color = Color(0.9, 0.72, 0.35)
	rim.light_energy = 0.45
	rim.omni_range = 2.4
	add_child(rim)
	var card_fill := OmniLight3D.new()
	card_fill.position = Vector3(0.0, 1.08, 0.62)
	card_fill.light_color = Color(1.0, 0.97, 0.92)
	card_fill.light_energy = 1.8
	card_fill.omni_range = 1.6
	add_child(card_fill)
	var dealer_fill := OmniLight3D.new()
	dealer_fill.position = Vector3(0.0, 1.05, -0.05)
	dealer_fill.light_color = Color(1.0, 0.95, 0.88)
	dealer_fill.light_energy = 1.2
	dealer_fill.omni_range = 1.8
	add_child(dealer_fill)


func _build_camera() -> void:
	camera = Camera3D.new()
	camera.position = Vector3(0.0, 1.20, 1.38)
	camera.fov = 53.0
	camera.near = 0.04
	camera.far = 40.0
	camera.current = true
	add_child(camera)
	camera.look_at(Vector3(0.0, 0.83, 0.02))
	get_viewport().physics_object_picking = true
	_idle_sway()


func _idle_sway() -> void:
	var tw := create_tween().set_loops()
	tw.set_trans(Tween.TRANS_SINE)
	tw.tween_property(camera, "position:x", 0.012, 4.5)
	tw.tween_property(camera, "position:x", -0.012, 4.5)


func cinematic_push(amount: float = 0.06) -> void:
	var dur := 0.45 * SettingsStore.anim_scale()
	var tw := create_tween()
	tw.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	var start := camera.fov
	tw.tween_property(camera, "fov", start - 4.0 * amount * 12.0, dur)
	tw.tween_property(camera, "fov", start, dur * 1.2)


func shoe_pos() -> Vector3:
	return _anchors["shoe"].global_position + Vector3(0, 0.04, 0.08)


func discard_pos() -> Vector3:
	return _anchors["discard"].global_position + Vector3(0, 0.02, 0)


func player_card_pos(hand_index: int, card_index: int, hand_count: int) -> Vector3:
	var origin_x := 0.0
	if hand_count > 1:
		origin_x = (float(hand_index) - (float(hand_count) - 1.0) * 0.5) * 0.40
	return Vector3(
		origin_x + float(card_index) * 0.07,
		0.82 + float(card_index) * 0.016,
		0.58 - float(card_index) * 0.026
	)


func player_card_yaw(hand_index: int, card_index: int, hand_count: int) -> float:
	var base := 0.0
	if hand_count > 1:
		base = (float(hand_index) - (float(hand_count) - 1.0) * 0.5) * -8.0
	return base + float(card_index) * 5.0 - 4.0


func dealer_card_pos(card_index: int) -> Vector3:
	return Vector3(-0.09 + float(card_index) * 0.115, 0.86 + float(card_index) * 0.012, -0.12)


func spawn_card(card, face_up: bool, dest: Vector3, tilt_deg: float = PLAYER_TILT, yaw_deg: float = 0.0):
	var view = CardView.new()
	view.setup(card, textures, false)
	view.apply_display(tilt_deg, yaw_deg)
	view.position = shoe_pos()
	add_child(view)
	_cards.append(view)
	_tween_card(view, dest, face_up, tilt_deg, yaw_deg)
	return view


func _tween_card(view, dest: Vector3, face_up: bool, tilt_deg: float = PLAYER_TILT, yaw_deg: float = 0.0) -> void:
	view.apply_display(tilt_deg, yaw_deg)
	var dur := 0.28 * SettingsStore.anim_scale()
	var mid: Vector3 = (view.position + dest) * 0.5 + Vector3(0, 0.16, 0)
	var tw := create_tween()
	tw.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.tween_property(view, "position", mid, dur * 0.4)
	if face_up:
		tw.parallel().tween_callback(func() -> void:
			view.set_face_up(true, dur * 0.55)
		)
	tw.tween_property(view, "position", dest, dur * 0.6)


func reveal_dealer_hole() -> void:
	if _cards.size() < 2:
		return
	for c in _cards:
		if c is CardView and c.card and not c.face_up:
			c.set_face_up(true, 0.28 * SettingsStore.anim_scale())
			return


func clear_cards(immediate: bool = false) -> void:
	var dest := discard_pos()
	var dur := 0.28 * SettingsStore.anim_scale()
	for c in _cards:
		if immediate or not is_instance_valid(c):
			if is_instance_valid(c):
				c.queue_free()
			continue
		var tw := create_tween()
		tw.tween_property(c, "position", dest + Vector3(randf() * 0.02, 0.01, randf() * 0.02), dur)
		tw.tween_callback(c.queue_free)
	_cards.clear()


func set_bet_stack(chips: Array) -> void:
	for n in _bet_chips:
		n.queue_free()
	_bet_chips.clear()
	var i := 0
	for v in chips:
		var chip: Node3D = ChipFactory.make(int(v), false)
		chip.position = Vector3(0.0, 0.754 + float(i) * 0.0044, 0.28)
		add_child(chip)
		_bet_chips.append(chip)
		i += 1


func _build_tray_chips() -> void:
	var i := 0
	for cents in BJMoney.CHIP_VALUES:
		var chip: Node3D = ChipFactory.make(cents, true)
		chip.position = Vector3(-0.62 + float(i) * 0.052, 0.776, 0.22)
		for extra in 2:
			var stack: Node3D = ChipFactory.make(cents, false)
			stack.position = chip.position + Vector3(0, 0.0046 * float(extra + 1), 0)
			add_child(stack)
		add_child(chip)
		_tray_chips.append(chip)
		var area := chip.find_child("Area3D", true, false)
		if area:
			area.input_event.connect(_on_chip_input.bind(cents))
		i += 1


func _on_chip_input(_cam: Node, event: InputEvent, _pos: Vector3, _norm: Vector3, _shape: int, cents: int) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		chip_clicked.emit(cents)
