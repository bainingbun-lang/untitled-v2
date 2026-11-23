class_name MapWorldBuilder
extends RefCounted

const WorldMaterialsScript = preload("res://maps/world_materials.gd")

const MAX_SPAWN_MARKERS: int = 16
const FLOOR_THICKNESS: float = 0.5
const WALL_HEIGHT: float = 2.0
const WALL_THICKNESS: float = 0.5


static func build(meta: Dictionary, parent: Node3D) -> Dictionary:
	var map_label := str(meta.get("name", meta.get("id", "?")))
	var errors: Array = []
	if parent == null:
		errors.append("parent: se requiere un Node3D")
		return _failure(errors)

	var spawn_points: Array = _parse_spawns(meta, errors)
	if spawn_points.is_empty():
		if errors.is_empty():
			errors.append("spawn_points: el mapa no tiene puntos de aparicion validos")
		return _failure(errors)

	var bounds: AABB = _parse_bounds(meta, spawn_points)
	if bounds.size.x <= 0.0 or bounds.size.z <= 0.0:
		errors.append("boundaries: limites del mapa invalidos")
		return _failure(errors)

	var marker_count: int = mini(spawn_points.size(), MAX_SPAWN_MARKERS)

	var root := Node3D.new()
	root.name = "WorldGeometry"
	parent.add_child(root)

	var mobile := WorldMaterialsScript.is_mobile()
	var ground_material := WorldMaterialsScript.surface_material("ground", mobile)
	var wall_material := WorldMaterialsScript.surface_material("brick", mobile)

	var time_of_day := str(meta.get("time_of_day", "atardecer"))
	var theme_name := str(meta.get("theme", ""))
	_build_floor(root, bounds, ground_material)
	_build_walls(root, bounds, wall_material)
	_build_environment(root, time_of_day, theme_name)
	_build_spawn_markers(root, spawn_points, marker_count)

	return {
		"ok": true,
		"spawn_points": spawn_points,
		"bounds": bounds,
		"errors": [],
		"props": [],
		"obstacle_count": 0,
		"node_count": count_nodes(root),
		"time_of_day": time_of_day,
		"theme": theme_name,
		"map_label": map_label,
	}


static func _build_floor(root: Node3D, bounds: AABB, material: StandardMaterial3D) -> void:
	var body := StaticBody3D.new()
	body.name = "Ground"
	body.collision_layer = 1
	body.collision_mask = 0
	body.set_meta("surface", "dirt")
	var shape := BoxShape3D.new()
	shape.size = Vector3(bounds.size.x, FLOOR_THICKNESS, bounds.size.z)
	var collision := CollisionShape3D.new()
	collision.shape = shape
	body.add_child(collision)
	var mesh_instance := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = shape.size
	mesh_instance.mesh = box
	mesh_instance.material_override = material
	mesh_instance.visible = true
	body.add_child(mesh_instance)
	body.position = Vector3(
		bounds.position.x + bounds.size.x * 0.5,
		-FLOOR_THICKNESS * 0.5,
		bounds.position.z + bounds.size.z * 0.5
	)
	root.add_child(body)


static func _build_walls(root: Node3D, bounds: AABB, material: StandardMaterial3D) -> void:
	var center_x: float = bounds.position.x + bounds.size.x * 0.5
	var center_z: float = bounds.position.z + bounds.size.z * 0.5
	var span_x: float = bounds.size.x + WALL_THICKNESS * 2.0
	var span_z: float = bounds.size.z + WALL_THICKNESS * 2.0
	var center_y: float = WALL_HEIGHT * 0.5

	_static_box(
		root, "WallNorth",
		Vector3(center_x, center_y, bounds.position.z - WALL_THICKNESS * 0.5),
		Vector3(span_x, WALL_HEIGHT, WALL_THICKNESS), material, "brick"
	)
	_static_box(
		root, "WallSouth",
		Vector3(center_x, center_y, bounds.end.z + WALL_THICKNESS * 0.5),
		Vector3(span_x, WALL_HEIGHT, WALL_THICKNESS), material, "brick"
	)
	_static_box(
		root, "WallWest",
		Vector3(bounds.position.x - WALL_THICKNESS * 0.5, center_y, center_z),
		Vector3(WALL_THICKNESS, WALL_HEIGHT, span_z), material, "brick"
	)
	_static_box(
		root, "WallEast",
		Vector3(bounds.end.x + WALL_THICKNESS * 0.5, center_y, center_z),
		Vector3(WALL_THICKNESS, WALL_HEIGHT, span_z), material, "brick"
	)


static func _static_box(
	root: Node3D, node_name: String, center: Vector3, size: Vector3,
	material: StandardMaterial3D, surface: String = "concrete"
) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.name = node_name
	body.collision_layer = 1
	body.collision_mask = 0
	body.set_meta("surface", surface)
	var shape := BoxShape3D.new()
	shape.size = size
	var collision := CollisionShape3D.new()
	collision.shape = shape
	body.add_child(collision)
	var mesh_instance := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = size
	mesh_instance.mesh = box
	mesh_instance.material_override = material
	mesh_instance.visible = true
	body.add_child(mesh_instance)
	body.position = center
	root.add_child(body)
	return body


static func _build_environment(root: Node3D, time_of_day: String, theme: String) -> void:
	root.set_meta("time_of_day", time_of_day)
	root.set_meta("theme", theme)
	var mobile := WorldMaterialsScript.is_mobile()
	var environment := WorldMaterialsScript.make_environment(mobile)
	var sky: Sky = environment.sky
	if sky != null and sky.sky_material is ProceduralSkyMaterial:
		var procedural := sky.sky_material as ProceduralSkyMaterial
		var top := Color(0.16, 0.32, 0.58)
		var horizon := Color(0.70, 0.78, 0.86)
		var fog_color := Color(0.74, 0.78, 0.82)
		var fog_density := 0.0025
		if time_of_day == "dia":
			top = Color(0.22, 0.46, 0.78)
			horizon = Color(0.78, 0.86, 0.92)
			fog_color = Color(0.78, 0.84, 0.88)
			fog_density = 0.0012
		elif time_of_day == "noche":
			top = Color(0.04, 0.07, 0.16)
			horizon = Color(0.14, 0.17, 0.26)
			fog_color = Color(0.15, 0.19, 0.30)
			fog_density = 0.006
		procedural.sky_top_color = top
		procedural.sky_horizon_color = horizon
		procedural.ground_bottom_color = Color(0.26, 0.25, 0.23)
		environment.fog_light_color = fog_color
		environment.fog_density = fog_density if not mobile else fog_density * 0.7

	var world_environment := WorldEnvironment.new()
	world_environment.name = "WorldEnvironment"
	world_environment.environment = environment
	root.add_child(world_environment)

	var sun_color := Color(1.0, 0.72, 0.48)
	var sun_energy := 1.2 if not mobile else 1.0
	var sun_rotation := Vector3(-24.0, -38.0, 0.0)
	if time_of_day == "dia":
		sun_color = Color(1.0, 0.90, 0.78)
		sun_energy = 1.4 if not mobile else 1.2
		sun_rotation = Vector3(-42.0, -38.0, 0.0)
	elif time_of_day == "noche":
		sun_color = Color(0.80, 0.70, 0.58)
		sun_energy = 0.48 if not mobile else 0.40
		sun_rotation = Vector3(-14.0, -38.0, 0.0)
	environment.fog_sun_scatter = 0.03 if time_of_day != "noche" else 0.01
	environment.ambient_light_energy = 0.3 if time_of_day == "noche" else (0.55 if mobile else 0.7)

	var sun := DirectionalLight3D.new()
	sun.name = "Sun"
	sun.light_color = sun_color
	sun.light_energy = sun_energy
	sun.rotation_degrees = sun_rotation
	sun.shadow_enabled = true
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS
	sun.directional_shadow_max_distance = 25.0
	sun.shadow_bias = 0.035
	sun.shadow_normal_bias = 0.02
	root.add_child(sun)


static func _build_spawn_markers(root: Node3D, spawns: Array, count: int) -> void:
	for i in range(count):
		var marker := Marker3D.new()
		marker.name = "Spawn_%d" % i
		marker.position = spawns[i]
		marker.add_to_group("spawn_points")
		root.add_child(marker)


static func count_nodes(node: Node) -> int:
	if node == null:
		return 0
	var total: int = 1
	for child in node.get_children():
		total += count_nodes(child)
	return total


static func _failure(errors: Array) -> Dictionary:
	return {
		"ok": false,
		"spawn_points": [],
		"bounds": AABB(),
		"errors": errors.duplicate(),
		"props": [],
		"obstacle_count": 0,
		"node_count": 0,
	}


static func _parse_spawns(meta: Dictionary, errors: Array) -> Array:
	var raw: Variant = meta.get("spawn_points", null)
	if not (raw is Array):
		errors.append("spawn_points: se esperaba una lista de posiciones")
		return []
	var result: Array = []
	for item in raw:
		var point: Variant = _as_point(item)
		if point == null:
			continue
		if not result.has(point):
			result.append(point)
		if result.size() >= MAX_SPAWN_MARKERS:
			break
	return result


static func _parse_bounds(meta: Dictionary, spawns: Array) -> AABB:
	var min_point: Vector3 = Vector3(INF, INF, INF)
	var max_point: Vector3 = Vector3(-INF, -INF, -INF)
	var raw: Variant = meta.get("boundaries", null)
	if raw is Dictionary:
		var source: Dictionary = raw
		var low: Variant = _as_point(source.get("min", null))
		var high: Variant = _as_point(source.get("max", null))
		if low != null:
			min_point = low
		if high != null:
			max_point = high

	if is_inf(min_point.x) or is_inf(max_point.x):
		min_point = Vector3.ZERO
		max_point = Vector3.ZERO
		for item in _obstacle_points(meta, _positive_float(meta.get("scale", 1.0), 1.0)):
			var obstacle: Vector3 = item
			min_point.x = mini(min_point.x, obstacle.x)
			min_point.z = mini(min_point.z, obstacle.z)
			max_point.x = maxi(max_point.x, obstacle.x)
			max_point.z = maxi(max_point.z, obstacle.z)
		for item in spawns:
			var spawn: Vector3 = item
			min_point.x = mini(min_point.x, spawn.x)
			min_point.z = mini(min_point.z, spawn.z)
			max_point.x = maxi(max_point.x, spawn.x)
			max_point.z = maxi(max_point.z, spawn.z)
		min_point.x -= 2.0
		min_point.z -= 2.0
		max_point.x += 2.0
		max_point.z += 2.0

	for item in spawns:
		var spawn: Vector3 = item
		min_point.x = mini(min_point.x, spawn.x - 1.0)
		min_point.z = mini(min_point.z, spawn.z - 1.0)
		max_point.x = maxi(max_point.x, spawn.x + 1.0)
		max_point.z = maxi(max_point.z, spawn.z + 1.0)
	min_point.y = mini(min_point.y, 0.0)
	max_point.y = maxi(max_point.y, 1.0)
	return AABB(min_point, max_point - min_point)


static func _obstacle_points(meta: Dictionary, scale: float) -> Array:
	var result: Array = []
	var raw: Variant = meta.get("obstacles", null)
	if raw is Array:
		for item in raw:
			var point: Variant = _as_point(item)
			if point != null and not result.has(point):
				result.append(point)
		return result

	var cells: Variant = meta.get("obstacle_cells", null)
	if cells is Array:
		for item in cells:
			var cell_value: Variant = _as_cell(item)
			if cell_value == null:
				continue
			var cell: Vector2i = cell_value
			var point: Vector3 = Vector3(
				(float(cell.x) + 0.5) * scale, 0.0, (float(cell.y) + 0.5) * scale
			)
			if not result.has(point):
				result.append(point)
		return result

	var grid: Variant = meta.get("grid", null)
	if grid is Array:
		for y in range(grid.size()):
			var row: String = str(grid[y])
			for x in range(row.length()):
				if row.substr(x, 1) == "#":
					result.append(Vector3(
						(float(x) + 0.5) * scale, 0.0, (float(y) + 0.5) * scale
					))
	return result


static func _as_point(value: Variant) -> Variant:
	match typeof(value):
		TYPE_VECTOR3:
			var point: Vector3 = value
			if _finite(point.x) and _finite(point.y) and _finite(point.z):
				return point
		TYPE_VECTOR3I:
			var point: Vector3i = value
			return Vector3(point)
		TYPE_VECTOR2:
			var point: Vector2 = value
			if _finite(point.x) and _finite(point.y):
				return Vector3(point.x, 0.0, point.y)
		TYPE_VECTOR2I:
			var point: Vector2i = value
			return Vector3(float(point.x), 0.0, float(point.y))
		TYPE_ARRAY:
			var values: Array = value
			if values.size() < 3:
				return null
			var x: Variant = _number(values[0])
			var y: Variant = _number(values[1])
			var z: Variant = _number(values[2])
			if x != null and y != null and z != null:
				return Vector3(x, y, z)
		TYPE_DICTIONARY:
			var values: Dictionary = value
			if values.has("position"):
				return _as_point(values["position"])
			var x: Variant = _number(values.get("x", 0.0))
			var y: Variant = _number(values.get("y", 0.0))
			var z: Variant = _number(values.get("z", 0.0))
			if x != null and y != null and z != null:
				return Vector3(x, y, z)
	return null


static func _as_cell(value: Variant) -> Variant:
	match typeof(value):
		TYPE_VECTOR2I:
			return value
		TYPE_VECTOR2:
			var point: Vector2 = value
			return Vector2i(int(point.x), int(point.y))
		TYPE_VECTOR3:
			var point: Vector3 = value
			return Vector2i(int(point.x), int(point.z))
		TYPE_ARRAY:
			var values: Array = value
			if values.size() < 2:
				return null
			var x: Variant = _as_int(values[0], -1)
			var y: Variant = _as_int(values[1], -1)
			if int(x) < 0 or int(y) < 0:
				return null
			return Vector2i(int(x), int(y))
	return null


static func _number(value: Variant) -> Variant:
	match typeof(value):
		TYPE_INT, TYPE_FLOAT:
			var number: float = float(value)
			return number if _finite(number) else null
		TYPE_STRING:
			var text: String = str(value).strip_edges()
			if not text.is_valid_float():
				return null
			var number: float = text.to_float()
			return number if _finite(number) else null
		_:
			return null


static func _as_int(value: Variant, fallback: int) -> int:
	var parsed: Variant = _number(value)
	if parsed == null:
		return fallback
	var number: float = float(parsed)
	if floor(number) != number:
		return fallback
	return int(clampi(int(number), -2147483648, 2147483647))


static func _positive_float(value: Variant, fallback: float) -> float:
	var parsed: Variant = _number(value)
	if parsed == null or float(parsed) <= 0.0:
		return fallback
	return float(parsed)


static func _finite(value: float) -> bool:
	return not is_nan(value) and not is_inf(value)
