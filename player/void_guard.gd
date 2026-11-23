extends Node

## Cuida el spawn del jugador:
##  - Sube el origen al piso real si nació bajo él (sandbox: origen y=0, piso y=0.5); sin esto
##    PlayerBody crece sin fin, llega a 2.5 m, choca con el techo y no puede caminar.
##  - Limita la altura del cuerpo a 1.8 m.
##  - Si cae al vacío (mapa aún construyéndose, hueco), lo devuelve a su punto de aparición.
## Se agrega como hijo de una escena que contiene XRPlayer.
const FALL_LIMIT := -4.0
const MAX_BODY_HEIGHT := 1.8
const SNAP_SECONDS := 8.0

var _origin: Node3D
var _spawn := Vector3.ZERO
var _snapped := false
var _age := 0.0


func _ready() -> void:
	var player := get_parent().get_node_or_null("XRPlayer")
	if player == null:
		return
	var found := player.find_children("*", "XROrigin3D", true, false)
	_origin = (found[0] as Node3D) if not found.is_empty() else (player as Node3D)
	_spawn = _origin.global_position
	var body := _origin.get_node_or_null("PlayerBody")
	if body != null:
		body.set("player_height_max", MAX_BODY_HEIGHT)


func _physics_process(delta: float) -> void:
	if _origin == null:
		return
	_age += delta
	if not _snapped and _age < SNAP_SECONDS:
		_try_snap_to_floor()
	if _origin.global_position.y < FALL_LIMIT:
		_origin.global_position = _spawn + Vector3(0, 0.6, 0)
		var body := _origin.get_parent()
		if body is CharacterBody3D:
			(body as CharacterBody3D).velocity = Vector3.ZERO


func _try_snap_to_floor() -> void:
	var p := _origin.global_position
	var q := PhysicsRayQueryParameters3D.create(p + Vector3(0, 3, 0), p + Vector3(0, -3, 0), 1)
	var hit := _origin.get_world_3d().direct_space_state.intersect_ray(q)
	if hit.is_empty():
		return
	_snapped = true
	if hit.position.y > p.y + 0.02:
		_origin.global_position.y = hit.position.y
		_spawn = _origin.global_position
