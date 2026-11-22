extends XROrigin3D

@export var render_viewport: NodePath
@export var enable_movement = false: set = set_enable_movement
@export var enable_pickup = false: set = set_enable_pickup
@export var enable_pointer = false: set = set_enable_pointer

# left = 0, right = 1
var pointer_on_hand = 1

var interface = null

func set_enable_movement(enabled : bool):
	enable_movement = enabled
	if $"Left hand/Function_Teleport":
		$"Left hand/Function_Teleport".enabled = enabled
	
	if $"Right hand/Function_Direct_movement":
		$"Right hand/Function_Direct_movement".enabled = enabled

func set_enable_pickup(enabled : bool):
	enable_pickup = enabled
	
	# need to implement enabled on our pickup function in xr-tools
	if $"Left hand/Function_Pickup":
		# $"Left hand/Function_Pickup".enabled = enabled
		pass
	
	if $"Right hand/Function_Pickup":
		# $"Right hand/Function_Pickup".enabled = enabled
		pass

func set_enable_pointer(enabled : bool):
	enable_pointer = enabled
	if $"Left hand/Function_pointer":
		$"Left hand/Function_pointer".enabled = enabled and pointer_on_hand == 0
	
	if $"Right hand/Function_pointer":
		$"Right hand/Function_pointer".enabled = enabled and pointer_on_hand == 1

func position_player(new_transform : Transform3D):
	# need to offset by our camera transform
	var t : Transform3D = $XRCamera3D.transform
	
	# remove height
	t.origin.y = 0
	
	# and remove tilt
	t.basis.y = Vector3.UP
	t.basis.z.y = 0.0
	if t.basis.z.length() == 0:
		t.basis.x = Vector3(1.0, 0.0, 0.0)
		t.basis.z = Vector3(0.0, 0.0, 1.0)
	else:
		t.basis.z = t.basis.z.normalized()
		t.basis.x = t.basis.y.cross(t.basis.z).normalized()
	
	# inverse this
	t = t.inverse()
	
	# and position
	global_transform = new_transform * t

# Called when the node enters the scene tree for the first time.
func _ready():
	interface = XRServer.find_interface("OpenXR")
	if interface and interface.is_initialized():
		var viewport = null
		if render_viewport:
			viewport = get_node(render_viewport)
		
		if !viewport:
			viewport = get_viewport()
		
		# Tell our viewport it is the XR viewport (size comes from the XR interface)
		viewport.use_xr = true
		
		# turn off vsync, the headset compositor paces frames
		DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
		
		# match physics to the headset refresh rate
		var rate = interface.get_display_refresh_rate()
		Engine.physics_ticks_per_second = int(rate) if rate > 0 else 90
	
	$"XRCamera3D/vr_common_shader_cache/Particles".emitting=true
	
	set_enable_movement(enable_movement)
	set_enable_pickup(enable_pickup)
	set_enable_pointer(enable_pointer)

func _on_vr_common_shader_cache_cooldown_finished():
	$"XRCamera3D/vr_common_shader_cache/Particles".emitting=false

func _on_Left_hand_button_pressed(button):
	if button == $"Left hand/Function_pointer".active_button and enable_pointer and pointer_on_hand == 1:
		pointer_on_hand = 0
		set_enable_pointer(enable_pointer)

func _on_Right_hand_button_pressed(button):
	if button == $"Right hand/Function_pointer".active_button and enable_pointer and pointer_on_hand == 0:
		pointer_on_hand = 1
		set_enable_pointer(enable_pointer)

