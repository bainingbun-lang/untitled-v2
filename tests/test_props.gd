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
	var root_n := Node3D.new()
	get_root().add_child(root_n)
	var fl := StaticBody3D.new()
	var cs := CollisionShape3D.new()
	cs.shape = BoxShape3D.new()
	(cs.shape as BoxShape3D).size = Vector3(40, 0.5, 40)
	fl.add_child(cs)
	fl.position.y = -0.25
	root_n.add_child(fl)
	var player := (load("res://player/xr_player.tscn") as PackedScene).instantiate()
	root_n.add_child(player)
	var sim = VrSim.new(self)
	await sim.attach(root_n)
	await sim.frames(20)
	var wm = player.get_node("WeaponMenu")
	_expect(wm.pages[1].has("prop:barril") and wm.pages[1].has("(borrar todos los props)"), "menu lista props y borrar: " + str(wm.pages[1].size()))
	var pickup = player.right_controller.find_child("FunctionPickup", true, false)
	for id in PF.ids():
		var p = wm.give("right", "prop:" + id)
		await sim.frames(3)
		_expect(p != null and pickup.picked_up_object == p, id + " queda en la mano")
	var held = pickup.picked_up_object
	player.right_controller.button_pressed.emit("ax_button")
	_expect(held.restore_freeze, "A/X fija el prop")
	await sim.press(&"right_hand", &"grip_click")
	await sim.squeeze_grip(&"right_hand", 0.0)
	pickup.drop_object()
	await sim.frames(30)
	var y0: float = held.global_position.y
	await sim.frames(60)
	_expect(held.freeze and absf(held.global_position.y - y0) < 0.001, "prop fijo no cae")
	player.right_controller.button_pressed.emit("ax_button")
	_expect(is_instance_valid(held), "toggle sobre prop no sujeto no rompe")
	_expect(get_nodes_in_group("prop").size() == PF.ids().size(), "props en escena: %d" % get_nodes_in_group("prop").size())
	wm._set_page(1)
	wm.cursor = wm.entries.find(wm.CLEAR)
	wm.open_side = "right"
	wm._confirm()
	await sim.frames(3)
	_expect(get_nodes_in_group("prop").size() == 0, "(borrar props) los elimina")
	var held2 = wm.give("right", "prop:caja")
	await sim.frames(3)
	wm._delete_held("right")
	await sim.frames(3)
	_expect(not is_instance_valid(held2) or held2.is_queued_for_deletion(), "(borrar el de la mano) elimina solo ese")
	wm.open_side = "right"
	wm._set_page(0)
	player.left_controller.button_pressed.emit("by_button")
	_expect(wm.page == 1, "B/Y de la otra mano cambia de pagina")
	for kind in ["civil", "hostil", "armado", "guardia", "zombi"]:
		wm._spawn_npc(kind)
	await sim.frames(3)
	_expect(get_nodes_in_group("basic_npc").size() == 5, "5 NPC creados: %d" % get_nodes_in_group("basic_npc").size())
	wm._set_page(2)
	wm.cursor = wm.entries.size() - 1
	wm._confirm()
	await sim.frames(3)
	_expect(get_nodes_in_group("basic_npc").size() == 0, "(borrar NPC) los elimina")
	var pb = PF.make("barril")
	root_n.add_child(pb)
	pb.global_position = Vector3(0, 2, -2)
	await sim.frames(90)
	_expect(pb._last_msec > 0, "barril suena al chocar con el suelo (rapidez %.1f)" % pb._speed)
	_expect(wm._panel.font_size >= 48 and wm._panel.pixel_size > 0.0006, "panel del menu grande y con contorno")
	var heavy = PF.make("caja_grande")
	_expect(heavy.mass >= 15.0 and heavy.has_signal("grabbed") and heavy.get_script().resource_path.ends_with("prop_body.gd"), "props pesados son PropBody con haptica por masa")
	print("RESULTADO: ", "OK" if fails == 0 else "%d fallos" % fails)
	quit(1 if fails else 0)
