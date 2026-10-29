class_name Grimoire
extends RefCounted
## Sistema C — Grimório: a memória da protagonista.
## Guarda o que foi DESCOBERTO (não o que existe). Tudo que não foi
## descoberto aparece como "???" na interface.

var page_reads: Dictionary = {}        # page_id -> vezes lidas
var known_recipes: Array = []          # recipe ids
var plant_catalogue: Dictionary = {}   # ingredient_id -> {"revealed": [props], "harvests": int}
var bestiary: Dictionary = {}          # creature_id -> nº de anotações reveladas
var insights: Array = []               # aprendizados de experimentos
var symbols: Dictionary = {}           # símbolo -> significado
var research: Dictionary = {}          # research_id -> 0..100
var annotations: Dictionary = {}       # id -> nota do jogador
var timeline: Array = []               # [{"day": int, "time": String, "text": String}]


func times_read(page_id: String) -> int:
	return int(page_reads.get(page_id, 0))


func register_read(page_id: String) -> int:
	var n := times_read(page_id) + 1
	page_reads[page_id] = n
	var page: Dictionary = DataRegistry.pages.get(page_id, {})
	for sym in page.get("symbols", {}):
		symbols[sym] = page.symbols[sym]
	return n


func learn_recipe(recipe_id: String) -> bool:
	if recipe_id in known_recipes or not DataRegistry.recipes.has(recipe_id):
		return false
	known_recipes.append(recipe_id)
	return true


func knows_recipe(recipe_id: String) -> bool:
	return recipe_id in known_recipes


func revealed_props(ingredient_id: String) -> Array:
	return plant_catalogue.get(ingredient_id, {}).get("revealed", [])


func _entry(ingredient_id: String) -> Dictionary:
	if not plant_catalogue.has(ingredient_id):
		plant_catalogue[ingredient_id] = {"revealed": [], "harvests": 0}
	return plant_catalogue[ingredient_id]


func is_catalogued(ingredient_id: String) -> bool:
	return plant_catalogue.has(ingredient_id)


func reveal_property(ingredient_id: String, prop: String) -> bool:
	var all_props: Array = DataRegistry.ingredients.get(ingredient_id, {}).get("properties", [])
	if not prop in all_props:
		return false
	var e := _entry(ingredient_id)
	if prop in e.revealed:
		return false
	e.revealed.append(prop)
	return true


## Revela a próxima propriedade ainda oculta (na ordem de intensidade).
func reveal_next_property(ingredient_id: String) -> String:
	var all_props: Array = DataRegistry.ingredients.get(ingredient_id, {}).get("properties", [])
	for p in all_props:
		if reveal_property(ingredient_id, p):
			return p
	return ""


## Colheita/obtenção: a 1ª revela 2 propriedades, as seguintes vão revelando
## até o total previsto em plants.json → rules.reveal_schedule.
func on_obtained(ingredient_id: String) -> Array:
	if not DataRegistry.ingredients.has(ingredient_id):
		return []
	var e := _entry(ingredient_id)
	e.harvests = int(e.harvests) + 1
	var schedule: Array = DataRegistry.plants_doc.get("rules", {}).get("reveal_schedule", [2, 3, 3, 4, 4, 5])
	var idx := mini(int(e.harvests) - 1, schedule.size() - 1)
	var target := int(schedule[idx])
	var newly: Array = []
	while e.revealed.size() < target:
		var p := reveal_next_property(ingredient_id)
		if p == "":
			break
		newly.append(p)
	return newly


func all_props_revealed(ingredient_id: String) -> bool:
	var all_props: Array = DataRegistry.ingredients.get(ingredient_id, {}).get("properties", [])
	return revealed_props(ingredient_id).size() >= all_props.size()


func add_insight(text: String) -> bool:
	if text == "" or text in insights:
		return false
	insights.append(text)
	return true


func bestiary_notes(creature_id: String) -> int:
	return int(bestiary.get(creature_id, 0))


## Revela anotações do bestiário até `up_to` (1-based). Retorna true se avançou.
func add_bestiary_note(creature_id: String, up_to: int = -1) -> bool:
	var notes: Array = DataRegistry.creatures.get(creature_id, {}).get("notes", [])
	if notes.is_empty():
		return false
	var current := bestiary_notes(creature_id)
	var target := current + 1 if up_to < 0 else maxi(current, up_to)
	target = mini(target, notes.size())
	if target <= current:
		return false
	bestiary[creature_id] = target
	return true


func add_research(research_id: String, amount: float) -> float:
	var v := clampf(float(research.get(research_id, 0.0)) + amount, 0.0, 100.0)
	research[research_id] = v
	return v


func log_entry(day: int, time_str: String, text: String) -> void:
	timeline.append({"day": day, "time": time_str, "text": text})
	if timeline.size() > 300:
		timeline.pop_front()


## Percentual de completude do grimório (0..1) para a barra de conhecimento.
func completeness() -> float:
	var total := 0.0
	var got := 0.0
	# Páginas
	total += DataRegistry.pages.size()
	for pid in page_reads:
		got += 1.0
	# Receitas
	total += DataRegistry.recipes.size()
	got += known_recipes.size()
	# Propriedades de ingredientes
	for ing in DataRegistry.ingredients.values():
		total += ing.properties.size() * 0.25
		got += revealed_props(ing.id).size() * 0.25
	# Bestiário
	for c in DataRegistry.creatures.values():
		total += c.notes.size() * 0.5
		got += bestiary_notes(c.id) * 0.5
	return 0.0 if total <= 0.0 else clampf(got / total, 0.0, 1.0)


func to_dict() -> Dictionary:
	return {
		"page_reads": page_reads.duplicate(),
		"known_recipes": known_recipes.duplicate(),
		"plant_catalogue": plant_catalogue.duplicate(true),
		"bestiary": bestiary.duplicate(),
		"insights": insights.duplicate(),
		"symbols": symbols.duplicate(),
		"research": research.duplicate(),
		"annotations": annotations.duplicate(),
		"timeline": timeline.duplicate(true),
	}


func from_dict(d: Dictionary) -> void:
	page_reads = {}
	for k in d.get("page_reads", {}):
		page_reads[k] = int(d.page_reads[k])
	known_recipes = Array(d.get("known_recipes", []))
	plant_catalogue = {}
	for k in d.get("plant_catalogue", {}):
		var e: Dictionary = d.plant_catalogue[k]
		plant_catalogue[k] = {"revealed": Array(e.get("revealed", [])), "harvests": int(e.get("harvests", 0))}
	bestiary = {}
	for k in d.get("bestiary", {}):
		bestiary[k] = int(d.bestiary[k])
	insights = Array(d.get("insights", []))
	symbols = d.get("symbols", {}).duplicate()
	research = {}
	for k in d.get("research", {}):
		research[k] = float(d.research[k])
	annotations = d.get("annotations", {}).duplicate()
	timeline = Array(d.get("timeline", []))
