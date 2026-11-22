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
	var ceiling_material := WorldMaterialsScript.surface_material("concrete", mobile)
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
	mesh_instance.visible = false
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
	mesh_instance.visible = false
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
		mesh_instance.visible = false
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
	mesh_instance.visible = false
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