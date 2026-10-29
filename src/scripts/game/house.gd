class_name House
extends RefCounted
## Sistema H — Propriedade. Cômodos com níveis; cada nível altera mecânicas.

var levels: Dictionary = {}


func _init() -> void:
	for rid in DataRegistry.room_order:
		levels[rid] = int(DataRegistry.house_rooms[rid].get("start_level", 0))


func def(room_id: String) -> Dictionary:
	return DataRegistry.house_rooms.get(room_id, {})


func level(room_id: String) -> int:
	return int(levels.get(room_id, 0))


func is_unlocked(room_id: String) -> bool:
	return level(room_id) > 0


func max_level(room_id: String) -> int:
	return int(def(room_id).get("max_level", 1))


func next_cost(room_id: String) -> int:
	var costs: Array = def(room_id).get("upgrade_costs", [])
	var lvl := level(room_id)
	if lvl >= max_level(room_id) or lvl >= costs.size():
		return -1
	return int(costs[lvl])


func can_upgrade(room_id: String, currency: int) -> Dictionary:
	if not is_unlocked(room_id):
		return {"ok": false, "reason": "Cômodo ainda bloqueado: %s." % unlock_text(room_id), "cost": -1}
	var cost := next_cost(room_id)
	if cost < 0:
		return {"ok": false, "reason": "Nível máximo.", "cost": -1}
	if currency < cost:
		return {"ok": false, "reason": "Faltam %d EP." % (cost - currency), "cost": cost}
	return {"ok": true, "reason": "", "cost": cost}


func upgrade(room_id: String) -> bool:
	if level(room_id) >= max_level(room_id):
		return false
	levels[room_id] = level(room_id) + 1
	return true


func unlock_text(room_id: String) -> String:
	var u: String = def(room_id).get("unlock", "inicio")
	if u.begins_with("school:"):
		var parts := u.split(":")
		return "aprenda algo de %s" % DataRegistry.school_name(parts[1])
	if u.begins_with("two_schools:"):
		return "alcance nível %s em duas escolas" % u.split(":")[1]
	return "disponível"


## Desbloqueia cômodos cujas condições foram atingidas. Retorna os ids desbloqueados.
func check_unlocks(stats: CharacterStats) -> Array:
	var out: Array = []
	for rid in DataRegistry.room_order:
		if is_unlocked(rid):
			continue
		var u: String = def(rid).get("unlock", "inicio")
		var ok := false
		if u == "inicio":
			ok = true
		elif u.begins_with("school:"):
			var parts := u.split(":")
			ok = stats.school(parts[1]) >= float(parts[2])
		elif u.begins_with("two_schools:"):
			var need := float(u.split(":")[1])
			var n := 0
			for s in stats.schools:
				if stats.school(s) >= need:
					n += 1
			ok = n >= 2
		if ok:
			levels[rid] = 1
			out.append(rid)
	return out


func _effect(room_id: String, key: String, default_value: Variant) -> Variant:
	return def(room_id).get("effects", {}).get(key, default_value)


func garden_plots() -> int:
	var arr: Array = _effect("jardim", "plots", [0, 4, 6, 9])
	return int(arr[clampi(level("jardim"), 0, arr.size() - 1)])


func lab_slots() -> int:
	var arr: Array = _effect("laboratorio", "slots", [3, 4, 4])
	return int(arr[clampi(level("laboratorio") - 1, 0, arr.size() - 1)])


func lab_quality_bonus() -> float:
	return float(_effect("laboratorio", "quality_bonus_per_level", 0.05)) * maxi(0, level("laboratorio") - 1)


func read_bonus() -> float:
	return float(_effect("biblioteca", "read_bonus_per_level", 2)) * maxi(0, level("biblioteca") - 1)


func storage_capacity() -> float:
	var arr: Array = _effect("armazem", "capacity", [40, 80, 160])
	return float(arr[clampi(level("armazem") - 1, 0, arr.size() - 1)])


func spell_power_bonus() -> float:
	return float(_effect("sala_ritual", "spell_power_per_level", 0.1)) * level("sala_ritual")


func rest_mana_bonus() -> float:
	return float(_effect("dormitorio", "rest_mana_bonus", 20)) * maxi(0, level("dormitorio") - 1)


func to_dict() -> Dictionary:
	return {"levels": levels.duplicate()}


func from_dict(d: Dictionary) -> void:
	for k in d.get("levels", {}):
		if levels.has(k):
			levels[k] = clampi(int(d.levels[k]), 0, max_level(k))
