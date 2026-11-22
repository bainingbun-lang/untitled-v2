class_name Holster
extends Node3D

signal drawn

@export var radius := 0.18
var controller: XRController3D
var weapon: Node3D
var _was := false

func _ready() -> void:
	name = "Holster"
	var area := Area3D.new()
	var cs := CollisionShape3D.new()
	var s := SphereShape3D.new()
	s.radius = radius
	cs.shape = s
	area.add_child(cs)
	add_child(area)

func _process(_d: float) -> void:
	if not is_instance_valid(controller):
		return
	var g := controller.is_button_pressed("grip_click")
	if g and not _was and controller.global_position.distance_to(global_position) < radius:
		if is_instance_valid(weapon) and weapon.has_method("holster_draw"):
			weapon.call("holster_draw")
		drawn.emit()
	_was = g
