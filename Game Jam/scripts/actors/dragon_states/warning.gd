extends "res://scripts/systems/state.gd"
## The telegraph. The attack is chosen and aimed, but nothing hurts yet.
##
## Aiming happens on entry, not continuously, so a player who reads the tell and
## moves is genuinely rewarded - the mark does not follow them.


func duration() -> float:
	return 0.95 if host.phase == 1 else 0.8


func next_id() -> StringName:
	return &"attack"


func enter(_previous: StringName, context: Variant = null) -> void:
	if context is Node2D:
		host.target_x = clampf(context.position.x - host.position.x, 55, 215)
	if not host.attack in host.attacks_seen:
		host.attacks_seen.append(host.attack)
