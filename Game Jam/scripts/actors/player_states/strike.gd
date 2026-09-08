extends "res://scripts/systems/state.gd"
## The downward strike: down plus dash while airborne.
##
## Unlike a dash it grants no phase window, so it cannot be used to cheat a
## barrier. It breaks fragile floors, bounces off marked spikes and pads, and
## the contact frame is deliberately held one step longer than the movement so
## the pad and barrier resolvers can see it after step() returns.


func pose() -> String:
	return "strike"


func enter(_previous: StringName, context: Variant = null) -> void:
	host.striking = true
	host._strike_left = host.STRIKE_DURATION
	# Explicitly no phase window: a strike is committal, not evasive.
	host._phase_left = 0.0
	host._dash_direction = Vector2.DOWN
	host.velocity = Vector2(0.0, host.STRIKE_SPEED)
	context.action = "strike"
	host._burst(Vector2.UP, host.MAGENTA, 8, 35.0)


func decide(delta: float, _frame: Dictionary) -> bool:
	host.velocity = Vector2(0.0, host.STRIKE_SPEED)
	host._strike_left = maxf(0.0, host._strike_left - delta)
	host.dash_left = maxf(0.0, host.dash_left - delta)
	if host._strike_left <= 0.0:
		host.striking = false
		host.rebind_motion(&"normal")
	return false
