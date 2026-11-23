class_name HouseBuilder
extends RefCounted

const WorldMaterialsScript = preload("res://maps/world_materials.gd")

const FLOOR_THICKNESS: float = 0.5
const WALL_HEIGHT: float = 3.0
const WALL_THICKNESS: float = 0.3
const HOUSE_WIDTH: float = 8.0
const HOUSE_DEPTH: float = 8.0
const STAIR_WIDTH: float = 1.5
const STAIR_DEPTH: float = 3.0
const STEP_HEIGHT: float = 0.2
const STEP_DEPTH: float = 0.3


static func build_two_story_house(center: Vector3, parent: Node3D) -> Dictionary:
	var errors: Array = []
	if parent == null:
		errors.append("parent: se requiere un Node3D")
		return _failure(errors)

	var mobile := WorldMaterialsScript.is_mobile()
	var floor_material := WorldMaterialsScript.surface_material("wood", mobile)
	var wall_material := WorldMaterialsScript.surface_material("brick", mobile)
	var ceiling_material := _plaster()
	var stair_material := WorldMaterialsScript.surface_material("wood", mobile)

	var root := Node3D.new()
	root.name = "HouseTwoStory"
	parent.add_child(root)

	var half_w = HOUSE_WIDTH * 0.5
	var half_d = HOUSE_DEPTH * 0.5
	var base_x = center.x - half_w
	var base_z = center.z - half_d
	var base_y = center.y

	_build_floor(root, base_x, base_y, base_z, HOUSE_WIDTH, HOUSE_DEPTH, floor_material, "Floor_1")
	_build_ceiling(root, base_x, base_y + WALL_HEIGHT, base_z, HOUSE_WIDTH, HOUSE_DEPTH, ceiling_material, "Ceiling_1")
	_build_walls(root, base_x, base_y, base_z, HOUSE_WIDTH, HOUSE_DEPTH, WALL_HEIGHT, wall_material, 1)

	var second_floor_y = base_y + WALL_HEIGHT + FLOOR_THICKNESS
	_build_floor(root, base_x, second_floor_y, base_z, HOUSE_WIDTH, HOUSE_DEPTH, floor_material, "Floor_2")
	_build_ceiling(root, base_x, second_floor_y + WALL_HEIGHT, base_z, HOUSE_WIDTH, HOUSE_DEPTH, ceiling_material, "Ceiling_2")
	_build_walls(root, base_x, second_floor_y, base_z, HOUSE_WIDTH, HOUSE_DEPTH, WALL_HEIGHT, wall_material, 2)

	_build_stairs(root, base_x, base_y, base_z, stair_material)
	_decorate(root, center, mobile)
	_decorate_stairs(root, base_x, base_y, base_z)

	return {
		"ok": true,
		"errors": [],
		"node_count": count_nodes(root),
	}


static func _build_floor(root: Node3D, x: float, y: float, z: float, width: float, depth: float, material: StandardMaterial3D, name: String) -> void:
	var body := StaticBody3D.new()
	body.name = name
	body.collision_layer = 1
	body.collision_mask = 0
	body.set_meta("surface", "wood")
	var shape := BoxShape3D.new()
	shape.size = Vector3(width, FLOOR_THICKNESS, depth)
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
	body.position = Vector3(x + width * 0.5, y + FLOOR_THICKNESS * 0.5, z + depth * 0.5)
	root.add_child(body)


static func _build_ceiling(root: Node3D, x: float, y: float, z: float, width: float, depth: float, material: StandardMaterial3D, name: String) -> void:
	var body := StaticBody3D.new()
	body.name = name
	body.collision_layer = 1
	body.collision_mask = 0
	body.set_meta("surface", "concrete")
	var shape := BoxShape3D.new()
	shape.size = Vector3(width, FLOOR_THICKNESS, depth)
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
	body.position = Vector3(x + width * 0.5, y + FLOOR_THICKNESS * 0.5, z + depth * 0.5)
	root.add_child(body)


static func _build_walls(root: Node3D, x: float, y: float, z: float, width: float, depth: float, height: float, material: StandardMaterial3D, level: int) -> void:
	var center_x = x + width * 0.5
	var center_z = z + depth * 0.5
	var span_x = width + WALL_THICKNESS * 2.0
	var span_z = depth + WALL_THICKNESS * 2.0
	var center_y = y + height * 0.5

	_static_box(
		root, "WallNorth_%d" % level,
		Vector3(center_x, center_y, z - WALL_THICKNESS * 0.5),
		Vector3(span_x, height, WALL_THICKNESS), material, "brick"
	)
	_static_box(
		root, "WallSouth_%d" % level,
		Vector3(center_x, center_y, z + depth + WALL_THICKNESS * 0.5),
		Vector3(span_x, height, WALL_THICKNESS), material, "brick"
	)
	_static_box(
		root, "WallWest_%d" % level,
		Vector3(x - WALL_THICKNESS * 0.5, center_y, center_z),
		Vector3(WALL_THICKNESS, height, span_z), material, "brick"
	)
	_static_box(
		root, "WallEast_%d" % level,
		Vector3(x + width + WALL_THICKNESS * 0.5, center_y, center_z),
		Vector3(WALL_THICKNESS, height, span_z), material, "brick"
	)


static func _build_stairs(root: Node3D, x: float, y: float, z: float, material: StandardMaterial3D) -> void:
	var stair_x = x + HOUSE_WIDTH - STAIR_WIDTH - WALL_THICKNESS
	var stair_z = z + (HOUSE_DEPTH - STAIR_DEPTH) * 0.5
	var step_count = int(WALL_HEIGHT / STEP_HEIGHT)

	for i in range(step_count):
		var step_y = y + i * STEP_HEIGHT
		var step_depth_pos = stair_z + i * STEP_DEPTH
		
		var body := StaticBody3D.new()
		body.name = "Stair_Step_%d" % i
		body.collision_layer = 1
		body.collision_mask = 0
		body.set_meta("surface", "wood")
		var shape := BoxShape3D.new()
		shape.size = Vector3(STAIR_WIDTH, STEP_HEIGHT, STEP_DEPTH)
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
			stair_x + STAIR_WIDTH * 0.5,
			step_y + STEP_HEIGHT * 0.5,
			step_depth_pos + STEP_DEPTH * 0.5
		)
		root.add_child(body)


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
		"errors": errors.duplicate(),
		"node_count": 0,
	}


static var _plaster_mat: StandardMaterial3D


static func _plaster() -> StandardMaterial3D:
	if _plaster_mat == null:
		_plaster_mat = StandardMaterial3D.new()
		_plaster_mat.albedo_color = Color(0.88, 0.84, 0.76)
		_plaster_mat.roughness = 0.95
	return _plaster_mat


static func _col(c: Color, rough: float = 0.7, emit: float = 0.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = rough
	if emit > 0.0:
		m.emission_enabled = true
		m.emission = c
		m.emission_energy_multiplier = emit
	return m


## Solo visual (sin colision, sin sombras): mesh de caja suelto.
static func _vis(root: Node3D, center: Vector3, size: Vector3, mat: Material, rot_x: float = 0.0) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.position = center
	mi.rotation.x = rot_x
	root.add_child(mi)
	return mi


static func _decorate(root: Node3D, center: Vector3, mobile: bool) -> void:
	var trim := _col(Color(0.93, 0.9, 0.84), 0.6)
	var dark := _col(Color(0.22, 0.14, 0.09), 0.55)
	var wood := WorldMaterialsScript.surface_material("wood", mobile)
	var hw := HOUSE_WIDTH * 0.5
	var hd := HOUSE_DEPTH * 0.5
	var cx := center.x
	var cz := center.z
	for lv in 2:
		var fy: float = center.y + lv * (WALL_HEIGHT + FLOOR_THICKNESS)
		var top := fy + FLOOR_THICKNESS
		var ceil_y := fy + WALL_HEIGHT
		# luz: una omni barata por piso, sin sombras
		var lamp := OmniLight3D.new()
		lamp.name = "RoomLight_%d" % (lv + 1)
		lamp.light_color = Color(1.0, 0.9, 0.72)
		lamp.light_energy = 1.4
		lamp.omni_range = 9.0
		lamp.shadow_enabled = false
		lamp.position = Vector3(cx, ceil_y - 0.5, cz)
		root.add_child(lamp)
		_vis(root, Vector3(cx, ceil_y - 0.06, cz), Vector3(0.5, 0.12, 0.5), _col(Color(1, 0.92, 0.75), 0.4, 3.0))
		# zocalos
		var bh := 0.14
		var by := top + bh * 0.5
		_vis(root, Vector3(cx, by, cz - hd + 0.02), Vector3(HOUSE_WIDTH, bh, 0.04), trim)
		_vis(root, Vector3(cx, by, cz + hd - 0.02), Vector3(HOUSE_WIDTH, bh, 0.04), trim)
		_vis(root, Vector3(cx - hw + 0.02, by, cz), Vector3(0.04, bh, HOUSE_DEPTH), trim)
		_vis(root, Vector3(cx + hw - 0.02, by, cz), Vector3(0.04, bh, HOUSE_DEPTH), trim)
		# vigas de techo
		for i in 3:
			_vis(root, Vector3(cx, ceil_y - 0.06, cz - 2.6 + i * 2.6), Vector3(HOUSE_WIDTH, 0.12, 0.2), dark)
		# marco de puerta en pared sur (hueco decorativo)
		var dz := cz + hd - 0.03
		var dx := cx - 2.0
		_vis(root, Vector3(dx, top + 1.05, dz), Vector3(0.9, 2.1, 0.03), dark)
		_vis(root, Vector3(dx - 0.5, top + 1.1, dz - 0.01), Vector3(0.1, 2.2, 0.06), trim)
		_vis(root, Vector3(dx + 0.5, top + 1.1, dz - 0.01), Vector3(0.1, 2.2, 0.06), trim)
		_vis(root, Vector3(dx, top + 2.2, dz - 0.01), Vector3(1.1, 0.1, 0.06), trim)
		_vis(root, Vector3(dx + 0.3, top + 1.0, dz - 0.04), Vector3(0.05, 0.05, 0.05), _col(Color(0.8, 0.65, 0.2), 0.3))
		# estante contra pared oeste
		var sx := cx - hw + 0.22
		for k in 4:
			_vis(root, Vector3(sx, top + 0.4 + k * 0.5, cz + 2.0), Vector3(0.4, 0.04, 1.4), wood)
		_vis(root, Vector3(sx - 0.18, top + 1.0, cz + 2.0), Vector3(0.03, 2.0, 1.4), wood)
		for k in 3:
			_vis(root, Vector3(sx, top + 0.51 + k * 0.5 + 0.1, cz + 1.6 + k * 0.35), Vector3(0.25, 0.2, 0.3), _col(Color.from_hsv(0.08 + k * 0.1, 0.5, 0.7)))
		# cajas en esquina nordeste
		_vis(root, Vector3(cx + hw - 0.5, top + 0.25, cz - hd + 0.5), Vector3(0.5, 0.5, 0.5), wood)
		_vis(root, Vector3(cx + hw - 1.1, top + 0.2, cz - hd + 0.45), Vector3(0.4, 0.4, 0.4), wood).rotation.y = 0.4
		_vis(root, Vector3(cx + hw - 0.55, top + 0.7, cz - hd + 0.5), Vector3(0.35, 0.35, 0.35), wood).rotation.y = 0.7
		# lampara de pie en esquina noroeste
		var lx := cx - hw + 0.5
		var lz := cz - hd + 0.5
		_vis(root, Vector3(lx, top + 0.9, lz), Vector3(0.05, 1.8, 0.05), dark)
		_vis(root, Vector3(lx, top + 0.03, lz), Vector3(0.3, 0.06, 0.3), dark)
		_vis(root, Vector3(lx, top + 1.75, lz), Vector3(0.3, 0.3, 0.3), _col(Color(1, 0.9, 0.7), 0.5, 2.5))
		if lv == 0:
			var fl := OmniLight3D.new()
			fl.light_color = Color(1.0, 0.85, 0.6)
			fl.light_energy = 0.8
			fl.omni_range = 4.0
			fl.shadow_enabled = false
			fl.position = Vector3(lx + 0.4, top + 1.6, lz + 0.4)
			root.add_child(fl)


static func _decorate_stairs(root: Node3D, x: float, y: float, z: float) -> void:
	var wood := _col(Color(0.3, 0.19, 0.11), 0.6)
	var sx := x + HOUSE_WIDTH - STAIR_WIDTH - WALL_THICKNESS
	var sz := z + (HOUSE_DEPTH - STAIR_DEPTH) * 0.5
	var steps := int(WALL_HEIGHT / STEP_HEIGHT)
	var run := steps * STEP_DEPTH
	var rise := steps * STEP_HEIGHT
	var ang := atan2(rise, run)
	var len := sqrt(run * run + rise * rise)
	var mid := Vector3(0, y + rise * 0.5, sz + run * 0.5)
	for side in [0.0, STAIR_WIDTH + 0.06]:
		_vis(root, mid + Vector3(sx - 0.03 + side, -0.05, 0), Vector3(0.06, 0.35, len), wood, -ang)
	_vis(root, mid + Vector3(sx - 0.03, 0.9, 0), Vector3(0.06, 0.06, len), wood, -ang)
	for i in range(0, steps, 3):
		_vis(root, Vector3(sx - 0.03, y + i * STEP_HEIGHT + 0.5, sz + i * STEP_DEPTH + 0.15), Vector3(0.05, 0.9, 0.05), wood)
	var nose := _col(Color(0.5, 0.33, 0.2), 0.5)
	for i in steps:
		_vis(root, Vector3(sx + STAIR_WIDTH * 0.5, y + i * STEP_HEIGHT + STEP_HEIGHT + 0.01, sz + i * STEP_DEPTH + 0.02), Vector3(STAIR_WIDTH, 0.03, 0.06), nose)
