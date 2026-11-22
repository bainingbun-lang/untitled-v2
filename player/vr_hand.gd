class_name VRHand extends RigidBody3D

const NpcImpact = preload("res://gore/npc_impact.gd")
const PUNCH_MIN_SPEED := 3.0
const PUNCH_COOLDOWN := 0.35


@export var controller: NodePath

var offset_rotation: Basis
var velocity := Vector3.ZERO

var _time_since_contact := 1.0

var _previous_position := Vector3.ZERO

@onready var _controller := get_node(controller) as VRController
@onready var _glove := $VRGlove as VRGlove
@onready var _positive_corner := (($Palm as CollisionShape3D).shape as BoxShape3D).size \
		* Vector3(0.5, -0.5, 0.5)


func _ready() -> void:
	assert(is_instance_valid(_controller), "Controller path was not set correctly for " + name)
	assert(is_instance_valid(_glove), name + " doesn't have a glove mesh")


func _physics_process(delta: float) -> void:
	velocity = (global_transform.origin - _previous_position) / delta
	_previous_position = global_transform.origin
	_check_punch()


func _integrate_forces(state: PhysicsDirectBodyState3D) -> void:
	if state.get_contact_count() == 0:
		_copy_rotation(state, _time_since_contact) # TODO this does not take delta into account correctly
		_time_since_contact += state.step
		if _time_since_contact >= 0.1:
			_glove.rest.call_deferred()
	else:
		for current_index in state.get_contact_count():
			var local_position := to_local(state.get_contact_local_position(current_index) \
					+ global_position)
			if _contact_is_on_lower_corner(local_position):
				_glove.flatten.call_deferred()
				break
		_time_since_contact = 0.0


func _copy_rotation(state: PhysicsDirectBodyState3D, weight: float) -> void:
	state.transform.basis = state.transform.basis.slerp(
		(_controller.global_transform.basis * offset_rotation).orthonormalized(),
		minf(weight, 1.0)
	)
	state.angular_velocity = Vector3.ZERO


func _contact_is_on_lower_corner(local_position: Vector3) -> bool:
	local_position.x = absf(local_position.x)
	local_position.z = absf(local_position.z)
	return local_position.is_equal_approx(_positive_corner)


## Golpe con la mano a un NPC: la velocidad de la mano decide el daño (ver gore/npc_impact.gd).
var _punch_last := {}


func _check_punch() -> void:
	var speed := velocity.length()
	if speed < PUNCH_MIN_SPEED:
		return
	var now := Time.get_ticks_msec() / 1000.0
	for body in get_colliding_bodies():
		if not body.has_method("take_damage"):
			continue
		if now - float(_punch_last.get(body, -10.0)) < PUNCH_COOLDOWN:
			continue
		_punch_last[body] = now
		var zone := "head" if global_position.y > (body as Node3D).global_position.y + 1.3 else "torso"
		NpcImpact.apply(body, global_position, -velocity.normalized(), speed, zone)
