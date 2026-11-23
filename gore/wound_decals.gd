# Adaptado de wound_decals.gd (proyecto UNTITLED), fuente solo lectura.
# Logica basica: sangre en superficies (heridas, salpicaduras, charcos, rastros).
# Sin dependencias del proyecto completo: todo es procedural y usa Node3D genericos.

class_name WoundDecals
extends RefCounted

const GoreTextures = preload("res://gore/gore_textures.gd")
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
	if parent == null or not parent.is_inside_tree() or _decal_limit <= 0 or not (parent is Node3D):
		return {}

	if npc_id >= 0:
		apply_damage_to_mask(npc_id, uv, depth, int(size * 128.0))

	var wound := Node3D.new()
	wound.name = "Wound_%s" % (zone if not zone.is_empty() else "generic")
	var n := normal.normalized() if normal.length_squared() > 0.0001 else Vector3.UP
	parent.add_child(wound)
	# El decal se proyecta sobre el cuerpo en el punto del impacto (su eje Y local = normal).
	wound.global_transform = Transform3D(Basis(Quaternion(Vector3.UP, n)), pos)

	var created_layers: Array = []
	var layer_count := clampi(layers, 1, 4)
	var variant := randi()
	for i in range(layer_count):
		var layer_decal := Decal.new()
		layer_decal.name = "WoundLayer_%d" % i
		var layer_size: float = size * 3.4 if i == 0 else clampf(size * 1.3 * (1.0 - float(i) * 0.3), 0.03, size * 1.3)
		layer_decal.texture_albedo = GoreTextures.get_texture("splat", variant) if i == 0 else GoreTextures.get_texture("pool", variant)
		layer_decal.texture_orm = GoreTextures.orm_texture()
		layer_decal.modulate = GoreTextures.blood_color(0.85) if i == 0 else layer_color(i, layer_count, depth)
		layer_decal.size = Vector3(layer_size, 0.3, layer_size)
		layer_decal.rotation.y = randf() * TAU
		layer_decal.distance_fade_enabled = true
		layer_decal.distance_fade_begin = 15.0
		layer_decal.distance_fade_length = 5.0
		wound.add_child(layer_decal)
		created_layers.append({
			"node": layer_decal,
			"layer": i,
			"size": layer_size,
			"age": 0.0,
		})

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
			_add_surface_decal(parent, hit_pos, hit_normal, clampf(0.12 + force * 0.003, 0.12, 0.45), "splatter", droplet_dir)
		else:
			_add_surface_decal(parent, ray_to, Vector3.UP, clampf(0.10 + force * 0.002, 0.10, 0.30), "splatter_air", droplet_dir, true)


## Decal real (proyectado) sobre una superficie. kind: splat|drop|trail. dir (opcional) orienta el eje largo de rastros/estallidos.
## snap_to_floor: busca el piso real bajo pos (para puntos en el aire); con superficie ya conocida (pared) va en false.
static func _add_surface_decal(parent: Node, pos: Vector3, normal: Vector3, size: float, decal_type: String, dir: Vector3 = Vector3.ZERO, snap_to_floor: bool = false) -> Decal:
	if parent == null or not parent.is_inside_tree() or _decal_limit <= 0:
		return null
	var impact_pos := pos
	var impact_normal := normal.normalized() if normal.length_squared() > 0.0001 else Vector3.UP
	if snap_to_floor:
		var surface := _raycast_ground(parent, pos + Vector3.UP * 0.3)
		if not surface.is_empty():
			impact_pos = surface["position"]
			impact_normal = surface["normal"]
	var kind := "trail" if decal_type == "trail" else ("drop" if decal_type == "drip" or randf() < 0.45 else "splat")
	var decal := Decal.new()
	decal.name = "SurfaceDecal_%s" % decal_type
	decal.texture_albedo = GoreTextures.get_texture(kind)
	decal.texture_orm = GoreTextures.orm_texture()
	decal.modulate = GoreTextures.blood_color(0.6)
	decal.size = Vector3(size, 0.12, size)
	decal.distance_fade_enabled = true
	decal.distance_fade_begin = 15.0
	decal.distance_fade_length = 5.0
	_world_parent(parent).add_child(decal)
	var basis := Basis(Quaternion(Vector3.UP, impact_normal))
	var yaw := randf() * TAU
	if dir.length_squared() > 0.0001:
		var local_dir := basis.inverse() * dir.normalized()
		if Vector2(local_dir.x, local_dir.z).length_squared() > 0.0001:
			yaw = atan2(local_dir.x, local_dir.z) + (PI if randf() < 0.3 else 0.0)
	decal.global_transform = Transform3D(basis * Basis(Vector3.UP, yaw), impact_pos + impact_normal * 0.03)
	_surface_decals.append({
		"root": decal,
		"position": impact_pos,
		"normal": impact_normal,
		"age": 0.0,
		"type": decal_type,
	})
	_enforce_limits()
	return decal


## Nodo donde cuelgan los decals del mundo (escena actual, o la raíz): no siguen al NPC que cae.
static func _world_parent(parent: Node) -> Node:
	var tree := parent.get_tree()
	return tree.current_scene if tree.current_scene != null else tree.root


## Gota que cae en una superficie (la usa GoreSystem tras el trazado balístico).
static func add_drop_decal(parent: Node, pos: Vector3, normal: Vector3, size: float, dir: Vector3 = Vector3.ZERO) -> void:
	_add_surface_decal(parent, pos, normal, size, "splatter", dir, false)
	if size > 0.2 and randf() < 0.55:
		add_run(parent, pos, normal, size)


## Churrete que resbala por una pared: el decal de rastro nace corto y se alarga hacia abajo (solo superficies verticales).
static func add_run(parent: Node, pos: Vector3, normal: Vector3, size: float) -> void:
	if absf(normal.y) > 0.35:
		return
	var w := size * 0.45
	var decal := _add_surface_decal(parent, pos, normal, w, "trail", Vector3.DOWN, false)
	if decal == null:
		return
	var n := normal.normalized()
	var down := (Vector3.DOWN - n * Vector3.DOWN.dot(n)).normalized()
	var start := decal.global_position
	var length := randf_range(0.4, 0.9)
	var tw := decal.create_tween().set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
	tw.tween_method(func(t: float) -> void:
		if is_instance_valid(decal):
			var z := lerpf(w, length, t)
			decal.size = Vector3(w, 0.12, z)
			decal.global_position = start + down * (z - w) * 0.5, 0.0, 1.0, randf_range(3.0, 5.0))


static func create_trail(parent: Node, from_pos: Vector3, to_pos: Vector3) -> void:
	if parent == null or not parent.is_inside_tree() or _decal_limit <= 0:
		return
	var distance := from_pos.distance_to(to_pos)
	if distance < 0.1:
		return
	var steps := clampi(ceili(distance / 0.4), 1, 3)
	var dir := (to_pos - from_pos).normalized()
	for i in range(steps):
		var t := float(i + 1) / float(steps)
		var size: float = randf_range(0.28, 0.42) * (1.0 - t * 0.4)
		_add_surface_decal(parent, from_pos.lerp(to_pos, t), Vector3.UP, size, "trail", Vector3(dir.x, 0.0, dir.z) if absf(dir.y) < 0.9 else Vector3.ZERO, true)


static func create_puddle(parent: Node, pos: Vector3, normal: Vector3, initial_size: float) -> Node3D:
	if parent == null or not parent.is_inside_tree() or _puddle_limit <= 0:
		return null

	# Piso real bajo pos (arranca sobre el pie del cuerpo, así sirve en cualquier altura de piso).
	var top_y := pos.y
	if parent is Node3D:
		top_y = maxf(top_y, (parent as Node3D).global_position.y)
	var surface := _raycast_ground(parent, Vector3(pos.x, top_y + 0.6, pos.z))
	var impact_pos: Vector3 = surface.get("position", pos)
	var impact_normal: Vector3 = surface.get("normal", normal)
	if surface.is_empty() or impact_normal.y < 0.4:
		impact_pos = pos
		impact_normal = normal.normalized() if normal.length_squared() > 0.0001 else Vector3.UP

	var puddle := Node3D.new()
	puddle.name = "BloodPuddle"
	_world_parent(parent).add_child(puddle)
	puddle.global_transform = Transform3D(Basis(Quaternion(Vector3.UP, impact_normal.normalized())), impact_pos)

	var diameter := clampf(initial_size, 0.08, 0.6)
	var layers: Array = []
	for i in range(3 if _puddle_limit >= 24 else 2):
		var d := Decal.new()
		d.name = "PuddleLayer_%d" % i
		d.texture_albedo = GoreTextures.get_texture("pool" if i < 2 else "drop")
		d.texture_orm = GoreTextures.orm_texture()
		d.modulate = GoreTextures.blood_color(0.45 - 0.15 * i)
		d.rotation.y = randf() * TAU
		d.position.y = 0.02
		d.distance_fade_enabled = true
		d.distance_fade_begin = 20.0
		d.distance_fade_length = 5.0
		puddle.add_child(d)
		layers.append({"decal": d, "mult": [1.0, 0.62, 1.35][i]})

	var entry := {
		"node": puddle,
		"position": impact_pos,
		"normal": impact_normal,
		"size": diameter,
		"max_size": diameter * PUDDLE_MAX_SIZE_MULT,
		"age": 0.0,
		"growing": true,
		"layers": layers,
	}
	_puddles.append(entry)
	_apply_puddle_size(entry)
	_enforce_limits()
	return puddle


static func _apply_puddle_size(entry: Dictionary) -> void:
	var s: float = entry["size"]
	(entry["node"] as Node3D).set_meta("diameter", s)
	for l in entry["layers"]:
		var d: Decal = l["decal"]
		if is_instance_valid(d):
			var w: float = s * l["mult"]
			d.size = Vector3(w, 0.12, w)


## Un charco que sigue sangrando: sube su tamaño máximo (diámetro, m) y vuelve a crecer.
static func feed_puddle(node: Node3D, amount: float) -> void:
	for entry in _puddles:
		if entry.get("node", null) == node:
			entry["max_size"] = minf(float(entry["max_size"]) + amount, 2.6)
			entry["growing"] = true
			return


static func update_puddles(delta: float) -> void:
	if delta <= 0.0 or _puddles.is_empty():
		return
	for puddle in _puddles:
		if not is_instance_valid(puddle.get("node", null)):
			continue
		puddle["age"] = float(puddle.get("age", 0.0)) + delta
		if bool(puddle.get("growing", false)):
			var s: float = puddle["size"]
			var mx: float = puddle["max_size"]
			s += (mx - s) * (1.0 - exp(-delta * 0.5))
			puddle["size"] = s
			if mx - s < 0.01:
				puddle["growing"] = false
			_apply_puddle_size(puddle)


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
	_limb_trail_material = null


## Piso real bajo `from` (mismo raycast que usan charcos y rastros).
static func floor_below(parent: Node, from: Vector3) -> Dictionary:
	return _raycast_ground(parent, from)


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
	if parent is CollisionObject3D:
		query.exclude = [(parent as CollisionObject3D).get_rid()]
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


static func layer_color(layer: int, total_layers: int, depth: float) -> Color:
	var layer_type: int
	if depth < 0.33:
		layer_type = DamageLayer.SKIN
	elif depth < 0.66:
		layer_type = DamageLayer.MUSCLE
	else:
		layer_type = DamageLayer.BONE
		# hueso expuesto: solo la capa más interna; los anillos externos siguen siendo músculo
		if layer < total_layers - 1:
			layer_type = DamageLayer.MUSCLE
	return _get_layer_color(layer_type)


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
