class_name NimbusModel
extends Node3D
## Nimbus, o gato-mariposa familiar de Asterion: nuvem de pelo com asas de mariposa.

var _t := 0.0
var _wing_l: Node3D
var _wing_r: Node3D
var _tail: Node3D
var _body: Node3D
var _ears: Array[Node3D] = []
var flap_speed := 9.0


func _ready() -> void:
	var fur := Toon.mat(Color("#f4f1ff"), {"rim": 0.5, "outline": 0.01})
	var fur2 := Toon.mat(Color("#d9d2f2"), {"outline": 0.01})
	var dark := Toon.mat(Color("#2a1d3a"), {"unshaded": true})
	var white := Toon.mat(Color.WHITE, {"unshaded": true})
	var pink := Toon.mat(Color("#ffb3c8"), {"unshaded": true})
	_body = MeshKit.pivot(self)
	MeshKit.part(_body, MeshKit.sphere(0.16, 14, 10), fur, Vector3(0, 0, 0.05), Vector3.ZERO, Vector3(1.0, 0.9, 1.25))
	# tufos de nuvem
	for p in [Vector3(-0.1, 0.05, 0.12), Vector3(0.1, 0.05, 0.12), Vector3(0, 0.1, 0.0)]:
		MeshKit.part(_body, MeshKit.sphere(0.08, 10, 6), fur, p)
	var head := MeshKit.pivot(_body, Vector3(0, 0.1, -0.15))
	MeshKit.part(head, MeshKit.sphere(0.14, 14, 10), fur, Vector3.ZERO, Vector3.ZERO, Vector3(1.1, 0.95, 1.0))
	for sx in [-1.0, 1.0]:
		var ear := MeshKit.pivot(head, Vector3(sx * 0.08, 0.11, 0.0))
		MeshKit.part(ear, MeshKit.cylinder(0.0, 0.055, 0.1, 6), fur, Vector3(0, 0.04, 0), Vector3(0, 0, -sx * 15))
		MeshKit.part(ear, MeshKit.cylinder(0.0, 0.032, 0.06, 6), pink, Vector3(sx * -0.004, 0.035, -0.012), Vector3(0, 0, -sx * 15))
		_ears.append(ear)
		MeshKit.part(head, MeshKit.sphere(0.04, 10, 8), dark, Vector3(sx * 0.055, 0.01, -0.115), Vector3.ZERO, Vector3(0.8, 1.1, 0.5))
		MeshKit.part(head, MeshKit.sphere(0.013, 6, 4), white, Vector3(sx * 0.05, 0.03, -0.135))
		# antenas de mariposa
		MeshKit.part(head, MeshKit.capsule(0.006, 0.14), Toon.mat(Color("#c9b8f2")), Vector3(sx * 0.03, 0.17, -0.03), Vector3(-20, 0, -sx * 20))
		MeshKit.part(head, MeshKit.sphere(0.018, 6, 4), Toon.glow(Color("#fff3b0"), 1.5), Vector3(sx * 0.055, 0.24, -0.055))
	MeshKit.part(head, MeshKit.sphere(0.014, 6, 4), pink, Vector3(0, -0.03, -0.14))
	# asas
	var wing_m := Toon.mat(Color("#c8b4ff"), {"rim": 0.6, "double_sided": true})
	var spot_m := Toon.glow(Color("#fff3b0"), 0.8)
	_wing_l = MeshKit.pivot(_body, Vector3(-0.08, 0.1, 0.02))
	_wing_r = MeshKit.pivot(_body, Vector3(0.08, 0.1, 0.02))
	for w in [_wing_l, _wing_r]:
		var sx := -1.0 if w == _wing_l else 1.0
		MeshKit.part(w, MeshKit.sphere(0.16, 12, 6), wing_m, Vector3(sx * 0.15, 0.02, 0.0), Vector3.ZERO, Vector3(1.0, 0.12, 0.75))
		MeshKit.part(w, MeshKit.sphere(0.1, 10, 6), wing_m, Vector3(sx * 0.12, 0.0, 0.14), Vector3.ZERO, Vector3(1.0, 0.12, 0.8))
		MeshKit.part(w, MeshKit.sphere(0.035, 8, 4), spot_m, Vector3(sx * 0.18, 0.025, -0.02), Vector3.ZERO, Vector3(1.0, 0.3, 1.0))
	_tail = MeshKit.pivot(_body, Vector3(0, 0.02, 0.22))
	MeshKit.part(_tail, MeshKit.capsule(0.035, 0.22), fur2, Vector3(0, 0.08, 0.06), Vector3(-50, 0, 0))
	MeshKit.part(_tail, MeshKit.sphere(0.05, 8, 6), fur, Vector3(0, 0.16, 0.13))
	MeshKit.light(self, Color("#e8dcff"), 0.35, 2.0, Vector3(0, 0.2, 0))


func _process(delta: float) -> void:
	_t += delta
	var f := sin(_t * flap_speed)
	_wing_l.rotation.z = 0.25 + f * 0.6
	_wing_r.rotation.z = -0.25 - f * 0.6
	_body.position.y = sin(_t * 2.2) * 0.05
	_tail.rotation.y = sin(_t * 2.6) * 0.4
	for i in _ears.size():
		_ears[i].rotation.x = maxf(0.0, sin(_t * 0.7 + i * 2.0) - 0.9) * 3.0
