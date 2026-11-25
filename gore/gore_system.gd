# Adaptado de gore_system.gd (proyecto UNTITLED), fuente solo lectura.
# Port base: sangre en superficies y desmembramiento simple, sin dependencias
# de modulos ausentes en esta base (vr_performance, content_registry, game_session).

class_name GoreSystem
extends RefCounted

const WoundDecalsScript = preload("res://gore/wound_decals.gd")
const GoreDriverScript = preload("res://gore/gore_driver.gd")
const MeshSlicerScript = preload("res://gore/mesh_slicer/mesh_slicer.gd")

enum GoreLevel { OFF = 0, NORMAL = 1, EXTREME = 2 }

const MAX_DECALS_NORMAL := 24
const MAX_DECALS_EXTREME := 48
const MAX_PUDDLES_NORMAL := 16
const MAX_PUDDLES_EXTREME := 32
const MAX_PARTS_NORMAL := 12
const MAX_PARTS_EXTREME := 24
const MAX_ACTIVE_PARTICLES_NORMAL := 24
const MAX_ACTIVE_PARTICLES_EXTREME := 48
const MAX_SCREEN_SPLATTERS := 4
const MAX_DISTANCE_PARTICLE := 30.0
const MAX_DISTANCE_PART := 35.0
const STUMP_BLEED_TIME := 6.0

static var _part_pool: Array = []
static var _active_particles: Array = []
static var _screen_splatters: Array = []
static var _stump_bleeds: Array = []
static var _blood_mesh = null
static var _blood_material = null
static var _stump_cap_material = null
static var _part_material = null
static var _gore_level: int = GoreLevel.NORMAL
static var _screen_root: Viewport = null
static var _driver: Node = null


static func initialize() -> void:
	apply_gore_level(_gore_level)


static func apply_gore_level(level: int) -> void:
	_gore_level = clampi(level, GoreLevel.OFF, GoreLevel.EXTREME)
	_apply_limits_for_level()


static func _apply_limits_for_level() -> void:
	match _gore_level:
		GoreLevel.OFF:
			WoundDecalsScript.set_limits(0, 0, 0, 0)
		GoreLevel.NORMAL:
			WoundDecalsScript.set_limits(
				MAX_DECALS_NORMAL, MAX_PUDDLES_NORMAL,
				MAX_PARTS_NORMAL, MAX_ACTIVE_PARTICLES_NORMAL
			)
		GoreLevel.EXTREME:
			WoundDecalsScript.set_limits(
				MAX_DECALS_EXTREME, MAX_PUDDLES_EXTREME,
				MAX_PARTS_EXTREME, MAX_ACTIVE_PARTICLES_EXTREME
			)


static func get_gore_level() -> int:
	return _gore_level


static func set_gore_level(level) -> void:
	if typeof(level) == TYPE_INT:
		apply_gore_level(int(level))


static func gore_enabled() -> bool:
	return get_gore_level() > GoreLevel.OFF


static func is_extreme() -> bool:
	return get_gore_level() >= GoreLevel.EXTREME


static func get_limits() -> Dictionary:
	return {
		"decals": WoundDecalsScript.get_decal_limit(),
		"puddles": WoundDecalsScript.get_puddle_limit(),
		"parts": WoundDecalsScript.get_part_limit(),
		"active_particles": WoundDecalsScript.get_active_particle_limit(),
	}


static func log_budgets() -> void:
	var limits := get_limits()
	print("[GoreSystem] Budgets: decals=%d, puddles=%d, parts=%d, active_particles=%d, level=%d" % [
		limits["decals"], limits["puddles"], limits["parts"],
		limits["active_particles"], get_gore_level()
	])


static func set_screen_root(viewport: Viewport) -> void:
	_screen_root = viewport if is_instance_valid(viewport) else null


static func create_bullet_wound(parent: Node, pos: Vector3, normal: Vector3, is_exit: bool = false, zone: String = "", npc_id: int = -1, uv: Vector2 = Vector2(0.5, 0.5), depth: float = 0.5) -> Dictionary:
	if not gore_enabled() or parent == null or not parent.is_inside_tree():
		return {}
	var size: float = 0.22 if is_exit else 0.12
	var depth_layers: int = 3 if is_extreme() else 2
	return WoundDecalsScript.create_wound(parent, pos, normal, size, depth_layers, zone, npc_id, uv, depth)


static func _ensure_driver(node: Node) -> void:
	if is_instance_valid(_driver) or node == null or not node.is_inside_tree():
		return
	_driver = GoreDriverScript.new()
	_driver.name = "GoreDriver"
	node.get_tree().root.add_child.call_deferred(_driver)


## Gotas balísticas: cada una vuela con gravedad, se traza con raycast y deja un decal donde cae (piso o pared reales), con retraso = tiempo de vuelo.
## Devuelve cuántas aterrizaron. Solo en el paso de física (raycast); fuera de él no hace nada.
static func _land_drops(parent: Node, origin: Vector3, dir: Vector3, spread_deg: float, vmin: float, vmax: float, count: int, size_min: float, size_max: float) -> int:
	if count <= 0 or not (parent is Node3D) or not Engine.is_in_physics_frame():
		return 0
	var world := (parent as Node3D).get_world_3d()
	if world == null or world.direct_space_state == null:
		return 0
	var space := world.direct_space_state
	var excl: Array[RID] = []
	if parent is CollisionObject3D:
		excl.append((parent as CollisionObject3D).get_rid())
	var d := dir.normalized() if dir.length_squared() > 0.0001 else Vector3.UP
	var ref := Vector3.UP if absf(d.dot(Vector3.UP)) < 0.95 else Vector3.FORWARD
	var right := d.cross(ref).normalized()
	var up := right.cross(d).normalized()
	var g := Vector3(0.0, -9.8, 0.0)
	var tree := parent.get_tree()
	var landed := 0
	for i in range(count):
		var a := randf() * TAU
		var r := tan(deg_to_rad(spread_deg)) * sqrt(randf())
		var v := (d + (right * cos(a) + up * sin(a)) * r).normalized() * randf_range(vmin, vmax)
		var prev := origin
		var t := 0.0
		for step in range(14):
			var nt := t + 0.07
			var next := origin + v * nt + g * (0.5 * nt * nt)
			var query := PhysicsRayQueryParameters3D.create(prev, next)
			query.collision_mask = 3
			query.exclude = excl
			var hit := space.intersect_ray(query)
			if not hit.is_empty():
				var hp: Vector3 = hit["position"]
				var hn: Vector3 = hit["normal"]
				var vel := v + g * (t + 0.035)
				var sz := randf_range(size_min, size_max)
				tree.create_timer(t + 0.035).timeout.connect(func() -> void:
					if is_instance_valid(parent) and parent.is_inside_tree():
						WoundDecalsScript.add_drop_decal(parent, hp, hn, sz, vel))
				landed += 1
				break
			prev = next
			t = nt
	return landed


## Chorro de impacto: gotas alargadas por la velocidad (0.4 s) + manchas reales donde aterrizan.
static func blood_spray(parent: Node, point: Vector3, normal: Vector3) -> GPUParticles3D:
	if not gore_enabled() or parent == null or not parent.is_inside_tree():
		return null
	if WoundDecalsScript.get_active_particle_limit() <= 0:
		return null
	_ensure_driver(parent)
	var dir := normal.normalized() if normal.length_squared() > 0.0001 else Vector3.UP
	var process := ParticleProcessMaterial.new()
	process.direction = dir
	process.spread = 28.0
	process.initial_velocity_min = 2.0
	process.initial_velocity_max = 5.5
	process.gravity = Vector3(0.0, -9.8, 0.0)
	process.scale_min = 0.4
	process.scale_max = 2.0
	process.particle_flag_align_y = true
	var particles := GPUParticles3D.new()
	particles.name = "BloodSpray"
	particles.amount = 56 if is_extreme() else 36
	particles.lifetime = 0.55
	particles.one_shot = true
	particles.explosiveness = 0.9
	particles.process_material = process
	particles.draw_pass_1 = _get_blood_mesh()
	particles.material_override = _get_blood_material()
	particles.finished.connect(particles.queue_free)
	parent.add_child(particles)
	particles.global_position = point
	particles.emitting = true
	_active_particles.append(particles)
	_enforce_active_particle_limit()
	_land_drops(parent, point, dir, 24.0, 2.5, 5.5, 8 if is_extreme() else 5, 0.2, 0.5)
	return particles


## Goteo de ~3 s desde una herida: gotas alargadas, cada una mancha el piso REAL (raycast hacia abajo) y alimentan un charco creciente.
static func blood_drip(parent: Node, point: Vector3) -> GPUParticles3D:
	if not gore_enabled() or parent == null or not parent.is_inside_tree():
		return null
	if WoundDecalsScript.get_active_particle_limit() <= 0:
		return null
	_ensure_driver(parent)
	var process := ParticleProcessMaterial.new()
	process.direction = Vector3.DOWN
	process.spread = 8.0
	process.initial_velocity_min = 0.2
	process.initial_velocity_max = 0.6
	process.gravity = Vector3(0.0, -9.8, 0.0)
	process.scale_min = 0.6
	process.scale_max = 1.0
	process.particle_flag_align_y = true
	var particles := GPUParticles3D.new()
	particles.name = "BloodDrip"
	particles.amount = 8
	particles.lifetime = 1.0
	particles.one_shot = false
	particles.process_material = process
	particles.draw_pass_1 = _get_blood_mesh()
	particles.material_override = _get_blood_material()
	parent.add_child(particles)
	particles.global_position = point
	particles.emitting = true
	var tree := parent.get_tree()
	tree.create_timer(3.0).timeout.connect(func() -> void:
		if is_instance_valid(particles):
			particles.emitting = false)
	tree.create_timer(4.5).timeout.connect(particles.queue_free)
	var floor_hit := WoundDecalsScript.floor_below(parent, point)
	if not floor_hit.is_empty():
		var fp: Vector3 = floor_hit["position"]
		var fn: Vector3 = floor_hit["normal"]
		var fall := sqrt(2.0 * maxf(point.y - fp.y, 0.05) / 9.8)
		var holder: Array = []
		for k in range(5):
			tree.create_timer(fall + 0.2 + k * 0.6).timeout.connect(func() -> void:
				if not (is_instance_valid(parent) and parent.is_inside_tree()) or not gore_enabled():
					return
				var pos := fp + Vector3(randf_range(-0.03, 0.03), 0.0, randf_range(-0.03, 0.03))
				WoundDecalsScript.add_drop_decal(parent, pos, fn, randf_range(0.14, 0.26))
				if holder.is_empty():
					holder.append(create_puddle(parent, fp, fn, 0.22))
				elif is_instance_valid(holder[0]):
					WoundDecalsScript.feed_puddle(holder[0], 0.08))
	_active_particles.append(particles)
	_enforce_active_particle_limit()
	return particles


static func create_directional_splatter(parent: Node, pos: Vector3, direction: Vector3, force: float, surface_normal: Vector3 = Vector3.UP) -> void:
	if not gore_enabled() or parent == null or not parent.is_inside_tree():
		return
	var cone_angle := 35.0
	var max_drops: int = 24 if is_extreme() else 16
	var droplet_count := clampi(int(force * 0.8), 6, max_drops)
	var spread := cone_angle * (1.0 - clampf(force / 100.0, 0.0, 0.5))
	WoundDecalsScript.create_splatter(parent, pos, direction, spread, droplet_count, force)


static func create_blood_trail(parent: Node, from_pos: Vector3, to_pos: Vector3) -> void:
	if not gore_enabled() or parent == null or not parent.is_inside_tree():
		return
	WoundDecalsScript.create_trail(parent, from_pos, to_pos)


static func create_puddle(parent: Node, pos: Vector3, normal: Vector3, initial_size: float = 0.3) -> Node3D:
	if not gore_enabled() or parent == null or not parent.is_inside_tree():
		return null
	return WoundDecalsScript.create_puddle(parent, pos, normal, initial_size)


static func dismember_limb(parent: Node, bone_idx: int, skeleton: Skeleton3D, hit_pos: Vector3, hit_normal: Vector3, cut_type: String = "clean") -> Dictionary:
	if not gore_enabled() or parent == null or not parent.is_inside_tree() or skeleton == null:
		return {}
	var bone_count := skeleton.get_bone_count()
	if bone_count <= 0 or bone_idx < 0 or bone_idx >= bone_count:
		return {}

	var bone_name := String(skeleton.get_bone_name(bone_idx))
	var bone_pos: Vector3 = skeleton.to_global(skeleton.get_bone_global_pose(bone_idx).origin)
	var bone_length := _get_bone_length(skeleton, bone_idx)
	var safe_normal := hit_normal.normalized() if hit_normal.length_squared() > 0.0001 else Vector3.UP

	var stump_cap := _create_stump_cap(parent, bone_pos, safe_normal, bone_length * 0.5)
	var detached_limb := _create_detached_limb(parent, bone_idx, skeleton, bone_pos, bone_length, safe_normal, hit_pos)

	var bleed_node: Node3D = null
	if is_instance_valid(detached_limb):
		bleed_node = _create_stump_bleed(parent, bone_pos, -safe_normal)
		if is_instance_valid(bleed_node):
			_stump_bleeds.append({
				"node": bleed_node,
				"timer": STUMP_BLEED_TIME,
				"position": bone_pos,
				"normal": -safe_normal,
				"age": 0.0,
				"tick": 0.0,
			})
			blood_spray(parent, bone_pos, -safe_normal + Vector3.UP)

	# Idea from Dismemberment_Tutorial_Godot4.2 scripts/dismemberment.gd:_remove_bone (MIT, Alenvei): scale the bone ~0 so the skinned limb (and its children) vanish.
	# shortcut: an AnimationPlayer that keys scale overwrites this; move to a SkeletonModifier3D when NPCs get animated skeletons.
	skeleton.set_bone_pose_scale(bone_idx, Vector3.ONE * 0.0001)

	var joints: Array = []
	if is_instance_valid(detached_limb) and detached_limb.has_meta("pin_joints"):
		joints = detached_limb.get_meta("pin_joints", [])

	return {
		"stump_cap": stump_cap,
		"detached_limb": detached_limb,
		"bone_name": bone_name,
		"bone_idx": bone_idx,
		"npc_changes": _calculate_npc_consequences(bone_name),
		"bleed_node": bleed_node,
		"joints": joints,
	}


## Cuts a static (non-skinned) MeshInstance3D along the plane through cut_point with normal cut_normal (world space).
## The instance keeps the half on the -normal side; the other half becomes a loose RigidBody3D, returned (null on failure).
static func slice_mesh_instance(mesh_instance: MeshInstance3D, cut_point: Vector3, cut_normal: Vector3) -> RigidBody3D:
	if not gore_enabled() or mesh_instance == null or not mesh_instance.is_inside_tree() or mesh_instance.mesh == null:
		return null
	if cut_normal.length_squared() < 0.0001 or WoundDecalsScript.get_part_limit() <= 0:
		return null
	var n := cut_normal.normalized()
	var up := Vector3.UP if absf(n.dot(Vector3.UP)) < 0.99 else Vector3.RIGHT
	# MeshSlicer wants the plane normal on +Z of the slice transform, relative to the mesh.
	var plane := Transform3D(Basis.looking_at(-n, up), cut_point)
	var halves: Array = MeshSlicerScript.slice_mesh(mesh_instance.global_transform.affine_inverse() * plane, mesh_instance.mesh, _get_stump_cap_material())
	if halves.size() < 2 or halves[0] == null or halves[1] == null or halves[1].get_faces().size() < 3:
		return null
	mesh_instance.mesh = halves[0]
	var piece := RigidBody3D.new()
	piece.name = "SlicedPiece"
	var visual := MeshInstance3D.new()
	visual.name = "MeshInstance3D"
	visual.mesh = halves[1]
	visual.material_override = mesh_instance.material_override
	piece.add_child(visual)
	var shape := CollisionShape3D.new()
	shape.shape = (halves[1] as Mesh).create_convex_shape()
	piece.add_child(shape)
	var tree := mesh_instance.get_tree()
	(tree.current_scene if tree.current_scene else tree.root).add_child(piece)
	piece.global_transform = mesh_instance.global_transform
	piece.apply_impulse(n * 1.5, cut_point - piece.global_position)
	blood_spray(piece, cut_point, n)
	_part_pool.append(piece)
	_enforce_part_limit()
	return piece


static func _create_stump_cap(parent: Node, pos: Vector3, normal: Vector3, radius: float) -> MeshInstance3D:
	if parent == null or not parent.is_inside_tree():
		return null
	var cap := MeshInstance3D.new()
	cap.name = "StumpCap"
	var cylinder := CylinderMesh.new()
	var r: float = clampf(radius, 0.05, 0.15)
	cylinder.top_radius = r
	cylinder.bottom_radius = r
	cylinder.height = 0.04
	cylinder.radial_segments = 12
	cap.mesh = cylinder
	cap.material_override = _get_stump_cap_material()
	parent.add_child(cap)
	cap.global_position = pos + normal * 0.02
	cap.global_rotation = Quaternion(Vector3.UP, normal).get_euler()
	return cap


static func _create_detached_limb(parent: Node, bone_idx: int, skeleton: Skeleton3D, pos: Vector3, length: float, hit_normal: Vector3, hit_pos: Vector3) -> RigidBody3D:
	if parent == null or not parent.is_inside_tree() or skeleton == null:
		return null
	if WoundDecalsScript.get_part_limit() <= 0:
		return null

	var limb := RigidBody3D.new()
	limb.name = "DetachedLimb_%s" % String(skeleton.get_bone_name(bone_idx)).replace(".", "_")
	limb.mass = clampf(length * 2.5, 0.8, 5.0)

	var shape := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = clampf(length * 0.12, 0.05, 0.15)
	capsule.height = clampf(length * 0.7, 0.15, 0.8)
	shape.shape = capsule
	limb.add_child(shape)

	var visual := MeshInstance3D.new()
	visual.name = "MeshInstance3D"
	visual.mesh = _create_limb_mesh(length)
	visual.material_override = _get_part_material()
	limb.add_child(visual)

	parent.add_child(limb)
	limb.global_position = pos

	var joints: Array = []
	for child_idx in skeleton.get_bone_children(bone_idx):
		var child_name := String(skeleton.get_bone_name(child_idx))
		var child_pos: Vector3 = skeleton.to_global(skeleton.get_bone_global_pose(child_idx).origin)
		var child_length := _get_bone_length(skeleton, child_idx)
		var child_limb := RigidBody3D.new()
		child_limb.name = "DetachedLimb_%s" % child_name.replace(".", "_")
		child_limb.mass = clampf(child_length * 2.5, 0.8, 5.0)
		var child_shape := CollisionShape3D.new()
		var child_capsule := CapsuleShape3D.new()
		child_capsule.radius = clampf(child_length * 0.12, 0.05, 0.15)
		child_capsule.height = clampf(child_length * 0.7, 0.15, 0.8)
		child_shape.shape = child_capsule
		child_limb.add_child(child_shape)
		var child_visual := MeshInstance3D.new()
		child_visual.name = "MeshInstance3D"
		child_visual.mesh = _create_limb_mesh(child_length)
		child_visual.material_override = _get_part_material()
		child_limb.add_child(child_visual)
		parent.add_child(child_limb)
		child_limb.global_position = child_pos
		var joint := PinJoint3D.new()
		joint.name = "PinJoint3D_%s" % child_name.replace(".", "_")
		child_limb.add_child(joint)
		joint.set_node_a(limb.get_path())
		joint.set_node_b(child_limb.get_path())
		_part_pool.append(child_limb)
		joints.append(joint)
	limb.set_meta("pin_joints", joints)

	var outward: Vector3 = (pos - (parent.global_position if parent is Node3D else Vector3.ZERO)).normalized()
	if outward.length_squared() < 0.0001:
		outward = -hit_normal
	var impulse_pos: Vector3 = hit_pos if hit_pos != Vector3.ZERO else pos
	limb.apply_impulse((outward + Vector3.UP * 0.4).normalized() * (3.0 + randf() * 4.0), impulse_pos)
	limb.apply_torque(Vector3(randf_range(-2.0, 2.0), randf_range(-2.0, 2.0), randf_range(-2.0, 2.0)))

	_part_pool.append(limb)
	_enforce_part_limit()
	return limb


static func _create_limb_mesh(length: float) -> Mesh:
	var cylinder := CylinderMesh.new()
	var r: float = clampf(length * 0.1, 0.04, 0.12)
	cylinder.top_radius = r
	cylinder.bottom_radius = r
	cylinder.height = clampf(length * 0.8, 0.15, 0.7)
	cylinder.radial_segments = 10
	return cylinder


static func _create_stump_bleed(parent: Node, pos: Vector3, normal: Vector3) -> Node3D:
	if parent == null or not parent.is_inside_tree():
		return null
	if WoundDecalsScript.get_active_particle_limit() <= 0:
		return null
	_ensure_driver(parent)
	var anchor := Node3D.new()
	anchor.name = "StumpBleed"
	parent.add_child(anchor)
	anchor.global_position = pos

	# Chorro arterial: sale por el corte y se curva por la gravedad (alargado según su velocidad).
	var particles := CPUParticles3D.new()
	particles.name = "Jet"
	particles.amount = 40
	particles.lifetime = 0.9
	particles.one_shot = false
	particles.emitting = true
	particles.direction = (normal.normalized() + Vector3.UP * 0.9).normalized()
	particles.spread = 12.0
	particles.initial_velocity_min = 1.6
	particles.initial_velocity_max = 3.4
	particles.gravity = Vector3(0.0, -7.0, 0.0)
	particles.scale_amount_min = 0.8
	particles.scale_amount_max = 1.5
	particles.particle_flag_align_y = true
	particles.mesh = _get_blood_mesh()
	particles.material_override = _get_blood_material()
	anchor.add_child(particles)

	_active_particles.append(anchor)
	_enforce_active_particle_limit()
	return anchor


static func _calculate_npc_consequences(bone_name: String) -> Dictionary:
	var changes := {}
	var name_lower := bone_name.to_lower()
	if name_lower.contains("leg") or name_lower.contains("foot"):
		changes["mobility"] = "crawl"
		changes["speed_multiplier"] = 0.25
	elif name_lower.contains("arm") or name_lower.contains("hand"):
		changes["drops_weapon"] = true
		changes["can_aim"] = false
		changes["melee_only"] = true
	return changes


static func add_screen_splatter(intensity: float) -> void:
	if not gore_enabled():
		return
	if _screen_splatters.size() >= MAX_SCREEN_SPLATTERS:
		var old = _screen_splatters.pop_front()
		if is_instance_valid(old):
			old.queue_free()
	var splatter := _create_screen_splatter(intensity)
	if splatter != null:
		_screen_splatters.append(splatter)


static func _create_screen_splatter(intensity: float) -> Control:
	if _screen_root == null or not is_instance_valid(_screen_root):
		return null
	var splatter := TextureRect.new()
	splatter.name = "ScreenSplatter"
	splatter.anchors_preset = Control.PRESET_FULL_RECT
	splatter.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	splatter.texture = _generate_splatter_texture(intensity)
	splatter.modulate = Color(1.0, 1.0, 1.0, clampf(0.3 + intensity * 0.5, 0.3, 0.85))
	_screen_root.add_child(splatter)
	if not splatter.is_inside_tree():
		splatter.queue_free()
		return null
	var tween := splatter.create_tween()
	if tween == null:
		splatter.queue_free()
		return null
	tween.tween_property(splatter, "modulate:a", 0.0, 2.0 + intensity * 1.5)
	tween.tween_callback(Callable(GoreSystem, "_remove_splatter").bind(splatter))
	return splatter


static func _generate_splatter_texture(intensity: float) -> Texture2D:
	var img := Image.create(64, 64, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var rng := RandomNumberGenerator.new()
	rng.seed = (int(intensity * 1000.0) ^ 0xFEED) & 0x7FFFFFFF
	var drops := clampi(int(5.0 + intensity * 15.0), 5, 30)
	for i in range(drops):
		var cx := rng.randi_range(8, 56)
		var cy := rng.randi_range(8, 56)
		var radius := rng.randi_range(3, 9)
		var alpha := rng.randf_range(0.4, 0.9)
		for y in range(maxi(0, cy - radius), mini(63, cy + radius)):
			for x in range(maxi(0, cx - radius), mini(63, cx + radius)):
				var dist := Vector2(x - cx, y - cy).length()
				if dist <= float(radius):
					var a := alpha * (1.0 - dist / float(radius))
					var existing := img.get_pixel(x, y)
					img.set_pixel(x, y, Color(existing.r, existing.g, existing.b, maxf(existing.a, a)))
	return ImageTexture.create_from_image(img)


static func _remove_splatter(splatter: Control) -> void:
	if is_instance_valid(splatter):
		_screen_splatters.erase(splatter)
		splatter.queue_free()


static var _cleanup_timer := 0.0


static func update(delta: float) -> void:
	if not gore_enabled():
		return
	_update_stump_bleeds(delta)
	WoundDecalsScript.update_puddles(delta)
	# La limpieza por distancia no necesita cada fotograma: 4 veces por segundo basta.
	_cleanup_timer -= delta
	if _cleanup_timer <= 0.0:
		_cleanup_timer = 0.25
		_cleanup_distant()


static func _update_stump_bleeds(delta: float) -> void:
	var i := 0
	while i < _stump_bleeds.size():
		var bleed = _stump_bleeds[i]
		if not (bleed is Dictionary):
			_stump_bleeds.remove_at(i)
			continue
		var node = bleed.get("node", null)
		if not is_instance_valid(node):
			_stump_bleeds.remove_at(i)
			continue
		bleed["timer"] = float(bleed.get("timer", 0.0)) - delta
		if bleed["timer"] <= 0.0:
			node.queue_free()
			_stump_bleeds.remove_at(i)
			continue
		# k: 1 recién cortado -> 0 apagado. El chorro pulsa con el "latido" y se debilita.
		var k: float = clampf(float(bleed["timer"]) / STUMP_BLEED_TIME, 0.0, 1.0)
		bleed["age"] = float(bleed.get("age", 0.0)) + delta
		var jet = bleed.get("jet", null)
		if not is_instance_valid(jet):
			jet = (node as Node).get_node_or_null("Jet") as CPUParticles3D
			bleed["jet"] = jet
		if jet != null:
			jet.emitting = k > 0.12
			jet.initial_velocity_max = lerpf(0.8, 3.4, k) * (0.8 + 0.2 * sin(float(bleed["age"]) * 9.0))
		bleed["tick"] = float(bleed.get("tick", 0.0)) - delta
		if bleed["tick"] <= 0.0 and k > 0.1:
			bleed["tick"] = 0.35
			var pos: Vector3 = (node as Node3D).global_position
			var dir: Vector3 = Vector3(bleed["normal"]) + Vector3.UP * 0.9
			_land_drops(node, pos, dir, 14.0, 1.4, 3.2 * (0.5 + 0.5 * k), 1, 0.16, 0.34)
			var pud = bleed.get("puddle", null)
			if not is_instance_valid(pud):
				var fh := WoundDecalsScript.floor_below(node, pos)
				if not fh.is_empty():
					bleed["puddle"] = create_puddle(node, fh["position"], fh["normal"], 0.16)
			else:
				WoundDecalsScript.feed_puddle(pud, 0.07 * k + 0.02)
		i += 1


static func _cleanup_distant() -> void:
	WoundDecalsScript.prune_invalid()
	var camera_pos := Vector3.ZERO
	if _screen_root != null and is_instance_valid(_screen_root):
		var cam := _screen_root.get_camera_3d()
		if cam != null and is_instance_valid(cam):
			camera_pos = cam.global_position
	_cleanup_array_distant(_active_particles, camera_pos, MAX_DISTANCE_PARTICLE)
	_cleanup_array_distant(_part_pool, camera_pos, MAX_DISTANCE_PART)


static func _cleanup_array_distant(arr: Array, camera_pos: Vector3, max_dist: float) -> void:
	var i := arr.size() - 1
	while i >= 0:
		var node = arr[i]
		if not is_instance_valid(node):
			arr.remove_at(i)
		elif camera_pos != Vector3.ZERO and node is Node3D:
			if (node as Node3D).global_position.distance_to(camera_pos) > max_dist:
				node.queue_free()
				arr.remove_at(i)
		i -= 1


static func _enforce_part_limit() -> void:
	_enforce_array_limit(_part_pool, WoundDecalsScript.get_part_limit())


static func _enforce_active_particle_limit() -> void:
	_enforce_array_limit(_active_particles, WoundDecalsScript.get_active_particle_limit())


static func _enforce_array_limit(arr: Array, limit: int) -> void:
	_cleanup_array_distant(arr, Vector3.ZERO, 0.0)
	while arr.size() > maxi(limit, 0):
		var old = arr.pop_front()
		if is_instance_valid(old):
			old.queue_free()


static func clear() -> void:
	WoundDecalsScript.clear()
	for node in _active_particles:
		if is_instance_valid(node):
			node.queue_free()
	for bleed in _stump_bleeds:
		var node = bleed.get("node", null) if bleed is Dictionary else null
		if is_instance_valid(node):
			node.queue_free()
	for splatter in _screen_splatters:
		if is_instance_valid(splatter):
			splatter.queue_free()
	_active_particles.clear()
	_stump_bleeds.clear()
	_screen_splatters.clear()


static func shutdown() -> void:
	clear()
	_part_pool.clear()
	_blood_mesh = null
	_blood_material = null
	_stump_cap_material = null
	_part_material = null
	WoundDecalsScript.shutdown()


static func _get_blood_mesh() -> Mesh:
	if _blood_mesh == null:
		var mesh := SphereMesh.new()
		mesh.radius = 0.007
		mesh.height = 0.034
		mesh.radial_segments = 8
		mesh.rings = 4
		_blood_mesh = mesh
	return _blood_mesh


static func _get_blood_material() -> Material:
	if _blood_material == null:
		var material := StandardMaterial3D.new()
		material.albedo_color = Color(0.4, 0.008, 0.012, 1.0)
		material.roughness = 0.4
		material.metallic_specular = 0.3
		_blood_material = material
	return _blood_material


static func _get_stump_cap_material() -> Material:
	if _stump_cap_material == null:
		var material := StandardMaterial3D.new()
		material.albedo_color = Color(0.6, 0.03, 0.03, 1.0)
		material.roughness = 0.25
		material.metallic = 0.05
		_stump_cap_material = material
	return _stump_cap_material


static func _get_part_material() -> Material:
	if _part_material == null:
		var material := StandardMaterial3D.new()
		material.albedo_color = Color(0.48, 0.04, 0.04, 1.0)
		material.roughness = 0.8
		_part_material = material
	return _part_material


static func _get_bone_length(skeleton: Skeleton3D, bone_idx: int) -> float:
	if skeleton.has_method("get_bone_length"):
		var value := float(skeleton.call("get_bone_length", bone_idx))
		if value > 0.01:
			return value
	var parent_idx := skeleton.get_bone_parent(bone_idx)
	if parent_idx >= 0:
		var pos: Vector3 = skeleton.get_bone_global_pose(bone_idx).origin
		var parent_pos: Vector3 = skeleton.get_bone_global_pose(parent_idx).origin
		return pos.distance_to(parent_pos)
	return 0.25


static func decal_count() -> int:
	return WoundDecalsScript.total_decal_count()


static func puddle_count() -> int:
	return WoundDecalsScript.puddle_count()


static func part_count() -> int:
	return _part_pool.size()


static func active_particle_count() -> int:
	return _active_particles.size()


static func stump_bleed_count() -> int:
	return _stump_bleeds.size()


static func screen_splatter_count() -> int:
	return _screen_splatters.size()


static func get_damage_mask(npc_id: int) -> Image:
	return WoundDecalsScript.get_damage_mask(npc_id)


static func damage_mask_count() -> int:
	return WoundDecalsScript.damage_mask_count()


static func release_npc_damage_mask(npc_id: int) -> void:
	WoundDecalsScript.release_npc_damage_mask(npc_id)


static func apply_damage_to_mask(npc_id: int, uv: Vector2, depth: float, radius_px: int = 8) -> void:
	WoundDecalsScript.apply_damage_to_mask(npc_id, uv, depth, radius_px)
