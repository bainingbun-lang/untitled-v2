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
#   addons/godot-xr-tools/objects/pickable.gd

@tool
## (sin class_name: el addon godot-xr-tools define XRToolsPickable)
extends RigidBody3D

## Pickable object adapted from godot-xr-tools. Keeps the original
## pick_up / let_go / can_pick_up API but drops addon-only dependencies
## (XRToolsGrabDriver, XRToolsGrabPoint, XRToolsSnapZone, ...).

signal picked_up(pickable: XRToolsPickable)
signal dropped(pickable: XRToolsPickable)
signal grabbed(pickable: XRToolsPickable, by: Node3D)
signal released(pickable: XRToolsPickable, by: Node3D)
signal action_pressed(pickable: XRToolsPickable)
signal action_released(pickable: XRToolsPickable)
signal highlight_updated(pickable: Node3D, enable: bool)

const DEFAULT_LAYER := 0b0000_0000_0000_0001_0000_0000_0000_0000

@export var enabled := true
@export var press_to_hold := true
@export_flags_3d_physics var picked_up_layer := DEFAULT_LAYER
@export var can_ranged_grab := false

var restore_freeze := false

var _holder: Node3D = null
var _grab_offset := Transform3D.IDENTITY
var _highlight_requests: Dictionary = {}
var _highlighted := false

@onready var original_collision_mask: int = collision_mask
@onready var original_collision_layer: int = collision_layer


func _physics_process(_delta: float) -> void:
	if not is_picked_up():
		return
	global_transform = _holder.global_transform * _grab_offset


func is_picked_up() -> bool:
	return is_instance_valid(_holder)


func get_picked_up_by() -> Node3D:
	return _holder if is_picked_up() else null


func can_pick_up(_by: Node3D) -> bool:
	if not enabled:
		return false
	return not is_picked_up()


func pick_up(by: Node3D) -> void:
	if not enabled or is_picked_up():
		return
	_holder = by
	restore_freeze = freeze
	original_collision_layer = collision_layer
	original_collision_mask = collision_mask
	_grab_offset = _holder.global_transform.affine_inverse() * global_transform
	freeze = true
	collision_layer = picked_up_layer
	collision_mask = 0
	picked_up.emit(self)
	grabbed.emit(self, by)


func let_go(by: Node3D, p_linear_velocity: Vector3, p_angular_velocity: Vector3) -> void:
	if not is_picked_up():
		return
	if by != null and by != _holder:
		return
	var previous_holder: Node3D = _holder
	_holder = null
	freeze = restore_freeze
	collision_layer = original_collision_layer
	collision_mask = original_collision_mask
	linear_velocity = p_linear_velocity
	angular_velocity = p_angular_velocity
	dropped.emit(self)
	released.emit(self, previous_holder)


func drop() -> void:
	if is_picked_up() and _holder.has_method("drop_object"):
		_holder.call("drop_object")


func action() -> void:
	action_pressed.emit(self)


func action_release() -> void:
	action_released.emit(self)


func request_highlight(from: Node, on: bool = true) -> void:
	var old_highlighted := _highlighted
	if from == null:
		_highlight_requests.clear()
	elif on:
		_highlight_requests[from] = true
	else:
		_highlight_requests.erase(from)
	_highlighted = not _highlight_requests.is_empty()
	if _highlighted != old_highlighted:
		highlight_updated.emit(self, _highlighted)


func is_xr_class(xr_name: String) -> bool:
	return xr_name == "XRToolsPickable"
