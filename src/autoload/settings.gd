extends Node
## Configurações do jogador (acessibilidade, áudio, gráficos), salvas em user://settings.cfg.

signal changed()

const PATH := "user://settings.cfg"
const BUSES := ["Music", "SFX", "Ambient"]
const TEXT_SCALES := [1.0, 1.2, 1.45]

var master_volume: float = 0.9
var music_volume: float = 0.7
var sfx_volume: float = 0.9
var ambient_volume: float = 0.7
var text_scale_index: int = 0
var high_contrast: bool = false
var vibration: bool = true
var quality: int = 1              # 0 baixa, 1 média, 2 alta
var camera_sensitivity: float = 1.0
var invert_camera_y: bool = false
var show_hints: bool = true


func _ready() -> void:
	_ensure_buses()
	load_settings()
	apply()


func _ensure_buses() -> void:
	for b in BUSES:
		if AudioServer.get_bus_index(b) == -1:
			AudioServer.add_bus()
			var idx := AudioServer.bus_count - 1
			AudioServer.set_bus_name(idx, b)
			AudioServer.set_bus_send(idx, "Master")


func text_scale() -> float:
	return TEXT_SCALES[clampi(text_scale_index, 0, TEXT_SCALES.size() - 1)]


func apply() -> void:
	_set_bus("Master", master_volume)
	_set_bus("Music", music_volume)
	_set_bus("SFX", sfx_volume)
	_set_bus("Ambient", ambient_volume)
	changed.emit()


func _set_bus(bus: String, v: float) -> void:
	var idx := AudioServer.get_bus_index(bus)
	if idx < 0:
		return
	AudioServer.set_bus_mute(idx, v <= 0.001)
	AudioServer.set_bus_volume_db(idx, linear_to_db(maxf(v, 0.0001)))


func vibrate(ms: int = 30) -> void:
	if vibration and OS.has_feature("mobile"):
		Input.vibrate_handheld(ms)


func save_settings() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("audio", "master", master_volume)
	cfg.set_value("audio", "music", music_volume)
	cfg.set_value("audio", "sfx", sfx_volume)
	cfg.set_value("audio", "ambient", ambient_volume)
	cfg.set_value("access", "text_scale_index", text_scale_index)
	cfg.set_value("access", "high_contrast", high_contrast)
	cfg.set_value("access", "vibration", vibration)
	cfg.set_value("access", "show_hints", show_hints)
	cfg.set_value("video", "quality", quality)
	cfg.set_value("control", "camera_sensitivity", camera_sensitivity)
	cfg.set_value("control", "invert_camera_y", invert_camera_y)
	cfg.save(PATH)


func load_settings() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(PATH) != OK:
		quality = 1 if OS.has_feature("mobile") else 2
		return
	master_volume = cfg.get_value("audio", "master", master_volume)
	music_volume = cfg.get_value("audio", "music", music_volume)
	sfx_volume = cfg.get_value("audio", "sfx", sfx_volume)
	ambient_volume = cfg.get_value("audio", "ambient", ambient_volume)
	text_scale_index = cfg.get_value("access", "text_scale_index", text_scale_index)
	high_contrast = cfg.get_value("access", "high_contrast", high_contrast)
	vibration = cfg.get_value("access", "vibration", vibration)
	show_hints = cfg.get_value("access", "show_hints", show_hints)
	quality = cfg.get_value("video", "quality", quality)
	camera_sensitivity = cfg.get_value("control", "camera_sensitivity", camera_sensitivity)
	invert_camera_y = cfg.get_value("control", "invert_camera_y", invert_camera_y)
