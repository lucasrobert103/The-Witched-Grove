extends Node
## Carrega todos os JSON de res://data e oferece consultas tipadas.
## Os dados são a "fonte da verdade" do design — o código não deve
## conter números de balanceamento que poderiam viver aqui.

const DATA_ROOT := "res://data"

var schools_doc: Dictionary = {}
var spells: Dictionary = {}          # id -> Dictionary
var spell_order: Array[String] = []
var ingredients: Dictionary = {}
var items: Dictionary = {}           # inclui ingredientes (category "ingrediente")
var currency: Dictionary = {}
var plants: Dictionary = {}
var plants_doc: Dictionary = {}
var recipes: Dictionary = {}
var recipe_order: Array[String] = []
var recipes_rules: Dictionary = {}
var npcs: Dictionary = {}
var player_def: Dictionary = {}
var familiar_def: Dictionary = {}
var dialogues: Dictionary = {}
var quests: Dictionary = {}
var quest_order: Array[String] = []
var factions: Dictionary = {}
var faction_order: Array[String] = []
var reputation_tiers: Array = []
var regions: Array = []
var house_rooms: Dictionary = {}
var room_order: Array[String] = []
var creatures: Dictionary = {}
var pages: Dictionary = {}
var page_rules: Dictionary = {}
var research: Dictionary = {}

var load_errors: Array[String] = []
var _loaded := false


func _ready() -> void:
	load_all()


func load_all() -> void:
	if _loaded:
		return
	_loaded = true
	schools_doc = _read("spells/schools.json")
	for s in _read("spells/spells.json").get("spells", []):
		spells[s.id] = s
		spell_order.append(s.id)
	var ing_doc := _read("ingredients/ingredients.json")
	for i in ing_doc.get("ingredients", []):
		ingredients[i.id] = i
		var item: Dictionary = i.duplicate(true)
		item["category"] = "ingrediente"
		items[i.id] = item
	var items_doc := _read("items/items.json")
	currency = items_doc.get("currency", {})
	for it in items_doc.get("items", []):
		items[it.id] = it
	plants_doc = _read("plants/plants.json")
	for p in plants_doc.get("plants", []):
		plants[p.id] = p
	var rec_doc := _read("recipes/recipes.json")
	recipes_rules = rec_doc.get("rules", {})
	for r in rec_doc.get("recipes", []):
		recipes[r.id] = r
		recipe_order.append(r.id)
	var npc_doc := _read("npcs/npcs.json")
	player_def = npc_doc.get("player", {})
	familiar_def = npc_doc.get("familiar", {})
	for n in npc_doc.get("npcs", []):
		npcs[n.id] = n
	dialogues = _read("npcs/dialogues.json")
	for q in _read("quests/quests.json").get("quests", []):
		quests[q.id] = q
		quest_order.append(q.id)
	var fac_doc := _read("world/factions.json")
	reputation_tiers = fac_doc.get("reputation_tiers", [])
	for f in fac_doc.get("factions", []):
		factions[f.id] = f
		faction_order.append(f.id)
	regions = _read("world/regions.json").get("regions", [])
	for room in _read("world/house.json").get("rooms", []):
		house_rooms[room.id] = room
		room_order.append(room.id)
	for c in _read("world/creatures.json").get("creatures", []):
		creatures[c.id] = c
	var pages_doc := _read("lore/pages.json")
	page_rules = pages_doc.get("rules", {})
	research = pages_doc.get("research", {})
	for pg in pages_doc.get("pages", []):
		pages[pg.id] = pg


func _read(rel_path: String) -> Dictionary:
	var path := DATA_ROOT.path_join(rel_path)
	if not FileAccess.file_exists(path):
		load_errors.append("Arquivo ausente: %s" % path)
		push_error(load_errors[-1])
		return {}
	var text := FileAccess.get_file_as_string(path)
	var parsed = JSON.parse_string(text)
	if typeof(parsed) != TYPE_DICTIONARY:
		load_errors.append("JSON inválido: %s" % path)
		push_error(load_errors[-1])
		return {}
	return parsed


# ---------------------------------------------------------------- consultas

func school_name(id: String) -> String:
	return schools_doc.get("schools", {}).get(id, {}).get("name", id)


func school_ids() -> Array:
	return schools_doc.get("schools", {}).keys()


func attribute_ids() -> Array:
	return schools_doc.get("attributes", {}).keys()


func attribute_name(id: String) -> String:
	return schools_doc.get("attributes", {}).get(id, {}).get("name", id)


func property_name(id: String) -> String:
	return schools_doc.get("property_names", {}).get(id, id.capitalize())


func technique_name(id: String) -> String:
	return schools_doc.get("techniques", {}).get(id, id)


func technique_ids() -> Array:
	return schools_doc.get("techniques", {}).keys()


func incompatible_pairs() -> Array:
	return schools_doc.get("incompatible_properties", [])


func item_name(id: String) -> String:
	return items.get(id, {}).get("name", id)


func item_color(id: String) -> Color:
	return Color(items.get(id, {}).get("color", "#cccccc"))


func season_name(id: String) -> String:
	return plants_doc.get("season_names", {}).get(id, id)


func seasons() -> Array:
	return plants_doc.get("seasons", ["primavera", "verao", "outono", "inverno"])


func plant_for_seed(seed_id: String) -> Dictionary:
	var pid: String = items.get(seed_id, {}).get("plant", "")
	return plants.get(pid, {})


func plant_producing(ingredient_id: String) -> Dictionary:
	for p in plants.values():
		if p.produces == ingredient_id:
			return p
	return {}


func npc_name(id: String) -> String:
	if id == "ondina":
		return "Ondina Vael"
	if id == player_def.get("id", ""):
		return player_def.get("name", id)
	if creatures.has(id):
		return creatures[id].name
	return npcs.get(id, {}).get("name", id)


func region(id: String) -> Dictionary:
	for r in regions:
		if r.id == id:
			return r
	return {}


func reputation_tier(value: int) -> String:
	var tier := ""
	for t in reputation_tiers:
		if value >= int(t.min):
			tier = t.name
	return tier


func quality_tier(q: float) -> String:
	var tier := ""
	for t in recipes_rules.get("quality_tiers", []):
		if q >= float(t.min):
			tier = t.name
	return tier
