class_name FrogModel
extends Node3D
## Sapo-Cristal: anfíbio translúcido com um cristal no peito.

var _t := 0.0
var _body: Node3D
var _hop_t := 0.0


func _ready() -> void:
	var skin := Toon.mat(Color("#5fd6b8"), {"rim": 0.6, "outline": 0.008})
	var belly := Toon.mat(Color("#c9fff0"))
	_body = MeshKit.pivot(self)
	MeshKit.part(_body, MeshKit.sphere(0.13, 12, 8), skin, Vector3(0, 0.1, 0), Vector3.ZERO, Vector3(1.0, 0.75, 1.15))
	MeshKit.part(_body, MeshKit.sphere(0.1, 10, 6), belly, Vector3(0, 0.07, -0.04), Vector3.ZERO, Vector3(1.0, 0.6, 1.0))
	MeshKit.part(_body, MeshKit.crystal(0.035), Toon.glow(Color("#d9e6ff"), 2.5), Vector3(0, 0.1, -0.13))
	for sx in [-1.0, 1.0]:
		MeshKit.part(_body, MeshKit.sphere(0.05, 10, 6), skin, Vector3(sx * 0.07, 0.19, -0.07))
		MeshKit.part(_body, MeshKit.sphere(0.028, 8, 6), Toon.mat(Color("#1a1420"), {"unshaded": true}), Vector3(sx * 0.075, 0.2, -0.105))
		MeshKit.part(_body, MeshKit.capsule(0.03, 0.14), skin, Vector3(sx * 0.12, 0.04, 0.06), Vector3(70, 0, sx * 20))
	_t = randf() * 5.0


func _process(delta: float) -> void:
	_t += delta
	_body.scale.y = 1.0 + sin(_t * 5.0) * 0.04
	_hop_t -= delta
	if _hop_t <= 0.0:
		_hop_t = randf_range(2.0, 5.0)
	_body.position.y = maxf(0.0, sin(clampf(1.0 - _hop_t * 3.0, 0.0, 1.0) * PI)) * 0.12
