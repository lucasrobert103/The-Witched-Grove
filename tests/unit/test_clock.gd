extends TestCase


func test_inicio() -> void:
	var c := WorldClock.new()
	assert_eq(c.day(), 1, "dia 1")
	assert_near(c.hour(), 7.0, 0.001, "07:00")
	assert_eq(c.season(), "primavera", "começa na primavera")
	assert_eq(c.time_string(), "07:00")


func test_30_minutos_reais_por_dia() -> void:
	var c := WorldClock.new()
	c.advance_real(1800.0)
	assert_eq(c.day(), 2, "30 min reais = 1 dia")


func test_estacoes_e_lua() -> void:
	var c := WorldClock.new()
	c.advance_minutes(5 * 1440.0)
	assert_eq(c.season(), "verao", "5 dias por estação")
	c.advance_minutes(15 * 1440.0)
	assert_eq(c.season(), "primavera", "ciclo de 20 dias")
	var c2 := WorldClock.new()
	c2.advance_minutes(4 * 1440.0)
	assert_true(c2.is_full_moon(), "dia 5 é lua cheia")


func test_clima_deterministico() -> void:
	var c := WorldClock.new()
	for d in range(1, 41):
		assert_eq(c.weather_for_day(d), c.weather_for_day(d), "clima repetível")
		if c.season_for_day(d) != "inverno":
			assert_true(c.weather_for_day(d) != "neve", "neve só no inverno")
	assert_eq(c.weather(), "limpo", "primeiro dia é limpo")


func test_noite() -> void:
	var c := WorldClock.new()
	assert_false(c.is_night(), "07:00 não é noite")
	c.advance_minutes(13 * 60.0)
	assert_true(c.is_night(), "20:00 é noite")
	assert_near(c.night_factor(), 1.0, 0.001, "noite plena")
