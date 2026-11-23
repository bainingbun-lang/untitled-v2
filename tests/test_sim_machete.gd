extends SceneTree

const VrSim = preload("res://tools/vr_sim/vr_sim.gd")
const OUT := "/data/data/com.termux/files/usr/tmp/vrsim/"
var _fails := 0


func _expect(ok: bool, msg: String) -> void:
	print(("PASS: " if ok else "FAIL: ") + msg)
	if not ok:
		_fails += 1


func _shot(sim, name: String) -> void:
	if DisplayServer.get_name() != "headless":
		await sim.screenshot(OUT + name + ".png")


func _init() -> void:
	await process_frame
	DirAccess.make_dir_recursive_absolute(OUT)
	var sim = VrSim.new(self)
	var sb = (load("res://sandbox/sandbox.tscn") as PackedScene).instantiate()
	root.add_child(sb)
	_expect(await sim.attach(sb), "attach")
	await sim.frames(40)
	var wm = sim.origin.get_node("WeaponMenu")
	var rp = sim.origin.get_node("RightHand/CollisionHandRight/FunctionPickup")

	await sim.press(&"right_hand", &"by_button")
	await sim.wait(0.7)
	_expect(wm.is_open() and wm.open_side == "right", "mantener B abre el menu")
	await sim.look_at_point(sim.hand_world(&"right_hand"))
	await _shot(sim, "menu_abierto")
	var want: int = wm.entries.find("machete")
	for i in want:
		await sim.press(&"left_hand", &"trigger_click")
		await sim.frames(2)
		await sim.release(&"left_hand", &"trigger_click")
		await sim.frames(2)
	_expect(wm.cursor == want, "gatillo izquierdo elige machete")
	await sim.release(&"right_hand", &"by_button")
	await sim.frames(6)
	var m = rp.picked_up_object
	_expect(m != null and m.name == "XR_machete", "machete en la mano derecha")
	if m == null:
		quit(1)
		return

	await sim.look_at_point(sim.origin.global_position + Vector3(0, 1.4, -2))
	await sim.move_hand(&"right_hand", Vector3(0.15, -0.25, -0.45), Vector3(0, 0, 0))
	await sim.frames(10)
	await _shot(sim, "machete_en_mano")

	var npc: Node3D = get_first_node_in_group("basic_npc")
	_expect(npc != null, "hay NPC")
	npc.global_position = sim.origin.global_position + Vector3(0.3, 0.0, -1.3)
	await sim.frames(5)
	var hp0: float = npc.get("health")
	var c := npc.global_position + Vector3(0, 1.0, 0)
	_expect(rp.picked_up_object == m, "sigue en la mano antes de acercarse")
	await sim.reach(&"right_hand", c + Vector3(0, 0.3, 0.7), 0.3)
	_expect(rp.picked_up_object == m, "sigue en la mano tras acercarse (pos %s)" % str(m.global_position))
	await sim.punch(&"right_hand", c, 7.0)
	await sim.frames(2)
	_expect(not m._cooldowns.is_empty(), "la hoja corto al NPC")
	_expect(not is_instance_valid(npc) or npc.get("health") < hp0, "el NPC perdio vida (%.0f -> %s)" % [hp0, str(npc.get("health")) if is_instance_valid(npc) else "muerto"])
	_expect(m._hit.playing or m._hit.pitch_scale != 1.0, "se disparo el sonido de impacto")
	await sim.frames(20)
	_expect(rp.picked_up_object == m, "sigue en la mano tras el golpe (pos %s)" % str(m.global_position))
	await sim.look_at_point(c)
	await _shot(sim, "tras_el_corte")
	print("RESULTADO: %s (%d fallos)" % ["OK" if _fails == 0 else "FALLO", _fails])
	quit(0 if _fails == 0 else 1)
