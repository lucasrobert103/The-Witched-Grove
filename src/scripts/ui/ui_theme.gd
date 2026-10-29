class_name UITheme
extends RefCounted
## Identidade visual da interface: pergaminho noturno, ouro e púrpura.
## Botões com no mínimo 48 dp, textos legíveis em 5,5"–7" e modo de alto contraste.

const GOLD := Color("#f3c74f")
const GOLD_DIM := Color("#b8923a")
const PURPLE := Color("#7a4fc4")
const PURPLE_DARK := Color("#2a1d44")
const NIGHT := Color("#1b1430")
const FOREST := Color("#3f8f55")
const MOON := Color("#f6f1ff")
const ROSE := Color("#ff7a9a")
const MANA := Color("#7f8cff")
const PARCHMENT := Color("#f3e6c4")
const INK := Color("#2a1d2e")
const BASE_FONT := 22

static var _theme: Theme
static var _theme_key := ""
static var _book_theme: Theme
static var _book_key := ""


static func font_size(mult: float = 1.0) -> int:
	return int(round(BASE_FONT * Settings.text_scale() * mult))


static func get_theme() -> Theme:
	var key := "%f|%s" % [Settings.text_scale(), str(Settings.high_contrast)]
	if _theme and key == _theme_key:
		return _theme
	_theme_key = key
	_theme = _build()
	return _theme


## Tema "tinta sobre pergaminho" usado dentro do grimório.
static func get_book_theme() -> Theme:
	var key := "%f|%s" % [Settings.text_scale(), str(Settings.high_contrast)]
	if _book_theme and key == _book_key:
		return _book_theme
	_book_key = key
	var t := _build().duplicate(true) as Theme
	var ink_c := INK
	t.set_color("font_color", "Label", ink_c)
	t.set_constant("outline_size", "Label", 0)
	t.set_color("default_color", "RichTextLabel", ink_c)
	var bn := box(Color(0.55, 0.38, 0.2, 0.12), Color("#8a6a4a"), 10, 2, 14)
	var bh := box(Color(0.55, 0.38, 0.2, 0.25), Color("#7a2a14"), 10, 2, 14)
	var bp := box(Color("#7a2a14"), Color("#4a1a0a"), 10, 2, 14)
	var bd := box(Color(0.5, 0.45, 0.4, 0.15), Color(0.6, 0.55, 0.5, 0.6), 10, 2, 14)
	for sb in [bn, bh, bp, bd]:
		sb.content_margin_top = 8
		sb.content_margin_bottom = 8
	t.set_stylebox("normal", "Button", bn)
	t.set_stylebox("hover", "Button", bh)
	t.set_stylebox("pressed", "Button", bp)
	t.set_stylebox("disabled", "Button", bd)
	t.set_color("font_color", "Button", ink_c)
	t.set_color("font_hover_color", "Button", Color("#7a2a14"))
	t.set_color("font_pressed_color", "Button", Color("#fff6e0"))
	t.set_color("font_disabled_color", "Button", Color(0.45, 0.4, 0.35))
	t.set_color("font_color", "CheckButton", ink_c)
	t.set_color("font_color", "CheckBox", ink_c)
	t.set_stylebox("background", "ProgressBar", box(Color(0.4, 0.3, 0.2, 0.25), Color("#8a6a4a"), 8, 1, 0))
	t.set_stylebox("panel", "PanelContainer", box(Color(0.55, 0.38, 0.2, 0.08), Color("#b89a72"), 12, 2, 12))
	_book_theme = t
	return t


static func box(bg: Color, border: Color = Color.TRANSPARENT, radius: int = 18, border_w: int = 0, pad: int = 12) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = border
	s.set_border_width_all(border_w)
	s.set_corner_radius_all(radius)
	s.content_margin_left = pad
	s.content_margin_right = pad
	s.content_margin_top = pad * 0.6
	s.content_margin_bottom = pad * 0.6
	s.anti_aliasing = true
	return s


static func _build() -> Theme:
	var hc := Settings.high_contrast
	var t := Theme.new()
	t.default_font_size = font_size()
	var panel_bg := Color("#120c22") if hc else Color(0.11, 0.08, 0.2, 0.94)
	var text := Color.WHITE if hc else MOON
	t.set_stylebox("panel", "PanelContainer", box(panel_bg, GOLD if hc else GOLD_DIM, 22, 3, 18))
	t.set_stylebox("panel", "Panel", box(panel_bg, GOLD_DIM, 22, 2, 18))
	# Botões
	var bn := box(Color("#4a2f7a") if not hc else Color("#000000"), GOLD_DIM if not hc else GOLD, 16, 2, 16)
	var bh := box(Color("#5c3c94") if not hc else Color("#222222"), GOLD, 16, 3, 16)
	var bp := box(Color("#7a4fc4") if not hc else Color("#444444"), GOLD, 16, 3, 16)
	var bd := box(Color(0.25, 0.22, 0.32, 0.8), Color(0.4, 0.38, 0.45), 16, 2, 16)
	for s in [bn, bh, bp, bd]:
		s.content_margin_top = 10
		s.content_margin_bottom = 10
	t.set_stylebox("normal", "Button", bn)
	t.set_stylebox("hover", "Button", bh)
	t.set_stylebox("pressed", "Button", bp)
	t.set_stylebox("disabled", "Button", bd)
	t.set_stylebox("focus", "Button", box(Color.TRANSPARENT, GOLD, 16, 3))
	t.set_color("font_color", "Button", text)
	t.set_color("font_hover_color", "Button", GOLD)
	t.set_color("font_pressed_color", "Button", Color.WHITE)
	t.set_color("font_disabled_color", "Button", Color(0.7, 0.68, 0.75))
	t.set_constant("h_separation", "Button", 10)
	t.set_color("font_color", "Label", text)
	t.set_color("font_outline_color", "Label", Color(0, 0, 0, 0.6))
	t.set_constant("outline_size", "Label", 2 if not hc else 4)
	t.set_color("default_color", "RichTextLabel", text)
	t.set_font_size("normal_font_size", "RichTextLabel", font_size())
	t.set_font_size("bold_font_size", "RichTextLabel", font_size())
	# Barras
	var bar_bg := box(Color(0, 0, 0, 0.45), Color(1, 1, 1, 0.25), 10, 2, 0)
	t.set_stylebox("background", "ProgressBar", bar_bg)
	t.set_stylebox("fill", "ProgressBar", box(PURPLE, Color.TRANSPARENT, 10, 0, 0))
	t.set_color("font_color", "ProgressBar", text)
	# Rolagem larga para o polegar
	var grab := box(Color(GOLD, 0.7), Color.TRANSPARENT, 8, 0, 6)
	t.set_stylebox("grabber", "VScrollBar", grab)
	t.set_stylebox("grabber_highlight", "VScrollBar", box(GOLD, Color.TRANSPARENT, 8, 0, 6))
	t.set_stylebox("grabber_pressed", "VScrollBar", box(GOLD, Color.TRANSPARENT, 8, 0, 6))
	t.set_stylebox("scroll", "VScrollBar", box(Color(1, 1, 1, 0.08), Color.TRANSPARENT, 8, 0, 6))
	# Slider e caixas
	t.set_stylebox("slider", "HSlider", box(Color(1, 1, 1, 0.2), Color.TRANSPARENT, 8, 0, 4))
	t.set_stylebox("grabber_area", "HSlider", box(PURPLE, Color.TRANSPARENT, 8, 0, 4))
	t.set_stylebox("grabber_area_highlight", "HSlider", box(GOLD, Color.TRANSPARENT, 8, 0, 4))
	t.set_color("font_color", "CheckButton", text)
	t.set_color("font_color", "CheckBox", text)
	t.set_stylebox("normal", "LineEdit", box(Color(0, 0, 0, 0.35), GOLD_DIM, 12, 2, 10))
	t.set_color("font_color", "LineEdit", text)
	t.set_stylebox("normal", "TextEdit", box(Color(0, 0, 0, 0.35), GOLD_DIM, 12, 2, 10))
	t.set_color("font_color", "TextEdit", text)
	return t


## Botão padrão com altura mínima de toque.
static func button(text: String, cb: Callable = Callable(), min_h: int = 56) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(0, min_h * Settings.text_scale())
	b.focus_mode = Control.FOCUS_NONE
	if cb.is_valid():
		b.pressed.connect(cb)
	b.pressed.connect(func(): AudioManager.play_sfx("ui_click", -4.0))
	return b


static func label(text: String, size_mult: float = 1.0, color: Color = Color(0, 0, 0, 0), wrap: bool = false) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", font_size(size_mult))
	if color.a > 0.0:
		l.add_theme_color_override("font_color", color)
	if wrap:
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return l


static func rich(bbcode: String, size_mult: float = 1.0) -> RichTextLabel:
	var r := RichTextLabel.new()
	r.bbcode_enabled = true
	r.fit_content = true
	r.scroll_active = false
	r.text = bbcode
	r.add_theme_font_size_override("normal_font_size", font_size(size_mult))
	r.add_theme_font_size_override("bold_font_size", font_size(size_mult))
	r.add_theme_font_size_override("italics_font_size", font_size(size_mult))
	r.mouse_filter = Control.MOUSE_FILTER_PASS
	return r


static func bar(fill: Color, h: int = 22) -> ProgressBar:
	var p := ProgressBar.new()
	p.custom_minimum_size = Vector2(0, h)
	p.show_percentage = false
	p.add_theme_stylebox_override("fill", box(fill, Color.TRANSPARENT, 10, 0, 0))
	return p


static func card(bg: Color = Color(1, 1, 1, 0.06), border: Color = Color(1, 1, 1, 0.12)) -> PanelContainer:
	var pc := PanelContainer.new()
	pc.add_theme_stylebox_override("panel", box(bg, border, 14, 2, 12))
	return pc


static func color_hex(c: Color) -> String:
	return "#" + c.to_html(false)
