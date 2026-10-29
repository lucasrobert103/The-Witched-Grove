class_name TestCase
extends RefCounted
## Base mínima de testes (sem dependências externas).

var failures: Array[String] = []
var asserts: int = 0
var current_test: String = ""


func before_each() -> void:
	Game.new_game()


func _fail(msg: String) -> void:
	failures.append("%s: %s" % [current_test, msg])


func assert_true(cond: bool, msg: String = "esperava verdadeiro") -> void:
	asserts += 1
	if not cond:
		_fail(msg)


func assert_false(cond: bool, msg: String = "esperava falso") -> void:
	assert_true(not cond, msg)


func assert_eq(a: Variant, b: Variant, msg: String = "") -> void:
	asserts += 1
	if typeof(a) != typeof(b) and not (typeof(a) in [TYPE_INT, TYPE_FLOAT] and typeof(b) in [TYPE_INT, TYPE_FLOAT]):
		_fail("%s (tipos diferentes: %s vs %s)" % [msg, str(a), str(b)])
	elif a != b:
		_fail("%s (obtido %s, esperado %s)" % [msg, str(a), str(b)])


func assert_near(a: float, b: float, eps: float = 0.001, msg: String = "") -> void:
	asserts += 1
	if absf(a - b) > eps:
		_fail("%s (obtido %f, esperado %f ± %f)" % [msg, a, b, eps])


## Escolhe uma opção de diálogo cujo texto contém `fragment`. Retorna false se não achar.
func choose_option(fragment: String) -> bool:
	for o in Game.dialogue.options():
		if fragment in o.text:
			Game.dialogue.choose(o.index)
			Game.refresh_quests()
			return true
	_fail("opção de diálogo não encontrada: '%s' em %s" % [fragment, str(Game.dialogue.options())])
	return false


func talk(npc_id: String) -> bool:
	var ok := Game.dialogue.start(npc_id)
	Game.refresh_quests()
	return ok
