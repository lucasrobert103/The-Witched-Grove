extends TestCase


func _brew(ings: Array, tech: Array = [], alchemy: float = 20.0) -> Dictionary:
	return AlchemyLab.evaluate(ings, tech, {"alchemy": alchemy})


func test_tonico_revigorante() -> void:
	var r := _brew(["folha_orvalho", "agua_manancial"], ["moer", "aquecer"])
	assert_true(r.success, "folha + água deve funcionar")
	assert_eq(r.output, "tonico_revigorante", "resultado: tônico")
	assert_eq(r.technique_grade, "exact", "técnica exata")


func test_cha_calmante() -> void:
	assert_eq(_brew(["lavanda_sonolenta", "mel_silvestre"]).output, "cha_calmante", "lavanda + mel = chá calmante")


func test_foco_claro() -> void:
	assert_eq(_brew(["agua_manancial", "raiz_concentracao"]).output, "pocao_foco_claro", "água + raiz = foco claro")


func test_tintura_purificadora() -> void:
	assert_eq(_brew(["petala_claridade", "cristal_lunar", "trevo_quatro"]).output, "tintura_purificadora", "rota alquímica do Ato I")


func test_adubo_vital() -> void:
	assert_eq(_brew(["folha_orvalho", "trevo_quatro"]).output, "adubo_vital", "folha + trevo = adubo")


func test_propriedade_precisa_de_dois() -> void:
	var p := AlchemyLab.active_properties(["folha_orvalho", "cogumelo_brasa"])
	assert_true("vitalidade" in p.active, "vitalidade compartilhada desperta")
	assert_false("claridade" in p.active, "claridade em um só ingrediente não desperta")


func test_incompatibilidade_anula() -> void:
	# Cogumelo-Brasa + Pimenta-Dragão + Folha + Água: calor (2) e frio (2) despertam e se anulam.
	var p := AlchemyLab.active_properties(["cogumelo_brasa", "pimenta_dragao", "folha_orvalho", "agua_manancial"])
	assert_false("calor" in p.active, "calor anulado")
	assert_false("frio" in p.active, "frio anulado")
	assert_eq(p.cancelled.size(), 1, "um par anulado")
	var ps := AlchemyLab.active_properties(["cogumelo_brasa", "pimenta_dragao", "folha_orvalho", "agua_manancial"], true)
	assert_true("calor" in ps.active and "frio" in ps.active, "Estabilização ignora a primeira incompatibilidade")


func test_falha_explica_porque() -> void:
	var r := _brew(["pedra_comum", "po_estrela"])
	assert_false(r.success, "sem propriedades em comum")
	assert_true(r.insight.length() > 10, "falha gera intuição explicativa")
	assert_eq(r.output, "mistura_turva", "falha produz Mistura Turva")


func test_proibicao_interfere() -> void:
	# Tinta de Lula traz Turvo: com Pétala + Cristal + Trevo + Tinta, a tintura é bloqueada? (turvo precisa de 2)
	var r := _brew(["agua_manancial", "raiz_concentracao", "tinta_lula", "cogumelo_brasa"])
	# volatilidade (tinta, cogumelo) desperta e é proibida no Foco Claro; estabilidade×volatilidade anulam.
	assert_false(r.output == "pocao_foco_claro", "volatilidade impede o Foco Claro")


func test_ingrediente_duplicado() -> void:
	var r := _brew(["folha_orvalho", "folha_orvalho"])
	assert_true(r.error != "", "duplicado gera erro")


func test_minimo_dois() -> void:
	assert_true(_brew(["folha_orvalho"]).error != "", "mínimo de 2 ingredientes")


func test_nivel_de_alquimia() -> void:
	var r := _brew(["petala_claridade", "cristal_lunar", "trevo_quatro"], [], 0.0)
	assert_false(r.output == "tintura_purificadora", "tintura exige Alquimia 5")
	assert_true("Alquimia" in r.insight or r.success, "explica falta de prática (ou cai em receita mais simples)")


func test_fator_tecnica() -> void:
	assert_eq(AlchemyLab.technique_factor(["moer", "aquecer"], ["moer", "aquecer"]).grade, "exact")
	assert_eq(AlchemyLab.technique_factor(["aquecer", "moer"], ["moer", "aquecer"]).grade, "same_steps")
	assert_eq(AlchemyLab.technique_factor(["moer"], ["moer", "aquecer"]).grade, "partial")
	assert_eq(AlchemyLab.technique_factor(["destilar"], ["moer", "aquecer"]).grade, "none")


func test_qualidade_limites() -> void:
	var r := AlchemyLab.evaluate(["folha_orvalho", "agua_manancial"], ["moer", "aquecer"], {"alchemy": 100.0, "qualities": [1.5, 1.5], "bonus": 1.0})
	assert_near(r.quality, 1.5, 0.001, "qualidade máxima 1.5")
	var r2 := AlchemyLab.evaluate(["folha_orvalho", "agua_manancial"], [], {"alchemy": 0.0, "qualities": [0.1, 0.1]})
	assert_near(r2.quality, 0.3, 0.001, "qualidade mínima 0.3")


func test_brew_via_game_ensina_e_registra() -> void:
	Game.give_item("folha_orvalho", 1, 1.0, true)
	var r := Game.brew(["folha_orvalho", "agua_manancial"], ["moer", "aquecer"])
	assert_true(r.success, "preparo pelo Game")
	assert_eq(Game.inventory.count("tonico_revigorante"), 1, "tônico no inventário")
	assert_eq(Game.inventory.count("folha_orvalho"), 0, "ingrediente consumido")
	assert_true(Game.has_flag("crafted.tonico_revigorante"), "flag de fabricação")
	assert_true("vitalidade" in Game.grimoire.revealed_props("agua_manancial"), "experimento revela propriedade")


func test_experimentacao_descobre_receita() -> void:
	Game.give_item("lavanda_sonolenta", 1, 1.0, true)
	Game.give_item("mel_silvestre", 1, 1.0, true)
	assert_false(Game.grimoire.knows_recipe("cha_calmante"), "ainda não conhece")
	var r := Game.brew(["lavanda_sonolenta", "mel_silvestre"], ["aquecer", "mexer"])
	assert_true(r.get("new_recipe", false), "descobriu por experimentação")
	assert_true(Game.grimoire.knows_recipe("cha_calmante"), "receita anotada")
