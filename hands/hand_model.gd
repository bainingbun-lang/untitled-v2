class_name HandModel
extends Node3D

const R := preload("res://hands/model/Hand_Glove_R.gltf")
const L := preload("res://hands/model/Hand_Glove_L.gltf")

func _init() -> void:
	name = "HandModel"

func _ready() -> void:
	var p := get_parent() as XRController3D
	var left := p != null and p.tracker == &"left_hand"
	add_child((L if left else R).instantiate())
