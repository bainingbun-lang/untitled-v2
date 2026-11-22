extends Node3D

## Mapa jugable con la casa descargada (CC0, ver CREDITS.md). Colisión por malla del modelo,
## piso y hasta 7 NPC. El jugador y la luz vienen de house_map.tscn.
const NpcSpawner = preload("res://npc/npc_spawner.gd")
const MAX_NPCS := 7


func _ready() -> void:
	var house := _load_glb(model_path())
	if house == null:
		push_warning("Mapa: no se pudo cargar " + model_path())
		return
	add_child(house)
	for mi in house.find_children("*", "MeshInstance3D", true, false):
		(mi as MeshInstance3D).create_trimesh_collision()
	_add_ground()
	_spawn_npcs()


## Carga un .glb en tiempo de ejecución (funciona aunque no esté importado, y dentro del PCK en Android).
static func _load_glb(path: String) -> Node3D:
	var bytes := FileAccess.get_file_as_bytes(path)
	if bytes.is_empty():
		return null
	var gltf := GLTFDocument.new()
	var state := GLTFState.new()
	if gltf.append_from_buffer(bytes, "", state) != OK:
		return null
	return gltf.generate_scene(state) as Node3D


## Ruta del modelo del mapa; cada mapa descargado la sobrescribe.
func model_path() -> String:
	return "res://maps/house_model/house.glb"


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


## Reparto de NPC del mapa. Un mapa lo sobrescribe para poner su propia población.
func npc_spec() -> Array:
	return [
		{"id": "npc_armed", "role": "hostile", "armed": true, "count": 3},
		{"id": "npc_civil", "role": "civilian", "count": 4},
	]


func _spawn_npcs() -> void:
	var points: Array = [
		Vector3(2, 0.5, 2), Vector3(-3, 0.5, -1), Vector3(-2.5, 0.5, 2.5),
		Vector3(2.5, 0.5, -2.5), Vector3(0, 0.5, -3), Vector3(-1, 0.5, 3), Vector3(3, 0.5, 0),
	]
	var eye := get_node_or_null("VRPlayer/CharacterBody3D/Origin/Camera") as Node3D
	var spec := npc_spec()
	var total := 0
	for e in spec:
		total += int(e.get("count", 1))
	if total > MAX_NPCS:
		push_warning("Mapa: se pidieron %d NPC, el máximo es %d" % [total, MAX_NPCS])
	NpcSpawner.spawn(self, spec, points, eye)
