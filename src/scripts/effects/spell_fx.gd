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


## Projétil mágico em arco, com rastro de partículas. on_hit recebe o ponto atingido.
static func projectile(parent: Node, from: Vector3, to: Vector3, color: Color, on_hit: Callable) -> void:
	var orb := Node3D.new()
	parent.add_child(orb)
	orb.global_position = from
	MeshKit.part(orb, MeshKit.sphere(0.13, 12, 8), Toon.glow(color.lightened(0.4), 4.0), Vector3.ZERO, Vector3.ZERO, Vector3.ONE, false)
	MeshKit.part(orb, MeshKit.star(0.2, 0.08, 0.02), Toon.glow(color, 2.5), Vector3.ZERO, Vector3.ZERO, Vector3.ONE, false)
	var l := OmniLight3D.new()
	l.light_color = color
	l.light_energy = 2.0
	l.omni_range = 4.0
	orb.add_child(l)
	var trail := CPUParticles3D.new()
	trail.amount = 40
	trail.lifetime = 0.5
	trail.local_coords = false
	trail.direction = Vector3.UP
	trail.spread = 180.0
	trail.initial_velocity_min = 0.1
	trail.initial_velocity_max = 0.5
	trail.gravity = Vector3.ZERO
	trail.scale_amount_min = 0.05
	trail.scale_amount_max = 0.12
	var curve := Curve.new()
	curve.add_point(Vector2(0, 1))
	curve.add_point(Vector2(1, 0))
	trail.scale_amount_curve = curve
	var m := SphereMesh.new()
	m.radius = 0.5
	m.height = 1.0
	m.radial_segments = 6
	m.rings = 3
	m.material = Toon.glow(color, 3.0)
	trail.mesh = m
	orb.add_child(trail)
	var dist := from.distance_to(to)
	var dur := clampf(dist / 26.0, 0.12, 0.65)
	var arc := clampf(dist * 0.08, 0.1, 1.2)
	var tw := orb.create_tween()
	tw.tween_method(func(t: float): _move_orb(t, orb, from, to, arc), 0.0, 1.0, dur)
	tw.tween_callback(func(): _orb_hit(orb, trail, l, on_hit, to))
	tw.tween_interval(0.6)
	tw.tween_callback(orb.queue_free)


static func _move_orb(t: float, orb: Node3D, from: Vector3, to: Vector3, arc: float) -> void:
	orb.global_position = from.lerp(to, t) + Vector3(0, sin(t * PI) * arc, 0)
	orb.rotation.z = t * 12.0


static func _orb_hit(orb: Node3D, trail: CPUParticles3D, l: OmniLight3D, on_hit: Callable, to: Vector3) -> void:
	on_hit.call(to)
	trail.emitting = false
	orb.get_child(0).visible = false
	orb.get_child(1).visible = false
	l.visible = false


## Explosão de impacto: anel, faíscas e luz.
static func impact(parent: Node, pos: Vector3, color: Color, tags: Array) -> void:
	burst(parent, pos, color, 36, 0.8, 3.0, 0.1, 0.8)
	flash(parent, pos - Vector3(0, 0.5, 0), color, 4.0, 6.0, 0.4)
	ring(parent, pos - Vector3(0, 0.45, 0), color, 2.0, 0.45)
	if "fire" in tags:
		burst(parent, pos, Color("#7fd6ff"), 30, 0.8, 4.0, 0.16, 1.0)
	if "ice" in tags:
		burst(parent, pos, Color("#e6f7ff"), 30, 1.0, 1.0, 0.12, 1.4)
	if "transfigure" in tags:
		burst(parent, pos, Color("#ffd1f0"), 40, 1.2, 2.0, 0.08, 1.2)
	if "levitate" in tags:
		burst(parent, pos, Color("#fff3c4"), 20, 0.6, 1.0, 0.06, 1.5)


## Florescer: flores brotam do chão ao redor do ponto e somem depois de um tempo.
static func bloom(parent: Node, pos: Vector3, radius: float) -> void:
	var holder := Node3D.new()
	parent.add_child(holder)
	holder.global_position = pos - Vector3(0, 0.5, 0)
	var cols := [Color("#ff9fb2"), Color("#fff3a0"), Color("#c8a2ff"), Color("#ffffff"), Color("#8fd6ff")]
	var world := parent as Node
	for i in 14:
		var a := randf() * TAU
		var r := sqrt(randf()) * radius
		var p := Vector3(sin(a) * r, 0, cos(a) * r)
		if world.has_method("ground_height"):
			p.y = world.ground_height(holder.global_position.x + p.x, holder.global_position.z + p.z) - holder.global_position.y
		var f := MeshKit.pivot(holder, p)
		MeshKit.part(f, MeshKit.cylinder(0.012, 0.016, 0.3, 4), Toon.mat(Color("#4f9f55")), Vector3(0, 0.15, 0), Vector3.ZERO, Vector3.ONE, false)
		MeshKit.part(f, MeshKit.sphere(0.07, 8, 4), Toon.mat(cols[i % cols.size()], {"emission": 0.4}), Vector3(0, 0.32, 0), Vector3.ZERO, Vector3(1.0, 0.6, 1.0), false)
		f.scale = Vector3.ONE * 0.01
		var tw := f.create_tween()
		tw.tween_interval(randf() * 0.4)
		tw.tween_property(f, "scale", Vector3.ONE * randf_range(0.9, 1.5), 0.4).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	var tw2 := holder.create_tween()
	tw2.tween_interval(25.0)
	tw2.tween_property(holder, "scale", Vector3(1, 0.01, 1), 1.0)
	tw2.tween_callback(holder.queue_free)


static func _auto_free(n: Node, t: float) -> void:
	var timer := n.get_tree().create_timer(t)
	timer.timeout.connect(n.queue_free)
