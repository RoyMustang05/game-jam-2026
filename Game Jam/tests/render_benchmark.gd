extends SceneTree
func _initialize() -> void:
	_run.call_deferred()
func _run() -> void:
	var game: Node2D = load("res://scripts/game.gd").new()
	root.add_child(game)
	game.load_level(3)
	game.player.position=Vector2(600,390)
	game._start_boss()
	game.set_physics_process(false)
	game.dragon.phase=2
	game.dragon.state="attack"
	game.dragon.attack=1
	var samples: Array[float]=[]
	var last: int=Time.get_ticks_usec()
	for n in range(180):
		game.dragon.projectiles.clear()
		game.dragon._volley(false)
		game.dragon._volley(true)
		game.dragon.age=0.9
		game.dragon.world_step(1.0/60,game.player)
		game.atmosphere.world_step(1.0/60)
		await process_frame
		await RenderingServer.frame_post_draw
		var now: int=Time.get_ticks_usec()
		if n>=30: samples.append((now-last)/1000.0)
		last=now
	samples.sort()
	print("RENDER BENCHMARK: 1280x720, 6 fireballs + rig + lights, median %.2fms p95 %.2fms p99 %.2fms"%[samples[75],samples[142],samples[148]])
	quit()
