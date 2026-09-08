extends SceneTree
## Real Godot physics checks. Fixture teleports isolate mechanics; room teleports
## below validate flow/checkpoints only. Traversal has a separate route suite.
const PlayerScript = preload("res://scripts/player.gd")
const GameScript = preload("res://scripts/game.gd")
const MechanismsScript = preload("res://scripts/mechanisms.gd")
var game: Node2D
var fixture: Node2D
var actor: CharacterBody2D
var fixture_mech: Node2D
var last_result: Dictionary = {}
var last_interaction: Dictionary = {}
var assertions: int = 0
var failures: int = 0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	await _controller_checks()
	if not OS.get_cmdline_user_args().has("--fixtures-only"):
		await _game_checks()
	print("CORE TESTS: %d checks, %d failures" % [assertions, failures])
	quit(0 if failures == 0 else 1)


func _controller_checks() -> void:
	fixture = Node2D.new()
	fixture.position = Vector2(0, 1200)
	root.add_child(fixture)
	_solid(Rect2(-500, 300, 1000, 40))
	_solid(Rect2(200, -400, 20, 700))
	_solid(Rect2(-220, -400, 20, 700))
	_solid(Rect2(-140, 190, 110, 8))
	_new_actor(Vector2(0, 300))
	await _actor_frames(20)
	_check(actor.is_on_floor() and not last_result.moving, "controller settles on feet-origin collider")
	_check(actor.animation_state == "idle", "respawn recovers to breathing idle")
	var start: Vector2 = actor.position
	await _actor_frames(12, {"axis": 1.0})
	_check(actor.position.x > start.x + 15.0 and last_result.moving, "acceleration produces fast meaningful horizontal motion")
	_check(actor.animation_state == "run", "run animation follows actual grounded motion")
	await _actor_frames(1, {"axis": -1.0})
	_check(actor.animation_state == "skid", "reversing momentum produces skid pose")
	await _actor_frames(10)
	_check(actor.velocity.x == 0.0 and not last_result.moving, "friction reaches exact rest and freezes clock")
	var pose_clock: float = actor._motion_clock
	await _actor_frames(60)
	_check(actor._motion_clock == pose_clock, "world particle/run clock never advances while still")
	_new_actor(Vector2(-195.99, 300))
	await _actor_frames(20, {"axis": -1.0})
	start = actor.position
	await _actor_frames(120, {"axis": -1.0})
	_check(actor.position == start and not last_result.moving, "holding against grounded wall stays frozen")
	_new_actor(Vector2(0, 300))
	await _actor_frames(3)
	await _actor_frames(1, {"axis": 0.0, "jump": true, "jump_held": true})
	_check(last_result.action == "jump" and last_result.jumped and actor.velocity.y < -220, "ground jump reports action and upward launch")
	_check(actor.animation_state == "takeoff", "jump begins with takeoff silhouette")
	var minimum_y: float = actor.position.y
	for index in range(24):
		await _actor_frames(1, {"axis": 0.0, "jump_held": true})
		minimum_y = minf(minimum_y, actor.position.y)
	_check(minimum_y < 264.0 and minimum_y > 259.0, "held jump reaches designed 37-40 pixel height")
	await _actor_frames(40)
	_check(actor.is_on_floor() and actor.extra_jumps == 1, "landing restores exactly one extra jump")
	_new_actor(Vector2(0, 300))
	await _actor_frames(3)
	await _actor_frames(1, {"axis": 0.0, "jump": true, "jump_held": true})
	var short_minimum: float = actor.position.y
	for index in range(25):
		await _actor_frames(1)
		short_minimum = minf(short_minimum, actor.position.y)
	_check(short_minimum > minimum_y + 20.0, "early release produces a controllable short jump")
	_new_actor(Vector2(0, 300))
	await _actor_frames(3)
	await _actor_frames(1, {"axis": 0.0, "jump": true, "jump_held": true})
	await _actor_frames(15, {"axis": 0.0, "jump_held": true})
	await _actor_frames(1, {"axis": 0.0, "jump": true, "jump_held": true})
	_check(last_result.action == "double_jump" and actor.extra_jumps == 0, "one airborne extra jump is available")
	_check(actor.animation_state == "double_jump" and actor._particles.size() >= 12, "extra jump has distinct temporal burst and pose")
	await _actor_frames(1, {"axis": 0.0, "jump_held": true})
	await _actor_frames(1, {"axis": 0.0, "jump": true, "jump_held": true})
	_check(not last_result.jumped and actor.extra_jumps == 0, "third jump is rejected until landing")
	await _actor_frames(65, {"axis": 0.0, "jump_held": true})
	_check(actor.is_on_floor() and actor.extra_jumps == 1, "landing resets double jump after its use")
	_new_actor(Vector2(-35, 190))
	await _actor_frames(3)
	for index in range(20):
		await _actor_frames(1, {"axis": 1.0})
		if not actor.is_on_floor():
			break
	await _actor_frames(1, {"axis": 1.0, "jump": true, "jump_held": true})
	_check(last_result.action == "jump", "coyote time preserves ground jump just after ledge departure")
	_new_actor(Vector2(50, 292))
	actor.velocity.y = 100.0
	actor.extra_jumps = 0
	await _actor_frames(1, {"axis": 0.0, "jump": true})
	var buffered: bool = false
	for index in range(8):
		await _actor_frames(1, {"axis": 0.0, "jump_held": true})
		buffered = buffered or last_result.action == "jump"
	_check(buffered, "jump pressed before landing is buffered and launches on contact")
	_new_actor(Vector2(0, 160))
	await _actor_frames(10)
	_check(actor.velocity.y > 0.0 and last_result.moving, "uncontrolled falling advances world")
	start = actor.position
	await _actor_frames(1, {"axis": 0.0, "freeze_air": true})
	var effects: Array = actor._particles.duplicate(true)
	await _actor_frames(120, {"axis": 0.0, "freeze_air": true})
	_check(actor.position == start and actor.focusing and not last_result.moving, "X focus suspends actual airborne motion indefinitely")
	_check(actor.animation_state == "focus" and actor._particles == effects, "air focus has distinct pose and frozen effect positions")
	await _actor_frames(2)
	_check(actor.position.y > start.y and not actor.focusing and last_result.moving, "releasing focus resumes saved fall without consuming resources")
	_new_actor(Vector2(195.99, 150))
	await _actor_frames(5, {"axis": 1.0})
	_check(actor.wall_clinging and actor.animation_state == "wall_slide" and last_result.moving, "holding toward airborne wall begins slow active slide")
	await _actor_frames(22, {"axis": 1.0})
	start = actor.position
	var grip: float = actor.wall_cling_budget
	await _actor_frames(120, {"axis": 1.0})
	_check(actor.position == start and actor.wall_clinging and not last_result.moving, "settled wall cling freezes position and world")
	_check(actor.wall_cling_budget == grip and actor.animation_state == "wall_cling", "stationary wall planning does not spend grip")
	actor.extra_jumps = 0
	await _actor_frames(1, {"axis": 1.0, "jump": true, "jump_held": true})
	_check(last_result.action == "wall_jump" and actor.velocity.x < -150 and actor.velocity.y < -230, "wall jump launches upward and away with recoil")
	_check(actor.extra_jumps == 1 and actor.animation_state == "wall_jump", "first wall jump refills extra jump and uses unique pose")
	await _actor_frames(8, {"axis": 1.0, "jump_held": true})
	_check(actor.position.x < 180, "short recovery prevents immediate wall-jump cancellation")
	actor.extra_jumps = 0
	actor.position = Vector2(195.99, 110)
	actor.velocity = Vector2(0, 30)
	await _actor_frames(24, {"axis": 1.0})
	await _actor_frames(1, {"axis": 1.0, "jump": true, "jump_held": true})
	_check(last_result.action == "wall_jump" and actor.extra_jumps == 0, "later wall jumps cannot endlessly refill airborne extra jump")
	_check(actor.wall_cling_budget < grip - 0.3, "repeated use of the same wall consumes finite grip")
	_new_actor(Vector2(0, 170))
	await _actor_frames(1)
	await _actor_frames(1, {"axis": 1.0, "vertical": -1.0, "dash": true})
	_check(last_result.dash_started and last_result.action == "dash" and actor.dash_charges == 1, "diagonal air dash consumes one charge")
	_check(actor.velocity.x > 170 and actor.velocity.y < -170 and absf(actor.velocity.length() - 245.0) < 0.1, "diagonal dash uses normalized eight-direction speed")
	_check(actor.can_phase() and actor.animation_state == "air_dash", "dash supplies brief phase window and air-dash smear")
	await _actor_frames(1, {"axis": 1.0, "dash": true})
	_check(not last_result.dash_started and actor.dash_charges == 1, "cooldown rejects overlapping dash requests")
	await _actor_frames(15)
	_check(not actor.can_phase(), "dash phase ends after its short window")
	await _actor_frames(1, {"axis": -1.0, "dash": true})
	_check(last_result.dash_started and actor.dash_charges == 0, "second dash is available after cooldown")
	await _actor_frames(18)
	await _actor_frames(1, {"axis": 0.0, "dash": true})
	_check(not last_result.dash_started and actor.dash_charges == 0, "exhausted charges prevent further dashes")
	actor.refill_at_anchor()
	_check(actor.dash_charges == 2, "Temporal Anchor API restores two charges")
	_new_actor(Vector2(0, 200))
	await _actor_frames(1)
	await _actor_frames(1, {"axis": 0.0, "vertical": 1.0, "dash": true})
	_check(last_result.action == "strike" and last_result.dash_started and actor.striking, "Down plus dash starts a downward strike")
	_check(actor.velocity.y == 320.0 and actor.dash_charges == 1 and not actor.can_phase(), "strike is fast and paid but does not phase through unmarked hazards")
	_check(actor.animation_state == "strike", "strike has pointed downward pose")
	actor.bounce_from_pad(270.0)
	_check(not actor.striking and actor.velocity.y == -270.0 and actor.dash_charges == 1 and actor.extra_jumps == 1, "pad bounce launches upward and restores extra jump without refilling dash")
	actor.bounce_from_pad(400.0)
	_check(actor.velocity.y == -270.0, "same pad cannot repeatedly bounce an ended strike")
	await _actor_frames(1)
	_check(last_result.action == "bounce" and actor.animation_state == "bounce", "bounce action and impact animation reach game manager")
	fixture_mech = MechanismsScript.new()
	fixture.add_child(fixture_mech)
	fixture_mech.setup({"spawn": Vector2(0, 220), "pads": [{"rect": Rect2(-15, 260, 30, 6), "bounce": 270.0}]})
	_new_actor(Vector2(0, 220))
	await _actor_frames(1)
	await _actor_frames(1, {"axis": 0.0, "vertical": 1.0, "dash": true})
	var bounced: bool = false
	for index in range(14):
		await _actor_frames(1)
		if bool(last_interaction.get("bounced", false)):
			bounced = true
			break
	_check(bounced and actor.velocity.y < -260.0, "swept real-physics strike contacts marked red pad and bounces")
	_new_actor(Vector2(0, 258))
	actor.velocity.y = 90
	await _actor_frames(2)
	_check(bool(last_interaction.get("dead", false)), "unmarked non-striking contact with red pad is lethal")
	fixture_mech.setup({"spawn": Vector2.ZERO, "barriers": [{"rect": Rect2(15, 240, 4, 50), "kind": "phase"}, {"rect": Rect2(55, 240, 4, 50), "kind": "fragile"}], "fields": [{"rect": Rect2(-50, 100, 40, 200), "multiplier": 0.5}, {"rect": Rect2(80, 100, 40, 200), "multiplier": 1.5}], "gates": [{"rect": Rect2(140, 200, 8, 80), "period": 2.0, "open_ratio": 0.5}]})
	_new_actor(Vector2(0, 265))
	await _actor_frames(1)
	await _actor_frames(1, {"axis": 1.0, "dash": true})
	var broken: bool = false
	for index in range(6):
		await _actor_frames(1)
		broken = broken or bool(last_interaction.get("barrier_broken", false))
	_check(broken and bool(fixture_mech.barriers[0].broken), "temporal dash breaks a marked magenta barrier")
	actor.position = Vector2(-30, 200)
	_check(fixture_mech.time_field_multiplier(actor) == 0.5, "slow field deterministically reports half world speed")
	actor.position = Vector2(100, 200)
	_check(fixture_mech.time_field_multiplier(actor) == 1.5, "accelerated field deterministically reports one-and-half world speed")
	actor.position = Vector2(0, 200)
	_check(fixture_mech.time_field_multiplier(actor) == 1.0, "outside a field world speed is normal")
	fixture_mech.pre_player(actor)
	var gate_timer: float = fixture_mech.gates[0].timer
	fixture_mech.world_step(0.0, actor)
	_check(fixture_mech.gates[0].timer == gate_timer, "gate timer freezes with zero world delta")
	fixture_mech.world_step(0.25, actor)
	_check(absf(fixture_mech.gates[0].timer - gate_timer - 0.25) < 0.0001, "gate timer progresses on explicit world delta")
	actor.play_finish()
	_check(actor.animation_state == "goal" and not actor.step(1.0 / 60.0, {"axis": 1.0}).moving, "goal pose prevents unintended post-completion movement")
	actor.play_hit()
	_check(actor.animation_state == "hit", "hit reaction animation is available for immediate impact")
	await process_frame
	await create_timer(0.10).timeout
	_check(actor.animation_state == "death", "hit transitions to pixel-shatter death pose")
	fixture.queue_free()
	actor = null
	fixture_mech = null
	await process_frame


func _game_checks() -> void:
	game = GameScript.new()
	game.test_mode = true
	game.test_command = {"axis": 0.0}
	root.add_child(game)
	await _frames(4)
	_check(game.state == "menu", "project opens at main menu")
	_action("confirm")
	await _frames(5)
	_check(game.state == "playing" and game.level_index == 0, "menu confirm begins first room")
	var timer_before: float = game.remaining
	var real_before: float = game.total_real
	var world_before: float = game.total_world
	var snapshot: Dictionary = _snapshot()
	await _frames(120)
	_check(game.frozen and game.remaining == timer_before and game.total_world == world_before, "standing freezes countdown and active-world statistics")
	_check(game.total_real > real_before + 1.9 and _snapshot() == snapshot, "real time advances while world entity snapshots remain identical")
	await _frames(12, {"axis": 1.0})
	_check(not game.frozen and game.total_distance > 10.0, "walking resumes world and distance statistic")
	await _frames(10)
	timer_before = game.remaining
	world_before = game.total_world
	await _frames(1, {"axis": 1.0, "dash": true})
	_check(game.player.dash_charges == 1 and game.total_dashes == 1, "manager records a single dash and spent charge")
	_check(absf(timer_before - game.remaining - 2.0 - (game.total_world - world_before)) < 0.00001, "each dash costs exactly two seconds plus active movement frame")
	_action("pause_game")
	timer_before = game.remaining
	var player_before: Vector2 = game.player.position
	var ui_before: float = game.ui_time
	await _frames(60, {"axis": 1.0, "jump": true, "dash": true})
	_check(game.paused and game.remaining == timer_before and game.player.position == player_before, "pause freezes controller, abilities and timer")
	_check(game.ui_time > ui_before + 0.9, "pause leaves interface responsive")
	_action("pause_game")
	_check(not game.paused, "Escape resumes")
	var deaths: int = game.total_deaths
	_action("restart")
	await _frames(5)
	_check(game.total_deaths == deaths + 1 and game.player.dash_charges == 2, "R restarts immediately and counts a death")
	_check(game.player.position.distance_to(Vector2(game.checkpoint_position)) < 0.1, "restart preserves authored local spawn")
	deaths = game.total_deaths
	game.remaining = 0.001
	await _frames(1, {"axis": 1.0})
	_check(game.total_deaths == deaths + 1 and game.death_reason == "TIME EXPIRED", "timer expiry kills and restores timeline")
	game.load_level(2)
	await _frames(5)
	if not game.hazards.watchers.is_empty():
		# Put the turret in an isolated visible lane; off-screen/occluded
		# Watchers intentionally do not shoot in the finished game.
		game.hazards.watchers[0].pos = game.player.position + Vector2(20, -40)
		game.hazards.watchers[0].direction = Vector2.DOWN
		game.hazards.watchers[0].fov = 360.0
		game.hazards.watchers[0].range = 1000.0
		game.hazards.watchers[0].timer = float(game.hazards.watchers[0].interval) - 0.005
		await _frames(2, {"axis": 1.0})
		_check(not game.hazards.projectiles.is_empty(), "Watcher fires on active-world schedule")
		await _frames(10)
		snapshot = _snapshot()
		await _frames(120)
		_check(game.frozen and snapshot == _snapshot(), "Watcher, projectiles, patrols and gates freeze together")
	else:
		_check(false, "antiquity room contains Watcher")
	game.load_level(2)
	await _frames(5)
	if not game.platforms.is_empty():
		var platform_before: Vector2 = game.platforms[0].pos
		await _frames(12, {"axis": 1.0})
		_check(Vector2(game.platforms[0].pos).distance_to(platform_before) > 1.0, "industrial platform follows active world clock")
		await _frames(10)
		snapshot = _snapshot()
		await _frames(120)
		_check(game.frozen and snapshot == _snapshot(), "platform remains perfectly frozen while Milo is still")
	else:
		_check(false, "industrial room contains moving platform")
	game.load_level(2)
	await _frames(5)
	if not game.mechanisms.anchors.is_empty():
		var anchor_position: Vector2 = game.mechanisms.anchors[0].pos
		game.player.position = anchor_position - Vector2(1, 0)
		game.player.velocity = Vector2.ZERO
		game.player.dash_charges = 0
		await _frames(1, {"axis": 1.0})
		_check(game.checkpoint_index == 0 and game.player.dash_charges == 2, "touching Temporal Anchor activates checkpoint and restores charges")
		var saved_time: float = game.checkpoint_remaining
		deaths = game.total_deaths
		_action("restart")
		await _frames(5)
		_check(game.total_deaths == deaths + 1 and game.player.position.distance_to(anchor_position) < 0.2, "R respawns instantly at latest active anchor")
		_check(absf(game.remaining - saved_time) < 0.1 and game.checkpoint_index == 0, "checkpoint restores saved room budget and active anchor")
	else:
		_check(false, "factory challenge provides Temporal Anchor")
	game.start_run()
	for index in range(3):
		game.load_level(index)
		await _frames(5)
		_check(game.level_index == index and game.state == "playing", "campaign room %d loads"%(index+1))
		game.player.position = Vector2(game.data.goal)
		game.player.velocity = Vector2.ZERO
		await _frames(1)
		_check(game.state == "clear", "exit advances room %d"%(index+1))
	game.load_level(3)
	_check(is_instance_valid(game.dragon) and game.data.title == "THE LAST FLAME", "fourth level contains Pyrax")
	_check(GameScript.ROOM_COUNT == 4, "campaign has exactly four levels")
	game.queue_free()
	await process_frame


func _solid(rectangle: Rect2) -> void:
	var body: StaticBody2D = StaticBody2D.new()
	body.position = rectangle.get_center()
	body.collision_layer = 1
	body.collision_mask = 2
	var shape: RectangleShape2D = RectangleShape2D.new()
	shape.size = rectangle.size
	var collision: CollisionShape2D = CollisionShape2D.new()
	collision.shape = shape
	body.add_child(collision)
	fixture.add_child(body)


func _new_actor(spawn: Vector2) -> void:
	if is_instance_valid(actor):
		fixture.remove_child(actor)
		actor.queue_free()
	actor = PlayerScript.new()
	fixture.add_child(actor)
	actor.reset_at(spawn)
	last_result = {}
	last_interaction = {}
	if is_instance_valid(fixture_mech):
		fixture_mech.previous_player = spawn


func _actor_frames(count: int, command: Dictionary = {"axis": 0.0}) -> void:
	for index in range(count):
		await physics_frame
		if is_instance_valid(fixture_mech):
			fixture_mech.pre_player(actor)
		last_result = actor.step(1.0 / 60.0, command)
		if is_instance_valid(fixture_mech):
			last_interaction = fixture_mech.world_step(1.0 / 60.0 if last_result.moving else 0.0, actor)
		await process_frame


func _frames(count: int, command: Dictionary = {"axis": 0.0}) -> void:
	game.test_command = command
	for index in range(count):
		await physics_frame
		await process_frame


func _action(name: String) -> void:
	var event: InputEventAction = InputEventAction.new()
	event.action = name
	event.pressed = true
	game._unhandled_input(event)


func _snapshot() -> Dictionary:
	var platform_state: Array = []
	for entry: Dictionary in game.platforms:
		platform_state.append({"pos": entry.pos, "travel": entry.travel})
	var gate_state: Array = []
	for entry: Dictionary in game.mechanisms.gates:
		gate_state.append({"timer": entry.timer, "closed": entry.closed, "warning": entry.warning})
	return {"world": game.level_world, "hazard_world": game.hazards.world_time, "spikes": game.hazards.spikes.duplicate(true), "watchers": game.hazards.watchers.duplicate(true), "projectiles": game.hazards.projectiles.duplicate(true), "echo_history": game.hazards.echo_history.duplicate(true), "echo_position": game.hazards.echo_position, "echo_visible": game.hazards.echo_visible, "platforms": platform_state, "gates": gate_state}


func _check(condition: bool, label: String) -> void:
	assertions += 1
	if condition:
		print("PASS: " + label)
	else:
		failures += 1
		push_error("FAIL: " + label)

