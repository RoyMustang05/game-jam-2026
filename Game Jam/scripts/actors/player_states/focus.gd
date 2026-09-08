extends "res://scripts/systems/state.gd"
## Airborne stillness. Milo hangs motionless and the world clock stops with him,
## which is the game's whole thesis expressed as a single verb.
##
## The frame ends here: no gravity, no physics step, no post-move bookkeeping.
## Velocity is stashed on entry and handed back on exit, so releasing focus
## resumes the exact arc that was interrupted rather than dropping from rest.


func pose() -> String:
	return "focus"


func enter(_previous: StringName, _context: Variant = null) -> void:
	host._focus_velocity = host.velocity
	host.focusing = true
	host.wall_clinging = false


func exit(_next: StringName) -> void:
	host.velocity = host._focus_velocity
	host.focusing = false


func decide(delta: float, frame: Dictionary) -> bool:
	if not host.wants_focus(frame):
		host.change_motion(&"normal", frame)
		return host.motion.current.decide(delta, frame)
	host.velocity = Vector2.ZERO
	host.active_motion = false
	return true
