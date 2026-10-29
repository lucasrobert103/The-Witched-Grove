class_name Interactable
extends Node3D
## Base de tudo que a protagonista pode tocar, ler, colher ou enfeitiçar.
## O jogador escolhe o Interactable mais próximo dentro de `radius`.

var prompt: String = "Interagir"
var radius: float = 2.2
var marker_height: float = 1.6
var map_label: String = ""        # aparece no minimapa quando não vazio
var map_color: Color = Color("#f3c74f")


func _enter_tree() -> void:
	add_to_group("interactable")


func can_interact() -> bool:
	return visible


func get_prompt() -> String:
	return prompt


func interact(_player: Node) -> void:
	pass


## Reage a um feitiço lançado por perto. Retorna true se houve efeito.
func on_spell(_tags: Array, _result: Dictionary) -> bool:
	return false


## Chamado pelo mundo quando o estado do jogo muda (flags, dia, carregamento).
func refresh_state() -> void:
	pass


func world() -> Node:
	return get_tree().get_first_node_in_group("game_world")


func say(text: String, kind: String = "info") -> void:
	EventBus.notify.emit(text, kind)
