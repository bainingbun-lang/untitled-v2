## VR Two Handed Component
## Copyright (c) 2019 Bastiaan Olij
## MIT License - see LICENSE file

class_name VrTwoHanded
extends VrWeaponBase

@export var enabled: bool = false: set = set_enabled, get = get_enabled

@onready var original_transform: Transform3D = transform

func get_enabled() -> bool:
	return enabled

func set_enabled(new_enabled: bool) -> void:
	enabled = new_enabled
	
	if is_picked_up() and !enabled:
		let_go()
	
	if get_node_or_null("CollisionShape3D"):
		get_node("CollisionShape3D").disabled = !enabled

func pick_up(by: Node, with_controller: XRController3D) -> void:
	super.pick_up(by, with_controller)
	
	var hand = picked_up_by.get_hand()
	if hand:
		hand.visible = false


func let_go(starting_linear_velocity: Vector3 = Vector3.ZERO) -> void:
	if picked_up_by:
		var hand = picked_up_by.get_hand()
		if hand:
			hand.visible = true
		
		picked_up_by.remove_child(self)
		original_parent.add_child(self)
		
		transform = original_transform
		collision_mask = original_collision_mask
		collision_layer = original_collision_layer
		
		## We are no longer picked up
		picked_up_by = null
		by_controller = null

func is_picked_up() -> bool:
	if picked_up_by:
		return true
	return false

func _ready() -> void:
	set_enabled(enabled)