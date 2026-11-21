class_name VrWeaponHand
extends Node3D

signal weapon_taken(weapon_id: String, hand: String)
signal weapon_stowed(weapon_id: String, hand: String)
signal fired(result: Dictionary)
signal reloaded(weapon_id: String)
signal two_hand_entered(weapon_id: String)
signal two_hand_exited(weapon_id: String)
signal haptic(hand: String, duration: float, frequency: float, amplitude: float)

const GrabScript = preload("res://weapons/vr_grab.gd")

const HOLSTER_GRAB_SCALE: float = 1.6
const SLOT_PRIORITY: Array = ["pistol", "assault_rifle", "shotgun", "sniper_rifle", "submachine_gun", "bat"]
const PROP_GRAB_RADIUS: float = 0.25
const HANDGUARD_RADIUS: float = 0.12
const HANDGUARD_OFFSETS: Dictionary = {
	"pistol": 0.08,
	"submachine_gun": 0.16,
	"assault_rifle": 0.24,
	"shotgun": 0.20,
	"sniper_rifle": 0.32,
	"bat": 0.18,
}
const RECOIL_REDUCTIONS: Dictionary = {
	"pistol": 0.25,
	"submachine_gun": 0.35,
	"assault_rifle": 0.65,
	"shotgun": 0.50,
	"sniper_rifle": 0.75,
	"bat": 0.10,
}

@export var hand: String = "right"
@export var muzzle_offset: Vector3 = Vector3(0.0, -0.04, -0.18)
@export var grip_offset: Vector3 = Vector3.ZERO
@export var max_aim_turn_degrees: float = 18.0
@export var aim_smoothing: float = 0.35
@export var base_recoil: float = 0.06
@export var base_shake: float = 0.004
@export var auto_process: bool = true
@export var use_physical_grab: bool = false
@export var fx_via_viewmodel: bool = true
@export var manual_gesture_reload: bool = false

var grab_system = null
var holsters = null
var reload_gestures = null
var reload_system = null
var recoil = null
var shot_trace: Array = []
var _rl_armed: bool = false
var _rl_prev_grip: bool = false
var _rl_ref: float = 0.0
var _rl_back: bool = false
var manual_reload_active: bool = false

var bag = null
var weapon_system: Node = null
var input_provider = null
var weapon_id: String = ""
var handguard_offsets: Dictionary = {}
var recoil_overrides: Dictionary = {}
var exclude: Array = []

var holder: Node3D = null
var viewmodel = null
var last_haptic: Dictionary = {}
var last_shot: Dictionary = {}

static var _last_fx_frame: int = -1

var _aim_dir: Vector3 = Vector3.FORWARD
var _two_hand: bool = false
var _was_grip: bool = false
var _hand_velocity: Vector3 = Vector3.ZERO
var _last_hand_origin: Vector3 = Vector3.ZERO
var _was_trigger: bool = false
var _recoil: float = 0.0
var _time: float = 0.0


var auto_equip: bool = false
var _auto_done: bool = false


var _alt_drawn: bool = false
var _alt_draw_time: float = -10.0


func _ready() -> void:
	if use_physical_grab:
		configure_handling()
	if not weapon_id.is_empty():
		_build_visual(weapon_id)


func _process(delta: float) -> void:
	if auto_process:
		step(delta)


func reset_buttons() -> void:
	_was_grip = false
	_was_trigger = false


func other_hand() -> String:
	return "left" if hand == "right" else "right"


func is_two_hand_aiming() -> bool:
	return _two_hand


func aim_dir() -> Vector3:
	return _aim_dir.normalized()


func current_recoil() -> float:
	return effective_recoil(weapon_id, _two_hand, base_recoil, recoil_overrides)


func current_shake() -> float:
	return shake_amplitude(weapon_id, _two_hand, base_shake, recoil_overrides)


func bind_weapon_system(node: Node) -> void:
	weapon_system = node
	if node != null and node.has_signal("impact") and not node.is_connected("impact", Callable(self, "on_impact")):
		node.connect("impact", Callable(self, "on_impact"))
	if node != null and node.has_signal("cycled") and not node.is_connected("cycled", Callable(self, "_on_cycled")):
		node.connect("cycled", Callable(self, "_on_cycled"))
	if node != null and node.has_signal("ammo_changed") and not node.is_connected("ammo_changed", Callable(self, "_on_ammo_changed")):
		node.connect("ammo_changed", Callable(self, "_on_ammo_changed"))


func configure_handling(head_pose: Transform3D = Transform3D.IDENTITY) -> void:
	if grab_system == null:
		grab_system = GrabScript.new()
		grab_system.set_hand(hand)


func hand_pose_values(grip_value: float = 1.0, trigger_value: float = 0.0, zone: String = "grip") -> Dictionary:
	return {"grip": grip_value, "trigger": trigger_value, "zone": zone}


func grab_weapon_from_pose(weapon_pose: Transform3D, grip_value: float = 1.0, zone: String = "") -> bool:
	if grab_system == null:
		configure_handling()
	if weapon_id.is_empty():
		return false
	return grab_system.grab(_pose(hand), weapon_pose, weapon_id, grip_value, zone)


func grab_world_prop(prop: Node3D, radius: float = GrabScript.GRAB_RADIUS) -> bool:
	if grab_system == null:
		configure_handling()
	return grab_system.grab_prop(prop, _pose(hand), radius)


func throw_world_prop(velocity: Vector3 = Vector3.ZERO) -> Dictionary:
	if grab_system == null:
		return {"released": false, "velocity": Vector3.ZERO}
	return grab_system.release_prop(velocity)


func release_weapon(velocity: Vector3 = Vector3.ZERO) -> Dictionary:
	if grab_system == null or not grab_system.is_grabbing():
		return {"mode": "", "velocity": Vector3.ZERO}
	var mode := "fall"
	return grab_system.release(mode, velocity)


func begin_manual_reload(capacity: int, reserve: int, loaded: int = -1, shells: int = 2) -> bool:
	if weapon_id.is_empty():
		return false
	manual_reload_active = true
	return true


func bind_reload_system(system) -> void:
	reload_system = system
	system.hand = hand
	reload_gestures = system
	manual_reload_active = true


func _on_cycled(id: String) -> void:
	if id == weapon_id:
		pulse(other_hand(), 0.06, 0.6, 0.6)


func _on_ammo_changed(id: String, loaded: int, reserve: int) -> void:
	if id == weapon_id and viewmodel != null and is_instance_valid(viewmodel) and viewmodel.has_method("update_ammo"):
		viewmodel.call("update_ammo", loaded, reserve)


func _ensure_reload_system() -> bool:
	if reload_system != null:
		return true
	if weapon_system == null or not weapon_system.has_method("set_manual_lock"):
		return false
	return false


func _on_magazine_dropped(_rounds: int, position: Vector3) -> void:
	pass


func _drive_reload(primary: Transform3D, secondary: Transform3D, other_grip: bool, delta: float) -> void:
	pass


func _drive_cycle(primary: Transform3D, secondary: Transform3D, other_grip: bool) -> void:
	pass


func _on_reload_haptic(target_hand: String, duration: float, amplitude: float) -> void:
	pulse(target_hand, duration, 0.6, amplitude)


func cancel_manual_reload(reason: String = "cambio_de_arma") -> void:
	manual_reload_active = false
	if reload_gestures != null:
		reload_gestures.cancel(reason)


func reload_phase() -> String:
	return ""


func reload_can_fire() -> bool:
	return false


func reload_events() -> Array:
	return []


func reload_eject_magazine(position: Vector3 = Vector3.ZERO) -> Dictionary:
	return {"ejected": false}


func reload_insert_magazine(pose: Transform3D, well: Transform3D) -> bool:
	return false


func reload_rack_slide(pull: float, released: bool) -> bool:
	return false


func reload_pump(travel: float) -> bool:
	return false


func reload_open_bolt() -> bool:
	return false


func reload_load_round() -> bool:
	return false


func reload_close_bolt() -> bool:
	return false


func _alt_draw_pressed(hand_name: String) -> bool:
	if _button("trigger", hand_name):
		return true
	var provider = _provider()
	if provider == null or not provider.has_method("is_button_pressed"):
		return false
	for action in ["a", "b", "x", "y", "thumbstick_click", "grip_click"]:
		if bool(provider.call("is_button_pressed", hand_name, action)):
			return true
	return false


func step(delta: float) -> void:
	_time += maxf(delta, 0.0)
	var primary := _pose(hand)
	var secondary := _pose(other_hand())
	var grip_value: float = _provider().get_grip_value(hand) if _provider().has_method("get_grip_value") else (1.0 if _button("grip", hand) else 0.0)
	var other_grip_value: float = _provider().get_grip_value(other_hand()) if _provider().has_method("get_grip_value") else (1.0 if _button("grip", other_hand()) else 0.0)
	var grip: bool = grip_value > 0.5
	var other_grip: bool = other_grip_value > 0.5
	var alt: bool = weapon_id.is_empty() and _alt_draw_pressed(hand)
	var want: bool = grip or alt

	if want and not _was_grip:
		if weapon_id.is_empty():
			if _in_bag_zone(primary):
				try_take()
			elif not try_take_from_holster(primary):
				_grab_nearby_prop(primary)
		if alt and not weapon_id.is_empty():
			_alt_drawn = true
			_alt_draw_time = _time
	elif not want and _was_grip:
		if not _alt_drawn and not weapon_id.is_empty() and _in_bag_zone(primary):
			stow()
		_release_prop(primary)
		_alt_drawn = false
	_was_grip = want
	_carry_prop(primary, delta)
	if auto_equip and not _auto_done and weapon_id.is_empty() and bag != null and not (bag.items() as Array).is_empty():
		_auto_done = true
		var ids: Array = bag.items()
		try_take("pistol" if ids.has("pistol") else str(ids[0]), true)

	var secondary_free: bool = bag == null or bag.held_in(other_hand()).is_empty()
	var in_zone: bool = false
	if not weapon_id.is_empty() and other_grip and secondary_free:
		in_zone = is_in_handguard_zone(primary, secondary, weapon_id, handguard_offsets)
	if in_zone != _two_hand:
		_two_hand = in_zone
		if in_zone:
			two_hand_entered.emit(weapon_id)
		else:
			two_hand_exited.emit(weapon_id)
	if reload_system != null and reload_system.active:
		_drive_reload(primary, secondary, other_grip, delta)
	elif not weapon_id.is_empty() and weapon_system != null and weapon_system.has_method("needs_cycle") \
			and bool(weapon_system.call("needs_cycle", weapon_id)) and secondary_free:
		_drive_cycle(primary, secondary, other_grip)
	if not weapon_id.is_empty() and other_grip and secondary_free \
			and is_reload_gesture(primary, secondary, weapon_id):
		try_reload()

	var target := aim_direction(primary, secondary, _two_hand)
	_aim_dir = limit_turn(_aim_dir, target, max_aim_turn_degrees, aim_smoothing)

	var trigger := _button("trigger", hand) and (_time - _alt_draw_time) > 0.4
	if trigger and (not _was_trigger or _auto_ready()):
		try_fire(_space())
	elif not trigger and _was_trigger:
		if recoil != null and recoil.has_method("end_burst"):
			recoil.end_burst()
	_recoil = maxf(_recoil - delta * 5.0, 0.0)
	_update_visual(primary, delta, grip_value)


func try_take(item_id: String = "", force: bool = false) -> bool:
	if not weapon_id.is_empty() or bag == null:
		return false
	var pose := _pose(hand)
	if not bag.is_open():
		bag.open(bag.bag_center() if force else pose.origin)
	var ids: Array = bag.items()
	if ids.is_empty():
		return false
	if item_id.is_empty():
		var taken: bool = false
		for candidate in ids:
			if bag.take(str(candidate), hand):
				taken = true
				break
		if not taken:
			return false
	elif not bag.take(item_id, hand):
		return false
	weapon_id = bag.held_in(hand)
	_aim_dir = aim_direction(pose, Transform3D.IDENTITY, false)
	_two_hand = false
	_build_visual(weapon_id)
	if use_physical_grab:
		configure_handling()
		var grip_val: float = _provider().get_grip_value(hand) if _provider().has_method("get_grip_value") else 1.0
		grab_weapon_from_pose(Transform3D(_aim_basis(pose), pose.origin), grip_val, "grip")
	weapon_taken.emit(weapon_id, hand)
	return true


func try_take_from_holster(pose: Transform3D) -> bool:
	return false


func _grab_nearby_prop(pose: Transform3D) -> bool:
	if not is_inside_tree():
		return false
	var best_prop: Node3D = null
	var best_prop_distance: float = PROP_GRAB_RADIUS
	for node in get_tree().get_nodes_in_group("physics_props"):
		if node is Node3D and is_instance_valid(node):
			var distance: float = (node as Node3D).global_position.distance_to(pose.origin)
			if distance < best_prop_distance:
				best_prop_distance = distance
				best_prop = node as Node3D
	var best_weapon: Node3D = null
	var best_weapon_distance: float = PROP_GRAB_RADIUS
	for node in get_tree().get_nodes_in_group("weapon_pickup"):
		if node is Node3D and is_instance_valid(node):
			var distance: float = (node as Node3D).global_position.distance_to(pose.origin)
			if distance < best_weapon_distance:
				best_weapon_distance = distance
				best_weapon = node as Node3D
	if best_weapon != null and best_weapon_distance <= best_prop_distance:
		return _equip_weapon_from_pickup(best_weapon)
	if best_prop == null:
		return false
	_last_hand_origin = pose.origin
	_hand_velocity = Vector3.ZERO
	return grab_world_prop(best_prop, PROP_GRAB_RADIUS)


func _equip_weapon_from_pickup(pickup: Node3D) -> bool:
	if not pickup.has_meta("weapon_id"):
		return false
	var id: String = str(pickup.get_meta("weapon_id"))
	if id.is_empty():
		return false
	if not weapon_id.is_empty():
		return false
	weapon_id = id
	_build_visual(weapon_id)
	if use_physical_grab and grab_system != null:
		var grip_val: float = _provider().get_grip_value(hand) if _provider().has_method("get_grip_value") else 1.0
		grab_weapon_from_pose(Transform3D(_aim_basis(_pose(hand)), _pose(hand).origin), grip_val, "grip")
	pickup.free()
	weapon_taken.emit(weapon_id, hand)
	return true


func _carry_prop(primary: Transform3D, delta: float) -> void:
	if grab_system == null:
		return
	var prop: Node3D = grab_system.held_prop()
	if prop == null or not is_instance_valid(prop):
		return
	var target: Vector3 = primary.origin
	_hand_velocity = (target - _last_hand_origin) / maxf(delta, 0.0001) if delta > 0.0 else _hand_velocity
	prop.global_position = target
	_last_hand_origin = target


func _release_prop(primary: Transform3D) -> void:
	if grab_system == null or grab_system.held_prop() == null:
		return
	grab_system.release_prop(GrabScript.safe_vector(_hand_velocity).limit_length(GrabScript.MAX_THROW_SPEED))


func stow() -> void:
	if weapon_id.is_empty():
		return
	if manual_reload_active:
		cancel_manual_reload("arma_guardada")
	if grab_system != null and grab_system.is_grabbing():
		release_weapon(Vector3.ZERO)
	var stowed_id := weapon_id
	if bag != null:
		bag.stow(hand)
	weapon_id = ""
	_two_hand = false
	_clear_visual()
	weapon_stowed.emit(stowed_id, hand)


func _auto_ready() -> bool:
	if weapon_id.is_empty() or weapon_system == null or not weapon_system.has_method("fire_block_reason"):
		return false
	return false


func _trace(step_name: String) -> void:
	shot_trace.append({"step": step_name, "frame": Engine.get_process_frames()})


func try_fire(space = null) -> Dictionary:
	shot_trace = []
	if weapon_id.is_empty():
		last_shot = {"fired": false, "reason": "empty_hand"}
		return last_shot
	if manual_reload_active and not reload_can_fire():
		last_shot = {"fired": false, "reason": "arma_no_montada"}
		return last_shot
	if weapon_system == null or not weapon_system.has_method("fire"):
		last_shot = {"fired": false, "reason": "no_weapon_system"}
		return last_shot
	var primary := _pose(hand)
	var base := _aim_dir.normalized()
	if base.length_squared() <= 0.000001:
		base = aim_direction(primary, Transform3D.IDENTITY, false)
	var origin := _muzzle_origin(primary)
	var direction := _aim_dir.normalized()
	var blocked := ""
	if weapon_system.has_method("fire_block_reason"):
		blocked = str(weapon_system.call("fire_block_reason", weapon_id))
	_trace("ammo")
	if not blocked.is_empty():
		var refused = weapon_system.call("fire", weapon_id, origin, direction, space, exclude.duplicate())
		last_shot = refused if refused is Dictionary else {"fired": false, "reason": blocked}
		return last_shot
	if recoil != null and recoil.has_method("aim_direction"):
		direction = recoil.aim_direction(direction)
	if recoil != null and recoil.has_method("on_fired"):
		recoil.primary_hand = hand
		recoil.secondary_hand = other_hand()
		var shot: Dictionary = recoil.on_fired(weapon_id, _two_hand)
		_recoil = current_recoil()
	_trace("recoil")
	if recoil != null and recoil.has_method("haptic_events"):
		for event in recoil.haptic_events():
			pulse(str(event["hand"]), float(event["duration"]), 0.75, float(event["amplitude"]))
	_trace("haptic")
	var host: Node = get_parent() if get_parent() != null else self
	_play_shot_sound(origin)
	_trace("sound")
	var result = weapon_system.call("fire", weapon_id, origin, direction, space, exclude.duplicate())
	_trace("fire")
	last_shot = result if result is Dictionary else {"fired": false, "reason": "respuesta_invalida"}
	last_shot["direction"] = direction
	last_shot["recoil"] = {}
	last_shot["camera_shake"] = 0.0
	if bool(last_shot.get("fired", false)):
		if manual_reload_active and reload_gestures != null:
			reload_gestures.fire()
		fired.emit(last_shot)
	return last_shot


func _play_shot_sound(origin: Vector3) -> void:
	pass


func try_reload() -> bool:
	if weapon_id.is_empty() or weapon_system == null or not weapon_system.has_method("reload"):
		return false
	var ok := bool(weapon_system.call("reload", weapon_id))
	if ok:
		reloaded.emit(weapon_id)
	return ok


func on_impact(info: Dictionary) -> void:
	if weapon_id.is_empty() or str(info.get("weapon_id", "")) != weapon_id:
		return
	var mass: float = float(info.get("mass", 0.0))
	var impact_velocity: float = float(info.get("impact_velocity", 0.0))
	if mass > 0.0 and impact_velocity > 0.0:
		var haptic: Dictionary = impact_haptic(mass, impact_velocity)
		pulse(hand, float(haptic["duration"]), float(haptic["frequency"]), float(haptic["amplitude"]))
		return
	var strength: float = clampf(float(info.get("damage", 0.0)) / 50.0, 0.1, 1.0)
	pulse(hand, 0.08, 0.5, strength)


static func impact_haptic(mass: float, impact_velocity: float) -> Dictionary:
	var energy: float = 0.5 * maxf(mass, 0.0) * impact_velocity * impact_velocity
	var strength: float = clampf(energy / 10.0, 0.0, 1.0)
	var duration: float = lerpf(0.04, 0.16, strength)
	var frequency: float = lerpf(0.8, 0.3, strength)
	var amplitude: float = lerpf(0.2, 1.0, strength)
	return {
		"duration": duration,
		"frequency": frequency,
		"amplitude": amplitude,
		"strength": strength,
		"energy": energy,
	}


func pulse(target_hand: String, duration: float = 0.05, frequency: float = 0.6, amplitude: float = 0.5) -> void:
	last_haptic = {
		"hand": target_hand,
		"duration": duration,
		"frequency": frequency,
		"amplitude": amplitude,
	}
	haptic.emit(target_hand, duration, frequency, amplitude)
	var controller = null
	var provider = _provider()
	if provider != null and provider.has_method("controller_for"):
		controller = provider.call("controller_for", target_hand)
	if controller != null and controller.has_method("trigger_haptic"):
		controller.call("trigger_haptic", duration, frequency, amplitude)


func _provider():
	return input_provider if input_provider != null else self


func _pose(hand_name: String) -> Transform3D:
	var provider = _provider()
	if provider != null and provider.has_method("get_pose"):
		var value = provider.call("get_pose", hand_name)
		if value is Transform3D:
			return value
	return Transform3D.IDENTITY


func _button(action: String, hand_name: String) -> bool:
	var provider = _provider()
	if provider == null:
		return false
	var method := "is_grip_pressed" if action == "grip" else "is_trigger_pressed"
	if provider.has_method(method):
		return bool(provider.call(method, hand_name))
	if provider.has_method("is_pressed"):
		return bool(provider.call("is_pressed", action))
	return false


func _in_bag_zone(pose: Transform3D) -> bool:
	return bag != null and bag.is_in_bag_zone(pose.origin)


func _space() -> PhysicsDirectSpaceState3D:
	var world := get_world_3d()
	return world.direct_space_state if world != null else null


func _aim_basis(primary: Transform3D) -> Basis:
	var direction := _aim_dir.normalized()
	if direction.length_squared() <= 0.000001:
		direction = Vector3.FORWARD
	var up: Vector3 = primary.basis.y
	if up.length_squared() <= 0.000001:
		up = Vector3.UP
	var z_axis := -direction
	var x_axis := up.cross(z_axis)
	if x_axis.length_squared() <= 0.000001:
		x_axis = Vector3.RIGHT
	x_axis = x_axis.normalized()
	var y_axis := z_axis.cross(x_axis).normalized()
	return Basis(x_axis, y_axis, z_axis)


func _muzzle_origin(primary: Transform3D) -> Vector3:
	var basis := _aim_basis(primary)
	return primary.origin + basis.x * muzzle_offset.x + basis.y * muzzle_offset.y + basis.z * muzzle_offset.z


func _update_visual(primary: Transform3D, delta: float = 0.0, grip_value: float = 1.0) -> void:
	if holder == null or weapon_id.is_empty():
		return
	var basis := _aim_basis(primary)
	var kick: Transform3D = Transform3D.IDENTITY
	if recoil != null and recoil.has_method("weapon_offset"):
		kick = recoil.weapon_offset()
	var aim_basis := basis
	var offset := grip_offset + aim_basis * kick.origin
	basis = aim_basis * kick.basis
	var shake: float = current_shake()
	offset += Vector3(sin(_time * 23.0), cos(_time * 19.0), 0.0) * shake
	if use_physical_grab and grab_system != null and grab_system.is_grabbing():
		var linked: Transform3D = grab_system.step(delta, primary, grip_value)
		holder.global_transform = Transform3D(linked.basis, linked.origin + aim_basis * kick.origin + Vector3(sin(_time * 23.0), cos(_time * 19.0), 0.0) * shake)
	else:
		holder.global_transform = Transform3D(basis, primary.origin + offset)
	if viewmodel != null and is_instance_valid(viewmodel) and viewmodel.has_method("advance"):
		viewmodel.call("advance", maxf(delta, 0.0))


func _build_visual(id: String) -> void:
	_clear_visual()
	if id.is_empty():
		return
	holder = Node3D.new()
	holder.name = "WeaponVisual"
	add_child(holder)
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(0.16, 0.18, 0.20)
	material.metallic = 0.3
	material.roughness = 0.65
	var body := MeshInstance3D.new()
	var box := BoxMesh.new()
	var is_long: bool = id in ["assault_rifle", "sniper_rifle", "shotgun", "submachine_gun", "bat"]
	var length: float = 0.44 if is_long else 0.24
	box.size = Vector3(0.05, 0.07, length)
	body.mesh = box
	body.material_override = material
	holder.add_child(body)
	if is_long:
		var barrel := MeshInstance3D.new()
		var cylinder := CylinderMesh.new()
		cylinder.top_radius = 0.012
		cylinder.bottom_radius = 0.012
		cylinder.height = 0.20
		barrel.mesh = cylinder
		barrel.rotation.x = PI * 0.5
		barrel.position.z = -length * 0.5 - 0.08
		barrel.material_override = material
		holder.add_child(barrel)


func _clear_visual() -> void:
	viewmodel = null
	if holder != null and is_instance_valid(holder) and not holder.is_queued_for_deletion():
		holder.queue_free()
	holder = null


static func aim_direction(primary: Transform3D, secondary: Transform3D, use_secondary: bool) -> Vector3:
	if use_secondary:
		var line := secondary.origin - primary.origin
		if line.length_squared() > 0.000001:
			return line.normalized()
	var forward := -primary.basis.z
	return forward.normalized() if forward.length_squared() > 0.000001 else Vector3.FORWARD


static func limit_turn(
	current: Vector3, target: Vector3, max_degrees: float, smoothing: float = 1.0
) -> Vector3:
	var from := current.normalized()
	var to := target.normalized()
	if from.length_squared() <= 0.000001:
		return to
	if to.length_squared() <= 0.000001:
		return from
	var angle: float = from.angle_to(to)
	if angle <= 0.000001:
		return to
	if max_degrees <= 0.0 or smoothing <= 0.0:
		return from
	var step: float = minf(rad_to_deg(angle) * clampf(smoothing, 0.0, 1.0), maxf(max_degrees, 0.0))
	var axis := from.cross(to)
	if axis.length_squared() <= 0.00000001:
		return to
	return from.rotated(axis.normalized(), deg_to_rad(step)).normalized()


static func handguard_offset(weapon_id: String, overrides: Dictionary = {}) -> float:
	if overrides.has(weapon_id):
		return clampf(float(overrides[weapon_id]), 0.02, 1.0)
	if HANDGUARD_OFFSETS.has(weapon_id):
		return float(HANDGUARD_OFFSETS[weapon_id])
	if _has_tag(weapon_id, "sniper"):
		return 0.32
	if _has_tag(weapon_id, "rifle"):
		return 0.24
	if _has_tag(weapon_id, "shotgun"):
		return 0.20
	if _has_tag(weapon_id, "smg"):
		return 0.16
	if _has_tag(weapon_id, "sidearm"):
		return 0.08
	return 0.12


static func handguard_center(primary: Transform3D, weapon_id: String, overrides: Dictionary = {}) -> Vector3:
	var forward := -primary.basis.z
	if forward.length_squared() <= 0.000001:
		forward = Vector3.FORWARD
	return primary.origin + forward.normalized() * handguard_offset(weapon_id, overrides)


static func is_in_handguard_zone(
	primary: Transform3D, secondary: Transform3D, weapon_id: String,
	overrides: Dictionary = {}, radius: float = HANDGUARD_RADIUS
) -> bool:
	if weapon_id.is_empty():
		return false
	return secondary.origin.distance_to(handguard_center(primary, weapon_id, overrides)) <= maxf(radius, 0.01)


static func is_reload_gesture(
	primary: Transform3D, secondary: Transform3D, weapon_id: String,
	radius: float = HANDGUARD_RADIUS
) -> bool:
	if weapon_id.is_empty():
		return false
	var forward := -primary.basis.z
	if forward.length_squared() <= 0.000001:
		forward = Vector3.FORWARD
	var center := primary.origin - Vector3.UP * 0.16 + forward.normalized() * 0.04
	return secondary.origin.distance_to(center) <= maxf(radius, 0.01)


static func recoil_reduction(weapon_id: String, overrides: Dictionary = {}) -> float:
	if overrides.has(weapon_id):
		return clampf(float(overrides[weapon_id]), 0.0, 0.95)
	if RECOIL_REDUCTIONS.has(weapon_id):
		return float(RECOIL_REDUCTIONS[weapon_id])
	if _has_tag(weapon_id, "sniper"):
		return 0.75
	if _has_tag(weapon_id, "rifle"):
		return 0.65
	if _has_tag(weapon_id, "shotgun"):
		return 0.50
	if _has_tag(weapon_id, "smg"):
		return 0.35
	return 0.25


static func effective_recoil(
	weapon_id: String, two_handed: bool, base: float, overrides: Dictionary = {}
) -> float:
	var factor: float = 1.0 - recoil_reduction(weapon_id, overrides) if two_handed else 1.0
	return maxf(base, 0.0) * factor


static func shake_amplitude(
	weapon_id: String, two_handed: bool, base: float, overrides: Dictionary = {}
) -> float:
	var factor: float = 1.0 - recoil_reduction(weapon_id, overrides) * 0.8 if two_handed else 1.0
	return maxf(base, 0.0) * factor


static func _has_tag(weapon_id: String, tag: String) -> bool:
	var tags: Array = []
	if weapon_id == "pistol":
		tags = ["sidearm"]
	elif weapon_id in ["assault_rifle", "submachine_gun"]:
		tags = ["rifle", "smg"]
	elif weapon_id == "sniper_rifle":
		tags = ["sniper", "rifle"]
	elif weapon_id == "shotgun":
		tags = ["shotgun"]
	elif weapon_id == "bat":
		tags = ["melee"]
	return tags.has(tag)