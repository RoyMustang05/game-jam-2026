extends "res://scripts/actors/dragon_patterns/pattern.gd"
## Attack 0: a sustained cone of fire along the arena floor.
##
## The counter is height, not distance: the cone is solid and phasing through it
## does not work, but it never reaches the high ledge or the far-left pocket.

const FIRE := Color("ff862e")
const GOLD := Color("ffd15c")


func warning_cue() -> String:
	return "BREATH: HIGH LEDGE OR FAR LEFT"


func attack_cue() -> String:
	return "FIRE IS SOLID / USE HEIGHT"


func head_override(state: StringName) -> Vector2:
	# The head drops to the floor line to aim the cone.
	return Vector2(222, 118) if state == &"attack" else Vector2.INF


func is_lethal(swept: Rect2, _age: float) -> bool:
	var poly := PackedVector2Array([swept.position, Vector2(swept.end.x, swept.position.y), swept.end, Vector2(swept.position.x, swept.end.y)])
	return not Geometry2D.intersect_polygons(host.fire_polygon(), poly).is_empty()


func draw_warning(canvas: CanvasItem) -> void:
	canvas.draw_dashed_line(Vector2(76, 140), Vector2(220, 140), GOLD, 1, 4)


func draw_attack(canvas: CanvasItem, age: float) -> void:
	canvas.draw_colored_polygon(host.fire_polygon(), FIRE)
	canvas.draw_line(host.head_position() + Vector2(-8, 5), Vector2(76, 130 + sin(age * 2.5) * 6), GOLD, 3)
	for n in range(10):
		canvas.draw_rect(Rect2(80 + n * 14, 145, 7, 1), Color(FIRE, 0.5))
