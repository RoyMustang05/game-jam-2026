extends SceneTree
const Game = preload("res://scripts/game.gd")
const Dragon = preload("res://scripts/dragon.gd")
var game: Node2D
var count := 0
var failures := 0
func _initialize() -> void:
	_run.call_deferred()
func check(ok: bool,label: String) -> void:
	count += 1
	if not ok: failures += 1
	print(("PASS " if ok else "FAIL ")+label)
func frames(n: int,command: Dictionary={"axis":0.0}) -> void:
	game.test_command = command
	for i in range(n):
		await physics_frame
		await process_frame
func arena() -> void:
	game.load_level(3)
	game.player.position = Vector2(598,390)
	game._start_boss()
	game.set_physics_process(false)
func _run() -> void:
	game = Game.new()
	game.test_mode = true
	root.add_child(game)
	await process_frame
	arena()
	var b: Node2D = game.dragon
	check(b.health==8 and b.phase==1 and game.remaining==130,"fresh arena has eight hits and a separate 130-second budget")
	for attack in range(3):
		b.state="warning"
		b.attack=attack
		b.age=0.5
		b.world_step(0,game.player)
		var snap: Array = [b.clock,b.age,b.head_position(),b.fire_polygon(),b.throat.energy]
		for n in range(120): b.world_step(0,game.player)
		check(snap==[b.clock,b.age,b.head_position(),b.fire_polygon(),b.throat.energy],"warning, rig, fire geometry and static light freeze for attack %d"%attack)
		b.world_step(0.1,game.player)
		check(b.age>0.5,"warning advances only with supplied world delta")
	b.state="attack"
	b.attack=0
	b.age=0.9
	game.player.position=b.position+Vector2(150,144)
	b.previous_player=game.player.position-b.position
	game.player._phase_left=1
	check(b.world_step(0,game.player).dead,"frozen sustained fire remains lethal during dash phase")
	game.player.position=b.position+Vector2(90,104)
	b.previous_player=game.player.position-b.position
	check(not b.world_step(0,game.player).dead,"high ledge is a safe fire-breath response")
	game.player.position=b.position+Vector2(40,144)
	b.previous_player=game.player.position-b.position
	check(not b.world_step(0,game.player).dead,"far-left observation pocket is outside fire geometry")
	b.attack=2
	b.age=0.1
	b.target_x=145
	game.player.position=b.position+Vector2(145,144)
	b.previous_player=game.player.position-b.position
	check(b.world_step(0,game.player).dead,"claw impact is solid even while frozen and phasing")
	b.age=0.7
	var wave: Rect2 = b.wave_rect()
	game.player.position=b.position+Vector2(wave.get_center().x,122)
	b.previous_player=game.player.position-b.position
	check(not b.world_step(0,game.player).dead,"jumping above the ground wave avoids it")
	game.player.position.y=b.position.y+144
	b.previous_player=game.player.position-b.position
	check(b.world_step(0,game.player).dead,"ground-wave contact remains dangerous")
	b.attack=1
	b.state="warning"
	b.phase=2
	b._next(game.player)
	check(b.projectiles.size()==3,"volley starts with three spaced projectiles")
	game.player.position=b.position+Vector2(40,144)
	b.previous_player=game.player.position-b.position
	b.world_step(0.81,game.player)
	check(b.projectiles.size()==6,"phase two adds one spaced follow-up volley")
	var bullets: Array = b.projectiles.duplicate(true)
	b.world_step(0,game.player)
	check(b.projectiles==bullets,"ember positions and trails remain frozen")
	b.state="recover"
	b.recharge_available=true
	game.player.position=b.position+Vector2(112,144)
	b.previous_player=game.player.position-b.position
	game.player.dash_charges=0
	check(b.world_step(0.01,game.player).refill and game.player.dash_charges==2,"visible recovery cell restores two dash charges")
	game.player.dash_charges=0
	check(not b.world_step(0.01,game.player).refill and game.player.dash_charges==0,"same recovery cell cannot be farmed repeatedly")
	b.projectiles.clear()
	b.state="recover"
	b.age=0.8
	b.phase=1
	b.health=8
	b.hit_this_opening=false
	game.player._phase_left=0
	game.player.position=b.position+Vector2(191,144)
	b.previous_player=game.player.position-b.position
	var strike := {"id":7,"rect":Rect2(game.player.position+Vector2(0,-30),Vector2(27,28))}
	check(not b.world_step(0,game.player,strike).hit,"stationary zero-time overlap cannot damage the weak point")
	check(b.world_step(0.01,game.player,strike).hit and b.health==7,"one committed temporal strike removes one health segment")
	for n in range(8): b.world_step(0.01,game.player,strike)
	check(b.health==7,"same strike and repeated overlap cannot cause extra hits")
	b.health=5
	b.hit_this_opening=false
	b.hurt=0
	strike.id=8
	check(b.world_step(0.01,game.player,strike).hit and b.phase==2 and b.state=="transition","fourth hit visibly transitions to phase two")
	b.state="recover"
	b.age=0.8
	b.health=1
	b.hurt=0
	b.hit_this_opening=false
	strike.id=9
	b.world_step(0.01,game.player,strike)
	check(b.state=="defeat" and b.projectiles.is_empty(),"final hit begins defeat and clears attack effects")
	b.world_step(2.5,game.player)
	check(b.completed,"defeat sequence finishes")
	for attack in range(3):
		arena()
		b=game.dragon
		b.state="attack"
		b.attack=attack
		b.health=2
		b.phase=2
		b._volley(false)
		var deaths: int=game.total_deaths
		game.die("RETRY TEST")
		check(game.total_deaths==deaths+1 and game.dragon.health==8 and game.dragon.phase==1 and game.dragon.projectiles.is_empty() and game.dragon.state=="prepare", "death during attack %d resets complete encounter and preserves death count"%attack)
		check(game.remaining==130 and game.player.dash_charges==2 and game.intro_left==0 and game.player.position.distance_to(game.checkpoint_position)<0.1,"retry restores timer, resources and arena checkpoint without intro")
	arena()
	game.set_physics_process(true)
	await frames(20)
	var start: float = game.level_world
	var pose: Vector2=game.dragon.head_position()
	await frames(30)
	check(game.level_world==start and game.dragon.head_position()==pose,"Milo idle breathing never advances boss time")
	await frames(1,{"axis":0.0,"attack":true})
	await frames(22)
	check(game.level_world>start+0.25 and game.level_world<start+0.34,"stationary J commits roughly 0.3 seconds of world time")
	start=game.level_world
	await frames(30)
	check(game.level_world==start,"time freezes again after the committed strike")
	print("BOSS TESTS: %d checks, %d failures"%[count,failures])
	quit(1 if failures else 0)
