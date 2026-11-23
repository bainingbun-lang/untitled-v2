extends SceneTree

const VrSim = preload("res://tools/vr_sim/vr_sim.gd")
var _fails := 0


func _expect(ok: bool, msg: String) -> void:
	print(("PASS: " if ok else "FAIL: ") + msg)
	if not ok:
		_fails += 1


func _touch(sim, hand: StringName, target: Callable) -> void:
	for i in 4:
		await sim.reach(hand, target.call(), 0.25)
		await sim.frames(2)
		if sim.hand_world(hand).distance_to(target.call()) < 0.05:
			return


func _init() -> void:
	await process_frame
	var sim = VrSim.new(self)
	var sb = (load("res://sandbox/sandbox.tscn") as PackedScene).instantiate()
	root.add_child(sb)
	await sim.attach(sb)
	await sim.frames(40)
	var gun = sb.get_node("Table_pistol")
	var spare = sb.get_node("Spare_pistol")
	var well = gun.get_node("MagazineWell")
	var rp = sim.origin.get_node("RightHand/CollisionHandRight/FunctionPickup")
	var lp = sim.origin.get_node("LeftHand/CollisionHandLeft/FunctionPickup")

	await sim.reach(&"right_hand", gun.global_position, 0.3)
	await sim.squeeze_grip(&"right_hand", 1.0)
	await sim.frames(8)
	_expect(rp.picked_up_object == gun, "agarro la pistola con la mano derecha")
	_expect(gun.reload.magazine_in and gun.reload.chambered, "arranca con cargador y bala en recamara (%d+1)" % gun.reload.magazine_rounds)

	await sim.press(&"right_hand", &"by_button")
	await sim.frames(4)
	await sim.release(&"right_hand", &"by_button")
	await sim.frames(10)
	_expect(gun.reload.magazine_in and well.has_snapped_object(), "B no expulsa el cargador (queda libre para el menu)")
	var shots := []
	gun.shot.connect(func(h): shots.append(h))
	for i in 3:
		await sim.pull_trigger(&"right_hand")
		await sim.frames(14)
		await sim.pull_trigger(&"right_hand", 0.0)
		await sim.frames(14)
	_expect(shots.size() == 3, "disparo 3 veces (%d)" % shots.size())
	var rounds_before: int = gun.reload.magazine_rounds

	var old_mag = well.picked_up_object
	await sim.reach(&"left_hand", old_mag.global_position, 0.3)
	await sim.squeeze_grip(&"left_hand", 1.0)
	await sim.frames(8)
	_expect(lp.picked_up_object == old_mag, "la mano izquierda agarra el cargador metido en la pistola")
	await sim.reach(&"left_hand", old_mag.global_position + Vector3(0, -0.25, 0), 0.3)
	await sim.frames(8)
	_expect(not gun.reload.magazine_in and not well.has_snapped_object(), "tirar del cargador lo saca de la pistola")
	_expect(old_mag.rounds == rounds_before, "el cargador conserva sus balas (%d)" % rounds_before)
	await sim.squeeze_grip(&"left_hand", 0.0)
	await sim.frames(30)

	await _touch(sim, &"left_hand", func(): return gun.global_position + Vector3(-0.3, 0.2, 0.1))
	spare.linear_velocity = Vector3.ZERO
	spare.global_position = sim.hand_world(&"left_hand")
	await sim.frames(3)
	await sim.squeeze_grip(&"left_hand", 1.0)
	await sim.frames(8)
	_expect(lp.picked_up_object == spare, "agarro el cargador de repuesto con la izquierda (tiene: %s, repuesto en %s, mano en %s, cargador viejo en %s)" % [str(lp.picked_up_object.name) if lp.picked_up_object else "nada", str(spare.global_position), str(sim.hand_world(&"left_hand")), str(old_mag.global_position)])
	for i in 5:
		await sim.reach(&"left_hand", sim.hand_world(&"left_hand") + (well.global_position - spare.global_position), 0.2)
		await sim.frames(3)
		if spare.global_position.distance_to(well.global_position) < 0.03:
			break
	await sim.frames(6)
	await sim.squeeze_grip(&"left_hand", 0.0)
	await sim.frames(20)
	_expect(well.has_snapped_object() and gun.reload.magazine_in, "el cargador entra en la pistola (zona activa %s, repuesto a %.3f m, en grupo %s, agarrado %s, snap_require %s, radio %s)" % [str(well.enabled), spare.global_position.distance_to(well.global_position), str(spare.is_in_group(well.snap_require)), str(spare.is_picked_up()), well.snap_require, str((well.get_node("CollisionShape3D").shape as SphereShape3D).radius) if well.get_node("CollisionShape3D").shape is SphereShape3D else "no-esfera"])
	_expect(gun.reload.magazine_rounds == spare.rounds, "carga las balas del cargador nuevo (%d)" % gun.reload.magazine_rounds)

	var so = gun.get_node("SlideOrigin")
	var slide = gun.get_node("SlideOrigin/Slide")
	var limit: float = so.limit_maximum
	_expect(limit > 0.0, "la pistola tiene corredera (recorrido %.3f m)" % limit)
	gun.reload.chambered = false
	slide.move_slider(limit)
	await sim.frames(4)
	slide.move_slider(0.0)
	await sim.frames(6)
	_expect(gun.reload.chambered, "corredera atras y adelante (movida por codigo, no con la mano) mete bala en recamara")

	shots.clear()
	await sim.pull_trigger(&"right_hand")
	await sim.frames(10)
	_expect(shots.size() == 1, "despues de recargar vuelve a disparar")
	print("RESULTADO: %s (%d fallos)" % ["OK" if _fails == 0 else "FALLO", _fails])
	quit(0 if _fails == 0 else 1)
