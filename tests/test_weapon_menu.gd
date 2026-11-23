extends SceneTree

var fails := 0


func _expect(ok: bool, msg: String) -> void:
	print(("PASS  " if ok else "FAIL  ") + msg)
	if not ok:
		fails += 1


func _init() -> void:
	await process_frame
	var root := Node3D.new()
	get_root().add_child(root)
	var player := (load("res://player/xr_player.tscn") as PackedScene).instantiate()
	root.add_child(player)
	for i in 10:
		await process_frame
	var wm = player.get_node("WeaponMenu")
	_expect(wm.entries.size() > 1, "menu con armas (%s)" % str(wm.entries))
	var right: XRController3D = player.right_controller
	var left: XRController3D = player.left_controller
	right.button_pressed.emit("grip_click")
	right.button_pressed.emit("by_button")
	wm._process(0.2)
	_expect(not wm.is_open(), "pulsacion corta no abre el menu")
	wm._process(0.4)
	_expect(wm.is_open() and wm.open_side == "right", "mantener B abre el menu en la mano derecha")
	var want: int = wm.entries.find("machete")
	for i in want:
		left.button_pressed.emit("trigger_click")
	_expect(wm.cursor == want, "gatillo de la otra mano avanza el cursor")
	right.button_released.emit("by_button")
	await process_frame
	var pickup = right.find_child("FunctionPickup", true, false)
	var held = pickup.picked_up_object
	_expect(held != null and held.name == "XR_machete", "soltar pone el arma elegida en la mano: " + (str(held.name) if held else "nada"))
	_expect(not wm.is_open(), "el menu se cierra")
	var ak = wm.give("right", "ak47")
	_expect(ak != null and pickup.picked_up_object == ak, "cambiar de arma sustituye la anterior")
	await process_frame
	_expect(not is_instance_valid(held) or held.is_queued_for_deletion(), "el arma anterior se libera")
	print("RESULTADO: ", "OK" if fails == 0 else "%d fallos" % fails)
	quit(1 if fails else 0)
