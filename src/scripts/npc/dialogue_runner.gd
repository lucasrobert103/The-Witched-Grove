class_name DialogueRunner
extends RefCounted
## Sistema G — Diálogos orientados a dados (data/npcs/dialogues.json).
## Escolhe o nó de entrada por condições, aplica efeitos e filtra opções.

var npc_id: String = ""
var node_id: String = ""
var game: Object
var finished: bool = true


func _init(p_game: Object) -> void:
	game = p_game


func tree() -> Dictionary:
	return DataRegistry.dialogues.get(npc_id, {})


func start(p_npc_id: String) -> bool:
	npc_id = p_npc_id
	var t := tree()
	if t.is_empty():
		finished = true
		return false
	for e in t.get("entries", []):
		if Conditions.check_all(e.get("if", []), game):
			finished = false
			_enter(e.node)
			return true
	finished = true
	return false


func _enter(id: String) -> void:
	if id == "end" or not tree().get("nodes", {}).has(id):
		finished = true
		node_id = ""
		return
	node_id = id
	var node: Dictionary = tree().nodes[id]
	game.apply_effects(node.get("effects", []))


func current_node() -> Dictionary:
	if finished:
		return {}
	return tree().nodes.get(node_id, {})


func text() -> String:
	return format_text(current_node().get("text", ""))


func format_text(t: String) -> String:
	return t.format({
		"player": DataRegistry.player_def.get("name", "Asterion"),
		"season": DataRegistry.season_name(game.clock.season()).to_lower(),
		"moon": game.clock.moon_name(),
		"day": str(game.clock.day()),
	})


## Opções visíveis: [{"text": String, "index": int}]
func options() -> Array:
	var node := current_node()
	if node.is_empty():
		return []
	var out: Array = []
	var raw: Array = node.get("options", [])
	for i in raw.size():
		if Conditions.check_all(raw[i].get("if", []), game):
			out.append({"text": format_text(raw[i].text), "index": i})
	if out.is_empty():
		if node.has("goto_after"):
			out.append({"text": "Continuar", "index": -2})
		else:
			out.append({"text": "Até mais.", "index": -1})
	return out


func choose(index: int) -> void:
	var node := current_node()
	if node.is_empty():
		return
	if index == -1:
		finished = true
		return
	if index == -2:
		_enter(node.goto_after)
		return
	var raw: Array = node.get("options", [])
	if index < 0 or index >= raw.size():
		finished = true
		return
	var opt: Dictionary = raw[index]
	game.apply_effects(opt.get("effects", []))
	_enter(opt.get("goto", "end"))
