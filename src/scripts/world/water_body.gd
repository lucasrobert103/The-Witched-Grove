class_name WaterBody
extends Node3D
## Superfície de água (lagoa ou riacho) que pode ser congelada com Cristal de Gelo.
## Congelada, ganha um piso de gelo caminhável.

var water_id: String = ""
var level: float = 0.0
var frozen_time: float = 0.0
var _mat: ShaderMaterial
var _ice_body: StaticBody3D
var _shapes: Array[CollisionShape3D] = []
var _area_points: Array = []     # pontos de referência para alcance do feitiço


func setup(p_id: String, p_level: float) -> void:
	water_id = p_id
	level = p_level
	add_to_group("water")
	_mat = Toon.water()
	_ice_body = StaticBody3D.new()
	add_child(_ice_body)


func add_disc(center: Vector3, r: float) -> void:
	var mi := MeshInstance3D.new()
	var m := CylinderMesh.new()
	m.top_radius = r
	m.bottom_radius = r
	m.height = 0.05
	m.radial_segments = 32
	mi.mesh = m
	mi.material_override = _mat
	mi.position = Vector3(center.x, level, center.z)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)
	var cs := CollisionShape3D.new()
	var shape := CylinderShape3D.new()
	shape.radius = r
	shape.height = 0.3
	cs.shape = shape
	cs.position = Vector3(center.x, level - 0.1, center.z)
	cs.disabled = true
	_ice_body.add_child(cs)
	_shapes.append(cs)
	_area_points.append(Vector3(center.x, level, center.z))


func add_segment(a: Vector3, b: Vector3, width: float) -> void:
	var mid := (a + b) * 0.5
	var d := b - a
	d.y = 0.0
	var mi := MeshInstance3D.new()
	var m := BoxMesh.new()
	m.size = Vector3(width, 0.05, d.length() + width * 0.5)
	mi.mesh = m
	mi.material_override = _mat
	mi.position = Vector3(mid.x, level, mid.z)
	mi.rotation.y = atan2(d.x, d.z)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)
	var cs := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(width + 1.0, 0.3, d.length() + width * 0.5)
	cs.shape = shape
	cs.position = Vector3(mid.x, level - 0.1, mid.z)
	cs.rotation.y = mi.rotation.y
	cs.disabled = true
	_ice_body.add_child(cs)
	_shapes.append(cs)
	_area_points.append(Vector3(mid.x, level, mid.z))


func distance_to(p: Vector3) -> float:
	var best := INF
	for q in _area_points:
		best = minf(best, Vector2(p.x - q.x, p.z - q.z).length())
	return best


func freeze(duration: float) -> void:
	frozen_time = maxf(frozen_time, duration)
	_set_frozen(true)


func is_frozen() -> bool:
	return frozen_time > 0.0


func _set_frozen(v: bool) -> void:
	_mat.set_shader_parameter("frozen", 1.0 if v else 0.0)
	for cs in _shapes:
		cs.disabled = not v


func _process(delta: float) -> void:
	if frozen_time > 0.0:
		frozen_time -= delta
		if frozen_time <= 3.0:
			_mat.set_shader_parameter("frozen", clampf(frozen_time / 3.0, 0.0, 1.0))
		if frozen_time <= 0.0:
			_set_frozen(false)
			EventBus.notify.emit("O gelo derrete com um suspiro.", "info")
