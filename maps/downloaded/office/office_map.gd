extends "res://maps/house_model/house_map.gd"

## Mapa de oficina con el modelo CC0 de innerscene (ver CREDITS.md).
func model_path() -> String:
	return "res://maps/downloaded/office/office.glb"


## El modelo mide ~6 m de ancho; a escala x3 queda como un edificio de oficinas de ~19 m.
func model_scale() -> float:
	return 3.0
