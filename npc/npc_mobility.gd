class_name NpcMobility
extends RefCounted

const LEG_INJURED: float = 30.0
const LIMP_FACTOR: float = 0.4
const CRAWL_SPEED: float = 0.4


static func mobility_for(leg_left_damage: float, leg_right_damage: float) -> Dictionary:
	var l: bool = leg_left_damage >= LEG_INJURED
	var r: bool = leg_right_damage >= LEG_INJURED
	if l and r:
		return {"speed_factor": 0.0, "state": "crawl"}
	if l or r:
		return {"speed_factor": LIMP_FACTOR, "state": "limp"}
	return {"speed_factor": 1.0, "state": "walk"}
