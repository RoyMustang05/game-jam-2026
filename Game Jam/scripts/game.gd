extends Node2D
## Director: owns the single simulation clock and rebuilds the world per room.
## Everything under `world` advances on world time; UI always uses unscaled delta.
signal player_died(reason: String)
signal level_completed(index: int)
signal checkpoint_reached(index: int)

const PlayerScript = preload("res://scripts/actors/player.gd")
const DragonScript = preload("res://scripts/actors/dragon.gd")
const Hazards = preload("res://scripts/world/hazards.gd")
const Mechanisms = preload("res://scripts/world/mechanisms.gd")
const Atmosphere = preload("res://scripts/world/atmosphere.gd")
const Crushers = preload("res://scripts/world/crushers.gd")
const MenuScreen = preload("res://scripts/ui/menu_screen.gd")
const LevelGeometry = preload("res://scripts/ui/level_geometry.gd")
const WorldLabels = preload("res://scripts/ui/world_labels.gd")
const Hud = preload("res://scripts/ui/hud.gd")
const SoundBank = preload("res://scripts/systems/sound_bank.gd")
const InputBindings = preload("res://scripts/systems/input_bindings.gd")

const Cinematic = preload("res://scripts/ui/cinematic.gd")
const TravelerLayer = preload("res://scripts/ui/traveler_layer.gd")

const ROOM_COUNT: int = 4
const WORLD_SIZE = Vector2i(320, 180)
const DEFAULT_HEIGHT: float = 180.0
const INTRO_TIME: float = 3.0
const BOSS_TIME_BUDGET: float = 130.0
const DASH_TIME_COST: float = 2.0
const ATTACK_WINDOW: float = 0.3
const ATTACK_COOLDOWN: float = 0.48

# --- Scene graph -------------------------------------------------------------
var world: Node2D
var world_viewport: SubViewport
var camera: Camera2D
var menu_screen: Node2D
var world_labels: Node2D
var hud: Node2D
var geometry: Node2D
var cinematic: Node2D
var prepared_room: PackedScene
var blocked_actions: Array[String] = []
var input_guard_frames: int = 0
var sound_bank: Node

# --- Room contents (rebuilt by load_level) -----------------------------------
var authored_room: Node2D
var player: CharacterBody2D
var hazards: Node2D
var mechanisms: Node2D
var atmosphere: Node2D
var crushers: Node2D
var dragon: Node2D
var goal_area: Area2D
var platforms: Array = []
var data: Dictionary = {}

# --- Run state ---------------------------------------------------------------
var state: String = "menu"
var level_index: int = 0
var chapter_index: int = 0
var playtest_room_path: String = ""
var frozen: bool = true
var paused: bool = false
var goal_pending: bool = false
var death_reason: String = ""
var remaining: float = 20.0
var level_world: float = 0.0
var field_multiplier: float = 1.0

# --- Checkpoints -------------------------------------------------------------
var checkpoint_index: int = -1
var checkpoint_position := Vector2.ZERO
var checkpoint_remaining: float = 90.0
var boss_checkpoint: bool = false

# --- Melee -------------------------------------------------------------------
var attack_left: float = 0.0
var attack_cooldown: float = 0.0
var attack_id: int = 0

# --- Run totals (completion screen) ------------------------------------------
var total_world: float = 0.0
var total_real: float = 0.0
var total_distance: float = 0.0
var total_deaths: int = 0
var total_dash_cost: float = 0.0
var total_dashes: int = 0
var par_by_room: Dictionary = {}

# --- Presentation timers (unscaled) ------------------------------------------
var ui_time: float = 0.0
var intro_left: float = 0.0
var transition_lock: float = 0.0
var anchor_flash: float = 0.0
var death_flash: float = 0.0
var dash_flash: float = 0.0
var death_position := Vector2.ZERO
var death_screen_position := Vector2.ZERO

# --- Headless test hooks -----------------------------------------------------
var test_mode: bool = false
var test_command: Dictionary = {}


func _ready() -> void:
	InputBindings.register()
	_build_render_stack()
	_build_interface()
	sound_bank = SoundBank.new()
	add_child(sound_bank)
	menu_screen.queue_redraw()


## Only the world is rasterized at 320x180. The root canvas keeps these logical
## coordinates but renders UI/font outlines at the window resolution.
func _build_render_stack() -> void:
	get_window().content_scale_aspect = Window.CONTENT_SCALE_ASPECT_KEEP
	world_viewport = SubViewport.new()
	world_viewport.size = WORLD_SIZE
	world_viewport.world_2d = World2D.new()
	world_viewport.canvas_item_default_texture_filter = Viewport.DEFAULT_CANVAS_ITEM_TEXTURE_FILTER_NEAREST
	world_viewport.snap_2d_transforms_to_pixel = true
	world_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(world_viewport)
	var world_image := Sprite2D.new()
	world_image.texture = world_viewport.get_texture()
	world_image.centered = false
	world_image.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	world_image.z_index = -1
	add_child(world_image)
	world = Node2D.new()
	world_viewport.add_child(world)
	camera = Camera2D.new()
	camera.enabled = false
	camera.position_smoothing_enabled = true
	camera.position_smoothing_speed = 7.0
	camera.process_callback = Camera2D.CAMERA2D_PROCESS_IDLE
	world_viewport.add_child(camera)


func _build_interface() -> void:
	menu_screen = MenuScreen.new()
	menu_screen.game = self
	add_child(menu_screen)
	var traveler_layer := TravelerLayer.new()
	traveler_layer.game = self
	add_child(traveler_layer)
	var interface_layer := CanvasLayer.new()
	add_child(interface_layer)
	world_labels = WorldLabels.new()
	world_labels.game = self
	interface_layer.add_child(world_labels)
	hud = Hud.new()
	hud.game = self
	interface_layer.add_child(hud)
	cinematic = Cinematic.new()
	cinematic.game = self
	interface_layer.add_child(cinematic)


func _unhandled_input(event: InputEvent) -> void:
	if state == "menu" and menu_screen.editor_panel.visible:
		return
	if state == "portal":
		get_viewport().set_input_as_handled()
		return
	if state == "story":
		if event is InputEventKey and event.echo:
			return
		if event.is_action_pressed("pause_game"):
			cinematic.finish_story()
		elif event.is_action_pressed("confirm"):
			cinematic.advance_story()
		get_viewport().set_input_as_handled()
		return
	if input_guard_frames > 0 or (event.is_action_pressed("pause_game") and "pause_game" in blocked_actions) or (event.is_action_pressed("restart") and "restart" in blocked_actions):
		get_viewport().set_input_as_handled()
		return
	if event is InputEventKey and event.echo:
		return
	if event.is_action_pressed("pause_game") and state == "playing":
		paused = not paused
		get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed("restart") and state == "playing":
		paused = false
		die("TIMELINE RESET")
		return
	if event.is_action_pressed("confirm") and transition_lock <= 0.0:
		confirm()


func confirm() -> void:
	if paused:
		paused = false
	elif state == "menu":
		start_new_game()
	elif state == "complete":
		start_run()
	elif state == "clear":
		load_level(level_index)


func start_new_game() -> void:
	# Story belongs exclusively to the main-menu new-game entry point.
	_reset_run_totals()
	cinematic.start_story()
	menu_screen.queue_redraw()


func consume_cinematic_input() -> void:
	input_guard_frames = 2
	blocked_actions.clear()
	for action: String in InputBindings.BINDINGS:
		if Input.is_action_pressed(action):
			blocked_actions.append(action)


func _gameplay_command() -> Dictionary:
	if test_mode:
		return test_command
	for i in range(blocked_actions.size() - 1, -1, -1):
		if not Input.is_action_pressed(blocked_actions[i]):
			blocked_actions.remove_at(i)
	if blocked_actions.is_empty():
		return {}
	return {
		"axis": _held("move_right") - _held("move_left"),
		"vertical": _held("move_down") - _held("move_up"),
		"jump": _pressed("jump"), "jump_held": bool(_held("jump")),
		"dash": _pressed("dash"), "freeze_air": bool(_held("focus")),
		"attack": _pressed("attack"),
	}


func _held(action: String) -> float:
	return 1.0 if action not in blocked_actions and Input.is_action_pressed(action) else 0.0


func _pressed(action: String) -> bool:
	return action not in blocked_actions and Input.is_action_just_pressed(action)


func start_run() -> void:
	_reset_run_totals()
	load_level(0)


func _reset_run_totals() -> void:
	boss_checkpoint = false
	total_world = 0.0
	total_real = 0.0
	total_distance = 0.0
	total_deaths = 0
	total_dash_cost = 0.0
	total_dashes = 0
	par_by_room.clear()


## Sum of the par times of every room reached this run; used for the final rank.
func total_par_time() -> float:
	var total: float = 0.0
	for par: float in par_by_room.values():
		total += par
	return total


# =============================================================================
# Room construction
# =============================================================================

func load_level(index: int, from_checkpoint: bool = false) -> void:
	_clear_world()
	level_index = index
	attack_left = 0.0
	attack_cooldown = 0.0
	if not from_checkpoint:
		boss_checkpoint = false
	_instance_room(index)
	_reset_room_state(from_checkpoint)
	_build_geometry_layer()
	_build_bounds()
	_build_platforms()
	_build_systems()
	_build_goal()
	_focus_camera()
	menu_screen.queue_redraw()


func _clear_world() -> void:
	for child in world.get_children():
		world.remove_child(child)
		child.queue_free()
	platforms.clear()
	world.position = Vector2.ZERO


func _instance_room(index: int) -> void:
	var room_path: String = playtest_room_path if not playtest_room_path.is_empty() else "res://rooms/room_%02d.tscn" % (index + 1)
	var room_scene: PackedScene = prepared_room if prepared_room != null else load(room_path)
	prepared_room = null
	authored_room = room_scene.instantiate()
	world.add_child(authored_room)
	data = authored_room.to_data()
	if not playtest_room_path.is_empty():
		level_index = int(data.room)
	chapter_index = int(data.chapter)
	par_by_room[level_index] = float(data.get("par_time", 60.0))
	authored_room.activate_runtime()


func _reset_room_state(from_checkpoint: bool) -> void:
	remaining = float(data.time_limit)
	if from_checkpoint:
		remaining = checkpoint_remaining
	else:
		checkpoint_index = -1
		checkpoint_position = data.spawn
		checkpoint_remaining = remaining
	level_world = 0.0
	frozen = true
	paused = false
	goal_pending = false
	state = "playing"
	intro_left = 0.0 if from_checkpoint else INTRO_TIME
	transition_lock = 0.18


func _build_geometry_layer() -> void:
	geometry = LevelGeometry.new()
	geometry.z_index = -10
	geometry.game = self
	world.add_child(geometry)


func _build_bounds() -> void:
	var height: float = _room_height()
	_make_solid(Rect2(-12, -100, 12, height + 240))
	_make_solid(Rect2(float(data.width), -100, 12, height + 240))
	_make_solid(Rect2(0, -20, float(data.width), 20))


func _build_platforms() -> void:
	for spec: Dictionary in data.platforms:
		var entry: Dictionary = spec.duplicate(true)
		entry["travel"] = float(entry.get("phase", 0.0)) * 2.0
		entry["pos"] = _path_position(entry)
		entry["body"] = _make_solid(Rect2(Vector2(entry.pos) - Vector2(entry.size) / 2.0, Vector2(entry.size)))
		platforms.append(entry)


func _build_systems() -> void:
	hazards = Hazards.new()
	world.add_child(hazards)
	# Hazards replay from the active checkpoint, not from the authored spawn.
	var timeline_data: Dictionary = data.duplicate(true)
	timeline_data.spawn = checkpoint_position
	hazards.setup(timeline_data, chapter_index)
	mechanisms = Mechanisms.new()
	world.add_child(mechanisms)
	mechanisms.setup(data)
	mechanisms.set_checkpoint(checkpoint_index, checkpoint_position)
	player = PlayerScript.new()
	player.costume = chapter_index
	player.high_resolution = true
	world.add_child(player)
	player.reset_at(checkpoint_position)
	atmosphere = Atmosphere.new()
	world.add_child(atmosphere)
	atmosphere.z_index = -5
	atmosphere.setup(data)
	crushers = Crushers.new()
	world.add_child(crushers)
	crushers.setup(data.get("crushers", []))
	dragon = null
	if _is_boss_room():
		dragon = DragonScript.new()
		world.add_child(dragon)
		dragon.setup(data.arena)
		if boss_checkpoint:
			_start_boss()


func _build_goal() -> void:
	goal_area = Area2D.new()
	goal_area.position = data.goal
	goal_area.collision_layer = 0
	goal_area.collision_mask = 2
	var goal_shape := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = Vector2(18, 28)
	goal_shape.shape = shape
	goal_shape.position.y = -14
	goal_area.add_child(goal_shape)
	world.add_child(goal_area)
	goal_area.body_entered.connect(_on_goal_body)


func _focus_camera() -> void:
	camera.enabled = true
	camera.limit_left = 0
	camera.limit_top = -28
	camera.limit_right = int(data.width)
	camera.limit_bottom = int(_room_height()) + 16
	camera.position = player.position + Vector2(25, -25)
	camera.reset_smoothing()
	camera.force_update_scroll()
	if is_instance_valid(dragon) and dragon.active:
		_arena_camera()


func _make_solid(rect: Rect2) -> StaticBody2D:
	var body := StaticBody2D.new()
	body.collision_layer = 1
	body.collision_mask = 2
	body.position = rect.get_center()
	var collider := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = rect.size
	collider.shape = shape
	body.add_child(collider)
	world.add_child(body)
	return body


func _room_height() -> float:
	return float(data.get("height", DEFAULT_HEIGHT))


func _is_boss_room() -> bool:
	return bool(data.get("boss", false))


func _on_goal_body(body: Node2D) -> void:
	if body == player and state == "playing":
		goal_pending = true


# =============================================================================
# Frames
# =============================================================================

func _process(delta: float) -> void:
	ui_time += delta
	transition_lock = maxf(0.0, transition_lock - delta)
	death_flash = maxf(0.0, death_flash - delta * 2.8)
	dash_flash = maxf(0.0, dash_flash - delta)
	anchor_flash = maxf(0.0, anchor_flash - delta)
	intro_left = maxf(0.0, intro_left - delta)
	if state == "playing" and not paused and input_guard_frames == 0:
		total_real += delta
	if state == "playing" and is_instance_valid(player):
		if is_instance_valid(dragon) and dragon.active:
			_arena_camera()
		else:
			camera.position = player.position + Vector2(player.facing * 25, -25)
		camera.offset = Vector2(roundf(sin(ui_time * 160.0) * death_flash * 1.5), 0)
	if is_instance_valid(geometry):
		geometry.queue_redraw()
	world_labels.queue_redraw()
	hud.queue_redraw()
	if state == "menu" or state == "complete":
		menu_screen.queue_redraw()


func _physics_process(delta: float) -> void:
	if state != "playing" or paused:
		return
	if input_guard_frames > 0:
		input_guard_frames -= 1
		return
	var command: Dictionary = _gameplay_command()
	mechanisms.pre_player(player)
	var committed: bool = _step_melee(delta, command)
	var result: Dictionary = player.step(delta, command)
	_account_for_movement(result)
	var was_frozen: bool = frozen
	frozen = not (bool(result.moving) or committed)
	if frozen and not was_frozen:
		_play("freeze")
	# World time only exists while Milo moves; every other clock derives from it.
	var world_delta: float = 0.0 if frozen else delta
	remaining -= world_delta
	level_world += world_delta
	total_world += world_delta
	field_multiplier = mechanisms.time_field_multiplier(player)
	var object_delta: float = world_delta * field_multiplier
	_move_platforms(object_delta)
	var interaction: Dictionary = mechanisms.world_step(object_delta, player)
	if bool(interaction.get("bounced", false)):
		_play("bounce")
	if bool(interaction.get("barrier_broken", false)):
		_play("break")
	var touched: bool = hazards.world_step(object_delta, player, world_delta)
	atmosphere.world_step(object_delta)
	var lethal: bool = crushers.world_step(object_delta, player)
	if is_instance_valid(dragon):
		var boss: Dictionary = _step_boss(world_delta)
		if bool(boss.complete):
			finish_level()
			return
		lethal = lethal or bool(boss.dead)
	if _resolve_death(lethal, interaction, touched):
		return
	_resolve_checkpoint(interaction)
	if hazards.bounced:
		_play("bounce")
	_resolve_goal()


## Advances the melee swing. Returns true while the swing itself keeps world
## time running, so a stationary strike still costs the player time.
func _step_melee(delta: float, command: Dictionary) -> bool:
	attack_cooldown = maxf(0.0, attack_cooldown - delta)
	var pressed: bool = bool(command.get("attack", false)) if not command.is_empty() else Input.is_action_just_pressed("attack")
	if pressed and attack_cooldown <= 0.0:
		attack_left = ATTACK_WINDOW
		attack_cooldown = ATTACK_COOLDOWN
		attack_id += 1
		_play("strike")
	var committed: bool = attack_left > 0.0
	attack_left = maxf(0.0, attack_left - delta)
	player.melee_pose = attack_left
	return committed


func _account_for_movement(result: Dictionary) -> void:
	if bool(result.dash_started):
		remaining -= DASH_TIME_COST
		total_dash_cost += DASH_TIME_COST
		total_dashes += 1
		dash_flash = 0.65
		_play("strike" if player.striking else "dash")
	elif not String(result.get("action", "")).is_empty():
		_play(String(result.action))
	total_distance += float(result.distance)


func _step_boss(world_delta: float) -> Dictionary:
	if not dragon.active:
		var arena := Rect2(data.arena)
		if player.position.x >= arena.position.x + 20 and player.position.y > arena.position.y:
			# The encounter also takes its first step on the activation frame.
			_start_boss()
		if not dragon.active:
			return {"dead": false, "complete": false}
	player.position.x = clampf(player.position.x, dragon.position.x + 6, dragon.position.x + 310)
	var strike: Dictionary = {}
	if attack_left > 0.08 and attack_left < 0.23:
		strike = {"id": attack_id, "rect": Rect2(player.position + Vector2(0 if player.facing > 0 else -27, -30), Vector2(27, 28))}
	var event: Dictionary = dragon.world_step(world_delta, player, strike)
	if dragon.state == "defeat":
		atmosphere.cool_after_defeat(dragon.age / 2.0)
	if event.hit:
		_play("break")
	if event.refill:
		_play("anchor")
	return {"dead": bool(event.dead), "complete": bool(event.complete)}


func _resolve_death(lethal: bool, interaction: Dictionary, touched: bool) -> bool:
	if remaining <= 0.0:
		die("TIME EXPIRED")
		return true
	if player.position.y > _room_height() + 20.0:
		die("LOST IN TIME")
		return true
	if lethal or bool(interaction.get("dead", false)) or (touched and not player.can_phase()):
		die("TIMELINE BROKEN")
		return true
	return false


func _resolve_checkpoint(interaction: Dictionary) -> void:
	if int(interaction.get("anchor", -1)) <= checkpoint_index:
		return
	checkpoint_index = int(interaction.anchor)
	checkpoint_position = interaction.anchor_pos
	checkpoint_remaining = maxf(remaining, float(data.get("retry_budget", 60.0)))
	remaining = checkpoint_remaining
	anchor_flash = 1.2
	checkpoint_reached.emit(checkpoint_index)
	_play("anchor")


func _resolve_goal() -> void:
	if _is_boss_room():
		return
	# An explicit rectangle check avoids delayed Area notifications after instant restarts.
	var goal_rect := Rect2(Vector2(data.goal) + Vector2(-9, -28), Vector2(18, 28))
	var player_rect := Rect2(player.position + Vector2(-4, -14), Vector2(8, 14))
	if goal_pending or goal_rect.intersects(player_rect):
		finish_level()


# =============================================================================
# Boss, camera and platforms
# =============================================================================

func _arena_camera() -> void:
	camera.position = dragon.position + Vector2(160, 72)
	camera.limit_left = int(dragon.position.x)
	camera.limit_right = int(dragon.position.x) + 320
	camera.reset_smoothing()
	camera.force_update_scroll()


func _start_boss() -> void:
	boss_checkpoint = true
	checkpoint_index = 0
	checkpoint_position = Vector2(data.arena.position) + Vector2(26, 144)
	checkpoint_remaining = BOSS_TIME_BUDGET
	remaining = BOSS_TIME_BUDGET
	player.refill_at_anchor()
	# Approach shots cannot enter an arena attempt.
	hazards.projectiles.clear()
	hazards.watchers.clear()
	hazards.spikes.clear()
	dragon.start(player)
	intro_left = 0.0
	_arena_camera()


func _path_position(entry: Dictionary) -> Vector2:
	var phase: float = fposmod(float(entry.travel), 2.0)
	var weight: float = phase if phase <= 1.0 else 2.0 - phase
	return Vector2(entry.a).lerp(Vector2(entry.b), weight)


func _move_platforms(dt: float) -> void:
	if dt <= 0.0:
		return
	for entry: Dictionary in platforms:
		var old_pos: Vector2 = entry.pos
		var length: float = maxf(Vector2(entry.a).distance_to(Vector2(entry.b)), 1.0)
		entry.travel = float(entry.travel) + dt * float(entry.speed) / length
		var new_pos: Vector2 = _path_position(entry)
		var size: Vector2 = entry.size
		var on_top: bool = absf(player.position.y - (old_pos.y - size.y / 2.0)) < 1.1 and absf(player.position.x - old_pos.x) < size.x / 2.0 + 3.0 and player.velocity.y >= 0.0
		entry.pos = new_pos
		entry.body.position = new_pos
		if on_top:
			player.position += new_pos - old_pos


# =============================================================================
# Outcomes
# =============================================================================

func die(reason: String) -> void:
	if state != "playing":
		return
	total_deaths += 1
	death_reason = reason
	death_position = player.position
	death_screen_position = player.position - camera.get_screen_center_position() + Vector2(160, 90)
	death_flash = 1.0
	_play("hit")
	player_died.emit(reason)
	load_level(level_index, true)


func finish_level() -> void:
	if state != "playing":
		return
	state = "clear" if not playtest_room_path.is_empty() else ("complete" if level_index == ROOM_COUNT - 1 else "portal")
	player.play_finish()
	frozen = true
	transition_lock = 0.3
	level_completed.emit(level_index)
	if state == "portal":
		cinematic.start_portal()
	else:
		_play("goal")


func _play(sound_name: String) -> void:
	if test_mode:
		return
	sound_bank.play(sound_name)


## Fraction of the authored route Milo has covered, for the HUD progress line.
func route_progress() -> float:
	var route: Array = data.get("waypoints", [])
	if route.size() < 2:
		return clampf(player.position.distance_to(Vector2(data.spawn)) / maxf(Vector2(data.goal).distance_to(Vector2(data.spawn)), 1.0), 0.0, 1.0)
	var total_length: float = 0.0
	var nearest: float = INF
	var traveled: float = 0.0
	for i in range(route.size() - 1):
		var a: Vector2 = route[i]
		var b: Vector2 = route[i + 1]
		var span: Vector2 = b - a
		var weight: float = clampf((player.position - a).dot(span) / maxf(span.length_squared(), 1.0), 0.0, 1.0)
		var distance: float = player.position.distance_squared_to(a + span * weight)
		if distance < nearest:
			nearest = distance
			traveled = total_length + span.length() * weight
		total_length += span.length()
	return clampf(traveled / maxf(total_length, 1.0), 0.0, 1.0)
