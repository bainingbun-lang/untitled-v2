class_name Sandbox
extends Node3D

const RemoteLog = preload("res://debug/remote_log.gd")

const MapWorldBuilder = preload("res://maps/map_world_builder.gd")
const HouseBuilder = preload("res://maps/house_builder.gd")
const BasicNpc = preload("res://npc/basic_npc.gd")
const VrWeaponHand = preload("res://weapons/vr_weapon_hand.gd")
const GameConfig = preload("res://storage/game_config.gd")
const FunctionPickup = preload("res://grab/function_pickup.gd")
const InventoryScript = preload("res://inventory/inventory.gd")


var _map_ok: bool = false
var _npcs_ok: bool = false
var _weapon_ok: bool = false
var _weapon_hand: VrWeaponHand = null
var _weapon_pickable: Node3D = null


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
		Vector3(0, 0.5, -3),
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
	var eye := get_node_or_null("VRPlayer/CharacterBody3D/Origin/Camera") as Node3D
	
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


func _equip_weapon() -> void:
	var player: Node3D = get_tree().get_first_node_in_group("player") as Node3D
	if player == null:
		player = get_node_or_null("VRPlayer") as Node3D
	if player == null:
		player = get_node_or_null("CharacterBody3D") as Node3D

	if player == null:
		push_warning("Sandbox: no se encontró jugador (VRPlayer/CharacterBody3D)")
		_weapon_ok = false
		return

	var controller := player.get_node_or_null("CharacterBody3D/Origin/RightController") as XRController3D
	if controller == null:
		controller = player.get_node_or_null("RightHand") as XRController3D
	if controller == null:
		push_warning("Sandbox: no se encontró RightController (XRController3D)")
		_weapon_ok = false
		return

	var hand_node := controller.get_node_or_null("VrWeaponHand")
	if hand_node is VrWeaponHand:
		_weapon_hand = hand_node
	else:
		_weapon_hand = VrWeaponHand.new()
		_weapon_hand.name = "VrWeaponHand"
		_weapon_hand.hand = "right"
		_weapon_hand.auto_process = true
		controller.add_child(_weapon_hand)

	var pickup_node := controller.get_node_or_null("WeaponPickup")
	var pickup: FunctionPickup
	if pickup_node is FunctionPickup:
		pickup = pickup_node
	else:
		pickup = FunctionPickup.new()
		pickup.name = "WeaponPickup"
		controller.add_child(pickup)
	pickup.set_controller(controller)

	_weapon_pickable = _create_weapon_ak(player)
	if not is_instance_valid(_weapon_pickable):
		push_warning("Sandbox: AK47 no válido")
		_weapon_ok = false
		return

	if not pickup.has_picked_up.is_connected(_on_weapon_picked_up):
		pickup.has_picked_up.connect(_on_weapon_picked_up)
	if not pickup.has_dropped.is_connected(_on_weapon_dropped):
		pickup.has_dropped.connect(_on_weapon_dropped)

	var origin := controller.get_parent()
	var left := origin.get_node_or_null("LeftController") as XRController3D
	var holster := Holster.new()
	holster.controller = controller
	holster.weapon = _weapon_pickable
	origin.add_child(holster)
	holster.position = Vector3(0.25, 0.8, 0.0)
	# Funda visible en la cadera: sin esto el arma enfundada parece flotar.
	var pouch := MeshInstance3D.new()
	var pouch_mesh := BoxMesh.new()
	pouch_mesh.size = Vector3(0.1, 0.14, 0.06)
	pouch.mesh = pouch_mesh
	var leather := StandardMaterial3D.new()
	leather.albedo_color = Color(0.13, 0.1, 0.08)
	leather.roughness = 0.9
	pouch.material_override = leather
	holster.add_child(pouch)
	_weapon_pickable.global_position = holster.global_position

	if left != null:
		var inventory := InventoryScript.new()
		inventory.name = "Inventory"
		add_child(inventory)
		inventory.setup(controller, left)
		inventory.changed.connect(func() -> void:
			var th: Node = inventory.right.weapon.get_node_or_null("TwoHanded") if is_instance_valid(inventory.right.weapon) else null
			if th:
				th.off_hand = left)
		inventory.add(GameConfig.left_pocket)
		holster.drawn.connect(func() -> void:
			if inventory.right.id.is_empty() and not inventory.equip_right(GameConfig.right_pocket):
				inventory.hold_existing(inventory.right, GameConfig.right_pocket, _weapon_pickable))
		controller.button_released.connect(func(action: String) -> void:
			if action == "grip_click" and inventory.right.id == GameConfig.right_pocket \
					and controller.global_position.distance_to(holster.global_position) < holster.radius:
				inventory.stow(inventory.right))
		# Bolsillo izquierdo: se saca con la mano izquierda y se guarda apretando el grip cerca de la cadera.
		var left_holster := Holster.new()
		left_holster.controller = left
		origin.add_child(left_holster)
		left_holster.position = Vector3(-0.25, 0.8, 0.0)
		var left_pouch := MeshInstance3D.new()
		var left_pouch_mesh := BoxMesh.new()
		left_pouch_mesh.size = Vector3(0.1, 0.14, 0.06)
		left_pouch.mesh = left_pouch_mesh
		var left_leather := StandardMaterial3D.new()
		left_leather.albedo_color = Color(0.13, 0.1, 0.08)
		left_leather.roughness = 0.9
		left_pouch.material_override = left_leather
		left_holster.add_child(left_pouch)
		left_holster.drawn.connect(func() -> void:
			if inventory.left.id.is_empty():
				inventory.equip_left(GameConfig.left_pocket))
		left.button_released.connect(func(action: String) -> void:
			if action == "grip_click" and not inventory.left.id.is_empty() \
					and left.global_position.distance_to(left_holster.global_position) < left_holster.radius:
				inventory.stow(inventory.left))

	_weapon_ok = true
	print("Sandbox: AK47 en funda, grip en la funda para sacarla")


func _create_weapon_ak(player: Node3D) -> Node3D:
	var weapon := (load(inventory_scene(GameConfig.right_pocket)) as PackedScene).instantiate() as Node3D
	add_child(weapon)
	weapon.global_position = player.global_position + Vector3(0.35, 1.0, -0.25)
	return weapon


func _on_weapon_picked_up(what: Node3D) -> void:
	if not is_instance_valid(_weapon_hand) or not is_instance_valid(what):
		return
	if _weapon_hand.weapon_id.is_empty():
		_weapon_hand.weapon_id = "pistol"
		var pose: Transform3D = _weapon_hand._pose("right")
		_weapon_hand._aim_dir = VrWeaponHand.aim_direction(pose, Transform3D.IDENTITY, false)
		_weapon_hand.weapon_taken.emit("pistol", "right")
	print("Sandbox: arma agarrada con grip")


func _on_weapon_dropped() -> void:
	if is_instance_valid(_weapon_hand) and _weapon_hand.weapon_id == "pistol":
		_weapon_hand.weapon_id = ""
		_weapon_hand._two_hand = false
		_weapon_hand.weapon_stowed.emit("pistol", "right")
	print("Sandbox: arma soltada al liberar grip")


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


## Ruta de escena de un arma por id (misma tabla que el inventario).
static func inventory_scene(id: String) -> String:
	var table := {"ak47": "res://weapons/ak47.tscn", "pistol": "res://weapons/pistol.tscn", "knife": "res://weapons/knife.tscn", "sniper": "res://weapons/sniper.tscn", "machete": "res://weapons/machete.tscn", "shotgun": "res://weapons/shotgun.tscn", "barrett": "res://weapons/barrett.tscn", "smg": "res://weapons/smg.tscn", "revolver": "res://weapons/revolver.tscn", "fusil": "res://weapons/fusil.tscn", "pdw": "res://weapons/pdw.tscn", "tanto": "res://weapons/tanto.tscn", "hacha": "res://weapons/hacha.tscn"}
	return str(table.get(id, "res://weapons/ak47.tscn"))
