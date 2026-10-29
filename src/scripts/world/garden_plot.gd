class_name GardenPlot
extends Interactable
## Canteiro do jardim: mostra a planta crescendo e reage a feitiços de Botânica/Runas/Ar.

var index: int = 0
var _soil: MeshInstance3D
var _plant_root: Node3D
var _water_ring: MeshInstance3D
var _rune_ring: MeshInstance3D
var _ready_glow: OmniLight3D
var _last_key := ""
var _t := 0.0


func setup(i: int) -> void:
	index = i
	radius = 1.5
	marker_height = 1.2


func _ready() -> void:
	var wood := Toon.mat(Color("#8a5a36"), {"outline": 0.01})
	for side in [Vector3(0, 0.1, -0.75), Vector3(0, 0.1, 0.75)]:
		MeshKit.part(self, MeshKit.box(Vector3(1.6, 0.2, 0.1)), wood, side)
	for side in [Vector3(-0.75, 0.1, 0), Vector3(0.75, 0.1, 0)]:
		MeshKit.part(self, MeshKit.box(Vector3(0.1, 0.2, 1.4)), wood, side)
	_soil = MeshKit.part(self, MeshKit.box(Vector3(1.4, 0.16, 1.4)), Toon.mat(Color("#4a3426")), Vector3(0, 0.08, 0))
	_water_ring = MeshKit.part(self, MeshKit.box(Vector3(1.38, 0.01, 1.38)), Toon.translucent(Color("#6ab0d8"), 0.35), Vector3(0, 0.17, 0), Vector3.ZERO, Vector3.ONE, false)
	_rune_ring = MeshKit.part(self, MeshKit.torus(0.78, 0.84, 24, 4), Toon.glow(Color("#c9a5ff"), 1.5), Vector3(0, 0.22, 0), Vector3.ZERO, Vector3.ONE, false)
	_plant_root = MeshKit.pivot(self, Vector3(0, 0.16, 0))
	_ready_glow = MeshKit.light(self, Color("#fff3b0"), 0.0, 2.0, Vector3(0, 0.8, 0))
	EventBus.garden_changed.connect(refresh_state)
	EventBus.house_changed.connect(refresh_state)
	refresh_state()


func _unlocked() -> bool:
	return index < Game.house.garden_plots()


func get_prompt() -> String:
	if not _unlocked():
		return "Terra bruta"
	var pl := Game.garden.plot(index)
	if pl.plant == "":
		return "Canteiro vazio (%s)" % _light_name(pl.light)
	if Game.garden.is_ready(index):
		return "Colher %s" % DataRegistry.plants[pl.plant].name
	return "%s · %d%%" % [DataRegistry.plants[pl.plant].name, int(float(pl.growth) * 100.0)]


static func _light_name(l: String) -> String:
	return {"sol": "sol pleno", "meia": "meia-luz", "sombra": "sombra"}.get(l, l)


func interact(_player: Node) -> void:
	if not _unlocked():
		if Game.house.is_unlocked("jardim"):
			say("Este canteiro ainda é terra bruta. Melhore o Jardim no Livro → Casa.", "info")
		else:
			say("Terra bruta. Aprenda algo de Botânica Arcana (o grimório de Ondina, no atril) para despertar o jardim.", "info")
		return
	if Game.garden.is_ready(index):
		var r := Game.garden_harvest(index)
		if r.ok:
			AudioManager.play_sfx("harvest")
			Settings.vibrate(25)
		return
	EventBus.panel_requested.emit("garden", {"plot": index})


func accepts_spells() -> bool:
	return index < Game.house.garden_plots()


func on_spell(tags: Array, result: Dictionary) -> bool:
	if not _unlocked():
		return false
	var reacted := false
	if "grow" in tags and not Game.garden.is_empty(index):
		var amount := 0.25 * float(result.get("power", 1.0))
		if "grow_strong" in tags:
			amount = 0.6
		reacted = Game.garden_grow(index, amount) or reacted
	if "nature_sync" in tags:
		Game.garden.water(index)
		reacted = true
	if "rune_protect" in tags:
		Game.garden.protect(index, 3.0)
		Game.garden.water(index)
		reacted = true
	if "pollinate" in tags and Game.garden.pollinate(index):
		say("O pólen dança: a próxima colheita deste canteiro revelará um segredo.", "discovery")
		reacted = true
	if "identify" in tags and not Game.garden.is_empty(index):
		Game.identify_ingredient(DataRegistry.plants[Game.garden.plot(index).plant].produces)
		reacted = true
	if reacted:
		EventBus.garden_changed.emit()
	return reacted


func refresh_state() -> void:
	if _plant_root == null:
		return
	var unlocked := _unlocked()
	_soil.material_override = Toon.mat(Color("#4a3426") if unlocked else Color("#6b5a48"))
	var pl := Game.garden.plot(index)
	_water_ring.visible = unlocked and float(pl.water) > 0.2
	_rune_ring.visible = unlocked and float(pl.protected_days) > 0.0
	var stage := -1
	if unlocked and pl.plant != "":
		stage = mini(3, int(float(pl.growth) * 3.0))
	var key := "%s|%d|%s" % [pl.plant, stage, str(unlocked)]
	_ready_glow.light_energy = 0.8 if stage == 3 else 0.0
	if key == _last_key:
		return
	_last_key = key
	for c in _plant_root.get_children():
		c.queue_free()
	if stage < 0:
		return
	var p: Dictionary = DataRegistry.plants[pl.plant]
	_build_plant(p, stage)


func _build_plant(p: Dictionary, stage: int) -> void:
	var c := Color(p.color)
	var leaf := Toon.mat(Color("#5fb85a"), {"rim": 0.4, "outline": 0.008})
	var s: float = [0.35, 0.6, 0.85, 1.0][stage]
	for k in 4:
		var off := Vector3((k % 2) * 0.6 - 0.3, 0, floorf(k / 2.0) * 0.6 - 0.3)
		var root := MeshKit.pivot(_plant_root, off)
		root.scale = Vector3.ONE * s
		root.rotation.y = k * 1.3
		if stage == 0:
			MeshKit.part(root, MeshKit.sphere(0.06, 6, 4), leaf, Vector3(0, 0.05, 0), Vector3.ZERO, Vector3(1.0, 1.6, 1.0))
			continue
		match p.shape:
			"rosette", "clover", "moss":
				for i in 5:
					var a := i * TAU / 5.0
					MeshKit.part(root, MeshKit.sphere(0.1, 6, 4), leaf if stage < 3 else Toon.mat(c, {"rim": 0.4}), Vector3(sin(a) * 0.1, 0.06, cos(a) * 0.1), Vector3.ZERO, Vector3(1.0, 0.35, 1.0))
			"mushroom":
				MeshKit.part(root, MeshKit.cylinder(0.03, 0.04, 0.18, 6), Toon.mat(Color("#f3e6cf")), Vector3(0, 0.09, 0))
				MeshKit.part(root, MeshKit.sphere(0.1, 8, 4, true), Toon.mat(c, {"emission": 0.4}), Vector3(0, 0.17, 0), Vector3.ZERO, Vector3(1.0, 0.7, 1.0))
			"root":
				MeshKit.part(root, MeshKit.sphere(0.12, 8, 4), leaf, Vector3(0, 0.12, 0), Vector3.ZERO, Vector3(0.8, 1.4, 0.8))
				if stage == 3:
					MeshKit.part(root, MeshKit.sphere(0.08, 6, 4), Toon.mat(c), Vector3(0, 0.03, 0))
			_:
				MeshKit.part(root, MeshKit.cylinder(0.012, 0.016, 0.3, 4), leaf, Vector3(0, 0.15, 0))
				MeshKit.part(root, MeshKit.sphere(0.09, 6, 4), leaf, Vector3(0, 0.08, 0), Vector3.ZERO, Vector3(1.3, 0.5, 1.3))
				if stage >= 2:
					MeshKit.part(root, MeshKit.sphere(0.07 if stage == 3 else 0.04, 8, 4), Toon.mat(c, {"emission": 0.5 if stage == 3 else 0.0}), Vector3(0, 0.32, 0))


func _process(delta: float) -> void:
	_t += delta
	if _rune_ring and _rune_ring.visible:
		_rune_ring.rotation.y += delta * 0.5
