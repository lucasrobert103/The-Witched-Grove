extends Node3D
## Menu principal: diorama 3D ao entardecer (Asterion e Nimbus numa ilha flutuante)
## com título, continuar, novo jogo, configurações e créditos.

var _cam: Camera3D
var _t := 0.0
var _ui: Control
var _modal: Control
var _island: Node3D


func _ready() -> void:
	Game.world_running = false
	_build_scene()
	_build_ui()
	AudioManager.play_music("tema_menu")
	AudioManager.play_ambient("amb_noite")


func _build_scene() -> void:
	var we := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	var sky := Sky.new()
	var sm := ShaderMaterial.new()
	sm.shader = load("res://src/resources/shaders/sky.gdshader")
	sm.set_shader_parameter("top_color", Color("#1e1c50"))
	sm.set_shader_parameter("horizon_color", Color("#ff8a7a"))
	sm.set_shader_parameter("ground_color", Color("#2a1d44"))
	sm.set_shader_parameter("sun_dir", Vector3(-0.9, 0.08, -0.4))
	sm.set_shader_parameter("sun_visible", 1.0)
	sm.set_shader_parameter("moon_dir", Vector3(0.6, 0.5, -0.6))
	sm.set_shader_parameter("moon_visible", 1.0)
	sm.set_shader_parameter("moon_phase", 0.3)
	sm.set_shader_parameter("star_intensity", 0.8)
	sm.set_shader_parameter("cloud_amount", 0.5)
	sm.set_shader_parameter("cloud_color", Color("#ffb8a8"))
	sky.sky_material = sm
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("#8a7ab8")
	env.ambient_light_energy = 0.8
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.glow_enabled = true
	env.glow_intensity = 0.8
	env.glow_hdr_threshold = 1.0
	we.environment = env
	add_child(we)
	var sun := DirectionalLight3D.new()
	sun.light_color = Color("#ffb08a")
	sun.light_energy = 1.1
	sun.shadow_enabled = true
	sun.rotation_degrees = Vector3(-25, -120, 0)
	add_child(sun)

	_island = Node3D.new()
	add_child(_island)
	MeshKit.part(_island, MeshKit.cylinder(4.2, 4.0, 0.6, 28), Toon.mat(Color("#6fbf5c"), {"rim": 0.3, "outline": 0.03}), Vector3(0, -0.3, 0))
	MeshKit.part(_island, MeshKit.cylinder(4.0, 0.4, 4.0, 14), Toon.mat(Color("#7a6a8a"), {"outline": 0.04}), Vector3(0, -2.6, 0))
	for k in 6:
		var a := k * TAU / 6.0
		MeshKit.part(_island, MeshKit.rock(k, 0.7), Toon.mat(Color("#8b889c"), {"outline": 0.02}), Vector3(sin(a) * 3.0, -1.6 - (k % 2) * 0.8, cos(a) * 3.0))
	# árvore e cogumelos
	MeshKit.part(_island, MeshKit.cylinder(0.25, 0.35, 2.4, 8), Toon.mat(Color("#7a5236"), {"outline": 0.03}), Vector3(-1.8, 1.2, -2.2))
	for p in [Vector3(-1.8, 3.0, -2.2), Vector3(-1.2, 2.6, -1.8), Vector3(-2.3, 2.5, -2.6)]:
		MeshKit.part(_island, MeshKit.sphere(1.0, 14, 8), Toon.mat(Color("#4fae5a"), {"rim": 0.5, "outline": 0.03}), p)
	for k in 4:
		var p2 := Vector3(1.8 + k * 0.35, 0.0, 1.2 - k * 0.3)
		MeshKit.part(_island, MeshKit.cylinder(0.05, 0.06, 0.25, 6), Toon.mat(Color("#f3e6cf")), p2 + Vector3(0, 0.12, 0))
		MeshKit.part(_island, MeshKit.sphere(0.16, 10, 6, true), Toon.mat(Color("#ff7a3c"), {"emission": 0.6}), p2 + Vector3(0, 0.24, 0), Vector3.ZERO, Vector3(1, 0.7, 1))
	# caldeirão
	MeshKit.part(_island, MeshKit.sphere(0.45, 14, 8), Toon.mat(Color("#2a2433"), {"outline": 0.02}), Vector3(1.6, 0.4, -1.4), Vector3.ZERO, Vector3(1, 0.8, 1))
	MeshKit.part(_island, MeshKit.cylinder(0.36, 0.36, 0.04, 14), Toon.glow(Color("#7dffb0"), 1.6), Vector3(1.6, 0.72, -1.4))
	MeshKit.light(_island, Color("#7dffb0"), 1.5, 4.0, Vector3(1.6, 1.3, -1.4))
	# Asterion e Nimbus
	var ast := HumanoidModel.new()
	_island.add_child(ast)
	ast.build(DataRegistry.player_def.appearance)
	ast.rotation_degrees.y = 165
	ast.position = Vector3(0.4, 0, 0.8)
	ast.play_wave()
	var nim := NimbusModel.new()
	_island.add_child(nim)
	nim.position = Vector3(-0.5, 1.7, 1.2)
	nim.rotation_degrees.y = 200
	# vagalumes
	var ff := CPUParticles3D.new()
	ff.amount = 40
	ff.lifetime = 5.0
	ff.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	ff.emission_box_extents = Vector3(5, 2, 5)
	ff.spread = 180.0
	ff.gravity = Vector3.ZERO
	ff.initial_velocity_min = 0.1
	ff.initial_velocity_max = 0.3
	ff.scale_amount_min = 0.04
	ff.scale_amount_max = 0.07
	var fm := SphereMesh.new()
	fm.radius = 0.5
	fm.height = 1.0
	fm.radial_segments = 6
	fm.rings = 3
	fm.material = Toon.glow(Color("#e8ff8a"), 4.0)
	ff.mesh = fm
	ff.position = Vector3(0, 1.5, 0)
	add_child(ff)
	_cam = Camera3D.new()
	_cam.fov = 50
	add_child(_cam)
	_cam.current = true


func _build_ui() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	_ui = Control.new()
	_ui.set_anchors_preset(Control.PRESET_FULL_RECT)
	_ui.theme = UITheme.get_theme()
	_ui.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(_ui)
	var col := VBoxContainer.new()
	col.anchor_left = 0.05
	col.anchor_right = 0.42
	col.anchor_top = 0.08
	col.anchor_bottom = 0.95
	col.add_theme_constant_override("separation", 14)
	_ui.add_child(col)
	var title := UITheme.label("The Witched Grove", 2.6, UITheme.GOLD)
	title.add_theme_constant_override("outline_size", 14)
	title.add_theme_color_override("font_outline_color", Color("#2a1d44"))
	col.add_child(title)
	var sub := UITheme.label("Asterion e o Silêncio Cinzento", 1.25, UITheme.MOON)
	sub.add_theme_constant_override("outline_size", 8)
	sub.add_theme_color_override("font_outline_color", Color("#2a1d44"))
	col.add_child(sub)
	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, 24)
	col.add_child(spacer)
	if SaveManager.has_save():
		var meta := SaveManager.save_meta()
		col.add_child(UITheme.button("Continuar  (dia %d)" % int(meta.get("day", 1)) if not meta.is_empty() else "Continuar", _continue, 64))
	col.add_child(UITheme.button("Novo jogo", _new_game, 64))
	col.add_child(UITheme.button("Configurações", _settings, 64))
	col.add_child(UITheme.button("Créditos", _credits, 64))
	if not OS.has_feature("mobile") and not OS.has_feature("web"):
		col.add_child(UITheme.button("Sair", func(): get_tree().quit(), 64))
	var ver := UITheme.label("v%s · Godot 4.7 · protótipo do Ato I" % ProjectSettings.get_setting("application/config/version", "0.1"), 0.7, Color(1, 1, 1, 0.6))
	ver.anchor_top = 1.0
	ver.anchor_bottom = 1.0
	ver.offset_top = -36
	ver.offset_left = 16
	_ui.add_child(ver)


func _process(delta: float) -> void:
	_t += delta
	var a := sin(_t * 0.12) * 0.3 + 0.15
	_cam.position = Vector3(sin(a) * 7.5, 2.2 + sin(_t * 0.3) * 0.25, cos(a) * 7.5)
	_cam.look_at(Vector3(-2.3, 1.15, 0), Vector3.UP)
	_island.position.y = sin(_t * 0.6) * 0.15


func _continue() -> void:
	if SaveManager.load_game():
		get_tree().change_scene_to_file("res://src/scenes/world/game_world.tscn")
	else:
		_open(MessagePanel.new(), {"title": "Ops", "text": "Não foi possível carregar o jogo salvo. Comece um novo jogo."})


func _new_game() -> void:
	if SaveManager.has_save() and _modal == null:
		var p := ConfirmPanel.new()
		_open(p, {"title": "Novo jogo", "text": "Começar de novo substituirá o jogo salvo. Tem certeza?"})
		p.confirmed.connect(_start_new)
		return
	_start_new()


func _start_new() -> void:
	SaveManager.delete_save()
	Game.new_game()
	get_tree().change_scene_to_file("res://src/scenes/world/game_world.tscn")


func _settings() -> void:
	_open(BookPanel.new(), {"tab": "opcoes", "only_options": true})


func _credits() -> void:
	_open(MessagePanel.new(), {"title": "Créditos", "text": "The Witched Grove — protótipo do Ato I.\n\nDesign, código, personagens, cenários, música e sons gerados proceduralmente para este projeto em Godot 4.7 + GDScript.\n\nProtagonista: Asterion. Familiar: Nimbus.\nNenhum asset de terceiros foi utilizado."})


func _open(p: Control, payload: Dictionary) -> void:
	if _modal and is_instance_valid(_modal):
		_modal.queue_free()
	_modal = p
	_ui.add_child(p)
	p.closed.connect(func(): _modal = null)
	p.open(payload)
