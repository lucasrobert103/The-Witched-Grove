extends Node
## Áudio: música com crossfade, ambiência em loop e pool de efeitos.
## Todos os sons são gerados proceduralmente por tools/gen_audio.py.

const SFX_DIR := "res://assets/audio/sfx/"
const MUSIC_DIR := "res://assets/audio/music/"
const POOL_SIZE := 10

var _sfx_cache: Dictionary = {}
var _pool: Array[AudioStreamPlayer] = []
var _pool_index := 0
var _music_a: AudioStreamPlayer
var _music_b: AudioStreamPlayer
var _music_current: AudioStreamPlayer
var _music_name := ""
var _ambient: AudioStreamPlayer
var _ambient_name := ""
var _rain: AudioStreamPlayer


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for i in POOL_SIZE:
		var p := AudioStreamPlayer.new()
		p.bus = "SFX"
		add_child(p)
		_pool.append(p)
	_music_a = _make_player("Music")
	_music_b = _make_player("Music")
	_music_current = _music_a
	_ambient = _make_player("Ambient")
	_rain = _make_player("Ambient")


func _make_player(bus: String) -> AudioStreamPlayer:
	var p := AudioStreamPlayer.new()
	p.bus = bus
	add_child(p)
	return p


func _load(path: String) -> AudioStream:
	if _sfx_cache.has(path):
		return _sfx_cache[path]
	var s: AudioStream = null
	if ResourceLoader.exists(path):
		s = load(path)
	_sfx_cache[path] = s
	return s


func _find(dir: String, sound_name: String) -> AudioStream:
	for ext in [".ogg", ".wav"]:
		var s := _load(dir + sound_name + ext)
		if s:
			if dir == MUSIC_DIR and s is AudioStreamOggVorbis:
				s.loop = true
			return s
	return null


func play_sfx(sound_name: String, volume_db: float = 0.0, pitch_variation: float = 0.06, base_pitch: float = 1.0) -> void:
	var s := _find(SFX_DIR, sound_name)
	if s == null:
		return
	var p := _pool[_pool_index]
	_pool_index = (_pool_index + 1) % POOL_SIZE
	p.stream = s
	p.volume_db = volume_db
	p.pitch_scale = base_pitch * (1.0 + randf_range(-pitch_variation, pitch_variation))
	p.play()


func play_music(track: String, fade: float = 2.0) -> void:
	if track == _music_name:
		return
	_music_name = track
	var s := _find(MUSIC_DIR, track)
	var old := _music_current
	var nxt := _music_b if _music_current == _music_a else _music_a
	_music_current = nxt
	if old.playing:
		var tw := create_tween()
		tw.tween_property(old, "volume_db", -60.0, fade)
		tw.tween_callback(old.stop)
	if s:
		nxt.stream = s
		nxt.volume_db = -60.0
		nxt.play()
		var tw2 := create_tween()
		tw2.tween_property(nxt, "volume_db", -4.0, fade)


func stop_music(fade: float = 1.5) -> void:
	_music_name = ""
	var tw := create_tween()
	tw.tween_property(_music_current, "volume_db", -60.0, fade)
	tw.tween_callback(_music_current.stop)


func play_ambient(track: String) -> void:
	if track == _ambient_name:
		return
	if track == "":
		_ambient_name = ""
		_ambient.stop()
		return
	_ambient_name = track
	var s := _find(MUSIC_DIR, track)
	if s == null:
		_ambient.stop()
		return
	_ambient.stream = s
	_ambient.volume_db = -8.0
	_ambient.play()


func set_rain(active: bool) -> void:
	if active and not _rain.playing:
		var s := _find(MUSIC_DIR, "amb_chuva")
		if s:
			_rain.stream = s
			_rain.volume_db = -6.0
			_rain.play()
	elif not active and _rain.playing:
		_rain.stop()


func _exit_tree() -> void:
	# Libera fluxos ao sair (evita vazamentos de playback ao fechar o app).
	for p in _pool + [_music_a, _music_b, _ambient, _rain]:
		p.stop()
		p.stream = null
	_sfx_cache.clear()
