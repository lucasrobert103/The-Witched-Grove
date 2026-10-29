extends TestCase


func test_plantar_crescer_colher() -> void:
	var g := Game.garden
	var r := Game.garden_plant(0, "semente_orvalheira")
	assert_false(r.ok, "jardim bloqueado no início (terra bruta)")
	Game.add_school_xp("botany", 1.0)
	assert_eq(Game.house.garden_plots(), 4, "aprender Botânica desbloqueia 4 canteiros")
	r = Game.garden_plant(0, "semente_orvalheira")
	assert_true(r.ok, "plantou")
	assert_false(g.is_ready(0), "recém-plantada")
	g.water(0)
	g.tick_hours(30.0, "primavera", "chuva", 0, 0.0)
	assert_true(g.is_ready(0), "orvalheira (1 dia) pronta em 30h na primavera")
	var h := Game.garden_harvest(0)
	assert_true(h.ok, "colheu")
	assert_true(Game.inventory.count("folha_orvalho") >= 3, "rendimento base 3")
	assert_true(g.is_empty(0), "canteiro vazio após colheita")


func test_multiplicadores_estacao() -> void:
	var g := Game.garden
	var p: Dictionary = DataRegistry.plants["lavanda"]
	assert_near(g.season_mult(p, "verao"), 1.25, 0.001, "estação ideal")
	assert_near(g.season_mult(p, "outono"), 1.0, 0.001, "estação vizinha")
	assert_near(g.season_mult(p, "inverno"), 0.5, 0.001, "estação oposta")


func test_agua_seca_desacelera() -> void:
	var g := Game.garden
	Game.add_school_xp("botany", 1.0)
	Game.give_item("semente_lucidalia", 1, 1.0, true)
	Game.garden_plant(1, "semente_lucidalia")
	g.plots[1].water = 0.0
	var b := g.growth_breakdown(1, "primavera", 0, 0.0)
	assert_near(float(b.parts.agua), 0.25, 0.001, "seco → ×0.25")
	g.water(1)
	b = g.growth_breakdown(1, "primavera", 0, 0.0)
	assert_near(float(b.parts.agua), 1.0, 0.001, "regado → ×1")


func test_evaporacao_e_runas() -> void:
	var g := Game.garden
	g.plots[2].water = 1.0
	g.tick_hours(24.0, "verao", "limpo", 0, 0.0)
	assert_near(float(g.plots[2].water), 0.5, 0.01, "evapora 0.5 por dia")
	g.plots[3].water = 1.0
	g.protect(3, 3.0)
	g.tick_hours(24.0, "verao", "limpo", 0, 0.0)
	assert_near(float(g.plots[3].water), 1.0, 0.001, "Círculo de Proteção impede evaporação")


func test_adubo() -> void:
	Game.add_school_xp("botany", 1.0)
	Game.garden_plant(0, "semente_orvalheira")
	var r := Game.garden_fertilize(0)
	assert_false(r.ok, "precisa de adubo")
	Game.give_item("adubo_vital", 1, 1.0, true)
	r = Game.garden_fertilize(0)
	assert_true(r.ok, "adubou")
	var b := Game.garden.growth_breakdown(0, "primavera", 0, 0.0)
	assert_near(float(b.parts.adubo), 1.5, 0.001, "adubo ×1.5")


func test_colheita_devolve_semente_e_revela() -> void:
	Game.add_school_xp("botany", 1.0)
	Game.garden_plant(0, "semente_orvalheira")
	Game.garden.plots[0].growth = 1.0
	Game.garden_harvest(0)
	assert_eq(Game.inventory.count("semente_orvalheira"), 2, "1 semente usada, 1 devolvida + 1 inicial")
	assert_true(Game.grimoire.revealed_props("folha_orvalho").size() >= 2, "1ª obtenção revela 2 propriedades")
