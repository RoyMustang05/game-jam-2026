extends CharacterBody2D
## Normal physics for Milo; the game advances its separate clock from step().
const RUN_SPEED: float = 105.0
const ACCELERATION: float = 1300.0
const FRICTION: float = 1800.0
const GRAVITY: float = 680.0
const FALL_LIMIT: float = 330.0
const JUMP_SPEED: float = -230.0
const DOUBLE_JUMP_SPEED: float = -220.0
const WALL_JUMP_SPEED: Vector2 = Vector2(155.0, -242.0)
const COYOTE_TIME: float = 0.10
const JUMP_BUFFER_TIME: float = 0.12
const DASH_SPEED: float = 245.0
const DASH_DURATION: float = 0.14
const DASH_COOLDOWN: float = 0.18
const STRIKE_SPEED: float = 320.0
const STRIKE_DURATION: float = 0.5
const WHITE: Color = Color("f8f8f2")
const CYAN: Color = Color("61e7ff")
const MAGENTA: Color = Color("ff5fcb")
const RED: Color = Color("ff5a67")
const INK: Color = Color("0d1013")

var melee_pose: float = 0.0
var dash_charges: int = 2
var facing: int = 1
var dash_left: float = 0.0
var active_motion: bool = false
var striking: bool = false
var focusing: bool = false
var wall_clinging: bool = false
var wall_cling_budget: float = 1.0
var extra_jumps: int = 1
var animation_state: String = "respawn"
var _coyote_left: float = 0.0
var _jump_buffer_left: float = 0.0
var _dash_cooldown: float = 0.0
var _dash_direction: Vector2 = Vector2.RIGHT
var _phase_left: float = 0.0
var _strike_left: float = 0.0
var _strike_landed: bool = false
var _wall_hold_time: float = 0.0
var _wall_recovery: float = 0.0
var _last_wall_jump_normal: float = 0.0
var _wall_jump_refilled: bool = false
var _jump_cut_lock: float = 0.0
var _focus_velocity: Vector2 = Vector2.ZERO
var _motion_clock: float = 0.0
var _visual_clock: float = 0.0
var _trail_clock: float = 0.0
var _last_axis: float = 0.0
var _special_state: String = ""
var _special_left: float = 0.0
var _spawn_left: float = 0.25
var _impact_left: float = 0.0
var _hit_left: float = 0.0
var _death_left: float = 0.0
var _finished: bool = false
var _dead: bool = false
var _pending_action: String = ""
var _trail: Array[Dictionary] = []
var _particles: Array[Dictionary] = []


func _ready() -> void:
	set_physics_process(false)
	# Only Milo's breathing, impact pose recovery and respawn use _process.
	# World particles/afterimages receive active time exclusively in step().
	set_process(true)
	collision_layer = 2
	collision_mask = 1
	up_direction = Vector2.UP
	floor_snap_length = 2.0
	safe_margin = 0.01
	floor_stop_on_slope = true
	platform_floor_layers = 0
	platform_wall_layers = 0
	platform_on_leave = CharacterBody2D.PLATFORM_ON_LEAVE_DO_NOTHING
	var collider: CollisionShape2D = CollisionShape2D.new()
	var rectangle: RectangleShape2D = RectangleShape2D.new()
	rectangle.size = Vector2(8.0, 14.0)
	collider.shape = rectangle
	collider.position = Vector2(0.0, -7.0)
	add_child(collider)
	queue_redraw()


func _process(delta: float) -> void:
	_visual_clock += delta
	_spawn_left = maxf(0.0, _spawn_left - delta)
	_special_left = maxf(0.0, _special_left - delta)
	_hit_left = maxf(0.0, _hit_left - delta)
	if _hit_left <= 0.0:
		_death_left = maxf(0.0, _death_left - delta)
	_resolve_animation()
	queue_redraw()


func reset_at(spawn_position: Vector2) -> void:
	position = spawn_position
	velocity = Vector2.ZERO
	dash_charges = 2
	facing = 1
	dash_left = 0.0
	active_motion = false
	striking = false
	focusing = false
	wall_clinging = false
	wall_cling_budget = 1.0
	extra_jumps = 1
	_coyote_left = 0.0
	_jump_buffer_left = 0.0
	_dash_cooldown = 0.0
	_dash_direction = Vector2.RIGHT
	_phase_left = 0.0
	_strike_left = 0.0
	_strike_landed = false
	_wall_hold_time = 0.0
	_wall_recovery = 0.0
	_last_wall_jump_normal = 0.0
	_wall_jump_refilled = false
	_jump_cut_lock = 0.0
	_focus_velocity = Vector2.ZERO
	_motion_clock = 0.0
	_trail_clock = 0.0
	_last_axis = 0.0
	_special_state = ""
	_special_left = 0.0
	_spawn_left = 0.25
	_impact_left = 0.0
	_hit_left = 0.0
	_death_left = 0.0
	_finished = false
	_dead = false
	_pending_action = ""
	_trail.clear()
	_particles.clear()
	animation_state = "respawn"
	reset_physics_interpolation()
	queue_redraw()


func can_phase() -> bool:
	return _phase_left > 0.0 and not striking and not _dead


func refill_at_anchor() -> void:
	dash_charges = 2
	_spawn_left = 0.20
	_emit_burst(Vector2.UP, CYAN, 12, 40.0)
	queue_redraw()


func bounce() -> void:
	bounce_from_pad(270.0)


func bounce_from_pad(strength: float = 270.0) -> void:
	# A pad resolves after step; this guard prevents repeated overlap launches.
	if not striking:
		return
	striking = false
	_strike_landed = false
	_strike_left = 0.0
	dash_left = 0.0
	_phase_left = 0.0
	velocity.y = -absf(strength)
	velocity.x *= 0.35
	extra_jumps = 1
	focusing = false
	wall_clinging = false
	_jump_cut_lock = 0.16
	_coyote_left = 0.0
	_pending_action = "bounce"
	_special("bounce", 0.15)
	_impact_left = 0.18
	_emit_burst(Vector2.UP, CYAN, 16, 65.0)
	active_motion = true
	queue_redraw()


func play_finish() -> void:
	_finished = true
	velocity = Vector2.ZERO
	dash_left = 0.0
	striking = false
	focusing = false
	wall_clinging = false
	active_motion = false
	animation_state = "goal"
	queue_redraw()


func play_hit() -> void:
	_dead = true
	_hit_left = 0.06
	_death_left = 0.22
	velocity = Vector2.ZERO
	active_motion = false
	animation_state = "hit"
	queue_redraw()


func play_death() -> void:
	play_hit()


func step(delta: float, command: Dictionary = {}) -> Dictionary:
	if _finished or _dead:
		return {"moving": false, "dash_started": false, "jumped": false, "distance": 0.0, "action": "", "landed": false}
	var axis: float = 0.0
	var vertical: float = 0.0
	var jump_pressed: bool = false
	var jump_held: bool = false
	var dash_pressed: bool = false
	var cling_held: bool = true
	var focus_held: bool = false
	if command.is_empty():
		axis = Input.get_axis("move_left", "move_right")
		vertical = Input.get_axis("move_up", "move_down")
		jump_pressed = Input.is_action_just_pressed("jump")
		jump_held = Input.is_action_pressed("jump")
		dash_pressed = Input.is_action_just_pressed("dash")
		focus_held = Input.is_action_pressed("focus")
	else:
		axis = clampf(float(command.get("axis", 0.0)), -1.0, 1.0)
		vertical = clampf(float(command.get("vertical", 0.0)), -1.0, 1.0)
		jump_pressed = bool(command.get("jump", false))
		jump_held = bool(command.get("jump_held", jump_pressed))
		dash_pressed = bool(command.get("dash", false))
		cling_held = bool(command.get("cling", true))
		focus_held = bool(command.get("freeze_air", false))
	if absf(axis) > 0.01 and _wall_recovery <= 0.0:
		facing = 1 if axis > 0.0 else -1
	var was_grounded: bool = is_on_floor()
	var old_velocity: Vector2 = velocity
	var action: String = _pending_action
	_pending_action = ""
	var jumped: bool = action == "bounce"
	var dash_started: bool = false
	_dash_cooldown = maxf(0.0, _dash_cooldown - delta)
	_phase_left = maxf(0.0, _phase_left - delta)
	_wall_recovery = maxf(0.0, _wall_recovery - delta)
	_jump_cut_lock = maxf(0.0, _jump_cut_lock - delta)
	_jump_buffer_left = maxf(0.0, _jump_buffer_left - delta)
	if _strike_landed:
		striking = false
		_strike_landed = false
		_strike_left = 0.0
		dash_left = 0.0
	if was_grounded:
		_coyote_left = COYOTE_TIME
		_reset_air_resources()
	else:
		_coyote_left = maxf(0.0, _coyote_left - delta)
	if jump_pressed:
		_jump_buffer_left = JUMP_BUFFER_TIME
	var normal_x: float = get_wall_normal().x if is_on_wall() else 0.0
	var toward_wall: bool = axis * normal_x < -0.1
	if absf(normal_x) > 0.5 and normal_x * _last_wall_jump_normal < -0.5:
		# Alternating walls refresh grip; repeating one wall spends grip.
		wall_cling_budget = 1.0
		_last_wall_jump_normal = 0.0
	var wall_available: bool = not was_grounded and toward_wall and cling_held and wall_cling_budget > 0.0 and _wall_recovery <= 0.0
	var use_focus: bool = focus_held and not was_grounded and absf(axis) < 0.01 and absf(vertical) < 0.01 and not jump_pressed and not dash_pressed and dash_left <= 0.0 and not striking
	if use_focus:
		if not focusing:
			_focus_velocity = velocity
		focusing = true
		wall_clinging = false
		velocity = Vector2.ZERO
		active_motion = false
		_resolve_animation()
		queue_redraw()
		return {"moving": false, "dash_started": false, "jumped": false, "distance": 0.0, "action": "", "landed": false}
	if focusing:
		velocity = _focus_velocity
		focusing = false
	if dash_pressed and dash_charges > 0 and _dash_cooldown <= 0.0 and dash_left <= 0.0 and not striking:
		dash_charges -= 1
		dash_left = DASH_DURATION
		_dash_cooldown = DASH_COOLDOWN
		dash_started = true
		wall_clinging = false
		_wall_hold_time = 0.0
		_trail_clock = 0.0
		if vertical > 0.5 and not was_grounded:
			striking = true
			_strike_left = STRIKE_DURATION
			_phase_left = 0.0
			_dash_direction = Vector2.DOWN
			velocity = Vector2(0.0, STRIKE_SPEED)
			action = "strike"
			_emit_burst(Vector2.UP, MAGENTA, 8, 35.0)
		else:
			_dash_direction = Vector2(axis, vertical).normalized()
			if _dash_direction == Vector2.ZERO:
				_dash_direction = Vector2(float(facing), 0.0)
			_phase_left = DASH_DURATION
			velocity = _dash_direction * DASH_SPEED
			action = "dash"
			_emit_burst(-_dash_direction, CYAN, 8, 45.0)
	if striking:
		velocity = Vector2(0.0, STRIKE_SPEED)
		_strike_left = maxf(0.0, _strike_left - delta)
		dash_left = maxf(0.0, dash_left - delta)
		if _strike_left <= 0.0:
			striking = false
	elif dash_left > 0.0:
		velocity = _dash_direction * DASH_SPEED
		dash_left = maxf(0.0, dash_left - delta)
	else:
		if _wall_recovery <= 0.0:
			var rate: float = ACCELERATION if absf(axis) > 0.01 else FRICTION
			velocity.x = move_toward(velocity.x, axis * RUN_SPEED, rate * delta)
		if absf(axis) <= 0.01 and absf(velocity.x) < 1.0:
			velocity.x = 0.0
		velocity.y = minf(velocity.y + GRAVITY * delta, FALL_LIMIT)
		wall_clinging = false
		if wall_available and velocity.y >= -35.0:
			_wall_hold_time += delta
			wall_clinging = true
			if _wall_hold_time >= 0.20:
				velocity.y = 0.0
			else:
				velocity.y = minf(velocity.y, 24.0)
				wall_cling_budget = maxf(0.0, wall_cling_budget - delta)
		else:
			_wall_hold_time = 0.0
		if _jump_buffer_left > 0.0 and _coyote_left > 0.0:
			velocity.y = JUMP_SPEED
			_jump_buffer_left = 0.0
			_coyote_left = 0.0
			jumped = true
			action = "jump"
			_special("takeoff", 0.07)
			_emit_burst(Vector2.DOWN, CYAN, 5, 20.0)
		elif _jump_buffer_left > 0.0 and wall_available:
			velocity = Vector2(normal_x * WALL_JUMP_SPEED.x, WALL_JUMP_SPEED.y)
			facing = 1 if normal_x > 0.0 else -1
			_wall_recovery = 0.12
			_jump_cut_lock = 0.10
			_wall_hold_time = 0.0
			wall_clinging = false
			wall_cling_budget = maxf(0.0, wall_cling_budget - 0.22)
			_last_wall_jump_normal = normal_x
			if not _wall_jump_refilled:
				extra_jumps = 1
				_wall_jump_refilled = true
			_jump_buffer_left = 0.0
			_coyote_left = 0.0
			jumped = true
			action = "wall_jump"
			_special("wall_jump", 0.13)
			_emit_burst(Vector2(normal_x, -0.6), CYAN, 10, 42.0)
		elif _jump_buffer_left > 0.0 and extra_jumps > 0 and not was_grounded:
			extra_jumps -= 1
			velocity.y = DOUBLE_JUMP_SPEED
			_jump_buffer_left = 0.0
			_jump_cut_lock = 0.04
			_wall_hold_time = 0.0
			wall_clinging = false
			jumped = true
			action = "double_jump"
			_special("double_jump", 0.14)
			_emit_burst(Vector2.ZERO, MAGENTA, 12, 38.0)
		elif not jump_held and velocity.y < -82.0 and _jump_cut_lock <= 0.0:
			velocity.y = -82.0
	var previous_position: Vector2 = position
	var impact_speed: float = velocity.y
	move_and_slide()
	var distance: float = position.distance_to(previous_position)
	var landed: bool = not was_grounded and is_on_floor()
	if landed:
		_reset_air_resources()
		if striking:
			# Remain striking through this contact frame for the pad/barrier
			# resolver immediately after step. Clear on the next step.
			_strike_landed = true
		if impact_speed > 50.0:
			_special("land", 0.11)
			_emit_burst(Vector2.UP, WHITE, 7, minf(impact_speed * 0.12, 42.0))
			_impact_left = 0.10
		if action.is_empty():
			action = "land"
	if not is_on_wall():
		wall_clinging = false
		_wall_hold_time = 0.0
	var airborne_motion: bool = not is_on_floor() and not is_on_ceiling() and absf(velocity.y) > 0.01
	active_motion = distance > 0.025 or jumped or dash_started or airborne_motion
	if is_on_floor() and not jumped and dash_left <= 0.0 and not striking:
		if absf(axis) > 0.01 and absf(_last_axis) < 0.01 and absf(old_velocity.x) < 2.0:
			_special("start", 0.05)
		elif absf(old_velocity.x) > 45.0 and (absf(axis) < 0.01 or axis * old_velocity.x < 0.0) and _special_state != "skid":
			_special("skid", 0.08)
			_emit_burst(Vector2(-signf(old_velocity.x), -0.3), CYAN, 4, 20.0)
	_last_axis = axis
	if active_motion:
		_advance_effects(delta, previous_position, dash_started)
	_resolve_animation()
	queue_redraw()
	return {"moving": active_motion, "dash_started": dash_started, "jumped": jumped, "distance": distance, "action": action, "landed": landed}


func _reset_air_resources() -> void:
	extra_jumps = 1
	_wall_jump_refilled = false
	wall_cling_budget = 1.0
	_last_wall_jump_normal = 0.0
	_wall_hold_time = 0.0
	wall_clinging = false


func _special(state_name: String, duration: float) -> void:
	_special_state = state_name
	_special_left = duration


func _resolve_animation() -> void:
	if _dead:
		animation_state = "hit" if _hit_left > 0.0 else "death"
	elif _finished:
		animation_state = "goal"
	elif striking:
		animation_state = "strike"
	elif dash_left > 0.0:
		animation_state = "dash" if is_on_floor() and absf(_dash_direction.y) < 0.1 else "air_dash"
	elif focusing:
		animation_state = "focus"
	elif wall_clinging:
		animation_state = "wall_cling" if absf(velocity.y) < 0.01 else "wall_slide"
	elif _special_left > 0.0:
		animation_state = _special_state
	elif not is_on_floor():
		animation_state = "rise" if velocity.y < 0.0 else "fall"
	elif _spawn_left > 0.06 and not active_motion:
		animation_state = "respawn"
	elif absf(velocity.x) > 2.0:
		animation_state = "run"
	else:
		animation_state = "idle"


func _emit_burst(direction: Vector2, tint: Color, count: int, strength: float) -> void:
	for index in range(count):
		var angle: float = TAU * float(index) / float(maxi(count, 1)) + _motion_clock * 1.3
		var spread: Vector2 = Vector2(cos(angle), sin(angle))
		var drift: Vector2 = (spread * 0.65 + direction) * strength * (0.6 + float(index % 3) * 0.2)
		var color: Color = tint if index % 3 != 0 else CYAN
		_particles.append({"pos": position + Vector2(0, -5), "velocity": drift, "life": 0.24 + float(index % 4) * 0.03, "max_life": 0.33, "color": color})
	while _particles.size() > 72:
		_particles.pop_front()


func _advance_effects(delta: float, previous_position: Vector2, dash_started: bool) -> void:
	_motion_clock += delta
	_impact_left = maxf(0.0, _impact_left - delta)
	for index in range(_trail.size() - 1, -1, -1):
		var life: float = float(_trail[index].life) - delta
		_trail[index].life = life
		if life <= 0.0:
			_trail.remove_at(index)
	for index in range(_particles.size() - 1, -1, -1):
		var particle: Dictionary = _particles[index]
		particle.life = float(particle.life) - delta
		particle.pos = Vector2(particle.pos) + Vector2(particle.velocity) * delta
		particle.velocity = Vector2(particle.velocity) + Vector2(0.0, 60.0) * delta
		if float(particle.life) <= 0.0:
			_particles.remove_at(index)
	if dash_left > 0.0 or dash_started or striking:
		_trail_clock -= delta
		if _trail_clock <= 0.0:
			_trail.append({"position": previous_position, "facing": facing, "life": 0.19, "pose": "strike" if striking else "air_dash", "frame": int(_motion_clock * 36.0) % 8})
			_trail_clock = 0.022
			if _trail.size() > 8:
				_trail.pop_front()


func _draw() -> void:
	for ghost in _trail:
		var opacity: float = clampf(float(ghost.life) / 0.19, 0.0, 1.0) * 0.42
		var tint: Color = CYAN if int(ghost.frame) % 2 == 0 else MAGENTA
		_draw_figure((Vector2(ghost.position) - position).round(), int(ghost.facing), Color(tint, opacity), String(ghost.pose), int(ghost.frame), false)
	for particle in _particles:
		var local_point: Vector2 = (Vector2(particle.pos) - position).round()
		var opacity: float = clampf(float(particle.life) / float(particle.max_life), 0.0, 1.0)
		draw_rect(Rect2(local_point, Vector2(2, 1)), Color(Color(particle.color), opacity))
	if _impact_left > 0.0:
		var spread: float = roundf((0.18 - _impact_left) * 65.0)
		draw_line(Vector2(-spread - 3, -1), Vector2(-spread, -1), Color(CYAN, _impact_left * 4.0))
		draw_line(Vector2(spread, -1), Vector2(spread + 3, -1), Color(CYAN, _impact_left * 4.0))
	if animation_state == "death":
		_draw_death()
		return
	var frame: int = int(_motion_clock * 19.0) % 8
	var tint: Color = WHITE if animation_state != "hit" else RED
	_draw_figure(Vector2.ZERO, facing, tint, "melee" if melee_pose > 0 else animation_state, frame, true)
	if melee_pose > 0.08 and melee_pose < 0.23:
		var center := Vector2(facing*12,-15)
		draw_arc(center,13,-1.2 if facing > 0 else PI-1.2,1.2 if facing > 0 else PI+1.2,7,CYAN,2)
		draw_line(Vector2(facing*5,-9),Vector2(facing*24,-19),WHITE,1)
	if _spawn_left > 0.0:
		var width: float = ceilf(_spawn_left * 24.0)
		var alpha: float = _spawn_left * 2.0
		draw_rect(Rect2(-width, -16, width * 2.0, 17), Color(CYAN, alpha), false)
		draw_line(Vector2(-width - 3, -7), Vector2(-width, -7), Color(CYAN, alpha))
		draw_line(Vector2(width, -7), Vector2(width + 3, -7), Color(CYAN, alpha))


func _draw_figure(origin: Vector2, direction: int, tint: Color, pose: String, frame: int, detailed: bool) -> void:
	# Original segmented pixel silhouette: pose changes each limb and helmet.
	var head: Vector2 = Vector2(-3, -14)
	var torso: Rect2 = Rect2(-2, -9, 5, 5)
	var rear_hand: Vector2 = Vector2(-4, -5)
	var front_hand: Vector2 = Vector2(4, -5)
	var rear_foot: Vector2 = Vector2(-2, -1)
	var front_foot: Vector2 = Vector2(2, -1)
	var rear_knee: Vector2 = Vector2(-2, -3)
	var front_knee: Vector2 = Vector2(2, -3)
	var accent: Color = CYAN
	var head_size: Vector2 = Vector2(6, 5)
	match pose:
		"melee":
			head += Vector2(2,1)
			front_hand = Vector2(13,-12)
			rear_hand = Vector2(-6,-5)
			front_foot = Vector2(4,-1)
		"idle", "respawn":
			var breath: float = 1.0 if sin(_visual_clock * 2.8) > 0.55 else 0.0
			head.y += breath
			torso.position.y += breath
			front_hand.y -= breath
		"start":
			head += Vector2(1, 1)
			torso.position += Vector2(1, 1)
			rear_hand = Vector2(-4, -6)
			front_hand = Vector2(3, -7)
			front_foot.x = 3
		"run":
			var stride: Array[Vector4] = [Vector4(-2, 0, 2, -1), Vector4(-2, -1, 1, 0), Vector4(-1, -2, 0, 0), Vector4(0, -1, -1, 0), Vector4(2, 0, -2, -1), Vector4(2, -1, -1, 0), Vector4(1, -2, 0, 0), Vector4(0, -1, 1, 0)]
			var legs: Vector4 = stride[frame]
			var bob: float = -1.0 if frame % 4 >= 2 else 0.0
			head += Vector2(1, bob)
			torso.position += Vector2(0, bob)
			rear_foot = Vector2(-1 + legs.x, -1 + legs.y)
			front_foot = Vector2(1 + legs.z, -1 + legs.w)
			rear_knee = Vector2(-1 + legs.x * 0.5, -3 + legs.y)
			front_knee = Vector2(1 + legs.z * 0.5, -3 + legs.w)
			rear_hand = Vector2(-2 - legs.z, -6 - legs.w)
			front_hand = Vector2(2 - legs.x, -6 - legs.y)
		"skid":
			head += Vector2(-1, 1)
			torso.position += Vector2(-1, 1)
			front_knee = Vector2(2, -3)
			front_foot = Vector2(4, -1)
			rear_foot = Vector2(-3, -1)
			front_hand = Vector2(4, -7)
			rear_hand = Vector2(-5, -7)
		"takeoff", "land":
			head.y += 2
			torso.position.y += 2
			torso.size.y = 4
			front_knee = Vector2(3, -3)
			rear_knee = Vector2(-3, -3)
			front_hand = Vector2(4, -4)
			rear_hand = Vector2(-4, -4)
		"rise", "wall_jump", "double_jump", "bounce":
			head.y -= 1
			front_hand = Vector2(3, -10)
			rear_hand = Vector2(-4, -6)
			front_knee = Vector2(3, -5)
			front_foot = Vector2(2, -3)
			rear_foot = Vector2(-3, -1)
			if pose == "wall_jump":
				rear_hand = Vector2(-5, -10)
				rear_foot = Vector2(-4, -3)
			if pose == "double_jump":
				accent = MAGENTA
				rear_hand = Vector2(-4, -11)
				front_hand = Vector2(4, -11)
			if pose == "bounce":
				torso.size.y = 6
				front_hand = Vector2(4, -12)
				rear_hand = Vector2(-4, -12)
				front_foot = Vector2(1, -1)
		"fall", "focus":
			front_hand = Vector2(5, -9)
			rear_hand = Vector2(-5, -9)
			front_foot = Vector2(3, -1)
			rear_foot = Vector2(-3, -2)
			if pose == "focus":
				front_foot = Vector2(2, -3)
				rear_foot = Vector2(-2, -3)
		"wall_cling", "wall_slide":
			head.x += 1
			front_hand = Vector2(4, -12)
			rear_hand = Vector2(4, -8)
			front_knee = Vector2(3, -5)
			front_foot = Vector2(4, -3)
			rear_foot = Vector2(-2, -1)
			if pose == "wall_slide":
				head.y += 1
				front_hand.y += 1
			if wall_cling_budget < 0.23:
				accent = MAGENTA
		"dash", "air_dash":
			head = Vector2(0, -12)
			torso = Rect2(-4, -9, 7, 4)
			rear_hand = Vector2(-6, -8)
			front_hand = Vector2(5, -7)
			rear_knee = Vector2(-4, -4)
			front_knee = Vector2(-1, -4)
			rear_foot = Vector2(-6, -3)
			front_foot = Vector2(-3, -1)
			accent = CYAN if frame % 2 == 0 else MAGENTA
			if detailed:
				var smear: float = float(frame % 3) * 2.0
				_box(origin, Rect2(-11 - smear, -10, 7 + smear, 2), Color(accent, 0.65), direction)
				_box(origin, Rect2(-8 - smear, -6, 5 + smear, 1), accent, direction)
		"strike":
			head = Vector2(-3, -15)
			torso = Rect2(-2, -10, 4, 6)
			front_hand = Vector2(4, -12)
			rear_hand = Vector2(-4, -12)
			front_knee = Vector2(1, -4)
			rear_knee = Vector2(-1, -4)
			front_foot = Vector2(0, -1)
			rear_foot = Vector2(-1, -1)
			accent = MAGENTA
		"hit":
			head += Vector2(-2, 1)
			rear_hand = Vector2(-6, -9)
			front_hand = Vector2(5, -10)
			front_foot.x = 4
			accent = RED
		"goal":
			head.y -= 1
			front_hand = Vector2(5, -15)
			rear_hand = Vector2(-4, -6)
	var shade: Color = tint.darkened(0.24) if detailed else tint
	_limb(origin, Vector2(-1, -5), rear_knee, shade, direction)
	_limb(origin, rear_knee, rear_foot, shade, direction)
	_limb(origin, Vector2(-2, -8), rear_hand, shade, direction)
	_box(origin, Rect2(rear_foot + Vector2(-1, 0), Vector2(3, 1)), shade, direction)
	if detailed:
		_box(origin, Rect2(head - Vector2.ONE, head_size + Vector2(2, 2)), INK, direction)
		_box(origin, torso.grow(1), INK, direction)
	_box(origin, torso, tint, direction)
	_box(origin, Rect2(torso.position + Vector2(0, torso.size.y - 1), Vector2(torso.size.x, 1)), shade, direction)
	_limb(origin, Vector2(1, -5), front_knee, tint, direction)
	_limb(origin, front_knee, front_foot, tint, direction)
	_box(origin, Rect2(front_foot + Vector2(-1, 0), Vector2(3, 1)), tint, direction)
	_box(origin, Rect2(head, head_size), tint, direction)
	_box(origin, Rect2(head + Vector2(0, 4), Vector2(5, 1)), shade, direction)
	_limb(origin, torso.position + Vector2(torso.size.x - 1, 1), front_hand, tint, direction)
	if detailed:
		_box(origin, Rect2(head + Vector2(3, 2), Vector2(3, 2)), accent, direction)
		_box(origin, Rect2(head + Vector2(5, 2), Vector2(1, 1)), WHITE, direction)
		_box(origin, Rect2(torso.position + Vector2(1, 1), Vector2(1, 2)), accent, direction)
		if pose == "strike":
			_limb(origin, Vector2(-3, 1), Vector2(0, 5), accent, direction, 1)
			_limb(origin, Vector2(0, 5), Vector2(3, 1), accent, direction, 1)
		if pose == "double_jump" or pose == "focus":
			for index in range(4):
				var p: Vector2 = Vector2(-7 if index % 2 == 0 else 6, -15 if index < 2 else -2)
				_box(origin, Rect2(p, Vector2(2, 1)), accent, direction)
		if pose == "wall_cling" or pose == "wall_slide":
			_box(origin, Rect2(5, -12, 1, 8), Color(accent, 0.7), direction)
		if pose == "goal":
			_box(origin, Rect2(4, -20, 3, 3), CYAN, direction)
			_box(origin, Rect2(5, -19, 1, 1), INK, direction)


func _box(origin: Vector2, rectangle: Rect2, color: Color, direction: int) -> void:
	var result: Rect2 = rectangle
	if direction < 0:
		result.position.x = -rectangle.position.x - rectangle.size.x
	result.position = (result.position + origin).round()
	draw_rect(result, color)


func _limb(origin: Vector2, start: Vector2, end: Vector2, color: Color, direction: int, width: int = 2) -> void:
	var length: int = maxi(1, int(ceilf(maxf(absf(end.x - start.x), absf(end.y - start.y)))))
	for index in range(length + 1):
		var point: Vector2 = start.lerp(end, float(index) / float(length)).round()
		_box(origin, Rect2(point - Vector2.ONE, Vector2(width, width)), color, direction)


func _draw_death() -> void:
	var progress: float = clampf(1.0 - _death_left / 0.22, 0.0, 1.0)
	for index in range(10):
		var angle: float = float(index) * TAU / 10.0
		var point: Vector2 = Vector2(cos(angle), sin(angle)) * progress * 18.0 + Vector2(0, -7)
		var tint: Color = WHITE if index % 3 == 0 else (CYAN if index % 2 == 0 else RED)
		draw_rect(Rect2(point.round(), Vector2(2, 2)), Color(tint, 1.0 - progress))

