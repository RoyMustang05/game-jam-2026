extends Node2D
## Everything here advances on explicitly supplied world time, never frame time.

const MAGENTA := Color("#FF5FCB")
const CYAN := Color("#61E7FF")
const RED := Color("#FF5A67")
const WHITE := Color("#F8F8F2")
const AssetArt = preload("res://scripts/world/asset_art.gd")
const ECHO_DELAY := 1.7

var spikes: Array = []
var watchers: Array = []
var projectiles: Array = []
var echo_history: Array = []
var echo_position := Vector2.ZERO
var echo_visible := false
var world_time := 0.0
var frozen := true
var epoch := 0
var solids: Array = []
var echo_enabled := false
var echo_time := 0.0
var previous_player := Vector2.ZERO
var bounced := false
var spike_areas: Array[Area2D] = []
var echo_area: Area2D
var echo_shape: CollisionShape2D


func setup(data: Dictionary, index: int) -> void:
	for child in get_children():
		remove_child(child)
		child.queue_free()
	spike_areas.clear()
	echo_area = null
	echo_shape = null
	epoch = int(data.get("chapter", index))
	echo_enabled = bool(data.get("echo", epoch == 3))
	echo_time = 0.0
	world_time = 0.0
	frozen = true
	spikes.clear()
	watchers.clear()
	projectiles.clear()
	echo_history.clear()
	echo_visible = false
	echo_position = data.get("spawn", Vector2.ZERO)
	previous_player = echo_position
	solids = data.get("solids", []).duplicate()
	for entry in data.get("spikes", []):
		var spike: Dictionary = entry.duplicate(true)
		spike["a"] = entry.get("a", Vector2.ZERO)
		spike["b"] = entry.get("b", spike.a)
		spike["speed"] = entry.get("speed", 25.0)
		spike["phase"] = entry.get("phase", 0.0)
		spike["size"] = entry.get("size", Vector2(14, 12))
		spike["pos"] = _spike_position(spike)
		spike["previous"] = spike.pos
		spikes.append(spike)
		var sensor := _make_sensor(Vector2(spike.size))
		sensor.position = spike.pos
		spike_areas.append(sensor)
	for entry in data.get("watchers", []):
		var watcher: Dictionary = entry.duplicate(true)
		watcher["pos"] = entry.get("pos", Vector2.ZERO)
		watcher["interval"] = 1.0
		watcher["timer"] = fposmod(float(entry.get("phase", 0.0)), 1.0) * float(watcher.interval)
		watcher["speed"] = entry.get("speed", 55.0)
		watcher["range"] = float(entry.get("range", 190.0))
		watcher["direction"] = Vector2(entry.get("direction", Vector2.LEFT)).normalized()
		watcher["fov"] = float(entry.get("fov", 200.0))
		watcher["tracking"] = false
		watcher["aim"] = Vector2.LEFT
		watcher["flash"] = 0.0
		watcher["locked"] = false
		watcher["locked_aim"] = Vector2.LEFT
		watchers.append(watcher)
	if echo_enabled and data.has("spawn"):
		echo_history.append({"t": 0.0, "pos": echo_position})
	if echo_enabled:
		echo_area = _make_sensor(Vector2(8, 14), Vector2(0, -7))
		echo_area.position = echo_position
		echo_shape = echo_area.get_child(0) as CollisionShape2D
		echo_shape.disabled = true
	queue_redraw()


func _make_sensor(size: Vector2, offset: Vector2 = Vector2.ZERO) -> Area2D:
	# Inspectable Godot collision geometry; explicit swept tests remain authoritative.
	var area := Area2D.new()
	area.collision_layer = 4
	area.collision_mask = 2
	area.monitoring = false
	var collider := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = size
	collider.shape = shape
	collider.position = offset
	area.add_child(collider)
	add_child(area)
	return area


func reset_echo(spawn: Vector2) -> void:
	echo_history.clear()
	echo_position = spawn
	previous_player = spawn
	echo_time = 0.0
	echo_visible = false
	if echo_enabled:
		echo_history.append({"t": 0.0, "pos": spawn})
	if is_instance_valid(echo_area):
		echo_area.position = spawn
		echo_shape.disabled = true
	queue_redraw()


func world_step(dt: float, player: CharacterBody2D, echo_delta: float = -1.0) -> bool:
	frozen = dt <= 0.0
	bounced = false
	var player_rect := Rect2(player.position + Vector2(-4, -14), Vector2(8, 14))
	if dt <= 0.0:
		queue_redraw()
		# Invulnerability can end on normal player time while world time is stopped.
		# Contact remains lethal without advancing any hazard or consuming a shot.
		previous_player = player.position
		return _current_contact(player_rect)
	var hit := false
	if echo_enabled and echo_history.is_empty():
		echo_history.append({"t": echo_time, "pos": player.position})
	world_time += dt
	for spike_index in range(spikes.size()):
		var spike: Dictionary = spikes[spike_index]
		spike.previous = spike.pos
		spike.pos = _spike_position(spike)
		spike["anim_time"] = world_time+float(spike.phase)*4.2
		spike_areas[spike_index].position = spike.pos
		var half: Vector2 = spike.size * 0.5
		var expanded := Rect2(player_rect.position - half, player_rect.size + half * 2.0)
		if _spike_crosses_rect(spike, dt, expanded):
			var marked: bool = bool(spike.get("bounceable", false))
			var from_above: bool = previous_player.y <= minf(Vector2(spike.previous).y, Vector2(spike.pos).y) - half.y + 5.0 and player.velocity.y >= 0.0
			if marked and bool(player.get("striking")) and from_above and player.has_method("bounce_from_pad"):
				player.position.y = Vector2(spike.pos).y - half.y - 0.05
				player.bounce_from_pad(float(spike.get("bounce", 270.0)))
				bounced = true
				player_rect.position = player.position + Vector2(-4, -14)
			else:
				hit = true
	for i in range(projectiles.size() - 1, -1, -1):
		var bullet: Dictionary = projectiles[i]
		var result := _advance_bullet(bullet, dt, player_rect)
		if result == 2:
			hit = true
		if result != 0:
			projectiles.remove_at(i)
	for watcher in watchers:
		watcher.flash = maxf(0.0, float(watcher.flash) - dt)
		watcher.tracking = _watcher_can_see(watcher, player.position + Vector2(0, -7))
		watcher.timer += dt
		if not watcher.locked and float(watcher.timer) >= maxf(0,float(watcher.interval)-0.75):
			watcher.locked = true
			watcher.locked_aim = Vector2(watcher.aim)
			watcher["shot_ready"] = bool(watcher.tracking)
		while float(watcher.timer) >= float(watcher.interval):
			watcher.timer -= watcher.interval
			watcher.locked = false
			if not bool(watcher.get("shot_ready",false)) or not bool(watcher.tracking):
				continue
			watcher.flash = 0.12
			var direction: Vector2 = watcher.locked_aim
			if direction == Vector2.ZERO:
				direction = Vector2.LEFT
			watcher.aim = direction
			var bullet := {"pos": Vector2(watcher.pos), "previous": Vector2(watcher.pos),
				"velocity": direction * float(watcher.speed), "age": 0.0}
			# This shot existed only for the part of dt after its scheduled firing.
			var result := _advance_bullet(bullet, float(watcher.timer), player_rect)
			if result == 2:
				hit = true
			if result == 0:
				projectiles.append(bullet)
	if echo_enabled:
		echo_time += maxf(0.0, echo_delta if echo_delta >= 0.0 else dt)
		echo_history.append({"t": echo_time, "pos": player.position})
		var replay_time := echo_time - ECHO_DELAY
		echo_visible = replay_time >= 0.0
		if echo_visible:
			while echo_history.size() > 2 and float(echo_history[1].t) <= replay_time:
				echo_history.pop_front()
			var first: Dictionary = echo_history[0]
			var second: Dictionary = echo_history[1]
			var span := maxf(float(second.t) - float(first.t), 0.000001)
			var mix_amount := clampf((replay_time - float(first.t)) / span, 0.0, 1.0)
			echo_position = Vector2(first.pos).lerp(Vector2(second.pos), mix_amount)
			var echo_rect := Rect2(echo_position + Vector2(-3, -13), Vector2(6, 12))
			if echo_rect.intersects(player_rect):
				hit = true
		# A hard bound also covers unusually high custom simulation frequencies.
		while echo_history.size() > 2048:
			echo_history.pop_front()
		if is_instance_valid(echo_area):
			echo_area.position = echo_position
			echo_shape.disabled = not echo_visible
	previous_player = player.position
	queue_redraw()
	return hit


func _watcher_can_see(watcher: Dictionary, target: Vector2) -> bool:
	var source: Vector2 = watcher.pos
	var offset := target - source
	if offset.length() > float(watcher.range):
		return false
	if offset.length_squared() > 0.0001 and Vector2(watcher.direction).dot(offset.normalized()) < cos(deg_to_rad(float(watcher.fov) * 0.5)):
		return false
	# Camera-space visibility prevents a shot being launched from hidden scenery.
	if is_inside_tree():
		var screen_position := get_global_transform_with_canvas() * source
		if not get_viewport_rect().grow(-10.0).has_point(screen_position):
			return false
	for solid in solids:
		if solid is Rect2 and _segment_rect_fraction(source, target, solid) < 1.0:
			return false
	watcher.aim = offset.normalized()
	return true


func _current_contact(player_rect: Rect2) -> bool:
	for spike in spikes:
		var half: Vector2 = spike.size * 0.5
		var expanded := Rect2(player_rect.position - half, player_rect.size + half * 2.0)
		if _segment_hits_rect(spike.pos, spike.pos, expanded):
			return true
	for bullet in projectiles:
		if _segment_hits_rect(bullet.pos, bullet.pos, player_rect.grow(1.5)):
			return true
	if echo_visible:
		return Rect2(echo_position + Vector2(-3, -13), Vector2(6, 12)).intersects(player_rect)
	return false


func _spike_crosses_rect(spike: Dictionary, dt: float, rect: Rect2) -> bool:
	if bool(spike.get("lunge",false)):
		return _segment_hits_rect(spike.previous,spike.pos,rect)
	var distance: float = Vector2(spike.a).distance_to(Vector2(spike.b))
	if distance < 0.001 or float(spike.speed) <= 0.0:
		return _segment_hits_rect(spike.previous, spike.pos, rect)
	var travel_start := float(spike.phase) * 2.0 + (world_time - dt) * float(spike.speed) / distance
	var travel_end := travel_start + dt * float(spike.speed) / distance
	var first_turn := floorf(travel_start) + 1.0
	if first_turn > travel_end:
		return _segment_hits_rect(spike.previous, spike.pos, rect)
	# Respect a reflected patrol segment even if a large step ends near its start.
	if first_turn + 1.0 <= travel_end:
		return _segment_hits_rect(spike.a, spike.b, rect)
	var turning_point: Vector2 = spike.b if int(first_turn) % 2 != 0 else spike.a
	return _segment_hits_rect(spike.previous, turning_point, rect) or _segment_hits_rect(turning_point, spike.pos, rect)


func _spike_position(spike: Dictionary) -> Vector2:
	var a: Vector2 = spike.a
	var b: Vector2 = spike.b
	var distance := a.distance_to(b)
	if bool(spike.get("lunge",false)) and distance > 0.001:
		var t := fposmod(world_time+float(spike.phase)*4.2,4.2)
		var weight := 0.0
		if t < 1.2: weight = 0.15*t/1.2
		elif t < 2.0: weight = 0.15
		elif t < 2.4: weight = lerpf(0.15,1,(t-2)/0.4)
		elif t < 3: weight = 1
		else: weight = 1-(t-3)/1.2
		return a.lerp(b,weight)
	if distance < 0.001:
		return a
	var cycle := fposmod(float(spike.phase) * 2.0 + world_time * float(spike.speed) / distance, 2.0)
	return a.lerp(b, 1.0 - absf(cycle - 1.0))


func _advance_bullet(bullet: Dictionary, dt: float, player_rect: Rect2) -> int:
	var previous: Vector2 = bullet.pos
	var next: Vector2 = previous + Vector2(bullet.velocity) * dt
	bullet.previous = previous
	bullet.pos = next
	bullet.age += dt
	# Compare first intersections so a wall shields the player even in a long step.
	var player_t := _segment_rect_fraction(previous, next, player_rect.grow(1.5))
	var wall_t := 2.0
	for solid in solids:
		if solid is Rect2:
			wall_t = minf(wall_t, _segment_rect_fraction(previous, next, solid.grow(1.5)))
	if player_t <= 1.0 and player_t < wall_t:
		return 2
	if wall_t <= 1.0 or float(bullet.age) > 12.0 or next.y > 1000 or next.y < -500 or absf(next.x) > 10000:
		return 1
	return 0


static func _segment_hits_rect(a: Vector2, b: Vector2, rect: Rect2) -> bool:
	return _segment_rect_fraction(a, b, rect) <= 1.0


static func _segment_rect_fraction(a: Vector2, b: Vector2, rect: Rect2) -> float:
	var ray := b - a
	var near_time := 0.0
	var far_time := 1.0
	for axis in range(2):
		var start: float = a[axis]
		var movement: float = ray[axis]
		var low: float = rect.position[axis]
		var high: float = rect.end[axis]
		if absf(movement) < 0.000001:
			if start < low or start > high:
				return 2.0
		else:
			var entry := (low - start) / movement
			var leave := (high - start) / movement
			if entry > leave:
				var swap := entry
				entry = leave
				leave = swap
			near_time = maxf(near_time, entry)
			far_time = minf(far_time, leave)
			if near_time > far_time:
				return 2.0
	return near_time


func _draw() -> void:
	for spike in spikes:
		_draw_spike(spike)
	for watcher in watchers:
		_draw_watcher(watcher)
	for bullet in projectiles:
		var p: Vector2 = Vector2(bullet.pos).round()
		var trail: Vector2 = Vector2(bullet.velocity).normalized() * 4.0
		draw_line(p - trail, p, Color(RED, 0.35), 1.0)
		draw_rect(Rect2(p - Vector2.ONE, Vector2(2, 2)), RED)
	if echo_enabled and echo_visible:
		_draw_echo()


func _draw_spike(spike: Dictionary) -> void:
	AssetArt.spike(self, spike, epoch, world_time)

func _draw_watcher(watcher: Dictionary) -> void:
	AssetArt.watcher(self, watcher, epoch, frozen)

func _draw_echo() -> void:
	var p := echo_position.round()
	# The same compact, timeless traveler silhouette with a temporal afterimage.
	draw_rect(Rect2(p + Vector2(-3, -14), Vector2(6, 5)), MAGENTA)
	draw_rect(Rect2(p + Vector2(-3, -9), Vector2(6, 6)), MAGENTA)
	draw_rect(Rect2(p + Vector2(-4, -8), Vector2(1, 5)), MAGENTA)
	draw_rect(Rect2(p + Vector2(3, -8), Vector2(1, 5)), MAGENTA)
	var stride := 1.0 if sin(echo_time * 22.0) > 0.0 else 0.0
	draw_rect(Rect2(p + Vector2(-3, -3), Vector2(2, 3 - stride)), MAGENTA)
	draw_rect(Rect2(p + Vector2(1, -3), Vector2(2, 2 + stride)), MAGENTA)
	draw_rect(Rect2(p + Vector2(0, -12), Vector2(3, 2)), WHITE)
	draw_rect(Rect2(p + Vector2(-2, -8), Vector2(1, 2)), WHITE)
	draw_line(p + Vector2(-6, -7), p + Vector2(6, -7), Color(CYAN if frozen else MAGENTA, 0.5))
