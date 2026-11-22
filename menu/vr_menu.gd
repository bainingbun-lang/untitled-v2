extends Node3D

## Menú dentro del casco: el menú 2D se dibuja en un SubViewport y se muestra en un panel 3D.
## El puntero es el rayo de cualquier mando, y el gatillo hace clic en el panel.
## Limitación: sin verificar en casco real.

const MENU_SCENE := preload("res://menu/main_menu.tscn")
const PANEL_SIZE := Vector2(2.4, 1.5)
const VIEW_SIZE := Vector2i(1280, 800)
const MAX_DISTANCE := 6.0

var _viewport: SubViewport
var _panel: MeshInstance3D
var _controllers: Array[XRController3D] = []
var _pressed := {}


func _ready() -> void:
	_viewport = SubViewport.new()
	_viewport.size = VIEW_SIZE
	_viewport.transparent_bg = false
	_viewport.disable_3d = true
	add_child(_viewport)
	_viewport.add_child(MENU_SCENE.instantiate())

	_panel = MeshInstance3D.new()
	var quad := QuadMesh.new()
	quad.size = PANEL_SIZE
	_panel.mesh = quad
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_texture = _viewport.get_texture()
	_panel.material_override = mat
	_panel.position = Vector3(0, 1.4, -2.0)
	add_child(_panel)

	var player := get_node_or_null("VRPlayer")
	if player == null:
		return
	for path in ["CharacterBody3D/Origin/LeftController", "CharacterBody3D/Origin/RightController"]:
		var c := player.get_node_or_null(path) as XRController3D
		if c != null:
			_controllers.append(c)
			c.button_pressed.connect(_on_button.bind(c, true))
			c.button_released.connect(_on_button.bind(c, false))


func _process(_delta: float) -> void:
	for c in _controllers:
		var hit := _ray_panel(c)
		if hit.is_empty():
			continue
		var motion := InputEventMouseMotion.new()
		motion.position = hit["pos"]
		motion.global_position = hit["pos"]
		_viewport.push_input(motion)


func _on_button(action: String, controller: XRController3D, pressed: bool) -> void:
	if action != "trigger_click":
		return
	var hit := _ray_panel(controller)
	if hit.is_empty():
		return
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = pressed
	click.position = hit["pos"]
	click.global_position = hit["pos"]
	_viewport.push_input(click)


## Devuelve {"pos": Vector2 en píxeles del SubViewport} si el rayo del mando toca el panel.
func _ray_panel(c: XRController3D) -> Dictionary:
	var from := c.global_position
	var dir := -c.global_basis.z
	var n := _panel.global_basis.z
	var denom := dir.dot(n)
	if absf(denom) < 0.0001:
		return {}
	var t := (_panel.global_position - from).dot(n) / denom
	if t < 0.0 or t > MAX_DISTANCE:
		return {}
	var local := _panel.global_transform.affine_inverse() * (from + dir * t)
	if absf(local.x) > PANEL_SIZE.x * 0.5 or absf(local.y) > PANEL_SIZE.y * 0.5:
		return {}
	var u := (local.x + PANEL_SIZE.x * 0.5) / PANEL_SIZE.x
	var v := (PANEL_SIZE.y * 0.5 - local.y) / PANEL_SIZE.y
	return {"pos": Vector2(u * VIEW_SIZE.x, v * VIEW_SIZE.y)}
