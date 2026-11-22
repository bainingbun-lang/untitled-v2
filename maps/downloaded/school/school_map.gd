extends "res://maps/house_model/house_map.gd"

## Mapa de escuela con el modelo CC0 de OpenGameArt (ver CREDITS.md).
func model_path() -> String:
	return "res://maps/downloaded/school/school.glb"


## Escuela: vigilancia de seguridad (defensores sin arma) y alumnos/personal pacíficos.
func npc_spec() -> Array:
	return [
		{"id": "guardia", "role": "defender", "armed": false, "count": 2},
		{"id": "civil", "role": "civilian", "count": 5},
	]
