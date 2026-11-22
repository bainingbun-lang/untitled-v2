@tool
extends MultiMeshInstance3D

# Helper tool to randomly position our stones whenever we change distance or scale in the editor
# new positions should be saved as part of the scene

@export var distance: float = 300.0: set = set_distance
@export var min_scale: float = 0.1: set = set_min_scale
@export var max_scale: float = 0.8: set = set_max_scale

var is_ready = false

func set_distance(new_distance):
	distance = new_distance
	if is_ready:
		_randomize()

func set_min_scale(new_scale):
	min_scale = new_scale
	if is_ready:
		_randomize()

func set_max_scale(new_scale):
	max_scale = new_scale
	if is_ready:
		_randomize()

func _randomize():
	for i in range(0, multimesh.instance_count):
		var t = Transform3D()
		t.basis = t.basis.rotated(Vector3(1.0,1.0,1.0).normalized(),randf_range(0.0, 4.0))
		t.basis = t.basis.scaled(Vector3(randf_range(min_scale, max_scale), randf_range(min_scale, max_scale), randf_range(min_scale, max_scale)))
		t.origin = Vector3(randf_range(-distance, distance),0.0,randf_range(-distance, distance))
		while t.origin.length() > distance:
			# stay within a circle...
			t.origin = Vector3(randf_range(-distance, distance),0.0,randf_range(-distance, distance))

		multimesh.set_instance_transform(i, t)

# Called when the node enters the scene tree for the first time.
func _ready():
	is_ready = true
