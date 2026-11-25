extends SceneTree

const MAPS := [
	"res://maps/downloaded/office/office_map.tscn",
	"res://maps/downloaded/school/school_map.tscn",
	"res://maps/downloaded/scifi/facility_map.tscn",
	"res://maps/downloaded/house_model/house_map.tscn",
]


func _init() -> void:
	await process_frame
	for p in MAPS:
		if not ResourceLoader.exists(p):
			print("NO EXISTE ", p)
			continue
		var t0 := Time.get_ticks_msec()
		var ps := load(p) as PackedScene
		var t1 := Time.get_ticks_msec()
		var n := ps.instantiate()
		var t2 := Time.get_ticks_msec()
		root.add_child(n)
		await process_frame
		await process_frame
		var t3 := Time.get_ticks_msec()
		var nodes := _count(n)
		var meshes := n.find_children("*", "MeshInstance3D", true, false).size()
		var cols := n.find_children("*", "CollisionShape3D", true, false).size()
		var lights := n.find_children("*", "Light3D", true, false).size()
		print("MAP %s load=%dms inst=%dms ready=%dms nodos=%d mallas=%d colisiones=%d luces=%d" % [p.get_file(), t1 - t0, t2 - t1, t3 - t2, nodes, meshes, cols, lights])
		n.queue_free()
		await process_frame
	quit()


func _count(n: Node) -> int:
	var c := 1
	for ch in n.get_children():
		c += _count(ch)
	return c
