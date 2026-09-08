extends RefCounted
## One of Pyrax's three attacks, as an object instead of an index.
##
## The attack a cycle picks is a second dimension next to the state: both
## `warning` and `attack` branch on it, and so did the HUD. Giving each pattern
## its telegraph, its lethal geometry and its own coaching lines keeps those
## three branches in one file each, and lets the HUD ask the pattern instead of
## indexing an array by a number it should not have to know about.

var host: Object = null


## Index this pattern is registered under, kept so `dragon.attack` still reads
## as the same integer the rest of the project (and the tests) expect.
var index: int = 0


## Line shown while the attack is being telegraphed.
func warning_cue() -> String:
	return ""


## Line shown while the attack is live.
func attack_cue() -> String:
	return ""


## Fired when the `attack` state begins, for patterns that spawn something.
func begin() -> void:
	pass


## Fired partway through the attack. Only phase two uses this, for the
## follow-up volley.
func midpoint(_phase: int) -> void:
	pass


## Head offset while this pattern is winding up or live. Return an empty
## Vector2 sentinel by overriding `moves_head` instead of guessing here.
func head_offset(_state: StringName, _base: Vector2) -> Vector2:
	return Vector2.ZERO


## True when this pattern replaces the head position outright rather than
## nudging it.
func head_override(_state: StringName) -> Vector2:
	return Vector2.INF


## Does the swept player rectangle touch anything lethal this frame?
func is_lethal(_swept: Rect2, _age: float) -> bool:
	return false


## Telegraph drawn during the `warning` state.
func draw_warning(_canvas: CanvasItem) -> void:
	pass


## The attack itself, drawn during the `attack` state.
func draw_attack(_canvas: CanvasItem, _age: float) -> void:
	pass


## Front-claw placement, which only the claw pattern moves off its rest pose.
## Returns Vector2.INF to mean "leave the foot where the body puts it".
func foot_override(_state: StringName, _age: float) -> Vector2:
	return Vector2.INF
