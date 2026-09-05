extends RefCounted

const DELAY := 5.0
const RATE := 2.0
var cooldown := 0.0
var fraction := 0.0

func reset() -> void:
	cooldown = DELAY
	fraction = 0.0

func tick(delta: float, health: int, alive: bool) -> int:
	if not alive or health <= 0 or health >= 100:
		fraction = 0.0
		return health
	var elapsed := maxf(delta, 0.0)
	var waiting := minf(cooldown, elapsed)
	cooldown -= waiting
	elapsed -= waiting
	fraction += elapsed * RATE
	var points := int(floor(fraction + 0.000001))
	fraction = maxf(0.0, fraction - points)
	return mini(100, health + points)
