extends Node2D
const Levels = preload("res://scripts/world/levels.gd")
const GOLD := Color("ffd15c")
const CYAN := Color("61e7ff")
const PINK := Color("ff5fcb")
const WHITE := Color("f8f8f2")

var game: Node2D

func _draw() -> void:
	var data: Dictionary = game.data
	if data.is_empty():
		return
	for row_y in range(0, int(data.get("height", 180)), 160):
		draw_set_transform(Vector2(0, row_y))
		Levels.draw_environment(self, game.chapter_index, float(data.width), game.hazards.world_time)
	draw_set_transform(Vector2.ZERO)
	for entry: Dictionary in game.platforms:
		var a: Vector2 = entry.a
		var b: Vector2 = entry.b
		draw_dashed_line(a, b, Color("665a35"), 1, 3)
		draw_rect(Rect2(a - Vector2(1, 1), Vector2(3, 3)), GOLD)
		draw_rect(Rect2(b - Vector2(1, 1), Vector2(3, 3)), GOLD)
		var rect := Rect2(Vector2(entry.pos) - Vector2(entry.size) / 2, Vector2(entry.size))
		draw_rect(rect, Color("4a4e54"))
		draw_line(rect.position, Vector2(rect.end.x, rect.position.y), GOLD)
		for x in range(int(rect.position.x) + 2, int(rect.end.x) - 2, 6):
			draw_line(Vector2(x, rect.position.y + 2), Vector2(x + 2, rect.end.y), GOLD)
	if not bool(data.get("boss", false)):
		var goal: Vector2 = data.goal
		draw_rect(Rect2(goal + Vector2(-10, -29), Vector2(20, 29)), Color("142a30"))
		draw_rect(Rect2(goal + Vector2(-10, -29), Vector2(20, 29)), CYAN, false, 1)
		draw_rect(Rect2(goal + Vector2(-6, -25), Vector2(12, 25)), Color("214752"), false, 1)
		draw_line(goal + Vector2(-3, -18), goal + Vector2(3, -14), WHITE)
		draw_line(goal + Vector2(3, -14), goal + Vector2(-3, -10), WHITE)
		if game.level_index == 3:
			draw_arc(goal + Vector2(0, -14), 23, 0.2, 6.0, 24, PINK, 1)
			draw_arc(goal + Vector2(0, -14), 27, 2.0, 4.9, 14, CYAN, 1)
	var route: Array = data.get("waypoints", [])
	for i in range(route.size() - 1):
		var a: Vector2 = route[i]
		var b: Vector2 = route[i + 1]
		var direction: Vector2 = (b - a).normalized()
		var arrow: Vector2 = a + Vector2(0, -23)
		draw_line(arrow - direction * 3, arrow + direction * 3, Color("397482"))
		draw_line(arrow + direction * 3, arrow + direction.orthogonal() * 2, Color("397482"))
		draw_line(arrow + direction * 3, arrow - direction.orthogonal() * 2, Color("397482"))
	for n in range(22):
		var x: float = fposmod(float(n * 71) + game.level_world * (2.0 + n % 3), float(data.width))
		var y: float = 47.0 + fposmod(float(n * 23) - game.level_world * 2.0, 92.0)
		draw_rect(Rect2(roundf(x), roundf(y), 1, 1), Color(CYAN, 0.3))
