class_name SpellSystem
extends RefCounted
## Sistema B — Magia. Conhecimento por feitiço (0..100%), maestria por uso,
## recargas e explicações claras de "por que não funciona".
##
## Regras (rule-engine R-B1..R-B6):
## - Ler a página de um feitiço: +10% por leitura (até 5 leituras).
## - Castável a partir de 10% (padrão compreendido) e com nível de escola suficiente.
## - Cada lançamento bem-sucedido: +5% (até 100%).
## - Eficácia = 0.5 + conhecimento/200  (10% → 0.55, 100% → 1.0).
## - Maestria (100%): custo de mana -20% e +10% de velocidade em ações da escola.

const CASTABLE_MIN := 10.0
const KNOWLEDGE_PER_CAST := 5.0
const SLOT_COUNT := 6

var knowledge: Dictionary = {}   # spell_id -> 0..100
var casts: Dictionary = {}       # spell_id -> int
var cooldowns: Dictionary = {}   # spell_id -> segundos restantes
var slots: Array = ["", "", "", "", "", ""]
var selected_slot: int = 0


func def(spell_id: String) -> Dictionary:
	return DataRegistry.spells.get(spell_id, {})


func get_knowledge(spell_id: String) -> float:
	return float(knowledge.get(spell_id, 0.0))


func is_known(spell_id: String) -> bool:
	return get_knowledge(spell_id) >= CASTABLE_MIN


func is_mastered(spell_id: String) -> bool:
	return get_knowledge(spell_id) >= 100.0


func known_spells() -> Array:
	var out: Array = []
	for id in DataRegistry.spell_order:
		if is_known(id):
			out.append(id)
	return out


## Adiciona conhecimento de padrão. Retorna true se o feitiço acabou de se tornar castável.
func add_knowledge(spell_id: String, amount: float) -> bool:
	if not DataRegistry.spells.has(spell_id):
		return false
	var was_known := is_known(spell_id)
	knowledge[spell_id] = clampf(get_knowledge(spell_id) + amount, 0.0, 100.0)
	EventBus.spell_knowledge_changed.emit(spell_id, knowledge[spell_id])
	if not was_known and is_known(spell_id):
		_auto_slot(spell_id)
		return true
	return false


func _auto_slot(spell_id: String) -> void:
	if spell_id in slots:
		return
	for i in slots.size():
		if slots[i] == "":
			slots[i] = spell_id
			EventBus.spell_slots_changed.emit()
			return
	# Barra cheia: o feitiço novo entra no último espaço (o antigo continua no grimório).
	var old: String = slots[SLOT_COUNT - 1]
	slots[SLOT_COUNT - 1] = spell_id
	EventBus.spell_slots_changed.emit()
	EventBus.notify.emit("%s entrou no espaço %d da barra (%s continua no Grimório → Feitiços)." % [def(spell_id).get("name", spell_id), SLOT_COUNT, def(old).get("name", old)], "info")


## Feitiços iniciais (marcados com "starter" nos dados): já compreendidos e equipados.
func grant_starters() -> void:
	for id in DataRegistry.spell_order:
		var d: Dictionary = DataRegistry.spells[id]
		if not d.get("starter", false):
			continue
		knowledge[id] = 30.0
		var slot := int(d.get("starter_slot", -1))
		if slot >= 0 and slot < SLOT_COUNT:
			slots[slot] = id


func set_slot(index: int, spell_id: String) -> void:
	if index < 0 or index >= SLOT_COUNT:
		return
	if spell_id != "":
		for i in slots.size():
			if slots[i] == spell_id:
				slots[i] = ""
	slots[index] = spell_id
	EventBus.spell_slots_changed.emit()


func selected_spell() -> String:
	return slots[clampi(selected_slot, 0, SLOT_COUNT - 1)]


func efficacy(spell_id: String) -> float:
	return 0.5 + get_knowledge(spell_id) / 200.0


func mana_cost(spell_id: String, stats: CharacterStats = null) -> float:
	var d := def(spell_id)
	var cost := float(d.get("mana_cost", 0))
	if is_mastered(spell_id):
		cost *= 0.8
	if stats and d.get("school", "") == "elemental" and stats.has_specialization("tecela_elementos"):
		cost *= 0.8
	return roundf(cost)


func cooldown_left(spell_id: String) -> float:
	return float(cooldowns.get(spell_id, 0.0))


## Bônus lunar: Astral +20% na lua cheia; Ilusão +20% na lua nova.
static func moon_bonus(school: String, moon_phase: int) -> float:
	if school == "astral" and moon_phase == 4:
		return 0.2
	if school == "illusion" and moon_phase == 0:
		return 0.2
	return 0.0


func power(spell_id: String, ctx: Dictionary = {}) -> float:
	var d := def(spell_id)
	var p := efficacy(spell_id)
	var bonus := moon_bonus(d.get("school", ""), int(ctx.get("moon_phase", -1)))
	if bonus > 0.0:
		bonus += float(ctx.get("moon_item_bonus", 0.0))
	bonus += float(ctx.get("ritual_bonus", 0.0))
	return p * (1.0 + bonus)


## Verifica se é possível lançar, com explicação legível.
func can_cast(spell_id: String, stats: CharacterStats, inventory: Inventory) -> Dictionary:
	var d := def(spell_id)
	if d.is_empty():
		return {"ok": false, "reason": "Feitiço desconhecido."}
	if not is_known(spell_id):
		return {"ok": false, "reason": "Você ainda não compreende o padrão de %s. Leia a página onde ele está escrito." % d.name}
	var req := float(d.get("level_required", 0))
	if stats.school(d.school) < req:
		return {"ok": false, "reason": "%s exige %s nível %d (você tem %d)." % [d.name, DataRegistry.school_name(d.school), int(req), int(stats.school(d.school))]}
	if not d.get("implemented", true):
		return {"ok": false, "reason": "%s ainda não tem efeito nesta versão." % d.name}
	var cd := cooldown_left(spell_id)
	if cd > 0.0:
		return {"ok": false, "reason": "%s está se recompondo (%.0fs)." % [d.name, ceil(cd)]}
	var cost := mana_cost(spell_id, stats)
	if stats.mana < cost:
		return {"ok": false, "reason": "Mana insuficiente: %s custa %d, você tem %d." % [d.name, int(cost), int(stats.mana)]}
	var missing: Array = []
	var ing_cost: Dictionary = d.get("ingredient_cost", {})
	for ing in ing_cost:
		if inventory.count(ing) < int(ing_cost[ing]):
			missing.append("%d× %s" % [int(ing_cost[ing]), DataRegistry.item_name(ing)])
	if not missing.is_empty():
		return {"ok": false, "reason": "Faltam ingredientes: %s." % ", ".join(missing)}
	return {"ok": true, "reason": ""}


## Lança o feitiço: consome mana e ingredientes, inicia recarga, ganha maestria.
func cast(spell_id: String, stats: CharacterStats, inventory: Inventory, ctx: Dictionary = {}) -> Dictionary:
	var check := can_cast(spell_id, stats, inventory)
	if not check.ok:
		return {"ok": false, "reason": check.reason, "spell": spell_id}
	var d := def(spell_id)
	stats.mana -= mana_cost(spell_id, stats)
	var ing_cost: Dictionary = d.get("ingredient_cost", {})
	for ing in ing_cost:
		inventory.remove(ing, int(ing_cost[ing]))
	cooldowns[spell_id] = float(d.get("cooldown", 0.0))
	casts[spell_id] = int(casts.get(spell_id, 0)) + 1
	var was_mastered := is_mastered(spell_id)
	add_knowledge(spell_id, KNOWLEDGE_PER_CAST)
	var xp := stats.add_school_xp(d.school, 2.0)
	var result := {
		"ok": true, "spell": spell_id, "power": power(spell_id, ctx), "school": d.school,
		"school_xp": xp, "mastered_now": (not was_mastered and is_mastered(spell_id)),
	}
	return result


func tick(delta: float) -> void:
	for id in cooldowns.keys():
		var left := float(cooldowns[id]) - delta
		if left <= 0.0:
			cooldowns.erase(id)
		else:
			cooldowns[id] = left


func to_dict() -> Dictionary:
	return {"knowledge": knowledge.duplicate(), "casts": casts.duplicate(), "slots": slots.duplicate(), "selected": selected_slot}


func from_dict(d: Dictionary) -> void:
	knowledge = {}
	for k in d.get("knowledge", {}):
		if DataRegistry.spells.has(k):
			knowledge[k] = float(d.knowledge[k])
	casts = {}
	for k in d.get("casts", {}):
		casts[k] = int(d.casts[k])
	var s: Array = d.get("slots", [])
	slots = ["", "", "", "", "", ""]
	for i in mini(s.size(), SLOT_COUNT):
		slots[i] = str(s[i]) if DataRegistry.spells.has(str(s[i])) else ""
	selected_slot = clampi(int(d.get("selected", 0)), 0, SLOT_COUNT - 1)
	cooldowns = {}
