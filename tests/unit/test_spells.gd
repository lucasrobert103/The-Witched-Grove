extends TestCase


func test_aprender_lendo() -> void:
	assert_false(Game.spells.is_known("botany:crescimento_rapido"), "desconhecido no início")
	var r := Game.read_page("ondina_1")
	assert_eq(r.learned, "botany:crescimento_rapido", "1ª leitura ensina o padrão")
	assert_near(Game.spells.get_knowledge("botany:crescimento_rapido"), 10.0, 0.001, "10% por leitura")
	assert_eq(Game.spells.slots[0], "botany:crescimento_rapido", "equipa no 1º slot livre")


func test_releitura_limitada() -> void:
	for i in 7:
		Game.read_page("ondina_1")
	assert_near(Game.spells.get_knowledge("botany:crescimento_rapido"), 50.0, 0.001, "máximo de 5 leituras úteis")


func test_lancar_consome_mana_e_recarga() -> void:
	Game.read_page("ondina_1")
	var mana := Game.stats.mana
	var r := Game.cast_spell("botany:crescimento_rapido")
	assert_true(r.ok, "lançou")
	assert_near(Game.stats.mana, mana - 12.0, 0.001, "custo 12")
	assert_near(Game.spells.get_knowledge("botany:crescimento_rapido"), 15.0, 0.001, "+5% por uso")
	var r2 := Game.cast_spell("botany:crescimento_rapido")
	assert_false(r2.ok, "em recarga")
	assert_true("recompondo" in r2.reason, "explica recarga")
	Game.spells.tick(10.0)
	assert_true(Game.spells.can_cast("botany:crescimento_rapido", Game.stats, Game.inventory).ok, "recarga termina")


func test_motivos_claros() -> void:
	var c := Game.spells.can_cast("astral:visao_noturna", Game.stats, Game.inventory)
	assert_true("compreende" in c.reason, "não aprendido")
	Game.spells.add_knowledge("astral:visao_noturna", 20.0)
	c = Game.spells.can_cast("astral:visao_noturna", Game.stats, Game.inventory)
	assert_true("exige" in c.reason, "nível de escola insuficiente")
	Game.stats.add_school_xp("astral", 10.0)
	Game.stats.mana = 1.0
	c = Game.spells.can_cast("astral:visao_noturna", Game.stats, Game.inventory)
	assert_true("Mana" in c.reason, "mana insuficiente")


func test_custo_de_ingredientes() -> void:
	Game.spells.add_knowledge("alchemy:transmutar_essencia", 50.0)
	Game.stats.schools["alchemy"] = 40.0
	var c := Game.spells.can_cast("alchemy:transmutar_essencia", Game.stats, Game.inventory)
	assert_true("Faltam" in c.reason, "exige pedras")
	Game.give_item("pedra_comum", 3, 1.0, true)
	var r := Game.cast_spell("alchemy:transmutar_essencia")
	assert_true(r.ok, "transmutou")
	assert_eq(Game.inventory.count("cristal_lunar"), 1, "ganhou cristal")
	assert_eq(Game.inventory.count("pedra_comum"), 0, "pedras consumidas")


func test_maestria_reduz_custo() -> void:
	Game.spells.add_knowledge("astral:lume", 100.0)
	assert_near(Game.spells.mana_cost("astral:lume"), 8.0, 0.001, "maestria: -20%")


func test_bonus_lunar() -> void:
	assert_near(SpellSystem.moon_bonus("astral", 4), 0.2, 0.001, "lua cheia +20% astral")
	assert_near(SpellSystem.moon_bonus("illusion", 0), 0.2, 0.001, "lua nova +20% ilusão")
	assert_near(SpellSystem.moon_bonus("botany", 4), 0.0, 0.001, "botânica sem bônus")


func test_efeitos_proprios() -> void:
	Game.spells.add_knowledge("protection:escudo_pessoal", 10.0)
	Game.cast_spell("protection:escudo_pessoal")
	assert_true(Game.has_buff("shield"), "escudo ativo")
	assert_near(Game.damage(50.0), 0.0, 0.001, "escudo anula dano")
	Game.spells.add_knowledge("alchemy:dissolucao_precisa", 10.0)
	Game.cast_spell("alchemy:dissolucao_precisa")
	assert_true(Game.pending_brew_bonus > 0.0, "bônus de preparo pendente")


func test_desbloqueio_por_experimentacao() -> void:
	for rid in DataRegistry.recipe_order.slice(0, 7):
		Game.grimoire.learn_recipe(rid)
	Game._check_experimentation_unlocks()
	assert_false(Game.spells.is_known("alchemy:transmutar_essencia"), "7 receitas não bastam")
	Game.grimoire.learn_recipe(DataRegistry.recipe_order[7])
	Game._check_experimentation_unlocks()
	assert_true(Game.spells.is_known("alchemy:transmutar_essencia"), "8 receitas revelam Transmutação de Essência")
	assert_false(Game.spells.is_known("transmutation:replicacao"), "feitiços sem efeito na V1 não são revelados")
