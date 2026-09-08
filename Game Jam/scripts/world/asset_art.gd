@tool
extends RefCounted
const MAGENTA := Color("#FF5FCB")
const CYAN := Color("#61E7FF")
const RED := Color("#FF5A67")
const YELLOW := Color("#FFD15C")
const INK := Color("#0D1013")
const WHITE := Color("#F8F8F2")
static func spike(canvas: Node2D, spike: Dictionary, epoch: int, world_time: float = 0.0) -> void:
	var p: Vector2 = Vector2(spike.pos).round()
	var size: Vector2 = spike.size
	var half := size * 0.5
	var t := fposmod(float(spike.get("anim_time",world_time)),4.2)
	var windup: bool = bool(spike.get("lunge",false)) and t >= 1.2 and t < 2
	var attack: bool = bool(spike.get("lunge",false)) and t >= 2 and t < 2.4
	var stride := sin(world_time*16)*2
	if windup:
		canvas.draw_line(p+Vector2(-3,-half.y-3),p+Vector2(3,-half.y-3),YELLOW,2)
	# Thin path markings make the deterministic patrol readable at a glance.
	if Vector2(spike.a).distance_to(Vector2(spike.b)) > 1.0:
		canvas.draw_line(spike.a, spike.b, Color(MAGENTA, 0.12), 1.0)
		canvas.draw_line(Vector2(spike.a) + Vector2(0, -2), Vector2(spike.a) + Vector2(0, 2), Color(MAGENTA, 0.35))
		canvas.draw_line(Vector2(spike.b) + Vector2(0, -2), Vector2(spike.b) + Vector2(0, 2), Color(MAGENTA, 0.35))
	match epoch:
		0:
			# A low raptor silhouette: tail, heavy haunch, jaw, and two pointed feet.
			canvas.draw_colored_polygon(PackedVector2Array([
				p + Vector2(-half.x, -2+sin(world_time*7)*2), p + Vector2(-2, 1), p + Vector2(1, -half.y+(3 if windup else 0)),
				p + Vector2(half.x, -half.y), p + Vector2(half.x, -1), p + Vector2(2, 1),
				p + Vector2(3+stride, half.y), p + Vector2(0, half.y), p + Vector2(-2, 3),
				p + Vector2(-3-stride, half.y), p + Vector2(-5-stride, half.y), p + Vector2(-4, 2)
			]), Color("#C97B3D"))
			canvas.draw_line(p + Vector2(-half.x, -1), p + Vector2(-2, 1), MAGENTA, 2)
			canvas.draw_rect(Rect2(p + Vector2(half.x - 3, -half.y + 2), Vector2(2, 2)), MAGENTA)
		1:
			# Temple guard: braced windup, extended thrust, stepping feet.
			canvas.draw_rect(Rect2(p + Vector2(-3, -half.y), Vector2(6, 5)), Color("#D8B26A"))
			canvas.draw_rect(Rect2(p + Vector2(-4, -half.y + 6), Vector2(8, size.y - 7)), Color("#A5502C"))
			canvas.draw_line(p + Vector2(-2,-2),p+Vector2(half.x,-2 if attack else -half.y),YELLOW if windup else MAGENTA,1)
			canvas.draw_line(p+Vector2(-3,half.y-3),p+Vector2(-3+stride,half.y),Color("D8B26A"),2)
			canvas.draw_line(p + Vector2(-2, -half.y + 2), p + Vector2(2, -half.y + 2), MAGENTA)
		2:
			# Loose minecart with anomalous cargo and two iron wheels.
			canvas.draw_rect(Rect2(p - half + Vector2(0, 2), size - Vector2(0, 5)), Color("#8C5A3C"))
			canvas.draw_line(p + Vector2(-half.x, -half.y + 2), p + Vector2(half.x, -half.y + 2), MAGENTA, 2)
			canvas.draw_rect(Rect2(p + Vector2(-half.x + 2, half.y - 3), Vector2(3, 3)), Color("#4A4E54"))
			canvas.draw_rect(Rect2(p + Vector2(half.x - 5, half.y - 3), Vector2(3, 3)), Color("#4A4E54"))
			canvas.draw_rect(Rect2(p + Vector2(-2, -half.y), Vector2(4, 4)), MAGENTA)
			for x in [-half.x+3,half.x-3]:
				var wheel := p+Vector2(x,half.y-2)
				canvas.draw_circle(wheel,2,Color("85909c"))
				canvas.draw_line(wheel,wheel+Vector2.from_angle(world_time*9)*2,YELLOW,1)
			canvas.draw_rect(Rect2(p+Vector2(-half.x-3,half.y-2-fposmod(world_time*14,6)),Vector2.ONE),YELLOW)
		_:
			# Fractured future anomaly, angular and recognizably hostile.
			var points := PackedVector2Array([p + Vector2(0, -half.y), p + Vector2(half.x, 0), p + Vector2(0, half.y), p + Vector2(-half.x, 0)])
			canvas.draw_colored_polygon(points, Color("#2E2E3A"))
			points.append(points[0])
			canvas.draw_polyline(points, MAGENTA, 1)
			canvas.draw_rect(Rect2(p - Vector2(2, 3), Vector2(4, 6)), MAGENTA)
			var offset := sin(world_time * 5.0) * 2.0
			canvas.draw_line(p + Vector2(-half.x, offset), p + Vector2(half.x, -offset), WHITE, 1)
	if bool(spike.get("bounceable", false)):
		canvas.draw_line(p + Vector2(-half.x, -half.y), p + Vector2(half.x, -half.y), YELLOW, 2)
		canvas.draw_line(p + Vector2(-3, -half.y - 5), p + Vector2(0, -half.y - 2), YELLOW)
		canvas.draw_line(p + Vector2(0, -half.y - 2), p + Vector2(3, -half.y - 5), YELLOW)


static func watcher(canvas: Node2D, watcher: Dictionary, epoch: int, frozen: bool = true) -> void:
	var p: Vector2 = Vector2(watcher.pos).round()
	p.x += roundf(float(watcher.get("flash",0))*14)
	var charge := clampf(float(watcher.timer) / float(watcher.interval), 0.0, 1.0)
	var warning := YELLOW if charge > 0.72 else Color(YELLOW, 0.38)
	if bool(watcher.get("tracking", false)) and charge > 0.72:
		canvas.draw_dashed_line(p + Vector2(watcher.get("locked_aim",watcher.aim)) * 8.0, p + Vector2(watcher.get("locked_aim",watcher.aim)) * 28.0, Color(YELLOW, 0.4), 1.0, 3.0)
	match epoch:
		0, 1:
			canvas.draw_rect(Rect2(p + Vector2(-6, 5), Vector2(12, 3)), Color("#D8B26A"))
			canvas.draw_rect(Rect2(p + Vector2(-4, 0), Vector2(8, 6)), Color("#A5502C"))
			canvas.draw_colored_polygon(PackedVector2Array([p + Vector2(-7, 0), p + Vector2(0, -6), p + Vector2(7, 0), p + Vector2(0, 5)]), Color("#D8B26A"))
			canvas.draw_colored_polygon(PackedVector2Array([p + Vector2(-5, 0), p + Vector2(0, -3), p + Vector2(5, 0), p + Vector2(0, 3)]), INK)
		2:
			canvas.draw_rect(Rect2(p + Vector2(-5, -7), Vector2(10, 15)), Color("#8C5A3C"))
			canvas.draw_rect(Rect2(p + Vector2(-7, -4), Vector2(14, 8)), Color("#4A4E54"))
			canvas.draw_rect(Rect2(p - Vector2(4, 4), Vector2(8, 8)), INK)
			canvas.draw_arc(p, 4.0, -PI / 2, -PI / 2 + TAU * charge, 12, warning, 1)
			canvas.draw_line(p, p + Vector2(sin(charge * TAU), -cos(charge * TAU)) * 3, YELLOW, 1)
		_:
			canvas.draw_line(p + Vector2(-10, -2), p + Vector2(10, -2), Color("#2E2E3A"), 3)
			canvas.draw_rect(Rect2(p + Vector2(-11, -4), Vector2(4, 3)), CYAN)
			canvas.draw_rect(Rect2(p + Vector2(7, -4), Vector2(4, 3)), CYAN)
			canvas.draw_colored_polygon(PackedVector2Array([p + Vector2(-6, -3), p + Vector2(6, -3), p + Vector2(4, 4), p + Vector2(-4, 4)]), Color("#2E2E3A"))
			canvas.draw_line(p + Vector2(-4, 4), p + Vector2(4, 4), MAGENTA)
	var look: Vector2 = watcher.get("locked_aim",Vector2.LEFT) if bool(watcher.get("locked",false)) else watcher.get("aim",Vector2.LEFT)
	canvas.draw_rect(Rect2(p - Vector2(1, 2)+look*2, Vector2(2, maxf(1,charge*4))), RED if float(watcher.flash) > 0 else warning)
	canvas.draw_rect(Rect2(p + Vector2(-6, -11), Vector2(12, 2)), Color(YELLOW, 0.18))
	canvas.draw_rect(Rect2(p + Vector2(-6, -11), Vector2(floorf(charge * 12.0), 2)), warning)
	if float(watcher.get("flash",0)) > 0:
		for n in range(3): canvas.draw_rect(Rect2(p+Vector2(-7+n*7,12-float(watcher.flash)*20),Vector2.ONE),Color(YELLOW,0.7))
	if frozen:
		canvas.draw_line(p + Vector2(-7, 9), p + Vector2(7, 9), Color(CYAN, 0.5))


