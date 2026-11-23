extends Node3D

## Mapa jugable con la casa descargada (CC0, ver CREDITS.md). Colisión por malla del modelo,
## piso y hasta 7 NPC. El jugador y la luz vienen de house_map.tscn.
const HouseBuilder = preload("res://maps/house_builder.gd")
const NpcSpawner = preload("res://npc/npc_spawner.gd")
const NpcReactions = preload("res://npc/npc_reactions.gd")
const MAX_NPCS := 7


func _ready() -> void:
	var house := _load_glb(model_path())
	if house == null:
		# Respaldo: si el modelo no carga (por ejemplo no se empaquetó), se arma la casa procedural
		# para que el mapa siempre tenga piso, paredes y NPC en vez de quedar vacío.
		push_warning("Mapa: no se pudo cargar " + model_path() + "; se usa la casa procedural")
		HouseBuilder.build_two_story_house(Vector3.ZERO, self)
		_model = get_node_or_null("HouseTwoStory") as Node3D
		_add_ground()
		_spawn_npcs()
		return
	add_child(house)
	_model = house
	house.scale = Vector3.ONE * model_scale()
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


## Escala del modelo. La casa de prueba mide ~2 m, así que se agranda a escala humana.
func model_scale() -> float:
	return 4.0


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


## Reparto de NPC del mapa. Un mapa puede sobrescribirlo; por defecto se calcula por área.
func npc_spec(total: int) -> Array:
	return NpcSpawner.default_spec(total)


## Piso del mapa como rectángulo (XZ) a partir de las mallas del modelo.
var _model: Node3D = null


func footprint() -> Array:
	var lo: Vector3 = Vector3(INF, INF, INF)
	var hi: Vector3 = Vector3(-INF, -INF, -INF)
	if _model == null:
		return [Vector2.ZERO, Vector2.ZERO]
	for mi in _model.find_children("*", "MeshInstance3D", true, false):
		var box: AABB = (mi as MeshInstance3D).global_transform * (mi as MeshInstance3D).get_aabb()
		lo = lo.min(box.position)
		hi = hi.max(box.position + box.size)
	return [Vector2(lo.x, lo.z), Vector2(hi.x, hi.z)]


func _spawn_npcs() -> void:
	await get_tree().physics_frame
	await get_tree().physics_frame
	var fp := footprint()
	var area: float = (fp[1].x - fp[0].x) * (fp[1].y - fp[0].y)
	var total := NpcSpawner.count_for_area(area)
	var space := get_world_3d().direct_space_state
	var points := NpcSpawner.floor_points(space, fp[0], fp[1], total, [])
	var eye := get_node_or_null("XRPlayer/XRCamera3D") as Node3D
	var spec := npc_spec(points.size())
	var made: Array = NpcSpawner.spawn(self, spec, points, eye)
	var rx := NpcReactions.new()
	add_child(rx)
	rx.setup(self, eye, made)
	print("Mapa: area %.0f m2, NPC pedidos %d, colocados %d" % [area, total, points.size()])
