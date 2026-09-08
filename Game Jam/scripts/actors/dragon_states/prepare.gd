extends "res://scripts/systems/state.gd"
## Pyrax reads the arena and waits. Nothing is dangerous except its body.
##
## This is the beat that makes the whole encounter fair: the player is told to
## keep moving, and moving is the only thing that advances the boss at all.


func duration() -> float:
	return 1.8 if host.phase == 1 else 1.5


func next_id() -> StringName:
	return &"warning"
