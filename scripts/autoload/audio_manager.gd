extends Node
## Fully procedural audio system - no external sound assets required.
## Generates simple waveforms into AudioStreamGenerator buffers at runtime.

const MIX_RATE := 22050.0

var _engine_player: AudioStreamPlayer
var _engine_playback: AudioStreamGeneratorPlayback
var _engine_phase: float = 0.0
var _engine_target_freq: float = 60.0
var _engine_current_freq: float = 60.0
var _engine_enabled: bool = false

var _sfx_bus_volume: float = 1.0
var _paz := false
var _road_ratio := 0.0
var _music: AudioStreamPlayer
var _engine_noise := 0.0

func _ready() -> void:
	_engine_player = AudioStreamPlayer.new()
	var gen := AudioStreamGenerator.new()
	gen.mix_rate = MIX_RATE
	gen.buffer_length = 0.2
	_engine_player.stream = gen
	_engine_player.volume_db = -14.0
	add_child(_engine_player)
	_engine_player.play()
	_engine_playback = _engine_player.get_stream_playback()
	set_process(true)
	_apply_saved_settings()
	_music=AudioStreamPlayer.new()
	var track: AudioStreamWAV=load("res://assets/audio/radio_evening.wav").duplicate()
	track.loop_mode=AudioStreamWAV.LOOP_FORWARD
	track.loop_end=track.data.size()/2
	_music.stream=track
	add_child(_music)
	_music.play()

func _apply_saved_settings() -> void:
	if SaveManager == null:
		return
	_sfx_bus_volume = SaveManager.get_sound_setting("sfx")

func _process(_delta: float) -> void:
	if _engine_playback == null:
		return
	_engine_current_freq = lerp(_engine_current_freq, _engine_target_freq, 0.05)
	var frames_available := _engine_playback.get_frames_available()
	var muted := SaveManager != null and SaveManager.is_muted()
	var master := SaveManager.get_sound_setting("master")
	var sfx := SaveManager.get_sound_setting("sfx")
	if _music:
		var music_volume := 0.0 if muted else master*SaveManager.get_sound_setting("music")
		_music.volume_db=linear_to_db(maxf(music_volume*0.6,0.00001))
	var vol := 0.0 if muted or not _engine_enabled else 0.24 * master * sfx
	for i in range(frames_available):
		var sample := sin(_engine_phase * TAU) * vol
		# add a bit of low harmonic buzz for an "engine" feel
		sample += sin(_engine_phase * TAU * 2.0) * vol * 0.38
		sample += sin(_engine_phase * TAU * 4.0) * vol * 0.12
		_engine_noise=lerpf(_engine_noise,randf_range(-1,1),0.10)
		sample += _engine_noise*vol*(0.18+_road_ratio*0.8)
		_engine_phase = fmod(_engine_phase + _engine_current_freq / MIX_RATE, 1.0)
		_engine_playback.push_frame(Vector2(sample, sample))

func set_engine_running(running: bool) -> void:
	_engine_enabled = running

func set_engine_rpm(speed_ratio: float) -> void:
	# speed_ratio: 0..1
	_road_ratio=clampf(speed_ratio,0.0,1.0)
	var gear := mini(3,int(_road_ratio*4.0))
	var rev := _road_ratio*4.0-float(gear)
	_engine_target_freq = (43.0 if _paz else 58.0) + rev*42.0 + gear*5.0

func _spawn_tone_player() -> AudioStreamPlayer:
	var p := AudioStreamPlayer.new()
	var gen := AudioStreamGenerator.new()
	gen.mix_rate = MIX_RATE
	gen.buffer_length = 0.5
	p.stream = gen
	add_child(p)
	return p

func _play_tone(freq: float, duration: float, volume: float, wave: String = "sine", freq_slide: float = 0.0) -> void:
	if SaveManager != null and SaveManager.is_muted():
		return
	var master := 1.0 if SaveManager == null else SaveManager.get_sound_setting("master")
	var sfx := 1.0 if SaveManager == null else SaveManager.get_sound_setting("sfx")
	var vol := volume * master * sfx
	if vol <= 0.001:
		return
	var p := _spawn_tone_player()
	p.play()
	var playback: AudioStreamGeneratorPlayback = p.get_stream_playback()
	var total_frames := int(MIX_RATE * duration)
	var phase := 0.0
	for i in range(total_frames):
		var t := float(i) / MIX_RATE
		var f := freq + freq_slide * t
		var env := 1.0
		var attack := 0.02
		var release := duration * 0.5
		if t < attack:
			env = t / attack
		elif t > duration - release:
			env = max(0.0, (duration - t) / release)
		var sample := 0.0
		match wave:
			"square":
				sample = 1.0 if sin(phase * TAU) >= 0.0 else -1.0
			"noise":
				sample = randf_range(-1.0, 1.0)
			_:
				sample = sin(phase * TAU)
		phase = fmod(phase + f / MIX_RATE, 1.0)
		playback.push_frame(Vector2.ONE * sample * env * vol)
	var timer := get_tree().create_timer(duration + 0.1)
	timer.timeout.connect(func(): if is_instance_valid(p): p.queue_free())

func play_ui_click() -> void:
	_play_tone(880.0, 0.06, 0.35)

func play_money() -> void:
	_play_tone(660.0, 0.1, 0.3)
	get_tree().create_timer(0.08).timeout.connect(func(): _play_tone(990.0, 0.12, 0.3))

func play_doors() -> void:
	_play_tone(220.0, 0.35, 0.25, "sine", 40.0)

func play_boarding() -> void:
	_play_tone(500.0, 0.08, 0.2)

func play_collision(strength: float) -> void:
	_play_tone(90.0, 0.25, clamp(0.25 + strength * 0.5, 0.2, 0.9), "noise")

func play_brake() -> void:
	_play_tone(300.0, 0.15, 0.2, "square", -120.0)

func play_stop_success() -> void:
	_play_tone(523.0, 0.1, 0.3)
	get_tree().create_timer(0.1).timeout.connect(func(): _play_tone(784.0, 0.16, 0.3))

func play_trip_complete() -> void:
	var notes := [523.0, 659.0, 784.0, 1046.0]
	for i in range(notes.size()):
		get_tree().create_timer(i * 0.14).timeout.connect(func(): _play_tone(notes[i], 0.18, 0.32))

func set_vehicle_type(paz: bool) -> void:
	_paz=paz

func play_horn(paz: bool = false) -> void:
	_play_tone(185.0 if paz else 330.0,0.4,0.18,"square")
	_play_tone(233.0 if paz else 415.0,0.4,0.12)
