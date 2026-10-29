class_name InventoryView
extends HBoxContainer
## Grade de itens com ícones (estilo bolsa de RPG) + painel de detalhes.
## Usada no Armazém (baú da cabana) e na aba Inventário do grimório.

signal changed()

const CATS := [["", "Tudo"], ["ingrediente", "Ingredientes"], ["pocao", "Poções"], ["semente", "Sementes"], ["ferramenta", "Ferramentas"], ["artefato", "Artefatos"]]

var category: String = ""
var selected: String = ""
var ink: bool = false               # true dentro do livro (texto escuro em pergaminho)
var _grid: GridContainer
var _detail: VBoxContainer
var _filters: HFlowContainer
var _cap: Label


func _ready() -> void:
	add_theme_constant_override("separation", 14)
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	var left := VBoxContainer.new()
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left.size_flags_stretch_ratio = 1.6
	add_child(left)
	_filters = HFlowContainer.new()
	left.add_child(_filters)
	for c in CATS:
		var cid: String = c[0]
		var b := UITheme.button(c[1], _set_cat.bind(cid), 44)
		b.toggle_mode = true
		b.set_meta("cat", cid)
		_filters.add_child(b)
	_cap = UITheme.label("", 0.8, _txt_color(), true)
	left.add_child(_cap)
	var sc := ScrollContainer.new()
	sc.size_flags_vertical = Control.SIZE_EXPAND_FILL
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	sc.custom_minimum_size = Vector2(0, 280)
	left.add_child(sc)
	_grid = GridContainer.new()
	_grid.columns = 6
	_grid.add_theme_constant_override("h_separation", 8)
	_grid.add_theme_constant_override("v_separation", 8)
	sc.add_child(_grid)
	var dp := UITheme.card(Color(0.15, 0.1, 0.06, 0.25) if ink else Color(1, 1, 1, 0.06), Color(0.55, 0.42, 0.28, 0.6))
	dp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	dp.custom_minimum_size = Vector2(300, 0)
	add_child(dp)
	_detail = VBoxContainer.new()
	_detail.add_theme_constant_override("separation", 8)
	dp.add_child(_detail)
	refresh()


func _txt_color() -> Color:
	return UITheme.INK if ink else UITheme.PARCHMENT


func _set_cat(c: String) -> void:
	category = c
	refresh()


func refresh() -> void:
	for b in _filters.get_children():
		b.button_pressed = b.get_meta("cat") == category
	for c in _grid.get_children():
		c.queue_free()
	var ids: Array = Game.inventory.all_ids() if category == "" else Game.inventory.ids_by_category(category)
	_cap.text = "%d EP  ·  Peso %.1f / %.0f" % [Game.inventory.currency, Game.inventory.total_weight(), Game.inventory.capacity]
	if ids.is_empty():
		var l := UITheme.label("Vazio por aqui. Colha, prepare ou compre algo!", 0.9, _txt_color(), true)
		l.custom_minimum_size.x = 360
		_grid.add_child(l)
	for id in ids:
		var iid: String = id
		var slot := Button.new()
		slot.custom_minimum_size = Vector2(84, 84)
		slot.focus_mode = Control.FOCUS_NONE
		slot.flat = true
		slot.pressed.connect(_select.bind(iid))
		var icon := ItemIcon.new()
		icon.set_anchors_preset(Control.PRESET_FULL_RECT)
		icon.item_id = iid
		icon.count = Game.inventory.count(iid)
		icon.quality = Game.inventory.quality(iid)
		icon.selected = iid == selected
		slot.add_child(icon)
		_grid.add_child(slot)
	if selected == "" or Game.inventory.count(selected) <= 0:
		selected = ids[0] if not ids.is_empty() else ""
	_show_detail()


func _select(id: String) -> void:
	selected = id
	AudioManager.play_sfx("ui_click", -6.0)
	refresh()


func _show_detail() -> void:
	for c in _detail.get_children():
		c.queue_free()
	if selected == "":
		_detail.add_child(UITheme.label("Toque em um item para ver os detalhes.", 0.9, _txt_color(), true))
		return
	var it: Dictionary = DataRegistry.items[selected]
	var big := ItemIcon.new()
	big.custom_minimum_size = Vector2(120, 120)
	big.item_id = selected
	big.show_frame = true
	big.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_detail.add_child(big)
	var title := UITheme.label(it.name, 1.15, Color("#7a3a10") if ink else UITheme.GOLD, true)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_detail.add_child(title)
	var q := Game.inventory.quality(selected)
	_detail.add_child(UITheme.label("Quantidade: %d  ·  Qualidade: %s" % [Game.inventory.count(selected), DataRegistry.quality_tier(q)], 0.82, _txt_color(), true))
	_detail.add_child(UITheme.label(it.get("description", ""), 0.85, _txt_color(), true))
	if DataRegistry.ingredients.has(selected):
		var props: Array = []
		for p in DataRegistry.ingredients[selected].properties:
			props.append(DataRegistry.property_name(p) if p in Game.grimoire.revealed_props(selected) else "???")
		_detail.add_child(UITheme.label("Propriedades: " + ", ".join(props), 0.8, _txt_color(), true))
	var use_type: String = it.get("use", {}).get("type", "none")
	if use_type in ["heal", "mana_pct", "buff", "grow_area"]:
		_detail.add_child(UITheme.button("Usar", _use, 52))


func _use() -> void:
	var r := Game.use_item(selected)
	if not r.ok:
		EventBus.notify.emit(r.reason, "warning")
	else:
		AudioManager.play_sfx("pickup")
	refresh()
	changed.emit()
