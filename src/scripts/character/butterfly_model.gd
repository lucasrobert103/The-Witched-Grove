class_name ButterflyModel
extends Node3D
## Borboleta-do-Éter: voa em laços preguiçosos ao redor de um ponto.

var center := Vector3.ZERO
var color := Color("#ff9fb2")
var _t := 0.0
var _wl: Node3D
var _wr: Node3D
var _speed := 1.0


func _ready() -> void:
	var m := Toon.mat(color, {"unshaded": true, "double_sided": true})
	_wl = MeshKit.pivot(self)
	_wr = MeshKit.pivot(self)
	MeshKit.part(_wl, MeshKit.sphere(0.06, 8, 4), m, Vector3(-0.055, 0, 0), Vector3.ZERO, Vector3(1.0, 0.1, 0.8), false)
	MeshKit.part(_wr, MeshKit.sphere(0.06, 8, 4), m, Vector3(0.055, 0, 0), Vector3.ZERO, Vector3(1.0, 0.1, 0.8), false)
	MeshKit.part(self, MeshKit.capsule(0.01, 0.07), Toon.mat(Color("#2a1d2e")), Vector3.ZERO, Vector3(90, 0, 0), Vector3.ONE, false)
	_t = randf() * 20.0
	_speed = randf_range(0.6, 1.2)


func _process(delta: float) -> void:
	_t += delta
	var f := sin(_t * 18.0) * 1.1
	_wl.rotation.z = f
	_wr.rotation.z = -f
	var a := _t * 0.5 * _speed
	var p := center + Vector3(sin(a) * 1.6 + sin(a * 2.3) * 0.5, 0.9 + sin(_t * 1.3) * 0.35, cos(a * 0.8) * 1.4)
	if p.distance_to(position) > 0.001:
		look_at(p, Vector3.UP)
	position = p
