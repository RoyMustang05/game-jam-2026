extends Node2D
const DrawText = preload("res://scripts/ui/draw_text.gd")
const INK := Color("0d1013")
const WHITE := Color("f8f8f2")
const CYAN := Color("61e7ff")
const PINK := Color("ff5fcb")
const MUTED := Color("a6b3bf")
const GOLD := Color("ffd15c")

var game: Node2D
 # Al chile tocar rezar porque esto no se rompa :)
func _draw() -> void:
	if game.state != "menu":
		return
	draw_rect(Rect2(0, 0, 320, 180), INK)
	for x in range(0, 320, 16):
		draw_line(Vector2(x, 0), Vector2(x, 180), Color("131a20"))
	for y in range(0, 180, 16):
		draw_line(Vector2(0, y), Vector2(320, y), Color("131a20"))
	var origin := Vector2(253, 81)
	for n in range(12):
		var a: float = float(n) * TAU / 12.0 - PI / 2.0
		var direction := Vector2(cos(a), sin(a))
		draw_line((origin + direction * 49.0).round(), (origin + direction * 53.0).round(), CYAN if n % 3 == 0 else Color("354653"), 2)
	draw_arc(origin, 43, 0.3, 3.0, 18, Color("314650"), 1)
	draw_arc(origin + Vector2(3, -3), 43, 3.5, 5.9, 16, PINK, 1)
	draw_line(origin, origin + Vector2(0, -30), WHITE, 2)
	draw_line(origin, origin + Vector2(22, 12), CYAN, 2)
	draw_rect(Rect2(origin - Vector2(2, 2), Vector2(4, 4)), PINK)
	draw_rect(Rect2(15, 18, 4, 4), CYAN)
	DrawText.text(self, Vector2(24, 23), "CHRONOPHOBIA / FOUR FRACTURED EPOCHS", 8, MUTED)
	DrawText.text(self, Vector2(14, 65), "STILL", 31)
	DrawText.text(self, Vector2(91, 64), "//", 31, CYAN)
	DrawText.text(self, Vector2(14, 93), "MOVING", 31)
	draw_rect(Rect2(15, 102, 28, 2), PINK)
	DrawText.text(self, Vector2(15, 116), "THE TIME IS NOT YOURS.", 9, CYAN)
	DrawText.text(self, Vector2(15, 130), "Move to create time. Stop to survive.", 9)
	DrawText.text(self, Vector2(15, 151), "[ ENTER / SPACE ]  BEGIN", 9, GOLD)
	draw_line(Vector2(15, 160), Vector2(305, 160), Color("2a3540"))
	DrawText.text(self, Vector2(15, 172), "A/D MOVE   SPACE JUMP   SHIFT DASH   X FOCUS   J STRIKE", 8, MUTED)
	DrawText.text(self, Vector2(278, 151), "01 / 04", 7, CYAN)
