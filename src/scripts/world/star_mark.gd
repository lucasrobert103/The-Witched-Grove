class_name StarMark
extends Interactable
## Marca estelar dos Primeiros: só aparece à noite sob luz estelar (ou com Visão Noturna).

var mark_index: int = 1
var _glyph: Node3D
var _light: OmniLight3D
var _t := 0.0


func setup(i: int) -> void:
	mark_index = i
	radius = 2.4
	marker_height = 1.8


func _ready() -> void:
	MeshKit.part(self, MeshKit.rock(90 + mark_index, 0.9), Toon.mat(Color("#7a7890"), {"outline": 0.02}), Vector3(0, 0.5, 0))
	_glyph = MeshKit.pivot(self, Vector3(0, 0.95, -0.72))
	var g := Toon.glow(Color("#bcd4ff"), 2.5)
	MeshKit.part(_glyph, MeshKit.star(0.28, 0.12, 0.03), g)
	MeshKit.part(_glyph, MeshKit.torus(0.34, 0.38, 24, 4), g, Vector3.ZERO, Vector3(90, 0, 0))
	_light = MeshKit.light(self, Color("#bcd4ff"), 1.2, 4.0, Vector3(0, 1.2, -1.2))


func flag() -> String:
	return "marca_estelar_%d" % mark_index


func revealed() -> bool:
	if Game.has_buff("reveal"):
		return true
	var lit := Game.has_buff("light_orb") or Game.has_buff("glow")
	return Game.clock.night_factor() > 0.6 and lit


func can_interact() -> bool:
	return revealed() and not Game.has_flag(flag())


func get_prompt() -> String:
	return "Estudar a marca estelar"


func interact(_player: Node) -> void:
	Game.set_flag(flag())
	Game.add_school_xp("astral", 3.0)
	Game.add_research("misterio_ondina", 5.0)
	Game.discover("marca", flag(), "Marca estelar %d de 3: uma constelação gravada na pedra aponta para o Portal das Ruínas." % mark_index)
	AudioManager.play_sfx("discovery")


func _process(delta: float) -> void:
	_t += delta
	var on := revealed() or Game.has_flag(flag())
	var target := 1.0 if revealed() else (0.15 if Game.has_flag(flag()) else 0.0)
	_glyph.visible = on
	_light.light_energy = lerpf(_light.light_energy, target * (1.0 + sin(_t * 2.0) * 0.2), 1.0 - exp(-4.0 * delta))
	_glyph.rotation.z = sin(_t * 0.7) * 0.1
