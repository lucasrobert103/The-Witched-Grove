class_name Station
extends Interactable
## Estações da casa e do mundo: caldeirão, atril, cama, baú, círculo ritual, placas.

var kind: String = ""
var data: Dictionary = {}
var _t := 0.0
var _anim: Node3D


func setup(p_kind: String, p_data: Dictionary = {}) -> void:
	kind = p_kind
	data = p_data
	match kind:
		"cauldron": prompt = "Usar o caldeirão"; radius = 2.4; marker_height = 1.8
		"lectern": prompt = "Ler o grimório de Ondina"; radius = 2.0; marker_height = 1.8
		"bed": prompt = "Descansar"; radius = 2.2; marker_height = 2.6
		"chest": prompt = "Abrir o baú"; radius = 2.0; marker_height = 1.3
		"ritual": prompt = "Círculo ritual"; radius = 3.0; marker_height = 1.5
		"sign": prompt = "Ler placa"; radius = 2.0; marker_height = 2.2
		"portal": prompt = "Examinar o portal"; radius = 3.5; marker_height = 4.5


func interact(_player: Node) -> void:
	match kind:
		"cauldron":
			EventBus.panel_requested.emit("lab", {})
		"lectern":
			EventBus.panel_requested.emit("lectern", {})
		"bed":
			EventBus.panel_requested.emit("rest", {})
		"chest":
			EventBus.panel_requested.emit("book", {"tab": "inventario"})
		"ritual":
			if Game.house.is_unlocked("sala_ritual"):
				say("O círculo pulsa: seus feitiços têm +%d%% de potência." % int(Game.house.spell_power_bonus() * 100.0), "discovery")
			else:
				say("O círculo está adormecido. Alcance nível 20 em duas escolas para despertá-lo.", "info")
		"sign", "portal":
			EventBus.panel_requested.emit("message", {"title": data.get("title", ""), "text": _sign_text()})
			AudioManager.play_sfx("page_turn")


func _sign_text() -> String:
	if kind == "portal":
		if Game.has_flag("ato1_concluido"):
			return "As runas do arco brilham fracas. Três fechaduras em forma de estrela aguardam as chaves rúnicas da Floresta Encantada, dos Picos da Lua e da Lagoa Espelhada.\n\n— Fim do Ato I (versão de demonstração) —"
		return "Um arco de pedra coberto de runas que você quase entende. Atrás dele, o ar tremula como sobre uma chama. Está selado."
	return data.get("text", "")


func _process(delta: float) -> void:
	_t += delta
	if _anim:
		match kind:
			"cauldron":
				_anim.scale = Vector3(1.0, 1.0 + sin(_t * 3.0) * 0.08, 1.0)
			"ritual":
				_anim.rotation.y += delta * 0.3
			"lectern":
				_anim.position.y = 1.55 + sin(_t * 2.0) * 0.05
				_anim.rotation.y += delta


func set_anim_node(n: Node3D) -> void:
	_anim = n
