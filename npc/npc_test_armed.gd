extends SceneTree

const NpcScript = preload("res://npc/basic_npc.gd")

var _checks := 0
var _failures: Array = []


func _expect(condition: bool, label: String) -> void:
	_checks += 1
	if not condition:
		_failures.append(label)


func _initialize() -> void:
	await process_frame
	var parent := Node3D.new()
	root.add_child(parent)
	await physics_frame
	var player := Node3D.new()
	player.name = "player"
	parent.add_child(player)

	var armed = NpcScript.new()
	armed.auto_tick = false
	parent.add_child(armed)
	armed.apply_options({"id": "a", "role": "hostile", "armed": true})
	armed.global_position = Vector3.ZERO
	armed.set_target(player)
	var shots: Array = []
	armed.shot_fired.connect(func(hit): shots.append(hit))
	_expect(armed.get_node_or_null("Gun") != null, "armado lleva arma visible")
	_expect(armed.get_node_or_null("Gun/GunSound") is AudioStreamPlayer3D, "armado tiene AudioStreamPlayer3D")

	player.global_position = Vector3(0, 1.6, -10)
	var r: Dictionary = armed.tick(0.1)
	_expect(str(r.get("action")) == "shoot", "dispara a 10 m")
	_expect(shots.size() == 1, "primer disparo inmediato")
	armed.tick(0.1)
	_expect(shots.size() == 1, "cooldown entre disparos")
	armed.tick(0.5)
	_expect(shots.size() == 2, "segundo disparo tras cooldown")

	player.global_position = Vector3(0, 1.6, -16.5)
	r = armed.tick(1.0)
	_expect(str(r.get("action")) != "shoot", "no dispara a 16.5 m")
	_expect(shots.size() == 2, "sin disparo fuera de 15 m")

	armed.take_damage(5.0, Vector3(1, 0, 0))
	r = armed.tick(0.1)
	_expect(str(r.get("action")) != "flee", "armado no huye")

	var civ = NpcScript.new()
	civ.auto_tick = false
	parent.add_child(civ)
	civ.apply_options({"id": "c", "role": "civilian"})
	civ.set_target(player)
	player.global_position = civ.global_position + Vector3(0, 1.6, -3)
	_expect(str(civ.tick(0.1).get("action")) == "wander", "pacifico no dispara")
	_expect(civ.get_node_or_null("Gun") == null, "pacifico sin arma")
	civ.take_damage(1.0, civ.global_position + Vector3(1, 0, 0))
	_expect(str(civ.tick(0.1).get("action")) == "flee", "pacifico huye al ser agredido")

	parent.free()
	if _failures.is_empty():
		print("PASS (%d assertions)" % _checks)
		quit(0)
	else:
		for f in _failures:
			print("FAIL: " + f)
		quit(1)
