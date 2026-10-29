extends Node
## Persistência. JSON versionado com soma de verificação e cópia de segurança.
## (Proposta técnica: SQLite exigiria um GDExtension de terceiros; JSON em
## user:// é nativo, legível e suficiente para o volume de dados da V1.)

const SAVE_PATH := "user://savegame.json"
const BACKUP_PATH := "user://savegame.bak.json"

signal saved()
signal loaded()


func _notification(what: int) -> void:
	# Android: salvar quando o app vai para segundo plano ou é fechado.
	if what == NOTIFICATION_APPLICATION_PAUSED or what == NOTIFICATION_WM_CLOSE_REQUEST:
		if Game.started:
			save_game()


func has_save() -> bool:
	return FileAccess.file_exists(SAVE_PATH) or FileAccess.file_exists(BACKUP_PATH)


func save_game() -> bool:
	var payload := Game.to_dict()
	var body := JSON.stringify(payload)
	var doc := {
		"meta": {
			"game": "the-witched-grove", "version": Game.SAVE_VERSION,
			"saved_at": Time.get_datetime_string_from_system(), "checksum": body.md5_text(),
			"day": Game.clock.day(), "playtime": Game.playtime,
		},
		"data": body,
	}
	if FileAccess.file_exists(SAVE_PATH):
		DirAccess.copy_absolute(ProjectSettings.globalize_path(SAVE_PATH), ProjectSettings.globalize_path(BACKUP_PATH))
	var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if f == null:
		push_error("Não foi possível salvar: %s" % error_string(FileAccess.get_open_error()))
		return false
	f.store_string(JSON.stringify(doc))
	f.close()
	saved.emit()
	return true


func _read_doc(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(path))
	if typeof(parsed) != TYPE_DICTIONARY or not parsed.has("data") or not parsed.has("meta"):
		return {}
	var body: String = parsed.data
	if body.md5_text() != parsed.meta.get("checksum", ""):
		push_warning("Save corrompido (checksum): %s" % path)
		return {}
	var data = JSON.parse_string(body)
	return data if typeof(data) == TYPE_DICTIONARY else {}


func load_game() -> bool:
	var data := _read_doc(SAVE_PATH)
	if data.is_empty():
		data = _read_doc(BACKUP_PATH)
	if data.is_empty():
		return false
	data = migrate(data)
	Game.from_dict(data)
	loaded.emit()
	return true


func save_meta() -> Dictionary:
	if not FileAccess.file_exists(SAVE_PATH):
		return {}
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(SAVE_PATH))
	return parsed.get("meta", {}) if typeof(parsed) == TYPE_DICTIONARY else {}


## Migra saves antigos para o formato atual (ponto de extensão para versões futuras).
func migrate(data: Dictionary) -> Dictionary:
	var v := int(data.get("version", 1))
	if v < Game.SAVE_VERSION:
		data["version"] = Game.SAVE_VERSION
	return data


func delete_save() -> void:
	for p in [SAVE_PATH, BACKUP_PATH]:
		if FileAccess.file_exists(p):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(p))
