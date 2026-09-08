extends RefCounted
## Base class for one state of a StateMachine.
##
## A state is a behaviour lookup, not a container: it never stores the actor's
## data. Everything it needs lives on `host`, so two machines can share a state
## class and the host stays the single source of truth for its own fields.
##
## There is deliberately no back-reference to the machine. The machine holds
## every state, so a state holding the machine would be a RefCounted cycle that
## never frees - Godot reports it as "resources still in use at exit". States
## that need the machine receive it as an argument instead.
##
## Subclasses override only what they actually change. The defaults here are the
## "this state does nothing special" answers, which keeps each file short enough
## to read in one screen.

## The actor this state acts upon, assigned by the machine when it is added.
var host: Object = null

## Name this state was registered under. The machine assigns it; never set it
## by hand, or transitions will look up a state that does not exist.
var id: StringName = &""


## How long the state lasts before the machine advances to next_id().
## Return a large number for states that only leave on an external event.
func duration() -> float:
	return 99999.0


## Which state follows when this one runs out of time. An empty name keeps the
## machine where it is, which is how terminal states park themselves.
func next_id() -> StringName:
	return &""


## Called after this state becomes current through the machine. `context` is
## whatever the caller passed to advance() or change_to() - for Pyrax that is
## the player, because several entries aim at wherever Milo is standing.
func enter(_previous: StringName, _context: Variant = null) -> void:
	pass


## Called when the host reports this state's duration has elapsed, before any
## transition is attempted. Terminal states use this to finish their business,
## because they have no successor to do it in enter().
func timeout() -> void:
	pass


## Called before another state takes over. Not called when the host's state is
## rebound directly, only on a real machine transition.
func exit(_next: StringName) -> void:
	pass
