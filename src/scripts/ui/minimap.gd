class_name Minimap
extends Control
## Minimapa circular desenhado: trilhas, água, pontos de interesse, NPCs e objetivo.

var player: Node3D
var terrain: ValleyTerrain
var world_radius: float = 26.0     # metros visíveis do centro à borda
var full_map: bool = false
var target: Vector3 = Vector3.INF


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _process(_delta: float) -> void:
	queue_redraw()


func _to_map(p: Vector3, center: Vector3, r: float) -> Vector2:
	var rel := Vector2(p.x - center.x, p.z - center.z) / world_radius * r
	return size * 0.5 + rel


func _draw() -> void:
	if player == null or terrain == null:
		return
	var r := minf(size.x, size.y) * 0.5
	var c := size * 0.5
	var center := Vector3.ZERO if full_map else player.global_position
	draw_circle(c, r, Color("#2f5a3a") if not Settings.high_contrast else Color.BLACK)
	draw_circle(c, r * 0.985, Color("#5f9a55") if not Settings.high_contrast else Color("#203020"))
	# água
	var pond := _to_map(Vector3(ValleyTerrain.POND_CENTER.x, 0, ValleyTerrain.POND_CENTER.y), center, r)
	_draw_clipped_circle(pond, ValleyTerrain.POND_RADIUS / world_radius * r, Color("#5ab0d8"), c, r)
	for i in terrain.creek.size() - 1:
		var a := _to_map(Vector3(terrain.creek[i].x, 0, terrain.creek[i].y), center, r)
		var b := _to_map(Vector3(terrain.creek[i + 1].x, 0, terrain.creek[i + 1].y), center, r)
		if a.distance_to(c) < r and b.distance_to(c) < r:
			draw_line(a, b, Color("#5ab0d8"), maxf(2.0, 4.0 / world_radius * r), true)
	# trilhas
	for path in terrain.paths:
		for i in path.size() - 1:
			var a := _to_map(Vector3(path[i].x, 0, path[i].y), center, r)
			var b := _to_map(Vector3(path[i + 1].x, 0, path[i + 1].y), center, r)
			if a.distance_to(c) < r * 0.98 and b.distance_to(c) < r * 0.98:
				draw_line(a, b, Color("#e8d6a0"), maxf(2.0, 2.0 / world_radius * r), true)
	# casa
	var home := _to_map(Vector3(0, 0, -6), center, r)
	if home.distance_to(c) < r:
		draw_rect(Rect2(home - Vector2(6, 6), Vector2(12, 12)), Color("#f3c74f"))
	# interativos com rótulo
	var font := get_theme_default_font()
	for n in get_tree().get_nodes_in_group("interactable"):
		var it := n as Interactable
		if it == null or not it.is_visible_in_tree():
			continue
		var p := _to_map(it.global_position, center, r)
		if p.distance_to(c) > r - 4.0:
			continue
		if it is NPCActor:
			draw_circle(p, 6.0, it.map_color)
			draw_arc(p, 6.0, 0, TAU, 12, Color.BLACK, 1.5, true)
			if full_map:
				draw_string(font, p + Vector2(8, 5), it.map_label, HORIZONTAL_ALIGNMENT_LEFT, -1, UITheme.font_size(0.55), Color.WHITE)
		elif it.map_label != "" and full_map:
			draw_circle(p, 4.0, it.map_color)
	# objetivo rastreado
	if target != Vector3.INF:
		var tp := _to_map(target, center, r)
		var inside := tp.distance_to(c) < r - 8.0
		if not inside:
			tp = c + (tp - c).normalized() * (r - 10.0)
		draw_colored_polygon(RoundButton._star_pts(tp, 10.0, 4.5), UITheme.GOLD)
	# protagonista (seta)
	var pp := _to_map(player.global_position, center, r)
	var yaw := player.rotation.y
	var fwd := Vector2(-sin(yaw), -cos(yaw))
	var side := Vector2(fwd.y, -fwd.x)
	draw_colored_polygon(PackedVector2Array([pp + fwd * 11.0, pp - fwd * 7.0 + side * 7.0, pp - fwd * 3.0, pp - fwd * 7.0 - side * 7.0]), Color.WHITE)
	draw_arc(c, r, 0, TAU, 64, UITheme.GOLD, 3.0, true)
	if not full_map:
		draw_string(font, c + Vector2(-6, -r + 18), "N", HORIZONTAL_ALIGNMENT_LEFT, -1, UITheme.font_size(0.6), UITheme.GOLD)


func _draw_clipped_circle(p: Vector2, rad: float, col: Color, c: Vector2, r: float) -> void:
	if p.distance_to(c) - rad < r:
		draw_circle(p, rad, col)
