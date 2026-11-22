extends StaticBody3D

var vp_material

func reset_target():
	$SubViewport/Background.visible = true
	$SubViewport/BulletHole.visible = false
	$SubViewport.render_target_update_mode = SubViewport.UPDATE_ONCE

func hit(p_at, p_direction = Vector3()):
	# We hit our target at the position specified
	var t = global_transform
	var at = (p_at) * t
	
	if p_direction.length() > 0.0:
		var dir = (p_direction) * t.basis.normalized()
		at += dir * at.x
	
	# Adjust from our 3D coordinates to 2D coordinates in our viewport
	at.x = (0.5 - (at.z / 1.0)) * 512.0
	at.y = (0.5 - (at.y / 2.0)) * 1024.0
	
	# Position our bullet hole at these coordinates
	$SubViewport/BulletHole.position = Vector2(at.x - 32.0, at.y - 32.0)
	
	# Now render the bullet hole
	$SubViewport/Background.visible = false
	$SubViewport/BulletHole.visible = true
	$SubViewport.render_target_update_mode = SubViewport.UPDATE_ONCE

# Called when the node enters the scene tree for the first time.
func _ready():
	vp_material = StandardMaterial3D.new()
	vp_material.albedo_texture = $SubViewport.get_texture()
	$MeshInstance3D.material_override = vp_material

