class_name BookPanel
extends ModalPanel
## O Livro de Asterion: grimório, inventário, missões, escolas, mapa, casa, diário e opções.

const TABS := [
	["grimorio", "Grimório"], ["inventario", "Inventário"], ["missoes", "Missões"], ["escolas", "Escolas"],
	["mapa", "Mapa"], ["casa", "Casa"], ["diario", "Diário"], ["opcoes", "Opções"],
]
const GRIM_SUB := [["feiticos", "Feitiços"], ["plantas", "Plantas"], ["receitas", "Receitas"], ["bestiario", "Bestiário"], ["saber", "Saber"]]

var tab := "grimorio"
var sub := "feiticos"
var _tabbar: HFlowContainer
var _body: VBoxContainer
var _scroll: ScrollContainer


func open(payload: Dictionary) -> void:
	tab = payload.get("tab", tab)
	var only_options: bool = payload.get("only_options", false)
	build_frame("Configurações" if only_options else "Livro de Asterion", 0.9 if only_options else 0.96, 0.95, false)
	_tabbar = HFlowContainer.new()
	content.add_child(_tabbar)
	_tabbar.visible = not only_options
	for t in TABS:
		var tid: String = t[0]
		var b := UITheme.button(t[1], func(): _set_tab(tid), 52)
		b.toggle_mode = true
		b.set_meta("tab", tid)
		_tabbar.add_child(b)
	_scroll = ScrollContainer.new()
	_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	content.add_child(_scroll)
	_body = VBoxContainer.new()
	_body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_body.add_theme_constant_override("separation", 10)
	_scroll.add_child(_body)
	AudioManager.play_sfx("ui_open", -4.0)
	_render()


func _set_tab(t: String) -> void:
	tab = t
	AudioManager.play_sfx("page_turn", -6.0)
	_render()


func _render() -> void:
	for b in _tabbar.get_children():
		b.button_pressed = b.get_meta("tab") == tab
	for c in _body.get_children():
		c.queue_free()
	_scroll.scroll_vertical = 0
	match tab:
		"grimorio": _grimoire()
		"inventario": _inventory()
		"missoes": _quests()
		"escolas": _schools()
		"mapa": _map()
		"casa": _house()
		"diario": _journal()
		"opcoes": _options()


func _h(text: String) -> void:
	_body.add_child(UITheme.label(text, 1.15, UITheme.GOLD))


func _p(bb: String, size: float = 0.92) -> RichTextLabel:
	var r := UITheme.rich(bb, size)
	_body.add_child(r)
	return r


# ------------------------------------------------------------------ grimório

func _grimoire() -> void:
	var pct := Game.grimoire.completeness()
	_p("Conhecimento registrado: [b]%d%%[/b]" % int(pct * 100.0))
	var bar := UITheme.bar(UITheme.GOLD, 20)
	bar.max_value = 1.0
	bar.value = pct
	_body.add_child(bar)
	var row := HFlowContainer.new()
	_body.add_child(row)
	for s in GRIM_SUB:
		var sid: String = s[0]
		var b := UITheme.button(s[1], _set_sub.bind(sid), 48)
		b.toggle_mode = true
		b.button_pressed = sub == sid
		row.add_child(b)
	match sub:
		"feiticos": _g_spells()
		"plantas": _g_plants()
		"receitas": _g_recipes()
		"bestiario": _g_bestiary()
		"saber": _g_lore()


func _set_sub(s: String) -> void:
	sub = s
	_render()


func _g_spells() -> void:
	var by_school := {}
	for sid in DataRegistry.spell_order:
		var d: Dictionary = DataRegistry.spells[sid]
		if not by_school.has(d.school):
			by_school[d.school] = []
		by_school[d.school].append(sid)
	for school in DataRegistry.school_ids():
		var list: Array = by_school.get(school, [])
		var c := Color(DataRegistry.schools_doc.schools[school].color)
		_p("[b][color=%s]%s[/color][/b] — nível %d" % [UITheme.color_hex(c), DataRegistry.school_name(school), int(Game.stats.school(school))], 1.0)
		for sid in list:
			var spell_id: String = sid
			var d: Dictionary = DataRegistry.spells[spell_id]
			var k := Game.spells.get_knowledge(spell_id)
			if k <= 0.0:
				_p("   ???  [i](um feitiço de %s ainda não descoberto)[/i]" % DataRegistry.school_name(school), 0.85)
				continue
			var card := UITheme.card()
			var v := VBoxContainer.new()
			card.add_child(v)
			v.add_child(UITheme.rich("[b]%s[/b]  ·  compreensão %d%%  ·  mana %d  ·  recarga %ds  ·  exige nível %d\n%s\n[i][color=#c9a5ff]%s[/color][/i]" % [d.name, int(k), int(Game.spells.mana_cost(spell_id, Game.stats)), int(d.cooldown), int(d.level_required), d.description, d.flavor_text], 0.85))
			if Game.spells.is_known(spell_id):
				var slots := HFlowContainer.new()
				v.add_child(slots)
				slots.add_child(UITheme.label("Equipar no espaço:", 0.8))
				for i in SpellSystem.SLOT_COUNT:
					var idx := i
					var b := UITheme.button(str(i + 1), _equip.bind(idx, spell_id), 48)
					b.custom_minimum_size.x = 56
					b.disabled = Game.spells.slots[i] == spell_id
					slots.add_child(b)
			_body.add_child(card)


func _equip(i: int, spell_id: String) -> void:
	Game.spells.set_slot(i, spell_id)
	_render()


func _g_plants() -> void:
	for ing_id in DataRegistry.ingredients:
		var d: Dictionary = DataRegistry.ingredients[ing_id]
		if not Game.grimoire.is_catalogued(ing_id):
			_p("???  [i](%s)[/i]" % d.rarity, 0.85)
			continue
		var props: Array = []
		for p in d.properties:
			props.append(DataRegistry.property_name(p) if p in Game.grimoire.revealed_props(ing_id) else "???")
		var plant := DataRegistry.plant_producing(ing_id)
		var grow := ""
		if not plant.is_empty():
			grow = "\nCultivo: %s, %s, %.1f dia(s)%s" % [DataRegistry.season_name(plant.season), GardenPlot._light_name(plant.light), float(plant.growth_days), " · planta lunar" if plant.get("lunar", false) else ""]
		_p("[b][color=%s]%s[/color][/b] (%s, %s)\nPropriedades: %s%s\n[i]%s[/i]" % [d.color, d.name, d.rarity, d.state, ", ".join(props), grow, d.description], 0.85)


func _g_recipes() -> void:
	for rid in DataRegistry.recipe_order:
		var r: Dictionary = DataRegistry.recipes[rid]
		if not Game.grimoire.knows_recipe(rid):
			_p("???  [i](receita não descoberta)[/i]", 0.85)
			continue
		var req: Array = []
		for p in r.requires:
			req.append(DataRegistry.property_name(p))
		var forb: Array = []
		for p in r.get("forbids", []):
			forb.append(DataRegistry.property_name(p))
		var tech: Array = []
		for t in r.technique:
			tech.append(DataRegistry.technique_name(t))
		var it: Dictionary = DataRegistry.items[r.output]
		_p("[b]%s[/b] — despertar: %s%s · técnica: %s\n%s" % [r.name, ", ".join(req), (" · não pode ter: " + ", ".join(forb)) if not forb.is_empty() else "", " → ".join(tech), it.get("description", "")], 0.85)
	if not Game.grimoire.insights.is_empty():
		_h("Intuições de experimentos")
		for ins in Game.grimoire.insights:
			_p("• " + ins, 0.85)


func _g_bestiary() -> void:
	for cid in DataRegistry.creatures:
		var c: Dictionary = DataRegistry.creatures[cid]
		var n := Game.grimoire.bestiary_notes(cid)
		if n == 0:
			_p("???  [i](criatura não observada)[/i]", 0.85)
			continue
		var notes: Array = []
		for i in n:
			notes.append("• " + c.notes[i])
		var full: bool = n >= c.notes.size()
		_p("[b]%s[/b] — %s, ativa: %s\n%s%s" % [c.name, c.kind, c.active, "\n".join(notes), ("\n[color=#7dffa0]Resolução: %s[/color]" % c.resolution) if full else "\n[i](observe mais para completar)[/i]"], 0.85)


func _g_lore() -> void:
	_h("Pesquisas")
	for rid in DataRegistry.research:
		var r: Dictionary = DataRegistry.research[rid]
		var v := float(Game.grimoire.research.get(rid, 0.0))
		_p("[b]%s[/b] — %d%%\n[i]%s[/i]" % [r.name, int(v), r.description], 0.9)
	_h("Símbolos")
	if Game.grimoire.symbols.is_empty():
		_p("[i]Nenhum símbolo compreendido ainda.[/i]")
	for s in Game.grimoire.symbols:
		_p("• %s = %s" % [s.replace("_", " "), Game.grimoire.symbols[s]], 0.88)
	_h("Páginas lidas")
	for pid in Game.grimoire.page_reads:
		_p("• %s (%d/5)" % [DataRegistry.pages[pid].title, mini(Game.grimoire.times_read(pid), 5)], 0.85)


# ------------------------------------------------------------------ inventário

func _inventory() -> void:
	_p("[b]%d EP[/b] · Peso %.1f / %.0f  [i](melhore o Armazém para levar mais)[/i]" % [Game.inventory.currency, Game.inventory.total_weight(), Game.inventory.capacity], 1.0)
	var cats := [["pocao", "Poções e bebidas"], ["ingrediente", "Ingredientes"], ["semente", "Sementes"], ["ferramenta", "Ferramentas"], ["artefato", "Artefatos"]]
	for c in cats:
		var ids := Game.inventory.ids_by_category(c[0])
		if ids.is_empty():
			continue
		_h(c[1])
		for id in ids:
			var iid: String = id
			var it: Dictionary = DataRegistry.items[iid]
			var row := HBoxContainer.new()
			var l := UITheme.rich("[b][color=%s]%s[/color][/b] ×%d  [%s]\n[i]%s[/i]" % [it.get("color", "#ffffff"), it.name, Game.inventory.count(iid), DataRegistry.quality_tier(Game.inventory.quality(iid)), it.get("description", "")], 0.85)
			l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			row.add_child(l)
			var use_type: String = it.get("use", {}).get("type", "none")
			if use_type in ["heal", "mana_pct", "buff", "grow_area"]:
				row.add_child(UITheme.button("Usar", _use.bind(iid), 52))
			_body.add_child(row)
	if Game.inventory.stacks.is_empty():
		_p("[i]Bolsos vazios. Que tal colher alguma coisa?[/i]")


func _use(id: String) -> void:
	var r := Game.use_item(id)
	if not r.ok:
		EventBus.notify.emit(r.reason, "warning")
	else:
		AudioManager.play_sfx("pickup")
	_render()


# ------------------------------------------------------------------ missões

func _quests() -> void:
	var cat_names := {"main": "Principal", "side": "Secundária", "investigation": "Investigação"}
	var active := Game.quests.active_ids()
	_h("Em andamento")
	if active.is_empty():
		_p("[i]Nenhuma missão ativa.[/i]")
	for qid in active:
		var q: Dictionary = DataRegistry.quests[qid]
		var lines: Array = []
		for o in Game.quests.visible_objectives(qid):
			lines.append(("[color=#7dffa0][s]%s[/s] (feito)[/color]" % o.text) if o.done else ("• " + o.text))
		var tracked: bool = Game.quests.tracked == qid
		var card := UITheme.card(Color(0.3, 0.2, 0.45, 0.5) if tracked else Color(1, 1, 1, 0.05), UITheme.GOLD if tracked else Color(1, 1, 1, 0.12))
		var v := VBoxContainer.new()
		card.add_child(v)
		v.add_child(UITheme.rich("[b]%s[/b]  [i](%s)[/i]\n%s\n%s" % [q.title, cat_names.get(q.category, q.category), q.summary, "\n".join(lines)], 0.88))
		if not tracked:
			v.add_child(UITheme.button("Acompanhar", _track.bind(qid), 48))
		_body.add_child(card)
	var done := Game.quests.done_ids()
	if not done.is_empty():
		_h("Concluídas")
		for qid in done:
			var q: Dictionary = DataRegistry.quests[qid]
			var out := Game.quests.outcome(qid)
			var txt: String = q.get("outcomes", {}).get(out, {}).get("text", "")
			_p("[b]%s[/b]%s" % [q.title, ("\n[i]" + txt + "[/i]") if txt != "" else ""], 0.85)


func _track(qid: String) -> void:
	Game.quests.tracked = qid
	EventBus.quest_updated.emit(qid)
	_render()


# ------------------------------------------------------------------ escolas e personagem

func _schools() -> void:
	var s := Game.stats
	_p("[b]Asterion[/b] — %s · Saúde %d/%d · Mana %d/%d" % [DataRegistry.player_def.get("title", ""), int(s.health), int(s.max_health()), int(s.mana), int(s.max_mana())], 1.0)
	_h("Atributos" + ("  (%d ponto(s) de talento)" % s.talent_points if s.talent_points > 0 else ""))
	for a in DataRegistry.attribute_ids():
		var aid: String = a
		var row := HBoxContainer.new()
		var l := UITheme.rich("[b]%s[/b] %d/10 — [i]%s[/i]" % [DataRegistry.attribute_name(aid), s.attr(aid), DataRegistry.schools_doc.attributes[aid].description], 0.85)
		l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(l)
		if s.talent_points > 0 and s.attr(aid) < 10:
			row.add_child(UITheme.button("+1", _spend.bind(aid), 48))
		_body.add_child(row)
	_h("Escolas de Magia")
	for sch in DataRegistry.school_ids():
		var d: Dictionary = DataRegistry.schools_doc.schools[sch]
		var row := VBoxContainer.new()
		row.add_child(UITheme.rich("[b][color=%s]%s[/color][/b] %d/100 · aprendizado ×%.2f — [i]%s[/i]" % [d.color, d.name, int(s.school(sch)), s.learning_multiplier(sch), d.identity], 0.85))
		var b := UITheme.bar(Color(d.color), 14)
		b.max_value = 100
		b.value = s.school(sch)
		row.add_child(b)
		_body.add_child(row)
	_h("Especializações (40+ em duas escolas)")
	for spec in s.specialization_defs():
		var names: Array = []
		for sc in spec.schools:
			names.append(DataRegistry.school_name(sc))
		var has := s.has_specialization(spec.id)
		_p("%s [b]%s[/b] (%s) — %s" % ["[color=#7dffa0]ATIVA[/color]" if has else "•", spec.name, " + ".join(names), spec.bonus], 0.85)
	_h("Reputação")
	for fid in DataRegistry.faction_order:
		var f: Dictionary = DataRegistry.factions[fid]
		var v := Game.reputation(fid)
		_p("[b][color=%s]%s[/color][/b] %+d (%s) — %s" % [f.color, f.name, v, DataRegistry.reputation_tier(v), f.goal], 0.85)


func _spend(aid: String) -> void:
	Game.stats.spend_talent(aid)
	_render()


# ------------------------------------------------------------------ mapa

func _map() -> void:
	var holder := Control.new()
	holder.custom_minimum_size = Vector2(0, 420)
	_body.add_child(holder)
	var mm := Minimap.new()
	mm.full_map = true
	mm.world_radius = 58.0
	var world := get_tree().get_first_node_in_group("game_world")
	if world:
		mm.player = world.player
		mm.terrain = world.builder.terrain
	mm.custom_minimum_size = Vector2(420, 420)
	mm.size = Vector2(420, 420)
	mm.position = Vector2(0, 0)
	holder.add_child(mm)
	_h("Regiões")
	for r in DataRegistry.regions:
		var st: String = {"jogavel_v1": "[color=#7dffa0]aberta[/color]", "planejada_v1": "[color=#f3c74f]planejada (V1)[/color]", "futura": "[color=#9a96a8]futura[/color]"}.get(r.status, r.status)
		_p("[b]%s[/b] — %s · %s\n[i]%s[/i]" % [r.name, r.focus, st, r.mood], 0.85)


# ------------------------------------------------------------------ casa

func _house() -> void:
	_p("A cabana cresce com você. Cada melhoria muda uma mecânica — nada é só decoração.", 0.9)
	for rid in DataRegistry.room_order:
		var d: Dictionary = DataRegistry.house_rooms[rid]
		var lvl := Game.house.level(rid)
		var desc: Array = d.get("upgrade_desc", [])
		var card := UITheme.card()
		var v := VBoxContainer.new()
		card.add_child(v)
		var state := "Nível %d/%d — %s" % [lvl, d.max_level, desc[clampi(lvl, 0, desc.size() - 1)]] if Game.house.is_unlocked(rid) else "Bloqueado: %s" % Game.house.unlock_text(rid)
		v.add_child(UITheme.rich("[b]%s[/b] — %s\n%s" % [d.name, d.function, state], 0.88))
		var chk := Game.house.can_upgrade(rid, Game.inventory.currency)
		if Game.house.is_unlocked(rid) and Game.house.next_cost(rid) > 0:
			var b := UITheme.button("Melhorar: %s (%d EP)" % [desc[mini(lvl + 1, desc.size() - 1)] if lvl + 1 < desc.size() else "", Game.house.next_cost(rid)], _upgrade.bind(rid), 52)
			b.disabled = not chk.ok
			v.add_child(b)
		_body.add_child(card)


func _upgrade(rid: String) -> void:
	var r := Game.upgrade_room(rid)
	if not r.ok:
		EventBus.notify.emit(r.reason, "warning")
	else:
		AudioManager.play_sfx("quest_complete")
	_render()


# ------------------------------------------------------------------ diário

func _journal() -> void:
	_p("Tudo o que você descobriu, na ordem em que aconteceu.", 0.9)
	var tl: Array = Game.grimoire.timeline
	for i in range(tl.size() - 1, maxi(-1, tl.size() - 80), -1):
		var e: Dictionary = tl[i]
		_p("[color=#f3c74f]Dia %d, %s[/color] — %s" % [int(e.day), e.time, e.text], 0.85)


# ------------------------------------------------------------------ opções

func _options() -> void:
	_h("Áudio")
	_slider("Volume geral", Settings.master_volume, func(v): Settings.master_volume = v)
	_slider("Música", Settings.music_volume, func(v): Settings.music_volume = v)
	_slider("Efeitos", Settings.sfx_volume, func(v): Settings.sfx_volume = v)
	_slider("Ambiente", Settings.ambient_volume, func(v): Settings.ambient_volume = v)
	_h("Acessibilidade")
	var ts := HFlowContainer.new()
	_body.add_child(ts)
	ts.add_child(UITheme.label("Tamanho do texto: ", 0.95))
	for i in Settings.TEXT_SCALES.size():
		var b := UITheme.button(["Normal", "Grande", "Enorme"][i], _text_scale.bind(i), 48)
		b.toggle_mode = true
		b.button_pressed = Settings.text_scale_index == i
		ts.add_child(b)
	_check("Alto contraste", Settings.high_contrast, func(v): Settings.high_contrast = v, true)
	_check("Vibração", Settings.vibration, func(v): Settings.vibration = v)
	_check("Dicas do Nimbus", Settings.show_hints, func(v): Settings.show_hints = v)
	_check("Inverter câmera vertical", Settings.invert_camera_y, func(v): Settings.invert_camera_y = v)
	_slider("Sensibilidade da câmera", (Settings.camera_sensitivity - 0.4) / 1.6, func(v): Settings.camera_sensitivity = 0.4 + v * 1.6)
	_h("Gráficos")
	var qs := HFlowContainer.new()
	_body.add_child(qs)
	for i in 3:
		var b := UITheme.button(["Leve (aparelhos simples)", "Equilibrado", "Bonito"][i], _quality.bind(i), 48)
		b.toggle_mode = true
		b.button_pressed = Settings.quality == i
		qs.add_child(b)
	_p("[i]A densidade da grama muda ao recarregar o jogo.[/i]", 0.8)
	_h("Jogo")
	var row := HFlowContainer.new()
	_body.add_child(row)
	if get_tree().get_first_node_in_group("game_world"):
		row.add_child(UITheme.button("Salvar agora", _save))
		row.add_child(UITheme.button("Salvar e voltar ao menu", _to_menu))
	_p("Idioma: Português (Brasil). Inglês e Espanhol planejados para a Fase 6.", 0.8)


func _slider(text: String, value: float, cb: Callable) -> void:
	var row := HBoxContainer.new()
	var l := UITheme.label(text, 0.95)
	l.custom_minimum_size.x = 340
	row.add_child(l)
	var s := HSlider.new()
	s.min_value = 0.0
	s.max_value = 1.0
	s.step = 0.05
	s.value = value
	s.custom_minimum_size = Vector2(0, 48)
	s.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	s.value_changed.connect(_on_slider.bind(cb))
	row.add_child(s)
	_body.add_child(row)


func _check(text: String, value: bool, cb: Callable, rebuild: bool = false) -> void:
	var c := CheckButton.new()
	c.text = text
	c.button_pressed = value
	c.custom_minimum_size = Vector2(0, 52)
	c.focus_mode = Control.FOCUS_NONE
	c.toggled.connect(_on_check.bind(cb, rebuild))
	_body.add_child(c)


func _on_slider(v: float, cb: Callable) -> void:
	cb.call(v)
	Settings.apply()
	Settings.save_settings()


func _on_check(v: bool, cb: Callable, rebuild: bool) -> void:
	cb.call(v)
	Settings.apply()
	Settings.save_settings()
	_after_toggle(rebuild)


func _after_toggle(rebuild: bool) -> void:
	if rebuild:
		theme = UITheme.get_theme()
		EventBus.panel_requested.emit("theme_changed", {})


func _text_scale(i: int) -> void:
	Settings.text_scale_index = i
	Settings.apply()
	Settings.save_settings()
	theme = UITheme.get_theme()
	EventBus.panel_requested.emit("theme_changed", {})
	_render()


func _quality(i: int) -> void:
	Settings.quality = i
	Settings.apply()
	Settings.save_settings()
	_render()


func _save() -> void:
	var world := get_tree().get_first_node_in_group("game_world")
	if world:
		world.save_now()
	EventBus.notify.emit("Jogo salvo.", "info")


func _to_menu() -> void:
	_save()
	Game.world_running = false
	get_tree().change_scene_to_file("res://src/scenes/ui/main_menu.tscn")
