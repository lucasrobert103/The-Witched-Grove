class_name InteriorRoom
extends Node3D
## Cômodo interior visto "em corte": as paredes viradas para a câmera somem,
## como numa casa de bonecas, para mostrar a cama, as estantes e tudo mais.
## Fica fora do mapa (x > 300) e é acessado pelas portas das casas.

const WALL_LAYER := 2

var room_id: String = ""
var title: String = ""
var size := Vector3(10, 3.4, 8)
var spawn: Vector3                 # onde a protagonista aparece ao entrar
var exit_outside: Vector3          # onde ela aparece ao sair
var exit_yaw: float = 0.0
var floor_color := Color("#9a6a3e")
var wall_color := Color("#f1e3c6")
var _walls: Array = []             # [{"node": Node3D, "normal": Vector3, "center": Vector3}]
var _body: StaticBody3D


func setup(p_id: String, p_title: String, p_size: Vector3, p_floor: Color, p_wall: Color) -> void:
	room_id = p_id
	title = p_title
	size = p_size
	floor_color = p_floor
	wall_color = p_wall


func _ready() -> void:
	add_to_group("interior")
	_body = StaticBody3D.new()
	_body.collision_layer = WALL_LAYER
	_body.collision_mask = 0
	add_child(_body)
	var hw := size.x * 0.5
	var hd := size.z * 0.5
	# piso (tábuas) e colisão do piso na camada 1
	var floor_body := StaticBody3D.new()
	add_child(floor_body)
	var fcs := CollisionShape3D.new()
	var fbox := BoxShape3D.new()
	fbox.size = Vector3(size.x, 0.4, size.z)
	fcs.shape = fbox
	fcs.position = Vector3(0, -0.2, 0)
	floor_body.add_child(fcs)
	var plank_count := int(size.x / 0.5)
	for i in plank_count:
		var c := floor_color.darkened(0.06 * (i % 3))
		MeshKit.part(self, MeshKit.box(Vector3(0.48, 0.06, size.z)), Toon.mat(c, {"surface": "wood"}), Vector3(-hw + 0.25 + i * 0.5, -0.03, 0), Vector3.ZERO, Vector3.ONE, false)
	# paredes (planos virados para dentro) + rodapé (sem vigas soltas: a câmera vê de cima)
	_wall(Vector3(0, 0, -hd), Vector3(0, 0, 1), size.x, 0.0)
	_wall(Vector3(0, 0, hd), Vector3(0, 0, -1), size.x, 180.0)
	_wall(Vector3(-hw, 0, 0), Vector3(1, 0, 0), size.z, 90.0)
	_wall(Vector3(hw, 0, 0), Vector3(-1, 0, 0), size.z, -90.0)
	var ceil := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(size.x, size.z)
	ceil.mesh = pm
	ceil.material_override = Toon.mat(wall_color.darkened(0.25))
	ceil.position = Vector3(0, size.y, 0)
	ceil.rotation_degrees = Vector3(180, 0, 0)
	ceil.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(ceil)


func _wall(center: Vector3, normal: Vector3, length: float, rot_y: float) -> void:
	var g := Node3D.new()
	g.position = center
	g.rotation_degrees.y = rot_y
	add_child(g)
	var q := MeshInstance3D.new()
	var qm := QuadMesh.new()
	qm.size = Vector2(length, size.y)
	q.mesh = qm
	q.material_override = Toon.mat(wall_color, {"surface": "plaster"})
	q.position = Vector3(0, size.y * 0.5, 0)
	q.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	g.add_child(q)
	# rodapé e viga superior pertencem à parede (somem junto no corte)
	MeshKit.part(g, MeshKit.box(Vector3(length, 0.18, 0.06)), Toon.mat(Color("#6b4630"), {"surface": "wood"}), Vector3(0, 0.09, 0.03), Vector3.ZERO, Vector3.ONE, false)
	MeshKit.part(g, MeshKit.box(Vector3(length, 0.1, 0.06)), Toon.mat(wall_color.darkened(0.15)), Vector3(0, 1.0, 0.03), Vector3.ZERO, Vector3.ONE, false)
	for k in int(length / 2.2) + 1:
		MeshKit.part(g, MeshKit.box(Vector3(0.16, size.y, 0.1)), Toon.mat(Color("#6b4630"), {"surface": "wood", "outline": 0.015}), Vector3(-length * 0.5 + k * length / maxf(1.0, floorf(length / 2.2)), size.y * 0.5, 0.05), Vector3.ZERO, Vector3.ONE, false)
	var cs := CollisionShape3D.new()
	var b := BoxShape3D.new()
	b.size = Vector3(length + 0.6, size.y + 1.0, 0.4)
	cs.shape = b
	cs.position = center + Vector3(0, size.y * 0.5, 0) - normal * 0.2
	cs.rotation_degrees.y = rot_y
	_body.add_child(cs)
	_walls.append({"node": g, "normal": normal, "center": center})


## Nó de decoração preso a uma parede (some junto com ela quando a câmera está do lado de fora).
## side: "n", "s", "w", "e"
func wall_node(side: String) -> Node3D:
	var idx := ["n", "s", "w", "e"].find(side)
	return _walls[idx].node


## Atualiza o corte: esconde paredes entre a câmera e o cômodo.
func update_cutaway(cam_pos: Vector3) -> void:
	for w in _walls:
		var to_cam: Vector3 = cam_pos - (global_position + w.center)
		w.node.visible = to_cam.dot(w.normal) > -0.5
