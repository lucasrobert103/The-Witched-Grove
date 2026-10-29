class_name ItemIcon
extends Control
## Ícone desenhado de um item (frasco, folha, flor, cogumelo, cristal, semente, ferramenta...).
## Sem texturas externas: cada forma é desenhada com primitivas 2D na cor do item.

var item_id: String = "" : set = set_item
var count: int = 0
var quality: float = -1.0
var show_frame: bool = true
var selected: bool = false


func set_item(v: String) -> void:
	item_id = v
	queue_redraw()


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	custom_minimum_size = Vector2(72, 72)


func _shape() -> String:
	var it: Dictionary = DataRegistry.items.get(item_id, {})
	var cat: String = it.get("category", "")
	match cat:
		"pocao":
			return "bread" if item_id == "pao_mel" else "potion"
		"semente":
			return "seed"
		"ferramenta":
			return item_id
		"artefato":
			return "jar" if item_id == "lanterna_faisca" else "pouch"
	var by_id := {
		"folha_orvalho": "leaf", "petala_claridade": "flower", "agua_manancial": "drop", "raiz_concentracao": "root",
		"musgo_lunar": "moss", "cogumelo_brasa": "mushroom", "mel_silvestre": "honey", "lavanda_sonolenta": "spikes",
		"tinta_lula": "ink", "cristal_lunar": "crystal", "pedra_comum": "stone", "po_estrela": "sparkle",
		"espinho_sarca": "thorn", "flor_aurora": "flower", "trevo_quatro": "clover", "casca_salgueiro": "bark",
		"pena_coruja": "feather", "essencia_luz": "orb", "resina_ambar": "drop", "orquidea_sombra": "flower",
		"pimenta_dragao": "pepper", "flocos_neve": "snow", "cinza_vulcanica": "ash", "lagrima_guardiao": "orb",
	}
	return by_id.get(item_id, "orb")


func _draw() -> void:
	var s := minf(size.x, size.y)
	var c := Vector2(size.x * 0.5, size.y * 0.5)
	if show_frame:
		var bg := UITheme.box(Color(0.22, 0.15, 0.1, 0.55) if not selected else Color(0.45, 0.3, 0.12, 0.8), UITheme.GOLD if selected else Color(0.55, 0.42, 0.28, 0.9), 12, 2, 0)
		draw_style_box(bg, Rect2(Vector2.ZERO, size))
	if item_id == "":
		return
	var col := DataRegistry.item_color(item_id)
	var r := s * 0.32
	_draw_shape(_shape(), c, r, col)
	var font := get_theme_default_font()
	if count > 1:
		var txt := "×%d" % count
		var fs := int(s * 0.22)
		var w := font.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		var p := Vector2(size.x - w - 5, size.y - 6)
		draw_string_outline(font, p, txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, 5, Color(0, 0, 0, 0.9))
		draw_string(font, p, txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color.WHITE)
	if quality >= 1.15:
		draw_colored_polygon(RoundButton._star_pts(Vector2(10, 10), 7.0, 3.0), UITheme.GOLD)
	elif quality >= 0.9:
		draw_colored_polygon(RoundButton._star_pts(Vector2(10, 10), 6.0, 2.6), Color("#c9d3e8"))


func _draw_shape(sh: String, c: Vector2, r: float, col: Color) -> void:
	var dark := col.darkened(0.45)
	var light := col.lightened(0.35)
	var ink := Color("#2a1d18")
	match sh:
		"potion":
			draw_rect(Rect2(c + Vector2(-r * 0.22, -r * 1.05), Vector2(r * 0.44, r * 0.45)), Color("#d8eef0", 0.9))
			draw_rect(Rect2(c + Vector2(-r * 0.3, -r * 1.2), Vector2(r * 0.6, r * 0.2)), Color("#8a5a36"))
			draw_circle(c + Vector2(0, r * 0.15), r * 0.82, Color("#d8eef0", 0.85))
			draw_circle(c + Vector2(0, r * 0.25), r * 0.7, col)
			draw_rect(Rect2(c + Vector2(-r * 0.7, -r * 0.05), Vector2(r * 1.4, r * 0.18)), col.lightened(0.2))
			draw_circle(c + Vector2(-r * 0.3, -r * 0.05), r * 0.16, Color(1, 1, 1, 0.7))
			draw_arc(c + Vector2(0, r * 0.15), r * 0.82, 0, TAU, 32, ink, 2.0, true)
		"leaf":
			var pts := PackedVector2Array()
			for i in 21:
				var t := float(i) / 20.0
				var a := lerpf(-PI * 0.5, PI * 1.5, t)
				var rr := r * (0.55 + 0.45 * absf(sin(a)))
				pts.append(c + Vector2(cos(a) * rr * 0.6, sin(a) * rr))
			draw_colored_polygon(pts, col)
			draw_line(c + Vector2(0, -r * 0.9), c + Vector2(0, r * 1.0), dark, 2.0)
			for k in 3:
				draw_line(c + Vector2(0, -r * 0.3 + k * r * 0.4), c + Vector2(r * 0.4, -r * 0.6 + k * r * 0.4), dark, 1.5)
			draw_circle(c + Vector2(r * 0.2, -r * 0.3), r * 0.1, Color("#d9f6ff"))
		"flower":
			for k in 6:
				var a := k * TAU / 6.0
				draw_circle(c + Vector2(cos(a), sin(a)) * r * 0.55, r * 0.42, col)
			draw_circle(c, r * 0.35, Color("#fff3a0") if col.v < 0.9 else Color("#f3a83a"))
		"drop":
			var pts2 := PackedVector2Array([c + Vector2(0, -r * 1.1)])
			for i in 17:
				var a := lerpf(-0.15, PI + 0.15, float(i) / 16.0)
				pts2.append(c + Vector2(cos(a) * r * 0.75, r * 0.25 + sin(a) * r * 0.75))
			draw_colored_polygon(pts2, col)
			draw_circle(c + Vector2(-r * 0.25, r * 0.15), r * 0.15, Color(1, 1, 1, 0.7))
		"root":
			draw_line(c + Vector2(0, -r), c + Vector2(r * 0.2, r), col, r * 0.35)
			draw_line(c + Vector2(r * 0.1, 0), c + Vector2(-r * 0.6, r * 0.7), col, r * 0.2)
			draw_line(c + Vector2(r * 0.15, r * 0.3), c + Vector2(r * 0.7, r * 0.8), col, r * 0.18)
			draw_circle(c + Vector2(0, -r * 0.9), r * 0.35, Color("#5fb85a"))
		"moss":
			for k in 5:
				draw_circle(c + Vector2(cos(k * 1.3) * r * 0.5, sin(k * 1.3) * r * 0.35), r * 0.45, col.lerp(dark, 0.15 * (k % 2)))
		"mushroom":
			draw_rect(Rect2(c + Vector2(-r * 0.2, -r * 0.1), Vector2(r * 0.4, r * 0.95)), Color("#f3e6cf"))
			var cap := PackedVector2Array()
			for i in 17:
				var a := PI + PI * float(i) / 16.0
				cap.append(c + Vector2(cos(a) * r, sin(a) * r * 0.8))
			draw_colored_polygon(cap, col)
			draw_circle(c + Vector2(-r * 0.4, -r * 0.4), r * 0.12, Color.WHITE)
			draw_circle(c + Vector2(r * 0.3, -r * 0.55), r * 0.1, Color.WHITE)
		"honey":
			draw_rect(Rect2(c + Vector2(-r * 0.7, -r * 0.6), Vector2(r * 1.4, r * 1.5)), Color("#d8eef0", 0.8))
			draw_rect(Rect2(c + Vector2(-r * 0.65, -r * 0.2), Vector2(r * 1.3, r * 1.05)), col)
			draw_rect(Rect2(c + Vector2(-r * 0.8, -r * 0.85), Vector2(r * 1.6, r * 0.3)), Color("#c4673a"))
			draw_rect(Rect2(c + Vector2(-r * 0.4, r * 0.1), Vector2(r * 0.8, r * 0.4)), Color("#fff3e0"))
		"spikes":
			for k in 3:
				var x := (k - 1) * r * 0.5
				draw_line(c + Vector2(x, r), c + Vector2(x * 1.3, -r * 0.2), Color("#5fb85a"), 2.5)
				for j in 4:
					draw_circle(c + Vector2(x * 1.3 + (j % 2 - 0.5) * r * 0.15, -r * 0.3 - j * r * 0.22), r * 0.15, col)
		"ink":
			draw_rect(Rect2(c + Vector2(-r * 0.6, -r * 0.4), Vector2(r * 1.2, r * 1.3)), col)
			draw_rect(Rect2(c + Vector2(-r * 0.3, -r * 0.8), Vector2(r * 0.6, r * 0.45)), col.lightened(0.2))
			draw_line(c + Vector2(r * 0.1, -r * 1.2), c + Vector2(r * 0.9, -r * 0.2), Color("#f2f5ff"), 3.0)
		"crystal":
			var pts3 := PackedVector2Array([c + Vector2(0, -r * 1.15), c + Vector2(r * 0.6, -r * 0.2), c + Vector2(r * 0.35, r), c + Vector2(-r * 0.35, r), c + Vector2(-r * 0.6, -r * 0.2)])
			draw_colored_polygon(pts3, col)
			draw_colored_polygon(PackedVector2Array([c + Vector2(0, -r * 1.15), c + Vector2(r * 0.6, -r * 0.2), c + Vector2(0, -r * 0.1)]), light)
			draw_polyline(PackedVector2Array(Array(pts3) + [pts3[0]]), dark, 1.5, true)
		"stone":
			draw_circle(c + Vector2(-r * 0.3, r * 0.2), r * 0.55, col)
			draw_circle(c + Vector2(r * 0.35, r * 0.1), r * 0.45, col.darkened(0.1))
			draw_circle(c + Vector2(0, -r * 0.35), r * 0.4, col.lightened(0.1))
		"sparkle", "snow":
			draw_colored_polygon(RoundButton._star_pts(c, r, r * 0.35), col)
			draw_colored_polygon(RoundButton._star_pts(c + Vector2(r * 0.7, -r * 0.7), r * 0.35, r * 0.14), light)
			draw_colored_polygon(RoundButton._star_pts(c + Vector2(-r * 0.7, r * 0.6), r * 0.3, r * 0.12), light)
		"thorn":
			draw_line(c + Vector2(-r, r * 0.6), c + Vector2(r, -r * 0.6), col, 4.0)
			for k in 4:
				var p := c + Vector2(-r + k * r * 0.6, r * 0.6 - k * r * 0.4)
				draw_colored_polygon(PackedVector2Array([p, p + Vector2(-r * 0.15, -r * 0.4), p + Vector2(r * 0.15, -r * 0.1)]), col)
		"clover":
			for k in 4:
				var a := k * TAU / 4.0 + PI * 0.25
				draw_circle(c + Vector2(cos(a), sin(a)) * r * 0.42, r * 0.42, col)
			draw_line(c, c + Vector2(r * 0.3, r * 1.1), Color("#2f8a4a"), 3.0)
		"bark":
			draw_rect(Rect2(c - Vector2(r * 0.6, r), Vector2(r * 1.2, r * 2.0)), col)
			for k in 4:
				draw_line(c + Vector2(-r * 0.4 + k * r * 0.27, -r * 0.9), c + Vector2(-r * 0.45 + k * r * 0.27, r * 0.9), dark, 2.0)
		"feather":
			draw_line(c + Vector2(-r * 0.8, r * 0.9), c + Vector2(r * 0.7, -r * 0.9), Color("#9a96a8"), 2.0)
			var fp := PackedVector2Array()
			for i in 13:
				var t := float(i) / 12.0
				fp.append(c + Vector2(lerpf(-r * 0.5, r * 0.7, t), lerpf(r * 0.5, -r * 0.9, t)) + Vector2(-0.6, -0.8).normalized() * sin(t * PI) * r * 0.45)
			for i in range(12, -1, -1):
				var t2 := float(i) / 12.0
				fp.append(c + Vector2(lerpf(-r * 0.5, r * 0.7, t2), lerpf(r * 0.5, -r * 0.9, t2)) + Vector2(0.6, 0.8).normalized() * sin(t2 * PI) * r * 0.35)
			draw_colored_polygon(fp, col)
		"orb":
			draw_circle(c, r * 0.95, Color(col, 0.35))
			draw_circle(c, r * 0.7, col)
			draw_circle(c + Vector2(-r * 0.25, -r * 0.25), r * 0.22, Color(1, 1, 1, 0.8))
		"pepper":
			draw_circle(c + Vector2(0, -r * 0.1), r * 0.5, col)
			draw_colored_polygon(PackedVector2Array([c + Vector2(-r * 0.45, 0), c + Vector2(r * 0.45, 0), c + Vector2(r * 0.2, r * 1.0)]), col)
			draw_line(c + Vector2(0, -r * 0.5), c + Vector2(r * 0.25, -r * 1.0), Color("#4f8a3a"), 3.0)
		"ash":
			draw_circle(c + Vector2(0, r * 0.4), r * 0.8, col)
			draw_circle(c + Vector2(r * 0.2, r * 0.1), r * 0.5, col.lightened(0.1))
			draw_circle(c + Vector2(-r * 0.3, r * 0.3), r * 0.15, Color("#ff7a3c"))
		"seed":
			draw_circle(c + Vector2(0, r * 0.25), r * 0.8, Color("#c9a27a"))
			draw_rect(Rect2(c + Vector2(-r * 0.4, -r * 0.85), Vector2(r * 0.8, r * 0.45)), Color("#c9a27a"))
			draw_line(c + Vector2(-r * 0.5, -r * 0.4), c + Vector2(r * 0.5, -r * 0.4), Color("#7a4a2a"), 3.0)
			draw_circle(c + Vector2(0, r * 0.3), r * 0.32, col)
		"bread":
			draw_circle(c + Vector2(0, r * 0.1), r * 0.85, col)
			draw_circle(c + Vector2(0, r * 0.25), r * 0.8, col.darkened(0.15))
			for k in 3:
				draw_line(c + Vector2(-r * 0.4 + k * r * 0.4, -r * 0.3), c + Vector2(-r * 0.25 + k * r * 0.4, r * 0.05), Color("#fff3e0"), 2.5)
		"jar":
			draw_rect(Rect2(c + Vector2(-r * 0.6, -r * 0.7), Vector2(r * 1.2, r * 1.6)), Color("#d8eef0", 0.6))
			draw_circle(c + Vector2(0, r * 0.15), r * 0.4, Color("#ffd36b"))
			draw_circle(c + Vector2(0, r * 0.15), r * 0.7, Color("#ffd36b", 0.3))
			draw_rect(Rect2(c + Vector2(-r * 0.7, -r * 0.95), Vector2(r * 1.4, r * 0.28)), Color("#8a5a36"))
		"pouch":
			draw_circle(c + Vector2(0, r * 0.25), r * 0.8, col)
			draw_colored_polygon(PackedVector2Array([c + Vector2(-r * 0.4, -r * 0.4), c + Vector2(r * 0.4, -r * 0.4), c + Vector2(r * 0.2, -r * 0.9), c + Vector2(-r * 0.2, -r * 0.9)]), col)
			draw_line(c + Vector2(-r * 0.45, -r * 0.45), c + Vector2(r * 0.45, -r * 0.45), Color("#3a2a20"), 3.0)
		"tesoura_poda":
			draw_circle(c + Vector2(-r * 0.4, r * 0.5), r * 0.3, Color("#c4473a"))
			draw_circle(c + Vector2(r * 0.4, r * 0.5), r * 0.3, Color("#c4473a"))
			draw_line(c + Vector2(-r * 0.3, r * 0.3), c + Vector2(r * 0.3, -r), col, 4.0)
			draw_line(c + Vector2(r * 0.3, r * 0.3), c + Vector2(-r * 0.3, -r), col, 4.0)
		"regador_encantado":
			draw_rect(Rect2(c + Vector2(-r * 0.6, -r * 0.3), Vector2(r * 1.1, r * 1.1)), col)
			draw_line(c + Vector2(r * 0.4, 0), c + Vector2(r * 1.0, -r * 0.7), col, 5.0)
			draw_arc(c + Vector2(-r * 0.1, -r * 0.3), r * 0.5, PI, TAU, 16, col.darkened(0.2), 4.0)
		"amuleto_lua":
			draw_arc(c + Vector2(0, -r * 0.6), r * 0.4, PI, TAU, 16, Color("#c9a24a"), 2.0)
			draw_circle(c + Vector2(0, r * 0.2), r * 0.65, col)
			draw_circle(c + Vector2(r * 0.25, r * 0.05), r * 0.55, Color(0.22, 0.15, 0.1, 1.0))
		"lupa_sabia":
			draw_arc(c + Vector2(-r * 0.2, -r * 0.2), r * 0.6, 0, TAU, 24, col, 5.0)
			draw_circle(c + Vector2(-r * 0.2, -r * 0.2), r * 0.5, Color("#d8eef0", 0.5))
			draw_line(c + Vector2(r * 0.25, r * 0.25), c + Vector2(r, r), Color("#6b4630"), 6.0)
		_:
			draw_circle(c, r * 0.8, col)
