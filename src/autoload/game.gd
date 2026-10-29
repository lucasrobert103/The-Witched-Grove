extends Node
## Orquestrador central do estado do jogo.
## Possui as instâncias dos sistemas (lógica pura) e aplica as regras que
## atravessam sistemas: recompensas, descobertas, consequências, tempo.
## O mundo 3D e a UI conversam com o jogo APENAS por aqui e pelo EventBus.

const SAVE_VERSION := 1
const START_CURRENCY := 120
const REGEN_MANA_PER_SEC := 0.5
const REGEN_HEALTH_PER_SEC := 0.25
const GARDEN_TICK_HOURS := 0.25
const DAILY_ORDERS := [
	["tonico_revigorante", 1], ["folha_orvalho", 4], ["petala_claridade", 3], ["cha_calmante", 1],
	["adubo_vital", 1], ["lavanda_sonolenta", 3], ["pocao_foco_claro", 1], ["casca_salgueiro", 3],
]
const DAILY_ORDER_REWARD := 50

var stats: CharacterStats
var inventory: Inventory
var grimoire: Grimoire
var spells: SpellSystem
var garden: Garden
var clock: WorldClock
var quests: QuestLog
var house: House
var dialogue: DialogueRunner

var flags: Dictionary = {}
var rep: Dictionary = {}
var buffs: Dictionary = {}               # nome -> segundos restantes
var wild_harvested: Dictionary = {}      # node_id -> dia da colheita
var player_state: Dictionary = {}        # posição salva pelo mundo
var daily_order_done_day: int = 0
var pending_brew_bonus: float = 0.0
var pending_stabilize: bool = false
var last_obtained_ingredient: String = ""
var playtime: float = 0.0
var world_running: bool = false
var started: bool = false

var _hour_accum: float = 0.0
var _last_day: int = 1
var _last_season: String = ""
var _last_weather: String = ""
var _refresh_queued: bool = false
var _refreshing: bool = false


func _ready() -> void:
	_setup_input()
	new_game()


# =================================================================== ciclo de vida

func new_game() -> void:
	stats = CharacterStats.new()
	inventory = Inventory.new()
	grimoire = Grimoire.new()
	spells = SpellSystem.new()
	garden = Garden.new()
	clock = WorldClock.new()
	quests = QuestLog.new()
	house = House.new()
	dialogue = DialogueRunner.new(self)
	flags = {}
	rep = {}
	for fid in DataRegistry.faction_order:
		rep[fid] = int(DataRegistry.factions[fid].get("start", 0))
	buffs = {}
	wild_harvested = {}
	player_state = {}
	daily_order_done_day = 0
	pending_brew_bonus = 0.0
	pending_stabilize = false
	last_obtained_ingredient = ""
	playtime = 0.0
	_hour_accum = 0.0
	_last_day = clock.day()
	_last_season = clock.season()
	_last_weather = clock.weather()

	inventory.capacity = house.storage_capacity()
	inventory.currency = START_CURRENCY
	inventory.add("semente_orvalheira", 2)
	inventory.add("semente_lucidalia", 1)
	inventory.add("agua_manancial", 1)
	grimoire.learn_recipe("tonico_revigorante")
	grimoire.log_entry(1, clock.time_string(), "Ondina não voltou. O grimório dela está no atril da varanda.")
	quests.start("mq01_grimorio", 1)
	started = false


func begin() -> void:
	## Chamado quando o mundo 3D está pronto.
	started = true
	world_running = true
	refresh_quests()


func _process(delta: float) -> void:
	if not world_running or get_tree().paused:
		return
	playtime += delta
	var minutes := clock.advance_real(delta)
	_on_minutes_passed(minutes)
	spells.tick(delta)
	_tick_buffs(delta)
	if stats.mana < stats.max_mana() or stats.health < stats.max_health():
		stats.mana = minf(stats.max_mana(), stats.mana + REGEN_MANA_PER_SEC * delta)
		stats.health = minf(stats.max_health(), stats.health + REGEN_HEALTH_PER_SEC * delta)


func advance_time(minutes: float) -> void:
	## Avança o relógio (leitura, preparo, sono) processando o jardim em blocos.
	var left := minutes
	while left > 0.0:
		var step := minf(left, 60.0)
		clock.advance_minutes(step)
		_on_minutes_passed(step)
		left -= step


func _on_minutes_passed(minutes: float) -> void:
	_hour_accum += minutes / 60.0
	if _hour_accum >= GARDEN_TICK_HOURS:
		var changed := garden.tick_hours(_hour_accum, clock.season(), clock.weather(), clock.moon_phase(), stats.school("botany"))
		_hour_accum = 0.0
		if changed:
			EventBus.garden_changed.emit()
	EventBus.time_changed.emit(clock.hour())
	if clock.day() != _last_day:
		_on_new_day()


func _on_new_day() -> void:
	_last_day = clock.day()
	EventBus.day_changed.emit(_last_day)
	var msg := "Dia %d · %s · Lua %s" % [_last_day, DataRegistry.season_name(clock.season()), clock.moon_name()]
	EventBus.notify.emit(msg, "info")
	if clock.season() != _last_season:
		_last_season = clock.season()
		EventBus.season_changed.emit(_last_season)
		EventBus.notify.emit("Começou a estação: %s." % DataRegistry.season_name(_last_season), "discovery")
	if clock.weather() != _last_weather:
		_last_weather = clock.weather()
		EventBus.weather_changed.emit(_last_weather)
	if clock.is_full_moon():
		EventBus.notify.emit("Lua cheia! Magia Astral +20% esta noite.", "discovery")
	EventBus.garden_changed.emit()
	request_quest_refresh()


# =================================================================== flags e reputação

func has_flag(f: String) -> bool:
	return bool(flags.get(f, false))


func set_flag(f: String, value: bool = true) -> void:
	if has_flag(f) == value:
		return
	if value:
		flags[f] = true
	else:
		flags.erase(f)
	EventBus.flag_changed.emit(f, value)
	request_quest_refresh()


func reputation(faction_id: String) -> int:
	return int(rep.get(faction_id, 0))


func change_rep(faction_id: String, delta: int) -> void:
	if not DataRegistry.factions.has(faction_id) or delta == 0:
		return
	var v := clampi(reputation(faction_id) + delta, -100, 100)
	rep[faction_id] = v
	EventBus.reputation_changed.emit(faction_id, v)
	EventBus.notify.emit("%s %+d (%s)" % [DataRegistry.factions[faction_id].name, delta, DataRegistry.reputation_tier(v)], "info")
	request_quest_refresh()


# =================================================================== itens e moeda

func give_item(id: String, n: int = 1, q: float = 1.0, silent: bool = false) -> int:
	var added := inventory.add(id, n, q)
	if added < n:
		EventBus.notify.emit("Sem espaço para %d× %s. Melhore o Armazém." % [n - added, DataRegistry.item_name(id)], "warning")
	if added > 0:
		if not silent:
			EventBus.notify.emit("+%d %s" % [added, DataRegistry.item_name(id)], "item")
		if DataRegistry.ingredients.has(id):
			last_obtained_ingredient = id
			var first := not grimoire.is_catalogued(id)
			var newly := grimoire.on_obtained(id)
			if first:
				discover("planta", id, "Catalogado no grimório: %s." % DataRegistry.item_name(id))
			for p in newly:
				if not first:
					discover("propriedade", id, "%s revela: %s." % [DataRegistry.item_name(id), DataRegistry.property_name(p)])
		EventBus.inventory_changed.emit()
		request_quest_refresh()
	return added


func take_item(id: String, n: int = 1) -> bool:
	if not inventory.remove(id, n):
		return false
	EventBus.inventory_changed.emit()
	request_quest_refresh()
	return true


func give_ep(amount: int) -> void:
	inventory.add_currency(amount)
	EventBus.currency_changed.emit(inventory.currency)
	if amount > 0:
		EventBus.notify.emit("+%d EP" % amount, "item")


func take_ep(amount: int) -> bool:
	if not inventory.spend_currency(amount):
		return false
	EventBus.currency_changed.emit(inventory.currency)
	return true


func use_item(id: String) -> Dictionary:
	if inventory.count(id) <= 0:
		return {"ok": false, "reason": "Você não tem %s." % DataRegistry.item_name(id)}
	var item: Dictionary = DataRegistry.items.get(id, {})
	var use: Dictionary = item.get("use", {})
	var q := inventory.quality(id)
	match use.get("type", "none"):
		"heal":
			take_item(id, 1)
			heal(float(use.amount) * q)
			EventBus.notify.emit("Você bebeu %s." % item.name, "info")
		"mana_pct":
			take_item(id, 1)
			stats.mana = minf(stats.max_mana(), stats.mana + stats.max_mana() * float(use.amount) * q)
			EventBus.stats_changed.emit()
			EventBus.notify.emit("Você bebeu %s." % item.name, "info")
		"buff":
			take_item(id, 1)
			add_buff(use.buff, float(use.duration) * q)
			EventBus.notify.emit("Você usou %s." % item.name, "info")
		"grow_area":
			take_item(id, 1)
			EventBus.spell_cast.emit("item:" + id, {"ok": true, "spell": "item:" + id, "tags": ["grow", "grow_strong"], "power": 1.5 * q, "radius": 7.0})
			EventBus.notify.emit("Tudo ao redor cresce num suspiro verde!", "discovery")
		"fertilizer":
			return {"ok": false, "reason": "Use o Adubo Vital em um canteiro do jardim."}
		"give":
			return {"ok": false, "reason": "Ofereça %s a quem precisa (fale com a pessoa ou criatura)." % item.name}
		_:
			return {"ok": false, "reason": "%s não pode ser usado diretamente." % item.name}
	return {"ok": true, "reason": ""}


func heal(amount: float) -> void:
	stats.health = minf(stats.max_health(), stats.health + amount)
	EventBus.stats_changed.emit()


func damage(amount: float, source: String = "") -> float:
	if has_buff("shield") or amount <= 0.0:
		return 0.0
	stats.health = maxf(0.0, stats.health - amount)
	EventBus.stats_changed.emit()
	if stats.health <= 0.0:
		faint(source)
	return amount


func faint(_source: String = "") -> void:
	EventBus.player_health_depleted.emit()
	var h := clock.hour()
	var minutes_to_morning := ((24.0 - h) + 7.0) * 60.0 if h >= 7.0 else (7.0 - h) * 60.0
	advance_time(minutes_to_morning)
	stats.health = stats.max_health() * 0.5
	stats.mana = stats.max_mana() * 0.5
	EventBus.stats_changed.emit()
	EventBus.teleport_requested.emit("home")
	EventBus.notify.emit("Você desmaiou e acordou em casa. Nimbus jura que te arrastou sozinho.", "warning")


# =================================================================== escolas e descobertas

func add_school_xp(school: String, amount: float) -> float:
	var gained := stats.add_school_xp(school, amount)
	if gained > 0.0:
		for rid in house.check_unlocks(stats):
			EventBus.notify.emit("Novo cômodo desbloqueado: %s!" % house.def(rid).name, "discovery")
			discover("casa", rid, "A cabana ganhou vida nova: %s." % house.def(rid).name)
			EventBus.house_changed.emit()
		EventBus.stats_changed.emit()
	return gained


func discover(category: String, id: String, text: String) -> void:
	grimoire.log_entry(clock.day(), clock.time_string(), text)
	EventBus.discovery_made.emit(category, id, text)
	EventBus.notify.emit(text, "discovery")


func add_bestiary(creature_id: String, up_to: int = -1) -> bool:
	if grimoire.add_bestiary_note(creature_id, up_to):
		var c: Dictionary = DataRegistry.creatures.get(creature_id, {})
		var n := grimoire.bestiary_notes(creature_id)
		discover("bestiario", creature_id, "Bestiário — %s: %s" % [c.get("name", creature_id), c.notes[n - 1]])
		request_quest_refresh()
		return true
	return false


func observe_creature(creature_id: String) -> bool:
	var extra := int(inventory.passive_value("observe_bonus", 0))
	if stats.attr("arcane_sense") >= 7:
		extra += 1
	var target := grimoire.bestiary_notes(creature_id) + 1 + extra
	var ok := add_bestiary(creature_id, target)
	if ok:
		add_school_xp("illusion", 1.0)
	else:
		EventBus.notify.emit("Você já anotou tudo o que dá para perceber só olhando.", "info")
	return ok


func add_research(research_id: String, amount: float) -> void:
	var before := float(grimoire.research.get(research_id, 0.0))
	var v := grimoire.add_research(research_id, amount)
	if v > before:
		var r: Dictionary = DataRegistry.research.get(research_id, {})
		EventBus.notify.emit("Pesquisa \"%s\": %d%%" % [r.get("name", research_id), int(v)], "discovery")


# =================================================================== leitura

func read_page(page_id: String, spend_time: bool = true) -> Dictionary:
	var page: Dictionary = DataRegistry.pages.get(page_id, {})
	if page.is_empty():
		return {"ok": false}
	var rules := DataRegistry.page_rules
	var max_reads := int(rules.get("max_reads", 5))
	var before := grimoire.times_read(page_id)
	var count := grimoire.register_read(page_id)
	var result := {"ok": true, "first": before == 0, "count": count, "gains": before < max_reads, "learned": ""}
	if before < max_reads:
		var teaches: Dictionary = page.get("teaches", {})
		if teaches.has("spell"):
			var amount := float(rules.get("knowledge_per_read", 10)) + house.read_bonus()
			if stats.has_specialization("guardia_saber"):
				amount += 5.0
			var sid: String = teaches.spell
			if spells.add_knowledge(sid, amount):
				result.learned = sid
				discover("feitico", sid, "Novo feitiço compreendido: %s!" % spells.def(sid).name)
				EventBus.spell_learned.emit(sid)
			elif before > 0:
				EventBus.notify.emit("Compreensão de %s: %d%%" % [spells.def(sid).name, int(spells.get_knowledge(sid))], "info")
		if teaches.has("recipe") and grimoire.learn_recipe(teaches.recipe):
			discover("receita", teaches.recipe, "Receita anotada: %s." % DataRegistry.recipes[teaches.recipe].name)
			EventBus.recipe_learned.emit(teaches.recipe)
		add_school_xp(page.get("school", "astral"), float(rules.get("school_xp_per_read", 2)))
	if before == 0:
		for rid in page.get("research", {}):
			add_research(rid, float(page.research[rid]))
		grimoire.log_entry(clock.day(), clock.time_string(), "Lido: %s." % page.title)
	if spend_time:
		advance_time(float(rules.get("read_minutes", 30)))
	EventBus.page_read.emit(page_id, count)
	request_quest_refresh()
	return result


# =================================================================== magia

func spell_context() -> Dictionary:
	return {
		"moon_phase": clock.moon_phase(),
		"moon_item_bonus": float(inventory.passive_value("moon_bonus", 0.0)),
		"ritual_bonus": house.spell_power_bonus(),
	}


func cast_spell(spell_id: String) -> Dictionary:
	var r := spells.cast(spell_id, stats, inventory, spell_context())
	if not r.ok:
		EventBus.notify.emit(r.reason, "warning")
		EventBus.spell_cast.emit(spell_id, r)
		return r
	var d := spells.def(spell_id)
	r["tags"] = d.get("tags", [])
	r["radius"] = float(d.get("radius", 4.0))
	for e in d.get("effects", []):
		match e.get("type", ""):
			"brew_bonus":
				pending_brew_bonus = float(e.amount) * float(r.power)
				EventBus.notify.emit("O próximo preparo terá qualidade extra.", "info")
			"brew_stabilize":
				pending_stabilize = true
				EventBus.notify.emit("O próximo preparo ignorará uma incompatibilidade.", "info")
			"buff":
				var dur := float(e.duration) * float(r.power)
				if e.buff == "shield" and stats.has_specialization("guardia_saber"):
					dur *= 1.5
				add_buff(e.buff, dur)
			"light_orb":
				var dur2 := float(e.duration) * float(r.power)
				if stats.has_specialization("investigadora"):
					dur2 *= 2.0
				add_buff("light_orb", dur2)
			"reveal_hidden":
				add_buff("reveal", float(e.duration) * float(r.power))
			"give_item":
				give_item(e.item, int(e.amount))
			"teleport_home":
				EventBus.teleport_requested.emit("home")
			"reveal_property":
				pass   # resolvido pelo mundo (planta próxima) ou abaixo, se nada próximo
	set_flag("cast." + spell_id)
	if r.get("mastered_now", false):
		discover("maestria", spell_id, "Maestria alcançada: %s! (custo de mana -20%%)" % d.name)
	EventBus.stats_changed.emit()
	EventBus.spell_cast.emit(spell_id, r)
	return r


func identify_ingredient(ingredient_id: String) -> String:
	## Revela a próxima propriedade oculta (Identificação de Propriedades).
	if ingredient_id == "" or not DataRegistry.ingredients.has(ingredient_id):
		return ""
	var p := grimoire.reveal_next_property(ingredient_id)
	if p != "":
		discover("propriedade", ingredient_id, "%s revela: %s." % [DataRegistry.item_name(ingredient_id), DataRegistry.property_name(p)])
	else:
		EventBus.notify.emit("Você já conhece todas as propriedades de %s." % DataRegistry.item_name(ingredient_id), "info")
	return p


func add_buff(buff: String, duration: float) -> void:
	var had := has_buff(buff)
	buffs[buff] = maxf(float(buffs.get(buff, 0.0)), duration)
	if not had:
		EventBus.buff_changed.emit(buff, true)


func has_buff(buff: String) -> bool:
	return float(buffs.get(buff, 0.0)) > 0.0


func buff_left(buff: String) -> float:
	return float(buffs.get(buff, 0.0))


func _tick_buffs(delta: float) -> void:
	for b in buffs.keys():
		var left := float(buffs[b]) - delta
		if left <= 0.0:
			buffs.erase(b)
			EventBus.buff_changed.emit(b, false)
		else:
			buffs[b] = left


# =================================================================== alquimia

func brew(ingredient_ids: Array, technique: Array) -> Dictionary:
	var slots := house.lab_slots()
	if ingredient_ids.size() > slots:
		var err := {"success": false, "error": "Seu laboratório comporta %d ingredientes." % slots}
		EventBus.notify.emit(err.error, "warning")
		return err
	for id in ingredient_ids:
		if inventory.count(id) < 1:
			var err2 := {"success": false, "error": "Você não tem %s." % DataRegistry.item_name(id)}
			EventBus.notify.emit(err2.error, "warning")
			return err2
	var qualities: Array = []
	for id in ingredient_ids:
		qualities.append(inventory.quality(id))
	var bonus := pending_brew_bonus + house.lab_quality_bonus()
	if stats.has_specialization("criadora_pocoes"):
		bonus += 0.1
	var ctx := {"alchemy": stats.school("alchemy"), "qualities": qualities, "bonus": bonus, "stabilize": pending_stabilize}
	var r := AlchemyLab.evaluate(ingredient_ids, technique, ctx)
	if r.error != "":
		EventBus.notify.emit(r.error, "warning")
		return r
	for id in ingredient_ids:
		inventory.remove(id, 1)
	pending_brew_bonus = 0.0
	pending_stabilize = false

	# Experimentar ensina: propriedades despertas (ou anuladas) ficam registradas.
	var taught: Array = r.active.duplicate()
	for pair in r.cancelled:
		taught.append(pair[0])
		taught.append(pair[1])
	var revealed_count := 0
	for id in ingredient_ids:
		for p in taught:
			if grimoire.reveal_property(id, p):
				revealed_count += 1
	if revealed_count > 0:
		discover("propriedade", "", "O experimento revelou %d propriedade(s) nos ingredientes usados." % revealed_count)

	if r.success:
		var recipe: Dictionary = DataRegistry.recipes[r.recipe_id]
		give_item(r.output, 1, r.quality, true)
		r["new_recipe"] = grimoire.learn_recipe(r.recipe_id)
		if r.new_recipe:
			discover("receita", r.recipe_id, "Receita descoberta por experimentação: %s!" % recipe.name)
			EventBus.recipe_learned.emit(r.recipe_id)
		add_school_xp("alchemy", float(recipe.get("xp", 3)) * (1.5 if r.new_recipe else 1.0))
		if r.new_recipe:
			_check_experimentation_unlocks()
		set_flag("crafted." + r.recipe_id)
		set_flag("crafted.any")
		if r.insight != "":
			grimoire.add_insight(r.insight)
	else:
		give_item(r.output, 1, 0.3, true)
		add_school_xp("alchemy", 1.0)
		if grimoire.add_insight(r.insight) or stats.has_specialization("teorica"):
			discover("intuicao", "", "Anotado no grimório: %s" % r.insight)
	advance_time(20.0)
	EventBus.inventory_changed.emit()
	EventBus.brew_finished.emit(r)
	request_quest_refresh()
	return r


## Feitiços com unlock_method "experimentation" surgem de tanto experimentar:
## ao descobrir EXPERIMENT_RECIPES receitas, o padrão se revela sozinho.
const EXPERIMENT_RECIPES := 8


func _check_experimentation_unlocks() -> void:
	if grimoire.known_recipes.size() < EXPERIMENT_RECIPES:
		return
	for sid in DataRegistry.spell_order:
		var d: Dictionary = DataRegistry.spells[sid]
		if d.get("unlock_method", "") == "experimentation" and d.get("implemented", false) and not spells.is_known(sid):
			if spells.add_knowledge(sid, 10.0):
				discover("feitico", sid, "De tanto experimentar, um padrão se revelou: %s!" % d.name)
				EventBus.spell_learned.emit(sid)


# =================================================================== botânica

func is_wild_available(node_id: String) -> bool:
	return int(wild_harvested.get(node_id, -1)) != clock.day()


func harvest_wild(node_id: String, ingredient_id: String, base_amount: int = 1) -> Dictionary:
	if not is_wild_available(node_id):
		return {"ok": false, "reason": "Já colhido hoje. Volta a crescer amanhã."}
	var dex := stats.attr("dexterity")
	var amount := base_amount + (1 if dex >= 7 else 0) + int(inventory.passive_value("harvest_bonus", 0))
	var q := clampf(0.85 + dex * 0.03, 0.5, 1.4)
	var added := give_item(ingredient_id, amount, q)
	if added <= 0:
		return {"ok": false, "reason": "Sem espaço no inventário."}
	wild_harvested[node_id] = clock.day()
	add_school_xp("botany", 1.0)
	return {"ok": true, "amount": added}


func garden_plant(i: int, seed_id: String) -> Dictionary:
	var r := garden.plant(i, seed_id, inventory, house.garden_plots())
	if r.ok:
		add_school_xp("botany", 1.0)
		EventBus.inventory_changed.emit()
		EventBus.garden_changed.emit()
		EventBus.notify.emit("Plantado: %s." % DataRegistry.plants[r.plant].name, "info")
	else:
		EventBus.notify.emit(r.reason, "warning")
	return r


func garden_water(i: int) -> void:
	if inventory.passive_value("water_all", false):
		garden.water_all()
	else:
		garden.water(i)
	EventBus.garden_changed.emit()


func garden_fertilize(i: int) -> Dictionary:
	if garden.is_empty(i):
		return {"ok": false, "reason": "Plante algo antes de adubar."}
	if inventory.count("adubo_vital") < 1:
		return {"ok": false, "reason": "Você precisa de Adubo Vital (Crescimento + Vitalidade no caldeirão)."}
	if not garden.fertilize(i):
		return {"ok": false, "reason": "Este canteiro já foi adubado."}
	take_item("adubo_vital", 1)
	EventBus.garden_changed.emit()
	return {"ok": true, "reason": ""}


func garden_harvest(i: int) -> Dictionary:
	var ctx := {
		"botany": stats.school("botany"),
		"harvest_bonus": int(inventory.passive_value("harvest_bonus", 0)),
		"dexterity": stats.attr("dexterity"),
		"spec_bonus": 1 if stats.has_specialization("criadora_pocoes") else 0,
	}
	var r := garden.harvest(i, ctx)
	if not r.ok:
		EventBus.notify.emit(r.reason, "warning")
		return r
	give_item(r.item, r.amount, r.quality)
	give_item(r.seed, r.seeds, 1.0, true)
	if r.pollinated:
		identify_ingredient(r.item)
	add_school_xp("botany", 2.0)
	EventBus.garden_changed.emit()
	return r


func garden_grow(i: int, amount: float) -> bool:
	var ok := garden.add_growth(i, amount)
	if ok:
		EventBus.garden_changed.emit()
	return ok


# =================================================================== missões

func request_quest_refresh() -> void:
	if _refresh_queued:
		return
	_refresh_queued = true
	call_deferred("_flush_refresh")


func _flush_refresh() -> void:
	_refresh_queued = false
	refresh_quests()


func refresh_quests() -> void:
	if _refreshing:
		return
	_refreshing = true
	for _guard in 8:
		var before := {}
		for qid in quests.active_ids():
			before[qid] = quests.states[qid].objectives.duplicate()
		var r := quests.refresh(self)
		for qid in r.updated:
			for o in quests.def(qid).objectives:
				if quests.objective_done(qid, o.id) and not before.get(qid, {}).get(o.id, false):
					EventBus.notify.emit("Objetivo concluído: %s" % o.text, "quest")
			EventBus.quest_updated.emit(qid)
		for qid in r.ready:
			_complete_quest_internal(qid, "")
		if r.updated.is_empty() and r.ready.is_empty():
			break
	_refreshing = false


func start_quest(quest_id: String) -> bool:
	if not quests.start(quest_id, clock.day()):
		return false
	var q := quests.def(quest_id)
	EventBus.notify.emit("Nova missão: %s" % q.title, "quest")
	grimoire.log_entry(clock.day(), clock.time_string(), "Missão iniciada: %s." % q.title)
	EventBus.quest_started.emit(quest_id)
	request_quest_refresh()
	return true


func complete_quest(quest_id: String, outcome: String = "") -> bool:
	return _complete_quest_internal(quest_id, outcome)


func _complete_quest_internal(quest_id: String, outcome: String) -> bool:
	if not quests.is_active(quest_id):
		return false
	var q := quests.def(quest_id)
	if outcome == "":
		outcome = quests.resolve_outcome(quest_id, self)
	quests.mark_done(quest_id, outcome)
	EventBus.notify.emit("Missão concluída: %s" % q.title, "quest")
	var rw: Dictionary = q.get("rewards", {})
	if rw.has("ep"):
		give_ep(int(rw.ep))
	for s in rw.get("school", {}):
		add_school_xp(s, float(rw.school[s]))
	for it in rw.get("items", {}):
		give_item(it, int(rw.items[it]))
	for f in rw.get("rep", {}):
		change_rep(f, int(rw.rep[f]))
	for fl in rw.get("flags", []):
		set_flag(fl)
	var out: Dictionary = q.get("outcomes", {}).get(outcome, {})
	if not out.is_empty():
		apply_effects(out.get("effects", []))
		EventBus.notify.emit(out.get("text", ""), "quest")
	grimoire.log_entry(clock.day(), clock.time_string(), "Missão concluída: %s%s" % [q.title, (" — " + out.text) if out.has("text") else "."])
	set_flag("quest_done." + quest_id)
	EventBus.quest_completed.emit(quest_id, outcome)
	if q.has("next"):
		start_quest(q.next)
	return true


# =================================================================== efeitos de dados

func apply_effects(effects: Array) -> void:
	for e in effects:
		for key in e:
			var v: Variant = e[key]
			match key:
				"set_flag": set_flag(v)
				"clear_flag": set_flag(v, false)
				"start_quest": start_quest(v)
				"complete_quest": complete_quest(v[0], v[1])
				"give_item": give_item(v[0], int(v[1]))
				"take_item": take_item(v[0], int(v[1]))
				"give_ep": give_ep(int(v))
				"take_ep": take_ep(int(v))
				"rep": change_rep(v[0], int(v[1]))
				"read_page": read_page(v, false)
				"school_xp": add_school_xp(v[0], float(v[1]))
				"open_shop": EventBus.shop_requested.emit(v)
				"bestiary": add_bestiary(v[0], int(v[1]))
				"research": add_research(v[0], float(v[1]))
				"upgrade_room":
					if house.upgrade(v):
						_apply_house_effects()
						EventBus.notify.emit("%s melhorado para o nível %d!" % [house.def(v).name, house.level(v)], "discovery")
				"notify": EventBus.notify.emit(str(v), "info")
				_: push_warning("Efeito desconhecido: %s" % key)


# =================================================================== casa, descanso, comércio

func upgrade_room(room_id: String) -> Dictionary:
	var chk := house.can_upgrade(room_id, inventory.currency)
	if not chk.ok:
		return chk
	take_ep(int(chk.cost))
	house.upgrade(room_id)
	_apply_house_effects()
	EventBus.notify.emit("%s agora está no nível %d." % [house.def(room_id).name, house.level(room_id)], "discovery")
	return {"ok": true, "reason": ""}


func _apply_house_effects() -> void:
	inventory.capacity = house.storage_capacity()
	EventBus.house_changed.emit()
	EventBus.garden_changed.emit()


func rest() -> Dictionary:
	var h := clock.hour()
	var kind := "cochilo"
	var minutes := 180.0
	if h >= 18.0 or h < 5.0:
		kind = "sono"
		minutes = ((24.0 - h) + 7.0) * 60.0 if h >= 7.0 else (7.0 - h) * 60.0
	advance_time(minutes)
	stats.bonus_max_mana = house.rest_mana_bonus()
	if kind == "sono":
		stats.health = stats.max_health()
		stats.mana = stats.max_mana()
	else:
		stats.health = minf(stats.max_health(), stats.health + stats.max_health() * 0.5)
		stats.mana = minf(stats.max_mana(), stats.mana + stats.max_mana() * 0.5)
	EventBus.stats_changed.emit()
	return {"kind": kind, "minutes": minutes}


func buy_price(id: String) -> int:
	var it: Dictionary = DataRegistry.items.get(id, {})
	var mult := 1.0 if it.get("category", "") in ["semente", "ferramenta"] else 1.5
	return int(ceil(float(it.get("value", 1)) * mult))


func sell_price(id: String) -> int:
	var it: Dictionary = DataRegistry.items.get(id, {})
	var v := float(it.get("value", 0))
	if it.get("category", "") in ["semente", "ferramenta"]:
		return int(floor(v * 0.5))
	return maxi(0, int(round(v * (0.6 + 0.4 * inventory.quality(id)))))


func buy(id: String, n: int = 1) -> Dictionary:
	var price := buy_price(id) * n
	if inventory.currency < price:
		return {"ok": false, "reason": "Faltam %d EP." % (price - inventory.currency)}
	if inventory.free_weight() < inventory.item_weight(id) * n:
		return {"ok": false, "reason": "Sem espaço no armazém."}
	take_ep(price)
	give_item(id, n)
	return {"ok": true, "reason": ""}


func sell(id: String, n: int = 1) -> Dictionary:
	if inventory.count(id) < n:
		return {"ok": false, "reason": "Você não tem isso."}
	var it: Dictionary = DataRegistry.items.get(id, {})
	if it.get("category", "") == "artefato":
		return {"ok": false, "reason": "%s não está à venda." % it.name}
	var price := sell_price(id) * n
	take_item(id, n)
	give_ep(price)
	return {"ok": true, "reason": ""}


func daily_order() -> Dictionary:
	var o: Array = DAILY_ORDERS[clock.day() % DAILY_ORDERS.size()]
	return {"item": o[0], "count": int(o[1]), "reward": DAILY_ORDER_REWARD, "done": daily_order_done_day == clock.day()}


func fulfill_daily_order() -> Dictionary:
	var o := daily_order()
	if o.done:
		return {"ok": false, "reason": "Pedido de hoje já entregue. Volte amanhã!"}
	if inventory.count(o.item) < o.count:
		return {"ok": false, "reason": "Faltam %d× %s." % [o.count - inventory.count(o.item), DataRegistry.item_name(o.item)]}
	take_item(o.item, o.count)
	give_ep(o.reward)
	change_rep("aldeia_vime", 2)
	daily_order_done_day = clock.day()
	return {"ok": true, "reason": ""}


# =================================================================== persistência

func to_dict() -> Dictionary:
	return {
		"version": SAVE_VERSION,
		"stats": stats.to_dict(),
		"inventory": inventory.to_dict(),
		"grimoire": grimoire.to_dict(),
		"spells": spells.to_dict(),
		"garden": garden.to_dict(),
		"clock": clock.to_dict(),
		"quests": quests.to_dict(),
		"house": house.to_dict(),
		"flags": flags.duplicate(),
		"rep": rep.duplicate(),
		"wild_harvested": wild_harvested.duplicate(),
		"player_state": player_state.duplicate(true),
		"daily_order_done_day": daily_order_done_day,
		"playtime": playtime,
	}


func from_dict(d: Dictionary) -> void:
	new_game()
	stats.from_dict(d.get("stats", {}))
	inventory.from_dict(d.get("inventory", {}))
	grimoire.from_dict(d.get("grimoire", {}))
	spells.from_dict(d.get("spells", {}))
	garden.from_dict(d.get("garden", {}))
	clock.from_dict(d.get("clock", {}))
	quests.from_dict(d.get("quests", {}))
	house.from_dict(d.get("house", {}))
	flags = {}
	for f in d.get("flags", {}):
		flags[f] = true
	for fid in d.get("rep", {}):
		if rep.has(fid):
			rep[fid] = clampi(int(d.rep[fid]), -100, 100)
	wild_harvested = {}
	for k in d.get("wild_harvested", {}):
		wild_harvested[k] = int(d.wild_harvested[k])
	player_state = d.get("player_state", {})
	daily_order_done_day = int(d.get("daily_order_done_day", 0))
	playtime = float(d.get("playtime", 0.0))
	inventory.capacity = house.storage_capacity()
	_last_day = clock.day()
	_last_season = clock.season()
	_last_weather = clock.weather()
	EventBus.game_loaded.emit()


# =================================================================== entrada

func _setup_input() -> void:
	var keys := {
		"move_forward": [KEY_W, KEY_UP], "move_back": [KEY_S, KEY_DOWN],
		"move_left": [KEY_A, KEY_LEFT], "move_right": [KEY_D, KEY_RIGHT],
		"interact": [KEY_E, KEY_SPACE], "cast": [KEY_Q, KEY_F],
		"slot_1": [KEY_1], "slot_2": [KEY_2], "slot_3": [KEY_3], "slot_4": [KEY_4],
		"open_book": [KEY_TAB, KEY_B], "pause": [KEY_ESCAPE], "hint": [KEY_H],
	}
	for action in keys:
		if InputMap.has_action(action):
			continue
		InputMap.add_action(action)
		for k in keys[action]:
			var ev := InputEventKey.new()
			ev.physical_keycode = k
			InputMap.action_add_event(action, ev)
