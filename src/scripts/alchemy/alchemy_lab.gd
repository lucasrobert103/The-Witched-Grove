class_name AlchemyLab
extends RefCounted
## Sistema D — Alquimia. Avaliação pura (sem efeitos colaterais) de uma mistura.
##
## Regras (rule-engine R-D1..R-D7):
## 1. Uma propriedade DESPERTA quando aparece em pelo menos 2 ingredientes.
## 2. Pares incompatíveis despertos se anulam (Calor×Frio, Luz×Sombra,
##    Estabilidade×Volatilidade, Claridade×Turvo) — salvo Estabilização.
## 3. A receita escolhida é a mais específica cujas propriedades exigidas
##    estão todas despertas e nenhuma proibida está desperta.
## 4. Qualidade = média(qualidade ingredientes) × fator técnica × (0.7 + Alquimia/200) + bônus,
##    limitada a [0.3, 1.5].


static func active_properties(ingredient_ids: Array, stabilize: bool = false) -> Dictionary:
	var counts := {}
	for id in ingredient_ids:
		var props: Array = DataRegistry.ingredients.get(id, {}).get("properties", [])
		for p in props:
			counts[p] = int(counts.get(p, 0)) + 1
	var min_count := int(DataRegistry.recipes_rules.get("property_active_min_count", 2))
	var active: Array = []
	for p in counts:
		if int(counts[p]) >= min_count:
			active.append(p)
	var cancelled: Array = []
	var stabilized: Array = []
	for pair in DataRegistry.incompatible_pairs():
		if pair[0] in active and pair[1] in active:
			if stabilize and stabilized.is_empty():
				stabilized.append(pair)
				continue
			cancelled.append(pair)
	for pair in cancelled:
		active.erase(pair[0])
		active.erase(pair[1])
	active.sort()
	return {"active": active, "cancelled": cancelled, "stabilized": stabilized, "counts": counts}


static func technique_factor(given: Array, ideal: Array) -> Dictionary:
	var tf: Dictionary = DataRegistry.recipes_rules.get("technique_factor", {})
	if given == ideal:
		return {"factor": float(tf.get("exact", 1.0)), "grade": "exact"}
	var given_sorted := given.duplicate()
	given_sorted.sort()
	var ideal_sorted := ideal.duplicate()
	ideal_sorted.sort()
	if given_sorted == ideal_sorted:
		return {"factor": float(tf.get("same_steps", 0.85)), "grade": "same_steps"}
	for step in given:
		if step in ideal:
			return {"factor": float(tf.get("partial", 0.7)), "grade": "partial"}
	return {"factor": float(tf.get("none", 0.55)), "grade": "none"}


## Avalia uma mistura.
## ctx: alchemy (0..100), qualities (Array[float] por ingrediente), bonus (float), stabilize (bool)
static func evaluate(ingredient_ids: Array, technique: Array, ctx: Dictionary = {}) -> Dictionary:
	var result := {
		"success": false, "recipe_id": "", "output": DataRegistry.recipes_rules.get("failure_item", "mistura_turva"),
		"quality": 0.3, "tier": "", "active": [], "cancelled": [], "insight": "", "error": "",
		"technique_grade": "none",
	}
	if ingredient_ids.size() < 2:
		result.error = "Uma mistura precisa de pelo menos 2 ingredientes."
		return result
	var seen := {}
	for id in ingredient_ids:
		if seen.has(id):
			result.error = "Cada ingrediente só pode entrar uma vez na mesma mistura."
			return result
		seen[id] = true
		if not DataRegistry.ingredients.has(id):
			result.error = "%s não é um ingrediente alquímico." % DataRegistry.item_name(id)
			return result
	var max_steps := int(DataRegistry.recipes_rules.get("max_technique_steps", 3))
	if technique.size() > max_steps:
		result.error = "No máximo %d passos de técnica." % max_steps
		return result

	var props := active_properties(ingredient_ids, bool(ctx.get("stabilize", false)))
	var active: Array = props.active
	result.active = active
	result.cancelled = props.cancelled

	# Candidatas: todas as exigências despertas. Ordena da mais específica para a menos.
	var candidates: Array = []
	for rid in DataRegistry.recipe_order:
		var r: Dictionary = DataRegistry.recipes[rid]
		var ok := true
		for req in r.requires:
			if not req in active:
				ok = false
				break
		if ok:
			candidates.append(r)
	candidates.sort_custom(func(a, b): return a.requires.size() > b.requires.size())

	var alchemy := float(ctx.get("alchemy", 0.0))
	var chosen: Dictionary = {}
	var blocked_by_forbid: Dictionary = {}
	var blocked_by_level: Dictionary = {}
	for r in candidates:
		var forbidden_hit := ""
		for f in r.get("forbids", []):
			if f in active:
				forbidden_hit = f
				break
		if forbidden_hit != "":
			if blocked_by_forbid.is_empty():
				blocked_by_forbid = {"recipe": r, "prop": forbidden_hit}
			continue
		if alchemy < float(r.get("alchemy_level", 0)):
			if blocked_by_level.is_empty():
				blocked_by_level = r
			continue
		chosen = r
		break

	if chosen.is_empty():
		result.insight = _failure_insight(active, props.cancelled, blocked_by_forbid, blocked_by_level)
		return result

	var qualities: Array = ctx.get("qualities", [])
	var avg_q := 1.0
	if not qualities.is_empty():
		var s := 0.0
		for q in qualities:
			s += float(q)
		avg_q = s / qualities.size()
	var tech := technique_factor(technique, chosen.technique)
	var q_final := avg_q * float(tech.factor) * (0.7 + alchemy / 200.0) + float(ctx.get("bonus", 0.0))
	q_final = clampf(q_final, 0.3, 1.5)

	result.success = true
	result.recipe_id = chosen.id
	result.output = chosen.output
	result.quality = snappedf(q_final, 0.01)
	result.tier = DataRegistry.quality_tier(result.quality)
	result.technique_grade = tech.grade
	if tech.grade != "exact":
		var first_step: String = chosen.technique[0]
		result.insight = "Intuição: a técnica de %s parece começar com '%s'." % [chosen.name, DataRegistry.technique_name(first_step)]
	return result


static func _failure_insight(active: Array, cancelled: Array, forbid: Dictionary, level: Dictionary) -> String:
	if not forbid.is_empty():
		return "%s interfere com %s: não pode estar desperta nesta receita." % [
			DataRegistry.property_name(forbid.prop), forbid.recipe.name]
	if not level.is_empty():
		return "Você sente que está perto de algo (%s), mas falta prática: Alquimia nível %d." % [
			level.name, int(level.alchemy_level)]
	if not cancelled.is_empty():
		var parts: Array = []
		for pair in cancelled:
			parts.append("%s e %s se anularam" % [DataRegistry.property_name(pair[0]), DataRegistry.property_name(pair[1])])
		return ", ".join(parts) + "."
	if active.is_empty():
		return "Nenhuma propriedade despertou: os ingredientes precisam compartilhar propriedades (pelo menos 2 com a mesma)."
	var names: Array = []
	for p in active:
		names.append(DataRegistry.property_name(p))
	return "A mistura despertou %s, mas nenhuma receita conhecida pelo mundo usa só isso." % ", ".join(names)
