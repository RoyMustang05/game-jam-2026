extends CharacterBody2D
## Normal physics for Milo; the game advances its separate clock from step().
## Drawing lives in milo_figure.gd and the trail/particles in player_effects.gd,
## so this file stays about movement.
const Figure = preload("res://scripts/actors/milo_figure.gd")
const PlayerEffects = preload("res://scripts/actors/player_effects.gd")
const StateMachine = preload("res://scripts/systems/state_machine.gd")

const MOTION_SCRIPTS := {
	&"normal": preload("res://scripts/actors/player_states/normal.gd"),
	&"dash": preload("res://scripts/actors/player_states/dash.gd"),
	&"strike": preload("res://scripts/actors/player_states/strike.gd"),
	&"focus": preload("res://scripts/actors/player_states/focus.gd"),
	&"finished": preload("res://scripts/actors/player_states/finished.gd"),
	&"dead": preload("res://scripts/actors/player_states/dead.gd"),
}

## Result of a frame Milo sat out entirely.
const IDLE_RESULT := {"moving": false, "dash_started": false, "jumped": false, "distance": 0.0, "action": "", "landed": false}

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
var _last_axis: float = 0.0
var _special_state: String = ""
var _special_left: float = 0.0
var _spawn_left: float = 0.25
var _hit_left: float = 0.0
var _death_left: float = 0.0
var _finished: bool = false
var _dead: bool = false
var _pending_action: String = ""
var costume: int = 0
var high_resolution: bool = false
var effects := PlayerEffects.new()
## Which movement rule produces velocity this frame. See player_states/.
var motion := StateMachine.new()


func _init() -> void:
	motion.host = self
	for motion_id: StringName in MOTION_SCRIPTS:
		motion.add(motion_id, MOTION_SCRIPTS[motion_id].new())
	motion.rebind(&"normal")


## Switch with enter/exit. Out-of-band forces use rebind_motion instead.
func change_motion(motion_id: StringName, frame: Dictionary = {}) -> void:
	motion.change_to(motion_id, frame)


## Switch without side effects, for changes another system already resolved.
func rebind_motion(motion_id: StringName) -> void:
	motion.rebind(motion_id)


## Focus is a deliberate stillness: any input at all, or already being committed
## to a dash or strike, disqualifies it. Shared by normal (to enter) and focus
## (to decide whether to stay).
func wants_focus(frame: Dictionary) -> bool:
	return bool(frame.focus_held) \
		and not bool(frame.was_grounded) \
		and absf(float(frame.axis)) < 0.01 \
		and absf(float(frame.vertical)) < 0.01 \
		and not bool(frame.jump_pressed) \
		and not bool(frame.dash_pressed) \
		and dash_left <= 0.0 \
		and not striking


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
	_last_axis = 0.0
	_special_state = ""
	_special_left = 0.0
	_spawn_left = 0.25
	_hit_left = 0.0
	_death_left = 0.0
	_finished = false
	_dead = false
	_pending_action = ""
	effects.clear()
	rebind_motion(&"normal")
	animation_state = "respawn"
	reset_physics_interpolation()
	queue_redraw()


func can_phase() -> bool:
	return _phase_left > 0.0 and not striking and not _dead


func refill_at_anchor() -> void:
	dash_charges = 2
	_spawn_left = 0.20
	_burst(Vector2.UP, CYAN, 12, 40.0)
	queue_redraw()


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
	rebind_motion(&"normal")
	_special("bounce", 0.15)
	effects.impact_left = PlayerEffects.IMPACT_DURATION
	_burst(Vector2.UP, CYAN, 16, 65.0)
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
	rebind_motion(&"finished")
	animation_state = "goal"
	queue_redraw()


func play_hit() -> void:
	_dead = true
	_hit_left = 0.06
	_death_left = 0.22
	velocity = Vector2.ZERO
	active_motion = false
	rebind_motion(&"dead")
	animation_state = "hit"
	queue_redraw()


func step(delta: float, command: Dictionary = {}) -> Dictionary:
	# Terminal states sit the frame out completely: no timers, no input, no
	# physics. Checked before the prologue so nothing ticks behind the scenes.
	if _finished or _dead:
		return IDLE_RESULT.duplicate()
	var frame: Dictionary = _read_command(command)
	if absf(float(frame.axis)) > 0.01 and _wall_recovery <= 0.0:
		facing = 1 if float(frame.axis) > 0.0 else -1
	var was_grounded: bool = is_on_floor()
	var old_velocity: Vector2 = velocity
	frame.action = _pending_action
	_pending_action = ""
	frame.jumped = frame.action == "bounce"
	frame.dash_started = false
	_tick_timers(delta)
	if _strike_landed:
		striking = false
		_strike_landed = false
		_strike_left = 0.0
		dash_left = 0.0
		rebind_motion(&"normal")
	if was_grounded:
		_coyote_left = COYOTE_TIME
		_reset_air_resources()
	else:
		_coyote_left = maxf(0.0, _coyote_left - delta)
	if bool(frame.jump_pressed):
		_jump_buffer_left = JUMP_BUFFER_TIME
	_derive_wall_context(frame, was_grounded)
	if motion.current.decide(delta, frame):
		_resolve_animation()
		queue_redraw()
		return IDLE_RESULT.duplicate()
	return _integrate(delta, frame, was_grounded, old_velocity)


## Live input and a scripted test command produce the same frame description,
## so the routes in tests/route_tests.gd drive exactly the player a human does.
func _read_command(command: Dictionary) -> Dictionary:
	if command.is_empty():
		return {
			"axis": Input.get_axis("move_left", "move_right"),
			"vertical": Input.get_axis("move_up", "move_down"),
			"jump_pressed": Input.is_action_just_pressed("jump"),
			"jump_held": Input.is_action_pressed("jump"),
			"dash_pressed": Input.is_action_just_pressed("dash"),
			"cling_held": true,
			"focus_held": Input.is_action_pressed("focus"),
		}
	var jump_pressed: bool = bool(command.get("jump", false))
	return {
		"axis": clampf(float(command.get("axis", 0.0)), -1.0, 1.0),
		"vertical": clampf(float(command.get("vertical", 0.0)), -1.0, 1.0),
		"jump_pressed": jump_pressed,
		"jump_held": bool(command.get("jump_held", jump_pressed)),
		"dash_pressed": bool(command.get("dash", false)),
		"cling_held": bool(command.get("cling", true)),
		"focus_held": bool(command.get("freeze_air", false)),
	}


func _tick_timers(delta: float) -> void:
	_dash_cooldown = maxf(0.0, _dash_cooldown - delta)
	_phase_left = maxf(0.0, _phase_left - delta)
	_wall_recovery = maxf(0.0, _wall_recovery - delta)
	_jump_cut_lock = maxf(0.0, _jump_cut_lock - delta)
	_jump_buffer_left = maxf(0.0, _jump_buffer_left - delta)


func _derive_wall_context(frame: Dictionary, was_grounded: bool) -> void:
	var normal_x: float = get_wall_normal().x if is_on_wall() else 0.0
	if absf(normal_x) > 0.5 and normal_x * _last_wall_jump_normal < -0.5:
		# Alternating walls refresh grip; repeating one wall spends grip.
		wall_cling_budget = 1.0
		_last_wall_jump_normal = 0.0
	frame.was_grounded = was_grounded
	frame.normal_x = normal_x
	frame.wall_available = not was_grounded \
		and float(frame.axis) * normal_x < -0.1 \
		and bool(frame.cling_held) \
		and wall_cling_budget > 0.0 \
		and _wall_recovery <= 0.0


## Move, then the bookkeeping every state shares: landing, wall release, whether
## this counted as motion, and the small grounded pose cues.
func _integrate(delta: float, frame: Dictionary, was_grounded: bool, old_velocity: Vector2) -> Dictionary:
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
			_burst(Vector2.UP, WHITE, 7, minf(impact_speed * 0.12, 42.0))
			effects.impact_left = 0.10
		if String(frame.action).is_empty():
			frame.action = "land"
	if not is_on_wall():
		wall_clinging = false
		_wall_hold_time = 0.0
	var airborne_motion: bool = not is_on_floor() and not is_on_ceiling() and absf(velocity.y) > 0.01
	active_motion = distance > 0.025 or bool(frame.jumped) or bool(frame.dash_started) or airborne_motion
	_ground_cues(frame, old_velocity)
	_last_axis = frame.axis
	if active_motion:
		_advance_effects(delta, previous_position, bool(frame.dash_started))
	_resolve_animation()
	queue_redraw()
	return {"moving": active_motion, "dash_started": frame.dash_started, "jumped": frame.jumped, "distance": distance, "action": frame.action, "landed": landed}


## Two grounded flourishes: pushing off from a standstill, and skidding when
## momentum is dropped or reversed.
func _ground_cues(frame: Dictionary, old_velocity: Vector2) -> void:
	if not is_on_floor() or bool(frame.jumped) or dash_left > 0.0 or striking:
		return
	var axis: float = frame.axis
	if absf(axis) > 0.01 and absf(_last_axis) < 0.01 and absf(old_velocity.x) < 2.0:
		_special("start", 0.05)
	elif absf(old_velocity.x) > 45.0 and (absf(axis) < 0.01 or axis * old_velocity.x < 0.0) and _special_state != "skid":
		_special("skid", 0.08)
		_burst(Vector2(-signf(old_velocity.x), -0.3), CYAN, 4, 20.0)


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


## The pose belongs to whichever state is producing movement. What used to be
## an eleven-branch cascade, whose ordering was the only record of which state
## outranked which, is now one question asked of the current state.
func _resolve_animation() -> void:
	animation_state = motion.current.pose()


func _burst(direction: Vector2, tint: Color, count: int, strength: float) -> void:
	effects.burst(position, direction, tint, count, strength, _motion_clock)


func _advance_effects(delta: float, previous_position: Vector2, dash_started: bool) -> void:
	_motion_clock += delta
	var ghosting: bool = dash_left > 0.0 or dash_started or striking
	effects.advance(delta, previous_position, ghosting, "strike" if striking else "air_dash", facing, _motion_clock)


func _draw() -> void:
	if not high_resolution:
		draw_visual(self)


func draw_visual(canvas: CanvasItem) -> void:
	effects.draw(canvas, position, costume)
	if animation_state == "death":
		Figure.death(canvas, clampf(1.0 - _death_left / 0.22, 0.0, 1.0))
		return
	var frame: int = int(_motion_clock * 19.0) % 8
	var tint: Color = WHITE if animation_state != "hit" else RED
	var pose: String = "melee" if melee_pose > 0 else animation_state
	Figure.figure(canvas, Vector2.ZERO, facing, tint, pose, frame, true, _visual_clock, wall_cling_budget, costume)
	if melee_pose > 0.08 and melee_pose < 0.23:
		var center := Vector2(facing*12,-15)
		canvas.draw_arc(center,13,-1.2 if facing > 0 else PI-1.2,1.2 if facing > 0 else PI+1.2,7,CYAN,2)
		canvas.draw_line(Vector2(facing*5,-9),Vector2(facing*24,-19),WHITE,1)
	if _spawn_left > 0.0:
		var width: float = ceilf(_spawn_left * 24.0)
		var alpha: float = _spawn_left * 2.0
		canvas.draw_rect(Rect2(-width, -16, width * 2.0, 17), Color(CYAN, alpha), false)
		canvas.draw_line(Vector2(-width - 3, -7), Vector2(-width, -7), Color(CYAN, alpha))
		canvas.draw_line(Vector2(width, -7), Vector2(width + 3, -7), Color(CYAN, alpha))
