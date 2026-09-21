extends Node

var _players: Dictionary = {}
var _streams: Dictionary = {}
var _music: AudioStreamPlayer
var _ambient: AudioStreamPlayer


func _ready() -> void:
	_streams["card"] = _tone(410, 0.08, 0.22, 1.8)
	_streams["card_flip"] = _tone(620, 0.07, 0.2, 2.2)
	_streams["chip"] = _tone(880, 0.05, 0.18, 3.2)
	_streams["chip_stack"] = _chord([520, 780, 1040], 0.12, 0.16)
	_streams["button"] = _tone(980, 0.04, 0.14, 0.4)
	_streams["deal"] = _tone(330, 0.09, 0.2, 1.4)
	_streams["win"] = _chord([523, 659, 784], 0.55, 0.26)
	_streams["blackjack"] = _chord([392, 523, 659, 784], 0.85, 0.28)
	_streams["lose"] = _tone(164, 0.32, 0.22, 1.1)
	_streams["bust"] = _tone(140, 0.28, 0.24, 1.4)
	_streams["push"] = _chord([392, 494], 0.28, 0.18)
	_streams["insurance"] = _tone(700, 0.1, 0.16, 1.0)
	for key in _streams:
		var p := AudioStreamPlayer.new()
		p.stream = _streams[key]
		p.bus = "FX"
		add_child(p)
		_players[key] = p
	_music = AudioStreamPlayer.new()
	_music.stream = _music_pad()
	_music.bus = "Music"
	add_child(_music)
	_ambient = AudioStreamPlayer.new()
	_ambient.stream = _room_tone()
	_ambient.bus = "Ambient"
	add_child(_ambient)
	SettingsStore.settings_changed.connect(_on_settings)
	_on_settings()


func play(kind: String) -> void:
	if SettingsStore.muted or SettingsStore.fx_volume <= 0.001:
		return
	if _players.has(kind):
		_players[kind].play()


func _on_settings() -> void:
	SettingsStore.apply_audio()
	if _music:
		if SettingsStore.music_volume > 0.02 and not SettingsStore.muted:
			if not _music.playing:
				_music.play()
		else:
			_music.stop()
	if _ambient:
		if SettingsStore.ambient_volume > 0.02 and not SettingsStore.muted:
			if not _ambient.playing:
				_ambient.play()
		else:
			_ambient.stop()


func _tone(freq: float, seconds: float, vol: float, decay: float) -> AudioStreamWAV:
	var rate := 22050
	var n := int(rate * seconds)
	var data := PackedByteArray()
	data.resize(n * 2)
	for i in n:
		var t := float(i) / float(rate)
		var env := exp(-t * (5.0 + decay * 6.0)) * (1.0 - t / seconds)
		var s := int(sin(t * TAU * freq) * 32767.0 * vol * env)
		s = clampi(s, -32767, 32767)
		data[i * 2] = s & 255
		data[i * 2 + 1] = (s >> 8) & 255
	return _wav(data, rate)


func _chord(freqs: Array, seconds: float, vol: float) -> AudioStreamWAV:
	var rate := 22050
	var n := int(rate * seconds)
	var data := PackedByteArray()
	data.resize(n * 2)
	for i in n:
		var t := float(i) / float(rate)
		var env := exp(-t * 3.6) * (1.0 - t / seconds)
		var sample := 0.0
		for f in freqs:
			sample += sin(t * TAU * float(f))
		sample /= float(freqs.size())
		var s := int(sample * 32767.0 * vol * env)
		s = clampi(s, -32767, 32767)
		data[i * 2] = s & 255
		data[i * 2 + 1] = (s >> 8) & 255
	return _wav(data, rate)


func _music_pad() -> AudioStreamWAV:
	var rate := 22050
	var seconds := 12.0
	var n := int(rate * seconds)
	var data := PackedByteArray()
	data.resize(n * 2)
	for i in n:
		var t := float(i) / float(rate)
		var sample := (
			0.10 * sin(t * TAU * 98.0)
			+ 0.07 * sin(t * TAU * 146.8)
			+ 0.05 * sin(t * TAU * 196.0)
			+ 0.03 * sin(t * TAU * 247.0)
		)
		sample *= 0.62 + 0.38 * sin(t * TAU * 0.08)
		var s := int(sample * 32767.0)
		s = clampi(s, -32767, 32767)
		data[i * 2] = s & 255
		data[i * 2 + 1] = (s >> 8) & 255
	var w := _wav(data, rate)
	w.loop_mode = AudioStreamWAV.LOOP_FORWARD
	w.loop_end = n
	return w


func _room_tone() -> AudioStreamWAV:
	var rate := 22050
	var seconds := 6.0
	var n := int(rate * seconds)
	var data := PackedByteArray()
	data.resize(n * 2)
	var rng := RandomNumberGenerator.new()
	rng.seed = 404
	for i in n:
		var t := float(i) / float(rate)
		var noise := (rng.randf() * 2.0 - 1.0) * 0.035
		var hum := 0.04 * sin(t * TAU * 55.0) + 0.02 * sin(t * TAU * 110.0)
		var s := int((noise + hum) * 32767.0)
		s = clampi(s, -32767, 32767)
		data[i * 2] = s & 255
		data[i * 2 + 1] = (s >> 8) & 255
	var w := _wav(data, rate)
	w.loop_mode = AudioStreamWAV.LOOP_FORWARD
	w.loop_end = n
	return w


func _wav(data: PackedByteArray, rate: int) -> AudioStreamWAV:
	var s := AudioStreamWAV.new()
	s.format = AudioStreamWAV.FORMAT_16_BITS
	s.mix_rate = rate
	s.stereo = false
	s.data = data
	return s
