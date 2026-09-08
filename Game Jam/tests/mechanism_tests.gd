extends SceneTree
## Isolated deterministic world-delta checks; core/route tests cover real motion.

const Mechanisms = preload("res://scripts/world/mechanisms.gd")
const Hazards = preload("res://scripts/world/hazards.gd")

class ProbePlayer extends CharacterBody2D:
	var striking := false
	var dash_left := 0.0
	var dash_charges := 1
	var refill_count := 0
	var bounce_count := 0
	func can_phase() -> bool:
		return dash_left > 0.0 and not striking
	func bounce_from_pad(strength: float = 270.0) -> void:
		striking = false
		dash_left = 0.0
		velocity.y = -strength
		bounce_count += 1
	func refill_at_anchor() -> void:
		dash_charges = 2
		refill_count += 1

var world: Node2D
var player: ProbePlayer
var mechanisms: Node2D
var hazards: Node2D
var checks := 0
var failures := 0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	world = Node2D.new()
	root.add_child(world)
	player = ProbePlayer.new()
	world.add_child(player)
	_test_gates()
	_test_barriers()
	_test_pads()
	_test_anchors()
	_test_fields_echo()
	_test_watchers()
	_test_marked_spikes()
	_test_frozen_contact_and_reflection()
	_test_hazard_sensors()
	_test_killzones()
	print("MECHANISM TESTS: %d assertions, %d failures" % [checks, failures])
	world.free()
	quit(1 if failures else 0)


func _mechanisms(data: Dictionary) -> void:
	if is_instance_valid(mechanisms):
		mechanisms.free()
	mechanisms = Mechanisms.new()
	world.add_child(mechanisms)
	mechanisms.setup(data)
	player.position = Vector2(250, 120)
	player.velocity = Vector2.ZERO
	player.striking = false
	player.dash_left = 0.0
	player.dash_charges = 1
	player.refill_count = 0
	player.bounce_count = 0
	mechanisms.pre_player(player)


func _hazards(data: Dictionary) -> void:
	if is_instance_valid(hazards):
		hazards.free()
	hazards = Hazards.new()
	world.add_child(hazards)
	hazards.setup(data, int(data.get("chapter", 0)))
	player.velocity = Vector2.ZERO
	player.striking = false
	player.dash_left = 0.0
	player.dash_charges = 1
	player.bounce_count = 0


func _check(condition: bool, description: String) -> void:
	checks += 1
	if condition:
		print("PASS ", description)
	else:
		failures += 1
		push_error("FAIL " + description)


func _test_gates() -> void:
	_mechanisms({"gates": [{"rect": Rect2(40, 10, 10, 50), "period": 2.0, "open_ratio": 0.5, "phase": 0.3}]})
	_check(bool(mechanisms.gates[0].open), "gate initial normalized phase is deterministic")
	mechanisms.world_step(0.15, player)
	_check(bool(mechanisms.gates[0].warning) and bool(mechanisms.gates[0].open), "gate telegraphs closure before becoming dangerous")
	var timer: float = mechanisms.gates[0].timer
	mechanisms.world_step(0.0, player)
	_check(is_equal_approx(float(mechanisms.gates[0].timer), timer), "gate clock freezes exactly at zero world delta")
	mechanisms.world_step(0.26, player)
	_check(bool(mechanisms.gates[0].closed), "gate closes after its authored active interval")
	player.position = Vector2(45, 35)
	mechanisms.pre_player(player)
	player.dash_left = 0.1
	var event: Dictionary = mechanisms.world_step(0.0, player)
	_check(bool(event.dead), "a closed gate remains lethal while frozen, including during a phase dash")
	player.position = Vector2(250, 120)
	mechanisms.pre_player(player)
	mechanisms.world_step(1.0, player)
	_check(bool(mechanisms.gates[0].open), "gate opens again on the next deterministic cycle")


func _test_barriers() -> void:
	var fixture := {"barriers": [{"rect": Rect2(40, 10, 8, 40), "kind": "phase"}]}
	_mechanisms(fixture)
	player.position = Vector2(20, 35)
	mechanisms.pre_player(player)
	player.position = Vector2(60, 35)
	var event: Dictionary = mechanisms.world_step(0.05, player)
	_check(bool(event.dead) and not bool(mechanisms.barriers[0].broken), "walking through a phase barrier is lethal, including a swept crossing")
	_mechanisms(fixture)
	player.position = Vector2(20, 35)
	mechanisms.pre_player(player)
	player.position = Vector2(60, 35)
	player.dash_left = 0.1
	event = mechanisms.world_step(0.05, player)
	_check(bool(event.barrier_broken) and not bool(event.dead), "phase dash breaks a magenta barrier")
	_check(player.dash_charges == 1, "breaking a barrier does not charge a second dash")
	var particle_position: Vector2 = mechanisms.particles[0].pos
	mechanisms.world_step(0.0, player)
	_check(Vector2(mechanisms.particles[0].pos) == particle_position, "barrier debris freezes with the world")
	fixture.barriers[0].kind = "fragile"
	_mechanisms(fixture)
	player.position = Vector2(44, 30)
	mechanisms.pre_player(player)
	player.dash_left = 0.1
	event = mechanisms.world_step(0.05, player)
	_check(bool(event.dead) and not bool(mechanisms.barriers[0].broken), "horizontal phase dash cannot break a yellow fragile barrier")
	player.striking = true
	player.velocity.y = 300.0
	event = mechanisms.world_step(0.05, player)
	_check(bool(event.barrier_broken) and not bool(event.dead), "downward strike breaks a yellow fragile barrier")


func _test_pads() -> void:
	_mechanisms({"pads": [{"rect": Rect2(50, 80, 30, 6), "bounce": 285.0}]})
	player.position = Vector2(65, 60)
	mechanisms.pre_player(player)
	player.position = Vector2(65, 100)
	player.striking = true
	player.velocity.y = 320.0
	var event: Dictionary = mechanisms.world_step(0.1, player)
	_check(bool(event.bounced) and not bool(event.dead), "a fast downward strike catches a marked pad without tunneling")
	_check(is_equal_approx(player.velocity.y, -285.0) and player.position.y < 80.0, "pad places Milo above its cap and launches him upward")
	_check(not player.striking and player.dash_charges == 1, "pad bounce clears the strike without refilling dash charges")
	player.position = Vector2(65, 60)
	mechanisms.pre_player(player)
	player.position = Vector2(65, 85)
	player.velocity.y = 100.0
	event = mechanisms.world_step(0.1, player)
	_check(bool(event.dead) and not bool(event.bounced), "landing on a red pad without a downward strike is lethal")


func _test_anchors() -> void:
	_mechanisms({"anchors": [{"pos": Vector2(100, 70)}, {"pos": Vector2(200, 70)}]})
	player.dash_charges = 0
	player.position = Vector2(100, 70)
	mechanisms.pre_player(player)
	var event: Dictionary = mechanisms.world_step(0.02, player)
	_check(int(event.anchor) == 0 and Vector2(event.anchor_pos) == Vector2(100, 70), "anchor reports its stable index and feet position")
	_check(bool(event.refilled) and player.dash_charges == 2 and player.refill_count == 1, "anchor restores both dash charges once")
	player.dash_charges = 0
	event = mechanisms.world_step(0.1, player)
	_check(int(event.anchor) == -1 and player.dash_charges == 0 and player.refill_count == 1, "an already active anchor cannot be farmed for charges")
	mechanisms.setup({"anchors": [{"pos": Vector2(100, 70)}, {"pos": Vector2(200, 70)}]})
	mechanisms.set_checkpoint(1)
	_check(mechanisms.active_anchor == 1 and mechanisms.previous_player == Vector2(200, 70), "checkpoint restoration preserves index and resets the collision sweep origin")
	player.position = Vector2(100, 70)
	mechanisms.pre_player(player)
	event = mechanisms.world_step(0.02, player)
	_check(int(event.anchor) == -1 and mechanisms.active_anchor == 1, "touching an earlier anchor cannot move the checkpoint backward")


func _test_fields_echo() -> void:
	_mechanisms({"fields": [{"rect": Rect2(10, 10, 70, 100), "multiplier": 0.5}, {"rect": Rect2(100, 10, 70, 100), "multiplier": 1.5}]})
	player.position = Vector2(30, 60)
	_check(is_equal_approx(mechanisms.time_field_multiplier(player), 0.5), "slow field gives a deterministic 0.5 object-time multiplier")
	player.position = Vector2(140, 60)
	_check(is_equal_approx(mechanisms.time_field_multiplier(player), 1.5), "accelerated field gives a deterministic 1.5 object-time multiplier")
	player.position = Vector2(240, 60)
	_check(is_equal_approx(mechanisms.time_field_multiplier(player), 1.0), "leaving a field restores normal object time")
	_hazards({"chapter": 3, "echo": true, "spawn": Vector2(20, 70)})
	player.position = Vector2(140, 70)
	hazards.world_step(0.5, player, 1.0)
	_check(is_equal_approx(hazards.world_time, 0.5) and is_equal_approx(hazards.echo_time, 1.0), "Echo records unscaled active time while world objects use scaled time")
	_check(not hazards.echo_visible, "Echo remains hidden until its active-time delay")
	player.position = Vector2(220, 70)
	hazards.world_step(0.5, player, 1.0)
	_check(hazards.echo_visible, "Echo becomes visible after 1.7 seconds of unscaled active time")
	var echo_position: Vector2 = hazards.echo_position
	var history_size: int = hazards.echo_history.size()
	hazards.world_step(0.0, player, 0.0)
	_check(hazards.echo_position == echo_position and hazards.echo_history.size() == history_size and is_equal_approx(hazards.echo_time, 2.0), "Echo history and replay freeze exactly when Milo stops")
	hazards.reset_echo(Vector2(190, 70))
	_check(not hazards.echo_visible and hazards.echo_history.size() == 1 and hazards.echo_position == Vector2(190, 70) and hazards.echo_time == 0.0, "checkpoint Echo reset clears the recorded path and old replay clock")
	_hazards({"chapter": 3, "echo": false, "spawn": Vector2(20, 70)})
	hazards.world_step(5.0, player, 5.0)
	_check(not hazards.echo_visible and hazards.echo_history.is_empty(), "Future Collapse rooms can explicitly disable the Echo")


func _test_watchers() -> void:
	var fixture := {"watchers": [{"pos": Vector2(100, 50), "direction": Vector2.RIGHT, "interval": 0.2, "speed": 50.0}], "echo": false}
	_hazards(fixture)
	player.position = Vector2(145, 57)
	hazards.world_step(0.21, player)
	_check(hazards.projectiles.size() == 1, "visible Watcher fires on its exact world interval")
	if not hazards.projectiles.is_empty():
		var pos: Vector2 = hazards.projectiles[0].pos
		var timer: float = hazards.watchers[0].timer
		hazards.world_step(0.0, player)
		_check(hazards.projectiles[0].pos == pos and hazards.watchers[0].timer == timer, "Watcher clock and bullets freeze exactly")
	fixture["solids"] = [Rect2(120, 0, 5, 100)]
	_hazards(fixture)
	hazards.world_step(0.21, player)
	_check(hazards.projectiles.is_empty(), "solid cover blocks Watcher line of sight")
	fixture["solids"] = []
	fixture.watchers[0].pos = Vector2(2000, 50)
	player.position = Vector2(2045, 57)
	_hazards(fixture)
	hazards.world_step(0.21, player)
	_check(hazards.projectiles.is_empty(), "Watcher cannot fire from offscreen even with nearby line of sight")
	fixture.watchers[0].pos = Vector2(100, 50)
	player.position = Vector2(45, 57)
	_hazards(fixture)
	hazards.world_step(0.21, player)
	_check(hazards.projectiles.is_empty(), "Watcher respects its authored facing cone")


func _test_marked_spikes() -> void:
	var fixture := {"spikes": [{"a": Vector2(100, 90), "b": Vector2(100, 90), "size": Vector2(12, 12), "bounceable": true}], "echo": false}
	_hazards(fixture)
	hazards.previous_player = Vector2(100, 80)
	player.position = Vector2(100, 86)
	player.velocity.y = 300.0
	player.striking = true
	var hit: bool = hazards.world_step(0.02, player)
	_check(not hit and hazards.bounced and player.bounce_count == 1, "downward strike bounces from a specifically marked Spike cap")
	_check(player.position.y < 84.0 and player.velocity.y < 0.0, "marked Spike bounce separates the collision shapes")
	fixture.spikes[0].bounceable = false
	_hazards(fixture)
	hazards.previous_player = Vector2(100, 80)
	player.position = Vector2(100, 86)
	player.velocity.y = 300.0
	player.striking = true
	hit = hazards.world_step(0.02, player)
	_check(hit and not hazards.bounced, "unmarked Spike is lethal during a downward strike")


func _test_frozen_contact_and_reflection() -> void:
	_hazards({"spikes": [{"a": Vector2(100, 90), "b": Vector2(100, 90), "size": Vector2(12, 12)}], "echo": false})
	player.position = Vector2(100, 96)
	var hit: bool = hazards.world_step(0.0, player)
	_check(hit and hazards.world_time == 0.0, "frozen contact remains lethal without consuming world time")
	_hazards({"spikes": [{"a": Vector2(0, 90), "b": Vector2(100, 90), "size": Vector2(12, 12), "speed": 200.0}], "echo": false})
	player.position = Vector2(95, 96)
	hit = hazards.world_step(1.0, player)
	_check(hit and Vector2(hazards.spikes[0].pos).is_equal_approx(Vector2(0, 90)), "a reflected patrol sweep hits even when it returns to its starting position")


func _test_hazard_sensors() -> void:
	_hazards({"chapter": 3, "echo": true, "spawn": Vector2(20, 70), "spikes": [{"a": Vector2(40, 90), "b": Vector2(140, 90), "size": Vector2(12, 14), "speed": 20.0}]})
	player.position = Vector2(220, 70)
	var sensor: Area2D = hazards.spike_areas[0]
	var collider := sensor.get_child(0) as CollisionShape2D
	_check(sensor.collision_layer == 4 and sensor.collision_mask == 2 and not sensor.monitoring and collider.shape.size == Vector2(12, 14), "Spike has inspectable layer-4 Area2D geometry matching its authored size")
	_check(hazards.echo_shape.disabled and hazards.echo_shape.shape.size == Vector2(8, 14), "Echo sensor matches Milo's silhouette and starts disabled")
	hazards.world_step(0.5, player, 0.5)
	_check(sensor.position == Vector2(hazards.spikes[0].pos), "Spike sensor follows its explicitly advanced hazard position")
	var frozen_pos := sensor.position
	hazards.world_step(0.0, player, 0.0)
	_check(sensor.position == frozen_pos, "Spike sensor transform stays fixed at zero world delta")
	hazards.world_step(1.3, player, 1.3)
	_check(not hazards.echo_shape.disabled and hazards.echo_area.position == hazards.echo_position, "Echo sensor activates only when delayed replay becomes visible")
	hazards.reset_echo(Vector2(190, 70))
	_check(hazards.echo_shape.disabled and hazards.echo_area.position == Vector2(190, 70), "checkpoint reset disables and repositions the Echo sensor")


func _test_killzones() -> void:
	_mechanisms({"killzones": [Rect2(50, 80, 60, 7)]})
	var zone: Dictionary = mechanisms.killzones[0]
	var collider := zone.area.get_child(0) as CollisionShape2D
	_check(zone.area is Area2D and int(zone.area.collision_layer) == 4 and collider.shape.size == Vector2(60, 7), "authored killzone has matching static hazard-layer collision geometry")
	for ability in ["fall", "dash", "strike"]:
		player.position = Vector2(75, 60)
		mechanisms.pre_player(player)
		player.position = Vector2(75, 110)
		player.velocity.y = 300.0
		player.striking = ability == "strike"
		player.dash_left = 0.1 if ability == "dash" else 0.0
		var event: Dictionary = mechanisms.world_step(0.1, player)
		_check(bool(event.dead), "killzone catches a swept %s crossing without phase immunity" % ability)
	var position: Vector2 = zone.area.position
	var timer: float = mechanisms.world_time
	player.position = Vector2(75, 84)
	mechanisms.pre_player(player)
	var event: Dictionary = mechanisms.world_step(0.0, player)
	_check(bool(event.dead) and zone.area.position == position and mechanisms.world_time == timer, "killzone stays lethal while its geometry and world clock are frozen")
