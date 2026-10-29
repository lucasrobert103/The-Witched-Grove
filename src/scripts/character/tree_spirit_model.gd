class_name TreeSpiritModel
extends Node3D
## Guardião Musgo: árvore ancestral com rosto. Estados: cinza, curado, violeta.

enum State { GREY, HEALED, VIOLET }
var state: int = State.GREY : set = set_state
var _t := 0.0
var _canopy: Array[MeshInstance3D] = []
var _bark: Array[MeshInstance3D] = []
var _moss: Array[MeshInstance3D] = []
var _eyes: Array[MeshInstance3D] = []
var _eye_light: OmniLight3D
var _crown: Node3D
var _eye_mat: StandardMaterial3D


func _ready() -> void:
	var bark := Toon.mat(Color("#6b4a32"), {"rim": 0.2, "outline": 0.04})
	_bark.append(MeshKit.part(self, MeshKit.cylinder(1.0, 1.7, 6.5, 16), bark, Vector3(0, 3.25, 0)))
	for i in 6:
		var a := i * TAU / 6.0 + 0.3
		_bark.append(MeshKit.part(self, MeshKit.cylinder(0.25, 0.55, 2.6, 8), bark, Vector3(sin(a) * 1.7, 0.45, cos(a) * 1.7), Vector3(0, rad_to_deg(a), 0) + Vector3(0, 0, 0)))
		_bark[-1].rotation = Vector3(cos(a) * 1.15, 0, -sin(a) * 1.15)
	for b in [Vector3(-1.4, 5.6, 0.2), Vector3(1.5, 5.9, -0.2), Vector3(0.2, 6.2, 1.2)]:
		_bark.append(MeshKit.part(self, MeshKit.cylinder(0.25, 0.5, 2.4, 8), bark, b, Vector3(b.z * 25, 0, -b.x * 22)))
	_crown = MeshKit.pivot(self, Vector3(0, 7.5, 0))
	var leaf := Toon.mat(Color("#4fae5a"), {"rim": 0.4, "outline": 0.05})
	for p in [Vector3(0, 0.6, 0), Vector3(-2.2, 0, 0.3), Vector3(2.3, -0.2, -0.3), Vector3(0.3, -0.3, 2.0), Vector3(-0.5, 0.0, -2.1), Vector3(0, 1.8, 0.2), Vector3(1.4, 1.0, 1.3), Vector3(-1.5, 1.1, -1.2)]:
		_canopy.append(MeshKit.part(_crown, MeshKit.sphere(2.0, 14, 8), leaf, p, Vector3.ZERO, Vector3(1.0, 0.85, 1.0)))
	var moss := Toon.mat(Color("#7fcf6a"))
	for p in [Vector3(0.9, 1.4, -0.9), Vector3(-1.0, 2.6, -0.6), Vector3(0.7, 4.1, -0.8), Vector3(-1.2, 0.6, 0.9)]:
		_moss.append(MeshKit.part(self, MeshKit.sphere(0.45, 10, 6), moss, p, Vector3.ZERO, Vector3(1.0, 0.5, 0.7)))
	# rosto (frente = -Z)
	_eye_mat = StandardMaterial3D.new()
	_eye_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_eye_mat.emission_enabled = true
	for sx in [-1.0, 1.0]:
		var hollow := MeshKit.part(self, MeshKit.sphere(0.32, 12, 8), Toon.mat(Color("#2a1a12")), Vector3(sx * 0.48, 3.6, -1.28), Vector3.ZERO, Vector3(1.0, 1.25, 0.5))
		hollow.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_eyes.append(MeshKit.part(self, MeshKit.sphere(0.17, 10, 8), _eye_mat, Vector3(sx * 0.48, 3.58, -1.4), Vector3.ZERO, Vector3(1.0, 1.2, 0.5)))
		MeshKit.part(self, MeshKit.capsule(0.07, 0.6), bark, Vector3(sx * 0.48, 4.05, -1.3), Vector3(0, 0, 90 + sx * 12))
	MeshKit.part(self, MeshKit.sphere(0.35, 12, 8), Toon.mat(Color("#2a1a12")), Vector3(0, 2.75, -1.36), Vector3.ZERO, Vector3(1.4, 0.55, 0.5))
	MeshKit.part(self, MeshKit.sphere(0.2, 10, 6), bark, Vector3(0, 3.2, -1.45), Vector3.ZERO, Vector3(0.9, 1.3, 0.8))
	_eye_light = MeshKit.light(self, Color("#9effc7"), 1.5, 6.0, Vector3(0, 3.6, -2.0))
	set_state(state)


func set_state(v: int) -> void:
	state = v
	if _crown == null:
		return
	var leaf_c := Color("#4fae5a")
	var bark_c := Color("#6b4a32")
	var moss_c := Color("#7fcf6a")
	var eye_c := Color("#9effc7")
	var eye_on := 1.0
	match state:
		State.GREY:
			leaf_c = Color("#8d8f8a")
			bark_c = Color("#6e6a66")
			moss_c = Color("#9a9c96")
			eye_c = Color("#5a5a5a")
			eye_on = 0.0
		State.VIOLET:
			leaf_c = Color("#5a4a7a")
			moss_c = Color("#7a5aa0")
			eye_c = Color("#b06bff")
	for c in _canopy:
		c.material_override = Toon.mat(leaf_c, {"rim": 0.4, "outline": 0.05})
	for b in _bark:
		b.material_override = Toon.mat(bark_c, {"rim": 0.2, "outline": 0.04})
	for m in _moss:
		m.material_override = Toon.mat(moss_c)
	_eye_mat.albedo_color = eye_c
	_eye_mat.emission = eye_c
	_eye_mat.emission_energy_multiplier = 2.5 * eye_on
	_eye_light.light_color = eye_c
	_eye_light.visible = eye_on > 0.0
	for e in _eyes:
		e.scale = Vector3(1.0, 1.2 if eye_on > 0.0 else 0.15, 0.5)


func _process(delta: float) -> void:
	_t += delta
	_crown.rotation.z = sin(_t * 0.5) * (0.004 if state == State.GREY else 0.015)
	if state != State.GREY:
		_eye_light.light_energy = 1.4 + sin(_t * 1.5) * 0.3
