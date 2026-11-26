extends SceneTree

const GDM = preload("res://gore/gore_damage_material.gd")
var _fails := 0


func _expect(ok: bool, msg: String) -> void:
	print(("PASS: " if ok else "FAIL: ") + msg)
	if not ok:
		_fails += 1


func _init() -> void:
	var mesh := MeshInstance3D.new()
	mesh.mesh = BoxMesh.new()
	GoreSystem.apply_damage_to_mask(9, Vector2(0.5, 0.5), 1.0, 8)
	GDM.bind_damage_mask(9, mesh)
	_expect(mesh.material_override is ShaderMaterial, "material_override es ShaderMaterial")
	var tex = null
	if mesh.material_override is ShaderMaterial:
		tex = (mesh.material_override as ShaderMaterial).get_shader_parameter("damage_mask")
	_expect(tex is Texture2D, "damage_mask es Texture2D")
	_expect(load("res://gore/gore_damage.gdshader") != null, "shader carga")
	GoreSystem.release_npc_damage_mask(9)
	mesh.free()
	print("RESULTADO: ", "OK" if _fails == 0 else "FALLO %d" % _fails)
	quit(0 if _fails == 0 else 1)
