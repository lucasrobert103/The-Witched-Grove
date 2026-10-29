extends TestCase


func test_cronograma_de_revelacao() -> void:
	var g := Grimoire.new()
	assert_eq(g.on_obtained("folha_orvalho").size(), 2, "1ª: 2 propriedades")
	assert_eq(g.on_obtained("folha_orvalho").size(), 1, "2ª: +1")
	g.on_obtained("folha_orvalho")
	g.on_obtained("folha_orvalho")
	g.on_obtained("folha_orvalho")
	g.on_obtained("folha_orvalho")
	assert_true(g.all_props_revealed("folha_orvalho"), "todas reveladas após 6 obtenções")


func test_bestiario() -> void:
	var g := Grimoire.new()
	assert_true(g.add_bestiary_note("lumecula"), "1ª anotação")
	assert_true(g.add_bestiary_note("lumecula", 3), "pula até a 3ª")
	assert_false(g.add_bestiary_note("lumecula"), "não passa do total")
	assert_eq(g.bestiary_notes("lumecula"), 3)


func test_insights_unicos() -> void:
	var g := Grimoire.new()
	assert_true(g.add_insight("Calor e Frio se anularam."))
	assert_false(g.add_insight("Calor e Frio se anularam."), "não duplica")


func test_completude_cresce() -> void:
	var before := Game.grimoire.completeness()
	Game.read_page("ondina_1")
	Game.give_item("folha_orvalho", 1)
	assert_true(Game.grimoire.completeness() > before, "descobertas aumentam a completude")


func test_simbolos_da_pagina() -> void:
	Game.read_page("ondina_2")
	assert_eq(Game.grimoire.symbols.get("estrela_cinco", ""), "luz", "símbolo compreendido")
