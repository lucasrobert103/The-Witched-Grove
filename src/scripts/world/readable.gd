class_name Readable
extends Interactable
## Página, inscrição ou tabuleta no mundo. Pode exigir uma flag para aparecer.

var page_id: String = ""
var requires_flag: String = ""
var style: String = "scroll"     # scroll, pedestal, carving, stone
var _visual: Node3D
var _t := 0.0


func setup(p_page: String, p_style: String = "scroll", p_flag: String = "") -> void:
	page_id = p_page
	style = p_style
	requires_flag = p_flag
	radius = 2.0
	marker_height = 1.4


func _ready() -> void:
	_visual = MeshKit.pivot(self)
	var paper := Toon.mat(Color("#f3e6c4"), {"rim": 0.3, "outline": 0.01})
	var stone := Toon.mat(Color("#8a8796"), {"surface": "stone", "outline": 0.02})
	match style:
		"scroll":
			MeshKit.part(self, MeshKit.cylinder(0.25, 0.32, 0.9, 8), stone, Vector3(0, 0.45, 0))
			MeshKit.part(_visual, MeshKit.cylinder(0.05, 0.05, 0.4, 8), paper, Vector3(0, 1.05, 0), Vector3(0, 0, 90))
			MeshKit.part(_visual, MeshKit.box(Vector3(0.36, 0.01, 0.28)), paper, Vector3(0, 1.0, -0.12), Vector3(-25, 0, 0))
			MeshKit.light(_visual, Color("#fff3b0"), 0.5, 2.0, Vector3(0, 1.3, 0))
		"carving":
			MeshKit.part(_visual, MeshKit.box(Vector3(0.6, 0.5, 0.05)), Toon.glow(Color("#c9a5ff"), 0.8), Vector3(0, 1.3, 0))
		"stone":
			MeshKit.part(self, MeshKit.box(Vector3(0.9, 1.2, 0.25)), stone, Vector3(0, 0.6, 0))
			MeshKit.part(_visual, MeshKit.box(Vector3(0.6, 0.7, 0.02)), Toon.glow(Color("#c9a5ff"), 0.9), Vector3(0, 0.7, -0.14))
		"sign":
			var wood := Toon.mat(Color("#8a5a36"), {"surface": "wood", "outline": 0.015})
			MeshKit.part(self, MeshKit.cylinder(0.05, 0.06, 1.4, 6), wood, Vector3(0, 0.7, 0))
			MeshKit.part(_visual, MeshKit.box(Vector3(0.8, 0.5, 0.06)), wood, Vector3(0, 1.3, 0))
			MeshKit.part(_visual, MeshKit.box(Vector3(0.6, 0.3, 0.01)), paper, Vector3(0, 1.3, -0.04))
		"book":
			MeshKit.part(_visual, MeshKit.box(Vector3(0.3, 0.06, 0.22)), Toon.mat(Color("#7a2f3a"), {"outline": 0.01}), Vector3(0, 0.12, 0), Vector3(0, 25, 0))
			MeshKit.light(_visual, Color("#fff3b0"), 0.6, 2.0, Vector3(0, 0.5, 0))
	refresh_state()


func can_interact() -> bool:
	return visible


func get_prompt() -> String:
	var page: Dictionary = DataRegistry.pages.get(page_id, {})
	var n := Game.grimoire.times_read(page_id)
	if n == 0:
		return "Ler: %s" % page.get("title", "???")
	return "Reler (%d/5): %s" % [mini(n, 5), page.get("title", "")]


func interact(_player: Node) -> void:
	EventBus.panel_requested.emit("reader", {"page": page_id})


func refresh_state() -> void:
	visible = requires_flag == "" or Game.has_flag(requires_flag)


func _process(delta: float) -> void:
	_t += delta
	if _visual and style in ["scroll", "book"]:
		_visual.position.y = sin(_t * 1.8) * 0.04
