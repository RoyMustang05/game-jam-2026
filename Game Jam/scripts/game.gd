extends Node2D
## The only simulation clock lives here. UI always uses unscaled delta.
signal player_died(reason: String)
signal level_completed(index: int)
signal checkpoint_reached(index: int)

const PlayerScript = preload("res://scripts/player.gd")
const Levels = preload("res://scripts/levels.gd")
const Hazards = preload("res://scripts/hazards.gd")
const Mechanisms = preload("res://scripts/mechanisms.gd")
const ROOM_COUNT: int = 4
const INK = Color("0d1013")
const WHITE = Color("f8f8f2")
const CYAN = Color("61e7ff")
const PINK = Color("ff5fcb")
const RED = Color("ff5a67")
const GOLD = Color("ffd15c")
const MUTED = Color("75818c")

var playtest_room_path: String = ""
var authored_room: Node2D
var atmosphere: Node2D
var crushers: Node2D
var dragon: Node2D
var boss_checkpoint: bool = false
var attack_left: float = 0.0
var attack_cooldown: float = 0.0
var attack_id: int = 0

var state: String = "menu"
var level_index: int = 0
var chapter_index: int = 0
var data: Dictionary = {}
var world: Node2D
var geometry: Node2D
var player: CharacterBody2D
var hazards: Node2D
var hud: Node2D
var camera: Camera2D
var mechanisms: Node2D
var platforms: Array = []
var goal_area: Area2D
var remaining: float = 20.0
var level_world: float = 0.0
var total_world: float = 0.0
var total_real: float = 0.0
var total_distance: float = 0.0
var total_deaths: int = 0
var total_dash_cost: float = 0.0
var total_dashes: int = 0
var checkpoint_index: int = -1
var checkpoint_position := Vector2.ZERO
var checkpoint_remaining: float = 90.0
var anchor_flash: float = 0.0
var field_multiplier: float = 1.0
var death_position := Vector2.ZERO
var death_screen_position := Vector2.ZERO
var frozen: bool = true
var paused: bool = false
var ui_time: float = 0.0
var death_flash: float = 0.0
var dash_flash: float = 0.0
var intro_left: float = 0.0
var transition_lock: float = 0.0
var death_reason: String = ""
var camera_x: float = 0.0
var goal_pending: bool = false
var test_mode: bool = false
var test_command: Dictionary = {}
var sfx: AudioStreamPlayer
var sounds: Dictionary = {}
var font: Font = ThemeDB.fallback_font

func _ready() -> void:
	_register_inputs()
	world = Node2D.new()
	add_child(world)
	camera = Camera2D.new()
	camera.enabled = false
	camera.position_smoothing_enabled = true
	camera.position_smoothing_speed = 7.0
	camera.process_callback = Camera2D.CAMERA2D_PROCESS_IDLE
	add_child(camera)
	var interface_layer := CanvasLayer.new()
	add_child(interface_layer)
	hud = Node2D.new()
	interface_layer.add_child(hud)
	hud.draw.connect(_draw_hud)
	sfx = AudioStreamPlayer.new()
	sfx.volume_db = -20.0
	add_child(sfx)
	_make_sounds()
	queue_redraw()

func _register_inputs() -> void:
	var bindings: Dictionary = {"attack": [KEY_J], "move_left": [KEY_A, KEY_LEFT], "move_right": [KEY_D, KEY_RIGHT], "move_up": [KEY_W, KEY_UP], "move_down": [KEY_S, KEY_DOWN], "focus": [KEY_X], "jump": [KEY_SPACE, KEY_W, KEY_UP], "dash": [KEY_SHIFT], "restart": [KEY_R], "pause_game": [KEY_ESCAPE], "confirm": [KEY_ENTER, KEY_SPACE]}
	for action: String in bindings:
		if not InputMap.has_action(action):
			InputMap.add_action(action)
		for key: int in bindings[action]:
			var event := InputEventKey.new()
			event.physical_keycode = key
			InputMap.action_add_event(action, event)

func _unhandled_input(event: InputEvent) -> void:
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
	elif state == "menu" or state == "complete":
		start_run()
	elif state == "clear":
		load_level(level_index if not playtest_room_path.is_empty() else level_index + 1)

func start_run() -> void:
	boss_checkpoint = false
	total_world = 0.0
	total_real = 0.0
	total_distance = 0.0
	total_deaths = 0
	total_dash_cost = 0.0
	total_dashes = 0
	load_level(0)

func load_level(index: int, from_checkpoint: bool = false) -> void:
	for child in world.get_children():
		world.remove_child(child)
		child.queue_free()
	platforms.clear()
	world.position = Vector2.ZERO
	level_index = index
	attack_left = 0
	attack_cooldown = 0
	if not from_checkpoint: boss_checkpoint = false
	chapter_index = index / 2
	var room_path: String = playtest_room_path if not playtest_room_path.is_empty() else "res://rooms/room_%02d.tscn" % (index+1)
	authored_room = load(room_path).instantiate()
	world.add_child(authored_room)
	data = authored_room.to_data()
	if not playtest_room_path.is_empty(): level_index = int(data.room)
	chapter_index = int(data.chapter)
	authored_room.activate_runtime()
	remaining = float(data.time_limit)
	if not from_checkpoint:
		checkpoint_index = -1
		checkpoint_position = data.spawn
		checkpoint_remaining = remaining
	else:
		remaining = checkpoint_remaining
	level_world = 0.0
	frozen = true
	paused = false
	goal_pending = false
	state = "playing"
	intro_left = 0.0 if from_checkpoint else 3.0
	transition_lock = 0.18
	geometry = Node2D.new()
	geometry.z_index = -10
	world.add_child(geometry)
	geometry.draw.connect(_draw_level)
	_make_solid(Rect2(-12, -100, 12, float(data.get("height", 180)) + 240))
	_make_solid(Rect2(float(data.width), -100, 12, float(data.get("height", 180)) + 240))
	_make_solid(Rect2(0, -20, float(data.width), 20))
	for spec: Dictionary in data.platforms:
		var entry: Dictionary = spec.duplicate(true)
		entry["travel"] = float(entry.get("phase", 0.0)) * 2.0
		entry["pos"] = _path_position(entry)
		entry["body"] = _make_solid(Rect2(Vector2(entry.pos) - Vector2(entry.size) / 2.0, Vector2(entry.size)))
		platforms.append(entry)
	hazards = Hazards.new()
	world.add_child(hazards)
	var timeline_data: Dictionary = data.duplicate(true)
	timeline_data.spawn = checkpoint_position
	hazards.setup(timeline_data, chapter_index)
	mechanisms = Mechanisms.new()
	world.add_child(mechanisms)
	mechanisms.setup(data)
	mechanisms.set_checkpoint(checkpoint_index, checkpoint_position)
	player = PlayerScript.new()
	world.add_child(player)
	player.reset_at(checkpoint_position)
	atmosphere = preload("res://scripts/atmosphere.gd").new()
	world.add_child(atmosphere)
	atmosphere.z_index = -5
	atmosphere.setup(data)
	crushers = preload("res://scripts/crushers.gd").new()
	world.add_child(crushers)
	crushers.setup(data.get("crushers",[]))
	dragon = null
	if bool(data.get("boss",false)):
		dragon = preload("res://scripts/dragon.gd").new()
		world.add_child(dragon)
		dragon.setup(data.arena)
		if boss_checkpoint: _start_boss()
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
	camera.enabled = true
	camera.limit_left = 0
	camera.limit_top = -28
	camera.limit_right = int(data.width)
	camera.limit_bottom = int(data.get("height", 180)) + 16
	camera.position = player.position + Vector2(25, -25)
	camera.reset_smoothing()
	camera.force_update_scroll()
	if is_instance_valid(dragon) and dragon.active: _arena_camera()
	queue_redraw()

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

func _on_goal_body(body: Node2D) -> void:
	if body == player:
		goal_pending = true

func _process(delta: float) -> void:
	ui_time += delta
	transition_lock = maxf(0.0, transition_lock - delta)
	death_flash = maxf(0.0, death_flash - delta * 2.8)
	dash_flash = maxf(0.0, dash_flash - delta)
	anchor_flash = maxf(0.0, anchor_flash - delta)
	intro_left = maxf(0.0, intro_left - delta)
	if state == "playing" or state == "clear":
		total_real += delta
	if state == "playing" and is_instance_valid(player):
		if is_instance_valid(dragon) and dragon.active: _arena_camera()
		else: camera.position = player.position + Vector2(player.facing * 25, -25)
		camera.offset = Vector2(roundf(sin(ui_time * 160.0) * death_flash * 1.5), 0)
	if is_instance_valid(geometry):
		geometry.queue_redraw()
	hud.queue_redraw()
	if state == "menu" or state == "complete":
		queue_redraw()

func _physics_process(delta: float) -> void:
	if state != "playing" or paused:
		return
	var command: Dictionary = test_command if test_mode else {}
	mechanisms.pre_player(player)
	attack_cooldown = maxf(0,attack_cooldown-delta)
	var attack_pressed: bool = bool(command.get("attack",false)) if test_mode else Input.is_action_just_pressed("attack")
	if attack_pressed and attack_cooldown <= 0:
		attack_left = 0.3
		attack_cooldown = 0.48
		attack_id += 1
		_play("strike")
	var committed: bool = attack_left > 0
	attack_left = maxf(0,attack_left-delta)
	player.melee_pose = attack_left
	var result: Dictionary = player.step(delta, command)
	if bool(result.dash_started):
		remaining -= 2.0
		total_dash_cost += 2.0
		total_dashes += 1
		dash_flash = 0.65
		_play("strike" if player.striking else "dash")
	elif not String(result.get("action", "")).is_empty():
		_play(String(result.action))
	var was_frozen: bool = frozen
	frozen = not (bool(result.moving) or committed)
	var world_delta: float = 0.0 if frozen else delta
	if frozen and not was_frozen:
		_play("freeze")
	remaining -= world_delta
	level_world += world_delta
	total_world += world_delta
	total_distance += float(result.distance)
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
	var crushed: bool = crushers.world_step(object_delta,player)
	if is_instance_valid(dragon):
		if not dragon.active and player.position.x >= Rect2(data.arena).position.x+20 and player.position.y > Rect2(data.arena).position.y:
			_start_boss()
		if dragon.active:
			player.position.x = clampf(player.position.x,dragon.position.x+6,dragon.position.x+310)
			var strike: Dictionary = {}
			if attack_left > 0.08 and attack_left < 0.23:
				strike = {"id":attack_id,"rect":Rect2(player.position+Vector2(0 if player.facing > 0 else -27,-30),Vector2(27,28))}
			var event: Dictionary = dragon.world_step(world_delta,player,strike)
			if dragon.state == "defeat": atmosphere.cool_after_defeat(dragon.age/2.0)
			if event.dead: crushed = true
			if event.hit: _play("break")
			if event.refill: _play("anchor")
			if event.complete:
				finish_level()
				return
	if remaining <= 0.0:
		die("TIME EXPIRED")
		return
	if player.position.y > float(data.get("height", 180)) + 20.0:
		die("LOST IN TIME")
		return
	if crushed or bool(interaction.get("dead", false)) or (touched and not player.can_phase()):
		die("TIMELINE BROKEN")
		return
	if int(interaction.get("anchor", -1)) > checkpoint_index:
		checkpoint_index = int(interaction.anchor)
		checkpoint_position = interaction.anchor_pos
		checkpoint_remaining = maxf(remaining, float(data.get("retry_budget",60.0)))
		remaining = checkpoint_remaining
		anchor_flash = 1.2
		checkpoint_reached.emit(checkpoint_index)
		_play("anchor")
	if hazards.bounced:
		_play("bounce")
	# An explicit rectangle check avoids delayed Area notifications after instant restarts.
	var goal_rect := Rect2(Vector2(data.goal) + Vector2(-9, -28), Vector2(18, 28))
	var player_rect := Rect2(player.position + Vector2(-4, -14), Vector2(8, 14))
	if not bool(data.get("boss",false)) and (goal_pending or goal_rect.intersects(player_rect)):
		finish_level()

func _arena_camera() -> void:
	camera.position = dragon.position+Vector2(160,72)
	camera.limit_left = int(dragon.position.x)
	camera.limit_right = int(dragon.position.x)+320
	camera.reset_smoothing()
	camera.force_update_scroll()

func _start_boss() -> void:
	boss_checkpoint = true
	checkpoint_index = 0
	checkpoint_position = Vector2(data.arena.position)+Vector2(26,144)
	checkpoint_remaining = 130.0
	remaining = 130.0
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
	state = "complete" if level_index == ROOM_COUNT - 1 else "clear"
	player.play_finish()
	frozen = true
	transition_lock = 0.3
	level_completed.emit(level_index)
	_play("goal")

func _text(canvas: Node2D, pos: Vector2, value: String, size: int = 8, color: Color = WHITE) -> void:
	canvas.draw_string(font, pos, value, HORIZONTAL_ALIGNMENT_LEFT, -1, size, color)

func _center(canvas: Node2D, y: float, value: String, size: int = 8, color: Color = WHITE) -> void:
	var length: float = font.get_string_size(value, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
	_text(canvas, Vector2(roundf((320.0 - length) / 2.0), y), value, size, color)

func _draw() -> void:
	if state != "menu":
		return
	draw_rect(Rect2(0, 0, 320, 180), INK)
	for x in range(0, 320, 16):
		draw_line(Vector2(x, 0), Vector2(x, 180), Color("131a20"))
	for y in range(0, 180, 16):
		draw_line(Vector2(0, y), Vector2(320, y), Color("131a20"))
	# A fractured clock, drawn with square-edged strokes and intentional gaps.
	var origin := Vector2(253, 81)
	for n in range(12):
		var a: float = float(n) * TAU / 12.0 - PI / 2.0
		var direction := Vector2(cos(a), sin(a))
		draw_line((origin + direction * 49.0).round(), (origin + direction * 53.0).round(), CYAN if n % 3 == 0 else Color("354653"), 2)
	draw_arc(origin, 43, 0.3, 3.0, 18, Color("314650"), 1)
	draw_arc(origin + Vector2(3, -3), 43, 3.5, 5.9, 16, PINK, 1)
	draw_line(origin, origin + Vector2(0, -30), WHITE, 2)
	draw_line(origin, origin + Vector2(22, 12), CYAN, 2)
	draw_rect(Rect2(origin - Vector2(2, 2), Vector2(4, 4)), PINK)
	draw_rect(Rect2(15, 18, 4, 4), CYAN)
	_text(self, Vector2(24, 23), "CHRONOPHOBIA / FOUR FRACTURED EPOCHS", 7, MUTED)
	_text(self, Vector2(14, 65), "STILL", 31)
	_text(self, Vector2(91, 64), "//", 31, CYAN)
	_text(self, Vector2(14, 93), "MOVING", 31)
	draw_rect(Rect2(15, 102, 28, 2), PINK)
	_text(self, Vector2(15, 116), "THE TIME IS NOT YOURS.", 9, CYAN)
	_text(self, Vector2(15, 130), "Move to create time. Stop to survive.", 8)
	_text(self, Vector2(15, 151), "[ ENTER / SPACE ]  BEGIN", 9, GOLD)
	draw_line(Vector2(15, 160), Vector2(305, 160), Color("2a3540"))
	_text(self, Vector2(15, 172), "A D  MOVE   SPACE  JUMP   SHIFT  DASH   X  FOCUS", 7, MUTED)
	_text(self, Vector2(278, 151), "01 / 04", 7, CYAN)

func _draw_level() -> void:
	if data.is_empty():
		return
	for row_y in range(0, int(data.get("height", 180)), 160):
		geometry.draw_set_transform(Vector2(0, row_y))
		Levels.draw_environment(geometry, chapter_index, float(data.width), hazards.world_time)
	geometry.draw_set_transform(Vector2.ZERO)
	for entry: Dictionary in platforms:
		var a: Vector2 = entry.a
		var b: Vector2 = entry.b
		geometry.draw_dashed_line(a, b, Color("665a35"), 1, 3)
		geometry.draw_rect(Rect2(a - Vector2(1, 1), Vector2(3, 3)), GOLD)
		geometry.draw_rect(Rect2(b - Vector2(1, 1), Vector2(3, 3)), GOLD)
		var rect := Rect2(Vector2(entry.pos) - Vector2(entry.size) / 2, Vector2(entry.size))
		geometry.draw_rect(rect, Color("4a4e54"))
		geometry.draw_line(rect.position, Vector2(rect.end.x, rect.position.y), GOLD)
		for x in range(int(rect.position.x) + 2, int(rect.end.x) - 2, 6):
			geometry.draw_line(Vector2(x, rect.position.y + 2), Vector2(x + 2, rect.end.y), GOLD)
	if not bool(data.get("boss",false)):
		var goal: Vector2 = data.goal
		geometry.draw_rect(Rect2(goal + Vector2(-10, -29), Vector2(20, 29)), Color("142a30"))
		geometry.draw_rect(Rect2(goal + Vector2(-10, -29), Vector2(20, 29)), CYAN, false, 1)
		geometry.draw_rect(Rect2(goal + Vector2(-6, -25), Vector2(12, 25)), Color("214752"), false, 1)
		geometry.draw_line(goal + Vector2(-3, -18), goal + Vector2(3, -14), WHITE)
		geometry.draw_line(goal + Vector2(3, -14), goal + Vector2(-3, -10), WHITE)
		_text(geometry, goal + Vector2(-10, -34), "CORE" if level_index == 3 else "EXIT", 7, GOLD)
		if level_index == 3:
			geometry.draw_arc(goal + Vector2(0, -14), 23, 0.2, 6.0, 24, PINK, 1)
			geometry.draw_arc(goal + Vector2(0, -14), 27, 2.0, 4.9, 14, CYAN, 1)
	# Authored route turns remain readable when the camera cannot show the exit.
	var route: Array = data.get("waypoints", [])
	for i in range(route.size() - 1):
		var a: Vector2 = route[i]
		var b: Vector2 = route[i + 1]
		var direction: Vector2 = (b - a).normalized()
		var arrow: Vector2 = a + Vector2(0, -23)
		geometry.draw_line(arrow - direction * 3, arrow + direction * 3, Color("397482"))
		geometry.draw_line(arrow + direction * 3, arrow + direction.orthogonal() * 2, Color("397482"))
		geometry.draw_line(arrow + direction * 3, arrow - direction.orthogonal() * 2, Color("397482"))
	for sign_data: Dictionary in data.get("signs", []):
		var sign_pos: Vector2 = sign_data.pos
		var content: String = sign_data.text
		var sign_width: float = font.get_string_size(content, HORIZONTAL_ALIGNMENT_LEFT, -1, 7).x
		geometry.draw_rect(Rect2(sign_pos + Vector2(-3, -8), Vector2(sign_width + 6, 12)), Color(INK, 0.92))
		_text(geometry, sign_pos, content, 7, GOLD)
	# Sparse world particles share the exact simulation clock.
	for n in range(22):
		var x: float = fposmod(float(n * 71) + level_world * (2.0 + n % 3), float(data.width))
		var y: float = 47.0 + fposmod(float(n * 23) - level_world * 2.0, 92.0)
		geometry.draw_rect(Rect2(roundf(x), roundf(y), 1, 1), Color(CYAN, 0.3))

func _timer(value: float) -> String:
	var centis: int = maxi(0, int(ceil(value * 100.0)))
	return "%02d:%02d.%02d" % [centis / 6000, (centis / 100) % 60, centis % 100]

func _draw_hud() -> void:
	if state == "menu":
		return
	hud.draw_rect(Rect2(0, 0, 320, 28), INK)
	hud.draw_line(Vector2(8, 27), Vector2(312, 27), Color("263740"))
	_text(hud, Vector2(8, 8), "REMAINING", 6, MUTED)
	_text(hud, Vector2(8, 22), _timer(remaining), 14, RED if remaining < 5.0 else WHITE)
	_text(hud, Vector2(109, 11), "%02d / 04" % (level_index + 1), 7, GOLD)
	_text(hud, Vector2(109, 21), String(data.title), 7, WHITE)
	_text(hud, Vector2(249, 10), "TIME FROZEN" if frozen else "TIME MOVING", 8, CYAN if frozen else MUTED)
	_text(hud, Vector2(247, 22), "DASH", 6, MUTED)
	for i in range(2):
		var rect := Rect2(273 + i * 19, 16, 15, 6)
		hud.draw_rect(rect, CYAN if i < player.dash_charges else Color("263740"), i < player.dash_charges)
		if i < player.dash_charges:
			hud.draw_line(rect.position + Vector2(5, 1), rect.position + Vector2(8, 3), INK)
			hud.draw_line(rect.position + Vector2(8, 3), rect.position + Vector2(5, 5), INK)
	hud.draw_rect(Rect2(0, 164, 320, 16), INK)
	hud.draw_line(Vector2(8, 164), Vector2(312, 164), Color("263740"))
	_draw_epoch_icon(hud, Vector2(12, 172))
	_text(hud, Vector2(21, 175), String(data.epoch).to_upper(), 7, CYAN)
	_text(hud, Vector2(145, 175), "R RETRY", 7, MUTED)
	_text(hud, Vector2(196, 175), "X FOCUS", 7, MUTED)
	_text(hud, Vector2(253, 175), "ESC PAUSE", 7, MUTED)
	# Route progress is a quiet, continuous line above the footer.
	var progress: float = _route_progress()
	hud.draw_line(Vector2(8, 162), Vector2(8 + 304 * progress, 162), CYAN)
	if intro_left > 0.0 and state == "playing" and not paused:
		var w: float = minf(300.0, font.get_string_size(String(data.hint), HORIZONTAL_ALIGNMENT_LEFT, -1, 8).x + 14)
		hud.draw_rect(Rect2((320 - w) / 2, 33, w, 17), Color(INK, 0.93))
		_center(hud, 44, String(data.hint), 8, GOLD)
	if dash_flash > 0.0:
		_text(hud, Vector2(79, 21), "-2s", 8, PINK)
	if field_multiplier != 1.0:
		_text(hud, Vector2(214, 22), "x%.1f" % field_multiplier, 7, CYAN if field_multiplier < 1.0 else GOLD)
	elif player.extra_jumps > 0:
		hud.draw_rect(Rect2(228, 17, 3, 3), CYAN)
	if anchor_flash > 0.0:
		_center(hud, 58, "ANCHOR SET / DASHES RESTORED", 8, CYAN)
		hud.draw_rect(Rect2(0, 28, 320, 136), Color(CYAN, anchor_flash * 0.035))
	if death_flash > 0.0:
		hud.draw_rect(Rect2(0, 28, 320, 136), Color(RED, death_flash * 0.18))
		_center(hud, 62, death_reason, 8, RED)
		for i in range(9):
			var direction := Vector2(cos(float(i) * TAU / 9), sin(float(i) * TAU / 9))
			var p: Vector2 = death_screen_position + Vector2(0, -7) + direction * (1.0 - death_flash) * 30.0
			hud.draw_rect(Rect2(p.round(), Vector2(2, 2)), Color(WHITE if i % 3 == 0 else RED, death_flash))
	if is_instance_valid(dragon) and dragon.active:
		hud.draw_rect(Rect2(53,29,214,23),Color(INK,0.95))
		_center(hud,37,"PYRAX / THE LAST FLAME / II" if dragon.phase == 2 else "PYRAX / THE LAST FLAME / I",7,GOLD)
		for n in range(8): hud.draw_rect(Rect2(85+n*19,41,16,3),RED if n < dragon.health else Color("30333d"))
		var cue: String = {"prepare":"READ THE DRAGON / MOVE TO ADVANCE", "warning":["BREATH: HIGH LEDGE OR FAR LEFT","VOLLEY: SPACED LANES / FLOOR IS SAFE","CLAW: LEAVE THE GOLD MARK"][dragon.attack], "attack":["FIRE IS SOLID / USE HEIGHT","EMBER LANES / STOP TO PLAN","JUMP THE GROUND WAVE"][dragon.attack], "recover":"OPEN HEAD: J STRIKE / CYAN CELL REFILLS", "transition":"PHASE II / THE FURNACE AWAKENS", "defeat":"THE LAST FLAME FALLS"}.get(dragon.state,"")
		hud.draw_rect(Rect2(0,165,320,15),INK)
		_center(hud,175,cue,7,CYAN if dragon.state == "recover" else GOLD)
	if paused:
		_panel("PAUSED", "JUMP x2 Â· WALL + JUMP Â· DOWN + SHIFT", "ENTER / ESC  RESUME", CYAN)
		_center(hud, 149, "HOLD X IN AIR TO FREEZE AND PLAN", 7, CYAN)
	elif state == "clear":
		_panel("TIMELINE RESTORED", "%s  /  %.2fs active" % [String(data.title), level_world], "ENTER / SPACE  NEXT ROOM", GOLD)
	elif state == "complete":
		_draw_completion()

func _draw_epoch_icon(canvas: Node2D, p: Vector2) -> void:
	if chapter_index == 0:
		canvas.draw_polyline(PackedVector2Array([p + Vector2(-5, 4), p + Vector2(0, -5), p + Vector2(5, 4), p + Vector2(-5, 4)]), CYAN)
	elif chapter_index == 1:
		canvas.draw_rect(Rect2(p + Vector2(-5, -5), Vector2(10, 2)), CYAN)
		for x in [-3, 3]:
			canvas.draw_line(p + Vector2(x, -2), p + Vector2(x, 4), CYAN)
	elif chapter_index == 2:
		canvas.draw_rect(Rect2(p + Vector2(-4, -4), Vector2(8, 8)), GOLD, false)
		canvas.draw_rect(Rect2(p + Vector2(-1, -1), Vector2(2, 2)), CYAN)
	else:
		canvas.draw_line(p + Vector2(-4, -4), p + Vector2(1, 1), PINK, 2)
		canvas.draw_line(p + Vector2(4, -4), p + Vector2(-1, 4), CYAN, 2)

func _panel(title: String, detail: String, prompt: String, color: Color) -> void:
	hud.draw_rect(Rect2(0, 28, 320, 136), Color(INK, 0.85))
	hud.draw_rect(Rect2(36, 61, 248, 72), INK)
	hud.draw_line(Vector2(36, 61), Vector2(284, 61), color)
	_center(hud, 84, title, 15, color)
	_center(hud, 103, detail, 8)
	_center(hud, 121, prompt, 8, GOLD)

func _draw_completion() -> void:
	hud.draw_rect(Rect2(0, 0, 320, 180), INK)
	hud.draw_line(Vector2(20, 15), Vector2(300, 15), CYAN)
	_center(hud, 32, "THE LAST FLAME IS STILL", 13, WHITE)
	_center(hud, 46, "And for a moment, time belonged to you.", 8, CYAN)
	var par_time: float = 0.0
	for i in range(ROOM_COUNT):
		par_time += float(Levels.build(i).get("par_time", 60.0))
	var rank: String = "S / THE STILL POINT" if total_world <= par_time and total_deaths == 0 else ("A / TIME TRAVELER" if total_world <= par_time * 1.5 and total_deaths < 10 else "B / NEVER STOP TRYING")
	_center(hud, 64, rank, 10, GOLD)
	var labels: Array[String] = ["WORLD TIME CONSUMED", "REAL TIME", "DISTANCE TRAVELED", "TOTAL DEATHS", "DASHES / TIME PAID"]
	var values: Array[String] = ["%.2f s" % total_world, _timer(total_real), "%.1f m" % (total_distance / 16.0), str(total_deaths), "%d / %.0fs" % [total_dashes, total_dash_cost]]
	for i in range(labels.size()):
		var y: float = 83 + i * 13
		_text(hud, Vector2(51, y), labels[i], 8, MUTED)
		_text(hud, Vector2(217, y), values[i], 8, WHITE)
	hud.draw_line(Vector2(51, 142), Vector2(269, 142), Color("263740"))
	_center(hud, 158, "PRESS ENTER TO REPLAY", 10, GOLD)
	_center(hud, 173, "STILL//MOVING    Â·    CHRONOPHOBIA", 7, CYAN)

func _make_sounds() -> void:
	for name: String in ["jump", "double_jump", "wall_jump", "land", "dash", "strike", "bounce", "break", "anchor", "freeze", "hit", "goal"]:
		var duration: float = 0.2 if name == "goal" else 0.07
		var bytes := PackedByteArray()
		var count: int = int(22050 * duration)
		bytes.resize(count * 2)
		for i in range(count):
			var t: float = float(i) / 22050.0
			var envelope: float = pow(1.0 - float(i) / count, 2.0)
			var frequency: float = 640.0
			match name:
				"jump": frequency = 420.0 + t * 4200.0
				"double_jump": frequency = 750.0 + t * 6000.0
				"wall_jump": frequency = 580.0 + t * 3800.0
				"land": frequency = 160.0 - t * 1100.0
				"dash": frequency = 900.0 - t * 8000.0
				"strike": frequency = 320.0 - t * 2200.0
				"bounce": frequency = 260.0 + t * 8500.0
				"break": frequency = 240.0 + sin(t * 2300.0) * 150.0
				"anchor": frequency = 1100.0 + t * 3500.0
				"freeze": frequency = 1350.0 - t * 3000.0
				"hit": frequency = 90.0 + sin(t * 1700.0) * 35.0
				"goal": frequency = 660.0 if t < 0.08 else 990.0
			var sample: int = int(sin(TAU * frequency * t) * envelope * 12000)
			bytes.encode_s16(i * 2, sample)
		var stream := AudioStreamWAV.new()
		stream.format = AudioStreamWAV.FORMAT_16_BITS
		stream.mix_rate = 22050
		stream.data = bytes
		sounds[name] = stream

func _play(name: String) -> void:
	if test_mode or not sounds.has(name):
		return
	sfx.stream = sounds[name]
	sfx.play()

func _route_progress() -> float:
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
