extends RefCounted
## Afterimage trail and impact particles for Milo.
##
## Owned by the player rather than being a node of its own, so everything draws
## into the player's canvas item and keeps the exact same z-order.
##
## Nothing here runs on frame time. The player only calls advance() while it is
## actually moving, so when Milo stops, the world stops and these freeze in
## place with it - a particle hanging mid-air is the point, not a glitch.

const Figure = preload("res://scripts/actors/milo_figure.gd")
const CYAN: Color = Color("61e7ff")
const MAGENTA: Color = Color("ff5fcb")

const MAX_PARTICLES: int = 72
const MAX_GHOSTS: int = 8
const GHOST_LIFE: float = 0.19
const GHOST_INTERVAL: float = 0.022
const PARTICLE_GRAVITY: float = 60.0
const IMPACT_DURATION: float = 0.18

var trail: Array[Dictionary] = []
var particles: Array[Dictionary] = []
var impact_left: float = 0.0
var _ghost_clock: float = 0.0


func clear() -> void:
	trail.clear()
	particles.clear()
	impact_left = 0.0
	_ghost_clock = 0.0


## Starts a fresh trail: the next advance() spawns a ghost straight away, so a
## dash always leaves an afterimage on its very first frame.
func begin_trail() -> void:
	_ghost_clock = 0.0


## `clock` is the player's motion clock: it only offsets the burst pattern, so
## two bursts fired at the same spot never overlap exactly.
func burst(origin: Vector2, direction: Vector2, tint: Color, count: int, strength: float, clock: float) -> void:
	for index in range(count):
		var angle: float = TAU * float(index) / float(maxi(count, 1)) + clock * 1.3
		var spread := Vector2(cos(angle), sin(angle))
		var drift: Vector2 = (spread * 0.65 + direction) * strength * (0.6 + float(index % 3) * 0.2)
		var color: Color = tint if index % 3 != 0 else CYAN
		particles.append({"pos": origin + Vector2(0, -5), "velocity": drift, "life": 0.24 + float(index % 4) * 0.03, "max_life": 0.33, "color": color})
	while particles.size() > MAX_PARTICLES:
		particles.pop_front()


## Call only with active-motion time. `clock` must already include this delta,
## so a ghost records the same animation frame the live figure is showing.
func advance(delta: float, previous_position: Vector2, ghosting: bool, pose: String, facing: int, clock: float) -> void:
	impact_left = maxf(0.0, impact_left - delta)
	for index in range(trail.size() - 1, -1, -1):
		var life: float = float(trail[index].life) - delta
		trail[index].life = life
		if life <= 0.0:
			trail.remove_at(index)
	for index in range(particles.size() - 1, -1, -1):
		var particle: Dictionary = particles[index]
		particle.life = float(particle.life) - delta
		particle.pos = Vector2(particle.pos) + Vector2(particle.velocity) * delta
		particle.velocity = Vector2(particle.velocity) + Vector2(0.0, PARTICLE_GRAVITY) * delta
		if float(particle.life) <= 0.0:
			particles.remove_at(index)
	if not ghosting:
		return
	_ghost_clock -= delta
	if _ghost_clock > 0.0:
		return
	trail.append({"position": previous_position, "facing": facing, "life": GHOST_LIFE, "pose": pose, "frame": int(clock * 36.0) % 8})
	_ghost_clock = GHOST_INTERVAL
	if trail.size() > MAX_GHOSTS:
		trail.pop_front()


## Drawn beneath the live figure, in the player's local space.
func draw(canvas: CanvasItem, origin: Vector2, costume: int = 0) -> void:
	for ghost in trail:
		var opacity: float = clampf(float(ghost.life) / GHOST_LIFE, 0.0, 1.0) * 0.42
		var tint: Color = CYAN if int(ghost.frame) % 2 == 0 else MAGENTA
		Figure.figure(canvas, (Vector2(ghost.position) - origin).round(), int(ghost.facing), Color(tint, opacity), String(ghost.pose), int(ghost.frame), false, 0.0, 1.0, costume)
	for particle in particles:
		var local_point: Vector2 = (Vector2(particle.pos) - origin).round()
		var opacity: float = clampf(float(particle.life) / float(particle.max_life), 0.0, 1.0)
		canvas.draw_rect(Rect2(local_point, Vector2(2, 1)), Color(Color(particle.color), opacity))
	if impact_left > 0.0:
		var spread: float = roundf((IMPACT_DURATION - impact_left) * 65.0)
		canvas.draw_line(Vector2(-spread - 3, -1), Vector2(-spread, -1), Color(CYAN, impact_left * 4.0))
		canvas.draw_line(Vector2(spread, -1), Vector2(spread + 3, -1), Color(CYAN, impact_left * 4.0))
