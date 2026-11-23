class_name XRPlayer
extends XROrigin3D

## Rutas (relativas a la raíz XRPlayer): XRCamera3D, LeftHand, RightHand (XRController3D),
## LeftHand/CollisionHandLeft/FunctionPickup, RightHand/CollisionHandRight/FunctionPickup, PlayerBody, MovementSprint.
## Cada mano lleva un XRHandExtras (puñetazo y agarre de NPC) y la cintura tiene dos fundas (SnapZone).

## Botón de menú: se emite siempre; además, fuera del menú, vuelve a menu_scene.
signal menu_requested

const HandExtras = preload("res://player/xr_hand_extras.gd")
const SNAP_ZONE := preload("res://addons/godot-xr-tools/objects/snap_zone.tscn")
const HIP_X := 0.22
const HIP_DROP := 0.7

@export var menu_scene := "res://menu/vr_menu.tscn"

@onready var camera: XRCamera3D = $XRCamera3D
@onready var left_controller: XRController3D = $LeftHand
@onready var right_controller: XRController3D = $RightHand

var holsters: Node3D
var holster_left: Node3D
var holster_right: Node3D


func _ready() -> void:
	AssetPack.apply_hand_material(left_controller)
	AssetPack.apply_hand_material(right_controller)
	for c in [left_controller, right_controller]:
		var extras := HandExtras.new()
		extras.name = "HandExtras"
		c.add_child(extras)
		c.button_pressed.connect(_on_button_pressed)
	_build_holsters()


func _physics_process(_delta: float) -> void:
	# Las fundas siguen la cintura: bajo la cabeza y giradas con ella (solo el yaw).
	var p := camera.global_position
	holsters.global_position = Vector3(p.x, p.y - HIP_DROP, p.z)
	holsters.global_rotation = Vector3(0.0, camera.global_rotation.y, 0.0)


func _build_holsters() -> void:
	holsters = Node3D.new()
	holsters.name = "Holsters"
	add_child(holsters)
	holster_right = _add_holster("HolsterRight", HIP_X)
	holster_left = _add_holster("HolsterLeft", -HIP_X)


func _add_holster(n: String, x: float) -> Node3D:
	var zone := SNAP_ZONE.instantiate() as Node3D
	zone.name = n
	zone.snap_require = "holsterable"
	(zone.get_node("CollisionShape3D") as CollisionShape3D).shape.radius = 0.12
	var mi := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(0.1, 0.14, 0.06)
	mi.mesh = box
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.13, 0.1, 0.08)
	mi.material_override = mat
	zone.add_child(mi)
	holsters.add_child(zone)
	zone.position = Vector3(x, 0.0, 0.0)
	return zone


func _on_button_pressed(action: String) -> void:
	if action != "menu_button":
		return
	menu_requested.emit()
	var cur := get_tree().current_scene
	if menu_scene != "" and cur != null and cur.scene_file_path != menu_scene:
		get_tree().change_scene_to_file.call_deferred(menu_scene)


func get_left_controller() -> XRController3D:
	return left_controller


func get_right_controller() -> XRController3D:
	return right_controller


func get_camera() -> XRCamera3D:
	return camera
