extends "res://addons/godot-xr-tools/functions/Function_Pickup.gd"

@export var hand: NodePath

func get_tracker_hand():
	if hand:
		return get_node(hand)
	else:
		return null
