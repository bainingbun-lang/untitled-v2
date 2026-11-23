extends SceneTree

## Demo del simulador: tomar la pistola -> disparar -> caminar -> golpear a un NPC, con capturas desde la cabeza.
## Con render: DISPLAY=:99 godot --path . --script res://tools/vr_sim/demo_walk_grab_shoot.gd   (sin --headless)
## Las capturas van a /data/data/com.termux/files/usr/tmp/vrsim/ ; con --headless solo se ejecuta la lógica.
const VrSim = preload("res://tools/vr_sim/vr_sim.gd")
const OUT := "/data/data/com.termux/files/usr/tmp/vrsim/"
var _shots := 0


func _init() -> void:
	await process_frame
	var sb = (load("res://sandbox/sandbox.tscn") as PackedScene).instantiate()
	root.add_child(sb)
	var sim = VrSim.new(self)
	await sim.attach(sb)
	var gun = sb.get_node("Table_pistol")
	await _snap(sim, "demo1_inicio")
	await sim.look_at_point(gun.global_position)
	await _snap(sim, "demo2_mira_pistola")
	await sim.reach(&"right_hand", gun.global_position, 0.3)
	await sim.squeeze_grip(&"right_hand", 1.0)
	await sim.frames(8)
	print("agarrada: ", gun.is_picked_up())
	await sim.reach(&"right_hand", sim.origin.global_position + Vector3(0, 1.3, -0.6), 0.3)
	var shots := []
	gun.shot.connect(func(h): shots.append(h))
	await sim.pull_trigger(&"right_hand")
	await sim.pull_trigger(&"right_hand", 0.0)
	print("disparos: ", shots.size())
	await _snap(sim, "demo3_disparo")
	await sim.squeeze_grip(&"right_hand", 0.0)
	await sim.walk(Vector2(0, -1), 1.0)
	print("origen tras caminar: ", sim.origin.global_position)
	var npc: Node3D = get_first_node_in_group("basic_npc")
	if npc:
		var c := npc.global_position + Vector3(0, 1.0, 0)
		await sim.look_at_point(c)
		await sim.reach(&"right_hand", c + Vector3(0, 0, 1.5), 0.3)
		var hp0 = npc.get("health")
		await sim.punch(&"right_hand", c, 6.0)
		await sim.frames(3)
		print("NPC vida: ", hp0, " -> ", npc.get("health") if is_instance_valid(npc) else "muerto")
		await _snap(sim, "demo4_puñetazo")
	sim.detach()
	sb.queue_free()
	await process_frame
	var fac = (load("res://maps/downloaded/scifi/facility_map.tscn") as PackedScene).instantiate()
	root.add_child(fac)
	var sim2 = VrSim.new(self)
	await sim2.attach(fac)
	await sim2.wait(4.0)
	var fy = sim2.floor_at(6.0, 6.0)
	if fy != null:
		await sim2.teleport(Vector3(6.0, fy, 6.0))
	print("facility origen ", sim2.origin.global_position)
	for i in 4:
		await sim2.move_head(Vector3(0, 1.6, 0), 90.0 * i)
		await _snap(sim2, "demo5_facility_%d" % i)
	sim2.detach()
	quit()


func _snap(sim, name: String) -> void:
	if DisplayServer.get_name() == "headless":
		return
	_shots += 1
	print("captura ", name, ": ", await sim.screenshot(OUT + name + ".png"))
