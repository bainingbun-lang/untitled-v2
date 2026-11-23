extends SceneTree

const GoreSystem = preload("res://gore/gore_system.gd")
const WoundDecals = preload("res://gore/wound_decals.gd")
const GoreTextures = preload("res://gore/gore_textures.gd")
const SHEET := "/data/data/com.termux/files/usr/tmp/vrsim/manchas.png"
var _fails := 0


func _expect(ok: bool, msg: String) -> void:
	print(("PASS: " if ok else "FAIL: ") + msg)
	if not ok:
		_fails += 1


func _init() -> void:
	await process_frame
	GoreSystem.set_gore_level(1)
	GoreTextures._ensure()
	var splats: Array = GoreTextures._tex["splat"]
	var drops: Array = GoreTextures._tex["drop"]
	_expect(splats.size() >= 5 and drops.size() >= 3, "hay manchas procedurales (splat %d, drop %d)" % [splats.size(), drops.size()])
	var picks: Array = splats.slice(splats.size() - 5) + drops.slice(drops.size() - 3)
	var sheet := Image.create(96 * picks.size(), 96, false, Image.FORMAT_RGB8)
	sheet.fill(Color(0.35, 0.35, 0.37))
	for i in picks.size():
		var img: Image = (picks[i] as Texture2D).get_image()
		img.decompress()
		for y in img.get_height():
			for x in img.get_width():
				var a := img.get_pixel(x, y).a
				sheet.set_pixel(i * 96 + x, y, Color(0.35, 0.35, 0.37).lerp(Color(0.5, 0.01, 0.015), a))
	DirAccess.make_dir_recursive_absolute(SHEET.get_base_dir())
	sheet.save_png(SHEET)

	var scene := Node3D.new()
	root.add_child(scene)
	current_scene = scene
	var wall := StaticBody3D.new()
	scene.add_child(wall)
	WoundDecals.add_run(wall, Vector3(0, 2.0, 0.1), Vector3(0, 0, 1), 0.4)
	var runs := scene.find_children("SurfaceDecal_trail", "Decal", true, false)
	_expect(runs.size() == 1, "una pared genera un churrete")
	var d: Decal = runs[0]
	var z0 := d.size.z
	var y0 := d.global_position.y
	await create_timer(6.0).timeout
	_expect(d.size.z > z0 * 1.5, "el churrete se alarga (%.2f -> %.2f)" % [z0, d.size.z])
	_expect(d.global_position.y < y0 - 0.05, "el churrete baja (y %.2f -> %.2f)" % [y0, d.global_position.y])
	var before := scene.find_children("SurfaceDecal_trail", "Decal", true, false).size()
	WoundDecals.add_run(wall, Vector3(0, 0.2, 0.1), Vector3(0, 1, 0), 0.4)
	_expect(scene.find_children("SurfaceDecal_trail", "Decal", true, false).size() == before, "en el suelo no hay churretes")
	print("RESULTADO: %s (%d fallos)" % ["OK" if _fails == 0 else "FALLO", _fails])
	quit(0 if _fails == 0 else 1)
