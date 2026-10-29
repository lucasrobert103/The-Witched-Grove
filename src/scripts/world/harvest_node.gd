class_name HarvestNode
extends Interactable
## Planta, mineral ou água silvestre. Rebrota no dia seguinte (ou com Crescimento Rápido).

var node_id: String = ""
var ingredient_id: String = ""
var amount: int = 1
var shape: String = "rosette"
var _visual: Node3D
var _t := 0.0


func setup(p_id: String, p_ingredient: String, p_shape: String, p_amount: int = 1) -> void:
	node_id = p_id
	ingredient_id = p_ingredient
	shape = p_shape
	amount = p_amount
	radius = 1.8
	marker_height = 1.0


func _ready() -> void:
	_visual = MeshKit.pivot(self)
	var c := DataRegistry.item_color(ingredient_id)
	var leaf := Toon.mat(Color("#5fb85a"), {"rim": 0.4, "outline": 0.01})
	match shape:
		"rosette":
			for i in 6:
				var a := i * TAU / 6.0
				MeshKit.part(_visual, MeshKit.sphere(0.16, 8, 4), Toon.mat(c, {"rim": 0.5, "outline": 0.01}), Vector3(sin(a) * 0.17, 0.08, cos(a) * 0.17), Vector3(0, rad_to_deg(a), 25), Vector3(1.0, 0.25, 0.55))
			for i in 4:
				var a2 := i * 1.7
				MeshKit.part(_visual, MeshKit.sphere(0.03, 6, 4), Toon.glow(Color("#d9f6ff"), 1.5), Vector3(sin(a2) * 0.18, 0.14, cos(a2) * 0.18), Vector3.ZERO, Vector3.ONE, false)
		"flower":
			for i in 3:
				var p := Vector3((i - 1) * 0.16, 0, (i % 2) * 0.12)
				MeshKit.part(_visual, MeshKit.cylinder(0.012, 0.016, 0.42, 5), leaf, p + Vector3(0, 0.21, 0))
				var head := MeshKit.pivot(_visual, p + Vector3(0, 0.44, 0))
				for k in 5:
					var a := k * TAU / 5.0
					MeshKit.part(head, MeshKit.sphere(0.06, 8, 4), Toon.mat(c, {"emission": 0.4}), Vector3(sin(a) * 0.06, 0, cos(a) * 0.06), Vector3.ZERO, Vector3(1.0, 0.4, 1.0))
				MeshKit.part(head, MeshKit.sphere(0.035, 6, 4), Toon.glow(Color("#fff3b0"), 1.2), Vector3(0, 0.02, 0))
			MeshKit.part(_visual, MeshKit.sphere(0.14, 8, 4), leaf, Vector3(0, 0.05, 0), Vector3.ZERO, Vector3(1.6, 0.4, 1.2))
		"spikes":
			for i in 7:
				var a := i * TAU / 7.0
				var p := Vector3(sin(a) * 0.12, 0, cos(a) * 0.12)
				MeshKit.part(_visual, MeshKit.cylinder(0.01, 0.012, 0.4, 4), leaf, p + Vector3(0, 0.2, 0), Vector3(sin(a) * 10, 0, cos(a) * 10))
				MeshKit.part(_visual, MeshKit.capsule(0.035, 0.18), Toon.mat(c, {"rim": 0.4}), p * 1.25 + Vector3(0, 0.42, 0), Vector3(sin(a) * 10, 0, cos(a) * 10))
		"moss":
			MeshKit.part(_visual, MeshKit.rock(17, 0.45), Toon.mat(Color("#8a8f9a"), {"outline": 0.015}), Vector3(0, 0.15, 0))
			for i in 5:
				var a := i * 1.3
				MeshKit.part(_visual, MeshKit.sphere(0.14, 8, 5), Toon.mat(c, {"rim": 0.6}), Vector3(sin(a) * 0.2, 0.38, cos(a) * 0.18), Vector3.ZERO, Vector3(1.0, 0.45, 1.0))
		"mushroom":
			for i in 4:
				var p := Vector3(sin(i * 1.9) * 0.18, 0, cos(i * 1.9) * 0.16)
				var s := 0.7 + (i % 3) * 0.25
				MeshKit.part(_visual, MeshKit.cylinder(0.03 * s, 0.04 * s, 0.16 * s, 6), Toon.mat(Color("#f3e6cf")), p + Vector3(0, 0.08 * s, 0))
				MeshKit.part(_visual, MeshKit.sphere(0.09 * s, 8, 4, true), Toon.mat(c, {"emission": 0.5, "outline": 0.008}), p + Vector3(0, 0.15 * s, 0), Vector3.ZERO, Vector3(1.0, 0.7, 1.0))
		"bark":
			MeshKit.part(_visual, MeshKit.box(Vector3(0.35, 0.5, 0.08)), Toon.mat(c, {"outline": 0.01}), Vector3(0, 0.6, 0), Vector3(0, 0, 4))
		"spring":
			MeshKit.part(_visual, MeshKit.cylinder(0.5, 0.6, 0.3, 12), Toon.mat(Color("#9a9aa6"), {"outline": 0.02}), Vector3(0, 0.15, 0))
			MeshKit.part(_visual, MeshKit.cylinder(0.42, 0.42, 0.04, 12), Toon.mat(c, {"emission": 0.3, "alpha": 0.85}), Vector3(0, 0.3, 0))
		"stone":
			for i in 3:
				MeshKit.part(_visual, MeshKit.rock(31 + i, 0.14), Toon.mat(c, {"outline": 0.01}), Vector3((i - 1) * 0.2, 0.08, (i % 2) * 0.12))
		"crystal":
			for i in 3:
				MeshKit.part(_visual, MeshKit.crystal(0.08 + i * 0.03), Toon.glow(c, 1.4), Vector3((i - 1) * 0.12, 0.15 + i * 0.05, 0), Vector3(0, i * 30, (i - 1) * 18))
			MeshKit.light(_visual, c, 0.6, 2.5, Vector3(0, 0.4, 0))
		"clover":
			for i in 4:
				var a := i * TAU / 4.0 + 0.4
				MeshKit.part(_visual, MeshKit.sphere(0.07, 8, 4), Toon.mat(c, {"emission": 0.35}), Vector3(sin(a) * 0.08, 0.2, cos(a) * 0.08), Vector3.ZERO, Vector3(1.0, 0.3, 1.0))
			MeshKit.part(_visual, MeshKit.cylinder(0.01, 0.01, 0.2, 4), Toon.mat(Color("#2f8a4a")), Vector3(0, 0.1, 0))
			MeshKit.light(_visual, c, 0.3, 1.5, Vector3(0, 0.3, 0))
		"feather":
			MeshKit.part(_visual, MeshKit.capsule(0.05, 0.36), Toon.mat(c, {"rim": 0.6, "outline": 0.008}), Vector3(0, 0.08, 0), Vector3(80, 30, 0), Vector3(1.0, 1.0, 0.3))
	refresh_state()


func can_interact() -> bool:
	return visible and Game.is_wild_available(node_id)


func get_prompt() -> String:
	return "Colher %s" % DataRegistry.item_name(ingredient_id) if shape not in ["spring"] else "Coletar %s" % DataRegistry.item_name(ingredient_id)


func interact(_player: Node) -> void:
	var r := Game.harvest_wild(node_id, ingredient_id, amount)
	if r.ok:
		AudioManager.play_sfx("water" if shape == "spring" else "harvest")
		Settings.vibrate(20)
		refresh_state()
	else:
		say(r.reason, "warning")


func accepts_spells() -> bool:
	return visible


func on_spell(tags: Array, _result: Dictionary) -> bool:
	if "identify" in tags:
		Game.identify_ingredient(ingredient_id)
		return true
	if ("grow" in tags) and not Game.is_wild_available(node_id) and shape not in ["spring", "stone", "crystal"]:
		Game.wild_harvested.erase(node_id)
		refresh_state()
		return true
	return false


func refresh_state() -> void:
	if _visual == null:
		return
	var avail := Game.is_wild_available(node_id) or shape == "spring"
	_visual.scale = Vector3.ONE if avail else Vector3(0.6, 0.25, 0.6)


func _process(delta: float) -> void:
	_t += delta
	if _visual and shape in ["flower", "spikes", "clover"]:
		_visual.rotation.z = sin(_t * 1.4 + position.x) * 0.06
