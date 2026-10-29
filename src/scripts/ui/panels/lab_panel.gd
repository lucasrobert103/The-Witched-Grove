class_name LabPanel
extends ModalPanel
## Laboratório: escolher ingredientes, sequência de técnica e preparar.
## Mostra apenas o que a protagonista SABE (propriedades descobertas) e explica falhas.

var selected: Array = []
var technique: Array = []
var _ing_list: VBoxContainer
var _slots_row: HBoxContainer
var _tech_label: Label
var _preview: RichTextLabel
var _result: VBoxContainer
var _recipes: VBoxContainer


func open(_payload: Dictionary) -> void:
	build_frame("Laboratório — Caldeirão de Ondina", 0.94, 0.94, false)
	var cols := HBoxContainer.new()
	cols.add_theme_constant_override("separation", 16)
	cols.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content.add_child(cols)
	# Coluna esquerda: ingredientes
	var left := VBoxContainer.new()
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left.size_flags_stretch_ratio = 0.9
	cols.add_child(left)
	left.add_child(UITheme.label("Ingredientes", 1.05, UITheme.GOLD))
	var sc := ScrollContainer.new()
	sc.size_flags_vertical = Control.SIZE_EXPAND_FILL
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	left.add_child(sc)
	_ing_list = VBoxContainer.new()
	_ing_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sc.add_child(_ing_list)
	# Coluna direita: mesa
	var right_sc := ScrollContainer.new()
	right_sc.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right_sc.size_flags_vertical = Control.SIZE_EXPAND_FILL
	right_sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	cols.add_child(right_sc)
	var right := VBoxContainer.new()
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right.add_theme_constant_override("separation", 10)
	right_sc.add_child(right)
	right.add_child(UITheme.label("Mistura (%d espaços)" % Game.house.lab_slots(), 1.05, UITheme.GOLD))
	_slots_row = HBoxContainer.new()
	right.add_child(_slots_row)
	right.add_child(UITheme.label("Técnica (até 3 passos, a ordem importa)", 0.95, UITheme.GOLD))
	var tech_row := HFlowContainer.new()
	right.add_child(tech_row)
	for t in DataRegistry.technique_ids():
		var tid: String = t
		tech_row.add_child(UITheme.button(DataRegistry.technique_name(tid), func(): _add_tech(tid)))
	tech_row.add_child(UITheme.button("Desfazer", _undo_tech))
	_tech_label = UITheme.label("", 1.0, UITheme.PARCHMENT, true)
	right.add_child(_tech_label)
	_preview = UITheme.rich("", 0.9)
	right.add_child(_preview)
	var brew_row := HBoxContainer.new()
	right.add_child(brew_row)
	var brew_btn := UITheme.button("Preparar no caldeirão", _brew, 64)
	brew_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	brew_row.add_child(brew_btn)
	brew_row.add_child(UITheme.button("Limpar", _clear))
	_result = VBoxContainer.new()
	right.add_child(_result)
	right.add_child(UITheme.label("Receitas conhecidas", 1.05, UITheme.GOLD))
	_recipes = VBoxContainer.new()
	right.add_child(_recipes)
	if Game.pending_brew_bonus > 0.0 or Game.pending_stabilize:
		right.add_child(UITheme.label("Magia ativa no caldeirão: %s" % ("Dissolução Precisa " if Game.pending_brew_bonus > 0.0 else "") + ("Estabilização" if Game.pending_stabilize else ""), 0.85, Color("#7dffa0")))
	_refresh()


func _props_text(id: String) -> String:
	var known: Array = Game.grimoire.revealed_props(id)
	var total: int = DataRegistry.ingredients[id].properties.size()
	var parts: Array = []
	for p in DataRegistry.ingredients[id].properties:
		parts.append(DataRegistry.property_name(p) if p in known else "???")
	return ", ".join(parts) if total > 0 else ""


func _refresh() -> void:
	for c in _ing_list.get_children():
		c.queue_free()
	var ids := Game.inventory.ids_by_category("ingrediente")
	if ids.is_empty():
		_ing_list.add_child(UITheme.label("Nenhum ingrediente. Colha plantas pelo vale ou compre com o Bento.", 0.9, UITheme.PARCHMENT, true))
	for id in ids:
		var iid: String = id
		var q := Game.inventory.quality(iid)
		var row := HBoxContainer.new()
		var icon := ItemIcon.new()
		icon.item_id = iid
		icon.count = Game.inventory.count(iid)
		icon.quality = q
		icon.custom_minimum_size = Vector2(76, 76)
		row.add_child(icon)
		var b := UITheme.button("%s  [%s]\n%s" % [DataRegistry.item_name(iid), DataRegistry.quality_tier(q), _props_text(iid)], func(): _add_ing(iid), 76)
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.disabled = iid in selected
		b.add_theme_color_override("font_color", DataRegistry.item_color(iid).lightened(0.3))
		row.add_child(b)
		_ing_list.add_child(row)
	for c in _slots_row.get_children():
		c.queue_free()
	for i in Game.house.lab_slots():
		var txt := "vazio"
		if i < selected.size():
			txt = DataRegistry.item_name(selected[i])
		var idx := i
		var b2 := UITheme.button("" if i < selected.size() else txt, func(): _remove_ing(idx), 84)
		b2.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b2.clip_text = true
		if i < selected.size():
			var si := ItemIcon.new()
			si.item_id = selected[i]
			si.show_frame = false
			si.set_anchors_preset(Control.PRESET_FULL_RECT)
			b2.add_child(si)
			b2.tooltip_text = txt
		_slots_row.add_child(b2)
	var names: Array = []
	for t in technique:
		names.append(DataRegistry.technique_name(t))
	_tech_label.text = "Sequência: " + (" → ".join(names) if not names.is_empty() else "(nenhuma — o resultado perde qualidade)")
	_preview.text = _prediction()
	for c in _recipes.get_children():
		c.queue_free()
	for rid in DataRegistry.recipe_order:
		if not Game.grimoire.knows_recipe(rid):
			continue
		var r: Dictionary = DataRegistry.recipes[rid]
		var req: Array = []
		for p in r.requires:
			req.append(DataRegistry.property_name(p))
		var tech: Array = []
		for t in r.technique:
			tech.append(DataRegistry.technique_name(t))
		var card := UITheme.card()
		var v := VBoxContainer.new()
		card.add_child(v)
		v.add_child(UITheme.rich("[b][color=#f3c74f]%s[/color][/b]\nExige despertar: %s\nTécnica: %s\n[i]%s[/i]" % [r.name, ", ".join(req), " → ".join(tech), r.get("hint", "")], 0.85))
		var rtech: Array = r.technique
		v.add_child(UITheme.button("Usar esta técnica", _use_tech.bind(rtech), 48))
		_recipes.add_child(card)
	var unknown := DataRegistry.recipes.size() - Game.grimoire.known_recipes.size()
	if unknown > 0:
		_recipes.add_child(UITheme.label("%d receita(s) ainda por descobrir. Experimente!" % unknown, 0.85, UITheme.GOLD_DIM))


## Previsão com base SOMENTE no que já foi descoberto.
func _prediction() -> String:
	if selected.size() < 2:
		return "[i]Escolha pelo menos 2 ingredientes. Uma propriedade só desperta se 2 ou mais ingredientes a tiverem.[/i]"
	var counts := {}
	for id in selected:
		for p in Game.grimoire.revealed_props(id):
			counts[p] = int(counts.get(p, 0)) + 1
	var shared: Array = []
	for p in counts:
		if int(counts[p]) >= 2:
			shared.append(DataRegistry.property_name(p))
	var txt := "Propriedades conhecidas em comum: [b]%s[/b]" % (", ".join(shared) if not shared.is_empty() else "nenhuma (ainda)")
	var hidden := false
	for id in selected:
		if not Game.grimoire.all_props_revealed(id):
			hidden = true
	if hidden:
		txt += "\n[i]Há propriedades ocultas: o resultado pode surpreender.[/i]"
	return txt


func _add_ing(id: String) -> void:
	if id in selected or selected.size() >= Game.house.lab_slots():
		return
	selected.append(id)
	AudioManager.play_sfx("plant", -6.0)
	_refresh()


func _remove_ing(i: int) -> void:
	if i < selected.size():
		selected.remove_at(i)
		_refresh()


func _add_tech(t: String) -> void:
	if technique.size() < int(DataRegistry.recipes_rules.get("max_technique_steps", 3)):
		technique.append(t)
		_refresh()


func _use_tech(t: Array) -> void:
	technique = t.duplicate()
	_refresh()


func _undo_tech() -> void:
	if not technique.is_empty():
		technique.pop_back()
		_refresh()


func _clear() -> void:
	selected.clear()
	technique.clear()
	_refresh()


func _play_brew_animation(used: Array, r: Dictionary) -> void:
	var overlay := ColorRect.new()
	overlay.color = Color(0.03, 0.02, 0.06, 0.82)
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(overlay)
	var anim := CauldronAnim.new()
	anim.ingredient_ids = used
	anim.success = r.success
	anim.result_item = r.output
	anim.result_color = DataRegistry.item_color(r.output)
	anim.set_anchors_preset(Control.PRESET_CENTER)
	anim.custom_minimum_size = Vector2(460, 460)
	anim.size = Vector2(460, 460)
	anim.position = (get_viewport_rect().size - anim.size) * 0.5
	overlay.add_child(anim)
	var lbl := UITheme.label("Borbulhando...", 1.2, UITheme.GOLD)
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	lbl.position = Vector2(get_viewport_rect().size.x * 0.5 - 200, get_viewport_rect().size.y - 90)
	lbl.custom_minimum_size = Vector2(400, 40)
	overlay.add_child(lbl)
	AudioManager.play_sfx("brew_bubble")
	await get_tree().create_timer(1.2).timeout
	AudioManager.play_sfx("brew_bubble", -2.0)
	await anim.finished
	lbl.text = ("%s!" % DataRegistry.item_name(r.output)) if r.success else "Puf... Mistura Turva."
	await get_tree().create_timer(0.7).timeout
	overlay.queue_free()


func _brew() -> void:
	if selected.size() < 2:
		EventBus.notify.emit("Escolha pelo menos 2 ingredientes.", "warning")
		return
	var used := selected.duplicate()
	var r := Game.brew(selected.duplicate(), technique.duplicate())
	for c in _result.get_children():
		c.queue_free()
	if r.get("error", "") != "":
		return
	selected.clear()
	await _play_brew_animation(used, r)
	var card := UITheme.card(Color(0.2, 0.12, 0.3, 0.9), UITheme.GOLD)
	var v := VBoxContainer.new()
	card.add_child(v)
	if r.success:
		AudioManager.play_sfx("brew_success")
		Settings.vibrate(40)
		v.add_child(UITheme.rich("[b][color=#7dffa0]%s[/color][/b] — qualidade [b]%s[/b] (%.2f)%s" % [DataRegistry.item_name(r.output), r.tier, r.quality, "\n[color=#f3c74f]Receita nova descoberta![/color]" if r.get("new_recipe", false) else ""], 1.0))
	else:
		AudioManager.play_sfx("brew_fail")
		v.add_child(UITheme.rich("[b][color=#ff9a8a]Mistura Turva[/color][/b]\n%s" % r.insight, 0.95))
	if r.success and r.insight != "":
		v.add_child(UITheme.rich("[i]%s[/i]" % r.insight, 0.85))
	_result.add_child(card)
	_refresh()
