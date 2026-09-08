extends RefCounted
## Holds a set of States and tracks which one is current.
##
## Deliberately small. It owns *which* state is active and runs enter/exit
## around a change; it does not own the frame. Hosts keep driving their own
## update order and ask the machine questions along the way, because both users
## here interleave state work with physics or collision in a specific order that
## a generic "machine.update()" would flatten.
##
## Timing lives on the host too (Pyrax counts its own `age`), so the machine
## stays usable by an actor whose clock is not real time - which is the whole
## point in this game.

var host: Object = null
var current: RefCounted = null
var previous_id: StringName = &""
var _states: Dictionary = {}


func _init(owner: Object = null) -> void:
	host = owner


func add(state_id: StringName, state: RefCounted) -> void:
	state.id = state_id
	state.host = host
	_states[state_id] = state


func has(state_id: StringName) -> bool:
	return _states.has(state_id)


func get_state(state_id: StringName) -> RefCounted:
	return _states.get(state_id)


func is_in(state_id: StringName) -> bool:
	return current != null and current.id == state_id


## Rebind the current state without running enter() or exit().
##
## This is the honest counterpart to assigning a plain string: it changes which
## behaviour is consulted and nothing else. Tests and the capture tool drop the
## boss into a pose this way, and they must not trigger a volley or re-aim an
## attack by doing so.
func rebind(state_id: StringName) -> void:
	if _states.has(state_id):
		current = _states[state_id]


## A real transition: exit the old state, enter the new one.
func change_to(state_id: StringName, context: Variant = null) -> void:
	if not _states.has(state_id):
		return
	var leaving: StringName = current.id if current != null else &""
	if current != null:
		current.exit(state_id)
	previous_id = leaving
	current = _states[state_id]
	current.enter(leaving, context)


## Follow the current state's own next_id(). Returns the state now current, so
## a host can react to where it landed without a second lookup.
func advance(context: Variant = null) -> StringName:
	if current == null:
		return &""
	var target: StringName = current.next_id()
	if target == &"" or not _states.has(target):
		return current.id
	change_to(target, context)
	return current.id
