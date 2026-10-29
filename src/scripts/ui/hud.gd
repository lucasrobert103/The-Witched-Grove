extends CanvasLayer
## HUD de jogo: vida/mana, relógio, minimapa, rastreador de missão, joystick,
## botões de ação (multitoque manual), notificações e painéis modais.

var PANEL_CLASSES := {
	"book": BookPanel, "lab": LabPanel, "garden": GardenPanel, "shop": ShopPanel,
	"reader": ReaderPanel, "lectern": LecternPanel, "message": MessagePanel,
	"rest": RestPanel, "intro": IntroPanel, "storage": StoragePanel,
}
const SCHOOL_ICON_COLORS := SpellFX.SCHOOL_COLORS

var player: Player
var root: Control
var modal: Control = null
var _hp: ProgressBar
var _mp: ProgressBar
var _ep: Label
var _buffs: Label
var _tracker: RichTextLabel
var _clock: ClockWidget
var _minimap: Minimap
var _joy: TouchJoystick
var _btn_interact: RoundButton
var _btn_cast: RoundButton
var _btn_book: RoundButton
var _btn_hint: RoundButton
var _slots: Array[RoundButton] = []
var _prompt: Label
var _toasts: VBoxContainer
var _pointers: Dictionary = {}        # idx -> {"role": String, "pos": Vector2}
var _pinch_dist := 0.0
var _toast_queue: Array = []
var _fade: ColorRect
var _room_label: PanelContainer
var _room_text: Label


func _ready() -> void:
	add_to_group("hud")
	layer = 10
	root = Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.theme = UITheme.get_theme()
	add_child(root)
	_build()
	EventBus.notify.connect(_on_notify)
	EventBus.panel_requested.connect(open_panel)
	EventBus.dialogue_requested.connect(func(id): open_panel("dialogue", {"npc": id}))
	EventBus.shop_requested.connect(func(id): open_panel.call_deferred("shop", {"shop": id}))
	EventBus.spell_slots_changed.connect(_refresh_slots)
	EventBus.quest_updated.connect(func(_q): _refresh_tracker())
	EventBus.quest_started.connect(func(_q): _refresh_tracker())
	EventBus.quest_completed.connect(func(_q, _o): _refresh_tracker())
	EventBus.player_health_depleted.connect(_on_faint)
	_refresh_slots()
	_refresh_tracker()


func bind_player(p: Player) -> void:
	player = p
	_minimap.player = p
	_minimap.terrain = get_parent().builder.terrain


# ================================================================== construção

func _build() -> void:
	# --- status (topo esquerdo)
	var status := PanelContainer.new()
	status.position = Vector2(16, 14)
	status.custom_minimum_size = Vector2(340, 0)
	status.add_theme_stylebox_override("panel", UITheme.box(Color(0.11, 0.08, 0.2, 0.82), UITheme.GOLD_DIM, 18, 2, 12))
	status.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(status)
	var sv := VBoxContainer.new()
	sv.add_theme_constant_override("separation", 4)
	status.add_child(sv)
	var name_row := HBoxContainer.new()
	sv.add_child(name_row)
	var nm := UITheme.label("Asterion", 1.0, UITheme.GOLD)
	nm.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_row.add_child(nm)
	_ep = UITheme.label("", 0.9, UITheme.PARCHMENT)
	name_row.add_child(_ep)
	_hp = UITheme.bar(UITheme.ROSE, 18)
	sv.add_child(_hp)
	_mp = UITheme.bar(UITheme.MANA, 18)
	sv.add_child(_mp)
	_buffs = UITheme.label("", 0.72, Color("#9ff0ff"))
	sv.add_child(_buffs)
	# --- rastreador de missão
	_tracker = UITheme.rich("", 0.82)
	_tracker.position = Vector2(18, 150)
	_tracker.custom_minimum_size = Vector2(400, 0)
	_tracker.size = Vector2(400, 120)
	_tracker.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_tracker.add_theme_constant_override("outline_size", 6)
	_tracker.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.7))
	root.add_child(_tracker)
	# --- relógio e minimapa (topo direito)
	_clock = ClockWidget.new()
	_clock.anchor_left = 1.0
	_clock.anchor_right = 1.0
	_clock.offset_left = -276
	_clock.offset_right = -16
	_clock.offset_top = 14
	_clock.offset_bottom = 92
	root.add_child(_clock)
	_minimap = Minimap.new()
	_minimap.anchor_left = 1.0
	_minimap.anchor_right = 1.0
	_minimap.offset_left = -196
	_minimap.offset_right = -16
	_minimap.offset_top = 104
	_minimap.offset_bottom = 284
	root.add_child(_minimap)
	_btn_book = _round("book", "Livro", UITheme.PURPLE, 76)
	_btn_book.anchor_left = 1.0
	_btn_book.anchor_right = 1.0
	_btn_book.offset_left = -290
	_btn_book.offset_right = -214
	_btn_book.offset_top = 108
	_btn_book.offset_bottom = 184
	_btn_book.triggered.connect(func(): open_panel("book", {}))
	_btn_hint = _round("cat", "Nimbus", Color("#5a6aa8"), 76)
	_btn_hint.anchor_left = 1.0
	_btn_hint.anchor_right = 1.0
	_btn_hint.offset_left = -290
	_btn_hint.offset_right = -214
	_btn_hint.offset_top = 196
	_btn_hint.offset_bottom = 272
	_btn_hint.triggered.connect(_hint)
	# --- joystick
	_joy = TouchJoystick.new()
	_joy.anchor_top = 1.0
	_joy.anchor_bottom = 1.0
	_joy.offset_left = 20
	_joy.offset_right = 380
	_joy.offset_top = -330
	_joy.offset_bottom = -10
	root.add_child(_joy)
	# --- ações (canto inferior direito)
	_btn_interact = _round("hand", "", Color("#3f8f55"), 132)
	_place_br(_btn_interact, Vector2(-170, -178))
	_btn_interact.triggered.connect(_do_interact)
	_btn_cast = _round("star", "", UITheme.PURPLE, 10)
	_btn_cast.visible = false
	# 6 feitiços em arco ao redor do botão de interagir: toque = lança na hora
	var center := Vector2(-170 + 66, -178 + 66)
	for i in SpellSystem.SLOT_COUNT:
		var ang := deg_to_rad(165.0 + i * 24.0)
		var pos := center + Vector2(cos(ang), sin(ang)) * 212.0 - Vector2(44, 44)
		var b := _round("", str(i + 1), Color("#3a2a5a"), 88)
		_place_br(b, pos)
		b.triggered.connect(_cast_slot.bind(i))
		_slots.append(b)
	_prompt = UITheme.label("", 0.85, Color.WHITE)
	_prompt.anchor_left = 1.0
	_prompt.anchor_right = 1.0
	_prompt.anchor_top = 1.0
	_prompt.anchor_bottom = 1.0
	_prompt.offset_left = -560
	_prompt.offset_right = -24
	_prompt.offset_top = -40
	_prompt.offset_bottom = -6
	_prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_prompt.add_theme_constant_override("outline_size", 8)
	_prompt.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
	root.add_child(_prompt)
	_room_label = PanelContainer.new()
	_room_label.add_theme_stylebox_override("panel", UITheme.box(Color(0.11, 0.08, 0.2, 0.85), UITheme.GOLD_DIM, 16, 2, 14))
	_room_label.offset_left = 16
	_room_label.offset_right = 360
	_room_label.offset_top = 230
	_room_label.visible = false
	_room_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(_room_label)
	_room_text = UITheme.label("", 0.9, UITheme.GOLD, true)
	_room_label.add_child(_room_text)
	# --- notificações
	_toasts = VBoxContainer.new()
	_toasts.anchor_left = 0.5
	_toasts.anchor_right = 0.5
	_toasts.offset_left = -330
	_toasts.offset_right = 330
	_toasts.offset_top = 14
	_toasts.alignment = BoxContainer.ALIGNMENT_BEGIN
	_toasts.add_theme_constant_override("separation", 6)
	_toasts.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(_toasts)


func _update_room_ui() -> void:
	var w := get_parent()
	var inside: bool = w.current_room != null
	_minimap.visible = not inside
	_room_label.visible = inside
	if inside:
		_room_text.text = "%s\nToque na porta para sair." % w.current_room.title


## Escurece a tela, executa a troca de cena (entrar/sair de casa) e clareia.
func fade_transition(cb: Callable) -> void:
	if _fade == null:
		_fade = ColorRect.new()
		_fade.color = Color(0.02, 0.01, 0.04, 0.0)
		_fade.set_anchors_preset(Control.PRESET_FULL_RECT)
		_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
		root.add_child(_fade)
	root.move_child(_fade, -1)
	_release_all()
	var tw := create_tween()
	tw.tween_property(_fade, "color:a", 1.0, 0.28)
	tw.tween_callback(cb)
	tw.tween_interval(0.12)
	tw.tween_property(_fade, "color:a", 0.0, 0.35)


func _do_interact() -> void:
	if player:
		player.try_interact()


func _do_cast() -> void:
	if player:
		player.cast_selected()


func _round(icon: String, label: String, color: Color, sz: float) -> RoundButton:
	var b := RoundButton.new()
	b.icon = icon
	b.label = label
	b.color = color
	b.custom_minimum_size = Vector2(sz, sz)
	b.size = Vector2(sz, sz)
	root.add_child(b)
	return b


func _place_br(b: Control, off: Vector2) -> void:
	b.anchor_left = 1.0
	b.anchor_right = 1.0
	b.anchor_top = 1.0
	b.anchor_bottom = 1.0
	b.offset_left = off.x
	b.offset_top = off.y
	b.offset_right = off.x + b.custom_minimum_size.x
	b.offset_bottom = off.y + b.custom_minimum_size.y


# ================================================================== atualização

func _process(delta: float) -> void:
	var s := Game.stats
	_hp.max_value = s.max_health()
	_hp.value = s.health
	_mp.max_value = s.max_mana()
	_mp.value = s.mana
	_ep.text = "%d EP" % Game.inventory.currency
	var buffs: Array = []
	for b in Game.buffs:
		buffs.append("%s %ds" % [{"shield": "Escudo", "stealth": "Véu", "light_orb": "Lume", "glow": "Brilho", "reveal": "Visão", "warm": "Calor"}.get(b, b), int(Game.buff_left(b))])
	_buffs.text = "  ".join(buffs)
	_buffs.visible = not buffs.is_empty()
	# botões
	var sid := Game.spells.selected_spell()
	if sid != "":
		var d := Game.spells.def(sid)
		_btn_cast.label = d.name.split(" ")[0]
		_btn_cast.color = SCHOOL_ICON_COLORS.get(d.school, UITheme.PURPLE).darkened(0.2)
		var cd := float(d.get("cooldown", 1.0))
		_btn_cast.cooldown = clampf(Game.spells.cooldown_left(sid) / maxf(cd, 0.01), 0.0, 1.0)
		_btn_cast.dim = not Game.spells.can_cast(sid, Game.stats, Game.inventory).ok
	else:
		_btn_cast.label = "—"
		_btn_cast.dim = true
		_btn_cast.cooldown = 0.0
	_btn_cast.queue_redraw()
	for i in _slots.size():
		var ssid: String = Game.spells.slots[i]
		_slots[i].selected = false
		_slots[i].dim = ssid != "" and not Game.spells.can_cast(ssid, Game.stats, Game.inventory).ok
		_slots[i].cooldown = clampf(Game.spells.cooldown_left(ssid) / maxf(float(Game.spells.def(ssid).get("cooldown", 1.0)), 0.01), 0.0, 1.0) if ssid != "" else 0.0
		_slots[i].queue_redraw()
	var f: Interactable = player.focused if player else null
	_btn_interact.dim = f == null
	_prompt.text = f.get_prompt() if f else ""
	_btn_interact.queue_redraw()
	# alvo do objetivo no minimapa
	_minimap.target = _objective_target()
	if player:
		player.move_input = _joy.value if modal == null else Vector2.ZERO
	_process_toasts(delta)


func _refresh_slots() -> void:
	for i in _slots.size():
		var sid: String = Game.spells.slots[i]
		if sid == "":
			_slots[i].label = str(i + 1)
			_slots[i].icon = ""
			_slots[i].color = Color("#3a2a5a")
		else:
			var d := Game.spells.def(sid)
			var nm: String = d.name.split(" ")[0]
			_slots[i].label = nm if nm.length() <= 9 else nm.substr(0, 8) + "."
			_slots[i].icon = spell_icon(sid)
			_slots[i].color = SCHOOL_ICON_COLORS.get(d.school, UITheme.PURPLE).darkened(0.4)


func _cast_slot(i: int) -> void:
	if Game.spells.slots[i] == "":
		EventBus.notify.emit("Espaço vazio. Equipe feitiços no Grimório → Feitiços.", "info")
		return
	Game.spells.selected_slot = i
	EventBus.spell_slots_changed.emit()
	if player:
		player.cast_selected()


static func spell_icon(spell_id: String) -> String:
	var d: Dictionary = DataRegistry.spells.get(spell_id, {})
	var tags: Array = d.get("tags", [])
	for pair in [["fire", "flame"], ["ice", "snow"], ["levitate", "feather"], ["transfigure", "swirl"], ["light", "sun"], ["shapeshift", "cat"], ["grow", "leaf"], ["nature_sync", "leaf"], ["shield", "shield"], ["stealth", "eye"], ["reveal", "eye"], ["wind", "wind"], ["purify", "sun"], ["teleport", "rune"], ["rune_protect", "rune"], ["identify", "leaf"]]:
		if pair[0] in tags:
			return pair[1]
	return "star"


func _select_slot(i: int) -> void:
	if Game.spells.slots[i] == "":
		EventBus.notify.emit("Espaço vazio. Equipe feitiços no Livro → Grimório → Feitiços.", "info")
		return
	if Game.spells.selected_slot == i and player:
		player.cast_selected()
	Game.spells.selected_slot = i
	EventBus.spell_slots_changed.emit()


func _objective_target() -> Vector3:
	var qid := Game.quests.tracked
	if qid == "" or not Game.quests.is_active(qid):
		return Vector3.INF
	var oid := Game.quests.current_objective(qid)
	for o in Game.quests.def(qid).objectives:
		if o.id == oid and o.has("target"):
			return Vector3(float(o.target[0]), 0, float(o.target[1]))
		if not DataRegistry.quests[qid].get("sequential", false) and not Game.quests.objective_done(qid, o.id) and o.has("target"):
			return Vector3(float(o.target[0]), 0, float(o.target[1]))
	return Vector3.INF


func _refresh_tracker() -> void:
	var qid := Game.quests.tracked
	if qid == "" or not Game.quests.is_active(qid):
		_tracker.text = ""
		return
	var q := Game.quests.def(qid)
	var lines: Array = ["[b][color=#f3c74f]%s[/color][/b]" % q.title]
	for o in Game.quests.visible_objectives(qid):
		if not o.done:
			lines.append("• " + o.text)
	_tracker.text = "\n".join(lines)


# ================================================================== Nimbus (dicas)

func _hint() -> void:
	AudioManager.play_sfx("creature_calm")
	var qid := Game.quests.tracked
	var msg := "Nimbus boceja: \"Explore! Colha coisas, leia tudo, misture o que der. Eu fico aqui, fofo.\""
	if qid != "" and Game.quests.is_active(qid):
		var oid := Game.quests.current_objective(qid)
		for o in Game.quests.def(qid).objectives:
			if o.id == oid or (oid == "" and not Game.quests.objective_done(qid, o.id)):
				var dir := ""
				if o.has("target") and player:
					dir = " (" + _direction_to(Vector3(float(o.target[0]), 0, float(o.target[1]))) + ")"
				msg = "Nimbus: \"%s\"%s" % [o.get("hint", o.text), dir]
				break
	if Game.clock.is_night() and not Game.has_buff("light_orb") and Game.spells.is_known("astral:lume"):
		msg += "\nNimbus: \"Tá escuro. Que tal um Lume Estelar?\""
	EventBus.notify.emit(msg, "hint")


func _direction_to(t: Vector3) -> String:
	var d := Vector2(t.x - player.global_position.x, t.z - player.global_position.z)
	if d.length() < 6.0:
		return "bem pertinho"
	var ang := atan2(d.x, -d.y)
	var names := ["ao norte", "a nordeste", "a leste", "a sudeste", "ao sul", "a sudoeste", "a oeste", "a noroeste"]
	var idx := int(round(ang / (TAU / 8.0))) % 8
	if idx < 0:
		idx += 8
	return "%s, uns %d passos" % [names[idx], int(d.length())]


# ================================================================== notificações

func _on_notify(text: String, kind: String) -> void:
	if text == "":
		return
	_toast_queue.append([text, kind])
	match kind:
		"discovery":
			AudioManager.play_sfx("discovery", -4.0)
		"quest":
			AudioManager.play_sfx("quest_complete", -4.0)
		"item":
			AudioManager.play_sfx("pickup", -10.0)


func _process_toasts(_delta: float) -> void:
	while not _toast_queue.is_empty() and _toasts.get_child_count() < 4:
		var e: Array = _toast_queue.pop_front()
		_spawn_toast(e[0], e[1])


func _spawn_toast(text: String, kind: String) -> void:
	var colors := {"discovery": Color("#f3c74f"), "quest": Color("#7dffa0"), "warning": Color("#ff9a8a"), "item": Color("#c9b8f2"), "hint": Color("#9fe8ff")}
	var c: Color = colors.get(kind, UITheme.MOON)
	var pc := PanelContainer.new()
	pc.add_theme_stylebox_override("panel", UITheme.box(Color(0.08, 0.05, 0.16, 0.88), c, 14, 2, 12))
	pc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var l := UITheme.label(text, 0.82 if kind == "item" else 0.9, c, true)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.custom_minimum_size.x = 620
	pc.add_child(l)
	_toasts.add_child(pc)
	pc.modulate.a = 0.0
	var life := 2.2 if kind == "item" else (6.5 if kind == "hint" else 4.0)
	var tw := pc.create_tween()
	tw.tween_property(pc, "modulate:a", 1.0, 0.25)
	tw.tween_interval(life)
	tw.tween_property(pc, "modulate:a", 0.0, 0.5)
	tw.tween_callback(pc.queue_free)


# ================================================================== painéis

func open_panel(panel: String, payload: Dictionary) -> void:
	if panel == "theme_changed":
		root.theme = UITheme.get_theme()
		return
	if panel == "room_changed":
		_update_room_ui()
		return
	if panel == "dialogue_node":
		panel = "dialogue"
	if modal and is_instance_valid(modal):
		modal.queue_free()
	var p: Control
	if panel == "dialogue":
		p = DialoguePanel.new()
	elif PANEL_CLASSES.has(panel):
		p = PANEL_CLASSES[panel].new()
	else:
		push_warning("Painel desconhecido: " + panel)
		return
	modal = p
	root.add_child(p)
	root.move_child(_toasts, -1)
	p.closed.connect(_on_modal_closed.bind(p))
	_release_all()
	Game.world_running = false
	if player:
		player.input_enabled = false
	p.open(payload)


func _on_modal_closed(p: Control) -> void:
	if modal == p:
		modal = null
		Game.world_running = true
		if player:
			player.input_enabled = true
		_refresh_tracker()


func _on_faint() -> void:
	EventBus.notify.emit("Tudo gira... e escurece.", "warning")


# ================================================================== multitoque

func _input(event: InputEvent) -> void:
	if modal != null:
		return
	if event is InputEventScreenTouch:
		if event.pressed:
			_pointer_down(event.index, event.position)
		else:
			_pointer_up(event.index)
	elif event is InputEventScreenDrag:
		_pointer_move(event.index, event.position, event.relative)
	elif event is InputEventMouseButton and event.device != InputEvent.DEVICE_ID_EMULATION and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			_pointer_down(99, event.position)
		else:
			_pointer_up(99)
	elif event is InputEventMouseMotion and event.device != InputEvent.DEVICE_ID_EMULATION and _pointers.has(99):
		_pointer_move(99, event.position, event.relative)
	elif event.is_action_pressed("open_book"):
		open_panel("book", {})
	elif event.is_action_pressed("pause"):
		open_panel("book", {"tab": "opcoes"})
	elif event.is_action_pressed("hint"):
		_hint()


func _pointer_down(idx: int, pos: Vector2) -> void:
	for b in [_btn_interact, _btn_cast, _btn_book, _btn_hint] + _slots:
		if b.hit(pos):
			b.press()
			Settings.vibrate(15)
			_pointers[idx] = {"role": "button", "pos": pos}
			get_viewport().set_input_as_handled()
			return
	var vp := root.get_viewport_rect().size
	if pos.x < vp.x * 0.4 and pos.y > vp.y * 0.38 and not _joy.active:
		_joy.start(pos - _joy.global_position)
		_pointers[idx] = {"role": "joy", "pos": pos}
	else:
		_pointers[idx] = {"role": "cam", "pos": pos}
		_update_pinch()
	get_viewport().set_input_as_handled()


func _pointer_move(idx: int, pos: Vector2, rel: Vector2) -> void:
	if not _pointers.has(idx):
		return
	var p: Dictionary = _pointers[idx]
	match p.role:
		"joy":
			_joy.drag(pos - _joy.global_position)
		"cam":
			p.pos = pos
			var cams := _cam_pointers()
			if cams.size() >= 2:
				var d: float = cams[0].pos.distance_to(cams[1].pos)
				if _pinch_dist > 0.0 and player:
					player.zoom_camera(_pinch_dist / maxf(d, 1.0))
				_pinch_dist = d
			elif player:
				player.rotate_camera(rel)
	get_viewport().set_input_as_handled()


func _pointer_up(idx: int) -> void:
	if not _pointers.has(idx):
		return
	if _pointers[idx].role == "joy":
		_joy.release()
	_pointers.erase(idx)
	_update_pinch()


func _cam_pointers() -> Array:
	var out: Array = []
	for k in _pointers:
		if _pointers[k].role == "cam":
			out.append(_pointers[k])
	return out


func _update_pinch() -> void:
	var cams := _cam_pointers()
	_pinch_dist = cams[0].pos.distance_to(cams[1].pos) if cams.size() >= 2 else 0.0


func _release_all() -> void:
	_pointers.clear()
	_joy.release()
	_pinch_dist = 0.0
