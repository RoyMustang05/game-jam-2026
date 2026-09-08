extends SceneTree
## Render inspection only: strategic camera placements are not route tests.
var output_dir: String = "res://tests/captures"

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	root.title = "STILL MOVING UI validation"
	root.show()
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--output="):
			output_dir = argument.trim_prefix("--output=")
	DirAccess.make_dir_recursive_absolute(output_dir)
	var game = load("res://main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(output_dir.path_join("menu.png"))
	game.test_mode = true
	game.test_command = {"axis": 0.0}
	game.start_run()
	for i in range(4):
		game.load_level(i)
		game.paused = true
		game.intro_left = 0.0
		# Keep game HUD visible while halting physics for visual snapshots.
		game.set_physics_process(false)
		game.paused = false
		await _capture(game, "room-%02d-start" % (i + 1))
		if game.data.get("anchors", []).size() > 0:
			game.player.position = game.data.anchors[0].pos
			await _capture(game, "room-%02d-anchor" % (i + 1))
		if game.data.get("pads", []).size() > 0:
			game.player.position = Rect2(game.data.pads[0].rect).position + Vector2(0, -25)
			await _capture(game, "room-%02d-strike" % (i + 1))
		# A whole-room drawing reveals route continuity and collider placement.
		var scale: float = minf(320.0 / float(game.data.width), 180.0 / float(game.data.height))
		game.camera.zoom = Vector2(scale, scale)
		game.player.position = Vector2(game.data.width, game.data.height) * 0.5 - Vector2(25, -25)
		game.hud.visible = false
		await _capture(game, "room-%02d-overview" % (i + 1))
		game.hud.visible = true
		game.camera.zoom = Vector2.ONE
	game.load_level(3)
	game.player.position = Vector2(600,390)
	game._start_boss()
	game.set_process(false)
	game.set_physics_process(false)
	for sample in ["warning","attack","recover","transition","defeat"]:
		game.dragon.state = sample
		game.dragon.age = 0.8
		game.dragon.clock = 12.7
		game.dragon.queue_redraw()
		game._arena_camera()
		game.world_labels.queue_redraw()
		game.hud.queue_redraw()
		await process_frame
		await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(output_dir.path_join("pyrax-%s.png" % sample))
	game.state = "complete"
	game.hud.queue_redraw()
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(output_dir.path_join("completion.png"))
	root.size = Vector2i(1000, 800)
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
	assert(game.world_viewport.size == Vector2i(320, 180), "World viewport changed after resize")
	root.get_texture().get_image().save_png(output_dir.path_join("resize.png"))
	if not await _ui_sizes(game):
		quit(1)
		return
	print("RENDER PASS: rooms, boss, menu, HUD, pause, clear, completion, wrapped instructions; 640x360, 1280x720, 1920x1080 and 1000x800")
	quit()

func _ui_sizes(game: Node2D) -> bool:
	game.load_level(0)
	game.set_process(false)
	game.set_physics_process(false)
	game.camera.position = game.player.position + Vector2(25, -25)
	game.camera.reset_smoothing()
	game.camera.force_update_scroll()
	var camera_transform: Transform2D = game.world.get_global_transform_with_canvas()
	for size: Vector2i in [Vector2i(640, 360), Vector2i(1280, 720), Vector2i(1920, 1080), Vector2i(1000, 800)]:
		root.size = size
		await create_timer(0.15).timeout
		for sample: String in ["menu", "playing", "moving", "pause", "clear", "complete", "long-hint"]:
			game.state = sample if sample in ["menu", "clear", "complete"] else "playing"
			game.paused = sample == "pause"
			game.frozen = sample != "moving"
			game.player.dash_charges = 1 if sample == "moving" else 2
			game.dash_flash = 0.5 if sample == "moving" else 0.0
			game.intro_left = 3.0
			game.data.hint = "STOP TO READ THE LUNGE. MOVE TO SURVIVE."
			if sample == "long-hint":
				game.data.hint = "WATCH THE LIGHTS. PACE TO MOVE MACHINERY. DOWN + SHIFT: BREAK THE FLOOR. HOLD X IN AIR TO FREEZE AND PLAN."
			game.queue_redraw()
			game.world_labels.queue_redraw()
			game.hud.queue_redraw()
			await process_frame
			await process_frame
			await RenderingServer.frame_post_draw
			assert(game.world_viewport.size == Vector2i(320, 180), "World resolution changed")
			assert(game.world.get_global_transform_with_canvas().is_equal_approx(camera_transform), "Camera framing changed after resize")
			var capture: Image = root.get_texture().get_image()
			# With integer scaling and keep-aspect, the texture excludes letterboxing.
			var scale: int = floori(minf(size.x / 320.0, size.y / 180.0))
			var expected_size := Vector2i(320, 180) * scale
			if capture.get_size() != expected_size or DisplayServer.window_get_size() != size:
				push_error("Requested window %s / content %s, got %s / %s" % [size, expected_size, DisplayServer.window_get_size(), capture.get_size()])
				return false
			capture.save_png(output_dir.path_join("ui-%dx%d-%s.png" % [size.x, size.y, sample]))
	return true

func _capture(game: Node2D, name: String) -> void:
	game.camera.position = game.player.position + Vector2(25, -25)
	game.camera.reset_smoothing()
	game.camera.force_update_scroll()
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(output_dir.path_join("%s.png" % name))
