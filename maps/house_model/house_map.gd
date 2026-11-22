extends Node3D

## Mapa jugable con la casa descargada (CC0, ver CREDITS.md). Colisión por malla del modelo,
## piso y hasta 7 NPC. El jugador y la luz vienen de house_map.tscn.
const BasicNpc = preload("res://npc/basic_npc.gd")
const MAX_NPCS := 7
const HOUSE := preload("res://maps/house_model/house.glb")


func _ready() -> void:
	var house := HOUSE.instantiate() as Node3D
	add_child(house)
	for mi in house.find_children("*", "MeshInstance3D", true, false):
		(mi as MeshInstance3D).create_trimesh_collision()
	_add_ground()
	_spawn_npcs()


func _add_ground() -> void:
	var body := StaticBody3D.new()
	body.name = "Ground"
	var shape := BoxShape3D.new()
	shape.size = Vector3(60, 0.5, 60)
	var cs := CollisionShape3D.new()
	cs.shape = shape
	body.add_child(cs)
	body.position = Vector3(0, -0.25, 0)
	add_child(body)


func _spawn_npcs() -> void:
	var spawn_points: Array = [
		Vector3(2, 0.5, 2), Vector3(-3, 0.5, -1), Vector3(-2.5, 0.5, 2.5),
		Vector3(2.5, 0.5, -2.5), Vector3(0, 0.5, -3), Vector3(-1, 0.5, 3), Vector3(3, 0.5, 0),
	].slice(0, MAX_NPCS)
	var configs: Array = [
		{"id": "npc_armed_1", "role": "hostile", "armed": true},
		{"id": "npc_civil_1", "role": "civilian"},
		{"id": "npc_armed_2", "role": "hostile", "armed": true},
		{"id": "npc_civil_2", "role": "civilian"},
		{"id": "npc_armed_3", "role": "hostile", "armed": true},
		{"id": "npc_civil_3", "role": "civilian"},
		{"id": "npc_armed_4", "role": "hostile", "armed": true},
	]
	var eye := get_node_or_null("VRPlayer/CharacterBody3D/Origin/Camera") as Node3D
	for i in spawn_points.size():
		var npc: Node3D = BasicNpc.spawn(self, spawn_points[i], configs[i % configs.size()])
		if npc != null and eye != null:
			npc.set_target(eye)
