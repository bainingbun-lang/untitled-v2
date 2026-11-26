extends RefCounted

# Histeresis: pulsar firme (press_at) para disparar, soltar casi del todo (release_at) para rearmar.
static func next_state(pressed: bool, value: float, press_at: float = 0.75, release_at: float = 0.25) -> bool:
	if value >= press_at:
		return true
	if value <= release_at:
		return false
	return pressed
