extends "res://scripts/systems/state.gd"
## The attack is live. Which one, and what it does, belongs to the pattern.


func duration() -> float:
	return 2.2


func next_id() -> StringName:
	return &"recover"


func enter(_previous: StringName, _context: Variant = null) -> void:
	host.pattern().begin()
