extends SceneTree
## Integration checks in the real director. Optional GPU captures stay outside git.
const Game = preload("res://scripts/game.gd")
const Figure = preload("res://scripts/actors/milo_figure.gd")
var game: Node2D
var failures: int = 0
var captures: bool = false
var completion_count: int = 0
var output: String = "/tmp/still-presentation"

func _initialize() -> void:
	_run.call_deferred()

func check(ok: bool, label: String) -> void:
	print(("PASS: " if ok else "FAIL: ") + label)
	if not ok:
		failures += 1

func _run() -> void:
	captures = "--capture" in OS.get_cmdline_user_args()
	DirAccess.make_dir_recursive_absolute(output)
	game = Game.new()
	game.test_mode = true
	root.add_child(game)
	await frames(3)
	await capture("menu")
	await key(KEY_RIGHT)
	await key(KEY_ENTER)
	check(game.state == "menu" and game.menu_screen.editor_panel.visible, "keyboard selects Editor de niveles without starting game")
	await key(KEY_ESCAPE)
	check(not game.menu_screen.editor_panel.visible, "Escape returns from editor access")
	await click(Vector2(50, 147))
	check(game.state == "story" and not is_instance_valid(game.player), "mouse new game opens story before constructing simulation")
	if game.state != "story":
		quit(1)
		return
	var started: int = Time.get_ticks_usec()
	var seen: Array[int] = []
	game.test_command = {"axis": 1.0, "jump": true, "dash": true, "attack": true}
	while game.state == "story":
		check_story_clocks()
		if game.cinematic.elapsed > 1.0 and game.cinematic.beat not in seen:
			seen.append(game.cinematic.beat)
			await capture("story-beat-%d" % game.cinematic.beat)
		await process_frame
	game.test_command = {"axis": 0.0}
	var story_duration: float = (Time.get_ticks_usec() - started) / 1000000.0
	check(story_duration >= 12 and story_duration <= 16 and seen.size() == 4, "automatic story: %.3f s, all four beats" % story_duration)
	check(game.level_index == 0 and game.remaining == float(game.data.time_limit), "intro starts first level with its full time budget")
	await frames(5)
	game.start_new_game()
	action("confirm")
	check(game.cinematic.beat == 1, "continue advances to machine pan")
	action("confirm")
	check(game.cinematic.beat == 2, "continue changes illustration")
	action("confirm")
	check(game.cinematic.beat == 3, "continue reveals delayed A TRABAJAR beat")
	action("confirm")
	check(game.state == "playing", "last continue enters gameplay")
	await frames(5)
	game.start_new_game()
	Input.action_press("jump")
	Input.action_press("dash")
	Input.action_press("move_right")
	action("pause_game")
	game.test_mode = false
	await frames(8)
	check(game.state == "playing" and game.player.dash_charges == 2 and game.player.position.distance_to(game.checkpoint_position) < 0.1, "skip consumes held jump, dash and movement without carryover")
	Input.action_release("jump")
	Input.action_release("dash")
	Input.action_release("move_right")
	game.test_mode = true
	game.level_completed.connect(func(_index: int): completion_count += 1)
	for index in range(3):
		game.load_level(index)
		await frames(5)
		check(game.player.costume == index, "room %d selects its era costume" % (index + 1))
		var deaths_before: int = game.total_deaths
		game.player.position = game.data.goal
		game.player.velocity = Vector2.ZERO
		# Exercise the actual exit trigger, followed by a duplicate notification.
		await frames(1)
		check(game.state == "portal", "exit starts automatic portal")
		var time_before: float = game.total_world
		var real_before: float = game.total_real
		started = game.cinematic.portal_started_usec
		game.finish_level()
		game._on_goal_body(game.player)
		game.die("SHOULD BE IGNORED")
		game.test_command = {"axis": 1.0, "jump": true, "dash": true, "attack": true}
		var samples: Array[int] = []
		var max_frame_ms: float = 0.0
		var previous: int = Time.get_ticks_usec()
		while game.state == "portal":
			var phase: int = int(game.cinematic.elapsed / 0.5)
			if phase not in samples:
				samples.append(phase)
				if index == 0:
					await capture("portal-%d" % phase)
			await process_frame
			var now: int = Time.get_ticks_usec()
			max_frame_ms = maxf(max_frame_ms, (now - previous) / 1000.0)
			previous = now
			check_transition_clocks(time_before, real_before)
		game.test_command = {"axis": 0.0}
		while game.input_guard_frames > 0:
			await frames(1)
		var duration: float = (Time.get_ticks_usec() - started) / 1000000.0
		check(duration < 3.0 and duration >= 2.0, "portal %d restored control in %.3f s (max sampled frame %.1f ms, including captures)" % [index + 1, duration, max_frame_ms])
		check(game.level_index == index + 1 and completion_count == index + 1, "exactly one load/completion, correct next room")
		check(game.total_deaths == deaths_before and game.remaining == float(game.data.time_limit), "portal cannot kill or consume next room budget")
		check(game.player.costume == index + 1 and game.player.position == game.checkpoint_position, "new costume emerges at authored spawn")
		await capture("arrival-%d" % (index + 2))
		game.die("RETRY CHECK")
		check(game.state == "playing" and game.player.costume == index + 1, "retry preserves outfit and bypasses story")
	game.load_level(3)
	game.finish_level()
	await frames(160)
	check(game.state == "complete" and game.level_index == 3, "last level retains completion screen and never loads room 5")
	await capture("completion")
	game.menu_screen.level_choice.select(2)
	var spec: Dictionary = game.menu_screen.editor_launch_spec()
	check(not spec.is_empty() and spec.args[3] == "res://rooms/room_03.tscn" and FileAccess.file_exists(spec.executable), "editor uses real selected scene, project path and installed executable")
	game.state = "menu"
	game.menu_screen._show_editor()
	await capture("editor")
	game.menu_screen._close_editor()
	check(not game.menu_screen.editor_panel.visible, "editor panel returns to menu")
	if "--launch-editor" in OS.get_cmdline_user_args():
		var pid: int = game.menu_screen.open_selected_level()
		check(pid > 0, "menu launches installed Godot editor (PID %d)" % pid)
		print("EDITOR_PID: %d" % pid)
	for cue: String in ["portal_open", "portal_whoosh", "portal_arrive"]:
		var stream: AudioStreamWAV = game.sound_bank.sounds[cue]
		var peak: int = 0
		for i in range(0, stream.data.size(), 2):
			peak = maxi(peak, absi(stream.data.decode_s16(i)))
		check(peak > 0 and peak < 16000, "%s synthesized PCM has headroom (peak %d / 32767)" % [cue, peak])
	check(game.sound_bank.sfx.volume_db == -20.0 and game.sound_bank.sfx.bus == &"Master", "portal cues retain existing volume and mute bus")
	if captures:
		await check_sizes_and_poses()
	print("PRESENTATION RESULT: %d failures" % failures)
	game.queue_free()
	await process_frame
	quit(1 if failures else 0)

func check_story_clocks() -> void:
	if game.total_real != 0 or game.total_world != 0 or game.total_dashes != 0:
		check(false, "story clocks advanced")

func check_transition_clocks(world_before: float, real_before: float) -> void:
	if game.total_world != world_before or game.total_real != real_before:
		check(false, "portal clocks advanced")

func action(name: String) -> void:
	var event := InputEventAction.new()
	event.action = name
	event.pressed = true
	game._unhandled_input(event)

func key(code: Key) -> void:
	var event := InputEventKey.new()
	event.keycode = code
	event.physical_keycode = code
	event.pressed = true
	root.push_input(event)
	await process_frame
	event.pressed = false
	root.push_input(event)
	await process_frame

func click(point: Vector2) -> void:
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.position = point
	event.global_position = point
	var motion := InputEventMouseMotion.new()
	motion.position = point
	motion.global_position = point
	root.push_input(motion, true)
	await process_frame
	event.pressed = true
	root.push_input(event, true)
	await process_frame
	event.pressed = false
	root.push_input(event, true)
	await process_frame

func frames(count: int) -> void:
	for n in range(count):
		await physics_frame
		await process_frame

func capture(label: String) -> void:
	if not captures:
		return
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(output.path_join(label + ".png"))

func check_sizes_and_poses() -> void:
	game.set_physics_process(false)
	for size: Vector2i in [Vector2i(1280, 720), Vector2i(1920, 1080), Vector2i(1000, 800)]:
		root.size = size
		await create_timer(0.15).timeout
		game.state = "menu"
		await capture("menu-%dx%d" % [size.x, size.y])
		game.start_new_game()
		game.cinematic.beat = 3
		game.cinematic.elapsed = 1.0
		await capture("story-%dx%d" % [size.x, size.y])
		game.load_level(0)
		await capture("game-%dx%d" % [size.x, size.y])
		check(game.world_viewport.size == Vector2i(320, 180), "world resolution remains unchanged at %s" % size)
	root.size = Vector2i(1920, 1080)
	await create_timer(0.15).timeout
	game.load_level(1)
	game.set_physics_process(true)
	await frames(5)
	game.finish_level()
	var started: int = Time.get_ticks_usec()
	var samples: Array[float] = []
	var previous: int = started
	while game.state == "portal" or game.input_guard_frames > 0:
		await process_frame
		await RenderingServer.frame_post_draw
		var now: int = Time.get_ticks_usec()
		samples.append((now - previous) / 1000.0)
		previous = now
	samples.sort()
	var duration: float = (Time.get_ticks_usec() - started) / 1000000.0
	check(duration < 3.0, "1920x1080 portal %.3f s; frame median %.2f ms / p95 %.2f ms / max %.2f ms" % [duration, samples[samples.size() / 2], samples[int(samples.size() * 0.95)], samples.back()])
	game.set_physics_process(false)
	game.hide()
	game.hud.hide()
	game.world_labels.hide()
	var sheet := Node2D.new()
	root.add_child(sheet)
	sheet.draw.connect(func():
		sheet.draw_rect(Rect2(0, 0, 320, 180), Color("17232c"))
		var poses: Array[String] = ["idle", "run", "start", "skid", "takeoff", "land", "rise", "double_jump", "fall", "focus", "wall_cling", "wall_slide", "wall_jump", "dash", "air_dash", "strike", "bounce", "melee", "hit", "goal", "respawn"]
		for era in range(4):
			for i in range(poses.size()):
				var p := Vector2(10 + (i % 11) * 28, 22 + era * 40 + (i / 11) * 18)
				Figure.figure(sheet, p, 1 if i % 2 else -1, Color.WHITE, poses[i], i % 8, true, 0.0, 1.0, era)
	)
	sheet.queue_redraw()
	await capture("all-outfits-all-poses")
	sheet.queue_free()
