extends "res://maps/house_model/house_map.gd"

## Mapa de escuela con el modelo CC0 de OpenGameArt (ver CREDITS.md).
func model_path() -> String:
	return "res://maps/downloaded/school/school.glb"


func model_scale() -> float:
	return 1.0


## Escuela: vigilancia de seguridad (defensores sin arma) y alumnos/personal pacíficos.
func npc_spec(total: int) -> Array:
	var guards := maxi(2, int(round(total * 0.2)))
	return [
		{"id": "guardia", "role": "defender", "armed": false, "count": guards},
		{"id": "civil", "role": "civilian", "count": maxi(0, total - guards)},
	]
