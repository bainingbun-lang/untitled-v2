extends StaticBody3D

signal pressed(at)

func pointer_pressed(at):
	emit_signal("pressed", at)

func pointer_entered():
	if $Texture2D:
		$Texture2D.get_surface_override_material(0).albedo_color = Color(0.8, 0.8, 1.0, 1.0)

func pointer_exited():
	if $Texture2D:
		$Texture2D.get_surface_override_material(0).albedo_color = Color(1.0, 1.0, 1.0, 1.0)
