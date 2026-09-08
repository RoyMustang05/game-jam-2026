extends SceneTree
## Full routes use ordinary input commands and the real collision world.
const Game = preload("res://scripts/game.gd")
var game: Node2D
var lane: int = 0
var last_jump: int = -100
var tick: int = 0
var failed: bool = false
var jump_origin: float = 0.0
var trace: Array = []
var boss_pace_dir := 1

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	game = Game.new()
	game.test_mode = true
	root.add_child(game)
	await process_frame
	game.start_run()
	var first_room: int = int(OS.get_cmdline_user_args()[0]) if OS.get_cmdline_user_args().size()>0 else 0
	for room in range(first_room,4):
		lane = 0
		last_jump = -100
		failed = false
		game.load_level(room)
		var deaths: int = game.total_deaths
		for frame in range(9000):
			tick = frame
			game.test_command = boss_command() if is_instance_valid(game.dragon) and game.dragon.active else command()
			if frame%6==0:
				trace.append([frame,lane,game.player.position,game.player.velocity,game.test_command])
				if trace.size()>20: trace.pop_front()
			await physics_frame
			await process_frame
			if game.total_deaths != deaths:
				print("FAIL room %d lane %d at %s time %.2f: %s" % [room+1,lane,str(game.death_position),game.total_world,game.death_reason])
				failed = true
				for entry in trace: print(entry)
				break
			if game.state != "playing":
				break
		if failed or game.state == "playing":
			print("ROUTE STOP position=%s lane=%d" % [str(game.player.position),lane])
			quit(1)
			return
		print("PASS ROUTE %d %s: %.2fs active, %d dashes total, %.2fs left" % [room+1,game.data.title,game.level_world,game.total_dashes,game.remaining])
	print("ALL FOUR ROUTES AND PYRAX PASSED through real physics and ordinary inputs")
	quit(0)

func command() -> Dictionary:
	var p: Vector2 = game.player.position
	var actor: CharacterBody2D = game.player
	var spacing: float = 192.0 if game.level_index<2 else 136.0
	var fy: float = 118.0 + lane * spacing
	if p.y > fy + spacing*0.55 and lane < (4 if game.level_index == 2 else (2 if game.level_index == 3 else 3)):
		lane += 1
		fy += spacing
	var dir: float = 1.0 if lane % 2 == 0 else -1.0
	var cmd: Dictionary = {"axis":dir,"jump":false,"jump_held":true,"vertical":0.0,"dash":false,"cling":true}
	var grounded: bool = actor.is_on_floor()
	var lane_width: float = 544.0 if game.level_index == 3 else float(game.data.width)
	if not grounded and p.y>fy+2 and (p.x>lane_width-40 or p.x<26):
		cmd.axis = 0.0
		cmd.cling = false
	# End-drop fragile floor is visible and must be struck from above.
	for barrier: Dictionary in game.mechanisms.barriers:
		if barrier.broken:
			continue
		var r: Rect2 = barrier.rect
		if barrier.kind == "fragile":
			if not grounded and p.x > r.position.x-2 and p.x < r.end.x+2 and p.y < r.position.y and p.y > r.position.y-35 and not actor.striking:
				cmd.axis = 0.0
				cmd.vertical = 1.0
				cmd.dash = true
		else:
			var ahead: float = r.position.x-p.x if dir>0 else p.x-r.end.x
			if ahead > 3 and ahead < 22 and p.y > r.position.y and p.y-14 < r.end.y:
				cmd.dash = true
	for gate: Dictionary in game.mechanisms.gates:
		var r: Rect2 = gate.rect
		var ahead: float = r.position.x-p.x if dir>0 else p.x-r.end.x
		if ahead > 8 and ahead < 31 and absf(r.end.y-fy)<2 and (gate.closed or float(gate.until_change)<0.4):
			# A vertical hop advances the cycle in the safe alcove; standing holds it.
			cmd.axis = 0.0
			cmd.jump = grounded and tick-last_jump>8
	var support := Rect2()
	var on_relay := false
	for rect: Rect2 in game.data.solids:
		if absf(p.y-rect.position.y)<1.2 and p.x>rect.position.x-4 and p.x<rect.end.x+4:
			support = rect
	for entry: Dictionary in game.platforms:
		var rect := Rect2(Vector2(entry.pos)-Vector2(entry.size)/2, Vector2(entry.size))
		if absf(rect.position.y-fy)>40: continue
		if absf(p.y-rect.position.y)<1.2 and absf(p.x-rect.get_center().x)<rect.size.x/2+4:
			support = rect
			on_relay = true
		elif not grounded and actor.velocity.y>0 and p.y<rect.position.y and absf(p.x-rect.get_center().x)<14:
			cmd.axis = 0.0
	for rect: Rect2 in game.data.solids:
		var ahead: float = rect.position.x-p.x if dir>0 else p.x-rect.end.x
		if rect.position.x>=lane_width-40: continue
		if rect.end.y>=fy-1 and rect.position.y<fy-4 and rect.position.y>fy-170 and ahead>3 and ahead<36:
			if grounded:
				cmd.jump = true
			elif fy-rect.position.y>38 and actor.extra_jumps>0 and ahead<23 and p.y>rect.position.y-2 and tick-last_jump>7:
				cmd.jump = true
	if grounded and on_relay:
		cmd.jump = true
	if grounded and support.size.x>0 and absf(p.y-fy)<2:
		var edge: float = support.end.x if dir>0 else support.position.x
		var ahead: float = (edge-p.x)*dir
		# Only jump interior gaps, never the intentional end shafts.
		if ahead<5 and edge>70 and edge<lane_width-65:
			var next_floor: bool = false
			for rect: Rect2 in game.data.solids:
				if rect.has_point(Vector2(edge+dir*7,p.y+2)):
					next_floor = true
			if not next_floor:
				cmd.jump = true
	if not grounded and actor.extra_jumps>0 and actor.velocity.y>-20 and p.y<fy-15:
		# Tile snapping can widen a 70px opening to 72px; use the available
		# extra jump on medium gaps too instead of relying on a marginal landing.
		for danger: Rect2 in game.data.killzones:
			if absf(danger.position.y-(fy+8))<2 and p.x>danger.position.x-8 and p.x<danger.end.x+4:
				var relay: bool = false
				for entry: Dictionary in game.platforms:
					if entry.pos.x>danger.position.x and entry.pos.x<danger.end.x and absf(entry.pos.y-fy)<35:
						relay = true
				if not relay or p.y>fy-45:
					cmd.jump = true
	for spike: Dictionary in game.hazards.spikes:
		var ahead: float = (Vector2(spike.pos).x-p.x)*dir
		if grounded and ahead>0 and ahead<34 and absf(Vector2(spike.pos).y-p.y)<18:
			cmd.jump = true
		elif not grounded and actor.extra_jumps>0 and actor.velocity.y>20 and ahead>-8 and ahead<34 and p.y>Vector2(spike.pos).y-28 and p.y<Vector2(spike.pos).y:
			cmd.jump = true
	for pad: Dictionary in game.mechanisms.pads:
		var r: Rect2 = pad.rect
		var ahead: float = (r.get_center().x-p.x)*dir
		if grounded and ahead>0 and ahead<34 and absf(r.end.y-p.y)<3:
			cmd.jump = true
		if not grounded and not actor.striking and actor.dash_charges>0 and p.x>r.position.x+3 and p.x<r.end.x-3 and p.y<r.position.y-3 and p.y>r.position.y-55:
			cmd.axis = 0.0
			cmd.vertical = 1.0
			cmd.dash = true
	if actor.is_on_wall() and not grounded and tick-last_jump>9 and p.x>65 and p.x<lane_width-65:
		cmd.jump = true
	for bullet: Dictionary in game.hazards.projectiles:
		var offset: Vector2 = Vector2(bullet.pos)-(p+Vector2(0,-7))
		if offset.length()<19 and absf(offset.y)<13:
			if grounded: cmd.jump = true
			elif actor.dash_charges>0: cmd.dash = true
	# Crushers are entered only when there is time to clear their complete width.
	for e: Dictionary in game.crushers.entries:
		var r: Rect2 = e.rect
		var ahead: float = (r.position.x-p.x) if dir>0 else (p.x-r.end.x)
		if ahead>4 and ahead<34 and absf(r.end.y-fy)<3:
			var t: float = game.crushers.phase_time(e)
			if not grounded: cmd.axis = 0.0
			if t>0.45 and t<2.7:
				cmd.axis = 0.0
				cmd.jump = grounded and tick-last_jump>8
	if bool(cmd.jump):
		if tick-last_jump<7:
			cmd.jump = false
		else:
			last_jump = tick
	return cmd



func boss_command() -> Dictionary:
	var b: Node2D = game.dragon
	var p: Vector2 = game.player.position-b.position
	var desired := 40.0
	var cmd := {"axis":0.0,"jump":false,"jump_held":true,"attack":false,"cling":false}
	if b.state == "recover" and not b.hit_this_opening:
		desired = 192
		if p.x>185 and p.x<204 and game.player.facing>0 and b.age>0.45: cmd.attack = true
	elif b.state in ["warning","attack"] and b.attack == 2:
		desired = b.target_x+45
	else:
		# Safe footwork deliberately advances time; no fake clock or teleports.
		if p.x>=54: boss_pace_dir = -1
		elif p.x<=38: boss_pace_dir = 1
		desired = 56 if boss_pace_dir>0 else 36
	if b.state in ["warning","attack"] and b.attack == 2 and absf(desired-p.x)<4:
		cmd.jump = game.player.is_on_floor()
	cmd.axis = signf(desired-p.x) if absf(desired-p.x)>2 else 0.0
	if b.state == "recover" and not b.hit_this_opening and p.x>185 and p.x<204: cmd.axis = 0.0
	return cmd

