class_name ModalPanel
extends Control
## Base dos painéis modais: fundo escurecido, moldura, título e botão fechar.
## Voltar do Android / Esc fecha o painel.

signal closed()

var frame: PanelContainer
var content: VBoxContainer
var title_label: Label
var scroll: ScrollContainer
var _closing := false


func _init() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	theme = UITheme.get_theme()


func build_frame(title: String, w_ratio: float = 0.86, h_ratio: float = 0.9, use_scroll: bool = true) -> void:
	var dim := ColorRect.new()
	dim.color = Color(0.03, 0.02, 0.08, 0.6)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	frame = PanelContainer.new()
	var vp := get_viewport_rect().size if is_inside_tree() else Vector2(1280, 720)
	frame.custom_minimum_size = Vector2(vp.x * w_ratio, vp.y * h_ratio)
	center.add_child(frame)
	var outer := VBoxContainer.new()
	outer.add_theme_constant_override("separation", 10)
	frame.add_child(outer)
	var header := HBoxContainer.new()
	outer.add_child(header)
	title_label = UITheme.label(title, 1.3, UITheme.GOLD)
	title_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title_label)
	var close_btn := UITheme.button("X", close, 56)
	close_btn.custom_minimum_size.x = 64
	header.add_child(close_btn)
	var sep := HSeparator.new()
	outer.add_child(sep)
	content = VBoxContainer.new()
	content.add_theme_constant_override("separation", 10)
	content.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if use_scroll:
		scroll = ScrollContainer.new()
		scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
		scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
		outer.add_child(scroll)
		scroll.add_child(content)
	else:
		outer.add_child(content)


func open(_payload: Dictionary) -> void:
	pass


func close() -> void:
	if _closing:
		return
	_closing = true
	AudioManager.play_sfx("ui_close", -6.0)
	closed.emit()
	queue_free()


func clear_content() -> void:
	for c in content.get_children():
		c.queue_free()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause") or event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		close()


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST:
		close()
