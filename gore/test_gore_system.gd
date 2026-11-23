extends SceneTree

const GoreScript = preload("res://gore/gore_system.gd")
const DecalsScript = preload("res://gore/wound_decals.gd")

var _checks := 0
var _failures: Array = []
var _case := ""


func _initialize() -> void:
	await process_frame
	await _run()
	if _failures.is_empty():
		print("PASS (%d assertions)" % _checks)
		quit(0)
	else:
		for failure in _failures:
			print("FAIL: " + failure)
		print("FAIL (%d/%d assertions fallidas)" % [_failures.size(), _checks])
		quit(1)


func _expect(condition: bool, label: String) -> void:
	_checks += 1
	if not condition:
		_failures.append("[%s] %s" % [_case, label])


func _run() -> void:
	_case = "inicializacion y limites base"
	GoreScript.clear()
	GoreScript.initialize()
	_expect(GoreScript.get_gore_level() == GoreScript.GoreLevel.NORMAL, "nivel inicial NORMAL")
	_expect(GoreScript.gore_enabled(), "gore habilitado")
	_expect(not GoreScript.is_extreme(), "no es EXTREME")
	var limits: Dictionary = GoreScript.get_limits()
	_expect(int(limits["decals"]) == 24, "limite decals=24")
	_expect(int(limits["puddles"]) == 16, "limite puddles=16")
	_expect(int(limits["parts"]) == 12, "limite parts=12")
	_expect(int(limits["active_particles"]) == 24, "limite particles=24")

	_case = "nivel OFF desactiva sangre"
	GoreScript.set_gore_level(GoreScript.GoreLevel.OFF)
	_expect(not GoreScript.gore_enabled(), "gore deshabilitado con OFF")
	_expect(int(GoreScript.get_limits()["decals"]) == 0, "limite decals=0 con OFF")
	var off_parent := Node3D.new()
	root.add_child(off_parent)
	_expect(GoreScript.create_bullet_wound(off_parent, Vector3.ZERO, Vector3.UP).is_empty(), "sin herida con OFF")
	_expect(GoreScript.create_puddle(off_parent, Vector3.ZERO, Vector3.UP, 0.3) == null, "sin charco con OFF")
	off_parent.free()

	_case = "sangre en superficie"
	GoreScript.apply_gore_level(GoreScript.GoreLevel.NORMAL)
	var parent := Node3D.new()
	parent.name = "ParentBlood"
	root.add_child(parent)
	var wound: Dictionary = GoreScript.create_bullet_wound(
		parent, Vector3(0.0, 0.1, 0.0), Vector3.UP, false, "torso", 7
	)
	_expect(not wound.is_empty(), "herida creada")
	_expect(int(wound.get("npc_id", -1)) == 7, "npc_id conservado")
	_expect(is_instance_valid(wound.get("root", null)), "raiz de herida valida")
	_expect(GoreScript.decal_count() == 1, "un decal de herida")
	_expect(parent.get_node_or_null("Wound_torso") != null, "nodo Wound_torso presente")
	_expect(GoreScript.get_damage_mask(7) != null, "mascara de dano creada")
	_expect(GoreScript.damage_mask_count() == 1, "una mascara de dano")
	GoreScript.create_blood_trail(parent, Vector3(0.0, 0.0, 0.0), Vector3(1.0, 0.0, 0.0))
	_expect(GoreScript.decal_count() >= 3, "rastro genera decals")
	GoreScript.create_directional_splatter(parent, Vector3.ZERO, Vector3.FORWARD, 40.0)
	_expect(GoreScript.decal_count() >= 3, "salpicadura sin romper decals")
	var puddle := GoreScript.create_puddle(parent, Vector3(0.0, 0.0, 0.0), Vector3.UP, 0.3)
	_expect(puddle != null and puddle.name == "BloodPuddle", "charco creado")
	_expect(GoreScript.puddle_count() == 1, "un charco")
	var old_scale: float = puddle.get_meta("diameter")
	GoreScript.update(1.0)
	_expect(float(puddle.get_meta("diameter")) > old_scale, "charco crece con update")
	GoreScript.clear()
	await process_frame
	_expect(GoreScript.decal_count() == 0, "clear limpia decals")
	_expect(GoreScript.puddle_count() == 0, "clear limpia charcos")
	_expect(GoreScript.damage_mask_count() == 0, "clear limpia mascaras")
	parent.free()

	_case = "desmembramiento simple"
	GoreScript.apply_gore_level(GoreScript.GoreLevel.NORMAL)
	var npc := Node3D.new()
	npc.name = "NPC"
	root.add_child(npc)
	var skeleton := Skeleton3D.new()
	skeleton.name = "Skeleton3D"
	npc.add_child(skeleton)
	skeleton.add_bone("UpperArm")
	skeleton.add_bone("LowerArm")
	skeleton.set_bone_parent(1, 0)
	skeleton.set_bone_pose_position(0, Vector3(0.0, 1.0, 0.0))
	skeleton.set_bone_pose_position(1, Vector3(0.0, 1.4, 0.0))
	var result: Dictionary = GoreScript.dismember_limb(
		npc, 0, skeleton, Vector3(0.0, 1.0, 0.0), Vector3.RIGHT
	)
	_expect(str(result.get("bone_name", "")) == "UpperArm", "hueso correcto")
	_expect(is_instance_valid(result.get("stump_cap", null)), "capa de muñon valida")
	_expect(is_instance_valid(result.get("detached_limb", null)), "miembro separado valido")
	_expect(is_instance_valid(result.get("bleed_node", null)), "sangrado de muñon valido")
	_expect(GoreScript.part_count() >= 1, "parte registrada")
	_expect(GoreScript.stump_bleed_count() == 1, "un sangrado activo")
	_expect((result.get("joints", []) as Array).size() == 1, "un PinJoint3D con hueso hijo")
	var changes: Dictionary = result.get("npc_changes", {})
	_expect(bool(changes.get("drops_weapon", false)), "consecuencia drops_weapon")
	_expect(not bool(changes.get("can_aim", true)), "consecuencia can_aim=false")
	_expect(npc.get_node_or_null("StumpCap") != null, "StumpCap bajo el padre")
	_expect(npc.get_node_or_null("StumpBleed") != null, "StumpBleed bajo el padre")
	_expect(GoreScript.dismember_limb(npc, 99, skeleton, Vector3.ZERO, Vector3.UP).is_empty(), "hueso invalido rechazado")

	var limb = result.get("detached_limb", null)
	for joint in (result.get("joints", []) as Array):
		if is_instance_valid(joint) and joint.get_parent() != null:
			joint.get_parent().free()
	if is_instance_valid(limb):
		limb.free()
	GoreScript.update(0.1)
	_expect(GoreScript.part_count() == 0, "referencias a miembros liberados podadas")
	GoreScript.update(GoreScript.STUMP_BLEED_TIME + 0.1)
	_expect(GoreScript.stump_bleed_count() == 0, "sangrado expirado y liberado")
	GoreScript.clear()
	await process_frame
	npc.free()

	_case = "splatter de pantalla sin viewport"
	GoreScript.set_screen_root(null)
	GoreScript.add_screen_splatter(0.5)
	_expect(GoreScript.screen_splatter_count() == 0, "sin splatter sin viewport")
	GoreScript.set_screen_root(root)
	GoreScript.add_screen_splatter(0.5)
	_expect(GoreScript.screen_splatter_count() == 1, "splatter creado con viewport")
	for i in range(GoreScript.MAX_SCREEN_SPLATTERS + 2):
		GoreScript.add_screen_splatter(0.4)
	_expect(GoreScript.screen_splatter_count() <= GoreScript.MAX_SCREEN_SPLATTERS, "tope de splatters respetado")
	GoreScript.clear()
	_expect(GoreScript.screen_splatter_count() == 0, "clear limpia splatters")
	GoreScript.set_screen_root(null)

	_case = "limites personalizados y padres nulos"
	GoreScript.apply_gore_level(GoreScript.GoreLevel.NORMAL)
	DecalsScript.set_limits(1, 1, 1, 0)
	var small := Node3D.new()
	root.add_child(small)
	for i in range(3):
		GoreScript.create_bullet_wound(small, Vector3(float(i), 0.0, 0.0), Vector3.UP)
		GoreScript.create_puddle(small, Vector3(float(i), 0.0, 0.0), Vector3.UP, 0.2)
	_expect(GoreScript.decal_count() <= 1, "reciclaje de decals por limite")
	_expect(GoreScript.puddle_count() <= 1, "reciclaje de charcos por limite")
	GoreScript.clear()
	small.free()
	_expect(GoreScript.create_bullet_wound(null, Vector3.ZERO, Vector3.UP).is_empty(), "herida con parent nulo")
	_expect(GoreScript.dismember_limb(null, 0, null, Vector3.ZERO, Vector3.UP).is_empty(), "dismember con parent nulo")
	_expect(DecalsScript.create_puddle(null, Vector3.ZERO, Vector3.UP, 0.2) == null, "charco con parent nulo")

	_case = "capas hueso, chorro y exit wound"
	GoreScript.clear()
	GoreScript.apply_gore_level(GoreScript.GoreLevel.NORMAL)
	var bone_inner: Color = DecalsScript.layer_color(1, 2, 0.9)
	var bone_outer: Color = DecalsScript.layer_color(0, 2, 0.9)
	_expect(bone_inner.g > 0.5 and bone_outer.g < 0.1, "hueso expuesto: centro claro, anillo rojo")
	_expect(DecalsScript.DamageLayer.BONE == 2, "capa BONE existe")
	var body := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(0.3, 1.0, 1.0)
	shape.shape = box
	body.add_child(shape)
	root.add_child(body)
	var spray = GoreScript.blood_spray(body, Vector3(0.15, 0, 0), Vector3.RIGHT)
	_expect(spray is GPUParticles3D and spray.lifetime == 0.4 and spray.one_shot, "blood_spray GPUParticles3D 0.4s")
	await physics_frame
	await physics_frame
	var exit_w: Dictionary = BulletImpact._try_exit_wound(body, Vector3(0.15, 0, 0), Vector3.RIGHT)
	_expect(not exit_w.is_empty(), "exit wound en cuerpo fino")
	if not exit_w.is_empty():
		_expect(absf(exit_w["position"].x + 0.15) < 0.01, "exit wound en lado opuesto")
	box.size = Vector3(1.0, 1.0, 1.0)
	await physics_frame
	await physics_frame
	_expect(BulletImpact._try_exit_wound(body, Vector3(0.5, 0, 0), Vector3.RIGHT).is_empty(), "sin exit wound en cuerpo grueso")
	GoreScript.clear()
	body.free()

	_case = "cuchillo: corte de malla y desmembrado"
	GoreScript.clear()
	GoreScript.initialize()
	var target := Node3D.new()
	target.add_to_group("sliceable")
	root.add_child(target)
	var limb_mesh := MeshInstance3D.new()
	limb_mesh.mesh = BoxMesh.new()
	target.add_child(limb_mesh)
	var piece := GoreScript.slice_mesh_instance(limb_mesh, Vector3.ZERO, Vector3.RIGHT)
	_expect(is_instance_valid(piece), "slice devuelve pieza suelta")
	_expect(limb_mesh.mesh.get_aabb().end.x < 0.05, "la malla original queda en el lado -normal")
	if is_instance_valid(piece):
		_expect(piece.get_node("MeshInstance3D").mesh.get_aabb().position.x > -0.05, "la pieza queda en el lado +normal")
	var knife: Node3D = (load("res://weapons/knife.tscn") as PackedScene).instantiate()
	root.add_child(knife)
	_expect(knife.cut(target, Vector3.ZERO, Vector3(0.5, 0, 0)).is_empty(), "golpe lento no corta")
	var npc_skel := Skeleton3D.new()
	target.add_child(npc_skel)
	for bone_name in ["Spine", "LeftForeArm", "LeftLeg"]:
		npc_skel.add_bone(bone_name)
	npc_skel.set_bone_pose_position(1, Vector3(0.5, 1.2, 0))
	npc_skel.set_bone_pose_position(2, Vector3(0.1, 0.4, 0))
	_expect(knife.pick_limb_bone(npc_skel, Vector3(0.45, 1.2, 0)) == 1, "hueso de brazo mas cercano")
	_expect(knife.pick_limb_bone(npc_skel, Vector3(0, 1.5, 0)) == 1, "ignora columna aunque este cerca")
	var cut_result: Dictionary = knife.cut(target, Vector3(0.1, 0.4, 0), Vector3(0, 0, -6))
	_expect(bool(cut_result.get("dismembered", false)), "golpe rapido en pierna desmiembra")
	_expect(npc_skel.get_bone_pose_scale(2).x < 0.01, "hueso cortado oculto (escala ~0)")
	knife.free()
	GoreScript.clear()
	target.free()

	_case = "cierre"
	GoreScript.shutdown()
	_expect(GoreScript.damage_mask_count() == 0, "shutdown limpia mascaras")
	_expect(_checks > 0, "se registraron aserciones")
