@tool
extends Node3D

@export var screen_size = Vector2(3.0, 2.0): get = get_screen_size, set = set_screen_size
@export var viewport_size = Vector2(300.0, 200.0): get = get_viewport_size, set = set_viewport_size
@export var transparent = true: get = get_transparent, set = set_transparent
@export var scene: PackedScene = null: get = get_scene, set = set_scene

# Need to replace this with proper solution once support for layer selection has been added
@export var collision_layer = 15: get = get_collision_layer, set = set_collision_layer # (int, LAYERS_3D_PHYSICS)

var is_ready = false
var scene_node = null

func set_screen_size(new_size: Vector2):
	screen_size = new_size
	if is_ready:
		$Screen.mesh.size = screen_size
		$StaticBody3D.screen_size = screen_size
		$StaticBody3D/CollisionShape3D.shape.extents = Vector3(screen_size.x * 0.5, screen_size.y * 0.5, 0.01)

func get_screen_size():
	return screen_size

func set_viewport_size(new_size: Vector2):
	viewport_size = new_size
	if is_ready:
		$SubViewport.size = new_size
		$StaticBody3D.viewport_size = new_size
		var material : StandardMaterial3D = $Screen.get_surface_override_material(0)
		material.albedo_texture = $SubViewport.get_texture()

func get_viewport_size():
	return viewport_size

func set_transparent(new_transparent: bool):
	transparent = new_transparent
	if is_ready:
		var material : StandardMaterial3D = $Screen.get_surface_override_material(0)
		material.flags_transparent = transparent
		$SubViewport.transparent_bg = transparent

func get_transparent():
	return transparent

func set_collision_layer(new_layer: int):
	collision_layer = new_layer
	if is_ready:
		$StaticBody3D.collision_layer = collision_layer

func get_collision_layer():
	return collision_layer

func set_scene(new_scene: PackedScene):
	scene = new_scene
	if is_ready:
		# out with the old
		if scene_node:
			$SubViewport.remove_child(scene_node)
			scene_node.queue_free()

		# in with the new
		if scene:
			scene_node = scene.instantiate()
			$SubViewport.add_child(scene_node)

func get_scene():
	return scene

func get_scene_instance():
	return scene_node

func connect_scene_signal(which, on, callback):
	if scene_node:
		scene_node.connect(which, Callable(on, callback))

# Called when the node enters the scene tree for the first time.
func _ready():
	# apply properties
	is_ready = true
	set_screen_size(screen_size)
	set_viewport_size(viewport_size)
	set_scene(scene)
	set_collision_layer(collision_layer)
