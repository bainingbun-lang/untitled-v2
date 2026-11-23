extends SceneTree

## Jugador xr-tools (player/xr_player.tscn): estructura, texturas de mano desde ZIP y agarre de una pistola.
## Ejecutar: godot --headless --path . --script res://tests/test_xr_player.gd
var _fails := 0


func _init() -> void:
	await process_frame
	var packed := load("res://player/xr_player.tscn") as PackedScene
	_expect(packed != null, "la escena carga")
	if packed == null:
		_end()
		return
	for t in [[&"left_hand", XRPositionalTracker.TRACKER_HAND_LEFT], [&"right_hand", XRPositionalTracker.TRACKER_HAND_RIGHT]]:
		var tr := XRControllerTracker.new() # sin runtime OpenXR: registra los trackers a mano
		tr.type = XRServer.TRACKER_CONTROLLER
		tr.name = t[0]
		tr.hand = t[1]
		XRServer.add_tracker(tr)
	var p = packed.instantiate()
	root.add_child(p)
	for i in 3:
		await physics_frame
	_expect(p.is_in_group("player"), "grupo player")
	var lc = p.get_left_controller()
	var rc = p.get_right_controller()
	_expect(lc is XRController3D and rc is XRController3D, "manos XRController3D")
	_expect(p.get_camera() is XRCamera3D, "cámara XRCamera3D")
	_expect(lc.tracker == &"left_hand" and rc.tracker == &"right_hand", "trackers left_hand/right_hand")
	var lp = p.get_node("LeftHand/CollisionHandLeft/FunctionPickup")
	var rp = p.get_node("RightHand/CollisionHandRight/FunctionPickup")
	_expect(lp.is_xr_class("XRToolsFunctionPickup") and rp.is_xr_class("XRToolsFunctionPickup"), "FunctionPickup en ambas manos")
	_expect(p.get_node("PlayerBody").is_xr_class("XRToolsPlayerBody"), "PlayerBody")
	_expect(p.get_node("LeftHand/CollisionHandLeft/MovementDirect").is_xr_class("XRToolsMovementDirect"), "MovementDirect")
	_expect(p.get_node("RightHand/CollisionHandRight/MovementTurn").is_xr_class("XRToolsMovementTurn"), "MovementTurn")
	_expect(p.get_node("MovementSprint").is_xr_class("XRToolsMovementSprint"), "MovementSprint")

	for hand in [lc, rc]:
		var meshes: Array = hand.find_children("*", "MeshInstance3D", true, false)
		_expect(meshes.size() > 0, "%s: tiene mallas" % hand.name)
		for m in meshes:
			var mat := m.material_override as ORMMaterial3D
			_expect(mat != null and mat.albedo_texture != null and mat.albedo_texture.get_width() > 0,
				"%s/%s: albedo del zip" % [hand.name, m.name])
			_expect(mat != null and mat.orm_texture != null, "%s/%s: orm del zip" % [hand.name, m.name])

	rc.global_position = Vector3(0, 1, 0)
	var gun = (load("res://weapons/xr_pistol.tscn") as PackedScene).instantiate()
	root.add_child(gun)
	gun.global_position = rc.global_position + Vector3(0, 0, -0.05)
	for i in 3:
		await physics_frame
	gun.pick_up(rp)
	await physics_frame
	_expect(gun.is_picked_up(), "la pistola se agarra")
	rc.global_position = Vector3(0.5, 1.2, -0.3)
	for i in 30:
		await physics_frame
	var d: float = gun.global_position.distance_to(rp.global_position)
	_expect(d < 0.25, "la pistola sigue a la mano (dist %.3f)" % d)
	_end()


func _expect(ok: bool, msg: String) -> void:
	if not ok:
		_fails += 1
		print("FAIL: ", msg)


func _end() -> void:
	print("RESULTADO: %s (%d fallos)" % ["OK" if _fails == 0 else "FALLO", _fails])
	quit(0 if _fails == 0 else 1)
