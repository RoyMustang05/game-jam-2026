extends Node2D
const DrawText = preload("res://scripts/ui/draw_text.gd")
const INK := Color("0d1013")
const GOLD := Color("ffd15c")

var game: Node2D

func _draw() -> void:
	var data: Dictionary = game.data
	if data.is_empty() or game.state in ["menu", "story"]:
		return
	draw_set_transform_matrix(game.world.get_global_transform_with_canvas())
	if not bool(data.get("boss", false)):
		DrawText.text(self, Vector2(data.goal) + Vector2(-10, -34), "CORE" if game.level_index == 3 else "EXIT", 8, GOLD)
	for sign_data: Dictionary in data.get("signs", []):
		var paragraph := DrawText.paragraph(String(sign_data.text), 260, 8)
		var pos: Vector2 = Vector2(sign_data.pos) - Vector2(0, 8)
		draw_rect(Rect2(pos - Vector2(3, 2), paragraph.get_size() + Vector2(6, 4)), Color(INK, 0.96))
		paragraph.draw(get_canvas_item(), pos, GOLD)
	game.mechanisms.draw_labels(self)
	draw_set_transform_matrix(Transform2D.IDENTITY)
