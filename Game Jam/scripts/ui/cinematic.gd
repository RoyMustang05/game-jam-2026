extends Node2D
## Unscaled presentation only. The director owns simulation and room loading.
const DrawText = preload("res://scripts/ui/draw_text.gd")
const STORY_IMAGES = [preload("res://assets/story/broken_machine.png"), preload("res://assets/story/prehistoric_danger.png")]
const BEAT_SECONDS = [2.5, 4.0, 3.5, 3.5]
const PORTAL_SECONDS: float = 2.35
const CYAN := Color("61e7ff")
const PINK := Color("ff5fcb")
const GOLD := Color("ffd15c")
var game: Node2D
var beat: int = 0
var elapsed: float = 0.0
var portal_loaded: bool = false
var portal_started_usec: int = 0
var last_portal_seconds: float = 0.0
var whoosh_played: bool = false
var arrival_played: bool = false

func start_story() -> void:
	beat = 0
	elapsed = 0.0
	game.state = "story"
	queue_redraw()

func advance_story() -> void:
	if beat == BEAT_SECONDS.size() - 1:
		finish_story()
	else:
		beat += 1
		elapsed = 0.0
	queue_redraw()

func finish_story() -> void:
	game.load_level(0)
	game.consume_cinematic_input()
	queue_redraw()

func start_portal() -> void:
	elapsed = 0.0
	portal_loaded = false
	whoosh_played = false
	arrival_played = false
	portal_started_usec = Time.get_ticks_usec()
	game.player.set_process(false)
	var next_path: String = "res://rooms/room_%02d.tscn" % (game.level_index + 2)
	ResourceLoader.load_threaded_request(next_path)
	game._play("portal_open")
	queue_redraw()

func _process(delta: float) -> void:
	if game.state == "story":
		elapsed += delta
		if elapsed >= BEAT_SECONDS[beat]:
			advance_story()
	elif game.state == "portal":
		elapsed += delta
		if elapsed >= 0.45 and not whoosh_played:
			whoosh_played = true
			game._play("portal_whoosh")
		if elapsed >= 1.05 and not portal_loaded:
			# Entire frame is covered by the colored tunnel during the scene swap.
			portal_loaded = true
			var next_path: String = "res://rooms/room_%02d.tscn" % (game.level_index + 2)
			game.prepared_room = ResourceLoader.load_threaded_get(next_path)
			game.load_level(game.level_index + 1)
			game.state = "portal"
			game.player.set_process(false)
		if elapsed >= 1.3 and not arrival_played:
			arrival_played = true
			game._play("portal_arrive")
		if elapsed >= PORTAL_SECONDS:
			game.state = "playing"
			game.player.set_process(true)
			game.intro_left = game.INTRO_TIME
			game.consume_cinematic_input()
			last_portal_seconds = (Time.get_ticks_usec() - portal_started_usec) / 1000000.0
			print("PORTAL: room %d ready in %.3f s" % [game.level_index + 1, last_portal_seconds])
	queue_redraw()

func traveler_visibility() -> float:
	if not portal_loaded:
		return 1.0 - smoothstep(0.3, 0.9, elapsed)
	return smoothstep(1.35, 2.0, elapsed)

func _draw() -> void:
	if game.state == "story":
		_draw_story()
	elif game.state == "portal":
		_draw_portal()

func _draw_story() -> void:
	var progress: float = clampf(elapsed / BEAT_SECONDS[beat], 0.0, 1.0)
	var zoom: float
	var focal: Vector2
	if beat == 0:
		zoom = lerpf(1.05, 1.16, smoothstep(0.0, 1.0, progress))
		focal = Vector2(0.35, 0.45)
	elif beat == 1:
		zoom = 1.16
		focal = Vector2(lerpf(0.35, 0.72, smoothstep(0.0, 1.0, progress)), 0.45)
	else:
		var scene_progress: float = (elapsed + (BEAT_SECONDS[2] if beat == 3 else 0.0)) / 7.0
		zoom = lerpf(1.0, 1.15, scene_progress)
		focal = Vector2(0.44, 0.43)
	var texture: Texture2D = STORY_IMAGES[0 if beat < 2 else 1]
	var size: Vector2 = texture.get_size()
	# Source crop keeps aspect ratio; the window itself intentionally letterboxes.
	var source_size := Vector2(minf(size.x, size.y * 16.0 / 9.0), minf(size.y, size.x * 9.0 / 16.0)) / zoom
	var source_origin: Vector2 = (size - source_size) * focal
	draw_texture_rect_region(texture, Rect2(0, 0, 320, 180), Rect2(source_origin, source_size))
	# A brief dark cross-scene fade, never a bright full-screen flash.
	var fade: float = 1.0 - smoothstep(0.0, 0.35, elapsed)
	if beat in [0, 2]:
		draw_rect(Rect2(0, 0, 320, 180), Color(0.025, 0.07, 0.08, fade))
	draw_rect(Rect2(0, 0, 320, 11), Color(0.02, 0.05, 0.07, 0.65))
	DrawText.text(self, Vector2(10, 8), "STILL//MOVING  /  LA PRIMERA FRACTURA", 6, CYAN)
	var dialogue: String = "¡No puede ser... La máquina se arruinó!" if beat < 2 else "Si logro dominar el tiempo, podré regresar a mi era..."
	var paragraph := DrawText.paragraph(dialogue, 292, 9)
	paragraph.alignment = HORIZONTAL_ALIGNMENT_CENTER
	draw_rect(Rect2(5, 137, 310, 39), Color(0.015, 0.035, 0.05, 0.82))
	draw_line(Vector2(14, 137), Vector2(52, 137), CYAN, 0.5)
	paragraph.draw(get_canvas_item(), Vector2(14, 140), Color("f8f8f2"))
	if beat == 3:
		DrawText.center(self, 166, "A TRABAJAR", 12, GOLD)
	DrawText.text(self, Vector2(13, 174), "Enter / Espacio: continuar", 6, Color("c4d7df"))
	DrawText.text(self, Vector2(252, 174), "Esc: omitir", 6, Color("c4d7df"))

func _draw_portal() -> void:
	var t: float = elapsed
	var cover: float = smoothstep(0.65, 0.98, t) * (1.0 - smoothstep(1.25, 1.7, t))
	var opening: float = smoothstep(0.0, 0.38, t)
	var closing: float = 1.0 - smoothstep(1.95, PORTAL_SECONDS, t)
	# Follow the actual rendered position, including residual camera smoothing.
	var center: Vector2 = game.player.get_global_transform_with_canvas() * Vector2(0, -8)
	center = center.lerp(Vector2(160, 90), cover)
	var radius: float = (20.0 + cover * 190.0) * opening * closing
	# Opaque colored tunnel masks construction; no loading gap or screen shader.
	if cover > 0.0:
		draw_rect(Rect2(0, 0, 320, 180), Color(0.045, 0.06, 0.17, cover))
	if cover > 0.0:
		# Interior streaming stars keep the tunnel luminous while its rim is offscreen.
		for i in range(42):
			var a: float = i * 2.39996 + t * 0.7
			var distance: float = 8.0 + fposmod(i * 17.3 + t * 125.0, 190.0)
			var radial := Vector2(cos(a), sin(a) * 0.7)
			var color: Color = CYAN if i % 3 else PINK
			var start: Vector2 = center + radial * distance
			var end: Vector2 = center + radial.rotated(0.05) * (distance + 6.0 + distance * 0.16)
			draw_line(start, end, Color(color, cover * 0.65), 0.6, true)
			draw_circle(start, 0.5, Color(Color.WHITE, cover * 0.7))
	for i in range(36):
		var a: float = float(i) * TAU / 36.0 + t * 4.8
		var radial := Vector2(cos(a), sin(a) * 1.18)
		var color: Color = CYAN if i % 3 == 0 else (PINK if i % 3 == 1 else GOLD)
		var length: float = 5 + fposmod(i * 7.3 + t * 42.0, 21)
		var p: Vector2 = center + radial * (radius + length)
		draw_line(p, center + radial.rotated(-0.16) * (radius + length + 8), Color(color, opening * closing * 0.5), 0.6)
		draw_circle(p, 0.65 if i % 2 == 0 else 0.4, Color(color, opening * closing))
	for ring in range(5):
		var color: Color = CYAN if ring % 2 == 0 else PINK
		var points := PackedVector2Array()
		for i in range(65):
			var a: float = float(i) * TAU / 64.0
			var ripple: float = sin(a * 5.0 + t * 14 + ring) * 1.4
			points.append(center + Vector2(cos(a), sin(a) * 1.18) * (radius + ring * 1.15 + ripple))
		draw_polyline(points, Color(color, opening * closing * (0.13 if ring > 1 else 0.9)), 3.5 if ring > 1 else 0.75, true)
	for i in range(7):
		var a: float = t * 5 + i * TAU / 7.0
		draw_arc(center, maxf(1.0, radius * (0.25 + i * 0.09)), a, a + 1.7, 24, Color(CYAN if i % 2 else PINK, opening * closing * (0.3 + cover * 0.45)), 0.5, true)
