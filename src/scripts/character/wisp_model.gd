class_name WispModel
extends Node3D
## Lumécula: espírito de luz com núcleo brilhante, halo e asinhas.

var color: Color = Color("#9fe8ff")
var blink_pattern: Array = []     # ex.: [1,1,0] = pisca-pisca-PAUSA (Faísca)
var brightness := 1.0
var _t := 0.0
var _core: MeshInstance3D
var _halo: MeshInstance3D
var _light: OmniLight3D
var _wings: Array[Node3D] = []
var _core_mat: StandardMaterial3D
var _halo_mat: StandardMaterial3D


func setup(c: Color, pattern: Array = []) -> void:
	color = c
	blink_pattern = pattern


func _ready() -> void:
	_core_mat = StandardMaterial3D.new()
	_core_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_core_mat.albedo_color = color.lightened(0.4)
	_core_mat.emission_enabled = true
	_core_mat.emission = color
	_core_mat.emission_energy_multiplier = 3.0
	_halo_mat = Toon.translucent(color, 0.25, 1.0).duplicate()
	_core = MeshKit.part(self, MeshKit.sphere(0.07, 10, 6), _core_mat, Vector3.ZERO, Vector3.ZERO, Vector3.ONE, false)
	_halo = MeshKit.part(self, MeshKit.sphere(0.16, 12, 8), _halo_mat, Vector3.ZERO, Vector3.ZERO, Vector3.ONE, false)
	var wing_m := Toon.translucent(Color.WHITE, 0.5, 1.0)
	for sx in [-1.0, 1.0]:
		var w := MeshKit.pivot(self, Vector3(sx * 0.05, 0.03, 0))
		MeshKit.part(w, MeshKit.sphere(0.06, 8, 4), wing_m, Vector3(sx * 0.06, 0, 0), Vector3.ZERO, Vector3(1.0, 0.15, 0.6), false)
		_wings.append(w)
	_light = MeshKit.light(self, color, 0.8, 3.0)
	_t = randf() * 10.0


func _process(delta: float) -> void:
	_t += delta
	var b := brightness
	if not blink_pattern.is_empty():
		var idx := int(_t * 3.0) % blink_pattern.size()
		b *= 1.0 if int(blink_pattern[idx]) == 1 else 0.25
	else:
		b *= 0.75 + 0.25 * sin(_t * 3.0)
	_core_mat.emission_energy_multiplier = 3.0 * b
	_light.light_energy = 0.8 * b
	_halo.scale = Vector3.ONE * (0.9 + 0.15 * sin(_t * 4.0))
	for i in _wings.size():
		_wings[i].rotation.z = (1.0 if i == 0 else -1.0) * sin(_t * 22.0) * 0.6
