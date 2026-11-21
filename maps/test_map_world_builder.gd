extends SceneTree

const BuilderScript = preload("res://maps/map_world_builder.gd")

var _checks := 0
var _failures: Array = []
var _case := ""


func _expect(condition: bool, label: String) -> void:
	_checks += 1
	if not condition:
		_failures.append("[%s] %s" % [_case, label])


func _child_of_type(node: Node, class_name_value: String) -> Node:
	if node == null:
		return null
	for child in node.get_children():
		if child.is_class(class_name_value):
			return child
	return null


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
	_case = "mapa simple con limites"
	var parent := Node3D.new()
	parent.name = "Parent_Basic"
	root.add_child(parent)
	var meta := {
		"name": "MAPA_SIMPLE",
		"theme": "urbano",
		"time_of_day": "dia",
		"seed": 1234,
		"spawn_points": [Vector3(0, 0, 0), Vector3(6, 0, 6)],
		"boundaries": {"min": Vector3(-4, 0, -4), "max": Vector3(10, 0, 10)},
	}
	var report: Dictionary = BuilderScript.build(meta, parent)
	await process_frame

	_expect(bool(report.get("ok", false)), "build ok=true")
	_expect((report.get("errors", []) as Array).is_empty(), "errors vacio")
	_expect((report.get("spawn_points", []) as Array).size() == 2, "2 puntos de aparicion")
	_expect(int(report.get("node_count", 0)) == 20, "node_count=20")
	_expect(int(report.get("obstacle_count", -1)) == 0, "sin obstaculos")
	_expect(str(report.get("time_of_day", "")) == "dia", "time_of_day conservado")
	_expect(str(report.get("theme", "")) == "urbano", "theme conservado")

	var world := parent.get_node_or_null("WorldGeometry")
	_expect(world != null, "WorldGeometry creado")

	var ground := parent.get_node_or_null("WorldGeometry/Ground") as StaticBody3D
	_expect(ground != null, "suelo Ground presente")
	if ground != null:
		var collision := _child_of_type(ground, "CollisionShape3D") as CollisionShape3D
		_expect(collision != null and collision.shape is BoxShape3D, "suelo con BoxShape3D")
		if collision != null and collision.shape is BoxShape3D:
			var box := collision.shape as BoxShape3D
			_expect(is_equal_approx(box.size.x, 14.0), "suelo ancho=14")
			_expect(is_equal_approx(box.size.z, 14.0), "suelo profundo=14")
			_expect(is_equal_approx(box.size.y, 0.5), "suelo grosor=0.5")
		_expect(is_equal_approx(ground.position.y, -0.25), "suelo centrado en y=-0.25")
		_expect(ground.collision_layer == 1 and ground.collision_mask == 0, "suelo capa 1")
		_expect(str(ground.get_meta("surface", "")) == "dirt", "suelo surface dirt")
		var ground_mesh := _child_of_type(ground, "MeshInstance3D") as MeshInstance3D
		_expect(ground_mesh != null and not ground_mesh.visible, "malla del suelo oculta")

	for wall_name in ["WallNorth", "WallSouth", "WallWest", "WallEast"]:
		var wall := parent.get_node_or_null("WorldGeometry/" + wall_name) as StaticBody3D
		_expect(wall != null, wall_name + " presente")
		if wall != null:
			_expect(_child_of_type(wall, "CollisionShape3D") != null, wall_name + " con colision")
			_expect(is_equal_approx(wall.position.y, 1.0), wall_name + " altura center=1")
			_expect(str(wall.get_meta("surface", "")) == "brick", wall_name + " surface brick")

	var world_environment := parent.get_node_or_null("WorldGeometry/WorldEnvironment") as WorldEnvironment
	_expect(world_environment != null and world_environment.environment != null, "WorldEnvironment con Environment")
	var sun := parent.get_node_or_null("WorldGeometry/Sun") as DirectionalLight3D
	_expect(sun != null, "Sun DirectionalLight3D")
	_expect(parent.get_tree().get_nodes_in_group("spawn_points").size() == 2, "2 markers en grupo spawn_points")

	var spawn_0 := parent.get_node_or_null("WorldGeometry/Spawn_0") as Marker3D
	_expect(spawn_0 != null and spawn_0.position == Vector3.ZERO, "Spawn_0 en el origen")
	parent.free()

	_case = "sin spawn_points"
	var parent_bad := Node3D.new()
	root.add_child(parent_bad)
	var bad: Dictionary = BuilderScript.build({"name": "BAD"}, parent_bad)
	_expect(not bool(bad.get("ok", true)), "falla sin spawns")
	_expect(not (bad.get("errors", []) as Array).is_empty(), "informa error")
	_expect(parent_bad.get_child_count() == 0, "no crea geometria al fallar")
	parent_bad.free()

	_case = "bounds derivados de grid"
	var parent_grid := Node3D.new()
	root.add_child(parent_grid)
	var grid_meta := {
		"name": "GRID",
		"grid": ["S##", "S..", "..."],
		"spawn_points": [Vector3(0.5, 0, 0.5), [1, 0, 1]],
	}
	var grid_report: Dictionary = BuilderScript.build(grid_meta, parent_grid)
	await process_frame
	_expect(bool(grid_report.get("ok", false)), "grid build ok")
	var grid_bounds: AABB = grid_report.get("bounds", AABB())
	_expect(grid_bounds.size.x > 0.0 and grid_bounds.size.z > 0.0, "grid bounds con area positiva")
	parent_grid.free()

	_case = "parent nulo"
	var null_report: Dictionary = BuilderScript.build({"spawn_points": [Vector3.ZERO]}, null)
	_expect(not bool(null_report.get("ok", true)), "falla con parent nulo")

	_case = "spawns duplicados"
	var parent_dup := Node3D.new()
	root.add_child(parent_dup)
	var dup_report: Dictionary = BuilderScript.build({
		"spawn_points": [Vector3(1, 0, 1), [1, 0, 1], [2, 0, 2], "invalido"],
		"boundaries": {"min": Vector3(0, 0, 0), "max": Vector3(6, 0, 6)},
	}, parent_dup)
	_expect((dup_report.get("spawn_points", []) as Array).size() == 2, "spawns deduplicados")
	parent_dup.free()

	_case = "tope de markers"
	var parent_many := Node3D.new()
	root.add_child(parent_many)
	var many: Array = []
	for i in range(20):
		many.append(Vector3(float(i), 0.0, 0.0))
	var many_report: Dictionary = BuilderScript.build({
		"spawn_points": many,
		"boundaries": {"min": Vector3(-2, 0, -2), "max": Vector3(22, 0, 2)},
	}, parent_many)
	_expect((many_report.get("spawn_points", []) as Array).size() == 16, "tope 16 spawns")
	var marker_count := 0
	for child in parent_many.get_node("WorldGeometry").get_children():
		if child is Marker3D:
			marker_count += 1
	_expect(marker_count == 16, "16 markers creados")
	parent_many.free()
