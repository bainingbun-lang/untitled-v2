extends SceneTree

## Reacciones de NPC en el mapa de la casa: refuerzo al ser atacado y alarma cuando cae uno.
## Ejecutar: godot --headless --path . --script res://tests/test_reactions.gd
var _fails := 0


func _init() -> void:
	await process_frame
	var sc = load("res://maps/house_model/house_map.tscn").instantiate()
	root.add_child(sc)
	var t0 := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < 4000:
		await process_frame
	var npcs: Array = []
	for c in sc.find_children("*", "CharacterBody3D", true, false):
		if c.has_method("take_damage"):
			npcs.append(c)
	_expect(npcs.size() >= 2, "la casa genera al menos 2 NPC")
	if npcs.size() >= 2:
		var victim = npcs[0]
		var near := 0
		for o in npcs:
			if o != victim and o.global_position.distance_to(victim.global_position) < 8.0:
				near += 1
		var before := npcs.size()
		victim.take_damage(999.0, victim.global_position, null, "torso")
		await _wait_until(func(): return near == 0 or npcs.any(func(o): return o != victim and is_instance_valid(o) and o.get_node_or_null("Shout") != null), 300)
		var alarmed := 0
		for o in npcs:
			if o != victim and o.get_node_or_null("Shout") != null:
				alarmed += 1
		_expect(near == 0 or alarmed >= 1, "al caer un NPC, un cercano (<8 m: %d) da la alarma (%d)" % [near, alarmed])
		var after := 0
		for c in sc.find_children("*", "CharacterBody3D", true, false):
			if c.has_method("take_damage"):
				after += 1
		_expect(after >= before, "no se pierden NPC al reaccionar")
	print("RESULTADO: %s (%d fallos)" % ["OK" if _fails == 0 else "FALLO", _fails])
	quit(0 if _fails == 0 else 1)


func _wait_until(cond: Callable, max_frames: int) -> bool:
	for _i in max_frames:
		if cond.call():
			return true
		await physics_frame
	return cond.call()


func _expect(cond: bool, label: String) -> void:
	print(("PASS: " if cond else "FAIL: ") + label)
	if not cond:
		_fails += 1
