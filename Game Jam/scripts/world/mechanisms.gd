extends Node2D
## Room interactions are explicit world-time sensors, never independent timers.

const CYAN := Color("61e7ff")
const PINK := Color("ff5fcb")
const RED := Color("ff5a67")
const GOLD := Color("ffd15c")
const WHITE := Color("f8f8f2")

var barriers: Array = []
var gates: Array = []
var pads: Array = []
var anchors: Array = []
var fields: Array = []
var killzones: Array = []
var particles: Array = []
var active_anchor: int = -1
var previous_player := Vector2.ZERO
var world_time: float = 0.0
var frozen: bool = true


func setup(data: Dictionary, parent: Node2D = null) -> void:
	if parent != null and get_parent() == null:
		parent.add_child(self)
	for child in get_children():
		remove_child(child)
		child.queue_free()
	barriers.clear()
	gates.clear()
	pads.clear()
	anchors.clear()
	fields.clear()
	killzones.clear()
	particles.clear()
	active_anchor = -1
	world_time = 0.0
	frozen = true
	previous_player = data.get("spawn", Vector2.ZERO)
	for spec in data.get("barriers", []):
		var entry: Dictionary = spec.duplicate(true)
		entry["kind"] = spec.get("kind", "phase")
		entry["broken"] = false
		entry["area"] = _make_area(entry.rect)
		barriers.append(entry)
	for spec in data.get("gates", []):
		var entry: Dictionary = spec.duplicate(true)
		entry["period"] = maxf(float(spec.get("period", 3.0)), 0.5)
		entry["open_ratio"] = clampf(float(spec.get("open_ratio", 0.55)), 0.15, 0.85)
		entry["timer"] = fposmod(float(spec.get("phase", 0.0)), 1.0) * float(entry.period)
		entry["area"] = _make_area(entry.rect)
		_update_gate_state(entry)
		gates.append(entry)
	for spec in data.get("pads", []):
		var entry: Dictionary = spec.duplicate(true)
		entry["bounce"] = float(spec.get("bounce", 270.0))
		entry["flash"] = 0.0
		entry["area"] = _make_area(entry.rect)
		pads.append(entry)
	for spec in data.get("anchors", []):
		var entry: Dictionary = {"pos": spec} if spec is Vector2 else spec.duplicate(true)
		entry["flash"] = 0.0
		entry["rect"] = Rect2(Vector2(entry.pos) + Vector2(-8, -24), Vector2(16, 24))
		entry["area"] = _make_area(entry.rect)
		anchors.append(entry)
	for spec in data.get("fields", []):
		var entry: Dictionary = spec.duplicate(true)
		entry["multiplier"] = clampf(float(spec.get("multiplier", 0.5)), 0.5, 1.5)
		entry["area"] = _make_area(entry.rect)
		fields.append(entry)
	for rect: Rect2 in data.get("killzones", []):
		var area := _make_area(rect)
		area.collision_layer = 4
		killzones.append({"rect": rect, "area": area})
	queue_redraw()


func _make_area(rect: Rect2) -> Area2D:
	var area := Area2D.new()
	area.position = rect.get_center()
	area.collision_layer = 8
	area.collision_mask = 2
	area.monitoring = false
	var collider := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = rect.size
	collider.shape = shape
	area.add_child(collider)
	add_child(area)
	return area


func pre_player(player: CharacterBody2D) -> void:
	previous_player = player.position


func set_checkpoint(index: int, spawn: Vector2 = Vector2.INF) -> void:
	active_anchor = clampi(index, -1, anchors.size() - 1)
	if spawn != Vector2.INF:
		previous_player = spawn
	elif active_anchor >= 0:
		previous_player = anchors[active_anchor].pos
	queue_redraw()


func time_field_multiplier(player: CharacterBody2D) -> float:
	var center := player.position + Vector2(0, -7)
	for field in fields:
		if Rect2(field.rect).has_point(center):
			return float(field.multiplier)
	return 1.0


func world_step(dt: float, player: CharacterBody2D) -> Dictionary:
	var result := {"dead": false, "anchor": -1, "anchor_pos": Vector2.ZERO,
		"refilled": false, "bounced": false, "barrier_broken": false}
	frozen = dt <= 0.0
	if dt > 0.0:
		world_time += dt
		for i in range(particles.size() - 1, -1, -1):
			particles[i].life -= dt
			particles[i].pos += Vector2(particles[i].velocity) * dt
			if float(particles[i].life) <= 0.0:
				particles.remove_at(i)
		for pad in pads:
			pad.flash = maxf(0.0, float(pad.flash) - dt)
		for anchor in anchors:
			anchor.flash = maxf(0.0, float(anchor.flash) - dt)
	for killzone in killzones:
		if _touches_rect(player.position, killzone.rect):
			result.dead = true
	for gate in gates:
		if dt > 0.0:
			gate.timer = fposmod(float(gate.timer) + dt, float(gate.period))
			_update_gate_state(gate)
		if bool(gate.closed) and _touches_rect(player.position, gate.rect):
			result.dead = true
	for barrier in barriers:
		if bool(barrier.broken) or not _touches_rect(player.position, barrier.rect):
			continue
		var striking := bool(player.get("striking"))
		var phasing: bool = player.can_phase() if player.has_method("can_phase") else float(player.get("dash_left")) > 0.0
		var can_break: bool = striking if String(barrier.kind) == "fragile" else striking or phasing
		if can_break and dt > 0.0:
			barrier.broken = true
			result.barrier_broken = true
			_burst(Rect2(barrier.rect).get_center(), GOLD if String(barrier.kind) == "fragile" else PINK, 14)
		elif not can_break:
			result.dead = true
	for pad in pads:
		if not _touches_rect(player.position, pad.rect):
			continue
		var rect: Rect2 = pad.rect
		var from_above: bool = previous_player.y <= rect.position.y + 5.0 and player.velocity.y >= 0.0
		if bool(player.get("striking")) and from_above and dt > 0.0:
			player.position.y = rect.position.y - 0.05
			player.bounce_from_pad(float(pad.bounce))
			pad.flash = 0.25
			result.bounced = true
			_burst(Vector2(player.position.x, rect.position.y), CYAN, 12)
		else:
			result.dead = true
	# A lethal contact cannot activate a checkpoint on the same frame.
	if not bool(result.dead) and dt > 0.0:
		for index in range(anchors.size()):
			if index <= active_anchor or not _touches_rect(player.position, anchors[index].rect):
				continue
			active_anchor = index
			anchors[index].flash = 0.6
			result.anchor = index
			result.anchor_pos = anchors[index].pos
			result.refilled = true
			if player.has_method("refill_at_anchor"):
				player.refill_at_anchor()
			else:
				player.set("dash_charges", 2)
			_burst(Vector2(anchors[index].pos) + Vector2(0, -12), CYAN, 16)
	previous_player = player.position
	queue_redraw()
	return result


func _update_gate_state(gate: Dictionary) -> void:
	var opening_duration: float = float(gate.period) * float(gate.open_ratio)
	gate["open"] = float(gate.timer) < opening_duration
	gate["closed"] = not bool(gate.open)
	gate["until_change"] = opening_duration - float(gate.timer) if bool(gate.open) else float(gate.period) - float(gate.timer)
	gate["warning"] = float(gate.until_change) <= 0.3


func _touches_rect(feet: Vector2, rect: Rect2) -> bool:
	# Sweeping feet against this Minkowski expansion also catches a fast strike.
	var expanded := Rect2(rect.position - Vector2(4, 0), rect.size + Vector2(8, 14))
	var start := previous_player
	var ray := feet - start
	var near_time := 0.0
	var far_time := 1.0
	for axis in range(2):
		if absf(ray[axis]) < 0.000001:
			if start[axis] < expanded.position[axis] or start[axis] > expanded.end[axis]:
				return false
		else:
			var entry: float = (expanded.position[axis] - start[axis]) / ray[axis]
			var leave: float = (expanded.end[axis] - start[axis]) / ray[axis]
			if entry > leave:
				var swap := entry
				entry = leave
				leave = swap
			near_time = maxf(near_time, entry)
			far_time = minf(far_time, leave)
			if near_time > far_time:
				return false
	return true


func _burst(pos: Vector2, tint: Color, count: int) -> void:
	for i in range(count):
		var angle: float = TAU * float(i) / float(count)
		particles.append({"pos": pos, "velocity": Vector2(cos(angle), sin(angle)) * (16.0 + float(i % 4) * 9.0),
			"life": 0.35 + float(i % 3) * 0.06, "color": tint})


func _draw() -> void:
	for killzone in killzones:
		var rect: Rect2 = killzone.rect
		draw_rect(rect, Color(RED, 0.2))
		draw_line(Vector2(rect.position.x, rect.end.y - 1), rect.end - Vector2(0, 1), RED)
		for x in range(int(rect.position.x), int(rect.end.x) - 2, 6):
			var right := minf(float(x + 6), rect.end.x)
			draw_colored_polygon(PackedVector2Array([Vector2(x, rect.end.y), Vector2((float(x) + right) * 0.5, rect.position.y), Vector2(right, rect.end.y)]), RED)
	for field in fields:
		var rect: Rect2 = field.rect
		var tint: Color = CYAN if float(field.multiplier) < 1.0 else PINK
		draw_rect(rect, Color(tint, 0.065))
		draw_rect(rect, Color(tint, 0.4), false)
		for x in range(int(rect.position.x) + 5, int(rect.end.x), 12):
			var offset := fposmod(world_time * float(field.multiplier) * 5.0 + float(x % 19), maxf(1, rect.size.y - 6))
			draw_rect(Rect2(x, rect.position.y + 3 + floorf(offset), 2, 2), Color(tint, 0.25))
	for barrier in barriers:
		if bool(barrier.broken):
			continue
		var rect: Rect2 = barrier.rect
		var fragile: bool = String(barrier.kind) == "fragile"
		var tint := GOLD if fragile else PINK
		draw_rect(rect, Color(tint, 0.2))
		draw_rect(rect, tint, false)
		for y in range(int(rect.position.y) + 4, int(rect.end.y) - 2, 9):
			var p := Vector2(rect.get_center().x, y)
			if fragile:
				draw_line(p + Vector2(-3, -2), p + Vector2(0, 1), GOLD)
				draw_line(p + Vector2(0, 1), p + Vector2(3, -2), GOLD)
			else:
				draw_line(p + Vector2(-2, -3), p + Vector2(1, 0), PINK)
				draw_line(p + Vector2(1, 0), p + Vector2(-2, 3), PINK)
		if frozen:
			draw_line(rect.position, Vector2(rect.end.x, rect.position.y), CYAN)
	for gate in gates:
		var rect: Rect2 = gate.rect
		var tint := GOLD if bool(gate.warning) else RED
		draw_rect(rect, Color(GOLD, 0.25), false)
		if bool(gate.closed):
			draw_rect(rect, Color(tint, 0.20))
			for y in range(int(rect.position.y), int(rect.end.y) - 2, 6):
				draw_rect(Rect2(rect.position.x, y, rect.size.x, 2), tint)
		else:
			draw_line(rect.position, rect.position + Vector2(rect.size.x, 0), GOLD, 2)
			draw_line(Vector2(rect.position.x, rect.end.y), rect.end, GOLD, 2)
			if bool(gate.warning):
				draw_dashed_line(rect.position + Vector2(rect.size.x * 0.5, 2), rect.end - Vector2(rect.size.x * 0.5, 2), GOLD, 1, 3)
		var charge: float = float(gate.timer) / float(gate.period)
		draw_rect(Rect2(rect.position + Vector2(-2, -5), Vector2(rect.size.x + 4, 2)), Color(GOLD, 0.2))
		draw_rect(Rect2(rect.position + Vector2(-2, -5), Vector2((rect.size.x + 4) * charge, 2)), GOLD)
	for pad in pads:
		var rect: Rect2 = pad.rect
		draw_rect(rect, RED)
		draw_line(rect.position, Vector2(rect.end.x, rect.position.y), GOLD, 2)
		var center := rect.get_center()
		draw_line(center + Vector2(-4, -7), center + Vector2(0, -3), CYAN if float(pad.flash) > 0.0 else GOLD)
		draw_line(center + Vector2(0, -3), center + Vector2(4, -7), CYAN if float(pad.flash) > 0.0 else GOLD)
	for i in range(anchors.size()):
		var anchor: Dictionary = anchors[i]
		var p: Vector2 = anchor.pos
		var tint := CYAN if i <= active_anchor else Color("42727c")
		draw_rect(Rect2(p + Vector2(-7, -3), Vector2(14, 3)), tint)
		draw_rect(Rect2(p + Vector2(-2, -19), Vector2(4, 16)), tint)
		var diamond := PackedVector2Array([p + Vector2(0, -26), p + Vector2(6, -20), p + Vector2(0, -14), p + Vector2(-6, -20), p + Vector2(0, -26)])
		draw_polyline(diamond, WHITE if float(anchor.flash) > 0.0 else CYAN, 1)
		draw_rect(Rect2(p + Vector2(-1, -21), Vector2(2, 2)), WHITE)
	for particle in particles:
		draw_rect(Rect2(Vector2(particle.pos).round(), Vector2(2, 2)), Color(particle.color, clampf(float(particle.life) * 3.0, 0.0, 1.0)))

func draw_labels(canvas: Node2D) -> void:
	# Called by the window-resolution overlay, with the world camera transform.
	for field in fields:
		var text := "0.5x FIELD" if float(field.multiplier) < 1.0 else "1.5x FIELD"
		canvas.draw_string(ThemeDB.fallback_font, Rect2(field.rect).position + Vector2(3, 8), text, HORIZONTAL_ALIGNMENT_LEFT, -1, 8, CYAN if float(field.multiplier) < 1.0 else PINK)
	for anchor in anchors:
		canvas.draw_string(ThemeDB.fallback_font, Vector2(anchor.pos) + Vector2(-16, -29), "ANCHOR", HORIZONTAL_ALIGNMENT_LEFT, -1, 8, CYAN)
