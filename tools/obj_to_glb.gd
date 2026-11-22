extends SceneTree

## Convierte un OBJ+MTL (con texturas PNG) a GLB, para mapas descargados.
## Uso: godot --headless --path . --script res://tools/obj_to_glb.gd -- <obj_res> <glb_out_res>
func _init() -> void:
	var args := OS.get_cmdline_user_args()
	var obj_path: String = args[0]
	var out_path: String = args[1]
	var mtl_path := obj_path.get_basename() + ".mtl"
	var mats := _parse_mtl(mtl_path)
	var obj := FileAccess.get_file_as_string(obj_path)
	var v: PackedVector3Array = []
	var vt: PackedVector2Array = []
	var vn: PackedVector3Array = []
	var groups := {}  # material name -> {verts, uvs, norms}
	var current := "default"
	for raw in obj.split("\n"):
		var line := raw.strip_edges()
		if line.begins_with("v "):
			var p := line.split(" ", false)
			v.append(Vector3(float(p[1]), float(p[2]), float(p[3])))
		elif line.begins_with("vt "):
			var p := line.split(" ", false)
			vt.append(Vector2(float(p[1]), 1.0 - float(p[2])))
		elif line.begins_with("vn "):
			var p := line.split(" ", false)
			vn.append(Vector3(float(p[1]), float(p[2]), float(p[3])))
		elif line.begins_with("usemtl "):
			current = line.substr(7).strip_edges()
		elif line.begins_with("f "):
			if not groups.has(current):
				groups[current] = {"v": PackedVector3Array(), "uv": PackedVector2Array(), "n": PackedVector3Array()}
			var g: Dictionary = groups[current]
			var corners: Array = []
			for tok in line.split(" ", false).slice(1):
				var idx := str(tok).split("/")
				var vi := int(idx[0]) - 1 if int(idx[0]) > 0 else v.size() + int(idx[0])
				var ti := -1
				if idx.size() > 1 and idx[1] != "":
					ti = int(idx[1]) - 1 if int(idx[1]) > 0 else vt.size() + int(idx[1])
				var ni := -1
				if idx.size() > 2 and idx[2] != "":
					ni = int(idx[2]) - 1 if int(idx[2]) > 0 else vn.size() + int(idx[2])
				corners.append([vi, ti, ni])
			# Triangulación en abanico.
			for k in range(1, corners.size() - 1):
				for c in [corners[0], corners[k + 1], corners[k]]:  # Godot usa caras horario; OBJ viene antihorario.
					g["v"].append(v[c[0]])
					g["uv"].append(vt[c[1]] if c[1] >= 0 else Vector2.ZERO)
					g["n"].append(vn[c[2]] if c[2] >= 0 else Vector3.UP)
	var root := Node3D.new()
	root.name = "School"
	for mname in groups.keys():
		var g: Dictionary = groups[mname]
		var st := SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		for i in g["v"].size():
			st.set_uv(g["uv"][i])
			st.add_vertex(g["v"][i])
		st.generate_normals()
		var am := st.commit()
		var mi := MeshInstance3D.new()
		mi.name = mname.validate_node_name()
		mi.mesh = am
		var mat := StandardMaterial3D.new()
		mat.cull_mode = BaseMaterial3D.CULL_DISABLED
		mat.roughness = 0.9
		mat.albedo_color = Color.WHITE
		if mats.has(mname):
			var md: Dictionary = mats[mname]
			mat.albedo_color = md.get("color", Color.WHITE)
			if md.has("tex"):
				var img := Image.load_from_file(ProjectSettings.globalize_path(md["tex"]))
				if img != null:
					mat.albedo_texture = ImageTexture.create_from_image(img)
		am.surface_set_material(0, mat)
		root.add_child(mi)
		mi.owner = root
	var gltf := GLTFDocument.new()
	var state := GLTFState.new()
	var err := gltf.append_from_scene(root, state)
	if err != OK:
		print("OBJGLB append error ", err)
		quit(1)
		return
	err = gltf.write_to_filesystem(state, ProjectSettings.globalize_path(out_path))
	print("OBJGLB ", "OK" if err == OK else "ERR %d" % err, " surfaces=", groups.size(), " verts=", v.size())
	quit(0 if err == OK else 1)


func _parse_mtl(path: String) -> Dictionary:
	var out := {}
	if not FileAccess.file_exists(path):
		return out
	var cur := ""
	for raw in FileAccess.get_file_as_string(path).split("\n"):
		var line := raw.strip_edges()
		if line.begins_with("newmtl "):
			cur = line.substr(7).strip_edges()
			out[cur] = {}
		elif cur != "" and line.begins_with("Kd "):
			var p := line.split(" ", false)
			out[cur]["color"] = Color(float(p[1]), float(p[2]), float(p[3]))
		elif cur != "" and line.begins_with("map_Kd "):
			var tex := line.substr(7).strip_edges()
			out[cur]["tex"] = path.get_base_dir().path_join(tex.get_file())
	return out
