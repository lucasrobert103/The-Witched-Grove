class_name MushroomModel
extends Node3D
## Cogumelo Resmungão: chapéu vermelho de bolinhas, sobrancelhas enormes, humor variável.

enum Mood { GRUMPY, CALM }
var mood: int = Mood.GRUMPY : set = set_mood
var _t := 0.0
var _cap: Node3D
var _brows: Array[MeshInstance3D] = []
var _eyes_open: Array[Node3D] = []
var _eyes_closed: Array[Node3D] = []
var _mouth_grumpy: MeshInstance3D
var _mouth_happy: MeshInstance3D
var _zzz: Node3D
var _spores: CPUParticles3D


func _ready() -> void:
	var stem := Toon.mat(Color("#f3e6cf"), {"rim": 0.3, "outline": 0.03})
	var cap := Toon.mat(Color("#d9442f"), {"rim": 0.4, "outline": 0.03})
	var dot := Toon.mat(Color("#fff6e6"))
	var dark := Toon.mat(Color("#2a1d2e"), {"unshaded": true})
	MeshKit.part(self, MeshKit.cylinder(0.75, 0.95, 1.6, 18), stem, Vector3(0, 0.8, 0))
	for sx in [-1.0, 1.0]:
		MeshKit.part(self, MeshKit.capsule(0.18, 0.6), stem, Vector3(sx * 0.95, 0.9, -0.1), Vector3(0, 0, sx * 50))
		MeshKit.part(self, MeshKit.capsule(0.22, 0.5), stem, Vector3(sx * 0.45, 0.15, -0.2), Vector3(90, 0, 0))
	_cap = MeshKit.pivot(self, Vector3(0, 1.55, 0))
	MeshKit.part(_cap, MeshKit.sphere(1.45, 22, 12, true), cap, Vector3.ZERO, Vector3.ZERO, Vector3(1.0, 0.75, 1.0))
	MeshKit.part(_cap, MeshKit.cylinder(1.35, 1.45, 0.15, 22), Toon.mat(Color("#f0d9c0"), {"outline": 0.02}), Vector3(0, -0.05, 0))
	var rng := RandomNumberGenerator.new()
	rng.seed = 42
	for i in 11:
		var a := rng.randf_range(0, TAU)
		var el := rng.randf_range(0.25, 1.2)
		var p := Vector3(sin(a) * cos(el) * 1.45, sin(el) * 1.45 * 0.75, cos(a) * cos(el) * 1.45)
		var d := MeshKit.part(_cap, MeshKit.sphere(0.2, 10, 6), dot, p, Vector3.ZERO, Vector3(1.0, 0.45, 1.0))
		d.look_at_from_position(p, p * 2.0, Vector3.UP)
	# rosto
	var face := MeshKit.pivot(self, Vector3(0, 1.0, -0.8))
	for sx in [-1.0, 1.0]:
		var open := MeshKit.pivot(face, Vector3(sx * 0.28, 0.12, 0))
		MeshKit.part(open, MeshKit.sphere(0.13, 12, 8), Toon.mat(Color.WHITE, {"unshaded": true}), Vector3.ZERO, Vector3.ZERO, Vector3(1.0, 1.0, 0.5))
		MeshKit.part(open, MeshKit.sphere(0.07, 10, 6), dark, Vector3(0, -0.02, -0.05), Vector3.ZERO, Vector3(1.0, 1.0, 0.5))
		_eyes_open.append(open)
		var closed := MeshKit.pivot(face, Vector3(sx * 0.28, 0.1, -0.03))
		MeshKit.part(closed, MeshKit.torus(0.08, 0.11, 14, 4), dark, Vector3.ZERO, Vector3(90, 0, 0), Vector3(1.0, 1.0, 0.5))
		_eyes_closed.append(closed)
		var brow := MeshKit.part(face, MeshKit.capsule(0.05, 0.38), dark, Vector3(sx * 0.3, 0.33, -0.02), Vector3(0, 0, 90 + sx * 25))
		_brows.append(brow)
	_mouth_grumpy = MeshKit.part(face, MeshKit.torus(0.12, 0.16, 16, 4), dark, Vector3(0, -0.28, 0), Vector3(90, 0, 0), Vector3(1.0, 1.0, 0.6))
	_mouth_happy = MeshKit.part(face, MeshKit.sphere(0.13, 12, 8, true), Toon.mat(Color("#7a2a3a")), Vector3(0, -0.2, -0.02), Vector3(180, 0, 0), Vector3(1.2, 0.8, 0.4))
	_zzz = MeshKit.pivot(self, Vector3(0.9, 2.6, 0))
	for i in 3:
		MeshKit.part(_zzz, MeshKit.box(Vector3(0.18 - i * 0.04, 0.03, 0.03)), Toon.glow(Color("#c8b4ff"), 1.0), Vector3(i * 0.18, i * 0.3, 0), Vector3(0, 0, 0))
	_spores = CPUParticles3D.new()
	_spores.amount = 24
	_spores.lifetime = 2.0
	_spores.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	_spores.emission_sphere_radius = 1.4
	_spores.direction = Vector3.UP
	_spores.spread = 60.0
	_spores.initial_velocity_min = 0.3
	_spores.initial_velocity_max = 0.8
	_spores.gravity = Vector3(0, 0.1, 0)
	_spores.scale_amount_min = 0.06
	_spores.scale_amount_max = 0.12
	var sm := SphereMesh.new()
	sm.radius = 0.5
	sm.height = 1.0
	sm.radial_segments = 6
	sm.rings = 3
	sm.material = Toon.translucent(Color("#ffb070"), 0.7, 1.0)
	_spores.mesh = sm
	_spores.position = Vector3(0, 1.8, 0)
	add_child(_spores)
	set_mood(mood)


func set_mood(v: int) -> void:
	mood = v
	if _cap == null:
		return
	var grumpy := mood == Mood.GRUMPY
	for e in _eyes_open:
		e.visible = grumpy
	for e in _eyes_closed:
		e.visible = not grumpy
	_mouth_grumpy.visible = grumpy
	_mouth_happy.visible = not grumpy
	_zzz.visible = not grumpy
	_spores.emitting = grumpy
	for i in _brows.size():
		var sx := -1.0 if i == 0 else 1.0
		_brows[i].rotation_degrees.z = 90 + sx * (25 if grumpy else -10)


func _process(delta: float) -> void:
	_t += delta
	if mood == Mood.GRUMPY:
		_cap.position.y = 1.55 + absf(sin(_t * 3.0)) * 0.06
		rotation.z = sin(_t * 2.0) * 0.03
	else:
		_cap.position.y = 1.55 + sin(_t * 0.8) * 0.03
		rotation.z = 0.0
		_zzz.position.y = 2.6 + fmod(_t * 0.3, 0.4)
