extends "res://scripts/systems/state.gd"
## A committed directional burst. Steering is spent at the moment of entry, so
## the dash cannot be curved once it is out - that is what makes it a decision
## rather than a speed boost.
##
## It also opens the phase window that lets Milo pass through a phase barrier,
## and costs two seconds of the level clock, charged by the director.


func pose() -> String:
	# Grounded and level reads as a ground dash; anything else smears in air.
	return "dash" if host.is_on_floor() and absf(host._dash_direction.y) < 0.1 else "air_dash"


func enter(_previous: StringName, context: Variant = null) -> void:
	host._dash_direction = Vector2(context.axis, context.vertical).normalized()
	if host._dash_direction == Vector2.ZERO:
		host._dash_direction = Vector2(float(host.facing), 0.0)
	host._phase_left = host.DASH_DURATION
	host.velocity = host._dash_direction * host.DASH_SPEED
	context.action = "dash"
	host._burst(-host._dash_direction, host.CYAN, 8, 45.0)


func decide(delta: float, _frame: Dictionary) -> bool:
	host.velocity = host._dash_direction * host.DASH_SPEED
	host.dash_left = maxf(0.0, host.dash_left - delta)
	# Leaving within the frame, so the pose resolved after move_and_slide is
	# already the ordinary one rather than a stale smear.
	if host.dash_left <= 0.0:
		host.rebind_motion(&"normal")
	return false
