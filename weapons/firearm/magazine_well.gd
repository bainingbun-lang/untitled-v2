extends "res://addons/godot-xr-tools/objects/snap_zone.gd"

## Boca del cargador: la mano solo puede sacar el cargador con el arma ya sujeta y con la
## mano libre. Sin esto, la mano que agarra el arma por la empuñadura (que casi coincide con
## el cargador) se llevaba el cargador en vez del arma.


func can_pick_up(by: Node3D) -> bool:
	var gun := get_parent() as XRToolsPickable
	if gun == null or not gun.is_picked_up() or gun.get_picked_up_by() == by:
		return false
	return super(by)
