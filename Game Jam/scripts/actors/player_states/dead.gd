extends "res://scripts/systems/state.gd"
## Hit, then scattered into pixels.
##
## Worth knowing: the campaign never shows this. game.die() reloads the room in
## the same frame, which frees the player before a single death frame is drawn.
## Only the unit tests exercise it. The animation is ready if the respawn is
## ever given a beat to breathe.


func pose() -> String:
	return "hit" if host._hit_left > 0.0 else "death"


func decide(_delta: float, _frame: Dictionary) -> bool:
	return true
