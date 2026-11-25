extends SceneTree

const VrSim = preload("res://tools/vr_sim/vr_sim.gd")
var _fails := 0


func _expect(ok: bool, msg: String) -> void:
	print(("PASS: " if ok else "FAIL: ") + msg)
	if not ok:
		_fails += 1


func _init() -> void:
	await process_frame
	var sim = VrSim.new(self)
	var sb = (load("res://sandbox/sandbox.tscn") as PackedScene).instantiate()
	root.add_child(sb)
	await sim.attach(sb)
	await sim.frames(40)
	_expect(sim.origin.holster_back_left != null and sim.origin.holster_back_right != null, "hay 4 fundas (2 en la espalda)")
	var npc: Node3D = get_first_node_in_group("basic_npc")
	npc.set("armed", true)
	npc.global_position = sim.origin.global_position + Vector3(0.0, 0.0, 1.5)
	await sim.frames(5)
	npc.take_damage(10000.0, npc.global_position + Vector3(0, 1, 0), null, "")
	await sim.frames(90)
	var gun = sb.get_node_or_null("Loot_ak47")
	var mag = sb.get_node_or_null("Loot_mag_ak47")
	_expect(gun != null, "el NPC muerto suelta su arma")
	_expect(mag != null and mag.is_in_group("mag_ak47") and mag.rounds == 30, "suelta un cargador de AK con 30 balas")
	if gun == null or mag == null:
		quit(1)
		return
	_expect(gun.global_position.y < 1.0, "el arma cayo al suelo (y=%.2f)" % gun.global_position.y)
	var rp = sim.origin.get_node("RightHand/CollisionHandRight/FunctionPickup")
	var lp = sim.origin.get_node("LeftHand/CollisionHandLeft/FunctionPickup")
	await sim.reach(&"right_hand", gun.global_position, 0.3)
	await sim.squeeze_grip(&"right_hand", 1.0)
	await sim.frames(8)
	_expect(gun.is_picked_up() and rp.picked_up_object == gun, "se puede agarrar el arma del muerto")
	for _i in 180: # el cargador de repuesto puede seguir rodando tras caer
		if mag.linear_velocity.length() < 0.05:
			break
		await sim.frames(1)
	await sim.reach(&"left_hand", mag.global_position, 0.3)
	await sim.squeeze_grip(&"left_hand", 1.0)
	await sim.frames(8)
	_expect(mag.is_picked_up() and lp.picked_up_object == mag, "se puede agarrar su cargador")
	print("RESULTADO: %s (%d fallos)" % ["OK" if _fails == 0 else "FALLO", _fails])
	quit(0 if _fails == 0 else 1)
