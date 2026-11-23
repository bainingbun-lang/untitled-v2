class_name XRPlayer
extends XROrigin3D

## Rutas (relativas a la raíz XRPlayer): XRCamera3D, LeftHand, RightHand (XRController3D),
## LeftHand/CollisionHandLeft/FunctionPickup, RightHand/CollisionHandRight/FunctionPickup, PlayerBody, MovementSprint.

@onready var camera: XRCamera3D = $XRCamera3D
@onready var left_controller: XRController3D = $LeftHand
@onready var right_controller: XRController3D = $RightHand


func _ready() -> void:
	AssetPack.apply_hand_material(left_controller)
	AssetPack.apply_hand_material(right_controller)


func get_left_controller() -> XRController3D:
	return left_controller


func get_right_controller() -> XRController3D:
	return right_controller


func get_camera() -> XRCamera3D:
	return camera
