class_name Garden
extends RefCounted
## Sistema E — Botânica. Canteiros com crescimento por hora de jogo.
##
## Taxa/hora = 1 / (dias_de_crescimento × 24) × estação × luz × água × adubo × lua × maestria
## (rule-engine R-E1..R-E6). Toda multiplicação é explicada na interface.

const MAX_PLOTS := 9
## Luz de cada canteiro (posições fixas no jardim da cabana).
const PLOT_LIGHT := ["sol", "sol", "meia", "sol", "meia", "sombra", "sol", "meia", "sombra"]

var plots: Array = []


func _init() -> void:
	for i in MAX_PLOTS:
		plots.append(_empty_plot(i))


func _empty_plot(i: int) -> Dictionary:
	return {"plant": "", "growth": 0.0, "water": 0.6, "fertilized": false, "protected_days": 0.0,
		"light": PLOT_LIGHT[i % PLOT_LIGHT.size()], "care_sum": 0.0, "care_hours": 0.0, "pollinated": false}


func rules() -> Dictionary:
	return DataRegistry.plants_doc.get("rules", {})


func plot(i: int) -> Dictionary:
	return plots[i] if i >= 0 and i < plots.size() else {}


func is_empty(i: int) -> bool:
	return plot(i).get("plant", "") == ""


func is_ready(i: int) -> bool:
	return not is_empty(i) and float(plot(i).growth) >= 1.0


func plant(i: int, seed_id: String, inventory: Inventory, unlocked_plots: int) -> Dictionary:
	if i >= unlocked_plots:
		return {"ok": false, "reason": "Este canteiro ainda é terra bruta. Melhore o Jardim no Livro → Casa."}
	if not is_empty(i):
		return {"ok": false, "reason": "Já há algo plantado aqui."}
	var p := DataRegistry.plant_for_seed(seed_id)
	if p.is_empty():
		return {"ok": false, "reason": "Isso não é uma semente."}
	if not inventory.remove(seed_id, 1):
		return {"ok": false, "reason": "Você não tem %s." % DataRegistry.item_name(seed_id)}
	var pl: Dictionary = plots[i]
	pl.plant = p.id
	pl.growth = 0.0
	pl.fertilized = false
	pl.care_sum = 0.0
	pl.care_hours = 0.0
	pl.pollinated = false
	return {"ok": true, "plant": p.id}


func water(i: int) -> bool:
	if i < 0 or i >= plots.size():
		return false
	plots[i].water = 1.0
	return true


func water_all() -> void:
	for pl in plots:
		pl.water = 1.0


func fertilize(i: int) -> bool:
	if is_empty(i) or plot(i).fertilized:
		return false
	plots[i].fertilized = true
	return true


func protect(i: int, days: float) -> void:
	if i >= 0 and i < plots.size():
		plots[i].protected_days = maxf(float(plots[i].protected_days), days)


func add_growth(i: int, amount: float) -> bool:
	if is_empty(i) or is_ready(i):
		return false
	plots[i].growth = minf(1.0, float(plots[i].growth) + amount)
	return true


static func season_index(season: String) -> int:
	return maxi(0, ["primavera", "verao", "outono", "inverno"].find(season))


func season_mult(plant_def: Dictionary, season: String) -> float:
	var r := rules()
	var diff := absi(season_index(plant_def.season) - season_index(season))
	if diff == 0:
		return float(r.get("season_ideal_mult", 1.25))
	if diff == 2:
		return float(r.get("season_opposite_mult", 0.5))
	return float(r.get("season_neutral_mult", 1.0))


func light_mult(plant_def: Dictionary, light: String) -> float:
	var order := ["sol", "meia", "sombra"]
	var diff := absi(order.find(plant_def.light) - order.find(light))
	if diff == 0:
		return float(rules().get("light_match_mult", 1.0))
	if diff == 1:
		return 0.8
	return float(rules().get("light_mismatch_mult", 0.6))


## Detalhamento da taxa de crescimento — usado pela UI para explicar "por que está lento".
func growth_breakdown(i: int, season: String, moon_phase: int, botany: float) -> Dictionary:
	var pl := plot(i)
	if pl.is_empty() or pl.plant == "":
		return {}
	var p: Dictionary = DataRegistry.plants[pl.plant]
	var r := rules()
	var parts := {
		"estacao": season_mult(p, season),
		"luz": light_mult(p, pl.light),
		"agua": 1.0 if float(pl.water) > float(r.get("dry_threshold", 0.2)) else float(r.get("dry_growth_mult", 0.25)),
		"adubo": float(r.get("fertilizer_mult", 1.5)) if pl.fertilized else 1.0,
		"lua": 1.0 + (float(r.get("full_moon_bonus", 0.25)) if p.get("lunar", false) and moon_phase == 4 else 0.0),
		"maestria": 1.0 + botany / 400.0,
	}
	var mult := 1.0
	for k in parts:
		mult *= float(parts[k])
	var base := 1.0 / (float(p.growth_days) * 24.0)
	return {"parts": parts, "mult": mult, "per_hour": base * mult,
		"hours_left": (1.0 - float(pl.growth)) / maxf(0.00001, base * mult)}


func tick_hours(hours: float, season: String, weather: String, moon_phase: int, botany: float) -> bool:
	var changed := false
	var r := rules()
	var drain := float(r.get("water_drain_per_day", 0.5)) / 24.0 * hours
	for i in plots.size():
		var pl: Dictionary = plots[i]
		if weather == "chuva" or weather == "neve":
			pl.water = 1.0
		elif float(pl.protected_days) > 0.0:
			pl.protected_days = maxf(0.0, float(pl.protected_days) - hours / 24.0)
		else:
			pl.water = maxf(0.0, float(pl.water) - drain)
		if pl.plant == "" or float(pl.growth) >= 1.0:
			continue
		var b := growth_breakdown(i, season, moon_phase, botany)
		var before := float(pl.growth)
		pl.growth = minf(1.0, before + float(b.per_hour) * hours)
		var care := 1.0 if float(pl.water) > float(r.get("dry_threshold", 0.2)) else 0.4
		pl.care_sum = float(pl.care_sum) + care * hours
		pl.care_hours = float(pl.care_hours) + hours
		if int(before * 4.0) != int(float(pl.growth) * 4.0):
			changed = true
	return changed


func care_quality(i: int) -> float:
	var pl := plot(i)
	if float(pl.get("care_hours", 0.0)) <= 0.0:
		return 1.0
	return float(pl.care_sum) / float(pl.care_hours)


## Colhe. ctx: botany, harvest_bonus (ferramentas), dexterity, spec_bonus
func harvest(i: int, ctx: Dictionary = {}) -> Dictionary:
	if not is_ready(i):
		return {"ok": false, "reason": "Ainda não está pronta para colher."}
	var pl: Dictionary = plots[i]
	var p: Dictionary = DataRegistry.plants[pl.plant]
	var botany := float(ctx.get("botany", 0.0))
	var amount := int(p.get("yield", 1)) + int(floor(botany / 35.0)) + int(ctx.get("harvest_bonus", 0)) + int(ctx.get("spec_bonus", 0))
	var quality := (0.75 + 0.25 * care_quality(i)) * (0.9 + botany / 250.0) * (0.94 + int(ctx.get("dexterity", 5)) * 0.012)
	if pl.pollinated:
		quality += 0.1
	quality = clampf(quality, 0.5, 1.5)
	var result := {"ok": true, "plant": p.id, "item": p.produces, "amount": amount,
		"quality": snappedf(quality, 0.01), "seed": p.seed, "seeds": int(rules().get("seed_return", 1)),
		"pollinated": pl.pollinated}
	plots[i] = _empty_plot(i)
	plots[i].water = pl.water
	return result


func pollinate(i: int) -> bool:
	if not is_ready(i) or plot(i).pollinated:
		return false
	plots[i].pollinated = true
	return true


func remove_plant(i: int) -> void:
	if i >= 0 and i < plots.size():
		var w: float = plots[i].water
		plots[i] = _empty_plot(i)
		plots[i].water = w


func to_dict() -> Dictionary:
	return {"plots": plots.duplicate(true)}


func from_dict(d: Dictionary) -> void:
	var raw: Array = d.get("plots", [])
	for i in MAX_PLOTS:
		plots[i] = _empty_plot(i)
		if i < raw.size():
			var src: Dictionary = raw[i]
			for k in plots[i]:
				if src.has(k):
					plots[i][k] = src[k]
			if plots[i].plant != "" and not DataRegistry.plants.has(plots[i].plant):
				plots[i] = _empty_plot(i)
			plots[i].light = PLOT_LIGHT[i]
