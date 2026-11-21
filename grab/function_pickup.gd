# MIT License
#
# Copyright (c) 2018-2023 Bastiaan Olij and Contributors
#
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:
#
# The above copyright notice and this permission notice shall be included in all
# copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
# SOFTWARE.
#
# Adapted from GodotVR/godot-xr-tools:
#   addons/godot-xr-tools/functions/function_pickup.gd

@tool
class_name XRToolsFunctionPickup
extends Node3D

## Grip pickup adapted from godot-xr-tools. Reads the analogue grip value
## with `XRController3D.get_float("grip")` and uses the original hysteresis
## (threshold 0.5 +/- 0.1) to take and release a nearby XRToolsPickable.

signal has_picked_up(what: Node3D)
signal has_dropped

const DEFAULT_GRAB_MASK := 0b0000_0000_0000_0100_0000_0000_0000_0100
const GRIP_THRESHOLD := 0.5
const HYSTERESIS := 0.1
const MAX_THROW_SPEED := 12.0

@export var enabled := true
@export var pickup_axis_action := "grip"
@export_custom(PROPERTY_HINT_NONE, "suffix:m") var grab_distance := 0.3:
	set = _set_grab_distance
@export_flags_3d_physics var grab_collision_mask := DEFAULT_GRAB_MASK
@export var impulse_factor := 1.0

var closest_object: Node3D = null
var picked_up_object: XRToolsPickable = null
var grip_pressed := false

var _controller: XRController3D
var _object_in_grab_area: Array[Node3D] = []
var _grab_area: Area3D
var _grab_collision: CollisionShape3D
var _last_transform := Transform3D.IDENTITY
var _linear_velocity := Vector3.ZERO
var _angular_velocity := Vector3.ZERO


func set_controller(controller: XRController3D) -> void:
	_controller = controller
	if is_inside_tree():
		_last_transform = global_transform


func get_controller() -> XRController3D:
	return _controller


func _ready() -> void:
	if _controller == null and get_parent() is XRController3D:
		_controller = get_parent()
	_last_transform = global_transform
	if Engine.is_editor_hint():
		return

	_grab_collision = CollisionShape3D.new()
	_grab_collision.name = "GrabCollisionShape"
	var shape := SphereShape3D.new()
	shape.radius = grab_distance
	_grab_collision.shape = shape

	_grab_area = Area3D.new()
	_grab_area.name = "GrabArea"
	_grab_area.collision_layer = 0
	_grab_area.collision_mask = grab_collision_mask
	_grab_area.add_child(_grab_collision)
	_grab_area.area_entered.connect(_on_grab_entered)
	_grab_area.body_entered.connect(_on_grab_entered)
	_grab_area.area_exited.connect(_on_grab_exited)
	_grab_area.body_exited.connect(_on_grab_exited)
	add_child(_grab_area)


func _process(delta: float) -> void:
	if Engine.is_editor_hint() or not enabled or _controller == null:
		return

	var grip_value := _controller.get_float(pickup_axis_action)
	if grip_pressed and grip_value < (GRIP_THRESHOLD - HYSTERESIS):
		grip_pressed = false
		_on_grip_release()
	elif not grip_pressed and grip_value > (GRIP_THRESHOLD + HYSTERESIS):
		grip_pressed = true
		_on_grip_pressed()

	_update_velocity(delta)
	_update_closest_object()


func _update_velocity(delta: float) -> void:
	if delta <= 0.0:
		return
	var current := global_transform
	_linear_velocity = (current.origin - _last_transform.origin) / delta
	var from_q := _last_transform.basis.get_rotation_quaternion()
	var to_q := current.basis.get_rotation_quaternion()
	var relative := from_q.inverse() * to_q
	var angle := 2.0 * acos(clampf(relative.w, -1.0, 1.0))
	if angle > 0.0001:
		_angular_velocity = relative.get_axis() * (angle / delta)
	else:
		_angular_velocity = Vector3.ZERO
	_linear_velocity = _linear_velocity.limit_length(MAX_THROW_SPEED)
	_angular_velocity = _angular_velocity.limit_length(MAX_THROW_SPEED)
	_last_transform = current


func _on_grip_pressed() -> void:
	if is_instance_valid(picked_up_object) and not picked_up_object.press_to_hold:
		drop_object()
	elif is_instance_valid(closest_object):
		_pick_up_object(closest_object)


func _on_grip_release() -> void:
	if is_instance_valid(picked_up_object) and picked_up_object.press_to_hold:
		drop_object()


func _on_grab_entered(target: Node3D) -> void:
	if not target is XRToolsPickable:
		return
	if _object_in_grab_area.has(target):
		return
	_object_in_grab_area.push_back(target)


func _on_grab_exited(target: Node3D) -> void:
	_object_in_grab_area.erase(target)
	if closest_object == target:
		closest_object = null


func _update_closest_object() -> void:
	var new_closest: XRToolsPickable = null
	if not is_instance_valid(picked_up_object):
		var best_distance := INF
		for obj: Node3D in _object_in_grab_area:
			if not is_instance_valid(obj) or not obj is XRToolsPickable:
				continue
			if not obj.can_pick_up(self):
				continue
			var distance := global_position.distance_squared_to(obj.global_position)
			if distance < best_distance:
				best_distance = distance
				new_closest = obj
	if closest_object == new_closest:
		return
	if is_instance_valid(closest_object):
		closest_object.request_highlight(self, false)
	closest_object = new_closest
	if is_instance_valid(closest_object):
		closest_object.request_highlight(self, true)


func _pick_up_object(target: Node3D) -> void:
	if is_instance_valid(picked_up_object):
		if picked_up_object == target:
			return
		drop_object()
	if not is_instance_valid(target) or not target is XRToolsPickable:
		return
	var pickable := target as XRToolsPickable
	if not pickable.can_pick_up(self):
		return
	picked_up_object = pickable
	pickable.pick_up(self)
	if is_instance_valid(pickable):
		has_picked_up.emit(pickable)


func drop_object() -> void:
	if not is_instance_valid(picked_up_object):
		return
	var pickable := picked_up_object
	picked_up_object = null
	pickable.let_go(self, _linear_velocity * impulse_factor, _angular_velocity)
	has_dropped.emit()


func is_xr_class(xr_name: String) -> bool:
	return xr_name == "XRToolsFunctionPickup"


func _exit_tree() -> void:
	if is_instance_valid(picked_up_object):
		drop_object()


func _set_grab_distance(new_value: float) -> void:
	grab_distance = new_value
	if is_inside_tree() and _grab_collision != null:
		(_grab_collision.shape as SphereShape3D).radius = new_value
