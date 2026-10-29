class_name Inventory
extends RefCounted
## Sistema K — Inventário. Pilhas por id com qualidade média.
## Limite por peso (generoso, sem "Tetris"); moeda sem limite superior.

var stacks: Dictionary = {}     # id -> {"count": int, "quality": float}
var currency: int = 0
var capacity: float = 40.0


func count(id: String) -> int:
	return int(stacks.get(id, {}).get("count", 0))


func has(id: String, n: int = 1) -> bool:
	return count(id) >= n


func quality(id: String) -> float:
	return float(stacks.get(id, {}).get("quality", 1.0))


func item_weight(id: String) -> float:
	return float(DataRegistry.items.get(id, {}).get("weight", 0.1))


func total_weight() -> float:
	var w := 0.0
	for id in stacks:
		w += item_weight(id) * count(id)
	return w


func free_weight() -> float:
	return maxf(0.0, capacity - total_weight())


## Adiciona até n unidades respeitando a capacidade. Retorna quantas entraram.
func add(id: String, n: int = 1, q: float = 1.0) -> int:
	if n <= 0 or not DataRegistry.items.has(id):
		return 0
	var w := item_weight(id)
	var fits := n
	if w > 0.0:
		fits = mini(n, int(floor(free_weight() / w + 0.0001)))
	if fits <= 0:
		return 0
	var c := count(id)
	var old_q := quality(id) if c > 0 else q
	var new_q := (old_q * c + q * fits) / float(c + fits)
	stacks[id] = {"count": c + fits, "quality": snappedf(new_q, 0.001)}
	return fits


func remove(id: String, n: int = 1) -> bool:
	if n <= 0:
		return true
	if count(id) < n:
		return false
	var left := count(id) - n
	if left <= 0:
		stacks.erase(id)
	else:
		stacks[id]["count"] = left
	return true


func ids_by_category(category: String) -> Array:
	var out: Array = []
	for id in stacks:
		if DataRegistry.items.get(id, {}).get("category", "") == category:
			out.append(id)
	out.sort_custom(func(a, b): return DataRegistry.item_name(a) < DataRegistry.item_name(b))
	return out


func all_ids() -> Array:
	var out: Array = stacks.keys()
	out.sort_custom(func(a, b): return DataRegistry.item_name(a) < DataRegistry.item_name(b))
	return out


func add_currency(amount: int) -> void:
	currency = maxi(0, currency + amount)


func spend_currency(amount: int) -> bool:
	if amount > currency:
		return false
	currency -= amount
	return true


func passive_value(key: String, default_value: Variant = 0) -> Variant:
	## Ferramentas no inventário concedem bônus passivos.
	var total: Variant = default_value
	for id in stacks:
		var passive: Dictionary = DataRegistry.items.get(id, {}).get("passive", {})
		if passive.has(key):
			var v: Variant = passive[key]
			if typeof(v) == TYPE_BOOL:
				return v
			total = total + v
	return total


func to_dict() -> Dictionary:
	return {"stacks": stacks.duplicate(true), "currency": currency, "capacity": capacity}


func from_dict(d: Dictionary) -> void:
	stacks = {}
	var raw: Dictionary = d.get("stacks", {})
	for id in raw:
		if DataRegistry.items.has(id):
			stacks[id] = {"count": int(raw[id].get("count", 0)), "quality": float(raw[id].get("quality", 1.0))}
	currency = int(d.get("currency", 0))
	capacity = float(d.get("capacity", 40.0))
