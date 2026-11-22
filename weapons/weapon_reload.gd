class_name WeaponReload
extends RefCounted

## Manual reload state: magazine in/out, rounds in magazine, round in chamber.
signal reload_action(action_name: String)

var magazine_size: int = 12
var magazine_in: bool = false
var magazine_rounds: int = 0
var chambered: bool = false

func _init(size: int = 12) -> void:
	magazine_size = size

func eject_magazine() -> bool:
	if not magazine_in:
		return false
	magazine_in = false
	magazine_rounds = 0
	reload_action.emit("eject_magazine")
	return true

func insert_magazine(rounds: int = -1) -> bool:
	if magazine_in:
		return false
	magazine_in = true
	magazine_rounds = magazine_size if rounds < 0 else mini(rounds, magazine_size)
	reload_action.emit("insert_magazine")
	return true

## Slide back and release: ejects any chambered round, feeds a new one from the magazine.
func rack_slide() -> void:
	chambered = _feed()
	reload_action.emit("rack_slide")

## Consumes the chambered round; semi-auto cycles the next one in. False means empty click.
func fire() -> bool:
	if not chambered:
		return false
	chambered = _feed()
	return true

func total_rounds() -> int:
	return magazine_rounds + (1 if chambered else 0)

func _feed() -> bool:
	if magazine_in and magazine_rounds > 0:
		magazine_rounds -= 1
		return true
	return false
