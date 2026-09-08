extends "res://scripts/systems/state.gd"
## The last flame goes out. Lethal geometry is off, and the arena cools.
##
## It still runs on world time, so the player has to keep moving to watch their
## own victory finish - the one joke the game plays on you at the end.


func duration() -> float:
	return 2.4


## Terminal: nothing follows the last flame.
func next_id() -> StringName:
	return &""


## No successor exists to report the win, so defeat reports it itself.
func timeout() -> void:
	host.completed = true
