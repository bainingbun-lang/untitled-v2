extends SceneTree
# Run: godot --headless --path . -s tests/test_armas.gd
var fails = 0

func ok(cond, msg):
	print(("PASS " if cond else "FAIL ") + msg)
	if not cond: fails += 1

func frames(n):
	for i in n:
		await physics_frame

func _init():
	await process_frame
	# demo spawns casings/smoke under this path
	var main = Node3D.new(); main.name = "Main"; root.add_child(main)
	var vp = Node3D.new(); vp.name = "SubViewport-VR"; main.add_child(vp)
	var spawns = Node3D.new(); spawns.name = "Spawns"; vp.add_child(spawns)

	var ctrl = XRController3D.new()
	ctrl.set_script(load("res://player/controller.gd"))
	main.add_child(ctrl)
	var hand = load("res://addons/godot-xr-tools/functions/Function_Pickup.tscn").instantiate()
	hand.collision_layer = 0; hand.collision_mask = 4 # as in player/player.tscn
	ctrl.add_child(hand)

	# 1. instancia
	var gun = load("res://models/weapons/M1911/M1911.tscn").instantiate()
	main.add_child(gun)
	gun.global_position = Vector3(0, 0, 0.1)
	ok(gun != null and gun.has_method("action"), "1 pistola instanciada")

	var target = load("res://models/targets/target.tscn").instantiate()
	main.add_child(target)
	target.global_position = Vector3(0, 0, -3)
	await frames(5)

	# 2. desenfundar con grip
	ctrl.button_pressed.emit("grip_click")
	ok(gun.get_parent() == hand and hand.picked_up_object == gun and gun.is_picked_up(), "2 desenfundar: pistola en la mano")
	gun.transform = Transform3D() # aim straight at target (-Z)
	await frames(3)

	# 3. disparar con cartucho
	var before = gun.ammunition
	ctrl.button_pressed.emit("trigger_click")
	ok(gun.ammunition == before - 1, "3a disparo gasta cartucho (%d->%d)" % [before, gun.ammunition])
	ok(target.get_node("SubViewport/BulletHole").visible, "3b objetivo impactado (agujero de bala)")

	# 4. sin cartucho
	await frames(90) # let Fire animation end
	gun.get_node("AnimationPlayer").stop()
	gun.ammunition = 0
	var bh = target.get_node("SubViewport/BulletHole")
	bh.visible = false
	ctrl.button_pressed.emit("trigger_click")
	ok(gun.ammunition == 0 and not bh.visible, "4 sin cartucho no dispara")
	ok(gun.get_node("AnimationPlayer").current_animation == "EmptyClick", "4b click vacio")
	gun.get_node("AnimationPlayer").stop()

	# 5. recargar: cargador sostenido entra en Gun_load_point
	var mag = load("res://models/weapons/Magazine/Magazine.tscn").instantiate()
	main.add_child(mag)
	mag.global_position = Vector3(5, 5, 5)
	await frames(2)
	var other = load("res://addons/godot-xr-tools/functions/Function_Pickup.tscn").instantiate()
	var ctrl2 = XRController3D.new(); ctrl2.set_script(load("res://player/controller.gd"))
	main.add_child(ctrl2); ctrl2.add_child(other)
	other._pick_up_object(mag) # held -> picked_up_layer 1024, matches load point mask
	other.global_position = gun.get_node("Pivot/Gun_load_point").global_position
	mag.transform = Transform3D()
	await frames(10)
	ok(gun.ammunition == gun.magazine_size, "5 recarga mete cartuchos (%d)" % gun.ammunition)
	ok(not is_instance_valid(mag) or mag.is_queued_for_deletion(), "5b cargador consumido")

	print("ARMAS fails=", fails)
	quit(1 if fails else 0)
