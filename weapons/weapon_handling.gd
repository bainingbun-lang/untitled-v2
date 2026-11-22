## Off-hand manual handling: grip on the magazine ejects / inserts it, grip on the charging handle and pull back racks.
## Off hand comes from the sibling TwoHanded node. Grab-zone idea from godot-vr-weapons Object_pickable.gd (c) 2019 Bastiaan Olij, MIT.
class_name WeaponHandling
extends Node

const ZONE_NONE := ""
const ZONE_MAGAZINE := "magazine"
const ZONE_HANDLE := "handle"

@export var magazine_path: NodePath = NodePath("../Pivot/Magazine")
@export var handle_path: NodePath = NodePath("../Pivot/ChargingHandle")
@export var two_handed_path: NodePath = NodePath("../TwoHanded")
@export var grab_radius: float = 0.07
@export var rack_travel: float = 0.07

var _weapon: Node3D
var _was_pressed := false
var _racking := false
var _rack_start := Vector3.ZERO
var _racked := false


func _ready() -> void:
	_weapon = get_parent() as Node3D


## Nearest zone within radius, in weapon-local space.
static func zone_for(hand_local: Vector3, mag_local: Vector3, handle_local: Vector3, radius: float) -> String:
	var dm := hand_local.distance_to(mag_local)
	var dh := hand_local.distance_to(handle_local)
	if dh <= radius and dh <= dm:
		return ZONE_HANDLE
	if dm <= radius:
		return ZONE_MAGAZINE
	return ZONE_NONE


## 0..1: how far the hand pulled back (+Z, barrel is -Z) from where it grabbed the handle.
static func rack_progress(start_local: Vector3, now_local: Vector3, travel: float) -> float:
	return clampf((now_local.z - start_local.z) / maxf(travel, 0.001), 0.0, 1.0)


## Feed one frame of off-hand input; returns the action taken ("eject_magazine", "insert_magazine", "rack_slide" or "").
func step(hand_local: Vector3, pressed: bool) -> String:
	var result := ""
	if pressed and not _was_pressed:
		var mag := _local_of(magazine_path)
		var handle := _local_of(handle_path)
		match zone_for(hand_local, mag, handle, grab_radius):
			ZONE_MAGAZINE:
				# shortcut: a second grip on the empty well inserts a fresh magazine (no physical magazine object yet).
				if _weapon.call("eject_magazine"):
					result = "eject_magazine"
				elif _weapon.call("insert_magazine"):
					result = "insert_magazine"
			ZONE_HANDLE:
				_racking = true
				_racked = false
				_rack_start = hand_local
	elif pressed and _racking and not _racked:
		if rack_progress(_rack_start, hand_local, rack_travel) >= 1.0:
			_racked = true
			_weapon.call("rack_slide")
			result = "rack_slide"
	if not pressed:
		_racking = false
	_was_pressed = pressed
	return result


func _process(_delta: float) -> void:
	if _weapon == null or not _weapon.has_method("rack_slide"):
		return
	var th := get_node_or_null(two_handed_path)
	var hand: XRController3D = th.get("off_hand") if th else null
	if hand == null:
		return
	var action: String = th.get("grip_action") if th else "grip_click"
	step(_weapon.global_transform.affine_inverse() * hand.global_position, hand.is_button_pressed(action))


func _local_of(path: NodePath) -> Vector3:
	var n := get_node_or_null(path) as Node3D
	if n == null:
		return Vector3(INF, INF, INF)
	return _weapon.global_transform.affine_inverse() * n.global_position
