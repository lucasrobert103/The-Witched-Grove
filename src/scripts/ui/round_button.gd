class_name RoundButton
extends Control
## Botão circular desenhado (HUD). Não usa o sistema de GUI: o HUD faz o toque
## manualmente para permitir multitoque (andar + lançar feitiço ao mesmo tempo).

signal triggered()

var label: String = ""
var sublabel: String = ""
var icon: String = ""              # star, hand, book, cat, moon, leaf...
var color: Color = UITheme.PURPLE
var cooldown: float = 0.0          # 0..1
var selected: bool = false
var dim: bool = false
var _press_t := 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func hit(global_pos: Vector2) -> bool:
	if not is_visible_in_tree():
		return false
	var c := global_position + size * 0.5
	return global_pos.distance_to(c) <= size.x * 0.55


func press() -> void:
	_press_t = 0.18
	triggered.emit()
	queue_redraw()


func _process(delta: float) -> void:
	if _press_t > 0.0:
		_press_t -= delta
		queue_redraw()


func _draw() -> void:
	var r := size.x * 0.5
	var c := size * 0.5
	var s := 1.0 - (_press_t / 0.18) * 0.08 if _press_t > 0.0 else 1.0
	r *= s
	var a := 0.55 if dim else 0.92
	draw_circle(c + Vector2(0, 4), r, Color(0, 0, 0, 0.3))
	draw_circle(c, r, Color(color.darkened(0.35), a))
	draw_circle(c, r * 0.86, Color(color, a))
	draw_circle(c + Vector2(-r * 0.25, -r * 0.3), r * 0.35, Color(1, 1, 1, 0.12))
	draw_arc(c, r, 0, TAU, 48, Color(UITheme.GOLD if selected else UITheme.GOLD_DIM, 1.0), 4.0 if selected else 2.5, true)
	if cooldown > 0.0:
		var pts := PackedVector2Array([c])
		var steps := 32
		for i in steps + 1:
			var ang := -PI / 2.0 + TAU * cooldown * float(i) / steps
			pts.append(c + Vector2(cos(ang), sin(ang)) * r * 0.86)
		draw_colored_polygon(pts, Color(0, 0, 0, 0.55))
	_draw_icon(c, r * 0.5)
	var font := get_theme_default_font()
	if label != "":
		var fs := int(UITheme.font_size(0.62 if size.x < 100 else 0.75))
		var w := font.get_string_size(label, HORIZONTAL_ALIGNMENT_CENTER, -1, fs).x
		var y := c.y + r * (0.55 if icon != "" else 0.15)
		draw_string_outline(font, Vector2(c.x - w * 0.5, y), label, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, 6, Color(0, 0, 0, 0.8))
		draw_string(font, Vector2(c.x - w * 0.5, y), label, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color.WHITE)


func _draw_icon(c: Vector2, r: float) -> void:
	var col := Color(1, 1, 1, 0.95)
	var off := Vector2(0, -r * 0.25) if label != "" else Vector2.ZERO
	c += off
	match icon:
		"star":
			draw_colored_polygon(_star_pts(c, r * 0.9, r * 0.4), UITheme.GOLD)
		"hand":
			draw_circle(c, r * 0.45, col)
			for i in 4:
				draw_rect(Rect2(c + Vector2(-r * 0.45 + i * r * 0.27, -r * 0.95), Vector2(r * 0.2, r * 0.6)), col)
		"book":
			draw_rect(Rect2(c - Vector2(r * 0.8, r * 0.6), Vector2(r * 0.75, r * 1.2)), UITheme.PARCHMENT)
			draw_rect(Rect2(c - Vector2(-r * 0.05, r * 0.6), Vector2(r * 0.75, r * 1.2)), UITheme.PARCHMENT.darkened(0.1))
			draw_line(c - Vector2(0, r * 0.6), c + Vector2(0, r * 0.6), UITheme.INK, 2.0)
		"cat":
			draw_circle(c, r * 0.6, col)
			draw_colored_polygon(PackedVector2Array([c + Vector2(-r * 0.6, -r * 0.2), c + Vector2(-r * 0.45, -r * 0.95), c + Vector2(-r * 0.1, -r * 0.5)]), col)
			draw_colored_polygon(PackedVector2Array([c + Vector2(r * 0.6, -r * 0.2), c + Vector2(r * 0.45, -r * 0.95), c + Vector2(r * 0.1, -r * 0.5)]), col)
			draw_circle(c + Vector2(-r * 0.22, 0), r * 0.1, UITheme.INK)
			draw_circle(c + Vector2(r * 0.22, 0), r * 0.1, UITheme.INK)
		"flame":
			draw_colored_polygon(PackedVector2Array([c + Vector2(0, -r), c + Vector2(r * 0.6, r * 0.2), c + Vector2(r * 0.35, r * 0.7), c + Vector2(-r * 0.35, r * 0.7), c + Vector2(-r * 0.6, r * 0.2)]), Color("#ffb070"))
			draw_circle(c + Vector2(0, r * 0.3), r * 0.35, Color("#fff3a0"))
		"snow":
			for k in 3:
				var a := k * PI / 3.0
				draw_line(c - Vector2(cos(a), sin(a)) * r, c + Vector2(cos(a), sin(a)) * r, Color("#e6f7ff"), 3.0)
			draw_circle(c, r * 0.18, Color.WHITE)
		"feather":
			draw_line(c + Vector2(-r * 0.7, r * 0.8), c + Vector2(r * 0.6, -r * 0.8), col, 2.0)
			draw_colored_polygon(PackedVector2Array([c + Vector2(r * 0.6, -r * 0.9), c + Vector2(r * 0.1, -r * 0.1), c + Vector2(-r * 0.5, r * 0.4), c + Vector2(-r * 0.1, -r * 0.3)]), col)
		"swirl":
			for k in 3:
				draw_arc(c, r * (0.3 + k * 0.28), k * 1.2, k * 1.2 + 4.0, 16, Color("#ffd1f0"), 3.0, true)
			draw_colored_polygon(_star_pts(c, r * 0.3, r * 0.12), UITheme.GOLD)
		"sun":
			draw_circle(c, r * 0.45, Color("#fff3a0"))
			for k in 8:
				var a2 := k * TAU / 8.0
				draw_line(c + Vector2(cos(a2), sin(a2)) * r * 0.62, c + Vector2(cos(a2), sin(a2)) * r * 0.95, Color("#fff3a0"), 3.0)
		"leaf":
			draw_circle(c + Vector2(-r * 0.15, -r * 0.1), r * 0.55, Color("#9dff9a"))
			draw_line(c + Vector2(-r * 0.6, r * 0.7), c + Vector2(r * 0.3, -r * 0.4), Color("#2f6a3a"), 3.0)
		"shield":
			draw_colored_polygon(PackedVector2Array([c + Vector2(-r * 0.7, -r * 0.7), c + Vector2(r * 0.7, -r * 0.7), c + Vector2(r * 0.6, r * 0.2), c + Vector2(0, r * 0.9), c + Vector2(-r * 0.6, r * 0.2)]), Color("#9ff0ff"))
		"eye":
			draw_circle(c, r * 0.65, Color("#f2f5ff"))
			draw_circle(c, r * 0.32, Color("#5a3a8a"))
			draw_circle(c + Vector2(-r * 0.1, -r * 0.1), r * 0.1, Color.WHITE)
		"wind":
			for k in 3:
				draw_arc(c + Vector2(0, (k - 1) * r * 0.45), r * 0.6, -PI * 0.9, 0.2, 12, Color("#f2f5ff"), 3.0, true)
		"rune":
			draw_arc(c, r * 0.75, 0, TAU, 24, Color("#d6b8ff"), 3.0, true)
			draw_line(c + Vector2(0, -r * 0.5), c + Vector2(0, r * 0.5), Color("#d6b8ff"), 3.0)
			draw_line(c + Vector2(-r * 0.35, -r * 0.1), c + Vector2(r * 0.35, r * 0.25), Color("#d6b8ff"), 3.0)
		"pause":
			draw_rect(Rect2(c - Vector2(r * 0.45, r * 0.6), Vector2(r * 0.3, r * 1.2)), col)
			draw_rect(Rect2(c + Vector2(r * 0.15, -r * 0.6), Vector2(r * 0.3, r * 1.2)), col)


static func _star_pts(c: Vector2, ro: float, ri: float) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in 10:
		var a := -PI / 2.0 + i * PI / 5.0
		pts.append(c + Vector2(cos(a), sin(a)) * (ro if i % 2 == 0 else ri))
	return pts
