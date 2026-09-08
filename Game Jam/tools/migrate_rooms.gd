extends SceneTree
const Levels = preload("res://scripts/levels.gd")
const Room = preload("res://scripts/editor/room_definition.gd")
const ObjectAsset = preload("res://scripts/editor/room_object.gd")
const NAMES = ["Spike", "Watcher", "MovingPlatform", "Spawn", "Exit", "Anchor", "PhaseBarrier", "FragileBarrier", "Gate", "Pad", "SlowField", "FastField", "Pit", "Sign"]
func _initialize() -> void:
	_run.call_deferred()
func _run() -> void:
	DirAccess.make_dir_recursive_absolute("res://assets/tiles")
	DirAccess.make_dir_recursive_absolute("res://assets/enemies")
	DirAccess.make_dir_recursive_absolute("res://assets/objects")
	DirAccess.make_dir_recursive_absolute("res://rooms")
	var img := Image.create(24,32,false,Image.FORMAT_RGBA8)
	for epoch in range(4):
		var base: Color = [Color("3b2a1a"),Color("554a35"),Color("353b40"),Color("242432")][epoch]
		for x in range(24):
			for y in range(8):
				var c := base
				if y == 0 and x < 8: c = Color("61e7ff")
				elif y == 7 or x % 8 == 7: c = base.darkened(0.3)
				elif y == 4 and x % 8 in [2,3,4]: c = base.lightened(0.17)
				if x >= 16: c = Color(base.lightened(0.1),0.6)
				img.set_pixel(x,y+epoch*8,c)
	var ts := TileSet.new()
	ts.tile_size = Vector2i(8,8)
	ts.add_physics_layer()
	ts.set_physics_layer_collision_layer(0,1)
	ts.set_physics_layer_collision_mask(0,2)
	var atlas := TileSetAtlasSource.new()
	atlas.texture = ImageTexture.create_from_image(img)
	atlas.texture_region_size = Vector2i(8,8)
	ts.add_source(atlas,0)
	for y in range(4):
		for x in range(3):
			var cell := Vector2i(x,y)
			atlas.create_tile(cell)
			if x < 2:
				var td := atlas.get_tile_data(cell,0)
				td.set_collision_polygons_count(0,1)
				td.set_collision_polygon_points(0,0,PackedVector2Array([Vector2(-4,-4),Vector2(4,-4),Vector2(4,4),Vector2(-4,4)]))
	ResourceSaver.save(ts,"res://assets/tiles/terrain.tres")
	ts = load("res://assets/tiles/terrain.tres")
	for kind: String in NAMES:
		var obj := ObjectAsset.new()
		obj.name = kind
		obj.kind = kind
		match kind:
			"Watcher": obj.speed = 50
			"MovingPlatform": obj.size = Vector2(32,8); obj.speed = 20
			"PhaseBarrier", "Gate": obj.size = Vector2(5,64)
			"FragileBarrier": obj.size = Vector2(48,4)
			"Pad": obj.size = Vector2(20,4)
			"SlowField", "FastField": obj.size = Vector2(96,72)
			"Pit": obj.size = Vector2(48,4)
		var scene := PackedScene.new()
		scene.pack(obj)
		ResourceSaver.save(scene,_asset_path(kind))
		obj.free()
	for i in range(8):
		var d: Dictionary = Levels.build(i)
		var room := Room.new()
		room.name = "Room%02d" % (i+1)
		root.add_child(room)
		room.title = d.title
		room.chapter = d.chapter
		room.room_index = i
		room.time_limit = d.time_limit
		room.hint = d.hint
		room.echo = d.echo
		room.waypoints.assign(d.waypoints)
		var floors := TileMapLayer.new()
		floors.name = "Floors"
		floors.position = Vector2(0,6)
		floors.tile_set = ts
		floors.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		room.add_child(floors)
		floors.owner = room
		var cells: Dictionary = {}
		for r: Rect2 in d.solids:
			for y in range(roundi((r.position.y-6)/8),roundi((r.end.y-6)/8)):
				for x in range(roundi(r.position.x/8),roundi(r.end.x/8)):
					cells[Vector2i(x,y)] = true
		for cell: Vector2i in cells:
			floors.set_cell(cell,0,Vector2i(1 if cells.has(cell+Vector2i.UP) else 0,d.chapter))
		var decor := TileMapLayer.new()
		decor.name = "Decoration"
		decor.position = floors.position
		decor.tile_set = ts
		decor.collision_enabled = false
		room.add_child(decor)
		decor.owner = room
		_add(room,"Spawn",{"pos":d.spawn})
		_add(room,"Exit",{"pos":d.goal})
		for s: Dictionary in d.spikes: _add(room,"Spike",s)
		for s: Dictionary in d.watchers: _add(room,"Watcher",s)
		for s: Dictionary in d.platforms: _add(room,"MovingPlatform",s)
		for s: Dictionary in d.anchors: _add(room,"Anchor",s)
		for s: Dictionary in d.barriers: _add(room,"PhaseBarrier" if s.kind == "phase" else "FragileBarrier",s)
		for s: Dictionary in d.gates: _add(room,"Gate",s)
		for s: Dictionary in d.pads: _add(room,"Pad",s)
		for s: Dictionary in d.fields: _add(room,"SlowField" if s.multiplier < 1 else "FastField",s)
		for r: Rect2 in d.killzones: _add(room,"Pit",{"rect":r})
		for s: Dictionary in d.signs: _add(room,"Sign",s)
		var packed := PackedScene.new()
		packed.pack(room)
		ResourceSaver.save(packed,"res://rooms/room_%02d.tscn" % (i+1))
		root.remove_child(room)
		room.free()
	print("Saved eight tile rooms and fourteen reusable assets.")
	quit()
func _asset_path(kind: String) -> String:
	return "res://assets/%s/%s.tscn" % ["enemies" if kind in ["Spike","Watcher"] else "objects",kind]
func _add(room: Node2D, kind: String, s: Dictionary) -> void:
	var obj: Node2D = load(_asset_path(kind)).instantiate(PackedScene.GEN_EDIT_STATE_INSTANCE)
	obj.name = kind
	room.add_child(obj,true)
	obj.owner = room
	if s.has("rect"):
		obj.position = s.rect.position
		obj.size = s.rect.size
	elif s.has("a"):
		obj.size = s.size
		obj.position = s.a + (Vector2(0,s.size.y/2) if kind == "Spike" else Vector2.ZERO)
		obj.patrol_offset = s.b-s.a
	else: obj.position = s.pos
	for prop: String in ["speed","phase","bounceable","bounce","open_ratio"]:
		if s.has(prop): obj.set(prop,s[prop])
	if s.has("interval"): obj.fire_interval = s.interval
	if s.has("range"): obj.sight_range = s.range
	if s.has("period"): obj.gate_period = s.period
	if s.has("text"): obj.message = s.text
