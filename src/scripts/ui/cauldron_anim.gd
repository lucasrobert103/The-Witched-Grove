class_name CauldronAnim
extends Control
## Animação do preparo: ingredientes caem no caldeirão, a cor se mistura,
## a colher gira, bolhas estouram, sobe vapor — e no fim a poção aparece (ou fumaça).

signal finished()

const DURATION := 3.2

var ingredient_ids: Array = []
var result_color: Color = Color("#7dffb0")
var result_item: String = ""
var success: bool = true
var _t := 0.0
var _bubbles: Array = []
var _done := false
var _icon: ItemIcon


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	for i in 18:
		_bubbles.append({"x": randf_range(-0.6, 0.6), "phase": randf() * 3.0, "speed": randf_range(0.6, 1.4), "r": randf_range(4.0, 11.0)})
	_icon = ItemIcon.new()
	_icon.show_frame = false
	_icon.item_id = result_item
	_icon.custom_minimum_size = Vector2(110, 110)
	_icon.size = Vector2(110, 110)
	_icon.visible = false
	add_child(_icon)


func _process(delta: float) -> void:
	_t += delta
	queue_redraw()
	if _t > DURATION and not _done:
		_done = true
		finished.emit()


func _mix_color() -> Color:
	if ingredient_ids.is_empty():
		return result_color
	var c := Color(0, 0, 0)
	for id in ingredient_ids:
		c += DataRegistry.item_color(id)
	c /= float(ingredient_ids.size())
	var k := clampf((_t - 1.4) / 1.0, 0.0, 1.0)
	var target := result_color if success else Color("#6b6460")
	return c.lerp(target, k)


func _draw() -> void:
	var c := Vector2(size.x * 0.5, size.y * 0.6)
	var R := minf(size.x, size.y) * 0.3
	var liquid := _mix_color()
	# fogo embaixo
	for i in 7:
		var fx := c.x + (i - 3) * R * 0.22
		var fh := R * (0.35 + 0.15 * sin(_t * 12.0 + i * 1.7))
		draw_colored_polygon(PackedVector2Array([Vector2(fx - R * 0.1, c.y + R * 1.05), Vector2(fx + R * 0.1, c.y + R * 1.05), Vector2(fx, c.y + R * 1.05 - fh)]), Color("#ff9a3c").lerp(Color("#ffe27a"), 0.5 + 0.5 * sin(_t * 9.0 + i)))
	# corpo do caldeirão
	draw_circle(c + Vector2(0, R * 0.15), R, Color("#2a2433"))
	draw_circle(c + Vector2(-R * 0.35, -R * 0.05), R * 0.25, Color(1, 1, 1, 0.06))
	for sx in [-1.0, 1.0]:
		draw_rect(Rect2(c + Vector2(sx * R * 0.6 - R * 0.08, R * 0.95), Vector2(R * 0.16, R * 0.3)), Color("#2a2433"))
	# boca e líquido (elipse)
	_ellipse(c + Vector2(0, -R * 0.55), Vector2(R * 1.05, R * 0.32), Color("#3a3444"))
	var glow := 0.6 + 0.4 * sin(_t * 5.0)
	_ellipse(c + Vector2(0, -R * 0.55), Vector2(R * 0.92, R * 0.25), liquid)
	_ellipse(c + Vector2(0, -R * 0.58), Vector2(R * 0.6, R * 0.14), liquid.lightened(0.25 * glow))
	# redemoinho
	for k in 3:
		var a := _t * 4.0 + k * TAU / 3.0
		draw_arc(c + Vector2(0, -R * 0.55), R * (0.25 + k * 0.18), a, a + 1.6, 16, Color(1, 1, 1, 0.25), 2.0, true)
	# colher mexendo
	var sa := sin(_t * 3.0) * 0.7
	var sp := c + Vector2(sin(sa) * R * 0.45, -R * 0.6)
	draw_line(sp, sp + Vector2(R * 0.5 * sin(sa + 0.6), -R * 1.2), Color("#8a5a36"), 7.0)
	# ingredientes caindo
	for i in ingredient_ids.size():
		var t0 := 0.2 + i * 0.35
		var k := clampf((_t - t0) / 0.6, 0.0, 1.0)
		if k <= 0.0 or k >= 1.0:
			if k >= 1.0 and _t - t0 < 0.9:
				var sk := (_t - t0 - 0.6) / 0.3
				for j in 6:
					var a2 := j * TAU / 6.0
					draw_circle(c + Vector2(cos(a2) * R * 0.3 * sk, -R * 0.6 - sin(a2) * R * 0.3 * sk), 4.0 * (1.0 - sk), liquid.lightened(0.4))
			continue
		var y := lerpf(-R * 2.2, -R * 0.55, k * k)
		var col := DataRegistry.item_color(ingredient_ids[i])
		var pos := c + Vector2((i - (ingredient_ids.size() - 1) * 0.5) * R * 0.35 * (1.0 - k), y)
		draw_circle(pos, R * 0.13, col)
		draw_circle(pos + Vector2(-R * 0.04, -R * 0.04), R * 0.04, Color(1, 1, 1, 0.7))
	# bolhas
	for b in _bubbles:
		var ph := fmod(_t * b.speed + b.phase, 1.6)
		if ph < 1.0:
			var bp := c + Vector2(b.x * R * 0.8, -R * 0.55 - ph * R * 0.9)
			draw_arc(bp, b.r * (0.6 + ph * 0.6), 0, TAU, 12, liquid.lightened(0.5), 2.0, true)
	# vapor
	for k in 5:
		var vp := fmod(_t * 0.7 + k * 0.2, 1.0)
		draw_circle(c + Vector2(sin(_t + k) * R * 0.4, -R * 0.8 - vp * R * 1.6), R * (0.12 + vp * 0.25), Color(1, 1, 1, 0.18 * (1.0 - vp)))
	# final: poção sobe ou fumaça
	if _t > 2.4:
		var e := clampf((_t - 2.4) / 0.6, 0.0, 1.0)
		if success:
			for k in 12:
				var a3 := k * TAU / 12.0 + _t
				draw_colored_polygon(RoundButton._star_pts(c + Vector2(cos(a3), sin(a3)) * R * (0.4 + e * 0.9) + Vector2(0, -R * 1.2), 8.0, 3.5), Color(UITheme.GOLD, 1.0 - e * 0.5))
			_icon.visible = true
			_icon.position = c + Vector2(-55, -R * 1.2 - 55 - e * R * 0.6)
			_icon.scale = Vector2.ONE * (0.4 + e * 0.6)
		else:
			for k in 8:
				var a4 := k * TAU / 8.0
				draw_circle(c + Vector2(cos(a4) * R * e * 1.1, -R * 0.9 + sin(a4) * R * e * 0.6), R * 0.35 * (1.0 - e * 0.4), Color(0.45, 0.42, 0.45, 0.6 * (1.0 - e)))


func _ellipse(center: Vector2, radii: Vector2, col: Color) -> void:
	var pts := PackedVector2Array()
	for i in 32:
		var a := i * TAU / 32.0
		pts.append(center + Vector2(cos(a) * radii.x, sin(a) * radii.y))
	draw_colored_polygon(pts, col)
