## Two-handed foregrip component. Add as child of a weapon; set off_hand to the free XRController3D.
## Ported from godot-vr-weapons (c) 2019 Bastiaan Olij, MIT.
class_name TwoHanded
extends Node3D

@export var off_hand: XRController3D
@export var foregrip_path: NodePath = NodePath("Pivot/Foregrip")
@export var grab_radius: float = 0.12
@export var grip_action: String = "grip"

var engaged: bool = false
var _weapon: Node3D
var _foregrip: Node3D

func _ready() -> void:
	_weapon = get_parent() as Node3D
	_foregrip = _weapon.get_node_or_null(foregrip_path) as Node3D

func is_two_handed() -> bool:
	return engaged

## Multiplier for sway (VrGrab.steadiness): 1.0 one hand, lower when braced.
func steadiness() -> float:
	return VrGrab.steadiness(engaged, false)

func _process(_delta: float) -> void:
	if _weapon == null or off_hand == null or _foregrip == null:
		return
	var pressed: bool = off_hand.is_button_pressed(grip_action)
	var hand_pos: Vector3 = off_hand.global_position
	if not engaged:
		engaged = pressed and hand_pos.distance_to(_foregrip.global_position) <= grab_radius
		return
	if not pressed:
		engaged = false
		return
	## Point the barrel (-Z) from the weapon origin to the off hand, keeping the roll.
	var origin: Vector3 = _weapon.global_position
	if hand_pos.distance_squared_to(origin) < 0.0001:
		return
	var up: Vector3 = _weapon.global_transform.basis.y
	var dir: Vector3 = (hand_pos - origin).normalized()
	if absf(dir.dot(up)) > 0.99:
		return
	_weapon.global_transform = Transform3D(Basis.looking_at(dir, up), origin)
