class_name DamageUV
extends RefCounted


static func uv_at_point(mesh_instance: MeshInstance3D, world_point: Vector3) -> Vector2:
	var none := Vector2(-1, -1)
	if mesh_instance == null or not mesh_instance.is_inside_tree() or mesh_instance.mesh == null or mesh_instance.mesh.get_surface_count() == 0:
		return none
	var arrays := mesh_instance.mesh.surface_get_arrays(0)
	var verts = arrays[Mesh.ARRAY_VERTEX]
	var uvs = arrays[Mesh.ARRAY_TEX_UV]
	if verts == null or uvs == null or (uvs as PackedVector2Array).is_empty():
		return none
	var idx = arrays[Mesh.ARRAY_INDEX]
	var p := mesh_instance.global_transform.affine_inverse() * world_point
	var n: int = (idx as PackedInt32Array).size() if idx != null else (verts as PackedVector3Array).size()
	var best := INF
	var best_uv := none
	# shortcut: brute force over all triangles, add a BVH/cache if NPC meshes get heavy
	for t in range(0, n - 2, 3):
		var i0: int = idx[t] if idx != null else t
		var i1: int = idx[t + 1] if idx != null else t + 1
		var i2: int = idx[t + 2] if idx != null else t + 2
		var a: Vector3 = verts[i0]
		var b: Vector3 = verts[i1]
		var c: Vector3 = verts[i2]
		var q := _closest_on_tri(p, a, b, c)
		var d := p.distance_squared_to(q)
		if d < best:
			best = d
			var w := _bary(q, a, b, c)
			best_uv = uvs[i0] * w.x + uvs[i1] * w.y + uvs[i2] * w.z
	return best_uv


static func _closest_on_tri(p: Vector3, a: Vector3, b: Vector3, c: Vector3) -> Vector3:
	var n := (b - a).cross(c - a)
	if n.length_squared() < 1e-12:
		return a
	var pr := Plane(n.normalized(), a).project(p)
	var w := _bary(pr, a, b, c)
	if w.x >= 0.0 and w.y >= 0.0 and w.z >= 0.0:
		return pr
	var best := a
	var bd := INF
	for pair in [[a, b], [b, c], [c, a]]:
		var q := Geometry3D.get_closest_point_to_segment(p, pair[0], pair[1])
		var d := p.distance_squared_to(q)
		if d < bd:
			bd = d
			best = q
	return best


static func _bary(p: Vector3, a: Vector3, b: Vector3, c: Vector3) -> Vector3:
	var v0 := b - a
	var v1 := c - a
	var v2 := p - a
	var d00 := v0.dot(v0)
	var d01 := v0.dot(v1)
	var d11 := v1.dot(v1)
	var d20 := v2.dot(v0)
	var d21 := v2.dot(v1)
	var den := d00 * d11 - d01 * d01
	if absf(den) < 1e-12:
		return Vector3(1, 0, 0)
	var v := (d11 * d20 - d01 * d21) / den
	var w := (d00 * d21 - d01 * d20) / den
	return Vector3(1.0 - v - w, v, w)
