extends Node

## Avanza GoreSystem.update (charcos que crecen, sangrado de muñones) en cada paso de física: nadie más lo llamaba.
func _physics_process(delta: float) -> void:
	preload("res://gore/gore_system.gd").update(delta)
