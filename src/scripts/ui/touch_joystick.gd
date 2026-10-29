class_name TouchJoystick
extends Control
## Joystick virtual flutuante: aparece onde o polegar toca, dentro da zona esquerda.

var value: Vector2 = Vector2.ZERO
var active: bool = false
var radius: float = 90.0
var _center: Vector2
var _knob: Vector2


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func idle_center() -> Vector2:
	return Vector2(size.x * 0.5, size.y * 0.55)


func start(local_pos: Vector2) -> void:
	active = true
	_center = local_pos
	_knob = local_pos
	value = Vector2.ZERO
	queue_redraw()


func drag(local_pos: Vector2) -> void:
	var d := local_pos - _center
	if d.length() > radius:
		d = d.normalized() * radius
	_knob = _center + d
	value = d / radius
	if value.length() < 0.12:
		value = Vector2.ZERO
	queue_redraw()


func release() -> void:
	active = false
	value = Vector2.ZERO
	queue_redraw()


func _draw() -> void:
	var c := _center if active else idle_center()
	var k := _knob if active else c
	var a := 0.55 if active else 0.28
	draw_circle(c, radius + 8.0, Color(0.1, 0.06, 0.2, a * 0.6))
	draw_arc(c, radius + 8.0, 0, TAU, 48, Color(UITheme.GOLD, a), 3.0, true)
	for i in 4:
		var ang := i * TAU / 4.0 - PI / 2.0
		var p := c + Vector2(cos(ang), sin(ang)) * (radius - 14.0)
		draw_circle(p, 5.0, Color(UITheme.MOON, a * 0.8))
	draw_circle(k, 40.0, Color(UITheme.PURPLE, 0.85 if active else 0.5))
	draw_arc(k, 40.0, 0, TAU, 32, Color(UITheme.GOLD, 0.9 if active else 0.5), 3.0, true)
	draw_circle(k + Vector2(-10, -10), 10.0, Color(1, 1, 1, 0.25))
