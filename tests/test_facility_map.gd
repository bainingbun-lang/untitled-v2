extends SceneTree

## Instalacion sci-fi: piezas, colision, NPC y 0 errores de script.
## Ejecutar: godot --headless --path . --script res://tests/test_facility_map.gd
var _fails := 0


func _init() -> void:
	await process_frame
	var sc = load("res://maps/downloaded/scifi/facility_map.tscn").instantiate()
	root.add_child(sc)
	await process_frame
	var t0 := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < 4000:
		await process_frame
	var meshes: int = sc.find_children("*", "MeshInstance3D", true, false).size()
	_expect(meshes > 100, "hay piezas de piso/pared (%d mallas)" % meshes)
	_expect(sc.find_children("*", "StaticBody3D", true, false).size() > 50, "hay colisiones")
	await physics_frame
	var space: PhysicsDirectSpaceState3D = root.world_3d.direct_space_state
	var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(Vector3(6, 2.5, 6), Vector3(6, -2, 6)))
	_expect(not hit.is_empty() and absf(hit.position.y) < 0.3, "raycast encuentra el piso")
	var wall := space.intersect_ray(PhysicsRayQueryParameters3D.create(Vector3(2, 1.5, 6), Vector3(-4, 1.5, 6)))
	_expect(not wall.is_empty(), "raycast encuentra pared exterior")
	var npcs := 0
	for c in sc.find_children("*", "CharacterBody3D", true, false):
		if c.has_method("take_damage"):
			npcs += 1
	_expect(npcs >= 4, "al menos 4 NPC (%d)" % npcs)
	print("RESULTADO: ", "OK" if _fails == 0 else "FALLO")
	quit(_fails)


func _expect(ok: bool, msg: String) -> void:
	if ok:
		print("PASS  ", msg)
	else:
		_fails += 1
		print("FAIL  ", msg)
