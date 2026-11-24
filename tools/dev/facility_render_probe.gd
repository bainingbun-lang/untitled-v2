extends SceneTree

const VrSim = preload("res://tools/vr_sim/vr_sim.gd")


func _init() -> void:
	await process_frame
	var sim = VrSim.new(self)
	var m = (load("res://maps/downloaded/scifi/facility_map.tscn") as PackedScene).instantiate()
	root.add_child(m)
	current_scene = m
	await sim.attach(m)
	for i in 300:
		await physics_frame
	var f = sim.floor_at(2.0, 14.0)
	sim.teleport(Vector3(2.0, (f if f != null else 0.0) + 0.1, 14.0))
	await sim.frames(20)
	await sim.look_at_point(Vector3(14.0, 1.5, 14.0))
	var mode := OS.get_environment("FAC_MODE")
	if mode.begins_with("ctrl_"):
		var tex1: Texture2D = null
		if mode == "ctrl_res":
			tex1 = load("res://assets/prototype_materials/pattern.png")
		elif mode == "ctrl_fac":
			for mi0 in m.find_children("*", "MeshInstance3D", true, false):
				var inst0 := mi0 as MeshInstance3D
				if inst0.mesh != null and inst0.mesh.get_surface_count() > 0:
					var mt = inst0.get_surface_override_material(0)
					if mt == null:
						mt = inst0.mesh.surface_get_material(0)
					if mt is BaseMaterial3D and (mt as BaseMaterial3D).albedo_texture != null:
						tex1 = (mt as BaseMaterial3D).albedo_texture
						break
		var q1 := MeshInstance3D.new()
		var qm1 := QuadMesh.new()
		qm1.size = Vector2(1.5, 1.5)
		q1.mesh = qm1
		var qmat1 := StandardMaterial3D.new()
		qmat1.albedo_texture = tex1
		qmat1.cull_mode = BaseMaterial3D.CULL_DISABLED
		q1.material_override = qmat1
		m.add_child(q1)
		var hw: Transform3D = sim.head_world()
		q1.global_transform = Transform3D(hw.basis, hw.origin - hw.basis.z * 1.5)
		print("CTRL tex=", tex1, " quad_at=", q1.global_position, " head=", hw.origin)
		mode = "none"
	if mode == "nolights":
		for l in m.find_children("*", "OmniLight3D", true, false):
			l.visible = false
		mode = "none"
	if mode == "noenv":
		for w in m.find_children("*", "WorldEnvironment", true, false):
			w.queue_free()
		mode = "none"
	if mode == "fewlights":
		var k := 0
		for l in m.find_children("*", "OmniLight3D", true, false):
			k += 1
			if k > 2:
				l.visible = false
		mode = "none"
	if mode == "multimesh":
		var groups := {}
		for mi in m.find_children("*", "MeshInstance3D", true, false):
			var inst := mi as MeshInstance3D
			if inst.mesh == null or inst.skin != null or str(inst.name).begins_with("mesh_Hand"):
				continue
			var anc: Node = inst.get_parent()
			var skip := false
			while anc != null and anc != m:
				if anc is CharacterBody3D or anc is XROrigin3D or anc is XRController3D:
					skip = true
				anc = anc.get_parent()
			if skip or not inst.visible:
				continue
			var key := inst.mesh
			if not groups.has(key):
				groups[key] = []
			groups[key].append(inst)
		var made := 0
		for mesh in groups:
			var arr: Array = groups[mesh]
			var first := arr[0] as MeshInstance3D
			for i in mesh.get_surface_count():
				var ov = first.get_surface_override_material(i)
				if ov != null:
					mesh.surface_set_material(i, ov)
			var mm := MultiMesh.new()
			mm.transform_format = MultiMesh.TRANSFORM_3D
			mm.mesh = mesh
			mm.instance_count = arr.size()
			for j in arr.size():
				mm.set_instance_transform(j, (arr[j] as MeshInstance3D).global_transform)
				(arr[j] as MeshInstance3D).visible = false
			var mmi := MultiMeshInstance3D.new()
			mmi.multimesh = mm
			m.add_child(mmi)
			mmi.global_transform = Transform3D.IDENTITY
			made += 1
		print("MULTIMESH grupos=", made)
		mode = "none"
	var plain := StandardMaterial3D.new()
	plain.albedo_color = Color(0.6, 0.6, 0.65)
	plain.cull_mode = BaseMaterial3D.CULL_DISABLED
	if mode == "ctrl_quad":
		mode = "none"
	var done := {}
	var frac_i := 0
	for mi in m.find_children("*", "MeshInstance3D", true, false):
		var inst := mi as MeshInstance3D
		if inst.mesh == null or str(inst.name).begins_with("mesh_Hand"):
			continue
		if mode == "plain":
			inst.material_override = plain
			continue
		if mode.begins_with("frac_"):
			var den: int = int(mode.get_slice("_", 1))
			var num: int = int(mode.get_slice("_", 2))
			frac_i += 1
			if frac_i % den < num:
				inst.material_override = plain
			continue
		if mode.begins_with("except_"):
			if not str(inst.name).begins_with(mode.trim_prefix("except_")):
				inst.material_override = plain
			continue
		if mode.begins_with("only_"):
			var pre: String = mode.trim_prefix("only_")
			if str(inst.name).begins_with(pre):
				inst.material_override = plain
			continue
		if mode == "texstats":
			for i in inst.mesh.get_surface_count():
				var old = inst.get_surface_override_material(i)
				if old == null:
					old = inst.mesh.surface_get_material(i)
				if old is BaseMaterial3D and not done.has(old) and (old as BaseMaterial3D).albedo_texture != null:
					done[old] = true
					var im: Image = ((old as BaseMaterial3D).albedo_texture as Texture2D).get_image()
					var ss := 0.0
					var cnt := 0
					for yy in range(0, im.get_height(), 32):
						for xx in range(0, im.get_width(), 32):
							var c := im.get_pixel(xx, yy)
							ss += (c.r + c.g + c.b) / 3.0
							cnt += 1
					print("TEXMEAN ", inst.name, " ", snappedf(ss / cnt, 0.001), " fmt=", im.get_format(), " size=", im.get_size())
			continue
		if mode in ["fresh_mips", "fresh_linear"]:
			for i in inst.mesh.get_surface_count():
				var old = inst.get_surface_override_material(i)
				if old == null:
					old = inst.mesh.surface_get_material(i)
				if old is BaseMaterial3D and not done.has(old):
					var nm := StandardMaterial3D.new()
					nm.cull_mode = BaseMaterial3D.CULL_DISABLED
					var tex = (old as BaseMaterial3D).albedo_texture
					if tex != null:
						var im2: Image = (tex as Texture2D).get_image()
						im2.convert(Image.FORMAT_RGBA8)
						if mode == "fresh_mips":
							im2.generate_mipmaps()
						nm.albedo_texture = ImageTexture.create_from_image(im2)
					if mode == "fresh_linear":
						nm.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR
					done[old] = nm
				if done.has(old):
					inst.set_surface_override_material(i, done[old])
			continue
		if mode in ["fresh_albedo", "fresh_full"]:
			for i in inst.mesh.get_surface_count():
				var old = inst.get_surface_override_material(i)
				if old == null:
					old = inst.mesh.surface_get_material(i)
				if old is BaseMaterial3D and not done.has(old):
					var nm := StandardMaterial3D.new()
					nm.cull_mode = BaseMaterial3D.CULL_DISABLED
					nm.albedo_texture = (old as BaseMaterial3D).albedo_texture
					nm.metallic = 0.1
					nm.roughness = 0.8
					if mode == "fresh_full":
						nm.normal_enabled = (old as BaseMaterial3D).normal_enabled
						nm.normal_texture = (old as BaseMaterial3D).normal_texture
						nm.metallic_texture = (old as BaseMaterial3D).metallic_texture
						nm.metallic_texture_channel = (old as BaseMaterial3D).metallic_texture_channel
						nm.roughness_texture = (old as BaseMaterial3D).roughness_texture
						nm.roughness_texture_channel = (old as BaseMaterial3D).roughness_texture_channel
					done[old] = nm
				if done.has(old):
					inst.set_surface_override_material(i, done[old])
			continue
		if mode == "freshsurf":
			for i in inst.mesh.get_surface_count():
				inst.set_surface_override_material(i, plain)
			continue
		for i in inst.mesh.get_surface_count():
			var mat = inst.get_surface_override_material(i)
			if mat == null:
				mat = inst.mesh.surface_get_material(i)
			if not (mat is BaseMaterial3D) or done.has(mat):
				continue
			done[mat] = true
			var b := mat as BaseMaterial3D
			if mode in ["nonormal", "albedoonly", "notex"]:
				b.normal_enabled = false
			if mode in ["noorm", "albedoonly", "notex"]:
				b.metallic_texture = null
				b.roughness_texture = null
			if mode == "notex":
				b.albedo_texture = null
			if mode == "metal0":
				b.normal_enabled = false
				b.metallic_texture = null
				b.roughness_texture = null
				b.albedo_texture = null
				b.metallic = 0.0
			if mode == "nocull":
				b.cull_mode = BaseMaterial3D.CULL_BACK
	var t0 := Time.get_ticks_msec()
	var nframes := int(OS.get_environment("FAC_FRAMES")) if OS.get_environment("FAC_FRAMES") != "" else 3
	for k in nframes:
		await RenderingServer.frame_post_draw
	print("FRAMES ", nframes, " en ", Time.get_ticks_msec() - t0, " ms")
	await RenderingServer.frame_post_draw
	var img := root.get_texture().get_image()
	var sum := 0.0
	var n := 0
	for y in range(0, img.get_height(), 8):
		for x in range(0, img.get_width(), 8):
			var c := img.get_pixel(x, y)
			sum += (c.r + c.g + c.b) / 3.0
			n += 1
	img.save_png(OS.get_environment("TMPDIR") + "/fac_" + mode + ".png")
	print("MEAN[", mode, "]=", snappedf(sum / n, 0.001))
	quit()
