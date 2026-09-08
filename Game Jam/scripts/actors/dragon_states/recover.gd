extends "res://scripts/systems/state.gd"
## The opening. The head drops, the weak point exposes, and the recovery cell
## can be collected once.
##
## The only window where Milo can deal damage, and the only one where standing
## still costs him nothing - so it is also where he plans the next cycle.


func duration() -> float:
	return 4.3 if host.phase == 1 else 3.9


func next_id() -> StringName:
	return &"prepare"


func enter(_previous: StringName, _context: Variant = null) -> void:
	host.projectiles.clear()
	host.hit_this_opening = false
	host.recharge_available = true


func exit(_next: StringName) -> void:
	host.cycle += 1
	host.attack = host.cycle % 3
	host.recharge_available = false
