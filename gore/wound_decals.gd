# Adaptado de wound_decals.gd (proyecto UNTITLED), fuente solo lectura.
# Logica basica: sangre en superficies (heridas, salpicaduras, charcos, rastros).
# Sin dependencias del proyecto completo: todo es procedural y usa Node3D genericos.

class_name WoundDecals
extends RefCounted

const GROUND_MASK := 1
const GROUND_PROBE := 8.0
const MAX_DECAL_AGE := 30.0
const PUDDLE_MAX_SIZE_MULT := 3.0
const DAMAGE_MASK_SIZE := 256
const MAX_DAMAGE_MASKS := 24

enum DamageLayer {
	SKIN = 0,
	MUSCLE = 1,
	BONE = 2
}

static var _wound_decals: Array = []
static var _surface_decals: Array = []
static var _puddles: Array = []
static var _trails: Array = []
static var _decal_materials: Dictionary = {}
static var _puddle_material = null
static var _decal_texture = null
static var _splat_texture = null
static var _limb_trail_material = null

static var _decal_limit: int = 96
static var _puddle_limit: int = 32
static var _part_limit: int = 16
static var _active_particle_limit: int = 48

static var _damage_masks: Dictionary = {}
static var _damage_mask_pool: Array = []
static var _npc_mask_refs: Dictionary = {}


static func set_limits(decals: int, puddles: int, parts: int, active_particles: int) -> void:
	_decal_limit = maxi(decals, 0)
	_puddle_limit = maxi(puddles, 0)
	_part_limit = maxi(parts, 0)
	_active_particle_limit = maxi(active_particles, 0)
	_enforce_limits()


static func get_decal_limit() -> int:
	return _decal_limit


static func get_puddle_limit() -> int:
	return _puddle_limit


static func get_part_limit() -> int:
	return _part_limit


static func get_active_particle_limit() -> int:
	return _active_particle_limit


static func get_or_create_damage_mask(npc_id: int) -> Image:
	if _damage_masks.has(npc_id):
		return _damage_masks[npc_id]

	if _damage_mask_pool.size() >= MAX_DAMAGE_MASKS:
		var oldest_key: int = _damage_mask_pool.pop_front()
		_damage_masks.erase(oldest_key)

	var mask := Image.create_empty(DAMAGE_MASK_SIZE, DAMAGE_MASK_SIZE, false, Image.FORMAT_RGBA8)
	mask.fill(Color(0, 0, 0, 0))
	_damage_masks[npc_id] = mask
	_damage_mask_pool.append(npc_id)
	return mask


static func release_damage_mask(npc_id: int) -> void:
	_damage_masks.erase(npc_id)
	_damage_mask_pool.erase(npc_id)


static func apply_damage_to_mask(npc_id: int, uv: Vector2, depth: float, radius_px: int = 8) -> void:
	var mask := get_or_create_damage_mask(npc_id)
	var cx := int(uv.x * DAMAGE_MASK_SIZE)
	var cy := int(uv.y * DAMAGE_MASK_SIZE)

	var layer: int
	if depth < 0.33:
		layer = DamageLayer.SKIN
	elif depth < 0.66:
		layer = DamageLayer.MUSCLE
	else:
		layer = DamageLayer.BONE

	var color: Color = _get_layer_color(layer)
	var radius := maxi(radius_px, 1)
	var r_sq := radius * radius
	var r: float = sqrt(float(r_sq))

	var dilate_radius := radius + 2
	var dilate_r_sq := dilate_radius * dilate_radius
	var dilate_r: float = sqrt(float(dilate_r_sq))

	var min_x: int = maxi(0, cx - dilate_radius)
	var max_x: int = mini(DAMAGE_MASK_SIZE - 1, cx + dilate_radius)
	var min_y: int = maxi(0, cy - dilate_radius)
	var max_y: int = mini(DAMAGE_MASK_SIZE - 1, cy + dilate_radius)

	var temp_pixels: Array = []
	for y in range(min_y, max_y + 1):
		var dy := y - cy
		var dy_sq := dy * dy
		if dy_sq > dilate_r_sq:
			continue
		var dx_max: int = int(sqrt(float(dilate_r_sq - dy_sq)))
		var x_start: int = maxi(min_x, cx - dx_max)
		var x_end: int = mini(max_x, cx + dx_max)
		for x in range(x_start, x_end + 1):
			var dx := x - cx
			var dist_sq := dx * dx + dy_sq
			if dist_sq <= dilate_r_sq:
				var dist: float = sqrt(float(dist_sq))
				var falloff: float = 1.0 - dist / dilate_r
				falloff *= falloff
				if dist_sq <= r_sq:
					falloff = 1.0
				var alpha: float = color.a * falloff
				var existing: Color = mask.get_pixel(x, y)
				var new_color: Color
				if existing.a <= 0.01:
					new_color = Color(color.r, color.g, color.b, alpha)
				else:
					new_color = Color(
						_overlay_blend(existing.r, color.r),
						_overlay_blend(existing.g, color.g),
						_overlay_blend(existing.b, color.b),
						_overlay_blend(existing.a, alpha)
					)
				temp_pixels.append({"x": x, "y": y, "color": new_color})

	for p in temp_pixels:
		mask.set_pixel(p["x"], p["y"], p["color"])

	_edge_feather(mask, cx, cy, dilate_radius)


static func _overlay_blend(base: float, blend: float) -> float:
	if base < 0.5:
		return 2.0 * base * blend
	return 1.0 - 2.0 * (1.0 - base) * (1.0 - blend)


static func _edge_feather(mask: Image, cx: int, cy: int, radius: int) -> void:
	var feather_radius := radius + 4
	var feather_r_sq := feather_radius * feather_radius
	var min_x: int = maxi(0, cx - feather_radius)
	var max_x: int = mini(DAMAGE_MASK_SIZE - 1, cx + feather_radius)
	var min_y: int = maxi(0, cy - feather_radius)
	var max_y: int = mini(DAMAGE_MASK_SIZE - 1, cy + feather_radius)
	for y in range(min_y, max_y + 1):
		var dy := y - cy
		var dy_sq := dy * dy
		if dy_sq > feather_r_sq:
			continue
		var dx_max: int = int(sqrt(float(feather_r_sq - dy_sq)))
		var x_start: int = maxi(min_x, cx - dx_max)
		var x_end: int = mini(max_x, cx + dx_max)
		for x in range(x_start, x_end + 1):
			var dx := x - cx
			var dist_sq := dx * dx + dy_sq
			if dist_sq > radius * radius and dist_sq <= feather_r_sq:
				var dist: float = sqrt(float(dist_sq))
				var feather_factor: float = clampf(1.0 - (dist - float(radius)) / 4.0, 0.0, 1.0)
				var existing: Color = mask.get_pixel(x, y)
				mask.set_pixel(x, y, Color(existing.r, existing.g, existing.b, existing.a * feather_factor))


static func _get_layer_color(layer: int) -> Color:
	match layer:
		DamageLayer.SKIN:
			return Color(0.55, 0.05, 0.05, 0.85)
		DamageLayer.MUSCLE:
			return Color(0.45, 0.02, 0.02, 0.9)
		DamageLayer.BONE:
			return Color(0.86, 0.80, 0.68, 0.95)
	return Color(0.5, 0.03, 0.03, 0.85)


static func create_wound(parent: Node, pos: Vector3, normal: Vector3, size: float, layers: int, zone: String = "", npc_id: int = -1, uv: Vector2 = Vector2(0.5, 0.5), depth: float = 0.5) -> Dictionary:
	if parent == null or not parent.is_inside_tree() or _decal_limit <= 0:
		return {}

	if npc_id >= 0:
		apply_damage_to_mask(npc_id, uv, depth, int(size * 128.0))

	var wound := Node3D.new()
	wound.name = "Wound_%s" % (zone if not zone.is_empty() else "generic")

	var surface := _raycast_ground(parent, pos + Vector3.UP * 0.3)
	var impact_pos: Vector3 = surface.get("position", pos)
	var impact_normal: Vector3 = surface.get("normal", normal)
	if surface.is_empty() or impact_normal.y < 0.3:
		impact_pos = pos
		impact_normal = normal.normalized() if normal.length_squared() > 0.0001 else Vector3.UP

	var wound_rot := Quaternion(Vector3.UP, impact_normal)
	var created_layers: Array = []
	var layer_count := clampi(layers, 1, 4)
	for i in range(layer_count):
		var layer_decal := MeshInstance3D.new()
		layer_decal.name = "WoundLayer_%d" % i
		var plane := PlaneMesh.new()
		var layer_size: float = clampf(size * (1.0 - float(i) * 0.18), 0.025, maxf(size, 0.025))
		plane.size = Vector2(layer_size, layer_size)
		layer_decal.mesh = plane
		layer_decal.material_override = _get_decal_material_for_layer(i, layer_count, depth)
		layer_decal.position = impact_normal * (0.004 + float(i) * 0.0015)
		layer_decal.rotation = wound_rot.get_euler()
		wound.add_child(layer_decal)
		created_layers.append({
			"node": layer_decal,
			"layer": i,
			"size": layer_size,
			"age": 0.0,
		})

	parent.add_child(wound)
	wound.global_position = impact_pos
	wound.global_rotation = wound_rot.get_euler()

	var wound_data := {
		"root": wound,
		"layers": created_layers,
		"position": pos,
		"normal": normal,
		"zone": zone,
		"age": 0.0,
		"is_character": parent is CharacterBody3D or parent.has_method("take_damage"),
		"npc_id": npc_id,
		"depth": depth,
	}
	if wound_data["is_character"]:
		_wound_decals.append(wound_data)
	else:
		_surface_decals.append(wound_data)

	_enforce_limits()
	return wound_data


static func create_splatter(parent: Node, pos: Vector3, direction: Vector3, spread_deg: float, count: int, force: float) -> void:
	if parent == null or not parent.is_inside_tree() or _decal_limit <= 0:
		return
	if not (parent is Node3D):
		return
	if not Engine.is_in_physics_frame():
		return
	var world_3d: World3D = (parent as Node3D).get_world_3d()
	if world_3d == null or world_3d.direct_space_state == null:
		return
	var space: PhysicsDirectSpaceState3D = world_3d.direct_space_state

	var dir := direction.normalized()
	if dir.length_squared() < 0.0001:
		dir = Vector3.UP
	var ref := Vector3.UP if absf(dir.dot(Vector3.UP)) < 0.95 else Vector3.FORWARD
	var right := dir.cross(ref).normalized()
	var up := right.cross(dir).normalized()
	var half_angle := deg_to_rad(clampf(spread_deg, 1.0, 80.0) * 0.5)

	for i in range(maxi(count, 0)):
		var angle := randf_range(-half_angle, half_angle)
		var tilt := randf_range(-half_angle * 0.5, half_angle * 0.5)
		var droplet_dir := (dir + right * sin(angle) + up * sin(tilt)).normalized()
		var distance := randf_range(0.5, 3.0 + force * 0.05)
		var ray_from := pos + droplet_dir * 0.1
		var ray_to := ray_from + droplet_dir * distance

		var query := PhysicsRayQueryParameters3D.create(ray_from, ray_to)
		query.collide_with_bodies = true
		query.collide_with_areas = false
		query.collision_mask = GROUND_MASK | 2 | 4 | 8
		var hit: Dictionary = space.intersect_ray(query)
		if not hit.is_empty():
			var hit_pos: Vector3 = hit.get("position", ray_to)
			var hit_normal: Vector3 = hit.get("normal", Vector3.UP)
			if hit_normal.length_squared() > 0.0001:
				hit_normal = hit_normal.normalized()
			_add_surface_decal(parent, hit_pos, hit_normal, clampf(0.08 + force * 0.0015, 0.08, 0.30), "splatter")
		else:
			_add_surface_decal(parent, ray_to, Vector3.UP, clampf(0.06 + force * 0.0010, 0.06, 0.20), "splatter_air")


static func _add_surface_decal(parent: Node, pos: Vector3, normal: Vector3, size: float, decal_type: String) -> void:
	if parent == null or not parent.is_inside_tree() or _decal_limit <= 0:
		return
	var decal := MeshInstance3D.new()
	decal.name = "SurfaceDecal_%s" % decal_type
	var plane := PlaneMesh.new()
	plane.size = Vector2(size, size)
	decal.mesh = plane
	decal.material_override = _get_surface_decal_material(decal_type)

	var surface := _raycast_ground(parent, pos + Vector3.UP * 0.3)
	var impact_pos: Vector3 = surface.get("position", pos)
	var impact_normal: Vector3 = surface.get("normal", normal)
	if surface.is_empty() or impact_normal.y < 0.2:
		impact_pos = pos
		impact_normal = normal.normalized() if normal.length_squared() > 0.0001 else Vector3.UP

	parent.add_child(decal)
	decal.global_position = impact_pos + impact_normal * 0.006
	decal.global_rotation = Quaternion(Vector3.UP, impact_normal).get_euler()

	_surface_decals.append({
		"root": decal,
		"position": impact_pos,
		"normal": impact_normal,
		"age": 0.0,
		"type": decal_type,
	})
	_enforce_limits()


static func create_trail(parent: Node, from_pos: Vector3, to_pos: Vector3) -> void:
	if parent == null or not parent.is_inside_tree() or _decal_limit <= 0:
		return
	var distance := from_pos.distance_to(to_pos)
	if distance < 0.1:
		return
	var steps := clampi(ceili(distance / 0.15), 1, 8)
	for i in range(steps):
		var t := float(i + 1) / float(steps)
		var pos := from_pos.lerp(to_pos, t)
		var size: float = clampf(0.05 * (1.0 - t * 0.5), 0.02, 0.08)
		_add_surface_decal(parent, pos, Vector3.UP, size, "trail")


static func create_puddle(parent: Node, pos: Vector3, normal: Vector3, initial_size: float) -> Node3D:
	if parent == null or not parent.is_inside_tree() or _puddle_limit <= 0:
		return null

	var puddle := MeshInstance3D.new()
	puddle.name = "BloodPuddle"
	puddle.mesh = _make_irregular_disc(clampf(initial_size, 0.08, 0.5), 16)
	puddle.material_override = _get_puddle_material()

	var surface := _raycast_ground(parent, pos + Vector3.UP * 0.5)
	var impact_pos: Vector3 = surface.get("position", pos)
	var impact_normal: Vector3 = surface.get("normal", normal)
	if surface.is_empty() or impact_normal.y < 0.4:
		impact_pos = pos
		impact_normal = normal.normalized() if normal.length_squared() > 0.0001 else Vector3.UP

	parent.add_child(puddle)
	puddle.global_position = impact_pos + impact_normal * 0.003
	puddle.global_rotation = Quaternion(Vector3.UP, impact_normal).get_euler()

	_puddles.append({
		"node": puddle,
		"position": impact_pos,
		"normal": impact_normal,
		"size": initial_size,
		"max_size": initial_size * PUDDLE_MAX_SIZE_MULT,
		"age": 0.0,
		"growing": true,
	})
	_enforce_limits()
	return puddle


static func update_puddles(delta: float) -> void:
	if delta <= 0.0 or _puddles.is_empty():
		return
	for puddle in _puddles:
		var node = puddle.get("node", null)
		if not is_instance_valid(node):
			continue
		puddle["age"] = float(puddle.get("age", 0.0)) + delta
		var age: float = puddle["age"]
		if bool(puddle.get("growing", false)) and age < 5.0:
			var grow_factor: float = 1.0 + (age / 5.0) * (PUDDLE_MAX_SIZE_MULT - 1.0)
			var base_size: float = maxf(float(puddle.get("size", 0.1)), 0.001)
			var new_size: float = base_size * grow_factor
			node.scale = Vector3(new_size / base_size, 1.0, new_size / base_size)
		elif age >= 5.0:
			puddle["growing"] = false
		if age > MAX_DECAL_AGE * 1.5:
			node.modulate = Color(1.0, 1.0, 1.0, maxf(0.0, 1.0 - (age - MAX_DECAL_AGE * 1.5) / 10.0))


static func prune_invalid() -> void:
	_prune_decal_array(_wound_decals, "root")
	_prune_decal_array(_surface_decals, "root")
	_prune_decal_array(_puddles, "node")
	var i := _trails.size() - 1
	while i >= 0:
		if not is_instance_valid(_trails[i]):
			_trails.remove_at(i)
		i -= 1


static func _prune_decal_array(arr: Array, key: String) -> void:
	var i := arr.size() - 1
	while i >= 0:
		var entry = arr[i]
		if not (entry is Dictionary) or not is_instance_valid(entry.get(key, null)):
			arr.remove_at(i)
		i -= 1


static func _enforce_limits() -> void:
	prune_invalid()
	while _wound_decals.size() + _surface_decals.size() > _decal_limit:
		var target_arr: Array = _surface_decals if _surface_decals.size() > _wound_decals.size() else _wound_decals
		if target_arr.is_empty():
			break
		var old: Dictionary = target_arr.pop_front()
		var old_root = old.get("root", null)
		if is_instance_valid(old_root):
			old_root.queue_free()

	while _puddles.size() > _puddle_limit:
		var old_puddle: Dictionary = _puddles.pop_front()
		var old_node = old_puddle.get("node", null)
		if is_instance_valid(old_node):
			old_node.queue_free()


static func clear() -> void:
	for wound in _wound_decals:
		var root = wound.get("root", null) if wound is Dictionary else null
		if is_instance_valid(root):
			root.queue_free()
	for decal in _surface_decals:
		var root = decal.get("root", null) if decal is Dictionary else null
		if is_instance_valid(root):
			root.queue_free()
	for puddle in _puddles:
		var node = puddle.get("node", null) if puddle is Dictionary else null
		if is_instance_valid(node):
			node.queue_free()
	for trail in _trails:
		if is_instance_valid(trail):
			trail.queue_free()
	_wound_decals.clear()
	_surface_decals.clear()
	_puddles.clear()
	_trails.clear()
	_damage_masks.clear()
	_damage_mask_pool.clear()
	_npc_mask_refs.clear()


static func shutdown() -> void:
	clear()
	_decal_materials.clear()
	_puddle_material = null
	_decal_texture = null
	_limb_trail_material = null


static func _raycast_ground(parent: Node, from: Vector3) -> Dictionary:
	if not (parent is Node3D):
		return {}
	if not Engine.is_in_physics_frame():
		return {}
	var world_3d: World3D = (parent as Node3D).get_world_3d()
	if world_3d == null or world_3d.direct_space_state == null:
		return {}
	var query := PhysicsRayQueryParameters3D.create(from, from - Vector3.UP * GROUND_PROBE)
	query.collide_with_bodies = true
	query.collide_with_areas = false
	query.collision_mask = GROUND_MASK
	return world_3d.direct_space_state.intersect_ray(query)


static func _make_irregular_disc(radius: float, segments: int) -> Mesh:
	var rng := RandomNumberGenerator.new()
	rng.seed = (int(radius * 1000.0) ^ 0xD15C) & 0x7FFFFFFF
	var vertices := PackedVector3Array()
	var normals := PackedVector3Array()
	var indices := PackedInt32Array()
	vertices.append(Vector3.ZERO)
	normals.append(Vector3.UP)
	for i in range(segments):
		var angle := TAU * float(i) / float(segments)
		var offset := radius * rng.randf_range(0.7, 1.0)
		vertices.append(Vector3(cos(angle) * offset, 0.0, sin(angle) * offset))
		normals.append(Vector3.UP)
	for i in range(segments):
		indices.append(0)
		indices.append((i + 1) % segments + 1)
		indices.append(i + 1)
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_INDEX] = indices
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh


static func _get_decal_material_for_layer(layer: int, total_layers: int, depth: float) -> Material:
	var key := "wound_%d_%d_%d" % [layer, total_layers, int(depth * 10.0)]
	if _decal_materials.has(key):
		return _decal_materials[key]
	var material := StandardMaterial3D.new()
	var layer_type: int
	if depth < 0.33:
		layer_type = DamageLayer.SKIN
	elif depth < 0.66:
		layer_type = DamageLayer.MUSCLE
	else:
		layer_type = DamageLayer.BONE
		# exposed bone: only the innermost layer is bone, outer rings stay muscle
		if layer < total_layers - 1:
			layer_type = DamageLayer.MUSCLE
	material.albedo_color = _get_layer_color(layer_type)
	material.albedo_texture = _get_decal_texture()
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.roughness = 0.95
	material.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_ALWAYS
	_decal_materials[key] = material
	return material


static func _get_surface_decal_material(decal_type: String) -> Material:
	var key := "surface_%s" % decal_type
	if _decal_materials.has(key):
		return _decal_materials[key]
	var material := StandardMaterial3D.new()
	match decal_type:
		"splatter", "splatter_air":
			material.albedo_color = Color(0.35, 0.01, 0.01, 0.75)
		"trail":
			material.albedo_color = Color(0.28, 0.008, 0.008, 0.65)
		_:
			material.albedo_color = Color(0.3, 0.01, 0.01, 0.7)
	material.albedo_texture = (_get_splat_texture() if (decal_type.begins_with("splatter") or decal_type == "trail") else _get_decal_texture())
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.roughness = 1.0
	material.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_ALWAYS
	_decal_materials[key] = material
	return material


static func _get_puddle_material() -> Material:
	if _puddle_material == null:
		var material := StandardMaterial3D.new()
		material.albedo_color = Color(0.22, 0.005, 0.005, 0.85)
		material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		material.roughness = 0.15
		material.metallic = 0.05
		_puddle_material = material
	return _puddle_material


static func _get_decal_texture() -> Texture2D:
	if _decal_texture == null:
		var gradient := Gradient.new()
		gradient.add_point(0.0, Color(1.0, 1.0, 1.0, 1.0))
		gradient.add_point(0.5, Color(1.0, 1.0, 1.0, 0.65))
		gradient.add_point(1.0, Color(1.0, 1.0, 1.0, 0.0))
		var texture := GradientTexture2D.new()
		texture.gradient = gradient
		texture.fill = GradientTexture2D.FILL_RADIAL
		texture.fill_from = Vector2(0.5, 0.5)
		texture.fill_to = Vector2(1.0, 0.5)
		texture.width = 64
		texture.height = 64
		_decal_texture = texture
	return _decal_texture


## Irregular blob with ragged edge and droplets, so splatters don't read as squares.
static func _get_splat_texture() -> Texture2D:
	if _splat_texture == null:
		var size := 64
		var img := Image.create(size, size, false, Image.FORMAT_RGBA8)
		var rng := RandomNumberGenerator.new()
		rng.seed = 7741
		var harmonics: Array = []
		for k in 6:
			harmonics.append([rng.randf_range(0.03, 0.09), float(k + 2), rng.randf_range(0.0, TAU)])
		for y in size:
			for x in size:
				var dx := (x + 0.5) / size * 2.0 - 1.0
				var dy := (y + 0.5) / size * 2.0 - 1.0
				var r := sqrt(dx * dx + dy * dy)
				var ang := atan2(dy, dx)
				var edge := 0.5
				for h in harmonics:
					edge += h[0] * sin(h[1] * ang + h[2])
				var a := clampf((edge - r) / 0.08, 0.0, 1.0)
				img.set_pixel(x, y, Color(1.0, 1.0, 1.0, a))
		_splat_texture = ImageTexture.create_from_image(img)
	return _splat_texture


static func wound_count() -> int:
	return _wound_decals.size()


static func surface_decal_count() -> int:
	return _surface_decals.size()


static func puddle_count() -> int:
	return _puddles.size()


static func total_decal_count() -> int:
	return _wound_decals.size() + _surface_decals.size()


static func damage_mask_count() -> int:
	return _damage_masks.size()


static func get_damage_mask(npc_id: int) -> Image:
	return _damage_masks.get(npc_id, null)


static func release_npc_damage_mask(npc_id: int) -> void:
	release_damage_mask(npc_id)
