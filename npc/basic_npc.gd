class_name BasicNpc
extends CharacterBody3D

signal action_changed(action: String)
signal target_changed(source_id: String, visible: bool)
signal damaged(amount: float, health: float)
signal died(source: Node)

const ACTION_IDLE: String = "idle"
const ACTION_PATROL: String = "patrol"
const ACTION_CHASE: String = "chase"
const ACTION_INVESTIGATE: String = "investigate"
const ACTION_FLEE: String = "flee"
const ACTION_DEAD: String = "dead"

const ROLE_HOSTILE: String = "hostile"
const ROLE_CIVILIAN: String = "civilian"
const ROLE_DEFENDER: String = "defender"
const ROLE_ZOMBIE: String = "zombie"

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

var target: Node3D = null
var aim_point: Vector3 = Vector3.ZERO
var has_explicit_aim: bool = false
var patrol_points: Array = []
var health: float = DEFAULT_MAX_HEALTH
var goal: Vector3 = Vector3.ZERO

var collision: CollisionShape3D = null
var visual: MeshInstance3D = null
var head_visual: MeshInstance3D = null

var _material: StandardMaterial3D = null
var _home: Vector3 = Vector3.ZERO
var _last_seen: Vector3 = Vector3.ZERO
var _action: String = ACTION_IDLE
var _alert: float = 0.0
var _dead: bool = false
var _built: bool = false
var _patrol_index: int = -1
var _patrol_ready: bool = false
var _last_result: Dictionary = {}
var _source_id: String = ""


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
	var action: String = ACTION_IDLE
	if visible:
		if role == ROLE_CIVILIAN and distance < flee_distance:
			action = ACTION_FLEE
			var away: Vector3 = global_position - target_pos
			away.y = 0.0
			var escape: Vector3 = away.normalized() if away.length_squared() > 0.0001 else Vector3.FORWARD
			goal = global_position + escape * flee_distance
		else:
			action = ACTION_CHASE
			var to_target: Vector3 = target_pos - global_position
			to_target.y = 0.0
			if to_target.length() > stop_distance:
				goal = target_pos - to_target.normalized() * stop_distance
			else:
				goal = global_position
	elif _alert > 0.0 and _last_seen.length_squared() > 0.0001:
		action = ACTION_INVESTIGATE
		goal = _last_seen
	else:
		action = _patrol_action()
	_set_action(action)
	_last_result = {
		"action": action,
		"visible": visible,
		"distance": distance,
		"goal": goal,
		"alert": _alert,
	}
	return _last_result.duplicate(true)


func take_damage(amount: float, point: Vector3 = Vector3.ZERO, source: Node = null) -> void:
	if _dead or amount <= 0.0:
		return
	health = maxf(0.0, health - amount)
	_alert = 1.0
	if point.length_squared() > 0.0001:
		_last_seen = point
	elif source is Node3D:
		_last_seen = (source as Node3D).global_position
	damaged.emit(amount, health)
	if health <= 0.0:
		_dead = true
		velocity = Vector3.ZERO
		collision_layer = 0
		if visual != null:
			visual.visible = false
		if head_visual != null:
			head_visual.visible = false
		set_physics_process(false)
		_set_action(ACTION_DEAD)
		died.emit(source)


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
	var speed: float = patrol_speed
	if _action == ACTION_CHASE or _action == ACTION_FLEE:
		speed = run_speed
	elif _action == ACTION_INVESTIGATE:
		speed = maxf(patrol_speed, run_speed * 0.5)
	if remaining > ARRIVE_DISTANCE:
		var direction: Vector3 = offset / remaining
		velocity.x = direction.x * speed
		velocity.z = direction.z * speed
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
