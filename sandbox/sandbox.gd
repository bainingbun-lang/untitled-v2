class_name Sandbox
extends Node3D


const MapWorldBuilder = preload("res://maps/map_world_builder.gd")
const BasicNpc = preload("res://npc/basic_npc.gd")
const VrWeaponHand = preload("res://weapons/vr_weapon_hand.gd")
const FunctionPickup = preload("res://grab/function_pickup.gd")
const WeaponPickable = preload("res://grab/pickable.gd")


var _map_ok: bool = false
var _npcs_ok: bool = false
var _weapon_ok: bool = false
var _weapon_hand: VrWeaponHand = null
var _weapon_pickable: WeaponPickable = null


func _ready() -> void:
	_build_map()
	_spawn_npcs()
	_equip_weapon()
	_print_summary()


func _build_map() -> void:
	var meta: Dictionary = {
		"name": "sandbox",
		"spawns": [
			{"x": 0, "y": 0, "z": 0},
			{"x": 5, "y": 0, "z": 5},
			{"x": -5, "y": 0, "z": -5}
		],
		"time_of_day": "atardecer",
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


func _spawn_npcs() -> void:
	var spawn_points: Array = [
		Vector3(2, 0.5, 2),
		Vector3(-3, 0.5, -1)
	]
	
	var count: int = 0
	for pos in spawn_points:
		var npc: Node3D = BasicNpc.spawn(self, pos, {"role": "hostile"})
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

	_weapon_pickable = _create_weapon_pickable(player)
	if not is_instance_valid(_weapon_pickable):
		push_warning("Sandbox: WeaponPickable no válido")
		_weapon_ok = false
		return

	if not pickup.has_picked_up.is_connected(_on_weapon_picked_up):
		pickup.has_picked_up.connect(_on_weapon_picked_up)
	if not pickup.has_dropped.is_connected(_on_weapon_dropped):
		pickup.has_dropped.connect(_on_weapon_dropped)

	_weapon_ok = true
	print("Sandbox: arma lista para agarrar con grip (WeaponPickup -> WeaponPickable)")


func _create_weapon_pickable(player: Node3D) -> WeaponPickable:
	var weapon := WeaponPickable.new()
	weapon.name = "WeaponPickable"
	weapon.set_meta("weapon_id", "pistol")
	weapon.collision_layer = 4
	weapon.collision_mask = 1
	weapon.add_to_group("weapon_pickup")
	weapon.add_to_group("grabbable")
	var visual := Node3D.new()
	visual.name = "Visual"
	var body := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(0.05, 0.07, 0.24)
	body.mesh = box
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(0.16, 0.18, 0.20)
	body.material_override = material
	visual.add_child(body)
	weapon.add_child(visual)
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