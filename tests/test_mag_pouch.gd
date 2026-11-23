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
	for n in sb.get_children():
		if str(n.name).begins_with("Table_") or str(n.name).begins_with("Spare_"):
			n.free()
	var cfg = load("res://storage/game_config.gd")
	var wm = sim.origin.get_node("WeaponMenu")
	var pouch = sim.origin.get_node("Holsters/MagPouch")
	var lp = sim.origin.get_node("LeftHand/CollisionHandLeft/FunctionPickup")
	_expect(pouch != null, "el jugador tiene bolsa de cargadores en el cinturon")
	var gun = wm.give("right", "pistol")
	await sim.frames(10)
	_expect(gun != null, "pistola en la mano derecha")
	await sim.move_hand(&"right_hand", Vector3(0.3, -0.15, -0.55))
	await sim.frames(10)

	cfg.infinite_mags = true
	for i in 5:
		await sim.reach(&"left_hand", pouch.global_position, 0.2)
		await sim.frames(2)
		if sim.hand_world(&"left_hand").distance_to(pouch.global_position) < 0.1:
			break
	await sim.squeeze_grip(&"left_hand", 1.0)
	await sim.frames(8)
	var mag = lp.picked_up_object
	_expect(mag != null and mag.name.begins_with("PouchMag") and mag.is_in_group("mag_pistol"), "infinitos: agarrar en la bolsa da un cargador de pistola (tiene %s)" % (str(mag.name) if mag else "nada"))
	_expect(mag != null and mag.get("rounds") == 7, "viene lleno (%s balas)" % str(mag.get("rounds") if mag else "?"))
	await sim.squeeze_grip(&"left_hand", 0.0)
	await sim.frames(3)
	if is_instance_valid(mag):
		mag.queue_free()
	await sim.frames(3)

	cfg.infinite_mags = false
	var got := 0
	for i in 5:
		var m = pouch.dispense("left")
		if m == null:
			break
		got += 1
		lp.drop_object()
		m.global_position += Vector3(6, 0, 0)
		m.linear_velocity = Vector3.ZERO
		await sim.frames(3)
	_expect(got == 3, "limitados: la bolsa da 3 cargadores y se agota (%d)" % got)
	_expect(pouch.reserve.get_ammo_amount("mag_pistol") == 0, "reserva en 0")

	var back = pouch.get_node("..").get_parent().get_node_or_null("PouchMag")
	var spare = sb.find_children("PouchMag*", "RigidBody3D", true, false)
	_expect(spare.size() >= 1, "quedan cargadores sueltos para devolver")
	var m2 = spare[0]
	m2.rounds = 5
	m2.global_position = pouch.global_position
	m2.linear_velocity = Vector3.ZERO
	await sim.frames(20)
	_expect(pouch.reserve.get_ammo_amount("mag_pistol") == 5, "devolver un cargador a la bolsa suma sus balas (%d)" % pouch.reserve.get_ammo_amount("mag_pistol"))
	_expect(not is_instance_valid(m2) or m2.is_queued_for_deletion(), "el cargador devuelto desaparece")
	cfg.infinite_mags = true
	print("RESULTADO: %s (%d fallos)" % ["OK" if _fails == 0 else "FALLO", _fails])
	quit(0 if _fails == 0 else 1)
