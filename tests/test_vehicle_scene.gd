extends SceneTree

const VrSim = preload("res://tools/vr_sim/vr_sim.gd")
var fails := 0


func _expect(ok: bool, msg: String) -> void:
	print(("PASS  " if ok else "FAIL  ") + msg)
	if not ok:
		fails += 1


func _init() -> void:
	await process_frame
	var PF = load("res://props/prop_factory.gd")
	var SS = load("res://props/scene_store.gd")
	var root_n := Node3D.new()
	get_root().add_child(root_n)
	var fl := StaticBody3D.new()
	var cs := CollisionShape3D.new()
	cs.shape = BoxShape3D.new()
	(cs.shape as BoxShape3D).size = Vector3(200, 0.5, 200)
	fl.add_child(cs)
	fl.position.y = -0.25
	root_n.add_child(fl)
	var player := (load("res://player/xr_player.tscn") as PackedScene).instantiate()
	root_n.add_child(player)
	var sim = VrSim.new(self)
	await sim.attach(root_n)
	await sim.frames(20)
	var wm = player.get_node("WeaponMenu")
	_expect(wm.pages[1].has("coche") and wm.pages[1].has("(guardar escena)") and wm.pages[1].has("(cargar escena)"), "pagina Props con coche y guardar/cargar")

	# material del sonido
	_expect(PF.make("barril").surface == "metal" and PF.make("esfera").surface == "soft" and PF.make("caja").surface == "wood" and PF.make("sf_cofre").surface == "metal", "materiales de sonido por prop")

	# guardar y cargar
	for id in ["caja", "barril"]:
		var p = PF.make(id)
		root_n.add_child(p)
		p.global_position = Vector3(1, 1, -3)
	wm._spawn_npc("civil")
	await sim.frames(5)
	var rc: int = SS.save(self)
	_expect(rc == OK, "guardar escena")
	for p in get_nodes_in_group("prop"):
		p.queue_free()
	for n in get_nodes_in_group("basic_npc"):
		n.queue_free()
	await sim.frames(3)
	var made: int = SS.load_into(root_n, wm.NPC_KINDS)
	await sim.frames(3)
	_expect(made == 3 and get_nodes_in_group("prop").size() == 2 and get_nodes_in_group("basic_npc").size() == 1, "cargar escena recrea 2 props y 1 NPC (%d)" % made)

	# coche
	wm._spawn_car()
	await sim.frames(60)
	var car = get_first_node_in_group("vehicle")
	_expect(car != null, "coche creado")
	player.global_position = car.global_position + Vector3(2, 0, 0)
	wm._toggle_car()
	_expect(car.driver == player, "subirse al coche")
	var start: Vector3 = car.global_position
	var fwd: Vector3 = -car.global_basis.z
	await sim.stick(&"left_hand", Vector2(0, 1.0))
	await sim.frames(180)
	var d: Vector3 = car.global_position - start
	_expect(d.length() > 2.0, "el coche avanza con el stick: %.1f m" % d.length())
	_expect(d.dot(fwd) > 0.0, "avanza hacia delante (dot=%.2f)" % d.dot(fwd))
	_expect(player.global_position.distance_to(car.global_position) < 2.5, "el jugador viaja con el coche")
	await sim.stick(&"left_hand", Vector2.ZERO)
	player.left_controller.button_pressed.emit("ax_button")
	_expect(car.driver == null, "A/X baja del coche")
	DirAccess.remove_absolute(SS.PATH)
	print("RESULTADO: ", "OK" if fails == 0 else "%d fallos" % fails)
	quit(1 if fails else 0)
