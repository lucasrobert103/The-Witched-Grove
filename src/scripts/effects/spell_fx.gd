class_name SpellFX
extends RefCounted
## Efeitos visuais dos feitiços: explosões de partículas, anéis e flashes de luz.
## Tudo é criado sob demanda e se autodestrói.

const SCHOOL_COLORS := {
	"botany": Color("#7dffa0"), "alchemy": Color("#ffc85a"), "astral": Color("#a8b4ff"),
	"runes": Color("#d6b8ff"), "protection": Color("#9ff0ff"), "transmutation": Color("#ff9fd6"),
	"illusion": Color("#c8a2ff"), "elemental": Color("#ff9a5c"),
}


static func burst(parent: Node, pos: Vector3, color: Color, amount: int = 28, spread: float = 1.0, upward: float = 2.0, size: float = 0.09, life: float = 0.9) -> void:
	var p := CPUParticles3D.new()
	p.one_shot = true
	p.explosiveness = 0.85
	p.amount = amount
	p.lifetime = life
	p.direction = Vector3.UP
	p.spread = 180.0
	p.initial_velocity_min = upward * 0.4
	p.initial_velocity_max = upward
	p.gravity = Vector3(0, -1.0, 0)
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	p.emission_sphere_radius = 0.3 * spread
	p.scale_amount_min = size * 0.6
	p.scale_amount_max = size * 1.4
	var curve := Curve.new()
	curve.add_point(Vector2(0, 1))
	curve.add_point(Vector2(1, 0))
	p.scale_amount_curve = curve
	var m := SphereMesh.new()
	m.radius = 0.5
	m.height = 1.0
	m.radial_segments = 6
	m.rings = 3
	m.material = Toon.glow(color, 3.0)
	p.mesh = m
	parent.add_child(p)
	p.global_position = pos
	p.emitting = true
	_auto_free(p, life + 0.5)


static func ring(parent: Node, pos: Vector3, color: Color, radius: float = 3.0, duration: float = 0.6) -> void:
	var mi := MeshInstance3D.new()
	mi.mesh = MeshKit.torus(0.9, 1.0, 32, 4)
	var mat := Toon.translucent(color, 0.8, 2.0).duplicate()
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mi)
	mi.global_position = pos + Vector3(0, 0.15, 0)
	mi.scale = Vector3.ONE * 0.2
	var tw := mi.create_tween().set_parallel(true)
	tw.tween_property(mi, "scale", Vector3(radius, 1.0, radius), duration).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	tw.tween_property(mat, "albedo_color:a", 0.0, duration)
	tw.chain().tween_callback(mi.queue_free)


static func flash(parent: Node, pos: Vector3, color: Color, energy: float = 4.0, light_range: float = 6.0, duration: float = 0.5) -> void:
	var l := OmniLight3D.new()
	l.light_color = color
	l.light_energy = energy
	l.omni_range = light_range
	parent.add_child(l)
	l.global_position = pos + Vector3(0, 1.0, 0)
	var tw := l.create_tween()
	tw.tween_property(l, "light_energy", 0.0, duration)
	tw.tween_callback(l.queue_free)


static func for_spell(parent: Node, caster_pos: Vector3, spell_id: String, result: Dictionary) -> void:
	var school: String = result.get("school", "botany")
	var c: Color = SCHOOL_COLORS.get(school, Color.WHITE)
	var tags: Array = result.get("tags", [])
	var r := float(result.get("radius", 3.0))
	flash(parent, caster_pos, c)
	burst(parent, caster_pos + Vector3(0, 1.6, 0), c, 24, 0.6, 2.0)
	if "fire" in tags:
		burst(parent, caster_pos + Vector3(0, 0.5, 0), Color("#7fd6ff"), 40, r * 0.6, 3.5, 0.14, 1.2)
	if "grow" in tags or "nature_sync" in tags:
		burst(parent, caster_pos, Color("#7dffa0"), 40, r * 0.7, 2.5, 0.1, 1.4)
	if "ice" in tags:
		burst(parent, caster_pos, Color("#d9f2ff"), 40, r * 0.7, 1.5, 0.12, 1.4)
	if "wind" in tags:
		burst(parent, caster_pos + Vector3(0, 1, 0), Color("#f2f5ff"), 30, r * 0.5, 4.0, 0.06, 1.0)
	if "purify" in tags:
		burst(parent, caster_pos + Vector3(0, 1, 0), Color("#fffbe0"), 50, r * 0.6, 3.0, 0.1, 1.5)
	if school in ["botany", "elemental", "protection", "runes"] or "purify" in tags:
		ring(parent, caster_pos, c, r)
	if spell_id.begins_with("item:"):
		ring(parent, caster_pos, Color("#5cff9a"), r)


static func _auto_free(n: Node, t: float) -> void:
	var timer := n.get_tree().create_timer(t)
	timer.timeout.connect(n.queue_free)
