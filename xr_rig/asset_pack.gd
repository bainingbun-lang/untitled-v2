class_name AssetPack
extends RefCounted

const HANDS_ZIP := "res://assets/packs/hands_lowpoly.zip"
const CACHE_DIR := "user://packs/"

static var _textures: Dictionary = {}
static var _hand_material: ORMMaterial3D


static func _open(zip_path: String) -> ZIPReader:
	var zr := ZIPReader.new()
	if zr.open(zip_path) == OK:
		return zr
	var bytes := FileAccess.get_file_as_bytes(zip_path)
	if bytes.is_empty():
		return null
	DirAccess.make_dir_recursive_absolute(CACHE_DIR)
	var cache := CACHE_DIR + zip_path.get_file()
	var f := FileAccess.open(cache, FileAccess.WRITE)
	if f == null:
		return null
	f.store_buffer(bytes)
	f.close()
	return zr if zr.open(cache) == OK else null


static func load_texture(zip_path: String, file_name: String) -> ImageTexture:
	var key := zip_path + "::" + file_name
	if _textures.has(key):
		return _textures[key]
	var zr := _open(zip_path)
	if zr == null:
		push_warning("AssetPack: no se pudo abrir %s" % zip_path)
		return null
	var data := zr.read_file(file_name)
	zr.close()
	var img := Image.new()
	if data.is_empty() or img.load_png_from_buffer(data) != OK:
		push_warning("AssetPack: %s no está en %s" % [file_name, zip_path])
		return null
	var tex := ImageTexture.create_from_image(img)
	_textures[key] = tex
	return tex


static func get_hand_material() -> ORMMaterial3D:
	if _hand_material == null:
		var albedo := load_texture(HANDS_ZIP, "caucasian_baseColor.png")
		if albedo == null:
			return null
		var m := ORMMaterial3D.new()
		m.albedo_texture = albedo
		m.orm_texture = load_texture(HANDS_ZIP, "hands_occlusionRoughnessMetallic.png")
		_hand_material = m
	return _hand_material


static func apply_hand_material(hand_node: Node) -> int:
	var mat := get_hand_material()
	if mat == null:
		return 0
	var n := 0
	for mi in hand_node.find_children("*", "MeshInstance3D", true, false):
		mi.material_override = mat
		n += 1
	return n
