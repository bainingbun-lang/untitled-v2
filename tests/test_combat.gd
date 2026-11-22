extends SceneTree

## Pruebas de combate en la sandbox (headless): perdigones de escopeta y disparo a la cabeza.
## Ejecutar: godot --headless --path . --script res://tests/test_combat.gd
const BulletImpact = preload("res://gore/bullet_impact.gd")

var _fails := 0


func _init() -> void:
	var sb = load("res://sandbox/sandbox.tscn").instantiate()
	root.add_child(sb)
	var t0 := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < 3000:
		await process_frame
	var npc: Node3D = _first_npc(sb)
	_expect(npc != null, "hay un NPC en la sandbox")
	if npc != null:
		await _shotgun_pellets(sb, npc)
		_headshot(sb)
	print("RESULTADO: %s (%d fallos)" % ["OK" if _fails == 0 else "FALLO", _fails])
	quit(0 if _fails == 0 else 1)


func _first_npc(sb: Node) -> Node3D:
	for n in sb.find_children("*", "CharacterBody3D", true, false):
		if n.has_method("take_damage"):
			return n
	return null


func _shotgun_pellets(sb: Node, npc: Node3D) -> void:
	var sg = load("res://weapons/shotgun.tscn").instantiate()
	sb.add_child(sg)
	for i in 2:
		await physics_frame
	var target: Vector3 = npc.global_position + Vector3(0, 1.0, 0)
	var space = sb.get_world_3d().direct_space_state
	var spot := Vector3.ZERO
	var found := false
	for k in 36:
		var a := TAU * k / 36.0
		var cand: Vector3 = target + Vector3(cos(a), 0, sin(a)) * 2.5
		var h = space.intersect_ray(PhysicsRayQueryParameters3D.create(cand, target))
		if not h.is_empty() and h.collider == npc:
			spot = cand
			found = true
			break
	_expect(found, "hay un punto con línea de tiro al NPC")
	if not found:
		sg.queue_free()
		return
	sg.global_position = spot
	sg.look_at(target, Vector3.UP)
	for i in 2:
		await physics_frame
	var hp0: float = npc.health
	sg.physics_ready = true
	sg.drawn = true
	sg.reload.insert_magazine()
	sg.reload.rack_slide()
	sg._next_fire_ms = 0
	sg.action()
	for i in 10:
		await physics_frame
	_expect(hp0 - npc.health >= 90.0, "8 perdigones de 12 aciertan al NPC (daño %.0f)" % (hp0 - npc.health))
	sg.queue_free()


func _headshot(sb: Node) -> void:
	var target: Node3D = null
	for n in sb.find_children("*", "CharacterBody3D", true, false):
		if n.has_method("take_damage") and n.health > 0.0:
			target = n
	if target == null:
		return
	BulletImpact.apply(target, target.global_position + Vector3(0, 1.7, 0), Vector3(0, 0, 1), 150.0, null)
	_expect(target.health <= 0.0, "disparo de 150 a la cabeza mata al NPC")


func _expect(cond: bool, label: String) -> void:
	print(("PASS: " if cond else "FAIL: ") + label)
	if not cond:
		_fails += 1
