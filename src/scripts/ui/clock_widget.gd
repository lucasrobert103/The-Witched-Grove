class_name ClockWidget
extends Control
## Relógio: dia, estação, hora, fase da lua e clima (ícones desenhados).

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	custom_minimum_size = Vector2(260, 78)


func _process(_delta: float) -> void:
	queue_redraw()


func _draw() -> void:
	var font := get_theme_default_font()
	var bg := UITheme.box(Color(0.11, 0.08, 0.2, 0.85), UITheme.GOLD_DIM, 18, 2)
	draw_style_box(bg, Rect2(Vector2.ZERO, size))
	var clk := Game.clock
	var fs := UITheme.font_size(0.8)
	draw_string(font, Vector2(16, 32), clk.time_string(), HORIZONTAL_ALIGNMENT_LEFT, -1, UITheme.font_size(1.15), Color.WHITE)
	draw_string(font, Vector2(16, 62), "Dia %d · %s" % [clk.day(), DataRegistry.season_name(clk.season())], HORIZONTAL_ALIGNMENT_LEFT, -1, fs, UITheme.PARCHMENT)
	# lua
	var mc := Vector2(size.x - 92, 38)
	_draw_moon(mc, 18.0, clk.moon_phase())
	# clima
	_draw_weather(Vector2(size.x - 40, 38), clk.weather(), clk.is_night())


func _draw_moon(c: Vector2, r: float, phase: int) -> void:
	draw_circle(c, r, Color("#2a2350"))
	var lit := Color("#f6f1ff")
	if phase == 0:
		draw_arc(c, r, 0, TAU, 32, Color(lit, 0.5), 2.0, true)
		return
	if phase == 4:
		draw_circle(c, r, lit)
		return
	var waxing := phase < 4
	var k := absf(4 - phase) / 4.0        # 0 = cheia, 1 = nova
	var pts := PackedVector2Array()
	for i in 33:
		var a := -PI / 2.0 + PI * i / 32.0
		pts.append(c + Vector2(cos(a) * r * (1.0 if waxing else -1.0), sin(a) * r))
	for i in 33:
		var a := PI / 2.0 - PI * i / 32.0
		var x := cos(a) * r * (k * 2.0 - 1.0)
		pts.append(c + Vector2(x * (1.0 if waxing else -1.0), sin(a) * r))
	draw_colored_polygon(pts, lit)


func _draw_weather(c: Vector2, w: String, night: bool) -> void:
	match w:
		"limpo":
			if night:
				draw_colored_polygon(RoundButton._star_pts(c, 16.0, 7.0), UITheme.GOLD)
			else:
				draw_circle(c, 11.0, UITheme.GOLD)
				for i in 8:
					var a := i * TAU / 8.0
					draw_line(c + Vector2(cos(a), sin(a)) * 14.0, c + Vector2(cos(a), sin(a)) * 19.0, UITheme.GOLD, 3.0)
		"chuva", "neve", "bruma":
			draw_circle(c + Vector2(-7, 0), 9.0, Color("#dfe6f5"))
			draw_circle(c + Vector2(5, -4), 11.0, Color("#dfe6f5"))
			draw_circle(c + Vector2(12, 2), 8.0, Color("#dfe6f5"))
			if w == "chuva":
				for i in 3:
					draw_line(c + Vector2(-8 + i * 8, 12), c + Vector2(-11 + i * 8, 20), Color("#8fd6ff"), 3.0)
			elif w == "neve":
				for i in 3:
					draw_circle(c + Vector2(-8 + i * 8, 16), 2.5, Color.WHITE)
			else:
				draw_line(c + Vector2(-16, 14), c + Vector2(16, 14), Color(1, 1, 1, 0.7), 3.0)
				draw_line(c + Vector2(-12, 20), c + Vector2(18, 20), Color(1, 1, 1, 0.5), 3.0)
