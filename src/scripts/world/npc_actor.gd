class_name NPCActor
extends Interactable
## NPC no mundo: modelo, rotina diária (posição por hora), nome flutuante,
## indicador de novidade e conversa orientada a dados.

var npc_id: String = ""
var model: Node3D
var _label: Label3D
var _alert: Label3D
var _target_pos: Vector3
var _ground: Callable
var _t := 0.0
var _talking := false


func setup(p_id: String, ground_fn: Callable) -> void:
	npc_id = p_id
	_ground = ground_fn
	radius = 2.6
	map_color = Color(DataRegistry.factions.get(DataRegistry.npcs[npc_id].faction, {}).get("color", "#ffffff"))
	map_label = DataRegistry.npc_name(npc_id)


func _ready() -> void:
	var d: Dictionary = DataRegistry.npcs[npc_id]
	if d.appearance.get("special", "") == "tree_spirit":
		var tree := TreeSpiritModel.new()
		model = tree
		radius = 5.5
		marker_height = 9.5
	else:
		var h := HumanoidModel.new()
		model = h
		marker_height = 2.1 * float(d.appearance.get("height", 1.0)) + 0.4
	add_child(model)
	if model is HumanoidModel:
		model.build(d.appearance)
	_label = Label3D.new()
	_label.text = d.name
	_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_label.font_size = 34
	_label.outline_size = 9
	_label.visibility_range_begin = 2.5
	_label.visibility_range_end = 22.0
	_label.modulate = Color("#fff6e0")
	_label.outline_modulate = Color("#2a1d3a")
	_label.pixel_size = 0.006
	_label.position = Vector3(0, marker_height - 0.15, 0)
	_label.no_depth_test = false
	add_child(_label)
	_alert = Label3D.new()
	_alert.text = "!"
	_alert.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_alert.font_size = 96
	_alert.outline_size = 16
	_alert.modulate = Color("#f3c74f")
	_alert.outline_modulate = Color("#3a2068")
	_alert.pixel_size = 0.006
	_alert.visibility_range_end = 45.0
	_alert.position = Vector3(0, marker_height + 0.35, 0)
	add_child(_alert)
	EventBus.dialogue_closed.connect(_on_dialogue_closed)
	refresh_state()
	global_position = _target_pos


func get_prompt() -> String:
	return "Falar com %s" % DataRegistry.npc_name(npc_id)


func interact(player: Node) -> void:
	_talking = true
	if model is HumanoidModel:
		model.play_talk(2.5)
		var to: Vector3 = (player as Node3D).global_position - global_position
		to.y = 0
		if to.length() > 0.1:
			rotation.y = atan2(-to.x, -to.z)
	EventBus.dialogue_requested.emit(npc_id)


func _on_dialogue_closed(id: String) -> void:
	if id == npc_id:
		_talking = false
		refresh_state()


## Rotina: escolhe a posição da faixa de horário atual (com faixas que cruzam a meia-noite).
func scheduled_position() -> Variant:
	var hour := Game.clock.hour()
	for s in DataRegistry.npcs[npc_id].get("schedule", []):
		var from := float(s.from)
		var to := float(s.to)
		var inside := (hour >= from and hour < to) if from < to else (hour >= from or hour < to)
		if inside:
			return Vector3(float(s.pos[0]), 0.0, float(s.pos[1]))
	return null


func refresh_state() -> void:
	var p: Variant = scheduled_position()
	visible = p != null
	if p != null:
		var v: Vector3 = p
		v.y = _ground.call(v.x, v.z) if _ground.is_valid() else 0.0
		_target_pos = v
	if model is TreeSpiritModel:
		if Game.has_flag("musgo_corrompido"):
			model.state = TreeSpiritModel.State.VIOLET
		elif Game.has_flag("musgo_purificado"):
			model.state = TreeSpiritModel.State.HEALED
		else:
			model.state = TreeSpiritModel.State.GREY
	if _alert:
		_alert.visible = has_news()


## Há algo novo a dizer quando a entrada de diálogo escolhida não é a última (padrão).
func has_news() -> bool:
	var t: Dictionary = DataRegistry.dialogues.get(npc_id, {})
	var entries: Array = t.get("entries", [])
	for i in entries.size():
		if Conditions.check_all(entries[i].get("if", []), Game):
			return i < entries.size() - 1 and npc_id != "bento"
	return false


func on_spell(tags: Array, _result: Dictionary) -> bool:
	if npc_id != "musgo":
		return false
	if "purify" in tags and Game.quests.current_objective("mq02_raizes") == "purificar":
		Game.set_flag("purificado_magia")
		Game.set_flag("musgo_purificado")
		refresh_state()
		EventBus.panel_requested.emit("dialogue_node", {"npc": "musgo", "node": "curado"})
		return true
	if "purify" in tags:
		say("A luz da contra-magia escorre pela casca, mas não há cinza aqui para limpar.", "info")
		return true
	if "nature_sync" in tags and not Game.has_flag("musgo_purificado"):
		say("Você sente a seiva... e um vazio. \"O Silêncio Cinzento não é doença — é ausência.\"", "discovery")
		Game.add_research("silencio_cinzento", 5.0)
		return true
	return false


func _process(delta: float) -> void:
	_t += delta
	if not visible or _talking:
		if model is HumanoidModel:
			model.move_amount = 0.0
		return
	var to := _target_pos - global_position
	to.y = 0.0
	if to.length() > 0.15:
		var step := minf(to.length(), 1.6 * delta)
		global_position += to.normalized() * step
		global_position.y = _ground.call(global_position.x, global_position.z) if _ground.is_valid() else global_position.y
		rotation.y = lerp_angle(rotation.y, atan2(-to.x, -to.z), 1.0 - exp(-8.0 * delta))
		if model is HumanoidModel:
			model.move_amount = 0.45
	elif model is HumanoidModel:
		model.move_amount = 0.0
	if _alert and _alert.visible:
		_alert.position.y = marker_height + 0.35 + sin(_t * 3.0) * 0.08
