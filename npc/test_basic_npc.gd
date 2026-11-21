extends SceneTree

const NpcScript = preload("res://npc/basic_npc.gd")

var _checks := 0
var _failures: Array = []
var _case := ""


func _expect(condition: bool, label: String) -> void:
	_checks += 1
	if not condition:
		_failures.append("[%s] %s" % [_case, label])


func _initialize() -> void:
	await _run()
	if _failures.is_empty():
		print("PASS (%d assertions)" % _checks)
		quit(0)
	else:
		for failure in _failures:
			print("FAIL: " + failure)
		print("FAIL (%d/%d assertions fallidas)" % [_failures.size(), _checks])
		quit(1)


func _run() -> void:
	_case = "patrulla sin objetivo"
	var parent := Node3D.new()
	root.add_child(parent)
	await process_frame
	var npc = NpcScript.new()
	npc.name = "NpcPatrol"
	npc.auto_tick = false
	parent.add_child(npc)
	npc.apply_options({
		"id": "npc_a",
		"role": "hostile",
		"patrol_points": [Vector3(4, 0, 0), Vector3(4, 0, 4)],
	})
	var first: Dictionary = npc.tick(0.1)
	_expect(str(first.get("action", "")) == "patrol", "accion patrol sin objetivo")
	_expect(not bool(first.get("visible", true)), "sin objetivo visible")
	_expect(float(first.get("distance", -2.0)) < 0.0, "distance=-1 sin objetivo")
	_expect(npc.goal == Vector3(4, 0, 0), "primer waypoint")
	_expect(npc.current_action() == "patrol", "current_action patrol")
	_expect(npc.can_see(Vector3(1, 0, 0)), "can_see dentro de vision")
	_expect(not npc.can_see(Vector3(100, 0, 0)), "can_see fuera de vision")

	_case = "reaccion a objetivo"
	var target := Node3D.new()
	target.name = "player"
	parent.add_child(target)
	target.global_position = Vector3(1, 0, 0)
	npc.global_position = Vector3(0, 0, 0)
	var changes: Array = []
	npc.action_changed.connect(func(action): changes.append(action))
	npc.set_target(target)
	var near: Dictionary = npc.tick(0.1)
	_expect(bool(near.get("visible", false)), "objetivo visible")
	_expect(str(near.get("action", "")) == "chase", "accion chase")
	_expect(is_equal_approx(float(near.get("distance", 0.0)), 1.0), "distancia 1 al objetivo")
	_expect(npc.goal == Vector3.ZERO, "goal en el sitio al estar dentro de stop_distance")
	_expect(changes.has("chase"), "senal action_changed chase")
	var snapshot: Dictionary = npc.snapshot()
	_expect(bool(snapshot.get("visible", false)), "snapshot visible")
	_expect(str(snapshot.get("target_id", "")) == "player", "snapshot target_id")

	_case = "persecucion y perdida"
	target.global_position = Vector3(10, 0, 0)
	var far: Dictionary = npc.tick(0.1)
	_expect(str(far.get("action", "")) == "chase", "sigue chase con objetivo lejano")
	_expect(is_equal_approx(npc.goal.x, 8.0), "goal a stop_distance del objetivo")
	target.global_position = Vector3(100, 0, 0)
	var lost: Dictionary = npc.tick(0.1)
	_expect(not bool(lost.get("visible", true)), "objetivo fuera de vision")
	_expect(str(lost.get("action", "")) == "investigate", "investiga ultima posicion")
	_expect(is_equal_approx(npc.goal.x, 10.0), "goal en ultima posicion vista")

	_case = "huida de civiliano"
	var civilian = NpcScript.new()
	civilian.name = "NpcCivilian"
	civilian.auto_tick = false
	parent.add_child(civilian)
	civilian.apply_options({"role": "civilian", "flee_distance": 8.0})
	civilian.global_position = Vector3(0, 0, 0)
	var threat := Node3D.new()
	threat.name = "threat"
	parent.add_child(threat)
	threat.global_position = Vector3(1, 0, 0)
	civilian.set_target(threat)
	var flee: Dictionary = civilian.tick(0.1)
	_expect(str(flee.get("action", "")) == "flee", "civiliano huye")
	_expect(is_equal_approx(civilian.goal.x, -8.0), "goal opuesto al objetivo")

	_case = "dano y muerte"
	npc.take_damage(40.0)
	_expect(is_equal_approx(npc.health, 60.0), "vida 60 tras 40 de dano")
	_expect(is_equal_approx(npc.health_ratio(), 0.6), "health_ratio 0.6")
	var damages: Array = []
	npc.damaged.connect(func(amount, health): damages.append([amount, health]))
	npc.take_damage(100.0)
	_expect(npc.is_dead(), "npc muerto")
	_expect(npc.current_action() == "dead", "accion dead al morir")
	_expect(damages.size() == 1, "senal damaged emitida")
	var dead: Dictionary = npc.tick(0.1)
	_expect(str(dead.get("action", "")) == "dead", "tick devuelve dead")

	_case = "spawn estatico"
	BasicNpc.clear_registry()
	var spawned: Node3D = BasicNpc.spawn(parent, Vector3(2, 0, 3), {"id": "npc_b", "role": "defender"})
	_expect(spawned != null, "spawn crea NPC")
	_expect(BasicNpc.active_count() == 1, "un NPC en el registro")
	_expect(str(spawned.name) == "npc_b", "nombre del spawn")
	_expect(spawned.global_position.distance_to(Vector3(2, 0, 3)) < 0.01, "posicion del spawn")
	_expect(parent.get_node_or_null("NpcCivilian") != null, "estructura en arbol creada")
	BasicNpc.clear_registry()
	_expect(BasicNpc.active_count() == 0, "registro limpio")

	parent.free()
