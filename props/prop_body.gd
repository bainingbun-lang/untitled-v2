class_name PropBody
extends XRToolsPickable

## Prop agarrable que suena al chocar (según la velocidad del golpe).
const Sfx_ := preload("res://audio/sfx.gd")
const MIN_SPEED := 1.5
const COOLDOWN_MSEC := 150

## Material del prop: "wood", "metal" o "soft"; decide el sonido del choque.
@export var surface := "wood"
var prop_id := ""
var _last_msec := 0
var _speed := 0.0


func _ready() -> void:
	super()
	contact_monitor = true
	max_contacts_reported = 4
	body_entered.connect(_on_hit)
	grabbed.connect(_on_grabbed)


## Vibración al agarrar proporcional a la masa (15 kg o más = máxima).
func _on_grabbed(_pickable: Variant, _by: Variant) -> void:
	var c := get_picked_up_by_controller()
	if c != null:
		c.trigger_haptic_pulse("haptic", 0.0, clampf(mass / 15.0, 0.15, 1.0), 0.12, 0.0)


## body_entered llega ya con la velocidad frenada por el choque; se usa la del paso anterior.
func _physics_process(_delta: float) -> void:
	_speed = maxf(linear_velocity.length(), _speed * 0.8)


func _on_hit(_other: Node) -> void:
	var now := Time.get_ticks_msec()
	if now - _last_msec < COOLDOWN_MSEC or _speed < MIN_SPEED:
		return
	_last_msec = now
	var snd: AudioStream = Sfx_.metal() if surface == "metal" else (Sfx_.soft() if surface == "soft" else Sfx_.wood())
	Sfx_.play_at(self, snd, global_position)
