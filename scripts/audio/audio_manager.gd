extends Node
## Autoload `AudioManager`: plays the synthesized sound set (see tools/generate_audio.py)
## on the FX bus with variation, and crossfades menu / table music and room ambience.

const DIR := "res://assets/audio/"
## Sound name -> [variant files, volume dB, pitch jitter].
const SOUNDS := {
	"card_slide": [["card_slide_1", "card_slide_2", "card_slide_3"], 0.0, 0.06],
	"card": [["card_slide_1", "card_slide_2", "card_slide_3"], 0.0, 0.06],
	"deal": [["card_slide_1", "card_slide_2", "card_slide_3"], 0.0, 0.06],
	"card_flip": [["card_flip_1", "card_flip_2"], -2.0, 0.05],
	"card_place": [["card_place_1", "card_place_2"], -1.0, 0.05],
	"chip": [["chip_click_1", "chip_click_2", "chip_click_3"], -1.0, 0.05],
	"chip_stack": [["chip_stack_1", "chip_stack_2"], -2.0, 0.04],
	"chips_payout": [["chips_payout"], -1.0, 0.03],
	"shuffle": [["shuffle"], 0.0, 0.0],
	"ui_hover": [["ui_hover"], -4.0, 0.03],
	"ui_click": [["ui_click"], 0.0, 0.02],
	"button": [["ui_click"], 0.0, 0.02],
	"ui_back": [["ui_back"], 0.0, 0.02],
	"win": [["win"], -2.0, 0.0],
	"blackjack": [["blackjack"], -1.0, 0.0],
	"lose": [["lose"], -4.0, 0.0],
	"bust": [["bust"], -3.0, 0.0],
	"push": [["push"], -4.0, 0.0],
	"insurance": [["insurance"], -3.0, 0.0],
	"achievement": [["achievement"], -2.0, 0.0],
	"coach_good": [["coach_good"], -2.0, 0.0],
	"coach_bad": [["coach_bad"], -2.0, 0.0],
}
const MUSIC := {"menu": "music_menu", "table": "music_lounge"}

var _players: Dictionary = {}
var _streams: Dictionary = {}
var _music_a: AudioStreamPlayer
var _music_b: AudioStreamPlayer
var _ambient: AudioStreamPlayer
var _scene := ""
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	_rng.randomize()
	for name in SOUNDS:
		var spec: Array = SOUNDS[name]
		var variants: Array = []
		for file in spec[0]:
			var s := _load(file)
			if s != null:
				variants.append(s)
		if variants.is_empty():
			continue
		var p := AudioStreamPlayer.new()
		p.bus = "FX"
		p.max_polyphony = 6
		p.volume_db = float(spec[1])
		add_child(p)
		_players[name] = p
		_streams[name] = variants
	_music_a = _music_player()
	_music_b = _music_player()
	_ambient = AudioStreamPlayer.new()
	_ambient.bus = "Ambient"
	var amb := _load("ambience_room", true)
	if amb:
		_ambient.stream = amb
	add_child(_ambient)
	SettingsStore.settings_changed.connect(_on_settings)
	_on_settings()


func _music_player() -> AudioStreamPlayer:
	var p := AudioStreamPlayer.new()
	p.bus = "Music"
	p.volume_db = -80.0
	add_child(p)
	return p


func play(kind: String) -> void:
	if SettingsStore.muted or not _players.has(kind):
		return
	var p: AudioStreamPlayer = _players[kind]
	var variants: Array = _streams[kind]
	p.stream = variants[_rng.randi_range(0, variants.size() - 1)]
	var jitter: float = SOUNDS[kind][2]
	p.pitch_scale = 1.0 + _rng.randf_range(-jitter, jitter)
	p.play()


## "menu" or "table": crossfades to that scene's music.
func set_scene(scene: String) -> void:
	if scene == _scene:
		return
	_scene = scene
	var stream := _load(str(MUSIC.get(scene, "")), true)
	if stream == null:
		return
	var incoming := _music_b if _music_a.playing else _music_a
	var outgoing := _music_a if incoming == _music_b else _music_b
	incoming.stream = stream
	incoming.volume_db = -40.0
	if _music_allowed():
		incoming.play()
	var tw := create_tween().set_parallel(true)
	tw.tween_property(incoming, "volume_db", 0.0, 1.8)
	if outgoing.playing:
		tw.tween_property(outgoing, "volume_db", -60.0, 1.8)
		tw.chain().tween_callback(outgoing.stop)


func _music_allowed() -> bool:
	return not SettingsStore.muted and SettingsStore.music_volume > 0.01 and SettingsStore.master_volume > 0.01


func _on_settings() -> void:
	SettingsStore.apply_audio()
	var current := _music_a if _music_a.volume_db > _music_b.volume_db else _music_b
	if _music_allowed():
		if current.stream and not current.playing:
			current.volume_db = 0.0
			current.play()
	else:
		_music_a.stop()
		_music_b.stop()
	if _ambient.stream:
		if not SettingsStore.muted and SettingsStore.ambient_volume > 0.01:
			if not _ambient.playing:
				_ambient.play()
		else:
			_ambient.stop()


func _load(file: String, loop: bool = false) -> AudioStream:
	if file.is_empty():
		return null
	var path := DIR + file + ".ogg"
	if not ResourceLoader.exists(path):
		return null
	var s = load(path)
	if s is AudioStreamOggVorbis:
		if loop:
			s = s.duplicate()
			s.loop = true
		return s
	return s as AudioStream
