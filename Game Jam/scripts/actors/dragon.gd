extends Node2D
## Pyrax uses ONLY explicit world delta. Drawing and collision share geometry.
##
## The encounter is a state machine (scripts/actors/dragon_states/) crossed with
## three attack patterns (scripts/actors/dragon_patterns/). Timing stays here
## because `age` and `clock` advance on world time, not frame time, and that is
## the whole rule of the game.
##
## `state` remains a plain assignable String on purpose. The boss tests, the
## capture tool, the HUD and the director all read or write it, and assigning it
## must stay side-effect free: it rebinds which behaviour is consulted and
## nothing more. Real transitions go through _advance(), which runs exit/enter.

const GOLD := Color("ffd15c")
const FIRE := Color("ff862e")
const RED := Color("ff5a67")
const CYAN := Color("61e7ff")
const DARK := Color("351f31")
const SCALE := Color("854339")
## Swept segment/rect helpers are shared with the hazard system.
const Geometry = preload("res://scripts/world/hazards.gd")
const Atmosphere = preload("res://scripts/world/atmosphere.gd")
const StateMachine = preload("res://scripts/systems/state_machine.gd")

const STATE_SCRIPTS := {
	&"prepare": preload("res://scripts/actors/dragon_states/prepare.gd"),
	&"warning": preload("res://scripts/actors/dragon_states/warning.gd"),
	&"attack": preload("res://scripts/actors/dragon_states/attack.gd"),
	&"recover": preload("res://scripts/actors/dragon_states/recover.gd"),
	&"transition": preload("res://scripts/actors/dragon_states/transition.gd"),
	&"defeat": preload("res://scripts/actors/dragon_states/defeat.gd"),
}

const PATTERN_SCRIPTS := [
	preload("res://scripts/actors/dragon_patterns/breath.gd"),
	preload("res://scripts/actors/dragon_patterns/volley.gd"),
	preload("res://scripts/actors/dragon_patterns/claw.gd"),
]

## Body box. Solid contact is never phaseable.
const BODY_RECT := Rect2(248, 88, 46, 56)
## Where the recovery cell sits, and how close Milo must get to take it.
const CELL_POSITION := Vector2(112, 144)
const CELL_RADIUS: float = 13.0
## The weak point only opens this far into the recovery window.
const OPENING_DELAY: float = 0.4

var health := 8
var phase := 1
var active := false
var clock := 0.0
var age := 0.0
var attack := 0
var cycle := 0
var hurt := 0.0
var target_x := 155.0
var projectiles: Array = []
var last_strike := -1
var hit_this_opening := false
var recharge_available := false
var arena := Rect2(560, 246, 320, 144)
var previous_player := Vector2.ZERO
var throat: PointLight2D
var completed := false
var strike_hits := 0
var attacks_seen: Array[int] = []

var _machine := StateMachine.new()
var _patterns: Array = []

## Assigning rebinds behaviour without running enter/exit, exactly like the
## plain string it replaces. Use _advance() for a real transition.
var state: String = "dormant":
	set(value):
		state = value
		_machine.rebind(StringName(value))


func _init() -> void:
	_machine.host = self
	for state_id: StringName in STATE_SCRIPTS:
		_machine.add(state_id, STATE_SCRIPTS[state_id].new())
	for index in range(PATTERN_SCRIPTS.size()):
		var made = PATTERN_SCRIPTS[index].new()
		made.host = self
		made.index = index
		_patterns.append(made)


func setup(rect: Rect2) -> void:
	arena = rect
	position = arena.position
	throat = Atmosphere.make_light(FIRE, 80, 0.6)
	add_child(throat)
	throat.position = head_position()


func start(player: Node2D) -> void:
	active = true
	state = "prepare"
	age = 0
	previous_player = player.position - position
	queue_redraw()


## The attack pattern this cycle is running.
func pattern():
	return _patterns[clampi(attack, 0, _patterns.size() - 1)]


func duration() -> float:
	if _machine.current == null:
		return 99999.0
	return _machine.current.duration()


## Runs the state's own timeout and transition. Kept under the old name because
## the boss tests drive a transition by hand through it.
func _next(player: Node2D) -> void:
	age = 0
	if _machine.current == null:
		return
	_machine.current.timeout()
	var landed: StringName = _machine.advance(player)
	# Keep the public string in step without re-entering through the setter.
	state = String(landed)


func spawn_volley(followup: bool) -> void:
	for n in range(3):
		# Horizontal lanes have 25px gaps for a 14px player. Floor remains safe.
		var y := 58.0 + n * 28.0 + (10 if followup else 0)
		projectiles.append({"pos": Vector2(218, y), "previous": Vector2(218, y), "velocity": Vector2(-64 - n * 4, 0)})


## Retained for the boss tests, which fire a volley directly.
func _volley(followup: bool) -> void:
	spawn_volley(followup)


func head_position() -> Vector2:
	var p := Vector2(230, 83 + sin(clock * 1.8) * 2)
	var override: Vector2 = pattern().head_override(StringName(state))
	if state == "warning":
		p += Vector2(8 * minf(age / 0.5, 1), -5)
	if state == "attack":
		if override != Vector2.INF:
			p = override
		else:
			p += pattern().head_offset(&"attack", p)
	if state == "recover":
		p = p.lerp(Vector2(210, 120), minf(age / 0.35, 1))
	if state == "transition":
		p += Vector2(0, -12 * sin(age * PI / 1.4))
	if state == "defeat":
		p += Vector2(-18 * minf(age, 1), 45 * minf(age / 1.5, 1))
	return (p + Vector2(hurt * 14, -hurt * 9)).round()


func weak_rect() -> Rect2:
	return Rect2(head_position() + Vector2(-10, -7), Vector2(19, 16))


func fire_polygon() -> PackedVector2Array:
	var mouth := head_position() + Vector2(-8, 5)
	var end := Vector2(76, 130 + sin(age * 2.5) * 6)
	var normal := (end - mouth).normalized().orthogonal() * 6
	return PackedVector2Array([mouth + normal, end + normal, end - normal, mouth - normal])


func claw_rect() -> Rect2:
	return Rect2(target_x - 18, 105, 36, 39)


func wave_rect() -> Rect2:
	return Rect2(target_x - 20 - maxf(0, age - 0.18) * 86, 134, 12, 10)


func world_step(dt: float, player: Node2D, strike: Dictionary = {}) -> Dictionary:
	var result := {"dead": false, "hit": false, "refill": false, "complete": false}
	if not active:
		return result
	var p: Vector2 = player.position - position
	var rect := Rect2(p + Vector2(-4, -14), Vector2(8, 14))
	if dt > 0:
		_advance_time(dt, player)
	if state not in ["defeat", "transition"]:
		# Body and solid impacts cannot be phased. Head is approachable in recovery.
		if rect.intersects(BODY_RECT):
			result.dead = true
		if state == "attack":
			var swept := Rect2(previous_player + Vector2(-4, -14), Vector2(8, 14)).merge(rect)
			if pattern().is_lethal(swept, age):
				result.dead = true
		for bullet in projectiles:
			if Geometry._segment_hits_rect(bullet.previous if dt > 0 else bullet.pos, bullet.pos, rect.grow(4)) and not player.can_phase():
				result.dead = true
		if state == "recover" and recharge_available and p.distance_to(CELL_POSITION) < CELL_RADIUS:
			player.refill_at_anchor()
			recharge_available = false
			result.refill = true
		if not result.dead:
			_resolve_strike(dt, strike, result)
	previous_player = p
	_update_throat()
	result.complete = completed
	queue_redraw()
	return result


func _advance_time(dt: float, player: Node2D) -> void:
	clock += dt
	hurt = maxf(0, hurt - dt)
	var before := age
	age += dt
	if state == "attack" and before < 0.8 and age >= 0.8:
		pattern().midpoint(phase)
	if age >= duration():
		_next(player)
	for bullet in projectiles:
		bullet.previous = bullet.pos
		bullet.pos += bullet.velocity * dt
	projectiles = projectiles.filter(func(b): return b.pos.x > 8)


func _resolve_strike(dt: float, strike: Dictionary, result: Dictionary) -> void:
	if state != "recover" or age <= OPENING_DELAY or hit_this_opening:
		return
	if dt <= 0 or strike.is_empty() or int(strike.id) == last_strike:
		return
	var hitbox: Rect2 = strike.rect
	hitbox.position -= position
	if not hitbox.intersects(weak_rect()):
		return
	last_strike = int(strike.id)
	health -= 1
	strike_hits += 1
	hurt = 0.5
	hit_this_opening = true
	result.hit = true
	# Half health and death are forced rebinds: they interrupt recovery instead
	# of completing it, so the recover exit work must not run.
	if health == 4:
		phase = 2
		state = "transition"
		age = 0
		projectiles.clear()
	elif health <= 0:
		state = "defeat"
		age = 0
		projectiles.clear()


func _update_throat() -> void:
	if not is_instance_valid(throat):
		return
	throat.position = head_position()
	var warmth: float = age / duration() if state == "warning" else 0.0
	var blast: float = 1.1 if state == "attack" and attack == 0 else 0.0
	var cooling: float = age * 0.2 if state == "defeat" else 0.0
	throat.energy = maxf(0.15, 0.5 + warmth + blast - cooling)


## Filled polygon with a dark outline, the boss's signature silhouette style.
func draw_outlined_polygon(canvas: CanvasItem, points: Array, color: Color) -> void:
	var poly := PackedVector2Array(points)
	canvas.draw_colored_polygon(poly, color)
	poly.append(poly[0])
	canvas.draw_polyline(poly, Color("1a1623"), 1)


func _poly(points: Array, color: Color) -> void:
	draw_outlined_polygon(self, points, color)


func _draw() -> void:
	var breath := sin(clock * 1.8) * 2
	var body := Vector2(264, 100 + breath)
	var h := head_position()
	var collapse := minf(age / 2, 1) if state == "defeat" else 0.0
	var wing: float = sin(clock * 2.1) * 12 - (16 * minf(age / 0.5, 1) if state == "warning" else 0)
	if state == "attack":
		wing += 18 * sin(minf(age / 0.5, 1) * PI / 2)
	wing += collapse * 40
	# Segmented tail, two articulated wings, torso, bent neck, jaw, horns, claws.
	var prev := body + Vector2(14, 9)
	for n in range(7):
		var next := Vector2(280 + n * 4, 115 + sin(clock * 2 - n * 0.6) * (3 + n * 0.7) + n * 2)
		draw_line(prev.round(), next.round(), SCALE.darkened(n * 0.07), maxf(2, 10 - n))
		_poly([next + Vector2(-3, 0), next + Vector2(0, -6), next + Vector2(3, 0)], GOLD.darkened(0.3))
		prev = next
	_poly([body + Vector2(2, -10), Vector2(312, 22 + wing), Vector2(305, 97 + wing / 3)], Color("503042"))
	_poly([body + Vector2(-9, -5), Vector2(230, 28 + wing), Vector2(184, 16 + wing), Vector2(202, 62 + wing / 2), Vector2(220, 53 + wing / 2), Vector2(231, 78 + wing / 3)], Color("aa4b35") if phase == 2 else Color("743445"))
	for end in [Vector2(184, 16 + wing), Vector2(202, 62 + wing / 2), Vector2(220, 53 + wing / 2)]:
		draw_line(Vector2(230, 28 + wing), end.round(), FIRE.darkened(0.2), 2)
	_poly([body + Vector2(-15, -18), body + Vector2(11, -20), body + Vector2(24, -2), body + Vector2(15, 24), body + Vector2(-8, 28), body + Vector2(-20, 7)], SCALE)
	_poly([body + Vector2(-13, -10), body + Vector2(-3, -9), body + Vector2(2, 20), body + Vector2(-11, 24)], FIRE.darkened(0.35))
	var neck := Vector2(244, 72 + breath)
	draw_line(body + Vector2(-12, -4), neck, DARK, 17)
	draw_line(neck, h + Vector2(12, 0), DARK, 15)
	draw_line(body + Vector2(-13, -5), neck, SCALE, 12)
	draw_line(neck, h + Vector2(12, 0), SCALE, 10)
	draw_line(neck + Vector2(-2, 4), h + Vector2(6, 5), FIRE if state in ["warning", "attack"] else GOLD.darkened(0.45), 4)
	for n in range(3):
		var q := neck.lerp(h + Vector2(12, 0), n / 3.0)
		_poly([q + Vector2(0, -4), q + Vector2(8, -13), q + Vector2(7, -2)], GOLD.darkened(0.2))
	_poly([h + Vector2(12, -7), h + Vector2(2, -10), h + Vector2(-9, -5), h + Vector2(-16, 3), h + Vector2(-4, 6), h + Vector2(10, 3)], FIRE.lightened(0.15) if hurt > 0 else SCALE.lightened(0.2))
	var jaw: float = 6.0 if state == "attack" else (4 * age / duration() if state == "warning" else 0)
	_poly([h + Vector2(9, 3), h + Vector2(-13, 5 + jaw), h + Vector2(-5, 10 + jaw), h + Vector2(11, 7)], SCALE.darkened(0.3))
	_poly([h + Vector2(8, -7), h + Vector2(20, -21), h + Vector2(15, -5)], GOLD)
	draw_rect(Rect2(h + Vector2(-5, -4), Vector2(4, 2)), CYAN if state == "defeat" else GOLD)
	for n in range(3):
		draw_line(h + Vector2(-10 + n * 5, 5), h + Vector2(-9 + n * 5, 8), GOLD)
	_draw_limbs(body)
	if state == "warning":
		pattern().draw_warning(self)
	if state == "attack":
		pattern().draw_attack(self, age)
	for bullet in projectiles:
		var p: Vector2 = Vector2(bullet.pos).round()
		draw_line(p + Vector2(11, 0), p, Color(FIRE, 0.3), 3)
		draw_circle(p, 4, FIRE)
		draw_rect(Rect2(p - Vector2(2, 2), Vector2(4, 4)), GOLD)
	if state == "recover" and age > OPENING_DELAY and not hit_this_opening:
		_draw_opening()
	if recharge_available:
		draw_arc(Vector2(112, 137), 8, 0, TAU, 16, CYAN, 1)
		_poly([Vector2(112, 130), Vector2(116, 137), Vector2(112, 143), Vector2(108, 137)], CYAN)
	for n in range(22):
		var p := Vector2(188 + fposmod(n * 31.0 + clock * 7, 120), 140 - fposmod(n * 17.0 + clock * (7 + n % 3), 120))
		draw_rect(Rect2(p.round(), Vector2(1, 2)), Color(CYAN if state == "defeat" else FIRE, 0.4))


func _draw_limbs(body: Vector2) -> void:
	for side in [0, 1]:
		var foot := Vector2(246 + side * 32, 140)
		if side == 0:
			var override: Vector2 = pattern().foot_override(StringName(state), age)
			if override != Vector2.INF:
				foot = override
		var shoulder := body + Vector2(-8 + side * 23, 0)
		var elbow := shoulder.lerp(foot, 0.5) + Vector2(-10, 0)
		draw_polyline(PackedVector2Array([shoulder, elbow, foot]), DARK, 9)
		draw_polyline(PackedVector2Array([shoulder, elbow, foot]), SCALE, 6)
		for n in range(3):
			draw_line(foot + Vector2(-5 + n * 4, 0), foot + Vector2(-7 + n * 4, 4), GOLD, 2)


func _draw_opening() -> void:
	var r := weak_rect()
	# Opening plates change the silhouette, not just its tint.
	_poly([r.position + Vector2(-3, 0), r.position + Vector2(-8, 8), r.position + Vector2(-3, 16)], CYAN)
	_poly([r.position + Vector2(22, 0), r.position + Vector2(27, 8), r.position + Vector2(22, 16)], CYAN)
	draw_circle(r.get_center(), 5, Color("0d1013"))
	draw_line(r.get_center() - Vector2(3, 0), r.get_center() + Vector2(3, 0), GOLD, 2)
