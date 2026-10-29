class_name QuestLog
extends RefCounted
## Sistema I — Missões. Estado das missões e avaliação de objetivos por condições.
## Recompensas e consequências são aplicadas pelo orquestrador (Game).

var states: Dictionary = {}   # quest_id -> {"status", "objectives": {id: bool}, "outcome", "started_day"}
var tracked: String = ""


func def(quest_id: String) -> Dictionary:
	return DataRegistry.quests.get(quest_id, {})


func not_started(quest_id: String) -> bool:
	return not states.has(quest_id)


func is_active(quest_id: String) -> bool:
	return states.get(quest_id, {}).get("status", "") == "active"


func is_done(quest_id: String) -> bool:
	return states.get(quest_id, {}).get("status", "") == "done"


func outcome(quest_id: String) -> String:
	return states.get(quest_id, {}).get("outcome", "")


func start(quest_id: String, day: int) -> bool:
	if states.has(quest_id) or not DataRegistry.quests.has(quest_id):
		return false
	var objs := {}
	for o in def(quest_id).objectives:
		objs[o.id] = false
	states[quest_id] = {"status": "active", "objectives": objs, "outcome": "", "started_day": day}
	if tracked == "" or not is_active(tracked):
		tracked = quest_id
	return true


func objective_done(quest_id: String, obj_id: String) -> bool:
	return bool(states.get(quest_id, {}).get("objectives", {}).get(obj_id, false))


## Primeiro objetivo ainda não concluído (para missões sequenciais), ou "".
func current_objective(quest_id: String) -> String:
	if not is_active(quest_id):
		return ""
	for o in def(quest_id).objectives:
		if not objective_done(quest_id, o.id):
			return o.id
	return ""


func visible_objectives(quest_id: String) -> Array:
	## Objetivos a mostrar: em missões sequenciais, apenas os concluídos + o atual.
	var out: Array = []
	var q := def(quest_id)
	for o in q.objectives:
		var done := objective_done(quest_id, o.id)
		out.append({"id": o.id, "text": o.text, "done": done})
		if q.get("sequential", false) and not done:
			break
	return out


func all_objectives_done(quest_id: String) -> bool:
	for o in def(quest_id).objectives:
		if not objective_done(quest_id, o.id):
			return false
	return true


## Reavalia objetivos de todas as missões ativas.
## Retorna {"updated": [quest_ids], "ready": [quest_ids prontas para auto-concluir]}
func refresh(game: Object) -> Dictionary:
	var updated: Array = []
	var ready: Array = []
	for qid in states.keys():
		if not is_active(qid):
			continue
		var q := def(qid)
		var changed := false
		var keep_going := true
		for o in q.objectives:
			if objective_done(qid, o.id):
				continue
			if q.get("sequential", false) and not keep_going:
				break
			if Conditions.check_all(o.get("complete_when", []), game):
				states[qid].objectives[o.id] = true
				changed = true
			elif q.get("sequential", false):
				keep_going = false
		if changed:
			updated.append(qid)
		if q.get("auto_complete", false) and all_objectives_done(qid):
			ready.append(qid)
	return {"updated": updated, "ready": ready}


## Escolhe o desfecho cujas condições "if" são satisfeitas (ou "default").
func resolve_outcome(quest_id: String, game: Object) -> String:
	var outs: Dictionary = def(quest_id).get("outcomes", {})
	for key in outs:
		if Conditions.check_all(outs[key].get("if", []), game):
			return key
	return "default"


func mark_done(quest_id: String, outcome_id: String) -> bool:
	if not is_active(quest_id):
		return false
	states[quest_id].status = "done"
	states[quest_id].outcome = outcome_id
	for k in states[quest_id].objectives:
		states[quest_id].objectives[k] = true
	if tracked == quest_id:
		tracked = ""
		for qid in states:
			if is_active(qid):
				tracked = qid
				break
	return true


func active_ids() -> Array:
	var out: Array = []
	for qid in DataRegistry.quest_order:
		if is_active(qid):
			out.append(qid)
	return out


func done_ids() -> Array:
	var out: Array = []
	for qid in DataRegistry.quest_order:
		if is_done(qid):
			out.append(qid)
	return out


func to_dict() -> Dictionary:
	return {"states": states.duplicate(true), "tracked": tracked}


func from_dict(d: Dictionary) -> void:
	states = {}
	var raw: Dictionary = d.get("states", {})
	for qid in raw:
		if not DataRegistry.quests.has(qid):
			continue
		var s: Dictionary = raw[qid]
		var objs := {}
		for o in def(qid).objectives:
			objs[o.id] = bool(s.get("objectives", {}).get(o.id, false))
		states[qid] = {"status": str(s.get("status", "active")), "objectives": objs,
			"outcome": str(s.get("outcome", "")), "started_day": int(s.get("started_day", 1))}
	tracked = str(d.get("tracked", ""))
