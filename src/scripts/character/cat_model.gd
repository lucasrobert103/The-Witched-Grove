class_name CatModel
extends Node3D
## Metamorfose: Asterion vira um gatinho preto de chapéu de bruxa.

var move_amount: float = 0.0
var _t := 0.0
var _body: Node3D
var _tail: Node3D
var _legs: Array[Node3D] = []


func _ready() -> void:
	var fur := Toon.mat(Color("#2a2433"), {"rim": 0.6, "outline": 0.01})
	var eye := Toon.mat(Color("#f3c74f"), {"unshaded": true})
	var dark := Toon.mat(Color("#0a0610"), {"unshaded": true})
	_body = MeshKit.pivot(self, Vector3(0, 0.32, 0))
	MeshKit.part(_body, MeshKit.capsule(0.16, 0.55), fur, Vector3(0, 0, 0.05), Vector3(90, 0, 0))
	var head := MeshKit.pivot(_body, Vector3(0, 0.14, -0.3))
	MeshKit.part(head, MeshKit.sphere(0.16, 14, 10), fur)
	for sx in [-1.0, 1.0]:
		MeshKit.part(head, MeshKit.cylinder(0.0, 0.07, 0.13, 6), fur, Vector3(sx * 0.09, 0.15, 0.0), Vector3(0, 0, -sx * 15))
		MeshKit.part(head, MeshKit.sphere(0.045, 10, 8), eye, Vector3(sx * 0.065, 0.02, -0.13), Vector3.ZERO, Vector3(0.9, 1.1, 0.5))
		MeshKit.part(head, MeshKit.sphere(0.02, 8, 6), dark, Vector3(sx * 0.065, 0.02, -0.15), Vector3.ZERO, Vector3(0.5, 1.2, 0.5))
	var hat := MeshKit.pivot(head, Vector3(0, 0.15, 0.02))
	hat.rotation_degrees = Vector3(-10, 0, 12)
	MeshKit.part(hat, MeshKit.cylinder(0.2, 0.2, 0.015, 18), Toon.mat(Color("#4a3626"), {"outline": 0.008}))
	MeshKit.part(hat, MeshKit.cylinder(0.0, 0.1, 0.26, 12), Toon.mat(Color("#4a3626"), {"outline": 0.008}), Vector3(0, 0.13, 0), Vector3(10, 0, 0))
	MeshKit.part(hat, MeshKit.cylinder(0.1, 0.105, 0.035, 12), Toon.mat(Color("#d98a2b")), Vector3(0, 0.025, 0))
	for p in [Vector3(-0.1, -0.12, -0.25), Vector3(0.1, -0.12, -0.25), Vector3(-0.1, -0.12, 0.3), Vector3(0.1, -0.12, 0.3)]:
		var leg := MeshKit.pivot(_body, p)
		MeshKit.part(leg, MeshKit.capsule(0.045, 0.22), fur, Vector3(0, -0.08, 0))
		_legs.append(leg)
	_tail = MeshKit.pivot(_body, Vector3(0, 0.05, 0.38))
	MeshKit.part(_tail, MeshKit.capsule(0.035, 0.45), fur, Vector3(0, 0.2, 0.05), Vector3(-25, 0, 0))


func _process(delta: float) -> void:
	_t += delta
	var ph := _t * (6.0 + 10.0 * move_amount)
	for i in _legs.size():
		_legs[i].rotation.x = sin(ph + (PI if i % 2 == 0 else 0.0) + (PI * 0.5 if i >= 2 else 0.0)) * 0.6 * move_amount
	_body.position.y = 0.32 + absf(sin(ph)) * 0.03 * move_amount
	_tail.rotation.z = sin(_t * 3.0) * 0.4
