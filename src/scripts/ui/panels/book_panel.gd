class_name BookPanel
extends ModalPanel
## O Grimório de Asterion como um livro de verdade: capa de couro que se abre,
## páginas de pergaminho, índice de capítulos com fitas e virada de página.

const TABS := [
	["grimorio", "I. Grimório"], ["inventario", "II. Bolsa"], ["missoes", "III. Missões"], ["escolas", "IV. Escolas"],
	["mapa", "V. Mapa"], ["casa", "VI. Casa"], ["diario", "VII. Diário"], ["opcoes", "VIII. Opções"],
]
const TAB_TITLES := {
	"grimorio": "Grimório", "inventario": "Bolsa e Armazém", "missoes": "Missões", "escolas": "Escolas de Magia",
	"mapa": "Mapa do Vale", "casa": "A Cabana", "diario": "Diário", "opcoes": "Opções",
}
const GRIM_SUB := [["feiticos", "Feitiços"], ["plantas", "Plantas"], ["receitas", "Receitas"], ["bestiario", "Bestiário"], ["saber", "Saber"]]
const LEATHER := Color("#5a2f22")
const PAPER := Color("#f1e2bf")
const RED_INK := Color("#7a2a14")

var tab := "grimorio"
var sub := "feiticos"
var _tabbar: VBoxContainer
var _body: VBoxContainer
var _scroll: ScrollContainer
var _book: Control
var _cover: PanelContainer
var _left: PanelContainer
var _right: PanelContainer
var _page_flip: ColorRect
var _left_title: Label
var _left_info: VBoxContainer
var _only_options := false


func open(payload: Dictionary) -> void:
	tab = payload.get("tab", tab)
	_only_options = payload.get("only_options", false)
	if _only_options:
		tab = "opcoes"
	theme = UITheme.get_book_theme()
	var dim := ColorRect.new()
	dim.color = Color(0.03, 0.02, 0.06, 0.7)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(dim)
	var vp := get_viewport_rect().size if is_inside_tree() else Vector2(1280, 720)
	var bw := vp.x * 0.95
	var bh := vp.y * 0.93
	_book = Control.new()
	_book.size = Vector2(bw, bh)
	_book.position = (vp - _book.size) * 0.5
	add_child(_book)
	# contracapa de couro
	var back := Panel.new()
	back.add_theme_stylebox_override("panel", UITheme.box(LEATHER, Color("#c9a24a"), 20, 4, 0))
	back.position = Vector2(-10, -10)
	back.size = _book.size + Vector2(20, 20)
	_book.add_child(back)
	var pw := bw * 0.5
	_left = _page(Vector2(0, 0), Vector2(pw, bh), true)
	_right = _page(Vector2(pw, 0), Vector2(pw, bh), false)
	# lombada
	var spine := ColorRect.new()
	spine.color = Color(0.35, 0.2, 0.1, 0.35)
	spine.position = Vector2(pw - 6, 0)
	spine.size = Vector2(12, bh)
	spine.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_book.add_child(spine)
	_build_left()
	_build_right()
	# folha que vira ao trocar de capítulo
	_page_flip = ColorRect.new()
	_page_flip.color = PAPER.darkened(0.04)
	_page_flip.position = Vector2(pw, 0)
	_page_flip.size = Vector2(pw, bh)
	_page_flip.pivot_offset = Vector2(0, bh * 0.5)
	_page_flip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_page_flip.visible = false
	_book.add_child(_page_flip)
	# capa (abre como um livro)
	_cover = PanelContainer.new()
	_cover.add_theme_stylebox_override("panel", UITheme.box(LEATHER.lightened(0.05), Color("#e3b85a"), 18, 5, 30))
	_cover.position = Vector2(pw, -6)
	_cover.size = Vector2(pw + 6, bh + 12)
	_cover.pivot_offset = Vector2(0, (bh + 12) * 0.5)
	_book.add_child(_cover)
	var cv := VBoxContainer.new()
	cv.alignment = BoxContainer.ALIGNMENT_CENTER
	_cover.add_child(cv)
	var emblem := BookEmblem.new()
	emblem.custom_minimum_size = Vector2(220, 220)
	emblem.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	cv.add_child(emblem)
	var ct := UITheme.label("Grimório de Asterion", 1.6, Color("#f3d27a"))
	ct.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	ct.add_theme_constant_override("outline_size", 6)
	ct.add_theme_color_override("font_outline_color", Color("#2a140c"))
	cv.add_child(ct)
	var cs := UITheme.label("herdado de Ondina Vael", 0.9, Color("#e8c890"))
	cs.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	cv.add_child(cs)
	# fechar
	var close_btn := UITheme.button("X", close, 52)
	close_btn.custom_minimum_size.x = 60
	close_btn.position = Vector2(bw - 50, -22)
	_book.add_child(close_btn)
	_render()
	_play_open()


func _page(pos: Vector2, sz: Vector2, left: bool) -> PanelContainer:
	var pc := PanelContainer.new()
	var sb := UITheme.box(PAPER, Color("#c9a77a"), 10, 2, 26)
	if left:
		sb.corner_radius_top_right = 0
		sb.corner_radius_bottom_right = 0
	else:
		sb.corner_radius_top_left = 0
		sb.corner_radius_bottom_left = 0
	pc.add_theme_stylebox_override("panel", sb)
	pc.position = pos
	pc.size = sz
	_book.add_child(pc)
	return pc


func _build_left() -> void:
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 6)
	_left.add_child(v)
	_left_title = UITheme.label("", 1.5, RED_INK)
	v.add_child(_left_title)
	var orn := BookEmblem.new()
	orn.small = true
	orn.custom_minimum_size = Vector2(0, 70)
	v.add_child(orn)
	_left_info = VBoxContainer.new()
	v.add_child(_left_info)
	var sep := HSeparator.new()
	v.add_child(sep)
	v.add_child(UITheme.label("Capítulos", 0.95, RED_INK))
	var sc := ScrollContainer.new()
	sc.size_flags_vertical = Control.SIZE_EXPAND_FILL
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	v.add_child(sc)
	_tabbar = VBoxContainer.new()
	_tabbar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sc.add_child(_tabbar)
	var ribbons := [Color("#7a2a14"), Color("#2f5a7a"), Color("#4f7a3a"), Color("#7a5a2f"), Color("#5a3a7a"), Color("#a8743e"), Color("#3a6a6a"), Color("#6a6a7a")]
	for i in TABS.size():
		var tid: String = TABS[i][0]
		if _only_options and tid != "opcoes":
			continue
		var b := UITheme.button(TABS[i][1], _set_tab.bind(tid), 48)
		b.toggle_mode = true
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.set_meta("tab", tid)
		var on := UITheme.box(ribbons[i].lightened(0.15), ribbons[i].darkened(0.3), 8, 2, 14)
		b.add_theme_stylebox_override("pressed", on)
		b.add_theme_stylebox_override("hover_pressed", on)
		b.add_theme_color_override("font_pressed_color", Color("#fff6e0"))
		_tabbar.add_child(b)


func _build_right() -> void:
	_scroll = ScrollContainer.new()
	_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_right.add_child(_scroll)
	_body = VBoxContainer.new()
	_body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_body.add_theme_constant_override("separation", 10)
	_scroll.add_child(_body)


func _play_open() -> void:
	var pw := _book.size.x * 0.5
	var target := _book.position
	_book.position = target - Vector2(pw * 0.5, 0)
	_left.modulate.a = 0.0
	_right.modulate.a = 0.0
	AudioManager.play_sfx("book_open", -2.0)
	var tw := create_tween().set_parallel(true)
	tw.tween_interval(0.25)
	tw.chain().tween_property(_cover, "scale:x", 0.0, 0.55).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	tw.tween_property(_book, "position", target, 0.55).set_trans(Tween.TRANS_SINE)
	tw.tween_property(_left, "modulate:a", 1.0, 0.45)
	tw.chain().tween_property(_right, "modulate:a", 1.0, 0.25)
	tw.chain().tween_callback(func(): _cover.visible = false)


func _set_tab(t: String) -> void:
	if t == tab:
		_render()
		return
	tab = t
	AudioManager.play_sfx("page_turn", -2.0)
	_page_flip.visible = true
	_page_flip.scale = Vector2.ONE
	_render()
	var tw := create_tween()
	tw.tween_property(_page_flip, "scale:x", 0.0, 0.28).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	tw.tween_callback(func(): _page_flip.visible = false)


func _render() -> void:
	for b in _tabbar.get_children():
		b.button_pressed = b.get_meta("tab") == tab
	for c in _body.get_children():
		c.queue_free()
	for c in _left_info.get_children():
		c.queue_free()
	_scroll.scroll_vertical = 0
	_left_title.text = TAB_TITLES.get(tab, "")
	_fill_left_info()
	match tab:
		"grimorio": _grimoire()
		"inventario": _inventory()
		"missoes": _quests()
		"escolas": _schools()
		"mapa": _map()
		"casa": _house()
		"diario": _journal()
		"opcoes": _options()


func _fill_left_info() -> void:
	var pct := Game.grimoire.completeness()
	var info := UITheme.rich(_ink("[i]Conhecimento registrado:[/i] [b]%d%%[/b]\n[i]Dia %d · %s · Lua %s[/i]\n[i]%d EP · %d feitiços conhecidos[/i]" % [int(pct * 100.0), Game.clock.day(), DataRegistry.season_name(Game.clock.season()), Game.clock.moon_name(), Game.inventory.currency, Game.spells.known_spells().size()]), 0.85)
	_left_info.add_child(info)
	var bar := UITheme.bar(Color("#b8862e"), 14)
	bar.max_value = 1.0
	bar.value = pct
	_left_info.add_child(bar)


## Converte cores claras (pensadas para fundo escuro) em tinta legível no pergaminho.
static func _ink(bb: String) -> String:
	var re := RegEx.new()
	re.compile("\\[color=(#[0-9a-fA-F]{6})\\]")
	var out := bb
	for m in re.search_all(bb):
		var c := Color(m.get_string(1))
		if c.get_luminance() > 0.45:
			var dark := c.darkened(0.5)
			dark.s = minf(1.0, dark.s * 1.2)
			out = out.replace(m.get_string(0), "[color=#%s]" % dark.to_html(false))
	return out


func _h(text: String) -> void:
	_body.add_child(UITheme.label(text, 1.15, RED_INK))


func _p(bb: String, size: float = 0.92) -> RichTextLabel:
	var r := UITheme.rich(_ink(bb), size)
	_body.add_child(r)
	return r


# ------------------------------------------------------------------ grimório

func _grimoire() -> void:
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
			v.add_child(UITheme.rich(_ink("[b]%s[/b]  ·  compreensão %d%%  ·  mana %d  ·  recarga %ds  ·  exige nível %d\n%s\n[i][color=#c9a5ff]%s[/color][/i]" % [d.name, int(k), int(Game.spells.mana_cost(spell_id, Game.stats)), int(d.cooldown), int(d.level_required), d.description, d.flavor_text]), 0.85))
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
	var view := InventoryView.new()
	view.ink = true
	view.custom_minimum_size = Vector2(0, 460)
	_body.add_child(view)


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
		v.add_child(UITheme.rich(_ink("[b]%s[/b]  [i](%s)[/i]\n%s\n%s" % [q.title, cat_names.get(q.category, q.category), q.summary, "\n".join(lines)]), 0.88))
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
		v.add_child(UITheme.rich(_ink("[b]%s[/b] — %s\n%s" % [d.name, d.function, state]), 0.88))
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
		theme = UITheme.get_book_theme()
		EventBus.panel_requested.emit("theme_changed", {})


func _text_scale(i: int) -> void:
	Settings.text_scale_index = i
	Settings.apply()
	Settings.save_settings()
	theme = UITheme.get_book_theme()
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
