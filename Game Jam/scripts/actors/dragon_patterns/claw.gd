extends "res://scripts/actors/dragon_patterns/pattern.gd"
## Attack 2: a slam on the gold mark, followed by a wave along the ground.
##
## Two separate hazards on one timeline. The slam is lethal for the first 0.42s
## inside the marked rectangle; from 0.18s a wave travels left along the floor
## and has to be jumped. Both ignore the dash phase window.

const GOLD := Color("ffd15c")
const RED := Color("ff5a67")
const FIRE := Color("ff862e")

const SLAM_ENDS: float = 0.42
const WAVE_BEGINS: float = 0.18


func warning_cue() -> String:
	return "CLAW: LEAVE THE GOLD MARK"


func attack_cue() -> String:
	return "JUMP THE GROUND WAVE"


func is_lethal(swept: Rect2, age: float) -> bool:
	if age < SLAM_ENDS and swept.intersects(host.claw_rect()):
		return true
	return age >= WAVE_BEGINS and swept.intersects(host.wave_rect())


func draw_warning(canvas: CanvasItem) -> void:
	canvas.draw_rect(host.claw_rect(), Color(GOLD, 0.25), false, 2)


func draw_attack(canvas: CanvasItem, age: float) -> void:
	if age < SLAM_ENDS:
		canvas.draw_rect(host.claw_rect(), Color(RED, 0.45))
	if age >= WAVE_BEGINS:
		var r: Rect2 = host.wave_rect()
		host.draw_outlined_polygon(canvas, [r.position + Vector2(0, 10), r.position + Vector2(6, 0), r.end], FIRE)


## The front claw lifts to the mark while winding up, then slams onto it.
func foot_override(state: StringName, age: float) -> Vector2:
	if state == &"warning":
		return Vector2(host.target_x, 87)
	if state == &"attack":
		return Vector2(host.target_x, 139 if age < SLAM_ENDS else 118)
	return Vector2.INF
