class_name GardenPanel
extends ModalPanel
## Canteiro: plantar, regar, adubar, entender por que cresce rápido ou devagar.

var plot := 0


func open(payload: Dictionary) -> void:
	plot = int(payload.get("plot", 0))
	build_frame("Jardim — Canteiro %d" % (plot + 1), 0.7, 0.9)
	_refresh()


func _refresh() -> void:
	clear_content()
	var pl := Game.garden.plot(plot)
	var light := GardenPlot._light_name(pl.light)
	content.add_child(UITheme.label("Luz: %s · Água: %d%% · Estação: %s · Lua %s" % [light, int(float(pl.water) * 100.0), DataRegistry.season_name(Game.clock.season()), Game.clock.moon_name()], 0.9, UITheme.PARCHMENT, true))
	if pl.plant == "":
		content.add_child(UITheme.label("Escolha uma semente:", 1.0, UITheme.GOLD))
		var seeds := Game.inventory.ids_by_category("semente")
		if seeds.is_empty():
			content.add_child(UITheme.label("Você não tem sementes. Bento vende algumas na carroça ao sul.", 0.95, Color(0, 0, 0, 0), true))
		for sid in seeds:
			var seed_id: String = sid
			var p := DataRegistry.plant_for_seed(seed_id)
			var tip := "%s ×%d — %s, %s, %.1f dia(s)" % [DataRegistry.item_name(seed_id), Game.inventory.count(seed_id), DataRegistry.season_name(p.season), GardenPlot._light_name(p.light), float(p.growth_days)]
			var b := UITheme.button(tip, func(): _plant(seed_id))
			b.alignment = HORIZONTAL_ALIGNMENT_LEFT
			content.add_child(b)
	else:
		var p: Dictionary = DataRegistry.plants[pl.plant]
		var b := Game.garden.growth_breakdown(plot, Game.clock.season(), Game.clock.moon_phase(), Game.stats.school("botany"))
		var parts: Dictionary = b.parts
		content.add_child(UITheme.label("%s — %d%%" % [p.name, int(float(pl.growth) * 100.0)], 1.2, UITheme.GOLD))
		var growth := UITheme.bar(Color("#7dffa0"), 26)
		growth.max_value = 1.0
		growth.value = float(pl.growth)
		content.add_child(growth)
		var lines: Array = []
		lines.append("Velocidade: ×%.2f · Pronta em ~%.1f h de jogo" % [b.mult, b.hours_left])
		lines.append(_explain("Estação", parts.estacao, "ideal: %s" % DataRegistry.season_name(p.season)))
		lines.append(_explain("Luz", parts.luz, "prefere %s" % GardenPlot._light_name(p.light)))
		lines.append(_explain("Água", parts.agua, "seca reduz para ×0,25 — regue!"))
		lines.append(_explain("Adubo", parts.adubo, "Adubo Vital acelera ×1,5"))
		if p.get("lunar", false):
			lines.append(_explain("Lua", parts.lua, "planta lunar: +25% na lua cheia"))
		lines.append(_explain("Maestria", parts.maestria, "Botânica Arcana"))
		content.add_child(UITheme.rich("\n".join(lines), 0.88))
		if Game.garden.is_ready(plot):
			content.add_child(UITheme.button("Colher", _harvest, 64))
	var row := HFlowContainer.new()
	content.add_child(row)
	row.add_child(UITheme.button("Regar", _water))
	if pl.plant != "":
		row.add_child(UITheme.button("Adubar (%d)" % Game.inventory.count("adubo_vital"), _fertilize))
		row.add_child(UITheme.button("Arrancar", _remove))
	row.add_child(UITheme.button("Fechar", close))
	content.add_child(UITheme.label("Dica: Crescimento Rápido acelera tudo por perto; Círculo de Proteção impede a evaporação; Brisa Suave poliniza plantas maduras.", 0.8, UITheme.GOLD_DIM, true))


func _explain(name_: String, v: float, why: String) -> String:
	var col := "#7dffa0" if v > 1.001 else ("#ff9a8a" if v < 0.999 else "#f6f1ff")
	return "[color=%s]%s ×%.2f[/color] — %s" % [col, name_, v, why]


func _plant(seed_id: String) -> void:
	if Game.garden_plant(plot, seed_id).ok:
		AudioManager.play_sfx("plant")
	_refresh()


func _water() -> void:
	Game.garden_water(plot)
	AudioManager.play_sfx("water")
	_refresh()


func _fertilize() -> void:
	var r := Game.garden_fertilize(plot)
	if not r.ok:
		EventBus.notify.emit(r.reason, "warning")
	_refresh()


func _harvest() -> void:
	Game.garden_harvest(plot)
	AudioManager.play_sfx("harvest")
	_refresh()


func _remove() -> void:
	Game.garden.remove_plant(plot)
	EventBus.garden_changed.emit()
	_refresh()
