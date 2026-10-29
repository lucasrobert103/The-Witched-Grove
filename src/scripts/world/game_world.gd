class_name GameWorld
extends Node3D
## Cena principal de jogo: monta o vale, a protagonista, o familiar, a interface,
## o ciclo dia/noite, o clima, a música e liga feitiços ao mundo.

const HOME_SPAWN := Vector3(0.0, 0.0, -1.0)
## Paleta do céu por hora: [hora, topo, horizonte, cor da luz, energia, ambiente]
const SKY_KEYS := [
	[0.0, "#0b1030", "#2a2350", "#8fa8ff", 0.22, "#3a3f78"],
	[5.0, "#141a44", "#4a3060", "#8fa8ff", 0.25, "#4a4a80"],
	[6.2, "#3a4a8a", "#ff9a8a", "#ffb08a", 0.55, "#8a7aa0"],
	[7.5, "#5aa0e8", "#ffe2b8", "#ffe2b8", 1.0, "#a8b8d8"],
	[12.0, "#4f9ef0", "#d4ecff", "#fff6e8", 1.2, "#b8c8e8"],
	[16.5, "#5a8ee0", "#ffe0a8", "#ffd9a0", 1.05, "#b0b0d0"],
	[18.4, "#4a3f8a", "#ff8a5c", "#ff9a6a", 0.7, "#9a7aa0"],
	[19.6, "#1e1c50", "#6a3a7a", "#9aa8ff", 0.3, "#5a5090"],
	[21.0, "#0b1030", "#2a2350", "#8fa8ff", 0.22, "#3a3f78"],
	[24.0, "#0b1030", "#2a2350", "#8fa8ff", 0.22, "#3a3f78"],
]

var builder: ValleyBuilder
var player: Player
var nimbus: NimbusModel
var hud: Node
var sun: DirectionalLight3D
var env: Environment
var sky_mat: ShaderMaterial
var _rain: CPUParticles3D
var _snow: CPUParticles3D
var _fireflies: CPUParticles3D
var _marker: Node3D
var _last_hour_int := -1
var _autosave_timer := 0.0
var _t := 0.0
var _debug_hour := -1.0


func _ready() -> void:
	add_to_group("game_world")
	if get_tree().root.has_meta("debug_hour"):
		_debug_hour = float(get_tree().root.get_meta("debug_hour"))
		if _debug_hour >= 0.0:
			Game.clock.total_minutes = (Game.clock.day() - 1) * 1440.0 + _debug_hour * 60.0
	_build_environment()
	builder = ValleyBuilder.new()
	builder.build(self, Settings.quality)
	_build_weather()
	_build_marker()

	player = Player.new()
	player.name = "Asterion"
	add_child(player)
	var ps: Dictionary = Game.player_state
	if ps.has("pos"):
		var p: Array = ps.pos
		player.place_at(Vector3(p[0], p[1] + 0.2, p[2]), float(ps.get("yaw", 0.0)))
	else:
		player.place_at(builder.at(HOME_SPAWN.x, HOME_SPAWN.z, 0.1), 0.0)

	nimbus = NimbusModel.new()
	nimbus.name = "Nimbus"
	add_child(nimbus)
	nimbus.position = player.position + Vector3(-1, 1.5, 1)

	var hud_scene := load("res://src/scenes/ui/hud.tscn") as PackedScene
	hud = hud_scene.instantiate()
	add_child(hud)
	hud.bind_player(player)

	EventBus.spell_cast.connect(_on_spell_cast)
	EventBus.teleport_requested.connect(_on_teleport)
	EventBus.flag_changed.connect(func(_f, _v): _refresh_world())
	EventBus.day_changed.connect(func(_d): _refresh_world())
	EventBus.quest_started.connect(func(_q): _refresh_world())
	EventBus.quest_completed.connect(func(_q, _o): _refresh_world())
	EventBus.inventory_changed.connect(_refresh_world)
	EventBus.weather_changed.connect(func(_w): _apply_weather())
	Settings.changed.connect(_apply_quality)
	_apply_quality()
	_refresh_world()
	_apply_weather()
	_update_sky(0.0)
	Game.begin()
	if get_tree().root.has_meta("debug_cam"):
		_debug_camera(str(get_tree().root.get_meta("debug_cam")))
	elif not Game.has_flag("intro_vista"):
		EventBus.panel_requested.emit("intro", {})


## Enquadramentos de demonstração (capturas de tela automatizadas).
func _debug_camera(preset: String) -> void:
	Game.set_flag("intro_vista")
	var spots := {
		"casa": [Vector3(3.0, 0, 7.0), 0.35, -0.3, 8.5],
		"guardiao": [Vector3(0.5, 0, -27.0), 0.0, -0.25, 9.0],
		"lagoa": [Vector3(-22.0, 0, -10.0), 1.2, -0.3, 9.0],
		"cogumelo": [Vector3(24.0, 0, -4.0), -1.45, -0.25, 8.0],
		"salvia": [Vector3(-15.0, 0, 26.0), 0.9, -0.25, 9.0],
		"jardim": [Vector3(-6.6, 0, 9.5), 0.15, -0.55, 7.0],
		"circulo": [Vector3(19.0, 0, -15.0), 0.0, -0.3, 10.0],
	}
	if get_tree().root.has_meta("debug_panel"):
		_debug_seed_state()
		var panel := str(get_tree().root.get_meta("debug_panel"))
		var parts := panel.split(":")
		var payload := {}
		if parts.size() > 1:
			payload = {"tab": parts[1], "npc": parts[1], "page": parts[1], "plot": 0}
		EventBus.panel_requested.emit.call_deferred(parts[0], payload)
	if spots.has(preset):
		var sp: Array = spots[preset]
		var pos: Vector3 = sp[0]
		player.place_at(builder.at(pos.x, pos.z, 0.1), sp[1])
		player.cam_pitch = sp[2]
		player.cam_dist = sp[3]
		nimbus.global_position = player.global_position + Vector3(-1, 1.5, 1)


func _build_environment() -> void:
	var we := WorldEnvironment.new()
	env = Environment.new()
	env.background_mode = Environment.BG_SKY
	var sky := Sky.new()
	sky_mat = ShaderMaterial.new()
	sky_mat.shader = load("res://src/resources/shaders/sky.gdshader")
	sky.sky_material = sky_mat
	sky.radiance_size = Sky.RADIANCE_SIZE_64
	sky.process_mode = Sky.PROCESS_MODE_REALTIME
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_energy = 0.6
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.tonemap_exposure = 0.92
	env.tonemap_white = 6.0
	env.fog_enabled = true
	env.fog_density = 0.004
	env.fog_sky_affect = 0.15
	env.glow_enabled = true
	env.glow_intensity = 0.6
	env.glow_bloom = 0.08
	env.glow_hdr_threshold = 1.1
	env.adjustment_enabled = true
	env.adjustment_saturation = 1.12
	env.adjustment_contrast = 1.04
	we.environment = env
	add_child(we)
	sun = DirectionalLight3D.new()
	sun.shadow_enabled = true
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS
	sun.directional_shadow_max_distance = 45.0
	sun.shadow_blur = 1.5
	add_child(sun)


func _build_weather() -> void:
	_rain = _weather_particles(Color("#bcd8ff"), Vector3(0.02, 0.5, 0.02), Vector3(0, -24, 0), 400, 0.9)
	_snow = _weather_particles(Color("#ffffff"), Vector3(0.08, 0.08, 0.08), Vector3(0.4, -2.0, 0.2), 260, 5.0)
	_fireflies = CPUParticles3D.new()
	_fireflies.amount = 60
	_fireflies.lifetime = 6.0
	_fireflies.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	_fireflies.emission_box_extents = Vector3(22, 1.5, 22)
	_fireflies.direction = Vector3.UP
	_fireflies.spread = 180.0
	_fireflies.initial_velocity_min = 0.1
	_fireflies.initial_velocity_max = 0.4
	_fireflies.gravity = Vector3.ZERO
	_fireflies.scale_amount_min = 0.04
	_fireflies.scale_amount_max = 0.08
	var fm := SphereMesh.new()
	fm.radius = 0.5
	fm.height = 1.0
	fm.radial_segments = 6
	fm.rings = 3
	fm.material = Toon.glow(Color("#e8ff8a"), 4.0)
	_fireflies.mesh = fm
	_fireflies.position = Vector3(0, 1.5, 0)
	add_child(_fireflies)


func _weather_particles(c: Color, size: Vector3, gravity: Vector3, amount: int, life: float) -> CPUParticles3D:
	var p := CPUParticles3D.new()
	p.amount = amount
	p.lifetime = life
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	p.emission_box_extents = Vector3(18, 0.5, 18)
	p.direction = Vector3.DOWN
	p.spread = 5.0
	p.initial_velocity_min = 0.5
	p.initial_velocity_max = 1.0
	p.gravity = gravity
	var m := BoxMesh.new()
	m.size = size
	m.material = Toon.translucent(c, 0.6)
	p.mesh = m
	p.emitting = false
	add_child(p)
	return p


func _build_marker() -> void:
	_marker = Node3D.new()
	MeshKit.part(_marker, MeshKit.crystal(0.12), Toon.glow(Color("#f3c74f"), 2.5), Vector3.ZERO, Vector3(180, 0, 0), Vector3.ONE, false)
	_marker.visible = false
	add_child(_marker)


func _apply_quality() -> void:
	var q := Settings.quality
	sun.shadow_enabled = q >= 1
	sun.directional_shadow_max_distance = [20.0, 35.0, 55.0][q]
	env.glow_enabled = q >= 1
	get_viewport().scaling_3d_scale = [0.7, 0.85, 1.0][q]
	_fireflies.amount = [20, 40, 60][q]


func _refresh_world() -> void:
	for n in get_tree().get_nodes_in_group("interactable"):
		n.refresh_state()
	if builder and builder.corruption:
		builder.corruption.visible = not Game.has_flag("musgo_purificado")


func _apply_weather() -> void:
	var w := Game.clock.weather()
	_rain.emitting = w == "chuva"
	_snow.emitting = w == "neve"
	AudioManager.set_rain(w == "chuva")


func _process(delta: float) -> void:
	_t += delta
	if _debug_hour >= 0.0:
		Game.clock.total_minutes = (Game.clock.day() - 1) * 1440.0 + _debug_hour * 60.0
	_update_sky(delta)
	# clima segue a protagonista
	if player:
		_rain.global_position = player.global_position + Vector3(0, 12, 0)
		_snow.global_position = player.global_position + Vector3(0, 10, 0)
		_fireflies.global_position = player.global_position + Vector3(0, 1.5, 0)
		_update_nimbus(delta)
		_update_marker(delta)
	var hi := int(Game.clock.hour())
	if hi != _last_hour_int:
		_last_hour_int = hi
		for n in get_tree().get_nodes_in_group("interactable"):
			if n is NPCActor or n is CreatureActor:
				n.refresh_state()
		_update_music()
	_autosave_timer += delta
	if _autosave_timer > 120.0:
		_autosave_timer = 0.0
		save_now()


func _update_nimbus(delta: float) -> void:
	var back := player.global_transform.basis.z
	var side := player.global_transform.basis.x
	var target := player.global_position + back * 1.1 - side * 0.9 + Vector3(0, 1.6, 0)
	nimbus.global_position = nimbus.global_position.lerp(target, 1.0 - exp(-3.0 * delta))
	var look := player.global_position + Vector3(0, 1.4, 0) - player.global_transform.basis.z * 3.0
	var dir := look - nimbus.global_position
	dir.y = 0
	if dir.length() > 0.1:
		nimbus.rotation.y = lerp_angle(nimbus.rotation.y, atan2(-dir.x, -dir.z), 1.0 - exp(-4.0 * delta))


func _update_marker(_delta: float) -> void:
	var f: Interactable = player.focused
	_marker.visible = f != null and player.input_enabled
	if f:
		_marker.global_position = f.global_position + Vector3(0, f.marker_height + sin(_t * 3.0) * 0.08, 0)
		_marker.rotation.y += 0.05


func _update_music() -> void:
	var night := Game.clock.is_night()
	AudioManager.play_music("tema_noite" if night else "tema_dia")
	AudioManager.play_ambient("amb_noite" if night else "amb_floresta")


func _sample_sky(hour: float) -> Array:
	for i in SKY_KEYS.size() - 1:
		var a: Array = SKY_KEYS[i]
		var b: Array = SKY_KEYS[i + 1]
		if hour >= a[0] and hour <= b[0]:
			var t: float = (hour - a[0]) / maxf(0.001, b[0] - a[0])
			return [Color(a[1]).lerp(Color(b[1]), t), Color(a[2]).lerp(Color(b[2]), t), Color(a[3]).lerp(Color(b[3]), t), lerpf(a[4], b[4], t), Color(a[5]).lerp(Color(b[5]), t)]
	return [Color("#0b1030"), Color("#2a2350"), Color("#8fa8ff"), 0.22, Color("#3a3f78")]


func _update_sky(_delta: float) -> void:
	var hour := Game.clock.hour()
	var s := _sample_sky(hour)
	var nf := Game.clock.night_factor()
	var w := Game.clock.weather()
	var top: Color = s[0]
	var hor: Color = s[1]
	var light_c: Color = s[2]
	var energy: float = s[3]
	var amb: Color = s[4]
	if w == "chuva" or w == "neve":
		top = top.lerp(Color("#6a7088"), 0.55 * (1.0 - nf))
		hor = hor.lerp(Color("#a0a4b4"), 0.55 * (1.0 - nf))
		energy *= 0.6
	if Game.has_buff("reveal"):
		amb = amb.lerp(Color("#9ab0ff"), 0.6)
		energy = maxf(energy, 0.6)
	# direção do sol: nasce às 6h a leste, se põe às 18h a oeste
	var sun_angle := (hour - 6.0) / 12.0 * PI
	var sun_dir := Vector3(cos(sun_angle), sin(sun_angle), -0.35).normalized()
	var moon_angle := (hour - 18.0) / 12.0 * PI
	if hour < 6.0:
		moon_angle = (hour + 6.0) / 12.0 * PI
	var moon_dir := Vector3(cos(moon_angle), sin(moon_angle), 0.4).normalized()
	var light_dir := sun_dir if nf < 0.5 else moon_dir
	if light_dir.y < 0.15:
		light_dir.y = 0.15
	sun.look_at_from_position(Vector3.ZERO, -light_dir, Vector3.UP)
	sun.light_color = light_c
	sun.light_energy = energy
	env.ambient_light_color = amb
	env.ambient_light_energy = 0.55 + 0.3 * nf
	env.fog_light_color = hor.lerp(top, 0.3)
	env.fog_density = 0.004 + (0.025 if w == "bruma" else 0.0) + (0.006 if w in ["chuva", "neve"] else 0.0)
	sky_mat.set_shader_parameter("top_color", top)
	sky_mat.set_shader_parameter("horizon_color", hor)
	sky_mat.set_shader_parameter("ground_color", Color("#3a4a3a").lerp(Color("#0e1020"), nf))
	sky_mat.set_shader_parameter("sun_dir", sun_dir)
	sky_mat.set_shader_parameter("moon_dir", moon_dir)
	sky_mat.set_shader_parameter("sun_visible", clampf(sun_dir.y * 4.0 + 0.3, 0.0, 1.0) * (0.3 if w in ["chuva", "neve"] else 1.0))
	sky_mat.set_shader_parameter("moon_visible", clampf(moon_dir.y * 4.0, 0.0, 1.0) * nf)
	sky_mat.set_shader_parameter("moon_phase", Game.clock.moon_phase() / 8.0)
	sky_mat.set_shader_parameter("star_intensity", nf * (0.3 if w in ["chuva", "neve", "bruma"] else 1.0))
	sky_mat.set_shader_parameter("cloud_amount", 0.85 if w in ["chuva", "neve"] else 0.45)
	sky_mat.set_shader_parameter("cloud_color", Color("#ffffff").lerp(Color("#3a3a6a"), nf).lerp(Color("#ffc8a8"), clampf(1.0 - absf(hour - 18.6) * 1.2, 0.0, 0.6)))
	_fireflies.emitting = nf > 0.5 and w != "chuva"
	for l in get_tree().get_nodes_in_group("lantern"):
		var bulb := l.get_node_or_null("Bulb") as MeshInstance3D
		if bulb:
			bulb.visible = nf > 0.3


# ------------------------------------------------------------------ magia no mundo

func _on_spell_cast(spell_id: String, result: Dictionary) -> void:
	if not result.get("ok", false):
		AudioManager.play_sfx("spell_fail")
		return
	var tags: Array = result.get("tags", [])
	var radius := float(result.get("radius", 4.0))
	var origin := player.global_position
	SpellFX.for_spell(self, origin, spell_id, result)
	AudioManager.play_sfx(_spell_sound(tags))
	var reacted := false
	for n in get_tree().get_nodes_in_group("interactable"):
		var it := n as Interactable
		if it == null or not it.is_visible_in_tree():
			continue
		var d := Vector2(it.global_position.x - origin.x, it.global_position.z - origin.z).length()
		if d <= radius + it.radius * 0.5:
			if it.on_spell(tags, result):
				reacted = true
	if "ice" in tags:
		for w in get_tree().get_nodes_in_group("water"):
			if w.distance_to(origin) < radius + 6.0:
				w.freeze(float(DataRegistry.spells.get(spell_id, {}).get("effects", [{}])[0].get("duration", 40.0)) * float(result.get("power", 1.0)))
				if not Game.has_flag("descobriu_gelo"):
					Game.discover("mundo", "gelo", "A água prende a respiração e vira um espelho de gelo. Dá para caminhar!")
					Game.set_flag("descobriu_gelo")
				reacted = true
	if "identify" in tags and not reacted:
		var ing := Game.last_obtained_ingredient
		if ing != "":
			Game.identify_ingredient(ing)
		else:
			EventBus.notify.emit("Nada por perto para identificar. Fique perto de uma planta ou colha algo antes.", "info")
	if "wind" in tags and Game.clock.weather() == "bruma":
		env.fog_density = 0.004
		EventBus.notify.emit("A brisa afasta a bruma por um instante.", "info")
	if "nature_sync" in tags:
		Game.heal(10.0)


func _spell_sound(tags: Array) -> String:
	for pair in [["fire", "spell_fire"], ["grow", "spell_grow"], ["nature_sync", "spell_grow"], ["light", "spell_light"], ["ice", "spell_ice"], ["wind", "spell_wind"], ["shield", "spell_shield"], ["stealth", "spell_veil"], ["purify", "spell_purify"], ["teleport", "teleport"]]:
		if pair[0] in tags:
			return pair[1]
	return "spell_cast"


func _on_teleport(target: String) -> void:
	if target == "home" and player:
		SpellFX.burst(self, player.global_position + Vector3(0, 1, 0), Color("#d6b8ff"), 40)
		player.place_at(builder.at(HOME_SPAWN.x, HOME_SPAWN.z, 0.1), 0.0)
		SpellFX.burst(self, player.global_position + Vector3(0, 1, 0), Color("#d6b8ff"), 40)
		nimbus.global_position = player.global_position + Vector3(-1, 1.5, 1)


## Estado de demonstração para revisar painéis (somente ferramentas de desenvolvimento).
func _debug_seed_state() -> void:
	for pid in ["ondina_1", "ondina_2", "caderno_salvia", "inscricao_salgueiro", "tabua_viajante"]:
		Game.read_page(pid, false)
	for it in [["folha_orvalho", 4], ["agua_manancial", 2], ["lavanda_sonolenta", 2], ["mel_silvestre", 1], ["petala_claridade", 3], ["cogumelo_brasa", 2], ["tonico_revigorante", 1], ["semente_lavanda", 2]]:
		Game.give_item(it[0], it[1], 1.0, true)
	Game.brew(["folha_orvalho", "agua_manancial"], ["moer", "aquecer"])
	Game.add_bestiary("lumecula", 2)
	Game.add_school_xp("botany", 6.0)
	Game.garden_plant(0, "semente_orvalheira")
	Game.garden.plots[0].growth = 0.55
	Game.refresh_quests()


func save_now() -> void:
	if player == null:
		return
	var p := player.last_safe_position
	Game.player_state = {"pos": [p.x, p.y, p.z], "yaw": player.rotation.y}
	SaveManager.save_game()


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_PAUSED or what == NOTIFICATION_WM_CLOSE_REQUEST:
		save_now()
