@tool
extends Node2D
## Drag this scene into a room. The room connects its ability to the world clock.
const Art = preload("res://scripts/world/asset_art.gd")
@export_enum("Spike", "Watcher", "MovingPlatform", "Spawn", "Exit", "Anchor", "PhaseBarrier", "FragileBarrier", "Gate", "Pad", "SlowField", "FastField", "Pit", "Sign", "Crusher") var kind: String = "Spike"
@export_group("Shape")
@export var size := Vector2(12, 14)
@export_group("Patrol / Platform")
## Endpoint relative to this object; moving the object moves the whole patrol.
@export var patrol_offset := Vector2(48, 0)
@export_range(0, 200, 1) var speed: float = 25.0
@export_range(0, 1, 0.01) var phase: float = 0.0
@export var bounceable: bool = false
@export var lunge: bool = true
@export_group("Watcher")
@export_range(0.1, 10, 0.1) var fire_interval: float = 2.2
@export_range(1, 600, 1) var sight_range: float = 185.0
@export var facing := Vector2.LEFT
@export_range(1, 360, 1) var field_of_view: float = 200.0
@export_group("Mechanism")
@export_range(0.1, 10, 0.1) var gate_period: float = 2.8
@export_range(0.05, 0.95, 0.01) var open_ratio: float = 0.72
@export var bounce: float = 270.0
@export var message: String = "YOUR SIGN HERE"

func _validate_property(property: Dictionary) -> void:
	var allowed: Dictionary = {
		"size":["Spike","MovingPlatform","PhaseBarrier","FragileBarrier","Gate","Pad","SlowField","FastField","Pit","Crusher"],
		"patrol_offset":["Spike","MovingPlatform"], "speed":["Spike","Watcher","MovingPlatform"],
		"phase":["Spike","Watcher","MovingPlatform","Gate","Crusher"], "bounceable":["Spike"], "lunge":["Spike"],
		"fire_interval":["Watcher"], "sight_range":["Watcher"], "facing":["Watcher"], "field_of_view":["Watcher"],
		"gate_period":["Gate","Crusher"], "open_ratio":["Gate"], "bounce":["Spike","Pad"], "message":["Sign"]
	}
	if property.name == "kind" or (allowed.has(property.name) and not kind in allowed[property.name]):
		property.usage = PROPERTY_USAGE_STORAGE

func _process(_delta: float) -> void:
	if Engine.is_editor_hint():
		queue_redraw()

func spec(room: Node2D) -> Dictionary:
	var p: Vector2 = room.to_local(global_position)
	match kind:
		"Spike":
			var a := p - Vector2(0, size.y / 2)
			return {"a":a, "b":a+patrol_offset, "size":size, "speed":speed, "phase":phase, "bounceable":bounceable, "bounce":bounce, "lunge":lunge}
		"Watcher": return {"pos":p, "interval":fire_interval, "range":sight_range, "speed":speed, "phase":phase, "direction":facing, "fov":field_of_view}
		"MovingPlatform": return {"a":p, "b":p+patrol_offset, "size":size, "speed":speed, "phase":phase}
		"Anchor", "Spawn", "Exit": return {"pos":p}
		"Sign": return {"pos":p, "text":message}
		"PhaseBarrier", "FragileBarrier": return {"rect":Rect2(p,size), "kind":"phase" if kind == "PhaseBarrier" else "fragile"}
		"Crusher": return {"rect":Rect2(p,size),"period":gate_period,"phase":phase}
		"Gate": return {"rect":Rect2(p,size), "period":gate_period, "open_ratio":open_ratio, "phase":phase}
		"Pad": return {"rect":Rect2(p,size), "bounce":bounce}
		"SlowField", "FastField": return {"rect":Rect2(p,size), "multiplier":0.5 if kind == "SlowField" else 1.5}
	return {"rect":Rect2(p,size)}

func _draw() -> void:
	var epoch: int = 0
	var ancestor: Node = get_parent()
	while ancestor:
		if ancestor.has_method("to_data"):
			epoch = ancestor.chapter
			break
		ancestor = ancestor.get_parent()
	var cyan := Color("61e7ff")
	var gold := Color("ffd15c")
	var pink := Color("ff5fcb")
	match kind:
		"Spike":
			var a := Vector2(0, -size.y/2)
			Art.spike(self, {"a":a, "b":a+patrol_offset, "pos":a, "size":size, "bounceable":bounceable}, epoch)
		"Watcher": Art.watcher(self, {"pos":Vector2.ZERO, "timer":0.0, "interval":fire_interval, "flash":0.0}, epoch)
		"Spawn":
			draw_rect(Rect2(-3,-14,6,14), Color("f8f8f2"))
			draw_rect(Rect2(0,-12,3,2), cyan)
		"Exit":
			draw_rect(Rect2(-10,-29,20,29), Color("214752"))
			draw_rect(Rect2(-10,-29,20,29), cyan, false)
		"Anchor":
			draw_line(Vector2(0,-24),Vector2.ZERO,cyan,2)
			draw_colored_polygon(PackedVector2Array([Vector2(0,-26),Vector2(6,-19),Vector2(0,-12),Vector2(-6,-19)]),cyan)
		"MovingPlatform":
			draw_dashed_line(Vector2.ZERO,patrol_offset,Color(gold,0.5),1,3)
			draw_rect(Rect2(-size/2,size),Color("4a4e54"))
			draw_line(-size/2,Vector2(size.x/2,-size.y/2),gold)
		"Sign": draw_string(ThemeDB.fallback_font,Vector2.ZERO,message,HORIZONTAL_ALIGNMENT_LEFT,-1,7,gold)
		"Crusher":
			draw_rect(Rect2(Vector2.ZERO,Vector2(size.x,12)),Color("859098"))
			draw_rect(Rect2(Vector2.ZERO,size),Color(gold,0.3),false)
		"Pit":
			for x in range(0,int(size.x),6):
				draw_colored_polygon(PackedVector2Array([Vector2(x,size.y),Vector2(x+3,0),Vector2(minf(x+6,size.x),size.y)]),Color("ff5a67"))
		_:
			var color: Color = cyan if kind == "SlowField" else pink
			if kind in ["Gate", "FragileBarrier", "Pad"]: color = gold
			draw_rect(Rect2(Vector2.ZERO,size),Color(color,0.2))
			draw_rect(Rect2(Vector2.ZERO,size),color,false)
