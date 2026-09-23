class_name TableView
extends Node3D
## The 3D table: environment, cards, chips, betting spots and camera. It never
## decides game state; GameController asks it to mirror the engine and it returns
## how long each animation takes so the controller can sequence the round.

const TableLayout = preload("res://scripts/table/table_layout.gd")
const TableBuilder = preload("res://scripts/table/table_builder.gd")
const CardTextures = preload("res://scripts/table/card_textures.gd")
const CardView = preload("res://scripts/table/card_view.gd")
const ChipStack = preload("res://scripts/table/chip_stack.gd")
const CameraRig = preload("res://scripts/table/camera_rig.gd")
const FeltPainter = preload("res://scripts/table/felt_painter.gd")
const PatternPainter = preload("res://scripts/table/pattern_painter.gd")
const TextureBaker = preload("res://scripts/table/texture_baker.gd")
const ResultVFX = preload("res://scripts/vfx/result_vfx.gd")
const BJMoney = preload("res://scripts/engine/bj_money.gd")
const SPOT_GLOW := preload("res://assets/shaders/spot_glow.gdshader")

signal spot_clicked(spot: String, button: int)
signal textures_ready

var rig: CameraRig
var textures: CardTextures
var vfx: ResultVFX
var nodes: Dictionary = {}
var world_env: WorldEnvironment
var _fill: DirectionalLight3D
var _card_fill: OmniLight3D
var _cards: Dictionary = {}
var _stacks: Dictionary = {}
var _spots: Dictionary = {}
var _spot_level: Dictionary = {}
var _hover_spot := ""
var _rng := RandomNumberGenerator.new()
var _felt_signature := ""
var textures_baked := false


func build() -> void:
	textures = CardTextures.new()
	textures.build(_deck_style(), SettingsStore.card_back)
	nodes = TableBuilder.build(self)
	_build_env()
	_build_lights()
	rig = CameraRig.new()
	add_child(rig)
	rig.setup()
	vfx = ResultVFX.new()
	add_child(vfx)
	_build_spots()
	_apply_back_materials()
	get_viewport().physics_object_picking = true
	apply_quality()


# --- baking -----------------------------------------------------------------

func bake_textures(rules) -> void:
	await rebake_felt(rules)
	var specs := [
		["carpet", Vector2i(1024, 1024)],
		["wallpaper", Vector2i(1024, 1024)],
		["art_fan", Vector2i(512, 640)],
		["art_lines", Vector2i(512, 640)],
		["sign", Vector2i(2048, 256)],
		["placard", Vector2i(512, 320)],
	]
	for spec in specs:
		var p := PatternPainter.new()
		p.kind = spec[0]
		p.tex_size = spec[1]
		var tex: Texture2D = await TextureBaker.bake(self, spec[1], p)
		if tex == null:
			continue
		match spec[0]:
			"carpet":
				(nodes["carpet_mat"] as StandardMaterial3D).albedo_texture = tex
			"wallpaper":
				(nodes["wall_mat"] as StandardMaterial3D).albedo_texture = tex
			"art_fan", "art_lines":
				var m: StandardMaterial3D = nodes["art_mats"][0 if spec[0] == "art_fan" else 1]
				m.albedo_texture = tex
				m.emission_texture = tex
			"sign":
				(nodes["sign_mat"] as StandardMaterial3D).emission_texture = tex
			"placard":
				var pm := StandardMaterial3D.new()
				pm.albedo_texture = tex
				pm.roughness = 0.5
				pm.emission_enabled = true
				pm.emission_texture = tex
				pm.emission_energy_multiplier = 0.15
				(nodes["placard"] as MeshInstance3D).material_override = pm
	textures_baked = true
	textures_ready.emit()


## Paints the felt for `rules` (the rules in force at the table) and the felt colour.
func rebake_felt(rules) -> void:
	var hi := SettingsStore.quality in ["high", "ultra"]
	var sig := "%s|%s|%s|%s|%s" % [SettingsStore.felt_color, rules.blackjack_ratio_text(), rules.soft17_text(), rules.side_bets, hi]
	if sig == _felt_signature:
		return
	_felt_signature = sig
	var fp := FeltPainter.new()
	fp.tex_size = Vector2i(4096, 2048) if hi else Vector2i(2048, 1024)
	fp.felt_key = SettingsStore.felt_color
	fp.line_bj = "BLACKJACK PAYS " + rules.blackjack_ratio_text()
	fp.line_rule = rules.soft17_text()
	fp.side_bets = rules.side_bets
	var mat: ShaderMaterial = nodes["felt_mat"]
	mat.set_shader_parameter("base_color", FeltPainter.FELTS.get(SettingsStore.felt_color, FeltPainter.FELTS["emerald"]))
	var tex: Texture2D = await TextureBaker.bake(self, fp.tex_size, fp)
	if tex:
		mat.set_shader_parameter("print_tex", tex)
		mat.set_shader_parameter("has_print", 1.0)
	set_side_spots_enabled(rules.side_bets)


# --- environment ------------------------------------------------------------

func _build_env() -> void:
	world_env = WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.006, 0.005, 0.005)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.21, 0.19, 0.17)
	env.ambient_light_energy = 0.5
	env.tonemap_mode = Environment.TONE_MAPPER_ACES
	env.tonemap_exposure = 0.95
	env.tonemap_white = 6.0
	env.glow_enabled = true
	env.glow_intensity = 0.55
	env.glow_strength = 1.0
	env.glow_bloom = 0.03
	env.glow_hdr_threshold = 1.6
	env.glow_blend_mode = Environment.GLOW_BLEND_MODE_SOFTLIGHT
	env.ssao_radius = 0.35
	env.ssao_intensity = 1.4
	env.ssao_power = 1.4
	env.ssil_radius = 1.5
	env.ssil_intensity = 0.6
	env.volumetric_fog_density = 0.010
	env.volumetric_fog_albedo = Color(0.9, 0.82, 0.7)
	env.volumetric_fog_anisotropy = 0.4
	env.volumetric_fog_length = 8.0
	env.adjustment_enabled = true
	env.adjustment_saturation = 1.05
	env.adjustment_contrast = 1.04
	world_env.environment = env
	add_child(world_env)


func _build_lights() -> void:
	_fill = DirectionalLight3D.new()
	_fill.rotation_degrees = Vector3(-38, 18, 0)
	_fill.light_color = Color(0.72, 0.8, 1.0)
	_fill.light_energy = 0.14
	_fill.shadow_enabled = false
	add_child(_fill)
	_card_fill = OmniLight3D.new()
	_card_fill.position = Vector3(0.0, 1.22, 0.62)
	_card_fill.light_color = Color(1.0, 0.95, 0.88)
	_card_fill.light_energy = 0.22
	_card_fill.omni_range = 1.5
	_card_fill.shadow_enabled = false
	add_child(_card_fill)


func apply_quality() -> void:
	var q: String = SettingsStore.quality
	var env := world_env.environment
	env.glow_enabled = SettingsStore.bloom_enabled()
	env.ssao_enabled = q in ["high", "ultra"]
	env.ssil_enabled = q == "ultra"
	env.volumetric_fog_enabled = q == "ultra"
	var lamp: SpotLight3D = nodes.get("lamp_light")
	var shadow_size := SettingsStore.shadow_size()
	if lamp:
		lamp.shadow_enabled = shadow_size > 0
	get_viewport().positional_shadow_atlas_size = maxi(shadow_size, 1024)
	get_viewport().positional_shadow_atlas_16_bits = q != "ultra"
	RenderingServer.positional_soft_shadow_filter_set_quality(
		RenderingServer.SHADOW_QUALITY_SOFT_HIGH if q in ["high", "ultra"] else RenderingServer.SHADOW_QUALITY_SOFT_LOW
	)
	for l in nodes.get("sconces", []):
		(l as OmniLight3D).light_energy = 0.9 if q != "low" else 0.6
	if rig:
		rig.apply_quality()


func apply_appearance(rules) -> void:
	textures.build(_deck_style(), SettingsStore.card_back)
	for v in _cards.values():
		(v as CardView).refresh_materials(textures)
	_apply_back_materials()
	rebake_felt(rules)


func _apply_back_materials() -> void:
	(nodes["discard_stack"] as MeshInstance3D).material_override = textures.back_material()
	(nodes["shoe_next"] as MeshInstance3D).material_override = textures.back_material()


func _deck_style() -> String:
	return "fourcolor" if SettingsStore.four_color else "classic"


# --- betting spots ----------------------------------------------------------

func _build_spots() -> void:
	for spot in TableLayout.SPOTS:
		var r: float = TableLayout.SPOTS[spot]["radius"]
		var pos := TableLayout.spot_world(spot)
		var area := Area3D.new()
		area.input_ray_pickable = true
		area.monitoring = false
		area.monitorable = false
		var col := CollisionShape3D.new()
		var sh := CylinderShape3D.new()
		sh.radius = r * 1.2
		sh.height = 0.04
		col.shape = sh
		area.add_child(col)
		area.position = pos + Vector3(0, 0.015, 0)
		add_child(area)
		area.input_event.connect(_on_spot_input.bind(spot))
		area.mouse_entered.connect(_on_spot_hover.bind(spot, true))
		area.mouse_exited.connect(_on_spot_hover.bind(spot, false))
		var glow := MeshInstance3D.new()
		var pm := PlaneMesh.new()
		pm.size = Vector2.ONE * r * 2.6
		glow.mesh = pm
		var gm := ShaderMaterial.new()
		gm.shader = SPOT_GLOW
		gm.set_shader_parameter("glow_color", Color(1.0, 0.80, 0.42))
		gm.set_shader_parameter("inner", 1.0 / 1.3 - 0.02)
		gm.set_shader_parameter("outer", 1.0 / 1.3 + 0.08)
		gm.set_shader_parameter("intensity", 0.0)
		glow.material_override = gm
		glow.position = pos + Vector3(0, 0.0012, 0)
		glow.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(glow)
		_spots[spot] = {"area": area, "glow": glow, "mat": gm}
		_spot_level[spot] = 0.0


func set_spot_available(spot: String, available: bool) -> void:
	if not _spots.has(spot):
		return
	_spot_level[spot] = 0.35 if available else 0.0
	_refresh_glow(spot)


func set_side_spots_enabled(enabled: bool) -> void:
	for spot in ["pp", "t3"]:
		var s: Dictionary = _spots[spot]
		(s["area"] as Area3D).input_ray_pickable = enabled
		(s["glow"] as MeshInstance3D).visible = enabled


func _on_spot_hover(spot: String, inside: bool) -> void:
	if inside:
		_hover_spot = spot
	elif _hover_spot == spot:
		_hover_spot = ""
	_refresh_glow(spot)


func _refresh_glow(spot: String) -> void:
	var level: float = _spot_level[spot]
	if spot == _hover_spot and level > 0.0:
		level = 1.0
	var mat: ShaderMaterial = _spots[spot]["mat"]
	var tw := create_tween()
	tw.tween_property(mat, "shader_parameter/intensity", level, 0.18)


func _on_spot_input(_cam: Node, event: InputEvent, _pos: Vector3, _normal: Vector3, _shape: int, spot: String) -> void:
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_LEFT:
			spot_clicked.emit(spot, 1)
		elif event.button_index == MOUSE_BUTTON_RIGHT:
			spot_clicked.emit(spot, 2)


# --- cards ------------------------------------------------------------------

## Mirrors every card in the engine onto the table. New cards are dealt from the
## shoe in draw order; existing cards slide or flip into place. Returns seconds
## until the last card has landed.
func sync_cards(engine, start_delay: float = 0.0, gap_scale: float = 1.0) -> float:
	var sc := SettingsStore.anim_scale()
	var move_dur := 0.32 * sc
	var gap := 0.19 * sc * gap_scale
	var targets: Array = []
	var n: int = engine.player_hands.size()
	for i in n:
		var hand = engine.player_hands[i]
		for j in hand.cards.size():
			var c = hand.cards[j]
			var pos := TableLayout.player_card(i, n, j)
			var yaw := _jitter(c)
			if hand.doubled and j == hand.cards.size() - 1 and j >= 2:
				yaw += PI * 0.5
				pos += Vector3(0.018, 0, 0.006)
			targets.append({"card": c, "pos": pos, "yaw": yaw, "up": true})
	var dn: int = engine.dealer.cards.size()
	for j in dn:
		var c = engine.dealer.cards[j]
		targets.append({"card": c, "pos": TableLayout.dealer_card(j, dn), "yaw": _jitter(c), "up": j > 0 or engine.hole_revealed()})
	var fresh: Array = []
	var busy := 0.0
	for t in targets:
		var c = t["card"]
		if _cards.has(c.uid()):
			var v: CardView = _cards[c.uid()]
			if v.position.distance_to(t["pos"]) > 0.002 or absf(angle_difference(v.rotation.y, t["yaw"])) > 0.01:
				v.move_to(t["pos"], t["yaw"], move_dur, 0.01)
				busy = move_dur
			if v.face_up != t["up"]:
				v.set_face_up(t["up"], 0.34 * sc)
				AudioManager.play("card_flip")
				busy = maxf(busy, 0.34 * sc)
		else:
			fresh.append(t)
	fresh.sort_custom(func(a, b): return a["card"].seq < b["card"].seq)
	var delay := start_delay
	for t in fresh:
		_deal_card(t, delay, move_dur)
		delay += gap
	if fresh.is_empty():
		return busy
	return maxf(busy, delay - gap + move_dur)


func _deal_card(t: Dictionary, delay: float, dur: float) -> void:
	var v := CardView.new()
	v.setup(t["card"], textures, false)
	v.position = TableLayout.shoe_mouth()
	v.rotation.y = deg_to_rad(38.0)
	v.visible = false
	add_child(v)
	_cards[v.uid] = v
	var tw := v.create_tween()
	tw.tween_interval(maxf(delay, 0.001))
	tw.tween_callback(func() -> void:
		v.visible = true
		AudioManager.play("card_slide")
		v.move_to(t["pos"], t["yaw"], dur, 0.03)
		if t["up"]:
			v.set_face_up(true, dur * 0.95)
	)


func peek_hole(engine) -> float:
	if engine.dealer.cards.is_empty():
		return 0.0
	var v: CardView = _cards.get(engine.dealer.cards[0].uid())
	if v == null:
		return 0.0
	var d := 0.75 * SettingsStore.anim_scale()
	v.peek(d)
	return d


## Sweeps every card into the discard holder.
func collect_cards() -> float:
	var sc := SettingsStore.anim_scale()
	var dur := 0.42 * sc
	var dest := TableLayout.DISCARD_POS + Vector3(0, 0.04, 0)
	var views: Array = _cards.values()
	views.sort_custom(func(a, b): return a.position.x > b.position.x)
	var i := 0
	for v in views:
		var view: CardView = v
		var tw := view.create_tween()
		tw.tween_interval(0.035 * i * sc)
		tw.tween_callback(func() -> void:
			view.set_face_up(false, dur * 0.8)
			view.move_to(dest, deg_to_rad(-30.0), dur, 0.05)
		)
		tw.tween_interval(dur)
		tw.tween_callback(view.queue_free)
		i += 1
	_cards.clear()
	if i > 0:
		AudioManager.play("card_slide")
	return dur + 0.035 * i * sc


func clear_cards_now() -> void:
	for v in _cards.values():
		(v as Node).queue_free()
	_cards.clear()


func update_shoe(engine) -> void:
	var shoe = engine.shoe
	var frac := float(shoe.remaining()) / float(shoe.capacity)
	var stack: MeshInstance3D = nodes["shoe_stack"]
	var depth := maxf(0.004, 0.19 * frac)
	stack.scale = Vector3(1, 1, depth)
	stack.position.z = -0.128 + depth * 0.5
	var discard: MeshInstance3D = nodes["discard_stack"]
	var count: int = shoe.discarded_count()
	discard.visible = count > 0
	var h := minf(float(count) * 0.00016, 0.05)
	discard.scale = Vector3(1, maxf(h, 0.0005), 1)
	discard.position.y = 0.006 + h * 0.5


func _jitter(card) -> float:
	_rng.seed = card.uid() * 7919 + card.seq * 31
	return deg_to_rad(_rng.randf_range(-2.2, 2.2))


# --- chips ------------------------------------------------------------------

func _stack(key: String, pos: Vector3) -> ChipStack:
	if _stacks.has(key) and is_instance_valid(_stacks[key]):
		return _stacks[key]
	var st := ChipStack.new()
	add_child(st)
	st.global_position = pos
	_stacks[key] = st
	return st


func _drop_stack(key: String) -> void:
	if _stacks.has(key):
		if is_instance_valid(_stacks[key]):
			(_stacks[key] as Node).queue_free()
		_stacks.erase(key)


## Betting phase: one stack per spot in the order chips were placed.
func show_pending_bets(engine, dropped_spot: String = "") -> void:
	for spot in ["main", "pp", "t3"]:
		var chips: Array = engine.chips_for(spot)
		if chips.is_empty():
			_drop_stack(spot)
			continue
		var st := _stack(spot, TableLayout.spot_world(spot))
		st.set_chips(chips, spot == dropped_spot, false)


## During a round: one stack per hand (plus the double and insurance stacks).
func show_round_bets(engine) -> void:
	var sc := SettingsStore.anim_scale()
	var n: int = engine.player_hands.size()
	if _stacks.has("main"):
		_stacks["hand_0"] = _stacks["main"]
		_stacks.erase("main")
	for i in n:
		var h = engine.player_hands[i]
		var base: int = h.bet_cents / 2 if h.doubled else h.bet_cents
		var pos := TableLayout.player_bet(i, n)
		_place_stack("hand_%d" % i, base, pos, sc)
		if h.doubled:
			_place_stack("dbl_%d" % i, base, pos + Vector3(0.048, 0, -0.01), sc)
	if engine.insurance_cents > 0:
		var ip := TableLayout.INSURANCE_POS
		_place_stack("ins", engine.insurance_cents, Vector3(ip.x, TableLayout.FELT_Y, ip.y), sc)


func _place_stack(key: String, amount: int, pos: Vector3, sc: float) -> void:
	if _stacks.has(key):
		var st: ChipStack = _stacks[key]
		if st.amount() != amount:
			st.set_amount(amount)
		if st.global_position.distance_to(pos) > 0.002:
			st.slide_to(pos, 0.35 * sc)
		return
	var fresh := _stack(key, TableLayout.BANKROLL_POS)
	fresh.set_amount(amount)
	fresh.slide_to(pos, 0.42 * sc)
	AudioManager.play("chip_stack")


## Resolves side-bet stacks right after the deal. Returns the animation length.
func resolve_side_bets(engine) -> float:
	if engine.side_results.is_empty():
		return 0.0
	var sc := SettingsStore.anim_scale()
	var any_win := false
	for s in engine.side_results:
		var key: String = s["kind"]
		if not _stacks.has(key):
			continue
		var st: ChipStack = _stacks[key]
		_stacks.erase(key)
		if int(s["payout"]) > 0:
			any_win = true
			_pay_and_collect([st], int(s["net"]), st.global_position, sc)
			vfx.burst(st.global_position, "side")
		else:
			_later(0.25 * sc, func() -> void: st.slide_to(_rack_point(), 0.45 * sc, true))
	if any_win:
		AudioManager.play("chips_payout")
	return 1.3 * sc


## Pays, pushes or collects every hand's chips. Returns the animation length.
func settle_chips(engine) -> float:
	var sc := SettingsStore.anim_scale()
	var n: int = engine.player_hands.size()
	var paid := false
	for i in n:
		var h = engine.player_hands[i]
		var group: Array = []
		for key in ["hand_%d" % i, "dbl_%d" % i]:
			if _stacks.has(key):
				group.append(_stacks[key])
				_stacks.erase(key)
		if group.is_empty():
			continue
		var bet_pos := TableLayout.player_bet(i, n)
		match str(h.outcome):
			"win", "blackjack", "even_money":
				paid = true
				_pay_and_collect(group, h.payout_cents - h.bet_cents, bet_pos, sc)
			"push":
				_later(0.5 * sc, func() -> void:
					for st in group:
						(st as ChipStack).slide_to(_home_point(), 0.45 * sc, true)
				)
			"surrender":
				var half := ChipStack.new()
				add_child(half)
				half.global_position = bet_pos
				half.set_amount(h.bet_cents / 2)
				_later(0.3 * sc, func() -> void:
					half.slide_to(_home_point(), 0.45 * sc, true)
					for st in group:
						(st as ChipStack).slide_to(_rack_point(), 0.45 * sc, true)
				)
			_:
				_later(0.3 * sc, func() -> void:
					for st in group:
						(st as ChipStack).slide_to(_rack_point(), 0.45 * sc, true)
				)
	if _stacks.has("ins"):
		var ins: ChipStack = _stacks["ins"]
		_stacks.erase("ins")
		if engine.insurance_payout_cents > 0:
			paid = true
			_pay_and_collect([ins], engine.insurance_payout_cents - engine.insurance_cents, ins.global_position, sc)
		else:
			_later(0.3 * sc, func() -> void: ins.slide_to(_rack_point(), 0.45 * sc, true))
	if paid:
		AudioManager.play("chips_payout")
	return 1.45 * sc


func _pay_and_collect(group: Array, profit: int, near: Vector3, sc: float) -> void:
	if profit > 0:
		var pay := ChipStack.new()
		add_child(pay)
		pay.global_position = _rack_point()
		pay.set_amount(profit)
		pay.slide_to(near + Vector3(-0.05, 0, 0.012), 0.45 * sc)
		group.append(pay)
	_later(0.95 * sc, func() -> void:
		for st in group:
			if is_instance_valid(st):
				(st as ChipStack).slide_to(_home_point(), 0.42 * sc, true)
	)


func clear_bet_stacks() -> void:
	for key in _stacks.keys():
		_drop_stack(key)


func _rack_point() -> Vector3:
	return TableLayout.RACK_POS + Vector3(_rng.randf_range(-0.12, 0.12), 0.02, 0.0)


func _home_point() -> Vector3:
	return TableLayout.BANKROLL_POS + Vector3(_rng.randf_range(-0.05, 0.05), 0.0, 0.0)


func _later(delay: float, fn: Callable) -> void:
	get_tree().create_timer(maxf(delay, 0.0)).timeout.connect(fn)


# --- helpers for the HUD ----------------------------------------------------

func screen_point(world: Vector3) -> Vector2:
	return rig.camera.unproject_position(world)


func is_visible_point(world: Vector3) -> bool:
	return not rig.camera.is_position_behind(world)


func celebrate(kind: String, world_pos: Vector3) -> void:
	vfx.burst(world_pos, kind)
	if kind == "blackjack":
		rig.punch(1.0)
		vfx.lamp_flash(nodes.get("lamp_light"), nodes.get("lamp_glow"), 1.0)
