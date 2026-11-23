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
	add_child(_panel)

	var player := get_node_or_null("XRPlayer")
	if player == null:
		return
	_head = player.get_node_or_null("XRCamera3D") as XRCamera3D
	call_deferred("_place_panel")
	for path in ["LeftHand", "RightHand"]:
		var c := player.get_node_or_null(path) as XRController3D
		if c != null:
			_controllers.append(c)
			c.button_pressed.connect(_on_button.bind(c, true))
			c.button_released.connect(_on_button.bind(c, false))
			_add_laser(c)


var _head: XRCamera3D
var _placed := false
var _lasers: Dictionary = {}


## Coloca el panel frente a la cabeza (a 2 m, a la altura de los ojos) y lo deja fijo.
## Así no se queda abajo ni arriba según la altura del suelo.
func _place_panel() -> void:
	if _placed or _head == null:
		return
	var eye := _head.global_position
	var fwd := -_head.global_basis.z
	fwd.y = 0.0
	if fwd.length_squared() < 0.0001:
		fwd = Vector3.FORWARD
	fwd = fwd.normalized()
	_panel.global_position = Vector3(eye.x, eye.y - 0.1, eye.z) + fwd * 2.0
	_panel.look_at(eye, Vector3.UP)
	_panel.rotate_y(PI)
	_placed = true


## El panel sigue a la cabeza: siempre a 2 m al frente y a la altura de los ojos, mirando al jugador.
func _follow_head() -> void:
	if _head == null:
		return
	var eye := _head.global_position
	var fwd := -_head.global_basis.z
	fwd.y = 0.0
	if fwd.length_squared() < 0.0001:
		return
	fwd = fwd.normalized()
	var target := eye + fwd * 2.0
	target.y = eye.y
	_panel.global_position = _panel.global_position.lerp(target, 0.15) if _placed else target
	_panel.look_at(eye, Vector3.UP)
	_panel.rotate_y(PI)
	_placed = true


## Línea visible desde el mando hasta el panel, para apuntar.
func _add_laser(c: XRController3D) -> void:
	var mesh := CylinderMesh.new()
	mesh.top_radius = 0.002
	mesh.bottom_radius = 0.002
	mesh.height = 1.0
	var laser := MeshInstance3D.new()
	laser.mesh = mesh
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = Color(1.0, 0.25, 0.2)
	laser.material_override = mat
	c.add_child(laser)
	_lasers[c] = laser


func _update_laser(c: XRController3D, hit: Dictionary) -> void:
	var laser := _lasers.get(c) as MeshInstance3D
	if laser == null:
		return
	var length := 3.0
	if not hit.is_empty():
		length = (c.global_position - _panel.global_position).length() if hit.has("world") == false else (hit["world"] as Vector3 - c.global_position).length()
	laser.visible = true
	laser.position = Vector3(0, 0, -length * 0.5)
	laser.rotation = Vector3(PI * 0.5, 0, 0)
	laser.scale = Vector3(1, length, 1)


func _process(_delta: float) -> void:
	_follow_head()
	for c in _controllers:
		var hit := _ray_panel(c)
		_update_laser(c, hit)
		if hit.is_empty():
			continue
		var motion := InputEventMouseMotion.new()
		motion.position = hit["pos"]
		motion.global_position = hit["pos"]
		_viewport.push_input(motion)


func _on_button(action: String, controller: XRController3D, pressed: bool) -> void:
	if action != "grab" and action != "trigger_click":
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
	return {"pos": Vector2(u * VIEW_SIZE.x, v * VIEW_SIZE.y), "world": from + dir * t}
