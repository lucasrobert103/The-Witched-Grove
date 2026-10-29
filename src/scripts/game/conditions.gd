class_name Conditions
extends RefCounted
## Avaliador de condições compartilhado por diálogos, missões e portões do mundo.
## Uma lista de condições é um E lógico. Cada condição é um dicionário de uma chave:
##   flag, not_flag, quest_active, quest_done, quest_not_started, objective_current,
##   objective_done, has_item, item_quality, knows_spell, school, rep, time, moon,
##   page_read, ep, flag_count, bestiary_notes, any (lista de listas, OU), not (condição).


static func check_all(conds: Array, game: Object) -> bool:
	for c in conds:
		if not check(c, game):
			return false
	return true


static func check(c: Dictionary, game: Object) -> bool:
	for key in c:
		var v: Variant = c[key]
		match key:
			"flag":
				if not game.has_flag(v): return false
			"not_flag":
				if game.has_flag(v): return false
			"quest_active":
				if not game.quests.is_active(v): return false
			"quest_done":
				if not game.quests.is_done(v): return false
			"quest_not_started":
				if not game.quests.not_started(v): return false
			"objective_current":
				if game.quests.current_objective(v[0]) != v[1]: return false
			"objective_done":
				if not game.quests.objective_done(v[0], v[1]): return false
			"has_item":
				if game.inventory.count(v[0]) < int(v[1]): return false
			"item_quality":
				if game.inventory.count(v[0]) < 1 or game.inventory.quality(v[0]) < float(v[1]) - 0.0001: return false
			"knows_spell":
				if not game.spells.is_known(v): return false
			"school":
				if game.stats.school(v[0]) < float(v[1]): return false
			"rep":
				if game.reputation(v[0]) < int(v[1]): return false
			"time":
				if v == "night" and not game.clock.is_night(): return false
				if v == "day" and game.clock.is_night(): return false
				if v == "dusk" and not game.clock.is_dusk(): return false
			"moon":
				if game.clock.moon_name() != v: return false
			"page_read":
				if game.grimoire.times_read(v) < 1: return false
			"ep":
				if game.inventory.currency < int(v): return false
			"flag_count":
				var n := 0
				for f in game.flags:
					if String(f).begins_with(v[0]):
						n += 1
				if n < int(v[1]): return false
			"bestiary_notes":
				if game.grimoire.bestiary_notes(v[0]) < int(v[1]): return false
			"any":
				var any_ok := false
				for group in v:
					if check_all(group, game):
						any_ok = true
						break
				if not any_ok: return false
			"not":
				if check(v, game): return false
			_:
				push_warning("Condição desconhecida: %s" % key)
				return false
	return true
