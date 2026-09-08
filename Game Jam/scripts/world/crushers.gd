extends Node2D
var entries: Array = []
var clock := 0.0
var previous := Vector2.ZERO
func setup(specs: Array) -> void:
	entries = specs.duplicate(true)
	for e in entries:
		e["head"] = head(e)
		e["old_head"] = e.head
func phase_time(e: Dictionary) -> float:
	return fposmod(clock+float(e.get("phase",0))*float(e.period),float(e.period))
func head(e: Dictionary) -> Rect2:
	var r: Rect2 = e.rect
	var t := phase_time(e)
	var depth := 0.0
	if t >= 1.2 and t < 1.5: depth = (t-1.2)/0.3
	elif t < 1.95 and t >= 1.5: depth = 1.0
	elif t >= 1.95: depth = 1-clampf((t-1.95)/(float(e.period)-1.95),0,1)
	return Rect2(r.position+Vector2(0,(r.size.y-12)*depth),Vector2(r.size.x,12))
func world_step(dt: float, player: Node2D) -> bool:
	clock += dt
	var hit := false
	var rect := Rect2(player.position+Vector2(-4,-14),Vector2(8,14))
	for e in entries:
		e.old_head = e.head
		e.head = head(e)
		if Rect2(e.head).merge(e.old_head).intersects(rect): hit = true
	queue_redraw()
	return hit
func _draw() -> void:
	for e in entries:
		var r: Rect2 = e.rect
		var h: Rect2 = e.head
		var warning := phase_time(e) >= 0.4 and phase_time(e) < 1.2
		draw_line(r.position+Vector2(3,0),Vector2(r.position.x+3,r.end.y),Color("3c4049"),2)
		draw_line(r.position+Vector2(r.size.x-3,0),Vector2(r.end.x-3,r.end.y),Color("3c4049"),2)
		draw_rect(h,Color("77818c"))
		for n in range(0,int(h.size.x),7): draw_line(h.position+Vector2(n,1),h.position+Vector2(n+4,7),Color("ffd15c"),2)
		draw_line(Vector2(h.position.x,h.end.y),h.end,Color("ff5a67"),2)
		draw_rect(Rect2(r.position+Vector2(-5,-3),Vector2(3,4)),Color("ffd15c") if warning else Color("ff5a67"))
		if warning: draw_rect(r,Color(1,0.7,0.2,0.13),false)
