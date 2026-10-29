extends TestCase


func test_formulas_iniciais() -> void:
	var s := Game.stats
	assert_eq(s.attr("intellect"), 5, "atributos começam em 5")
	assert_near(s.max_health(), 150.0, 0.001, "Saúde = 100 + END×10")
	assert_near(s.max_mana(), 75.0, 0.001, "Mana = 50 + INT×5")
	assert_near(s.school("botany"), 0.0, 0.001, "escolas começam em 0")


func test_multiplicador_aprendizado() -> void:
	var s := Game.stats
	assert_near(s.learning_multiplier("botany"), 1.0, 0.001, "atributos 5 → ×1.0")
	s.attributes["insight"] = 10
	s.attributes["dexterity"] = 10
	assert_near(s.learning_multiplier("botany"), 1.25, 0.001, "atributos 10 → ×1.25")
	s.attributes["insight"] = 0
	s.attributes["dexterity"] = 0
	assert_near(s.learning_multiplier("botany"), 0.75, 0.001, "atributos 0 → ×0.75")


func test_xp_limitado_a_100() -> void:
	var s := Game.stats
	s.add_school_xp("alchemy", 500.0)
	assert_near(s.school("alchemy"), 100.0, 0.001, "escola limitada a 100")


func test_talentos_e_atributos() -> void:
	var s := Game.stats
	s.add_school_xp("alchemy", 60.0)
	assert_eq(s.talent_points, 1, "60 de conhecimento → 1 talento")
	var hp_before := s.max_health()
	assert_true(s.spend_talent("endurance"), "gastar talento")
	assert_near(s.max_health(), hp_before + 10.0, 0.001, "END +1 → saúde +10")
	assert_false(s.spend_talent("endurance"), "sem talentos restantes")


func test_especializacao() -> void:
	var s := Game.stats
	s.add_school_xp("alchemy", 40.0)
	assert_false(s.has_specialization("criadora_pocoes"), "precisa das duas escolas")
	s.add_school_xp("botany", 40.0)
	assert_true(s.has_specialization("criadora_pocoes"), "Alquimia 40 + Botânica 40 → Criadora de Poções")


func test_serializacao() -> void:
	var s := Game.stats
	s.add_school_xp("runes", 12.0)
	s.health = 33.0
	var d := s.to_dict()
	var s2 := CharacterStats.new()
	s2.from_dict(d)
	assert_near(s2.school("runes"), 12.0, 0.001, "escola restaurada")
	assert_near(s2.health, 33.0, 0.001, "saúde restaurada")
