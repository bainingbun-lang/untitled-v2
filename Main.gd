extends Node3D

@onready var resource_queue = get_node("/root/resource_queue")
@onready var fade_to_black = $"SubViewport-VR/FadeToBlack"
@onready var world_scene = $"SubViewport-VR/WorldScene"
@onready var player = $"SubViewport-VR/Player"
@onready var world_environment = $"SubViewport-VR/WorldEnvironment"
@onready var loading_screen = $"SubViewport-VR/LoadingScreen"

var current_world = null

func do_load_world(scene_to_load):
	print("loading...")
	
	# start loading
	resource_queue.queue_resource(scene_to_load)
	
	# fade to black
	fade_to_black.is_faded = true
	await fade_to_black.finished_fading
	
	# remove our current world (if applicable)
	world_scene.visible = false
	if current_world:
		current_world.exit_world()
		current_world.disconnect("change_world", Callable(self, "do_load_world"))
		world_scene.remove_child(current_world)
		current_world.queue_free()
		current_world = null
	
	# init our loading screen
	player.enable_movement = false
	player.enable_pointer = false
	player.enable_pickup = false
	player.position_player(Transform3D())
	world_environment.environment = loading_screen.environment
	loading_screen.visible = true
	
	# fade to transparent
	fade_to_black.is_faded = false
	await fade_to_black.finished_fading
	
	# check if our world has been loaded (might need to add a timeout)
	var new_world = resource_queue.get_resource(scene_to_load)
	while !new_world:
		# wait one second
		await get_tree().create_timer(1.0).timeout
		
		# try again
		new_world = resource_queue.get_resource(scene_to_load)
	
	# fade to black again
	fade_to_black.is_faded = true
	await fade_to_black.finished_fading
	
	# hide our loading screen
	loading_screen.visible = false
	
	# create our new world
	current_world = new_world.instantiate()
	world_scene.add_child(current_world)
	current_world.init_world(player)
	current_world.connect("change_world", Callable(self, "do_load_world"))
	world_environment.environment = current_world.environment
	world_scene.visible = true
	
	# final fade to transparent
	fade_to_black.is_faded = false

func _ready():
	# Tell our display what we want to display
	$"SubViewportContainer/SubViewport-UI".set_viewport_texture($"SubViewport-VR".get_texture())
	
	# Start our resource loader
	resource_queue.start()
	
	# Load our first scene
	do_load_world("res://scenes/selection/Selection.tscn")
