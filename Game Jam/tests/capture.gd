extends SceneTree
## Render inspection only: strategic camera placements are not route tests.

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	DirAccess.make_dir_recursive_absolute("res://tests/captures")
	var game = load("res://main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://tests/captures/menu.png")
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
		game.hud.queue_redraw()
		await process_frame
		await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://tests/captures/pyrax-%s.png"%sample)
	game.state = "complete"
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://tests/captures/completion.png")
	DisplayServer.window_set_size(Vector2i(1000, 800))
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
	assert(root.get_texture().get_size() == Vector2(320, 180), "Logical viewport changed after resize")
	root.get_texture().get_image().save_png("res://tests/captures/resize.png")
	print("RENDER PASS: menu, four levels, mechanism views, room overviews, completion and 1000x800 resize")
	quit()

func _capture(game: Node2D, name: String) -> void:
	game.camera.position = game.player.position + Vector2(25, -25)
	game.camera.reset_smoothing()
	game.camera.force_update_scroll()
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://tests/captures/%s.png" % name)
