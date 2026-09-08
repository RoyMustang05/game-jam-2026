extends "res://scripts/systems/state.gd"
## Half health. The furnace wakes up, every timing tightens, and the volley
## grows a follow-up. Nothing is lethal while this plays.


func duration() -> float:
	return 1.4


func next_id() -> StringName:
	return &"prepare"
