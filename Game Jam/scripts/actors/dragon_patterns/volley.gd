extends "res://scripts/actors/dragon_patterns/pattern.gd"
## Attack 1: three horizontal ember lanes with 25px gaps for a 14px Milo.
##
## The floor is always safe, so this is the attack you can stop and read. In
## phase two a second, offset volley follows partway through, which is what
## turns a readable pattern into one you have to commit to early.

const GOLD := Color("ffd15c")

## Phase two fires its follow-up once the attack is this far along.
const FOLLOWUP_AT: float = 0.8


func warning_cue() -> String:
	return "VOLLEY: SPACED LANES / FLOOR IS SAFE"


func attack_cue() -> String:
	return "EMBER LANES / STOP TO PLAN"


func head_offset(state: StringName, _base: Vector2) -> Vector2:
	return Vector2(-6, -16) if state == &"attack" else Vector2.ZERO


func begin() -> void:
	host.spawn_volley(false)


func midpoint(phase: int) -> void:
	if phase == 2:
		host.spawn_volley(true)


func draw_warning(canvas: CanvasItem) -> void:
	for n in range(3):
		canvas.draw_dashed_line(Vector2(40, 58 + n * 28), Vector2(217, 58 + n * 28), Color(GOLD, 0.45), 1, 4)
