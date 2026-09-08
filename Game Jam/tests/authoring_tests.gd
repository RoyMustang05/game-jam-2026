extends SceneTree
const Game = preload("res://scripts/game.gd")
var failures := 0
func _initialize() -> void:
	_run.call_deferred()
func check(ok: bool, label: String) -> void:
	print(("PASS: " if ok else "FAIL: ") + label)
	if not ok: failures += 1
func _run() -> void:
	var holder := Node2D.new()
	root.add_child(holder)
	var room: Node2D = load("res://rooms/room_01.tscn").instantiate()
	holder.add_child(room)
	var original_watchers: int = room.to_data().watchers.size()
	var original_spikes: int = room.to_data().spikes.size()
	var floors: TileMapLayer = room.get_node("Floors")
	check(floors.tile_set.resource_path == "res://assets/tiles/terrain.tres", "rooms use shared paintable terrain resource")
	var cell := Vector2i(10,5)
	floors.set_cell(cell,0,Vector2i.ZERO)
	floors.update_internals()
	await physics_frame
	await physics_frame
	var painted := Vector2(84,50)
	var ray := PhysicsRayQueryParameters2D.create(painted-Vector2(0,12),painted+Vector2(0,2),1)
	check(not room.get_world_2d().direct_space_state.intersect_ray(ray).is_empty(),"painting adds real floor collision")
	var d: Dictionary = room.to_data()
	var found := false
	for r: Rect2 in d.solids:
		if r.has_point(painted): found = true
	check(found,"painted tile also blocks watcher sight and shots")
	floors.erase_cell(cell)
	floors.update_internals()
	await physics_frame
	await physics_frame
	check(room.get_world_2d().direct_space_state.intersect_ray(ray).is_empty(),"erasing removes real collision")
	var watcher: Node2D = load("res://assets/enemies/Watcher.tscn").instantiate()
	room.add_child(watcher)
	watcher.owner = room
	watcher.position = Vector2(130,60)
	watcher.fire_interval = 0.3
	watcher.sight_range = 240
	var patrol: Node2D = load("res://assets/enemies/Spike.tscn").instantiate()
	room.add_child(patrol)
	patrol.owner = room
	patrol.position = Vector2(600,86)
	patrol.patrol_offset = Vector2(72,0)
	var packed := PackedScene.new()
	packed.pack(room)
	check(ResourceSaver.save(packed,"res://tests/authoring-temporary.tscn") == OK,"edited room saves")
	holder.remove_child(room)
	room.free()
	var game := Game.new()
	game.test_mode = true
	game.playtest_room_path = "res://tests/authoring-temporary.tscn"
	root.add_child(game)
	game.start_run()
	await physics_frame
	check(game.hazards.watchers.size() == original_watchers+1 and is_equal_approx(game.hazards.watchers.back().interval,0.3),"saved drag-in shooter carries its configured ability")
	check(game.hazards.spikes.size() == original_spikes+1 and game.hazards.spikes.back().b-game.hazards.spikes.back().a == Vector2(72,0),"saved patrol carries its relative path")
	game.player.position = Vector2(100,74)
	game.camera.position = Vector2(130,80)
	game.camera.reset_smoothing()
	game.camera.force_update_scroll()
	game.hazards.world_step(0.31,game.player)
	check(game.hazards.projectiles.size() > 0,"new shooter actually fires without wiring signals")
	var before: Vector2 = game.hazards.spikes.back().pos
	game.hazards.world_step(0.2,game.player)
	check(game.hazards.spikes.back().pos != before,"new enemy patrol actually moves")
	before = game.hazards.spikes.back().pos
	game.hazards.world_step(0,game.player)
	check(game.hazards.spikes.back().pos == before,"new enemy obeys frozen world time")
	game.finish_level()
	game.confirm()
	check(game.playtest_room_path == "res://tests/authoring-temporary.tscn" and game.hazards.watchers.size() == original_watchers+1,"playtest replay stays in edited room")
	root.remove_child(game)
	game.free()
	var standalone: Node2D = load("res://rooms/room_03.tscn").instantiate()
	root.add_child(standalone)
	await process_frame
	await process_frame
	var launched: Node2D
	for child in root.get_children():
		if child.get_script() == Game: launched = child
	check(is_instance_valid(launched) and launched.level_index == 2 and launched.state == "playing", "F6 launches selected room directly with correct chapter")
	print("AUTHORING FAILURES: %d" % failures)
	quit(1 if failures else 0)
