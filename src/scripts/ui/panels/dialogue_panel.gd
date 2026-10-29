class_name DialoguePanel
extends Control
## Diálogo: caixa inferior com nome, retrato colorido, texto digitado e escolhas.

signal closed()

var npc_id := ""
var _name: Label
var _text: Label
var _options: VBoxContainer
var _portrait: Panel
var _tween: Tween


func _init() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	theme = UITheme.get_theme()


func open(payload: Dictionary) -> void:
	npc_id = payload.get("npc", "")
	var dim := ColorRect.new()
	dim.color = Color(0.02, 0.01, 0.06, 0.35)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(dim)
	var box := PanelContainer.new()
	box.anchor_left = 0.04
	box.anchor_right = 0.96
	box.anchor_top = 0.5
	box.anchor_bottom = 0.97
	add_child(box)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 18)
	box.add_child(row)
	_portrait = Panel.new()
	_portrait.custom_minimum_size = Vector2(120, 120)
	var col := Color(DataRegistry.factions.get(DataRegistry.npcs.get(npc_id, {}).get("faction", ""), {}).get("color", "#7a4fc4"))
	_portrait.add_theme_stylebox_override("panel", UITheme.box(col.darkened(0.2), UITheme.GOLD, 60, 4))
	_portrait.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	var initial := UITheme.label(DataRegistry.npc_name(npc_id).substr(0, 1), 2.4, Color.WHITE)
	initial.set_anchors_preset(Control.PRESET_FULL_RECT)
	initial.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	initial.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_portrait.add_child(initial)
	row.add_child(_portrait)
	var col_v := VBoxContainer.new()
	col_v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col_v.add_theme_constant_override("separation", 8)
	row.add_child(col_v)
	_name = UITheme.label(DataRegistry.npc_name(npc_id), 1.15, UITheme.GOLD)
	col_v.add_child(_name)
	_text = UITheme.label("", 1.05, Color(0, 0, 0, 0), true)
	_text.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_text.mouse_filter = Control.MOUSE_FILTER_STOP
	_text.gui_input.connect(_on_text_input)
	col_v.add_child(_text)
	var opt_scroll := ScrollContainer.new()
	opt_scroll.custom_minimum_size = Vector2(0, 150)
	opt_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	opt_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	col_v.add_child(opt_scroll)
	_options = VBoxContainer.new()
	_options.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	opt_scroll.add_child(_options)
	if payload.has("node"):
		Game.dialogue.npc_id = npc_id
		Game.dialogue.finished = false
		Game.dialogue._enter(payload.node)
	elif not Game.dialogue.start(npc_id):
		_finish()
		return
	_render()


func _render() -> void:
	if Game.dialogue.finished:
		_finish()
		return
	Game.refresh_quests()
	_text.text = Game.dialogue.text()
	_text.visible_ratio = 0.0
	if _tween:
		_tween.kill()
	_tween = create_tween()
	_tween.tween_property(_text, "visible_ratio", 1.0, clampf(_text.text.length() * 0.018, 0.4, 3.0))
	for c in _options.get_children():
		c.queue_free()
	for o in Game.dialogue.options():
		var idx: int = o.index
		var b := UITheme.button("» " + o.text, func(): _choose(idx))
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_options.add_child(b)


func _on_text_input(ev: InputEvent) -> void:
	if ev is InputEventMouseButton and ev.pressed and _tween and _tween.is_running():
		_tween.kill()
		_text.visible_ratio = 1.0


func _choose(index: int) -> void:
	if _tween and _tween.is_running():
		_tween.kill()
		_text.visible_ratio = 1.0
	Game.dialogue.choose(index)
	Game.refresh_quests()
	_render()


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
