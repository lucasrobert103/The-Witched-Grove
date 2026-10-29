class_name Player
extends CharacterBody3D
## Asterion jogável: movimento relativo à câmera (joystick virtual ou teclado),
## câmera orbital com toque, foco de interação, magia e efeitos de buffs.

const WALK_SPEED := 4.4
const RUN_SPEED := 6.8
const GRAVITY := 22.0
const CAM_MIN_DIST := 3.2
const CAM_MAX_DIST := 11.0

var model: HumanoidModel
var cam_yaw: float = 0.0
var cam_pitch: float = -0.42
var cam_dist: float = 6.5
var move_input: Vector2 = Vector2.ZERO      # do joystick virtual (HUD)
var input_enabled: bool = true
var focused: Interactable = null
var last_safe_position: Vector3

var _cam_pivot: Node3D
var _spring: SpringArm3D
var camera: Camera3D
var _shove: Vector3 = Vector3.ZERO
var _light_orb: Node3D
var _shield: MeshInstance3D
var _glow_light: OmniLight3D
var _safe_timer := 0.0
var _step_timer := 0.0
var _orb_t := 0.0


func _ready() -> void:
	add_to_group("player")
	var col := CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = 0.35
	cap.height = 1.5
	col.shape = cap
	col.position.y = 0.75
	add_child(col)
	floor_snap_length = 0.6
	floor_max_angle = deg_to_rad(48)

	model = HumanoidModel.new()
	add_child(model)
	model.build(DataRegistry.player_def.appearance)

	_cam_pivot = Node3D.new()
	_cam_pivot.position = Vector3(0, 1.4, 0)
	add_child(_cam_pivot)
	_cam_pivot.top_level = true
	_spring = SpringArm3D.new()
	_spring.spring_length = cam_dist
	_spring.margin = 0.3
	var sph := SphereShape3D.new()
	sph.radius = 0.25
	_spring.shape = sph
	_spring.add_excluded_object(get_rid())
	_cam_pivot.add_child(_spring)
	camera = Camera3D.new()
	camera.fov = 62.0
	camera.far = 260.0
	_spring.add_child(camera)
	camera.current = true

	_light_orb = Node3D.new()
	_light_orb.visible = false
	add_child(_light_orb)
	MeshKit.part(_light_orb, MeshKit.sphere(0.12, 10, 6), Toon.glow(Color("#fff3c4"), 3.0), Vector3.ZERO, Vector3.ZERO, Vector3.ONE, false)
	MeshKit.part(_light_orb, MeshKit.star(0.16, 0.07, 0.02), Toon.glow(Color("#fff3c4"), 2.0), Vector3.ZERO, Vector3.ZERO, Vector3.ONE, false)
	MeshKit.light(_light_orb, Color("#fff0c4"), 2.2, 9.0)
	_shield = MeshKit.part(self, MeshKit.sphere(1.05, 20, 12), Toon.translucent(Color("#9ff0ff"), 0.18, 0.6), Vector3(0, 0.9, 0), Vector3.ZERO, Vector3.ONE, false)
	_shield.visible = false
	_glow_light = MeshKit.light(self, Color("#fff3a0"), 0.0, 6.0, Vector3(0, 1.4, 0))
	EventBus.buff_changed.connect(_on_buff_changed)
	last_safe_position = global_position


func place_at(pos: Vector3, yaw: float = 0.0) -> void:
	global_position = pos
	velocity = Vector3.ZERO
	rotation.y = yaw
	cam_yaw = yaw
	last_safe_position = pos
	_cam_pivot.global_position = pos + Vector3(0, 1.4, 0)


func shove(v: Vector3) -> void:
	_shove = v


func rotate_camera(delta_px: Vector2) -> void:
	var sens := 0.0045 * Settings.camera_sensitivity
	cam_yaw -= delta_px.x * sens
	var dy := delta_px.y * sens * (-1.0 if Settings.invert_camera_y else 1.0)
	cam_pitch = clampf(cam_pitch - dy, -1.15, 0.25)


func zoom_camera(factor: float) -> void:
	cam_dist = clampf(cam_dist * factor, CAM_MIN_DIST, CAM_MAX_DIST)


func _unhandled_input(event: InputEvent) -> void:
	if not input_enabled:
		return
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			zoom_camera(0.9)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			zoom_camera(1.1)
	if event.is_action_pressed("interact"):
		try_interact()
	elif event.is_action_pressed("cast"):
		cast_selected()
	for i in 4:
		if event.is_action_pressed("slot_%d" % (i + 1)):
			Game.spells.selected_slot = i
			EventBus.spell_slots_changed.emit()


func try_interact() -> void:
	if focused and focused.can_interact():
		focused.interact(self)
		AudioManager.play_sfx("ui_click", -6.0)


func cast_selected() -> void:
	var sid := Game.spells.selected_spell()
	if sid == "":
		EventBus.notify.emit("Nenhum feitiço neste espaço. Aprenda feitiços lendo grimórios.", "warning")
		return
	var r := Game.cast_spell(sid)
	if r.ok:
		model.play_cast()
		Settings.vibrate(35)


func _physics_process(delta: float) -> void:
	var input := Vector2.ZERO
	var running := false
	if input_enabled:
		input = move_input
		var kb := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
		if kb.length() > 0.05:
			input = kb
			running = Input.is_key_pressed(KEY_SHIFT)
	var mag := minf(1.0, input.length())
	if mag > 0.85 and move_input.length() > 0.0:
		running = true
	var dir := Vector3(input.x, 0, input.y).rotated(Vector3.UP, cam_yaw)
	if dir.length() > 1.0:
		dir = dir.normalized()
	var speed := RUN_SPEED if running else WALK_SPEED
	var target_v := dir * speed
	velocity.x = lerpf(velocity.x, target_v.x, 1.0 - exp(-12.0 * delta))
	velocity.z = lerpf(velocity.z, target_v.z, 1.0 - exp(-12.0 * delta))
	if _shove.length() > 0.1:
		velocity.x = _shove.x
		velocity.z = _shove.z
		_shove = _shove.lerp(Vector3.ZERO, 1.0 - exp(-6.0 * delta))
	if not is_on_floor():
		velocity.y -= GRAVITY * delta
	else:
		velocity.y = maxf(velocity.y, -0.5)
	move_and_slide()
	var flat := Vector2(velocity.x, velocity.z)
	if flat.length() > 0.4:
		rotation.y = lerp_angle(rotation.y, atan2(-velocity.x, -velocity.z), 1.0 - exp(-10.0 * delta))
	model.move_amount = clampf(flat.length() / RUN_SPEED, 0.0, 1.0)
	# passos
	if is_on_floor() and flat.length() > 1.0:
		_step_timer -= delta * flat.length() / WALK_SPEED
		if _step_timer <= 0.0:
			_step_timer = 0.42
			AudioManager.play_sfx("step", -14.0, 0.15)
	# limites do mundo e água
	var hz := Vector2(global_position.x, global_position.z)
	if hz.length() > ValleyTerrain.BOUNDARY:
		hz = hz.normalized() * ValleyTerrain.BOUNDARY
		global_position.x = hz.x
		global_position.z = hz.y
	_safe_timer -= delta
	if is_on_floor() and _safe_timer <= 0.0 and global_position.y > ValleyTerrain.CREEK_LEVEL + 0.2 and get_floor_normal().y > 0.8:
		_safe_timer = 0.5
		if not _on_ice():
			last_safe_position = global_position
	if global_position.y < ValleyTerrain.CREEK_LEVEL - 0.75:
		global_position = last_safe_position + Vector3(0, 0.3, 0)
		velocity = Vector3.ZERO
		AudioManager.play_sfx("water")
		EventBus.notify.emit("Splash! Você nadou de volta à margem. (Água funda demais — talvez uma ponte... ou gelo?)", "warning")
	_update_focus()


func _on_ice() -> bool:
	for w in get_tree().get_nodes_in_group("water"):
		if w.is_frozen() and w.distance_to(global_position) < 9.0 and global_position.y < ValleyTerrain.CREEK_LEVEL + 0.6:
			return true
	return false


func _process(delta: float) -> void:
	# câmera suave
	var target := global_position + Vector3(0, 1.45, 0)
	_cam_pivot.global_position = _cam_pivot.global_position.lerp(target, 1.0 - exp(-10.0 * delta))
	_cam_pivot.rotation = Vector3(cam_pitch, cam_yaw, 0)
	_spring.spring_length = lerpf(_spring.spring_length, cam_dist, 1.0 - exp(-8.0 * delta))
	# astro de luz orbitando
	if _light_orb.visible:
		_orb_t += delta
		_light_orb.position = Vector3(sin(_orb_t * 1.6) * 0.8, 2.1 + sin(_orb_t * 2.3) * 0.15, cos(_orb_t * 1.6) * 0.8)
	if _shield.visible:
		_shield.rotation.y += delta
		_shield.scale = Vector3.ONE * (1.0 + sin(_orb_t * 4.0) * 0.02)


func _update_focus() -> void:
	var best: Interactable = null
	var best_score := INF
	var fwd := -global_transform.basis.z
	for n in get_tree().get_nodes_in_group("interactable"):
		var it := n as Interactable
		if it == null or not it.is_visible_in_tree() or not it.can_interact():
			continue
		var to := it.global_position - global_position
		to.y = 0.0
		var d := to.length()
		if d > it.radius:
			continue
		var facing := 0.0 if d < 0.01 else fwd.dot(to / d)
		var score := d - facing * 0.8
		if score < best_score:
			best_score = score
			best = it
	focused = best


func _on_buff_changed(buff: String, active: bool) -> void:
	match buff:
		"light_orb":
			_light_orb.visible = active
			if active:
				AudioManager.play_sfx("spell_light")
		"glow":
			_glow_light.light_energy = 1.6 if active else 0.0
		"shield":
			_shield.visible = active
		"stealth":
			model.ghost = active
