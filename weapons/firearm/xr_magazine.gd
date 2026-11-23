extends XRToolsPickable

## Cargador agarrable (xr-tools). Guarda sus balas mientras está fuera del arma.
@export var rounds := 12


func _ready() -> void:
	super()
	# Un cuerpo congelado como estático no lo detecta ninguna Area3D (la SnapZone): kinemático sí.
	freeze_mode = RigidBody3D.FREEZE_MODE_KINEMATIC
