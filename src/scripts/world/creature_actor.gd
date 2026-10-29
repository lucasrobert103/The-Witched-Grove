class_name CreatureActor
extends Interactable
## Criaturas resolvidas por conhecimento — nunca por dano.
## kind: "mushroom" (Cogumelo Resmungão), "wisp" (Lumécula), "faisca", "frog" (Sapo-Cristal)

var kind: String = "frog"
var creature_id: String = ""
var model: Node3D
var home: Vector3
var _t := 0.0
var _player: Node3D
var _shove_cd := 0.0
var _ground: Callable


func setup(p_kind: String, ground_fn: Callable) -> void:
	kind = p_kind
	_ground = ground_fn
	match kind:
		"mushroom":
			creature_id = "cogumelo_resmungao"; radius = 4.0; marker_height = 3.4
		"wisp", "faisca":
			creature_id = "lumecula"; radius = 2.2; marker_height = 0.6
		"frog":
			creature_id = "sapo_cristal"; radius = 1.8; marker_height = 0.6


func _ready() -> void:
	home = position
	match kind:
		"mushroom":
			model = MushroomModel.new()
			var body := StaticBody3D.new()
			var cs := CollisionShape3D.new()
			var cyl := CylinderShape3D.new()
			cyl.radius = 1.1
			cyl.height = 3.0
			cs.shape = cyl
			cs.position.y = 1.5
			body.add_child(cs)
			add_child(body)
		"wisp":
			var w := WispModel.new()
			w.setup([Color("#9fe8ff"), Color("#b6ffcf"), Color("#d6b8ff"), Color("#ffd1f0")][randi() % 4])
			model = w
		"faisca":
			var f := WispModel.new()
			f.setup(Color("#ffd36b"), [1, 1, 0])
			model = f
		"frog":
			model = FrogModel.new()
	add_child(model)
	_t = randf() * 10.0
	refresh_state()


func refresh_state() -> void:
	match kind:
		"mushroom":
			var calm := Game.has_flag("cogumelo_calmo")
			model.mood = MushroomModel.Mood.CALM if calm else MushroomModel.Mood.GRUMPY
			position = home + (Vector3(0, 0, 2.6) if calm else Vector3.ZERO)
			rotation.y = (-0.6 if calm else 0.0) + PI * 0.5
		"faisca":
			visible = Game.quests.is_active("sq_juniper") and not Game.has_flag("faisca_achada") and Game.clock.is_night()


func _lit() -> bool:
	return Game.has_buff("light_orb") or Game.has_buff("glow")


func can_interact() -> bool:
	return visible


func get_prompt() -> String:
	match kind:
		"mushroom":
			if Game.has_flag("cogumelo_calmo"):
				return "Observar o Cogumelo (roncando)"
			if Game.inventory.count("cha_calmante") > 0:
				return "Oferecer Chá Calmante"
			if Game.inventory.count("pocao_sono_leve") > 0:
				return "Oferecer Poção do Sono Leve"
			return "Falar com o Cogumelo Resmungão"
		"faisca":
			return "Chamar Faísca" if _lit() else "Observar as luméculas"
		"wisp":
			return "Observar a lumécula"
	return "Observar o Sapo-Cristal"


func interact(_p: Node) -> void:
	match kind:
		"mushroom":
			_interact_mushroom()
		"faisca":
			if not _lit():
				say("São tantas luzinhas... Está escuro demais para saber qual é a Faísca. Juniper disse que ela ama luz de estrela.", "info")
				return
			Game.set_flag("faisca_achada")
			Game.give_item("lanterna_faisca", 1)
			Game.discover("criatura", "faisca", "Faísca reconheceu sua luz estelar e pulou para dentro do pote: pisca-pisca-PAUSA!")
			AudioManager.play_sfx("wisp_chime")
			refresh_state()
		"wisp":
			if Game.clock.is_night() and _lit():
				Game.observe_creature("lumecula")
				AudioManager.play_sfx("wisp_chime")
			else:
				say("A lumécula foge da sua sombra. Talvez se aproximasse de alguém com luz própria.", "info")
		"frog":
			Game.observe_creature("sapo_cristal")
			AudioManager.play_sfx("creature_calm")


func _interact_mushroom() -> void:
	if Game.quests.not_started("sq_cogumelo"):
		Game.start_quest("sq_cogumelo")
	if Game.has_flag("cogumelo_calmo"):
		Game.observe_creature("cogumelo_resmungao")
		return
	for gift in ["cha_calmante", "pocao_sono_leve"]:
		if Game.inventory.count(gift) > 0:
			Game.take_item(gift, 1)
			Game.set_flag("cogumelo_calmo")
			Game.add_bestiary("cogumelo_resmungao", 3)
			Game.discover("criatura", "cogumelo_resmungao", "O Cogumelo Resmungão bebe tudo de um gole, boceja... e se arrasta para o lado, roncando. O caminho leste está livre!")
			AudioManager.play_sfx("creature_calm")
			refresh_state()
			return
	Game.add_bestiary("cogumelo_resmungao", 1)
	AudioManager.play_sfx("grumble")
	say("\"HMMMF! Tô cochilando! Ninguém passa!\" — Ele cheira a terra molhada e parece... cansado. E guloso por coisas doces.", "warning")


func _process(delta: float) -> void:
	_t += delta
	if _player == null:
		_player = get_tree().get_first_node_in_group("player")
	match kind:
		"mushroom":
			_process_mushroom(delta)
		"wisp", "faisca":
			_process_wisp(delta)
		"frog":
			visible = not Game.clock.is_night()


func _process_mushroom(delta: float) -> void:
	_shove_cd -= delta
	if _player == null or Game.has_flag("cogumelo_calmo"):
		return
	var d := _player.global_position.distance_to(global_position)
	if Game.quests.not_started("sq_cogumelo") and d < 9.0:
		Game.start_quest("sq_cogumelo")
	var stealth := Game.has_buff("stealth")
	if not stealth and d < 3.2 and _shove_cd <= 0.0:
		_shove_cd = 1.5
		var away := (_player.global_position - global_position)
		away.y = 0
		if away.length() < 0.1:
			away = Vector3(-1, 0, 0)
		if _player.has_method("shove"):
			_player.shove(away.normalized() * 9.0)
		Game.damage(6.0, "esporos")
		AudioManager.play_sfx("grumble")
		say("O Cogumelo Resmungão te empurra e solta esporos: \"SAI! TÔ COCHILANDO!\"" + ("" if Game.has_buff("shield") else " (Esporos ardem!)"), "warning")
	# Atravessou para o outro lado sob o Véu?
	if stealth and _player.global_position.x > global_position.x + 2.5 and absf(_player.global_position.z - global_position.z) < 6.0:
		if not Game.has_flag("cogumelo_driblado"):
			Game.set_flag("cogumelo_driblado")
			Game.add_bestiary("cogumelo_resmungao", 2)
			say("Você passou como uma sombra. O Cogumelo nem piscou.", "discovery")


func _process_wisp(delta: float) -> void:
	var night := Game.clock.is_night()
	if kind == "wisp":
		visible = night
	elif Engine.get_process_frames() % 30 == 0:
		refresh_state()
	if not visible:
		return
	var target := home + Vector3(sin(_t * 0.6 + home.x) * 2.0, 1.2 + sin(_t * 1.7) * 0.3, cos(_t * 0.5 + home.z) * 2.0)
	if _player and _lit() and _player.global_position.distance_to(home) < 9.0:
		target = _player.global_position + Vector3(sin(_t + home.x) * 1.4, 1.6 + sin(_t * 2.0) * 0.2, cos(_t * 0.8 + home.z) * 1.4)
		if model is WispModel:
			model.brightness = 1.6
	elif model is WispModel:
		model.brightness = 1.0
	position = position.lerp(target, 1.0 - exp(-1.5 * delta))
