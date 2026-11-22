## VR Weapon Base
## Copyright (c) 2019 Bastiaan Olij
## MIT License - see LICENSE file

class_name VrWeaponBase
extends RigidBody3D

## Set hold mode
@export var press_to_hold: bool = true
@export var reset_transform_on_pickup: bool = true
## Agarre libre: el arma conserva el punto donde la mano la tomó (culata, cargador, cañón...).
## Con false vuelve al punto de agarre fijo (center_pickup_on_node).
@export var free_grab: bool = true
@export var center_pickup_on: NodePath = NodePath()
@export var highlight_mesh_instance: NodePath = NodePath()
@export var picked_up_layer: int = 0

const HIGHLIGHT_PATH := "res://addons/godot-xr-tools/materials/highlight.tres"

## Remember some state so we can return to it when the user drops the object
@onready var original_parent: Node3D = get_parent() as Node3D
@onready var original_collision_mask: int = collision_mask
@onready var original_collision_layer: int = collision_layer

## shortcut: godot-xr-tools addon is not in this project; highlight is skipped until it is added.
var highlight_material = load(HIGHLIGHT_PATH) if ResourceLoader.exists(HIGHLIGHT_PATH) else null
var original_materials: Array = []
var highlight_mesh_instance_node: MeshInstance3D = null

## Who picked us up?
var picked_up_by: Node = null
var center_pickup_on_node: Node3D = null
var by_controller: XRController3D = null
var closest_count: int = 0

## Have we been picked up?
func is_picked_up() -> bool:
	return picked_up_by != null

func _update_highlight() -> void:
	if highlight_mesh_instance_node:
		for i in range(highlight_mesh_instance_node.get_surface_material_count()):
			if closest_count > 0:
				highlight_mesh_instance_node.set_surface_override_material(i, highlight_material)
			else:
				highlight_mesh_instance_node.set_surface_override_material(i, original_materials[i])

func increase_is_closest() -> void:
	closest_count += 1
	_update_highlight()

func decrease_is_closest() -> void:
	closest_count -= 1
	_update_highlight()

func drop_and_free() -> void:
	if picked_up_by:
		picked_up_by.call("drop_object")
	queue_free()

## We are being picked up by...
func pick_up(by: Node, with_controller: XRController3D) -> void:
	if picked_up_by == by:
		return

	if picked_up_by:
		let_go()

	## Remember who picked us up
	picked_up_by = by
	by_controller = with_controller

	## Turn off physics on our pickable object
	freeze = true
	collision_layer = picked_up_layer
	collision_mask = 0

	## Now reparent it
	var original_transform: Transform3D = global_transform
	original_parent.remove_child(self)
	picked_up_by.add_child(self)

	if free_grab:
		## Agarre libre: mantiene la pose en el momento de agarrar, relativa a la mano.
		global_transform = original_transform
		transform = with_controller.global_transform.inverse() * original_transform if with_controller else transform
	elif reset_transform_on_pickup:
		if center_pickup_on_node:
			transform = center_pickup_on_node.global_transform.inverse() * global_transform
		else:
			## Reset our transform
			transform = Transform3D.IDENTITY
	else:
		## Make sure we keep its original position
		global_transform = original_transform

## We are being let go
func let_go(starting_linear_velocity: Vector3 = Vector3.ZERO) -> void:
	if picked_up_by:
		## Get our current global transform
		var t: Transform3D = global_transform

		## Reparent it
		picked_up_by.remove_child(self)
		original_parent.add_child(self)

		## Reposition it and apply impulse
		global_transform = t
		freeze = false
		collision_mask = original_collision_mask
		collision_layer = original_collision_layer

		## Set our starting velocity
		linear_velocity = starting_linear_velocity

		## We are no longer picked up
		picked_up_by = null
		by_controller = null

func _ready() -> void:
	if highlight_mesh_instance:
		highlight_mesh_instance_node = get_node(highlight_mesh_instance)
		if highlight_mesh_instance_node:
			for i in range(highlight_mesh_instance_node.get_surface_material_count()):
				original_materials.append(highlight_mesh_instance_node.get_surface_override_material(i))

	if center_pickup_on:
		center_pickup_on_node = get_node(center_pickup_on)