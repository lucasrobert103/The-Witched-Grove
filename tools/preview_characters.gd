extends Node3D
## Cena de desenvolvimento: enfileira todos os personagens para revisão visual.

func _ready() -> void:
	var env := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = Color("#2b2140")
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color("#d8d0e8")
	e.ambient_light_energy = 0.45
	e.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.environment = e
	add_child(env)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-40, 30, 0)
	sun.light_energy = 1.2
	sun.shadow_enabled = true
	add_child(sun)
	var ground := MeshInstance3D.new()
	ground.mesh = MeshKit.plane(Vector2(40, 40))
	ground.material_override = Toon.mat(Color("#4f7f45"))
	add_child(ground)
	var defs: Array = [DataRegistry.player_def]
	var only: String = get_tree().root.get_meta("debug_cam", "") if get_tree().root.has_meta("debug_cam") else ""
	for id in ["salvia", "bento", "mirela", "juniper", "lyra", "tome", "kael", "dorinha", "ornel", "celeste", "nox"]:
		defs.append(DataRegistry.npcs[id])
	if only in ["asterion", "rosto"]:
		defs = [DataRegistry.player_def]
	var x := -(defs.size() - 1) * 0.5
	for d in defs:
		var m := HumanoidModel.new()
		add_child(m)
		m.build(d.appearance)
		m.position = Vector3(x, 0, 0)
		m.rotation_degrees.y = 15
		x += 1.0
	var cam := Camera3D.new()
	add_child(cam)
	if only == "asterion":
		cam.position = Vector3(0.0, 1.2, -2.7)
		cam.look_at(Vector3(0, 0.95, 0))
		cam.fov = 38
	elif only == "rosto":
		cam.position = Vector3(0.12, 1.5, -0.66)
		cam.look_at(Vector3(0, 1.47, 0))
		cam.fov = 30
	else:
		cam.position = Vector3(0, 1.25, -7.4)
		cam.look_at(Vector3(0, 0.95, 0))
		cam.fov = 53
	cam.current = true
