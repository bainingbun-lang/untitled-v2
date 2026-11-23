class_name Sandbox
extends Node3D

const RemoteLog = preload("res://debug/remote_log.gd")

const MapWorldBuilder = preload("res://maps/map_world_builder.gd")
const HouseBuilder = preload("res://maps/house_builder.gd")
const BasicNpc = preload("res://npc/basic_npc.gd")


var _map_ok: bool = false
var _npcs_ok: bool = false
var _weapon_ok: bool = false


func _ready() -> void:
	RemoteLog.crumb("SANDBOX: ready start")
	_build_house()
	await get_tree().physics_frame
	_build_map()
	_spawn_npcs()
	_equip_weapon()
	_print_summary()
	RemoteLog.crumb("SANDBOX: ready end")


func _build_house() -> void:
	var result: Dictionary = HouseBuilder.build_two_story_house(Vector3.ZERO, self)
	
	if result.get("ok", false):
		print("Sandbox: casa 2 pisos construida OK, nodos: ", result.get("node_count", 0))
	else:
		var errs: Array = result.get("errors", [])
		for e in errs:
			push_warning("Sandbox: casa fallo - ", e)
		print("Sandbox: casa FALLÓ - ", errs)


func _build_map() -> void:
	var meta: Dictionary = {
		"name": "sandbox",
		"spawn_points": [
			{"x": 0, "y": 0, "z": 0},
			{"x": 5, "y": 0, "z": 5},
			{"x": -5, "y": 0, "z": -5}
		],
		"time_of_day": "dia",
		"theme": ""
	}
	
	var result: Dictionary = MapWorldBuilder.build(meta, self)
	
	if result.get("ok", false):
		_map_ok = true
		print("Sandbox: mapa construido OK, nodos: ", result.get("node_count", 0))
	else:
		_map_ok = false
		var errs: Array = result.get("errors", [])
		for e in errs:
			push_warning("Sandbox: mapa fallo - ", e)
		print("Sandbox: mapa FALLÓ - ", errs)


## Máximo de NPCs en la casa de prueba (pedido del usuario).
const MAX_NPCS := 7

func _spawn_npcs() -> void:
	# Ground-floor points inside the 8x8 house (center at origin), away from the stairs.
	var spawn_points: Array = [
		Vector3(2, 0.5, 2),
		Vector3(-3, 0.5, -1),
		Vector3(-2.5, 0.5, 2.5),
		Vector3(2.5, 0.5, -2.5),
		Vector3(-1.9, 0.5, -3.3),
		Vector3(-1, 0.5, 3),
		Vector3(3, 0.5, 0),
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
	var eye := get_node_or_null("XRPlayer/XRCamera3D") as Node3D
	
	var count: int = 0
	for i in spawn_points.size():
		var pos: Vector3 = spawn_points[i]
		var npc: Node3D = BasicNpc.spawn(self, pos, configs[i % configs.size()])
		if npc != null and eye != null:
			npc.set_target(eye)
		if npc != null and is_instance_valid(npc):
			count += 1
		else:
			push_warning("Sandbox: NPC spawn fallo en ", pos)
	
	if count == spawn_points.size():
		_npcs_ok = true
		print("Sandbox: ", count, " NPCs spawneados OK")
	else:
		_npcs_ok = false
		push_warning("Sandbox: solo ", count, " de ", spawn_points.size(), " NPCs spawneados")


const TABLE_Z := -2.8
const TABLE_TOP := 0.9
## Armas xr-tools sobre la mesa: id, x. Cada una lleva un cargador de repuesto delante.
const TABLE_WEAPONS := [["pistol", -0.55], ["ak47", -0.2], ["shotgun", 0.2], ["smg", 0.55]]


## Mesa frente al jugador con armas agarrables y un cargador de repuesto de cada una.
func _equip_weapon() -> void:
	var table := StaticBody3D.new()
	table.name = "WeaponTable"
	var cs := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(1.8, TABLE_TOP, 1.2)
	cs.shape = box
	table.add_child(cs)
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = box.size
	mi.mesh = bm
	var wood := StandardMaterial3D.new()
	wood.albedo_color = Color(0.45, 0.32, 0.2)
	mi.material_override = wood
	table.add_child(mi)
	add_child(table)
	table.global_position = Vector3(0.0, TABLE_TOP / 2.0, TABLE_Z)
	var count := 0
	for w in TABLE_WEAPONS:
		var gun := (load("res://weapons/xr_%s.tscn" % w[0]) as PackedScene).instantiate() as Node3D
		gun.name = "Table_" + w[0]
		add_child(gun)
		gun.global_position = Vector3(w[1], TABLE_TOP + 0.08, TABLE_Z)
		var spare := gun.get_node("Magazine").duplicate() as Node3D
		spare.name = "Spare_" + w[0]
		add_child(spare)
		spare.global_position = Vector3(w[1], TABLE_TOP + 0.08, TABLE_Z + 0.45)
		count += 1
	_weapon_ok = count == TABLE_WEAPONS.size()
	print("Sandbox: mesa con %d armas xr-tools y cargadores de repuesto" % count)


func _print_summary() -> void:
	print("=== SANDBOX RESUMEN ===")
	print("Mapa: ", "OK" if _map_ok else "FALLÓ")
	print("NPCs: ", "OK" if _npcs_ok else "FALLÓ")
	print("Arma: ", "OK" if _weapon_ok else "FALLÓ")
	print("========================")


func _process(_delta: float) -> void:
	var frame := Engine.get_frames_drawn()
	if frame == 1:
		RemoteLog.crumb("SANDBOX: frame 1")
	elif frame == 60:
		RemoteLog.crumb("SANDBOX: frame 60")
