class_name BookEmblem
extends Control
## Brasão dourado da capa do grimório (lua, estrela e folhas) e ornamento de página.

var small: bool = false


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _draw() -> void:
	var gold := Color("#e3b85a")
	var ink := Color("#7a2a14")
	var c := size * 0.5
	if small:
		draw_line(Vector2(20, c.y), Vector2(c.x - 24, c.y), ink, 2.0, true)
		draw_line(Vector2(c.x + 24, c.y), Vector2(size.x - 20, c.y), ink, 2.0, true)
		draw_colored_polygon(RoundButton._star_pts(c, 16.0, 7.0), ink)
		draw_circle(Vector2(c.x - 34, c.y), 4.0, ink)
		draw_circle(Vector2(c.x + 34, c.y), 4.0, ink)
		return
	var r := minf(size.x, size.y) * 0.45
	draw_arc(c, r, 0, TAU, 64, gold, 4.0, true)
	draw_arc(c, r * 0.9, 0, TAU, 64, gold, 1.5, true)
	for i in 12:
		var a := i * TAU / 12.0
		draw_circle(c + Vector2(cos(a), sin(a)) * r * 0.95, 3.0, gold)
	# lua crescente
	var moon := PackedVector2Array()
	for i in 33:
		var a := PI * 0.5 + PI * float(i) / 32.0
		moon.append(c + Vector2(-r * 0.12, 0) + Vector2(cos(a), sin(a)) * r * 0.6)
	for i in 33:
		var a2 := PI * 1.5 - PI * float(i) / 32.0
		moon.append(c + Vector2(-r * 0.02, 0) + Vector2(cos(a2) * 0.45, sin(a2)) * r * 0.5)
	draw_colored_polygon(moon, gold)
	draw_colored_polygon(RoundButton._star_pts(c + Vector2(r * 0.25, -r * 0.05), r * 0.28, r * 0.11), gold)
	# folhas
	for sx in [-1.0, 1.0]:
		for k in 3:
			var p := c + Vector2(sx * r * (0.35 + k * 0.17), r * (0.62 - k * 0.12))
			draw_circle(p, r * 0.07, gold)
	draw_line(c + Vector2(-r * 0.6, r * 0.66), c + Vector2(r * 0.6, r * 0.66), gold, 2.0, true)
