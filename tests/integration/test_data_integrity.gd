extends TestCase
## Garante que todos os dados se referenciam corretamente (rule-engine: R-0).

const KNOWN_EFFECTS := ["set_flag", "clear_flag", "start_quest", "complete_quest", "give_item", "take_item", "give_ep", "take_ep", "rep", "read_page", "school_xp", "open_shop", "bestiary", "research", "upgrade_room", "notify"]
const KNOWN_CONDS := ["flag", "not_flag", "quest_active", "quest_done", "quest_not_started", "objective_current", "objective_done", "has_item", "item_quality", "knows_spell", "school", "rep", "time", "moon", "page_read", "ep", "bestiary_notes", "any", "not"]


func test_sem_erros_de_carga() -> void:
	assert_true(DataRegistry.load_errors.is_empty(), "erros: %s" % str(DataRegistry.load_errors))


func test_quantidades_minimas() -> void:
	assert_true(DataRegistry.spells.size() >= 24, "24+ feitiços")
	assert_true(DataRegistry.ingredients.size() >= 20, "20+ ingredientes")
	assert_true(DataRegistry.recipes.size() >= 10, "10+ receitas")
	assert_true(DataRegistry.npcs.size() >= 12, "12 NPCs principais")
	assert_true(DataRegistry.factions.size() >= 5, "5+ facções")
	assert_true(DataRegistry.regions.size() >= 8, "8 regiões planejadas")


func test_ingredientes_tem_5_a_7_propriedades() -> void:
	var valid: Dictionary = DataRegistry.schools_doc.property_names
	for ing in DataRegistry.ingredients.values():
		assert_true(ing.properties.size() >= 5 and ing.properties.size() <= 7, "%s: 5-7 propriedades" % ing.id)
		for p in ing.properties:
			assert_true(valid.has(p), "%s: propriedade desconhecida %s" % [ing.id, p])


func test_receitas() -> void:
	for r in DataRegistry.recipes.values():
		assert_true(DataRegistry.items.has(r.output), "receita %s: saída inexistente" % r.id)
		for t in r.technique:
			assert_true(t in DataRegistry.technique_ids(), "receita %s: técnica %s" % [r.id, t])


func test_cada_receita_e_fabricavel() -> void:
	## Para cada receita, existe ao menos uma combinação de 2 ou 3 ingredientes que a produz.
	var ids: Array = DataRegistry.ingredients.keys()
	var found := {}
	for i in ids.size():
		for j in range(i + 1, ids.size()):
			var r := AlchemyLab.evaluate([ids[i], ids[j]], [], {"alchemy": 100.0})
			if r.success:
				found[r.recipe_id] = true
	for i in ids.size():
		for j in range(i + 1, ids.size()):
			for k in range(j + 1, ids.size()):
				if found.size() == DataRegistry.recipes.size():
					break
				var r := AlchemyLab.evaluate([ids[i], ids[j], ids[k]], [], {"alchemy": 100.0})
				if r.success:
					found[r.recipe_id] = true
	for rid in DataRegistry.recipes:
		assert_true(found.has(rid), "receita %s não é fabricável com nenhuma combinação" % rid)


func test_plantas_e_sementes() -> void:
	for p in DataRegistry.plants.values():
		assert_true(DataRegistry.ingredients.has(p.produces), "planta %s produz item inexistente" % p.id)
		assert_true(DataRegistry.items.has(p.seed), "planta %s: semente inexistente" % p.id)
		assert_eq(DataRegistry.items[p.seed].get("plant", ""), p.id, "semente %s aponta para a planta" % p.seed)


func test_paginas() -> void:
	for pg in DataRegistry.pages.values():
		var t: Dictionary = pg.get("teaches", {})
		if t.has("spell"):
			assert_true(DataRegistry.spells.has(t.spell), "página %s: feitiço inexistente" % pg.id)
			assert_true(DataRegistry.spells[t.spell].implemented, "página %s ensina feitiço sem efeito na V1" % pg.id)
		if t.has("recipe"):
			assert_true(DataRegistry.recipes.has(t.recipe), "página %s: receita inexistente" % pg.id)
		assert_true(DataRegistry.school_ids().has(pg.school), "página %s: escola" % pg.id)


func test_npcs() -> void:
	for n in DataRegistry.npcs.values():
		assert_true(DataRegistry.factions.has(n.faction), "npc %s: facção" % n.id)
		for it in n.get("trade", []):
			assert_true(DataRegistry.items.has(it), "npc %s vende item inexistente %s" % [n.id, it])


func _check_conds(conds: Array, where: String) -> void:
	for c in conds:
		for k in c:
			assert_true(k in KNOWN_CONDS, "%s: condição desconhecida %s" % [where, k])
			var v: Variant = c[k]
			match k:
				"quest_active", "quest_done", "quest_not_started":
					assert_true(DataRegistry.quests.has(v), "%s: missão %s" % [where, v])
				"objective_current", "objective_done":
					assert_true(DataRegistry.quests.has(v[0]), "%s: missão %s" % [where, v[0]])
					var ok := false
					for o in DataRegistry.quests.get(v[0], {}).get("objectives", []):
						if o.id == v[1]:
							ok = true
					assert_true(ok, "%s: objetivo %s/%s" % [where, v[0], v[1]])
				"has_item", "item_quality":
					assert_true(DataRegistry.items.has(v[0]), "%s: item %s" % [where, v[0]])
				"knows_spell":
					assert_true(DataRegistry.spells.has(v), "%s: feitiço %s" % [where, v])
				"page_read":
					assert_true(DataRegistry.pages.has(v), "%s: página %s" % [where, v])
				"any":
					for g in v:
						_check_conds(g, where)
				"not":
					_check_conds([v], where)


func _check_effects(effects: Array, where: String) -> void:
	for e in effects:
		for k in e:
			assert_true(k in KNOWN_EFFECTS, "%s: efeito desconhecido %s" % [where, k])
			var v: Variant = e[k]
			match k:
				"give_item", "take_item":
					assert_true(DataRegistry.items.has(v[0]), "%s: item %s" % [where, v[0]])
				"start_quest":
					assert_true(DataRegistry.quests.has(v), "%s: missão %s" % [where, v])
				"complete_quest":
					assert_true(DataRegistry.quests.has(v[0]), "%s: missão %s" % [where, v[0]])
				"rep":
					assert_true(DataRegistry.factions.has(v[0]), "%s: facção %s" % [where, v[0]])
				"read_page":
					assert_true(DataRegistry.pages.has(v), "%s: página %s" % [where, v])
				"bestiary":
					assert_true(DataRegistry.creatures.has(v[0]), "%s: criatura %s" % [where, v[0]])
				"research":
					assert_true(DataRegistry.research.has(v[0]), "%s: pesquisa %s" % [where, v[0]])
				"upgrade_room":
					assert_true(DataRegistry.house_rooms.has(v), "%s: cômodo %s" % [where, v])


func test_dialogos() -> void:
	for npc in DataRegistry.dialogues:
		var t: Dictionary = DataRegistry.dialogues[npc]
		var nodes: Dictionary = t.nodes
		for e in t.entries:
			assert_true(nodes.has(e.node), "%s: entrada aponta para nó inexistente %s" % [npc, e.node])
			_check_conds(e.get("if", []), "%s/entrada" % npc)
		for nid in nodes:
			var n: Dictionary = nodes[nid]
			_check_effects(n.get("effects", []), "%s/%s" % [npc, nid])
			if n.has("goto_after"):
				assert_true(nodes.has(n.goto_after), "%s/%s: goto_after" % [npc, nid])
			for o in n.get("options", []):
				var g: String = o.get("goto", "end")
				assert_true(g == "end" or nodes.has(g), "%s/%s: goto %s" % [npc, nid, g])
				_check_conds(o.get("if", []), "%s/%s" % [npc, nid])
				_check_effects(o.get("effects", []), "%s/%s" % [npc, nid])


func test_missoes() -> void:
	for q in DataRegistry.quests.values():
		assert_true(q.objectives.size() > 0, "missão %s sem objetivos" % q.id)
		for o in q.objectives:
			_check_conds(o.get("complete_when", []), "%s/%s" % [q.id, o.id])
		for oid in q.get("outcomes", {}):
			_check_conds(q.outcomes[oid].get("if", []), "%s/desfecho %s" % [q.id, oid])
			_check_effects(q.outcomes[oid].get("effects", []), "%s/desfecho %s" % [q.id, oid])
		if q.has("next"):
			assert_true(DataRegistry.quests.has(q.next), "missão %s: next" % q.id)
		for it in q.get("rewards", {}).get("items", {}):
			assert_true(DataRegistry.items.has(it), "missão %s: recompensa %s" % [q.id, it])
