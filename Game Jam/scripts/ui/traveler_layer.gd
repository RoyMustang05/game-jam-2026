extends Node2D
## The same player poses at window resolution; the world/colliders stay 320x180.
var game: Node2D

func _process(_delta: float) -> void:
	queue_redraw()

func _draw() -> void:
	if not is_instance_valid(game.player) or game.state in ["menu", "story"]:
		return
	var actor: Node2D = game.player
	var transform: Transform2D = actor.get_global_transform_with_canvas()
	if game.state == "portal":
		var progress: float = game.cinematic.traveler_visibility()
		transform = transform.translated_local(Vector2(0, -12 * (1.0 - progress)))
		transform = transform.scaled_local(Vector2(maxf(progress, 0.01), maxf(progress, 0.01)))
		modulate.a = progress
	else:
		modulate.a = 1.0
	draw_set_transform_matrix(transform)
	actor.draw_visual(self)
	draw_set_transform_matrix(Transform2D.IDENTITY)
