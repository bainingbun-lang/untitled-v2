class_name GoreDamageMaterial
extends RefCounted

const SHADER = preload("res://gore/gore_damage.gdshader")


static func bind_damage_mask(npc_id: int, mesh: MeshInstance3D) -> void:
	var img: Image = GoreSystem.get_damage_mask(npc_id)
	if img == null:
		return
	var mat := ShaderMaterial.new()
	mat.shader = SHADER
	mat.set_shader_parameter("damage_mask", ImageTexture.create_from_image(img))
	mesh.material_override = mat
