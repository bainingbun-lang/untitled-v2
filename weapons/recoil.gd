# Adapted from Godot-FPS-Template camera_recoil.gd
# MIT License, Copyright (c) 2026 Axel Reviron (see recoil_LICENSE.txt)
extends Node

@export var kick_angle: float = 2.0
@export var kick_back: float = 0.01
@export var recovery_speed: float = 12.0
@export var target_name: String = "Body"

var _target: Node3D
var _rest: Transform3D
var _kick: float = 0.0

func _ready() -> void:
	_target = get_parent().get_node_or_null(target_name) as Node3D
	if _target:
		_rest = _target.transform
	set_process(false)

func apply() -> void:
	if not _target:
		return
	_kick = 1.0
	set_process(true)

func _process(delta: float) -> void:
	_kick = lerpf(_kick, 0.0, clampf(recovery_speed * delta, 0.0, 1.0))
	if _kick < 0.001:
		_kick = 0.0
		_target.transform = _rest
		set_process(false)
		return
	var t := _rest
	t.basis = Basis(Vector3.RIGHT, deg_to_rad(kick_angle) * _kick) * _rest.basis
	t.origin += Vector3(0, 0, kick_back * _kick)
	_target.transform = t
