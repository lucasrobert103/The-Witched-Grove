class_name DialoguePanel
extends Control
## Diálogo em ritmo de RPG: o texto aparece letra a letra (com pausas na pontuação
## e "bipes" de voz), dividido em páginas. Toque para completar a página ou avançar.
## Um retrato 3D do personagem fala ao lado do texto.

signal closed()

const CHARS_PER_SEC := 34.0
const PAGE_CHARS := 150

var npc_id := ""
var _name_plate: PanelContainer
var _name: Label
var _text: Label
var _options: VBoxContainer
var _opt_scroll: ScrollContainer
var _arrow: Control
var _portrait_vp: SubViewport
var _portrait_model: Node3D
var _pages: Array = []
var _page := 0
var _shown := 0.0
var _pause := 0.0
var _typing := false
var _blip_n := 0
var _voice := 1.0
var _t := 0.0


func _init() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	theme = UITheme.get_theme()


func open(payload: Dictionary) -> void:
	npc_id = payload.get("npc", "")
	_voice = _voice_for(npc_id)
	var dim := ColorRect.new()
	dim.color = Color(0.02, 0.01, 0.06, 0.25)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	dim.gui_input.connect(_on_box_input)
	add_child(dim)
	# caixa principal
	var box := PanelContainer.new()
	box.anchor_left = 0.03
	box.anchor_right = 0.97
	box.anchor_top = 0.55
	box.anchor_bottom = 0.97
	box.add_theme_stylebox_override("panel", UITheme.box(Color(0.1, 0.07, 0.16, 0.95), UITheme.GOLD, 22, 3, 18))
	box.mouse_filter = Control.MOUSE_FILTER_STOP
	box.gui_input.connect(_on_box_input)
	add_child(box)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 18)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(row)
	row.add_child(_build_portrait())
	var col_v := VBoxContainer.new()
	col_v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col_v.add_theme_constant_override("separation", 8)
	col_v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(col_v)
	_text = UITheme.label("", 1.08, Color(0, 0, 0, 0), true)
	_text.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_text.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_text.visible_characters_behavior = TextServer.VC_CHARS_AFTER_SHAPING
	col_v.add_child(_text)
	_opt_scroll = ScrollContainer.new()
	_opt_scroll.custom_minimum_size = Vector2(0, 120)
	_opt_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_opt_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_opt_scroll.visible = false
	col_v.add_child(_opt_scroll)
	_options = VBoxContainer.new()
	_options.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_opt_scroll.add_child(_options)
	# seta de "continuar"
	_arrow = Control.new()
	_arrow.anchor_left = 0.95
	_arrow.anchor_right = 0.95
	_arrow.anchor_top = 0.93
	_arrow.anchor_bottom = 0.93
	_arrow.custom_minimum_size = Vector2(24, 18)
	_arrow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_arrow.draw.connect(func(): _arrow.draw_colored_polygon(PackedVector2Array([Vector2(0, 0), Vector2(24, 0), Vector2(12, 16)]), UITheme.GOLD))
	add_child(_arrow)
	# plaquinha com o nome
	_name_plate = PanelContainer.new()
	var fac_col := Color(DataRegistry.factions.get(DataRegistry.npcs.get(npc_id, {}).get("faction", ""), {}).get("color", "#7a4fc4"))
	_name_plate.add_theme_stylebox_override("panel", UITheme.box(fac_col.darkened(0.35), UITheme.GOLD, 14, 3, 14))
	_name_plate.anchor_left = 0.05
	_name_plate.anchor_right = 0.05
	_name_plate.grow_horizontal = Control.GROW_DIRECTION_END
	_name_plate.anchor_top = 0.55
	_name_plate.anchor_bottom = 0.55
	_name_plate.offset_top = -30
	_name_plate.offset_bottom = 18
	add_child(_name_plate)
	_name = UITheme.label(DataRegistry.npc_name(npc_id), 1.1, UITheme.GOLD)
	_name_plate.add_child(_name)
	if payload.has("node"):
		Game.dialogue.npc_id = npc_id
		Game.dialogue.finished = false
		Game.dialogue._enter(payload.node)
	elif not Game.dialogue.start(npc_id):
		_finish()
		return
	_render_node()


func _voice_for(id: String) -> float:
	var ap: Dictionary = DataRegistry.npcs.get(id, {}).get("appearance", {})
	if ap.get("special", "") == "tree_spirit":
		return 0.55
	match ap.get("age", "adult"):
		"child":
			return 1.55
		"elder":
			return 0.85
	return 1.0 + (hash(id) % 20) / 100.0


func _build_portrait() -> Control:
	var frame := PanelContainer.new()
	frame.custom_minimum_size = Vector2(190, 190)
	frame.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	frame.add_theme_stylebox_override("panel", UITheme.box(Color("#2a1d44"), UITheme.GOLD, 95, 4, 4))
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var svc := SubViewportContainer.new()
	svc.stretch = true
	svc.custom_minimum_size = Vector2(180, 180)
	svc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	frame.add_child(svc)
	_portrait_vp = SubViewport.new()
	_portrait_vp.own_world_3d = true
	_portrait_vp.transparent_bg = true
	_portrait_vp.size = Vector2i(256, 256)
	_portrait_vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	svc.add_child(_portrait_vp)
	var env := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_CLEAR_COLOR
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color("#d8d0e8")
	e.ambient_light_energy = 0.7
	env.environment = e
	_portrait_vp.add_child(env)
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-30, 150, 0)
	light.light_energy = 1.1
	_portrait_vp.add_child(light)
	var cam := Camera3D.new()
	_portrait_vp.add_child(cam)
	var d: Dictionary = DataRegistry.npcs.get(npc_id, {})
	var ap: Dictionary = d.get("appearance", {})
	if ap.get("special", "") == "tree_spirit":
		var tree := TreeSpiritModel.new()
		_portrait_vp.add_child(tree)
		if Game.has_flag("musgo_corrompido"):
			tree.state = TreeSpiritModel.State.VIOLET
		elif Game.has_flag("musgo_purificado"):
			tree.state = TreeSpiritModel.State.HEALED
		_portrait_model = tree
		cam.transform = _look(Vector3(0, 3.5, -5.0), Vector3(0, 3.4, 0))
		cam.fov = 45
	elif not ap.is_empty():
		var h := HumanoidModel.new()
		_portrait_vp.add_child(h)
		h.build(ap)
		_portrait_model = h
		var hh := float(ap.get("height", 1.0))
		var head_y := 1.28 * hh
		cam.transform = _look(Vector3(0.15, head_y + 0.05, -1.05 * maxf(hh, 0.8)), Vector3(0, head_y - 0.04, 0))
		cam.fov = 34
	cam.current = true
	return frame


## Transform de câmera olhando para um alvo (o retrato ainda não está na árvore).
static func _look(from: Vector3, to: Vector3) -> Transform3D:
	return Transform3D(Basis.looking_at(to - from, Vector3.UP), from)


func _render_node() -> void:
	if Game.dialogue.finished:
		_finish()
		return
	Game.refresh_quests()
	_pages = _split_pages(Game.dialogue.text())
	_page = 0
	_opt_scroll.visible = false
	_start_page()


static func _split_pages(text: String) -> Array:
	var pages: Array = []
	var current := ""
	var sentence := ""
	for i in text.length():
		var ch := text[i]
		sentence += ch
		var end_sentence := ch in [".", "!", "?", "…"] and (i + 1 >= text.length() or text[i + 1] == " ")
		if end_sentence or i == text.length() - 1:
			if current.length() + sentence.length() > PAGE_CHARS and current != "":
				pages.append(current.strip_edges())
				current = ""
			current += sentence
			sentence = ""
	if current.strip_edges() != "":
		pages.append(current.strip_edges())
	if pages.is_empty():
		pages.append("")
	return pages


func _start_page() -> void:
	_text.text = _pages[_page]
	_text.visible_characters = 0
	_shown = 0.0
	_pause = 0.08
	_typing = true
	_arrow.visible = false
	if _portrait_model is HumanoidModel:
		_portrait_model.play_talk(clampf(_text.text.length() / CHARS_PER_SEC, 0.6, 4.0))


func _process(delta: float) -> void:
	_t += delta
	if _typing:
		if _pause > 0.0:
			_pause -= delta
		else:
			var before := int(_shown)
			_shown += delta * CHARS_PER_SEC
			var n := mini(int(_shown), _text.text.length())
			for i in range(before, n):
				var ch := _text.text[i]
				if ch in [".", "!", "?", "…"]:
					_pause = 0.32
				elif ch in [",", ";", ":", "—"]:
					_pause = 0.14
				if ch != " ":
					_blip_n += 1
					if _blip_n % 3 == 0:
						AudioManager.play_sfx("blip", -14.0, 0.05, _voice)
				if _pause > 0.0:
					_shown = float(i + 1)
					n = i + 1
					break
			_text.visible_characters = n
			if n >= _text.text.length():
				_end_page()
	_arrow.visible = not _typing and _page < _pages.size() - 1
	if _arrow.visible:
		_arrow.position.y = sin(_t * 6.0) * 4.0
		_arrow.queue_redraw()
	if _portrait_model:
		_portrait_model.rotation.y = sin(_t * 0.6) * 0.08


func _end_page() -> void:
	_typing = false
	_text.visible_characters = -1
	if _page >= _pages.size() - 1:
		_show_options()


func _show_options() -> void:
	for c in _options.get_children():
		c.queue_free()
	for o in Game.dialogue.options():
		var idx: int = o.index
		var b := UITheme.button("» " + o.text, _choose.bind(idx))
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_options.add_child(b)
	_opt_scroll.visible = true
	_opt_scroll.modulate.a = 0.0
	create_tween().tween_property(_opt_scroll, "modulate:a", 1.0, 0.25)


func _advance() -> void:
	if _typing:
		_text.visible_characters = -1
		_typing = false
		_end_page()
		return
	if _page < _pages.size() - 1:
		_page += 1
		AudioManager.play_sfx("ui_click", -10.0)
		_start_page()


func _on_box_input(ev: InputEvent) -> void:
	if ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT:
		_advance()


func _choose(index: int) -> void:
	Game.dialogue.choose(index)
	Game.refresh_quests()
	_render_node()


func _finish() -> void:
	EventBus.dialogue_closed.emit(npc_id)
	closed.emit()
	queue_free()


func close() -> void:
	Game.dialogue.finished = true
	_finish()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause"):
		get_viewport().set_input_as_handled()
		close()
	elif event.is_action_pressed("interact") or event.is_action_pressed("ui_accept"):
		get_viewport().set_input_as_handled()
		_advance()
