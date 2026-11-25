extends SceneTree

const VrSim = preload("res://tools/vr_sim/vr_sim.gd")


func _init() -> void:
	await process_frame
	var sb = (load("res://sandbox/sandbox.tscn") as PackedScene).instantiate()
	root.add_child(sb)
	var sim = VrSim.new(self)
	await sim.attach(sb)
	await sim.frames(30)
	var names := []
	for c in sb.get_children():
		if str(c.name).begins_with("Table_") and c.has_signal("shot"):
			names.append(c.name)
	print("armas: ", names)
	for n in names:
		var gun = sb.get_node(str(n))
		await sim.reach(&"right_hand", gun.global_position, 0.3)
		await sim.squeeze_grip(&"right_hand", 1.0)
		await sim.frames(8)
		var shots := [0]
		gun.shot.connect(func(_h): shots[0] += 1)
		var npc: Node3D = get_first_node_in_group("basic_npc")
		if npc:
			await sim.look_at_point(npc.global_position + Vector3(0, 1.0, 0))
		print(n, " agarrada=", gun.is_picked_up())
		await sim.pull_trigger(&"right_hand")
		await sim.frames(20)
		await sim.pull_trigger(&"right_hand", 0.0)
		await sim.frames(10)
		print(n, " disparos=", shots[0])
		await sim.squeeze_grip(&"right_hand", 0.0)
		await sim.frames(10)
	print("FIN sin cierre")
	quit()
