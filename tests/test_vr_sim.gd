extends SceneTree

## Prueba del simulador de VR (tools/vr_sim/vr_sim.gd) sobre el sandbox xr-tools: caminar, agarrar, disparar, golpear, capturas.
## Ejecutar: DISPLAY=:99 godot --headless --path . --script res://tests/test_vr_sim.gd
const VrSim = preload("res://tools/vr_sim/vr_sim.gd")
var _fails := 0


func _init() -> void:
	await process_frame
	var sim = VrSim.new(self)
	var sb = (load("res://sandbox/sandbox.tscn") as PackedScene).instantiate()
	root.add_child(sb)
	var ok: bool = await sim.attach(sb)
	_expect(ok, "attach encuentra origen, cámara y los dos mandos")
	await sim.frames(40)

	# (b) (primero, junto a la mesa) agarrar pistola + disparar
	var gun = sb.get_node("Table_pistol")
	var rp = sim.origin.get_node("RightHand/CollisionHandRight/FunctionPickup")
	await sim.reach(&"right_hand", gun.global_position, 0.3)
	await sim.squeeze_grip(&"right_hand", 1.0)
	await sim.frames(8)
	_expect(gun.is_picked_up() and rp.picked_up_object == gun, "grip agarra la pistola")
	await sim.reach(&"right_hand", sim.origin.global_position + Vector3(0, 1.3, -0.5), 0.3)
	var shots := []
	gun.shot.connect(func(h): shots.append(h))
	await sim.pull_trigger(&"right_hand")
	_expect(shots.size() == 1, "gatillo dispara (%d)" % shots.size())
	await sim.pull_trigger(&"right_hand", 0.0)
	await sim.squeeze_grip(&"right_hand", 0.0)
	await sim.frames(3)
	_expect(not gun.is_picked_up(), "soltar grip suelta el arma")

	# (a) caminar (hacia atrás: delante hay una mesa)
	var p0: Vector3 = sim.origin.global_position
	await sim.walk(Vector2(0, -1), 1.0)
	var moved: float = sim.origin.global_position.distance_to(p0)
	_expect(moved > 0.3, "joystick atrás mueve al jugador (%.2f m)" % moved)

	# (c) puñetazo a un NPC
	var npc: Node3D = get_first_node_in_group("basic_npc")
	_expect(npc != null, "hay NPC")
	if npc:
		var c := npc.global_position + Vector3(0, 1.0, 0)
		var hp0 = npc.get("health")
		await sim.reach(&"right_hand", c + Vector3(0, 0, 1.5), 0.3)
		await sim.punch(&"right_hand", c, 6.0)
		await sim.frames(3)
		_expect(npc.get("health") != hp0 or not is_instance_valid(npc), "puñetazo rápido daña al NPC")

	# (d) capturas (solo con render)
	if DisplayServer.get_name() != "headless":
		await sim.look_at_point(sim.origin.global_position + Vector3(0, 1.4, -3))
		var png := "/data/data/com.termux/files/usr/tmp/vrsim/test_sandbox.png"
		_expect(await sim.screenshot(png) and FileAccess.file_exists(png), "captura de la cabeza en el sandbox")
	print("RESULTADO: %s (%d fallos)" % ["OK" if _fails == 0 else "FALLO", _fails])
	quit(0 if _fails == 0 else 1)


func _expect(ok: bool, msg: String) -> void:
	print(("PASS: " if ok else "FAIL: ") + msg)
	if not ok:
		_fails += 1
