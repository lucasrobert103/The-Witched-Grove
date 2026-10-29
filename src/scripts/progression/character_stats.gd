class_name CharacterStats
extends RefCounted
## Sistema A — Personagem: atributos, escolas de magia, saúde e mana.
## Fórmulas oficiais em docs/rule-engine.md (R-A1..R-A6).

const ATTR_MIN := 0
const ATTR_MAX := 10
const ATTR_START := 5
const SCHOOL_MAX := 100.0
const SPECIALIZATION_THRESHOLD := 40.0
const KNOWLEDGE_PER_TALENT := 60.0   # a cada 60 pontos somados nas escolas: +1 ponto de talento

var attributes: Dictionary = {}
var schools: Dictionary = {}
var health: float = 0.0
var mana: float = 0.0
var bonus_max_mana: float = 0.0
var talent_points: int = 0
var talents_granted: int = 0
var unlocked_specializations: Array = []


func _init() -> void:
	reset()


func reset() -> void:
	attributes.clear()
	schools.clear()
	for a in DataRegistry.attribute_ids():
		attributes[a] = ATTR_START
	for s in DataRegistry.school_ids():
		schools[s] = 0.0
	bonus_max_mana = 0.0
	talent_points = 0
	talents_granted = 0
	unlocked_specializations = []
	health = max_health()
	mana = max_mana()


func attr(id: String) -> int:
	return int(attributes.get(id, ATTR_START))


func school(id: String) -> float:
	return float(schools.get(id, 0.0))


func max_health() -> float:
	return 100.0 + attr("endurance") * 10.0


func max_mana() -> float:
	return 50.0 + attr("intellect") * 5.0 + bonus_max_mana


## Multiplicador de aprendizado de uma escola, a partir dos atributos afins.
## Atributo médio 5 → 1.0; 10 → 1.25; 0 → 0.75.
func learning_multiplier(school_id: String) -> float:
	var affinity: Array = DataRegistry.schools_doc.get("schools", {}).get(school_id, {}).get("affinity", [])
	if affinity.is_empty():
		return 1.0
	var total := 0.0
	for a in affinity:
		total += attr(a)
	var avg := total / affinity.size()
	return 0.75 + (avg / 10.0) * 0.5


## Adiciona experiência a uma escola. Retorna o ganho efetivo.
func add_school_xp(school_id: String, amount: float) -> float:
	if not schools.has(school_id) or amount <= 0.0:
		return 0.0
	var before := school(school_id)
	var after := minf(SCHOOL_MAX, before + amount * learning_multiplier(school_id))
	schools[school_id] = after
	_check_talents()
	_check_specializations()
	return after - before


func total_knowledge() -> float:
	var t := 0.0
	for s in schools.values():
		t += float(s)
	return t


func _check_talents() -> void:
	var earned := int(floor(total_knowledge() / KNOWLEDGE_PER_TALENT))
	if earned > talents_granted:
		var diff := earned - talents_granted
		talents_granted = earned
		talent_points += diff
		EventBus.notify.emit("Você ganhou %d ponto(s) de talento! Distribua-os no Livro → Escolas." % diff, "discovery")


func spend_talent(attr_id: String) -> bool:
	if talent_points <= 0 or not attributes.has(attr_id):
		return false
	if attr(attr_id) >= ATTR_MAX:
		return false
	var old_max_hp := max_health()
	var old_max_mp := max_mana()
	attributes[attr_id] = attr(attr_id) + 1
	talent_points -= 1
	health += max_health() - old_max_hp
	mana += max_mana() - old_max_mp
	EventBus.stats_changed.emit()
	return true


func specialization_defs() -> Array:
	return DataRegistry.schools_doc.get("specializations", [])


func _check_specializations() -> void:
	for spec in specialization_defs():
		if spec.id in unlocked_specializations:
			continue
		var ok := true
		for s in spec.schools:
			if school(s) < SPECIALIZATION_THRESHOLD:
				ok = false
		if ok:
			unlocked_specializations.append(spec.id)
			EventBus.notify.emit("Especialização desbloqueada: %s!" % spec.name, "discovery")
			EventBus.discovery_made.emit("especializacao", spec.id, "Especialização: %s" % spec.name)


func has_specialization(spec_id: String) -> bool:
	return spec_id in unlocked_specializations


func clamp_vitals() -> void:
	health = clampf(health, 0.0, max_health())
	mana = clampf(mana, 0.0, max_mana())


func to_dict() -> Dictionary:
	return {
		"attributes": attributes.duplicate(),
		"schools": schools.duplicate(),
		"health": health,
		"mana": mana,
		"bonus_max_mana": bonus_max_mana,
		"talent_points": talent_points,
		"talents_granted": talents_granted,
		"specializations": unlocked_specializations.duplicate(),
	}


func from_dict(d: Dictionary) -> void:
	reset()
	for k in d.get("attributes", {}):
		attributes[k] = int(d.attributes[k])
	for k in d.get("schools", {}):
		schools[k] = float(d.schools[k])
	bonus_max_mana = float(d.get("bonus_max_mana", 0.0))
	talent_points = int(d.get("talent_points", 0))
	talents_granted = int(d.get("talents_granted", 0))
	unlocked_specializations = Array(d.get("specializations", []))
	health = float(d.get("health", max_health()))
	mana = float(d.get("mana", max_mana()))
	clamp_vitals()
