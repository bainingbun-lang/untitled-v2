extends SceneTree

const VrSim = preload("res://tools/vr_sim/vr_sim.gd")
var fails := 0


func _expect(ok: bool, msg: String) -> void:
	print(("PASS  " if ok else "FAIL  ") + msg)
	if not ok:
		fails += 1


func _init() -> void:
	await process_frame
	var root_n := Node3D.new()
	get_root().add_child(root_n)
	var player := (load("res://player/xr_player.tscn") as PackedScene).instantiate()
	root_n.add_child(player)
	var sim = VrSim.new(self)
	await sim.attach(root_n)
	await sim.frames(20)
	var wm = player.get_node("WeaponMenu")
	var NpcScript = load("res://npc/basic_npc.gd")
	var fl := StaticBody3D.new()
	var cs := CollisionShape3D.new()
	cs.shape = BoxShape3D.new()
	(cs.shape as BoxShape3D).size = Vector3(40, 0.5, 40)
	fl.add_child(cs)
	fl.position = Vector3(0, -0.25, 0)
	root_n.add_child(fl)
	var hand: Node3D = player.right_controller
	var npc = NpcScript.new()
	root_n.add_child(npc)
	npc.global_position = hand.global_position + Vector3(0, -1.2, -3)
	var rb := RigidBody3D.new()
	var rcs := CollisionShape3D.new()
	rcs.shape = BoxShape3D.new()
	rb.add_child(rcs)
	root_n.add_child(rb)
	rb.global_position = hand.global_position + Vector3(0, 0, -2)
	for id in ["pistol", "ak47", "shotgun", "smg", "sniper", "barrett", "machete"]:
		var w = wm.give("right", id)
		await sim.frames(5)
		var shots := [0]
		if w and w.has_signal("shot"):
			w.shot.connect(func(_h): shots[0] += 1)
		await sim.pull_trigger(&"right_hand")
		await sim.frames(10)
		await sim.pull_trigger(&"right_hand", 0.0)
		await sim.frames(5)
		if w and "reload" in w:
			print("DBG ", id, " mag=", w.reload.magazine_in, " cham=", w.reload.chambered, " ctrl=", w.get_picked_up_by_controller(), " gp=", w.get_active_grab_point(), " trig=", w._trigger != null)
		_expect(is_instance_valid(w), "%s sigue vivo tras gatillo (disparos=%d)" % [id, shots[0]])
	print("RESULTADO: ", "OK" if fails == 0 else "%d fallos" % fails)
	quit(1 if fails else 0)
