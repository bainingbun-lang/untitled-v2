extends SceneTree

## Sandbox con el jugador xr-tools: mesa con armas, agarre real con FunctionPickup (trackers y poses simulados),
## cargador fuera/dentro, corredera, disparo con retroceso y puñetazo a un NPC.
## Ejecutar: DISPLAY=:99 godot --headless --path . --script res://tests/test_xr_sandbox.gd
var _fails := 0
var _trk := {}
var _player: Node3D
var _hand_pos := {&"left_hand": Vector3.ZERO, &"right_hand": Vector3.ZERO}


func _init() -> void:
	await process_frame
	for t in [[&"left_hand", XRPositionalTracker.TRACKER_HAND_LEFT], [&"right_hand", XRPositionalTracker.TRACKER_HAND_RIGHT]]:
		var tr := XRControllerTracker.new() # sin runtime OpenXR: registra los trackers a mano
		tr.type = XRServer.TRACKER_CONTROLLER
		tr.name = t[0]
		tr.hand = t[1]
		XRServer.add_tracker(tr)
		_trk[t[0]] = tr
	var head := XRPositionalTracker.new() # cabeza a 1.6 m: sin esto el cuerpo no tiene altura y cae
	head.type = XRServer.TRACKER_HEAD
	head.name = &"head"
	XRServer.add_tracker(head)
	head.set_pose(&"default", Transform3D(Basis.IDENTITY, Vector3(0, 1.6, 0)), Vector3.ZERO, Vector3.ZERO, XRPose.XR_TRACKING_CONFIDENCE_HIGH)
	var sb = (load("res://sandbox/sandbox.tscn") as PackedScene).instantiate()
	root.add_child(sb)
	for i in 40:
		await physics_frame
	_player = get_first_node_in_group("player")
	_expect(_player != null and _player.name == "XRPlayer", "el sandbox tiene el XRPlayer")
	_expect(sb.get_node_or_null("XRPlayer") != null and sb.get_node_or_null("VRPlayer") == null, "ya no hay VRPlayer")
	var gun = sb.get_node("Table_pistol")
	var ak = sb.get_node("Table_ak47")
	var eye: Vector3 = _player.get_camera().global_position
	for g in [gun, ak]:
		var flat := Vector2(g.global_position.x - eye.x, g.global_position.z - eye.z).length()
		_expect(g.is_xr_class("XRToolsPickable") and flat < 1.5, "%s agarrable a %.2f m del jugador" % [g.name, flat])
	for id in ["shotgun", "smg"]:
		_expect(sb.get_node_or_null("Table_" + id) != null and sb.get_node_or_null("Spare_" + id) != null, "%s y su cargador de repuesto en la mesa" % id)
	_expect(sb.get_node_or_null("Spare_pistol") != null and sb.get_node_or_null("Spare_ak47") != null, "cargadores de repuesto de pistola y AK")

	var lp = _player.get_node("LeftHand/CollisionHandLeft/FunctionPickup")
	var rp = _player.get_node("RightHand/CollisionHandRight/FunctionPickup")
	# Capas: el arma, su cargador y la zona de snap deben estar en la máscara de agarre del jugador.
	for n in [gun, gun.get_node("Magazine"), gun.get_node("MagazineWell"), sb.get_node("Spare_pistol")]:
		_expect(n.collision_layer & rp.grab_collision_mask != 0, "%s: capa dentro de grab_collision_mask" % n.name)

	# Agarrar la pistola con la mano derecha (grip real por el tracker).
	await _move(&"right_hand", gun.global_position, 15)
	_grip(&"right_hand", 1.0)
	await _move(&"right_hand", gun.global_position, 8)
	_expect(rp.picked_up_object == gun and gun.is_picked_up(), "FunctionPickup derecho agarra la pistola")
	var up := Vector3(0.0, 1.3, -2.45)
	await _move(&"right_hand", up, 20)
	_expect(gun.global_position.distance_to(rp.global_position) < 0.25, "la pistola sigue a la mano (%.3f)" % gun.global_position.distance_to(rp.global_position))

	# Cargador: la mano izquierda agarra el que está en el arma.
	var well = gun.get_node("MagazineWell")
	var mag = gun.get_node("Magazine")
	_expect(gun.reload.magazine_in, "pistola con cargador al empezar")
	await _move(&"left_hand", well.global_position, 15)
	_grip(&"left_hand", 1.0)
	await _move(&"left_hand", well.global_position, 8)
	var out := false
	var by_hand: bool = lp.picked_up_object == mag
	_expect(by_hand, "la mano izquierda agarra el cargador")
	if by_hand:
		await _move(&"left_hand", well.global_position + Vector3(0, -0.3, 0), 15)
		out = not gun.reload.magazine_in
	else:
		_press(&"right_hand", &"ax_button", true)
		await physics_frame
		_press(&"right_hand", &"ax_button", false)
		out = not gun.reload.magazine_in
	_expect(out, "el arma queda sin cargador")
	_expect(not by_hand or lp.picked_up_object == mag, "la mano izquierda sostiene el cargador fuera del arma")
	# Meterlo de nuevo: con la mano acercarlo al arma y soltar el grip dentro de la zona (snap).
	if by_hand:
		var off: Vector3 = mag.global_position - lp.global_position # el cargador cuelga de la mano con este desfase
		await _move(&"left_hand", well.global_position - off, 20)
		_grip(&"left_hand", 0.0)
	else:
		_grip(&"left_hand", 0.0)
		mag.global_position = well.global_position
		well.pick_up_object(mag)
	for i in 4:
		await physics_frame
	_expect(gun.reload.magazine_in and well.has_snapped_object(), "el cargador vuelve a entrar en el arma (snap)")

	# Corredera: llamar a la API del slider (ida y vuelta).
	gun.reload.chambered = false
	var slide = gun.get_node("SlideOrigin/Slide")
	var limit: float = gun.get_node("SlideOrigin").limit_maximum
	slide.move_slider(limit)
	slide.move_slider(0.0)
	_expect(gun.reload.chambered, "la corredera mete bala en la recámara")

	# Disparo con trigger_click real (tracker -> XRController3D -> FirearmTrigger/FunctionPickup).
	var shots := []
	gun.shot.connect(func(h): shots.append(h))
	var rounds0: int = gun.reload.magazine_rounds
	var rest: Transform3D = gun._model_rest
	_press(&"right_hand", &"trigger_click", true)
	await physics_frame
	_expect(shots.size() == 1, "trigger_click dispara una vez (%d)" % shots.size())
	_expect(gun.reload.magazine_rounds == rounds0 - 1, "la munición baja (%d -> %d)" % [rounds0, gun.reload.magazine_rounds])
	_expect(not gun.get_node("Model").transform.is_equal_approx(rest), "retroceso: el modelo se desplaza")
	_press(&"right_hand", &"trigger_click", false)
	# Expulsar el cargador con A/X de la mano que sostiene el arma.
	_press(&"right_hand", &"ax_button", true)
	await physics_frame
	_press(&"right_hand", &"ax_button", false)
	for i in 40:
		await physics_frame
	_expect(not gun.reload.magazine_in and not gun.get_node("MagazineWell").has_snapped_object(), "ax_button expulsa el cargador y no se re-captura")
	_grip(&"right_hand", 0.0)
	await physics_frame
	_expect(not gun.is_picked_up(), "soltar el grip suelta la pistola")

	await _punch(sb)
	print("RESULTADO: %s (%d fallos)" % ["OK" if _fails == 0 else "FALLO", _fails])
	quit(0 if _fails == 0 else 1)


## Puñetazo: mano derecha cruza un NPC a alta velocidad y le baja la vida; lenta no hace nada.
func _punch(sb: Node) -> void:
	var npc: Node3D = null
	for n in get_nodes_in_group("npc"):
		npc = n
		break
	if npc == null:
		for n in sb.find_children("*", "CharacterBody3D", true, false):
			if n.has_method("take_damage"):
				npc = n
				break
	_expect(npc != null, "hay un NPC en el sandbox")
	if npc == null:
		return
	var hp0 = npc.get("health")
	var dmg := [0]
	var orig_hp: float = float(hp0) if hp0 != null else 0.0
	var center: Vector3 = npc.global_position + Vector3(0, 1.0, 0)
	_grip(&"right_hand", 0.0)
	_hand_pos[&"right_hand"] = Vector3.ZERO # salto sin cruzar al NPC
	# lento: no hay daño
	await _move(&"right_hand", center + Vector3(0.0, 0, 1.2), 10)
	await _move(&"right_hand", center, 90) # ~1.3 m en 1.5 s = 0.8 m/s
	var slow_hp = npc.get("health")
	_expect(slow_hp == hp0, "golpe lento no hace daño (%s)" % str(slow_hp))
	# rápido
	await _move(&"right_hand", center + Vector3(0.0, 0, 1.5), 20)
	await _move(&"right_hand", center, 6) # ~1.5 m en 0.1 s
	for i in 3:
		await physics_frame
	var fast_hp = npc.get("health")
	_expect(fast_hp != hp0 or not is_instance_valid(npc), "golpe rápido daña al NPC (%s -> %s)" % [str(hp0), str(fast_hp)])
	# Agarre de NPC con grip (mano izquierda, vacía): el NPC sigue a la mano.
	if is_instance_valid(npc):
		_hand_pos[&"left_hand"] = Vector3.ZERO
		var c: Vector3 = npc.global_position + Vector3(0, 1.0, 0)
		await _move(&"left_hand", c, 5)
		_grip(&"left_hand", 1.0)
		await _move(&"left_hand", c, 5)
		await _move(&"left_hand", c + Vector3(0.0, 0.0, 0.6), 60)
		var d: float = npc.global_position.distance_to(_player.get_left_controller().global_position)
		_expect(d < 1.3, "el NPC agarrado sigue a la mano (%.2f m)" % d)
		_expect(absf(npc.global_position.z - (c.z + 0.6)) < 0.5, "el NPC se movió con la mano")


## Mueve la mano (pose en espacio del origen) hacia un punto del mundo en `frames` pasos de física.
func _move(tracker: StringName, world: Vector3, frames: int) -> void:
	var start: Vector3 = _hand_pos[tracker]
	if start == Vector3.ZERO:
		start = world
	for i in frames:
		var p := start.lerp(world, float(i + 1) / frames)
		_hand_pos[tracker] = p
		var local: Vector3 = _player.global_transform.affine_inverse() * p
		_trk[tracker].set_pose(&"grip", Transform3D(Basis.IDENTITY, local), Vector3.ZERO, Vector3.ZERO, XRPose.XR_TRACKING_CONFIDENCE_HIGH)
		await physics_frame
	_hand_pos[tracker] = world


func _grip(tracker: StringName, v: float) -> void:
	_trk[tracker].set_input(&"grip", v)


func _press(tracker: StringName, action: StringName, down: bool) -> void:
	_trk[tracker].set_input(action, down)


func _expect(ok: bool, msg: String) -> void:
	print(("PASS: " if ok else "FAIL: ") + msg)
	if not ok:
		_fails += 1
