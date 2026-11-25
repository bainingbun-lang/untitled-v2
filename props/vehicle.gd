class_name Vehicle
extends VehicleBody3D

## Coche básico conducible: el jugador se sienta, el joystick izquierdo acelera (adelante) y gira, A/X se baja.
const SEAT := Vector3(-0.35, 0.55, 0.1)
const FORCE := 700.0 # por rueda (4 con tracción)
const MAX_SPEED := 14.0
const STEER := 0.45
const GROUP := "vehicle"

var driver: XRPlayer
var _off: Array = []
var _last_yaw := 0.0


func _ready() -> void:
	add_to_group(GROUP)
	mass = 700.0
	var body := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(1.7, 0.5, 3.4)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.7, 0.1, 0.1)
	bm.material = mat
	body.mesh = bm
	body.position.y = 0.55
	add_child(body)
	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = bm.size
	cs.shape = bs
	cs.position.y = 0.55
	add_child(cs)
	center_of_mass_mode = RigidBody3D.CENTER_OF_MASS_MODE_CUSTOM
	center_of_mass = Vector3(0, 0.15, 0)
	for x in [-0.85, 0.85]:
		for z in [-1.15, 1.15]:
			_wheel(Vector3(x, 0.35, z), z < 0.0)


func _wheel(pos: Vector3, front: bool) -> void:
	var w := VehicleWheel3D.new()
	w.position = pos
	w.use_as_steering = front
	w.use_as_traction = true
	w.wheel_radius = 0.35
	w.wheel_rest_length = 0.15
	w.suspension_travel = 0.2
	w.suspension_stiffness = 45.0
	w.wheel_friction_slip = 3.0
	var m := MeshInstance3D.new()
	var c := CylinderMesh.new()
	c.top_radius = 0.35
	c.bottom_radius = 0.35
	c.height = 0.25
	m.mesh = c
	m.rotation.z = PI * 0.5
	w.add_child(m)
	add_child(w)


func enter(player: XRPlayer) -> void:
	if driver != null:
		return
	driver = player
	_set_walk(player, false)
	_last_yaw = global_rotation.y
	player.left_controller.button_pressed.connect(_on_button)


func exit() -> void:
	if driver == null:
		return
	var p := driver
	driver = null
	_set_walk(p, true)
	if p.left_controller.button_pressed.is_connected(_on_button):
		p.left_controller.button_pressed.disconnect(_on_button)
	p.global_position = global_position + global_basis.x * 2.2
	engine_force = 0.0
	steering = 0.0


func _on_button(action: String) -> void:
	if action == "ax_button":
		exit()


func _set_walk(p: XRPlayer, on: bool) -> void:
	for n in p.find_children("*", "XRToolsMovementDirect", true, false):
		n.enabled = on


func _physics_process(_delta: float) -> void:
	if driver == null or not is_instance_valid(driver):
		return
	var stick := driver.left_controller.get_vector2("primary")
	var drive := absf(stick.y) > 0.15 and linear_velocity.length() < MAX_SPEED
	engine_force = stick.y * -FORCE if drive else 0.0
	brake = 12.0 if absf(stick.y) <= 0.15 else 0.0
	steering = lerpf(steering, -stick.x * STEER, 0.2)
	var yaw := global_rotation.y
	driver.rotate_y(yaw - _last_yaw)
	_last_yaw = yaw
	driver.global_position = global_transform * SEAT + Vector3(0, -0.55, 0)
