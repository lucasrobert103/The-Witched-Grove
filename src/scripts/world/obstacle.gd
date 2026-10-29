class_name Obstacle
extends Interactable
## Obstáculo resolvido com magia (ou alquimia): sarças (fogo) e ponte de vinhas (crescimento).

var obstacle_id: String = ""
var kind: String = "bramble"
var length: float = 5.0
var _visual: Node3D
var _body: StaticBody3D
var _bridge: Node3D
var _bridge_body: StaticBody3D
var _anim_t := -1.0


func setup(p_id: String, p_kind: String, p_length: float) -> void:
	obstacle_id = p_id
	kind = p_kind
	length = p_length
	radius = maxf(3.0, length * 0.6)
	marker_height = 2.2


func flag() -> String:
	return "obst." + obstacle_id


func is_solved() -> bool:
	return Game.has_flag(flag())


func _ready() -> void:
	_visual = MeshKit.pivot(self)
	if kind == "bramble":
		var thorn := Toon.mat(Color("#4a3a2e"), {"outline": 0.02})
		var leaf := Toon.mat(Color("#3f6b3a"), {"outline": 0.02})
		var rng := RandomNumberGenerator.new()
		rng.seed = hash(obstacle_id)
		for i in int(length * 4.0):
			var x := rng.randf_range(-length * 0.5, length * 0.5)
			var y := rng.randf_range(0.3, 2.0)
			MeshKit.part(_visual, MeshKit.torus(0.3, 0.38, 10, 4), thorn, Vector3(x, y, rng.randf_range(-0.4, 0.4)), Vector3(rng.randf_range(0, 180), rng.randf_range(0, 180), 0), Vector3.ONE * rng.randf_range(0.8, 1.6))
			if i % 3 == 0:
				MeshKit.part(_visual, MeshKit.sphere(0.25, 6, 4), leaf, Vector3(x, y + 0.2, rng.randf_range(-0.3, 0.3)))
			if i % 2 == 0:
				MeshKit.part(_visual, MeshKit.cylinder(0.0, 0.04, 0.22, 4), Toon.mat(Color("#2a1d18")), Vector3(x, y, rng.randf_range(-0.5, 0.5)), Vector3(rng.randf_range(0, 360), 0, rng.randf_range(0, 360)))
		_body = StaticBody3D.new()
		var cs := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size = Vector3(length, 3.0, 1.4)
		cs.shape = box
		cs.position = Vector3(0, 1.5, 0)
		_body.add_child(cs)
		add_child(_body)
	else:
		var vine := Toon.mat(Color("#6b8a4a"), {"outline": 0.015})
		for i in 6:
			MeshKit.part(_visual, MeshKit.torus(0.18, 0.26, 10, 4), vine, Vector3(-length * 0.5 - 0.6, 0.15, (i - 3) * 0.25), Vector3(90, i * 30, 0))
		MeshKit.part(_visual, MeshKit.sphere(0.35, 8, 6), Toon.mat(Color("#8a7a4a")), Vector3(-length * 0.5 - 0.6, 0.2, 0), Vector3.ZERO, Vector3(1.0, 0.5, 1.0))
		_bridge = MeshKit.pivot(self)
		var plank := Toon.mat(Color("#9a6a3e"), {"outline": 0.015})
		var green := Toon.mat(Color("#5fb85a"), {"rim": 0.4, "outline": 0.015})
		var n := int(length / 0.45)
		for i in n:
			var x := -length * 0.5 + i * 0.45 + 0.2
			var sag := -sin(float(i) / max(n - 1, 1) * PI) * 0.25
			MeshKit.part(_bridge, MeshKit.box(Vector3(0.38, 0.08, 1.8)), plank, Vector3(x, 0.3 + sag, 0), Vector3(0, (i % 3 - 1) * 3, 0))
		for side in [-1.0, 1.0]:
			for i in 8:
				var x := -length * 0.5 + i * length / 7.0
				var sag := -sin(float(i) / 7.0 * PI) * 0.25
				MeshKit.part(_bridge, MeshKit.sphere(0.16, 8, 4), green, Vector3(x, 0.95 + sag, side * 0.95))
				if i < 7:
					MeshKit.part(_bridge, MeshKit.cylinder(0.05, 0.05, length / 7.0 + 0.1, 6), Toon.mat(Color("#6b8a4a")), Vector3(x + length / 14.0, 0.9 + sag, side * 0.95), Vector3(0, 0, 90))
		_bridge_body = StaticBody3D.new()
		var cs2 := CollisionShape3D.new()
		var deck := BoxShape3D.new()
		deck.size = Vector3(length + 1.0, 0.4, 1.8)
		cs2.shape = deck
		cs2.position = Vector3(0, 0.1, 0)
		_bridge_body.add_child(cs2)
		_bridge.add_child(_bridge_body)
	refresh_state()


func can_interact() -> bool:
	return visible and not is_solved()


func get_prompt() -> String:
	return "Examinar as sarças" if kind == "bramble" else "Examinar a vinha adormecida"


func interact(_player: Node) -> void:
	if kind == "bramble":
		say("Sarças grossas e espinhentas fecham a passagem. Cortar levaria dias... Fogo resolveria — mas só um fogo paciente, que não queime o bosque.", "info")
	else:
		say("Uma vinha antiga dorme enrolada à margem. Dizem que ela já foi ponte. Talvez só precise de um empurrãozinho para crescer.", "info")


func on_spell(tags: Array, _result: Dictionary) -> bool:
	if is_solved():
		return false
	if kind == "bramble" and "fire" in tags:
		_solve("As sarças ardem em chamas azuis e pacientes... e somem. O caminho para o Bosque das Corujas está aberto!")
		Game.give_item("espinho_sarca", 3)
		return true
	if kind == "vine_bridge" and "grow" in tags:
		_solve("A vinha desperta, se estica e se trança sobre o riacho: uma ponte viva!")
		return true
	if kind == "bramble" and "grow" in tags:
		say("As sarças crescem ainda mais. Ops.", "warning")
		return true
	return false


func _solve(msg: String) -> void:
	Game.set_flag(flag())
	Game.add_school_xp("elemental" if kind == "bramble" else "botany", 4.0)
	Game.discover("mundo", obstacle_id, msg)
	AudioManager.play_sfx("spell_fire" if kind == "bramble" else "spell_grow")
	_anim_t = 0.0
	if _body:
		_body.queue_free()
		_body = null
	refresh_state()


func refresh_state() -> void:
	if _visual == null:
		return
	var solved := is_solved()
	if kind == "bramble":
		if solved and _anim_t < 0.0:
			_visual.visible = false
			if _body:
				_body.queue_free()
				_body = null
	else:
		_bridge.visible = solved
		_bridge_body.process_mode = Node.PROCESS_MODE_INHERIT if solved else Node.PROCESS_MODE_DISABLED
		for c in _bridge_body.get_children():
			c.disabled = not solved
		_visual.get_child(0).visible = true


func _process(delta: float) -> void:
	if _anim_t < 0.0:
		return
	_anim_t += delta
	if kind == "bramble":
		var k := clampf(1.0 - _anim_t / 1.2, 0.0, 1.0)
		_visual.scale = Vector3(1.0, k, 1.0)
		if _anim_t > 1.2:
			_visual.visible = false
			_anim_t = -1.0
	else:
		var k2 := clampf(_anim_t / 1.5, 0.0, 1.0)
		_bridge.scale = Vector3(k2, 1.0, 1.0)
		if _anim_t > 1.5:
			_bridge.scale = Vector3.ONE
			_anim_t = -1.0
