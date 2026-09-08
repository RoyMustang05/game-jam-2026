extends "res://scripts/systems/state.gd"
## The exit has been reached. Input is ignored so a late press cannot carry Milo
## off the goal while the level-clear panel is up.


func pose() -> String:
	return "goal"


func decide(_delta: float, _frame: Dictionary) -> bool:
	return true
