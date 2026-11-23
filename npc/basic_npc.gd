class_name BasicNpc
extends CharacterBody3D
const GameConfig = preload("res://storage/game_config.gd")
const Sfx = preload("res://audio/sfx.gd")
const GoreSystem = preload("res://gore/gore_system.gd")
const LootDrop = preload("res://npc/loot_drop.gd")
const SHOT_SOUND_PATH := "res://weapons/ak47/ak47_shot.wav"

signal action_changed(action: String)
signal target_changed(source_id: String, visible: bool)
signal damaged(amount: float, health: float)
signal died(source: Node)
signal shot_fired(hit: Dictionary)

const ACTION_IDLE: String = "idle"
const ACTION_PATROL: String = "patrol"
const ACTION_CHASE: String = "chase"
const ACTION_INVESTIGATE: String = "investigate"
const ACTION_FLEE: String = "flee"
const ACTION_WANDER: String = "wander"
const WANDER_RADIUS: float = 6.0
const WANDER_INTERVAL: float = 4.0
const FLEE_DURATION: float = 8.0
const ACTION_DEAD: String = "dead"
const ACTION_SHOOT: String = "shoot"
const ARMED_RANGE: float = 15.0
const FIRE_INTERVAL: float = 0.5
const SHOT_DAMAGE: float = 10.0
const SHOT_SPREAD: float = 0.25
const EYE_HEIGHT: float = 1.6
const GUN_MODEL: String = "res://weapons/ak47/ak47.glb"
const GUN_SOUND: String = "res://weapons/ak47/ak47_shot.wav"

const ROLE_HOSTILE: String = "hostile"
const ROLE_CIVILIAN: String = "civilian"
const ROLE_DEFENDER: String = "defender"
const ROLE_ZOMBIE: String = "zombie"
const ZOMBIE_CHASE_RANGE: float = 14.0

const DEFAULT_VISION_RANGE: float = 18.0
const DEFAULT_PATROL_SPEED: float = 2.0
const DEFAULT_RUN_SPEED: float = 5.5
const DEFAULT_MAX_HEALTH: float = 100.0
const DEFAULT_STOP_DISTANCE: float = 2.0
const DEFAULT_FLEE_DISTANCE: float = 8.0
const ARRIVE_DISTANCE: float = 0.35

static var _active: Array = []

@export var npc_id: String = "npc"
@export var target_id: String = "player"
@export var role: String = ROLE_HOSTILE
@export var vision_range: float = DEFAULT_VISION_RANGE
@export var patrol_speed: float = DEFAULT_PATROL_SPEED
@export var run_speed: float = DEFAULT_RUN_SPEED
@export var max_health: float = DEFAULT_MAX_HEALTH
@export var stop_distance: float = DEFAULT_STOP_DISTANCE
@export var flee_distance: float = DEFAULT_FLEE_DISTANCE
@export var auto_tick: bool = true
## Armed variant: shoots the target when visible within ARMED_RANGE; never flees.
@export var armed: bool = false

var target: Node3D = null
var aim_point: Vector3 = Vector3.ZERO
var has_explicit_aim: bool = false
var patrol_points: Array = []
var health: float = DEFAULT_MAX_HEALTH
var goal: Vector3 = Vector3.ZERO

var collision: CollisionShape3D = null
const MODELS: Array = ["civil_man_casual", "civil_woman_casual", "office_suit", "police_swat", "soldier_female"]
var model: Node3D = null
var _anim: AnimationPlayer = null
var visual: MeshInstance3D = null
var head_visual: MeshInstance3D = null

var _material: StandardMaterial3D = null
var _home: Vector3 = Vector3.ZERO
var _last_seen: Vector3 = Vector3.ZERO
var _action: String = ACTION_IDLE
var _alert: float = 0.0
var leg_left_damage: float = 0.0
var leg_right_damage: float = 0.0
var _dead: bool = false
var _built: bool = false
var _patrol_index: int = -1
var _patrol_ready: bool = false
var _last_result: Dictionary = {}
var _source_id: String = ""
var _flee_time: float = 0.0
var _wander_time: float = 0.0
var _flee_from: Vector3 = Vector3.ZERO
var _fire_cooldown: float = 0.0
var _gun: Node3D = null
var _gun_sound: AudioStreamPlayer3D = null


static func active_count() -> int:
	var count: int = 0
	for entry in _active:
		if is_instance_valid(entry):
			count += 1
	return count


static func clear_registry() -> void:
	_active.clear()


static func spawn(parent: Node3D, position: Vector3, p_options: Dictionary = {}) -> Node3D:
	if parent == null:
		return null
	var npc := BasicNpc.new()
	npc.name = str(p_options.get("id", p_options.get("npc_id", "BasicNpc")))
	npc.apply_options(p_options)
	parent.add_child(npc)
	npc.global_position = position
	if not _active.has(npc):
		_active.append(npc)
	return npc


func _ready() -> void:
	_build()
	if _home == Vector3.ZERO:
		_home = global_position


func _build() -> void:
	if _built:
		return
	_built = true
	add_to_group("damageable")
	add_to_group("basic_npc")
	collision_layer = 1
	collision_mask = 1
	collision = CollisionShape3D.new()
	collision.name = "Collision"
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.35
	capsule.height = 1.8
	collision.shape = capsule
	collision.position = Vector3(0.0, 0.9, 0.0)
	add_child(collision)

	if not _build_model():
		_material = StandardMaterial3D.new()
		_material.albedo_color = _role_color()
		_material.roughness = 0.85
		visual = MeshInstance3D.new()
		visual.name = "Visual"
		var body := CapsuleMesh.new()
		body.radius = 0.35
		body.height = 1.8
		body.radial_segments = 8
		body.rings = 4
		visual.mesh = body
		visual.material_override = _material
		visual.position = Vector3(0.0, 0.9, 0.0)
		add_child(visual)

		head_visual = MeshInstance3D.new()
		head_visual.name = "HeadVisual"
		var sphere := SphereMesh.new()
		sphere.radius = 0.22
		sphere.height = 0.44
		sphere.radial_segments = 8
		sphere.rings = 4
		head_visual.mesh = sphere
		head_visual.material_override = _material
		head_visual.position = Vector3(0.0, 1.72, 0.0)
		add_child(head_visual)
	_attach_gun()


func _build_model() -> bool:
	var scene = load("res://npc/models/%s.gltf" % (["police_swat", "soldier_female"] if armed else MODELS).pick_random())
	if not scene is PackedScene:
		return false
	model = scene.instantiate() as Node3D
	if model == null:
		return false
	model.name = "Model"
	model.rotation.y = PI
	add_child(model)
	_anim = model.find_child("AnimationPlayer", true, false) as AnimationPlayer
	_play("Idle", true)
	return true


func _play(anim_name: String, loop: bool = false) -> bool:
	if _anim == null or not _anim.has_animation(anim_name):
		return false
	_anim.get_animation(anim_name).loop_mode = Animation.LOOP_LINEAR if loop else Animation.LOOP_NONE
	_anim.play(anim_name)
	return true


func _react_hit(point: Vector3, source: Node) -> void:
	if _play("HitRecieve") or _play("Hit"):
		_anim.queue("Idle")
		return
	var from: Vector3 = point if point.length_squared() > 0.0001 else (source.global_position if source is Node3D else Vector3.ZERO)
	var away: Vector3 = global_position - from
	away.y = 0.0
	if away.length_squared() > 0.0001:
		global_position += away.normalized() * 0.15


func _react_death() -> void:
	if _play("Death"):
		return
	if model != null:
		create_tween().tween_property(model, "rotation:x", -PI * 0.5, 0.4)
	for n in [visual, head_visual]:
		if n != null:
			n.visible = false


func apply_options(p_options: Dictionary) -> void:
	npc_id = str(p_options.get("id", p_options.get("npc_id", npc_id)))
	target_id = str(p_options.get("target_id", target_id))
	role = str(p_options.get("role", role))
	vision_range = maxf(0.0, float(p_options.get("vision_range", vision_range)))
	patrol_speed = maxf(0.0, float(p_options.get("patrol_speed", patrol_speed)))
	run_speed = maxf(patrol_speed, float(p_options.get("run_speed", run_speed)))
	max_health = maxf(1.0, float(p_options.get("max_health", max_health)))
	stop_distance = maxf(0.0, float(p_options.get("stop_distance", stop_distance)))
	flee_distance = maxf(1.0, float(p_options.get("flee_distance", flee_distance)))
	auto_tick = bool(p_options.get("auto_tick", auto_tick))
	armed = bool(p_options.get("armed", armed))
	if _built:
		_attach_gun()
	health = clampf(float(p_options.get("health", health)), 0.0, max_health)
	var points: Array = []
	for raw in p_options.get("patrol_points", []):
		points.append(_as_vector(raw))
	patrol_points = points
	var value: Variant = p_options.get("target", null)
	if value is Node3D:
		set_target(value as Node3D)
	elif typeof(value) == TYPE_NODE_PATH:
		set_target(get_node_or_null(value) as Node3D)
	elif value is Vector3:
		set_aim_point(value as Vector3)


func setup(p_options: Dictionary = {}) -> void:
	apply_options(p_options)


func set_target(node: Node3D) -> void:
	target = node
	has_explicit_aim = false
	_source_id = target_id if node == null else str(node.name)
	if node != null and is_inside_tree():
		_face_target()
	target_changed.emit(_source_id, node != null)


func set_aim_point(point: Vector3) -> void:
	aim_point = point
	has_explicit_aim = true
	_source_id = target_id
	target_changed.emit(_source_id, true)


func can_see(point: Vector3) -> bool:
	return global_position.distance_to(point) <= vision_range


func tick(delta: float) -> Dictionary:
	if _dead:
		_set_action(ACTION_DEAD)
		_last_result = {"action": ACTION_DEAD, "visible": false, "distance": -1.0, "goal": global_position}
		return _last_result.duplicate(true)
	var step: float = maxf(delta, 0.0)
	_alert = maxf(0.0, _alert - step * 0.2)
	if _home == Vector3.ZERO:
		_home = global_position
	var target_pos: Vector3 = _effective_target_position()
	var visible: bool = false
	var distance: float = -1.0
	if has_explicit_aim or (target != null and is_instance_valid(target)):
		distance = global_position.distance_to(target_pos)
		visible = can_see(target_pos)
	var was_visible: bool = bool(_last_result.get("visible", false))
	if visible and not was_visible:
		target_changed.emit(_source_id, true)
	elif not visible and was_visible:
		target_changed.emit(_source_id, false)
	if visible:
		_alert = 1.0
		_last_seen = target_pos
	var action: String = ACTION_WANDER
	_fire_cooldown = maxf(0.0, _fire_cooldown - step)
	if armed and visible and distance <= ARMED_RANGE and _has_line_of_sight(target_pos):
		action = ACTION_SHOOT
		goal = global_position
		if _fire_cooldown <= 0.0:
			_fire_cooldown = FIRE_INTERVAL
			_shoot(target_pos)
	elif role == ROLE_ZOMBIE and visible and distance <= ZOMBIE_CHASE_RANGE:
		# Zombi: se acerca lento al jugador en línea recta, sin armas ni huida.
		action = ACTION_WANDER
		goal = target_pos
	elif _flee_time > 0.0:
		_flee_time -= step
		action = ACTION_FLEE
		var away: Vector3 = global_position - _flee_from
		away.y = 0.0
		var escape: Vector3 = away.normalized() if away.length_squared() > 0.0001 else Vector3.FORWARD
		goal = global_position + escape * flee_distance
	else:
		_wander_time -= step
		if _wander_time <= 0.0 or global_position.distance_to(goal) < ARRIVE_DISTANCE:
			if _wander_time <= 0.0:
				_wander_time = WANDER_INTERVAL
				var angle: float = randf() * TAU
				goal = global_position + Vector3(cos(angle), 0.0, sin(angle)) * randf_range(1.0, WANDER_RADIUS)
	_set_action(action)
	_last_result = {
		"action": action,
		"visible": visible,
		"distance": distance,
		"goal": goal,
		"alert": _alert,
	}
	return _last_result.duplicate(true)


func take_damage(amount: float, point: Vector3 = Vector3.ZERO, source: Node = null, zone: String = "") -> void:
	if _dead or amount <= 0.0:
		return
	var z: String = zone.to_lower()
	if z == "":
		leg_left_damage += amount * 0.5
		leg_right_damage += amount * 0.5
	elif z.contains("leg") and (z.contains("left") or z.ends_with("_l")):
		leg_left_damage += amount
	elif z.contains("leg") and (z.contains("right") or z.ends_with("_r")):
		leg_right_damage += amount
	health = maxf(0.0, health - amount)
	_alert = 1.0
	if point.length_squared() > 0.0001:
		_last_seen = point
	elif source is Node3D:
		_last_seen = (source as Node3D).global_position
	_flee_from = point if point.length_squared() > 0.0001 else ((source as Node3D).global_position if source is Node3D else global_position + Vector3.BACK)
	_flee_time = 0.0 if armed else FLEE_DURATION
	damaged.emit(amount, health)
	if health > 0.0:
		_react_hit(point, source)
	if health <= 0.0:
		_dead = true
		velocity = Vector3.ZERO
		collision_layer = 0
		set_physics_process(false)
		_react_death()
		_set_action(ACTION_DEAD)
		# Charco bajo el cuerpo al morir (shortcut: altura de piso fija de la casa, 0.53 m).
		GoreSystem.create_puddle(get_parent(), Vector3(global_position.x, 0.53, global_position.z), Vector3.UP, 0.4)
		died.emit(source)
		if armed:
			LootDrop.spawn.call_deferred(self)


func is_dead() -> bool:
	return _dead


func health_ratio() -> float:
	return clampf(health / maxf(max_health, 0.01), 0.0, 1.0)


func current_action() -> String:
	return _action


func snapshot() -> Dictionary:
	return {
		"npc_id": npc_id,
		"role": role,
		"action": _action,
		"visible": bool(_last_result.get("visible", false)),
		"distance": float(_last_result.get("distance", -1.0)),
		"health": health,
		"dead": _dead,
		"target_id": _source_id,
	}


func _physics_process(delta: float) -> void:
	if not auto_tick or _dead:
		return
	tick(delta)
	_move(maxf(delta, 0.0))


func _attach_gun() -> void:
	if not armed or _gun != null:
		return
	var scene = load(GUN_MODEL)
	if not scene is PackedScene:
		return
	_gun = (scene as PackedScene).instantiate() as Node3D
	_gun.name = "Gun"
	# glb barrel is +X; rotate so it points along the NPC forward (-Z), held at chest height on the right.
	_gun.transform = Transform3D(Basis(Vector3.UP, PI * 0.5), Vector3(0.25, 1.25, -0.25))
	add_child(_gun)
	_gun_sound = AudioStreamPlayer3D.new()
	_gun_sound.name = "GunSound"
	_gun_sound.stream = load(GUN_SOUND)
	_gun_sound.max_polyphony = 4
	_gun.add_child(_gun_sound)


func _eye_position() -> Vector3:
	return global_position + Vector3(0.0, EYE_HEIGHT, 0.0)


## Clear if nothing blocks the ray, or what blocks it is (an ancestor of) the target or sits right at the point.
func _has_line_of_sight(point: Vector3) -> bool:
	if not is_inside_tree():
		return true
	var query := PhysicsRayQueryParameters3D.create(_eye_position(), point)
	query.exclude = [get_rid()]
	var hit: Dictionary = get_world_3d().direct_space_state.intersect_ray(query)
	if hit.is_empty():
		return true
	var collider: Object = hit.get("collider")
	if target != null and is_instance_valid(target) and collider is Node \
			and (collider == target or (collider as Node).is_ancestor_of(target)):
		return true
	return (hit["position"] as Vector3).distance_to(point) < 0.5


func _shoot(point: Vector3) -> Dictionary:
	var shot := Sfx.file(SHOT_SOUND_PATH)
	if shot != null:
		Sfx.play_at(self, shot, global_position)
	_face_target()
	var aim: Vector3 = point + Vector3(randf_range(-1, 1), randf_range(-1, 1), randf_range(-1, 1)) * SHOT_SPREAD
	var result: Dictionary = {"from": _eye_position(), "to": aim, "collider": null}
	if is_inside_tree():
		var from: Vector3 = _eye_position()
		var query := PhysicsRayQueryParameters3D.create(from, from + (aim - from).normalized() * (ARMED_RANGE + 2.0))
		query.exclude = [get_rid()]
		var hit: Dictionary = get_world_3d().direct_space_state.intersect_ray(query)
		if not hit.is_empty():
			result["collider"] = hit["collider"]
			result["position"] = hit["position"]
			BulletImpact.apply(hit["collider"], hit["position"], hit["normal"], SHOT_DAMAGE * GameConfig.npc_damage_scale(), self)
		if _gun_sound != null and _gun_sound.is_inside_tree():
			_gun_sound.play()
		if _gun != null and get_tree().current_scene != null:
			ShotFx.fire(_gun)
	if not _play("Gun_Shoot"):
		_play("Idle_Gun_Shoot")
	shot_fired.emit(result)
	return result


func _effective_target_position() -> Vector3:
	if has_explicit_aim:
		return aim_point
	if target != null and is_instance_valid(target):
		return target.global_position
	return Vector3.ZERO


func _patrol_action() -> String:
	if patrol_points.is_empty():
		goal = _home
		return ACTION_IDLE
	if not _patrol_ready or global_position.distance_to(goal) < ARRIVE_DISTANCE:
		_patrol_ready = true
		_patrol_index = (_patrol_index + 1) % patrol_points.size()
	goal = _as_vector(patrol_points[_patrol_index])
	return ACTION_PATROL


func _set_action(action: String) -> void:
	if _action == action:
		return
	_action = action
	action_changed.emit(action)


func _move(delta: float) -> void:
	var offset: Vector3 = goal - global_position
	offset.y = 0.0
	var remaining: float = offset.length()
	var mob: Dictionary = NpcMobility.mobility_for(leg_left_damage, leg_right_damage)
	var speed: float = patrol_speed
	if _action == ACTION_FLEE:
		speed = run_speed
	elif _action == ACTION_INVESTIGATE:
		speed = maxf(patrol_speed, run_speed * 0.5)
	speed *= float(mob["speed_factor"])
	if mob["state"] == "crawl":
		var away: Vector3 = global_position - _flee_from if _flee_time > 0.0 else goal - global_position
		away.y = 0.0
		if away.length_squared() > 0.0001:
			away = away.normalized()
		velocity.x = away.x * NpcMobility.CRAWL_SPEED
		velocity.z = away.z * NpcMobility.CRAWL_SPEED
		if not _play("Crawl", true):
			_play("Idle", true)
	elif remaining > ARRIVE_DISTANCE:
		var direction: Vector3 = offset / remaining
		velocity.x = direction.x * speed
		velocity.z = direction.z * speed
		if mob["state"] == "limp":
			_play("Walk", true)
		rotation.y = lerp_angle(rotation.y, atan2(-direction.x, -direction.z), clampf(delta * 8.0, 0.0, 1.0))
	else:
		velocity.x = 0.0
		velocity.z = 0.0
		if target != null and is_instance_valid(target) and not _dead:
			_face_target()
	if not is_on_floor():
		velocity.y -= 18.0 * delta
	else:
		velocity.y = 0.0
	move_and_slide()


func _face_target() -> void:
	if target == null or not is_instance_valid(target):
		return
	var direction: Vector3 = target.global_position - global_position
	direction.y = 0.0
	if direction.length_squared() > 0.0001:
		rotation.y = atan2(-direction.x, -direction.z)


func _role_color() -> Color:
	match role:
		ROLE_CIVILIAN:
			return Color(0.24, 0.48, 0.78)
		ROLE_DEFENDER:
			return Color(0.22, 0.62, 0.36)
		ROLE_ZOMBIE:
			return Color(0.45, 0.58, 0.25)
		_:
			return Color(0.72, 0.24, 0.18)


func _as_vector(value: Variant) -> Vector3:
	if value is Vector3:
		return value as Vector3
	if value is Vector2:
		var vector: Vector2 = value
		return Vector3(vector.x, 0.0, vector.y)
	if value is Array:
		var items: Array = value
		if items.size() >= 3:
			return Vector3(float(items[0]), float(items[1]), float(items[2]))
	return Vector3.ZERO
