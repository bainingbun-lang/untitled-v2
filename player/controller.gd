extends XRController3D

signal controller_activated(controller)
# Godot 3 style button ids (int) for the xr-tools functions and weapons.
signal vr_button_pressed(button)
signal vr_button_released(button)

# Godot 3 OpenVR button ids -> Godot 4 OpenXR default action map names.
const BUTTON_ACTIONS = {
	1: "by_button",
	2: "grip_click",
	7: "ax_button",
	14: "primary_click",
	15: "trigger_click",
}

# Driven by weapon animations (M1911 "Fire" track), 0..1.
var rumble = 0.0: set = set_rumble

func set_rumble(value):
	rumble = value
	if value > 0.0:
		trigger_haptic_pulse("haptic", 0.0, value, 0.1, 0.0)

func get_joystick_axis(axis):
	var v = get_vector2("primary")
	return v.x if axis == 0 else v.y

func is_vr_button_pressed(button):
	return BUTTON_ACTIONS.has(button) and is_button_pressed(BUTTON_ACTIONS[button])

func _on_button_pressed(action_name):
	var id = BUTTON_ACTIONS.find_key(action_name)
	if id != null:
		vr_button_pressed.emit(id)

func _on_button_released(action_name):
	var id = BUTTON_ACTIONS.find_key(action_name)
	if id != null:
		vr_button_released.emit(id)

func _ready():
	button_pressed.connect(_on_button_pressed)
	button_released.connect(_on_button_released)
	# hide to begin with
	visible = false

func _process(_delta):
	if !get_is_active():
		visible = false
		return

	if visible:
		return

	# make it visible
	visible = true
	controller_activated.emit(self)
