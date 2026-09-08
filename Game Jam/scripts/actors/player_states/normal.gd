extends "res://scripts/systems/state.gd"
## Ordinary movement: run, gravity, wall grip and the jump ladder.
##
## This state stays big on purpose. Gravity, the wall hold and the four jump
## branches read and write the same buffers - coyote time, the jump buffer, the
## finite grip, the airborne jump - and splitting them further would only move
## the coupling into a shared blob without making any of it easier to follow.
##
## It is also the only state that can start a dash, a strike or a focus, because
## each of those requires not already being in one.

## Wall grip engages once the fall is no longer a strong upward launch.
const CLING_ENTRY_SPEED: float = -35.0
## Sliding becomes a full hold after this long against the wall.
const CLING_HOLD_TIME: float = 0.20
const CLING_SLIDE_SPEED: float = 24.0
## Releasing jump early cuts the rise to this speed.
const JUMP_CUT_SPEED: float = -82.0


func pose() -> String:
	if host.wall_clinging:
		return "wall_cling" if absf(host.velocity.y) < 0.01 else "wall_slide"
	if host._special_left > 0.0:
		return host._special_state
	if not host.is_on_floor():
		return "rise" if host.velocity.y < 0.0 else "fall"
	if host._spawn_left > 0.06 and not host.active_motion:
		return "respawn"
	if absf(host.velocity.x) > 2.0:
		return "run"
	return "idle"


func decide(delta: float, frame: Dictionary) -> bool:
	if host.wants_focus(frame):
		host.change_motion(&"focus", frame)
		return host.motion.current.decide(delta, frame)
	if _wants_dash(frame):
		return _begin_dash(delta, frame)
	_horizontal(delta, frame)
	_gravity_and_wall(delta, frame)
	_jump_ladder(frame)
	return false


func _wants_dash(frame: Dictionary) -> bool:
	return bool(frame.dash_pressed) \
		and host.dash_charges > 0 \
		and host._dash_cooldown <= 0.0 \
		and host.dash_left <= 0.0 \
		and not host.striking


## Spend the charge, then hand the frame to whichever committed move this is.
## The new state runs in this same frame, exactly as the flat version fell
## straight through into its movement branch.
func _begin_dash(delta: float, frame: Dictionary) -> bool:
	host.dash_charges -= 1
	host.dash_left = host.DASH_DURATION
	host._dash_cooldown = host.DASH_COOLDOWN
	host.wall_clinging = false
	host._wall_hold_time = 0.0
	host.effects.begin_trail()
	frame.dash_started = true
	var downward: bool = float(frame.vertical) > 0.5 and not bool(frame.was_grounded)
	host.change_motion(&"strike" if downward else &"dash", frame)
	return host.motion.current.decide(delta, frame)


func _horizontal(delta: float, frame: Dictionary) -> void:
	var axis: float = frame.axis
	# A wall jump locks steering briefly so the launch cannot be cancelled.
	if host._wall_recovery <= 0.0:
		var rate: float = host.ACCELERATION if absf(axis) > 0.01 else host.FRICTION
		host.velocity.x = move_toward(host.velocity.x, axis * host.RUN_SPEED, rate * delta)
	if absf(axis) <= 0.01 and absf(host.velocity.x) < 1.0:
		host.velocity.x = 0.0


func _gravity_and_wall(delta: float, frame: Dictionary) -> void:
	host.velocity.y = minf(host.velocity.y + host.GRAVITY * delta, host.FALL_LIMIT)
	host.wall_clinging = false
	if not bool(frame.wall_available) or host.velocity.y < CLING_ENTRY_SPEED:
		host._wall_hold_time = 0.0
		return
	host._wall_hold_time += delta
	host.wall_clinging = true
	if host._wall_hold_time >= CLING_HOLD_TIME:
		# A settled hold is free, so planning on a wall costs no grip.
		host.velocity.y = 0.0
	else:
		host.velocity.y = minf(host.velocity.y, CLING_SLIDE_SPEED)
		host.wall_cling_budget = maxf(0.0, host.wall_cling_budget - delta)


## Ground jump, wall jump, airborne jump, then the variable-height cut. Order is
## the priority: a buffered press near the floor is always a ground jump.
func _jump_ladder(frame: Dictionary) -> void:
	var buffered: bool = host._jump_buffer_left > 0.0
	if buffered and host._coyote_left > 0.0:
		_ground_jump(frame)
	elif buffered and bool(frame.wall_available):
		_wall_jump(frame)
	elif buffered and host.extra_jumps > 0 and not bool(frame.was_grounded):
		_air_jump(frame)
	elif not bool(frame.jump_held) and host.velocity.y < JUMP_CUT_SPEED and host._jump_cut_lock <= 0.0:
		host.velocity.y = JUMP_CUT_SPEED


func _ground_jump(frame: Dictionary) -> void:
	host.velocity.y = host.JUMP_SPEED
	host._jump_buffer_left = 0.0
	host._coyote_left = 0.0
	frame.jumped = true
	frame.action = "jump"
	host._special("takeoff", 0.07)
	host._burst(Vector2.DOWN, host.CYAN, 5, 20.0)


func _wall_jump(frame: Dictionary) -> void:
	var normal_x: float = frame.normal_x
	host.velocity = Vector2(normal_x * host.WALL_JUMP_SPEED.x, host.WALL_JUMP_SPEED.y)
	host.facing = 1 if normal_x > 0.0 else -1
	host._wall_recovery = 0.12
	host._jump_cut_lock = 0.10
	host._wall_hold_time = 0.0
	host.wall_clinging = false
	host.wall_cling_budget = maxf(0.0, host.wall_cling_budget - 0.22)
	host._last_wall_jump_normal = normal_x
	# Only the first wall jump of a flight refills the airborne jump, so a single
	# wall cannot be climbed forever.
	if not host._wall_jump_refilled:
		host.extra_jumps = 1
		host._wall_jump_refilled = true
	host._jump_buffer_left = 0.0
	host._coyote_left = 0.0
	frame.jumped = true
	frame.action = "wall_jump"
	host._special("wall_jump", 0.13)
	host._burst(Vector2(normal_x, -0.6), host.CYAN, 10, 42.0)


func _air_jump(frame: Dictionary) -> void:
	host.extra_jumps -= 1
	host.velocity.y = host.DOUBLE_JUMP_SPEED
	host._jump_buffer_left = 0.0
	host._jump_cut_lock = 0.04
	host._wall_hold_time = 0.0
	host.wall_clinging = false
	frame.jumped = true
	frame.action = "double_jump"
	host._special("double_jump", 0.14)
	host._burst(Vector2.ZERO, host.MAGENTA, 12, 38.0)
