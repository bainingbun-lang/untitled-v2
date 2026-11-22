extends SceneTree

const SandboxScene = preload("res://sandbox/sandbox.tscn")
const GoreSystem = preload("res://gore/gore_system.gd")

var sandbox_instance: Node = null
var frame_count: int = 0
var instantiation_ok: bool = true
var error_message: String = ""
var checking_done: bool = false

func _init() -> void:
	print("SANDBOX CHECK: Starting...")

func _ready() -> void:
	_load_sandbox()

func _load_sandbox() -> void:
	var instance = SandboxScene.instantiate()
	if instance == null:
		instantiation_ok = false
		error_message = "Failed to instantiate sandbox scene"
		_finish()
		return
	
	sandbox_instance = instance
	root.add_child(instance)
	print("SANDBOX CHECK: Sandbox instantiated, waiting 60 frames...")

func _process(_delta: float) -> bool:
	if checking_done or sandbox_instance == null:
		return false
	
	frame_count += 1
	if frame_count >= 60:
		checking_done = true
		_check_pieces()
		_finish()
	return false

func _check_pieces() -> void:
	print("=== SANDBOX CHECK RESULTS ===")
	
	var arma: String = "no"
	var npc_count: int = 0
	var casa: String = "no"
	var gore: String = "no"
	
	if sandbox_instance != null and is_instance_valid(sandbox_instance):
		var arma_nodes = get_nodes_in_group("weapon_pickup")
		if arma_nodes.size() == 0:
			arma_nodes = get_nodes_in_group("weapon")
		if arma_nodes.size() == 0:
			var vr_weapon_hand = sandbox_instance.find_child("VrWeaponHand", true, false)
			if vr_weapon_hand != null:
				arma_nodes = [vr_weapon_hand]
		if arma_nodes.size() > 0:
			arma = "si"
		
		var npc_nodes = get_nodes_in_group("basic_npc")
		if npc_nodes.size() == 0:
			npc_nodes = get_nodes_in_group("npc")
		if npc_nodes.size() == 0:
			npc_nodes = sandbox_instance.find_children("BasicNpc", "CharacterBody3D", true, false)
		npc_count = npc_nodes.size()
		
		var house_node = sandbox_instance.find_child("HouseTwoStory", true, false)
		if house_node != null:
			casa = "si"
		else:
			var children = sandbox_instance.get_children()
			for child in children:
				if child.name.begins_with("House") or child.name.begins_with("Floor") or child.name.begins_with("Wall"):
					casa = "si"
					break
		
		if GoreSystem.gore_enabled():
			gore = "si"
	
	print("ARMA: " + arma)
	print("NPC: " + str(npc_count))
	print("CASA: " + casa)
	print("GORE: " + gore)
	print("=============================")

func _finish() -> void:
	if instantiation_ok:
		print("SANDBOX OK")
	else:
		print("SANDBOX ERROR: " + error_message)
	quit()