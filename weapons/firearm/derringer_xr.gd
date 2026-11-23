extends Node

## Disparo de la pistola derringer con agarre de xr-tools: al apretar el gatillo con la empuñadura
## agarrada, lanza un rayo desde el cañón y aplica el impacto (herida y sangre) con BulletImpact.
const BulletImpact = preload("res://gore/bullet_impact.gd")
const SHOT_SOUND := "res://weapons/ak47/ak47_shot.wav"
const DAMAGE := 60.0
const RANGE := 60.0

var _muzzle: Node3D
var _shot_sound: AudioStream
var _cooldown := 0.0


func _ready() -> void:
	_muzzle = get_parent().get_node_or_null("Muzzle") as Node3D
	_shot_sound = load(SHOT_SOUND)
	var trigger := get_parent().get_node_or_null("FirearmTrigger")
	if trigger != null and trigger.has_signal("fired"):
		trigger.fired.connect(_fire)


func _process(delta: float) -> void:
	_cooldown = maxf(0.0, _cooldown - delta)


func _fire() -> void:
	if _cooldown > 0.0 or _muzzle == null:
		return
	_cooldown = 0.5
	var from := _muzzle.global_position
	var dir := -_muzzle.global_basis.z
	var space := _muzzle.get_world_3d().direct_space_state
	var q := PhysicsRayQueryParameters3D.create(from, from + dir * RANGE)
	q.exclude = [get_parent().get_rid()]
	var hit := space.intersect_ray(q)
	if _shot_sound != null:
		var p := AudioStreamPlayer3D.new()
		p.stream = _shot_sound
		get_tree().root.add_child(p)
		p.global_position = from
		p.play()
		p.finished.connect(p.queue_free)
	if not hit.is_empty():
		BulletImpact.apply(hit["collider"], hit["position"], hit["normal"], DAMAGE, self)
