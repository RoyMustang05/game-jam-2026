extends RefCounted
## Keyboard layout registered at runtime, so project.godot keeps no InputMap state.
## Physical keycodes are used so the layout survives non-QWERTY keyboards.
##
## register() is idempotent: the F6 playtest flow builds a second game instance,
## and re-registering replaces each action's events instead of stacking duplicates.

const BINDINGS := {
	"move_left": [KEY_A, KEY_LEFT],
	"move_right": [KEY_D, KEY_RIGHT],
	"move_up": [KEY_W, KEY_UP],
	"move_down": [KEY_S, KEY_DOWN],
	"jump": [KEY_SPACE, KEY_W, KEY_UP],
	"dash": [KEY_SHIFT],
	"focus": [KEY_X],
	"attack": [KEY_J],
	"restart": [KEY_R],
	"pause_game": [KEY_ESCAPE],
	"confirm": [KEY_ENTER, KEY_SPACE],
}


static func register() -> void:
	for action: String in BINDINGS:
		if InputMap.has_action(action):
			InputMap.action_erase_events(action)
		else:
			InputMap.add_action(action)
		for key: int in BINDINGS[action]:
			var event := InputEventKey.new()
			event.physical_keycode = key
			InputMap.action_add_event(action, event)
