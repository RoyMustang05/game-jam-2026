@tool
extends Node2D
const Levels = preload("res://scripts/world/levels.gd")
@export var title: String = "MY ROOM"
@export_enum("Prehistory", "Antiquity", "Industrial", "Future Collapse") var chapter: int = 0
@export_range(0,3) var room_index: int = 0
@export var room_size := Vector2(960,540)
@export var time_limit: float = 95.0
@export var par_time: float = 62.0
@export var hint: String = "MOVE TO CREATE TIME. STOP TO SURVIVE."
@export var echo: bool = false
@export var boss: bool = false
@export var arena := Rect2(560,246,320,144)
@export var retry_budget: float = 70.0
@export var waypoints: Array[Vector2] = []

func _ready() -> void:
	if not Engine.is_editor_hint() and get_parent() == get_tree().root:
		_play_current.call_deferred()

func _play_current() -> void:
	var game := load("res://scripts/game.gd").new() as Node2D
	game.playtest_room_path = scene_file_path
	get_tree().root.add_child(game)
	get_parent().remove_child(self)
	game.start_run()
	queue_free()

func _process(_delta: float) -> void:
	if Engine.is_editor_hint(): queue_redraw()

func _draw() -> void:
	if not Engine.is_editor_hint(): return
	draw_rect(Rect2(Vector2.ZERO,room_size),Color("0d1013"))
	for y in range(0,int(room_size.y),160):
		draw_set_transform(Vector2(0,y))
		Levels.draw_environment(self,chapter,room_size.x,0.0)
	draw_set_transform(Vector2.ZERO)

func to_data() -> Dictionary:
	var d := {"title":title, "epoch":Levels.EPOCHS[chapter], "chapter":chapter, "room":room_index, "subtitle":"THE CLOCK / FRACTURE %02d" % (room_index+1), "hint":hint, "width":room_size.x, "height":room_size.y, "time_limit":time_limit, "par_time":par_time, "spawn":Vector2(25,86), "goal":Vector2(930,502), "echo":echo, "solids":[], "spikes":[], "watchers":[], "platforms":[], "barriers":[], "gates":[], "pads":[], "anchors":[], "fields":[], "killzones":[], "signs":[], "waypoints":Array(waypoints), "tiled":true, "boss":boss, "arena":arena, "retry_budget":retry_budget, "crushers":[]}
	_collect(self,d)
	return d

func _collect(node: Node, d: Dictionary) -> void:
	for child in node.get_children():
		if child is TileMapLayer and child.collision_enabled:
			d.solids.append_array(_tile_rects(child))
		if child.has_method("spec"):
			var s: Dictionary = child.spec(self)
			var key: String = {"Crusher":"crushers", "Spike":"spikes", "Watcher":"watchers", "MovingPlatform":"platforms", "Anchor":"anchors", "PhaseBarrier":"barriers", "FragileBarrier":"barriers", "Gate":"gates", "Pad":"pads", "SlowField":"fields", "FastField":"fields", "Sign":"signs"}.get(child.kind, "")
			if not key.is_empty(): d[key].append(s)
			elif child.kind == "Spawn": d.spawn = s.pos
			elif child.kind == "Exit": d.goal = s.pos
			elif child.kind == "Pit": d.killzones.append(s.rect)
		_collect(child,d)

func _tile_rects(layer: TileMapLayer) -> Array:
	var rows: Dictionary = {}
	for cell: Vector2i in layer.get_used_cells():
		var tile := layer.get_cell_tile_data(cell)
		if tile == null or tile.get_collision_polygons_count(0) == 0: continue
		if not rows.has(cell.y): rows[cell.y] = []
		rows[cell.y].append(cell.x)
	var result: Array = []
	var keys: Array = rows.keys()
	keys.sort()
	for y: int in keys:
		var xs: Array = rows[y]
		xs.sort()
		var first: int = xs[0]
		var last: int = first
		xs.append(2147483647)
		for x: int in xs.slice(1):
			if x == last+1:
				last = x
				continue
			var cell_size := Vector2(layer.tile_set.tile_size)
			var origin := to_local(layer.to_global(layer.map_to_local(Vector2i(first,y)))) - cell_size/2
			var rect := Rect2(origin,Vector2((last-first+1)*cell_size.x,cell_size.y))
			var merged := false
			for i in range(result.size()-1,-1,-1):
				var prev: Rect2 = result[i]
				if prev.position.x == rect.position.x and prev.size.x == rect.size.x and prev.end.y == rect.position.y:
					prev.size.y += rect.size.y
					result[i] = prev
					merged = true
					break
			if not merged: result.append(rect)
			first = x
			last = x
	return result

func activate_runtime() -> void:
	_hide_previews(self)
	set_process(false)

func _hide_previews(node: Node) -> void:
	for child in node.get_children():
		if child.has_method("spec"):
			child.hide()
			child.set_process(false)
		if child is TileMapLayer: child.update_internals()
		_hide_previews(child)
