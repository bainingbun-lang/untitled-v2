extends Node3D

## Extras de mano para el jugador xr-tools (se cuelga de cada XRController3D):
## puñetazo con la velocidad de la mano y agarre de NPC con "grip" (si la mano no sostiene nada).
## Misma API de daño que el jugador viejo (gore/npc_impact.gd).

const NpcImpact = preload("res://gore/npc_impact.gd")
const PUNCH_MIN_SPEED := 3.0
const PUNCH_COOLDOWN := 0.35
const SLAM_MIN_SPEED := 4.0
const GRIP_THRESHOLD := 0.6

## Velocidad de la mano en el mundo, sin la locomoción del jugador.
var velocity := Vector3.ZERO

var _controller: XRController3D
var _origin: XROrigin3D
var _zone: Area3D
var _prev_local := Vector3.ZERO
var _punch_last := {}
var _grabbed_npc: Node3D = null
var _grab_offset := Vector3.ZERO


func _ready() -> void:
	_controller = get_parent() as XRController3D
	_origin = _controller.get_parent() as XROrigin3D
	_zone = Area3D.new()
	_zone.collision_layer = 0
	_zone.collision_mask = 1
	var cs := CollisionShape3D.new()
	var sphere := SphereShape3D.new()
	sphere.radius = 0.1
	cs.shape = sphere
	_zone.add_child(cs)
	add_child(_zone)
	_prev_local = _controller.position


func _physics_process(delta: float) -> void:
	var local := _controller.position
	velocity = _origin.global_basis * ((local - _prev_local) / delta)
	_prev_local = local
	var picked: Variant = _held_object()
	if picked == null:
		_update_npc_grab()
		_check_punch()
	else:
		_grabbed_npc = null


func _held_object() -> Variant:
	var pk := _controller.find_child("FunctionPickup", true, false)
	if pk == null:
		return null
	var o: Variant = pk.get("picked_up_object")
	return o if is_instance_valid(o) else null


func _check_punch() -> void:
	var speed := velocity.length()
	if speed < PUNCH_MIN_SPEED:
		return
	var now := Time.get_ticks_msec() / 1000.0
	for body in _zone.get_overlapping_bodies():
		if not body.has_method("take_damage") or body == _grabbed_npc:
			continue
		if now - float(_punch_last.get(body, -10.0)) < PUNCH_COOLDOWN:
			continue
		_punch_last[body] = now
		var zone := "head" if global_position.y > (body as Node3D).global_position.y + 1.3 else "torso"
		NpcImpact.apply(body, global_position, -velocity.normalized(), speed, zone)


## Con grip sobre un NPC, la mano lo sostiene (y lo desarma). Si lo estrella contra algo
## sólido a más de SLAM_MIN_SPEED, recibe impacto en la cabeza y se suelta.
func _update_npc_grab() -> void:
	if _controller.get_float("grip") < GRIP_THRESHOLD:
		_grabbed_npc = null
		return
	if _grabbed_npc == null:
		for body in _zone.get_overlapping_bodies():
			if body.has_method("take_damage") and body is Node3D:
				_grabbed_npc = body
				_grab_offset = (body as Node3D).global_position - global_position
				if body.get("armed") == true:
					body.set("armed", false)
				break
		return
	if not is_instance_valid(_grabbed_npc):
		_grabbed_npc = null
		return
	_grabbed_npc.global_position = global_position + _grab_offset
	if _grabbed_npc is CharacterBody3D:
		(_grabbed_npc as CharacterBody3D).velocity = Vector3.ZERO
	var speed := velocity.length()
	if speed < SLAM_MIN_SPEED:
		return
	for body in _zone.get_overlapping_bodies():
		if body is StaticBody3D:
			NpcImpact.apply(_grabbed_npc, global_position, -velocity.normalized(), speed, "head")
			_grabbed_npc = null
			return
