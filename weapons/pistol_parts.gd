extends Node3D

## Animates the pistol parts by moving them along their own axis.
## amount is normalized: 0 = rest position, 1 = fully back / fully out.

const SLIDE_TRAVEL: float = 0.05
const MAGAZINE_DROP: float = 0.15

var slide: MeshInstance3D
var magazine: MeshInstance3D
var trigger: MeshInstance3D
var hammer: MeshInstance3D
var chamber: Marker3D

var slide_start_pos: Vector3
var magazine_start_pos: Vector3
var _parts_ready: bool = false


func _ready() -> void:
	_resolve_parts()


func _resolve_parts() -> void:
	if _parts_ready:
		return
	slide = get_node_or_null("Slide") as MeshInstance3D
	magazine = get_node_or_null("Magazine") as MeshInstance3D
	trigger = get_node_or_null("Trigger") as MeshInstance3D
	hammer = get_node_or_null("Hammer") as MeshInstance3D
	chamber = get_node_or_null("Chamber") as Marker3D
	if slide != null:
		slide_start_pos = slide.position
	if magazine != null:
		magazine_start_pos = magazine.position
	_parts_ready = true


## Pulls the slide backwards along +Z (the barrel points along -Z).
func set_slide_back(amount: float) -> void:
	_resolve_parts()
	if slide == null:
		return
	var t: float = clampf(amount, 0.0, 1.0)
	slide.position = slide_start_pos + Vector3(0, 0, SLIDE_TRAVEL * t)


## Drops the magazine downwards along -Y.
func set_magazine_out(amount: float) -> void:
	_resolve_parts()
	if magazine == null:
		return
	var t: float = clampf(amount, 0.0, 1.0)
	magazine.position = magazine_start_pos + Vector3(0, -MAGAZINE_DROP * t, 0)
