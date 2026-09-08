extends Node2D
## Pyrax uses ONLY explicit world delta. Drawing and collision share geometry.
const GOLD := Color("ffd15c")
const FIRE := Color("ff862e")
const RED := Color("ff5a67")
const CYAN := Color("61e7ff")
const DARK := Color("351f31")
const SCALE := Color("854339")
## Swept segment/rect helpers are shared with the hazard system.
const Geometry = preload("res://scripts/world/hazards.gd")
const Atmosphere = preload("res://scripts/world/atmosphere.gd")
var health := 8
var phase := 1
var active := false
var state := "dormant"
var clock := 0.0
var age := 0.0
var attack := 0
var cycle := 0
var hurt := 0.0
var target_x := 155.0
var projectiles: Array = []
var last_strike := -1
var hit_this_opening := false
var recharge_available := false
var arena := Rect2(560,246,320,144)
var previous_player := Vector2.ZERO
var throat: PointLight2D
var completed := false
var strike_hits := 0
var attacks_seen: Array[int] = []

func setup(rect: Rect2) -> void:
	arena = rect
	position = arena.position
	throat = Atmosphere.make_light(FIRE,80,0.6)
	add_child(throat)
	throat.position = head_position()

func start(player: Node2D) -> void:
	active = true
	state = "prepare"
	age = 0
	previous_player = player.position-position
	queue_redraw()

func duration() -> float:
	match state:
		"prepare": return 1.8 if phase == 1 else 1.5
		"warning": return 0.95 if phase == 1 else 0.8
		"attack": return 2.2
		"recover": return 4.3 if phase == 1 else 3.9
		"transition": return 1.4
		"defeat": return 2.4
	return 99999.0

func _next(player: Node2D) -> void:
	age = 0
	match state:
		"prepare":
			state = "warning"
			target_x = clampf(player.position.x-position.x,55,215)
			if not attack in attacks_seen: attacks_seen.append(attack)
		"warning":
			state = "attack"
			if attack == 1: _volley(false)
		"attack":
			state = "recover"
			projectiles.clear()
			hit_this_opening = false
			recharge_available = true
		"recover":
			state = "prepare"
			cycle += 1
			attack = cycle % 3
			recharge_available = false
		"transition": state = "prepare"
		"defeat": completed = true

func _volley(followup: bool) -> void:
	for n in range(3):
		# Horizontal lanes have 25px gaps for a 14px player. Floor remains safe.
		var y := 58.0+n*28.0 + (10 if followup else 0)
		projectiles.append({"pos":Vector2(218,y),"previous":Vector2(218,y),"velocity":Vector2(-64-n*4,0)})

func head_position() -> Vector2:
	var p := Vector2(230,83+sin(clock*1.8)*2)
	if state == "warning": p += Vector2(8*minf(age/0.5,1),-5)
	if state == "attack" and attack == 0: p = Vector2(222,118)
	if state == "attack" and attack == 1: p += Vector2(-6,-16)
	if state == "recover": p = p.lerp(Vector2(210,120),minf(age/0.35,1))
	if state == "transition": p += Vector2(0,-12*sin(age*PI/1.4))
	if state == "defeat": p += Vector2(-18*minf(age,1),45*minf(age/1.5,1))
	return (p+Vector2(hurt*14,-hurt*9)).round()

func weak_rect() -> Rect2:
	return Rect2(head_position()+Vector2(-10,-7),Vector2(19,16))

func fire_polygon() -> PackedVector2Array:
	var mouth := head_position()+Vector2(-8,5)
	var end := Vector2(76,130+sin(age*2.5)*6)
	var normal := (end-mouth).normalized().orthogonal()*6
	return PackedVector2Array([mouth+normal,end+normal,end-normal,mouth-normal])

func claw_rect() -> Rect2:
	return Rect2(target_x-18,105,36,39)

func wave_rect() -> Rect2:
	return Rect2(target_x-20-maxf(0,age-0.18)*86,134,12,10)

func world_step(dt: float, player: Node2D, strike: Dictionary = {}) -> Dictionary:
	var result := {"dead":false,"hit":false,"refill":false,"complete":false}
	if not active: return result
	var p: Vector2 = player.position-position
	var rect := Rect2(p+Vector2(-4,-14),Vector2(8,14))
	if dt > 0:
		clock += dt
		hurt = maxf(0,hurt-dt)
		var before := age
		age += dt
		if state == "attack" and attack == 1 and phase == 2 and before < 0.8 and age >= 0.8: _volley(true)
		if age >= duration(): _next(player)
		for bullet in projectiles:
			bullet.previous = bullet.pos
			bullet.pos += bullet.velocity*dt
		projectiles = projectiles.filter(func(b): return b.pos.x > 8)
	if state not in ["defeat", "transition"]:
		# Body and solid impacts cannot be phased. Head is approachable in recovery.
		if rect.intersects(Rect2(248,88,46,56)): result.dead = true
		if state == "attack":
			if attack == 0:
				var swept := Rect2(previous_player+Vector2(-4,-14),Vector2(8,14)).merge(rect)
				var poly := PackedVector2Array([swept.position,Vector2(swept.end.x,swept.position.y),swept.end,Vector2(swept.position.x,swept.end.y)])
				if not Geometry2D.intersect_polygons(fire_polygon(),poly).is_empty(): result.dead = true
			elif attack == 2:
				var swept := Rect2(previous_player+Vector2(-4,-14),Vector2(8,14)).merge(rect)
				if age < 0.42 and swept.intersects(claw_rect()): result.dead = true
				if age >= 0.18 and swept.intersects(wave_rect()): result.dead = true
		for bullet in projectiles:
			if Geometry._segment_hits_rect(bullet.previous if dt > 0 else bullet.pos,bullet.pos,rect.grow(4)) and not player.can_phase(): result.dead = true
		if state == "recover" and recharge_available and p.distance_to(Vector2(112,144)) < 13:
			player.refill_at_anchor()
			recharge_available = false
			result.refill = true
		if not result.dead and state == "recover" and age > 0.4 and not hit_this_opening and dt > 0 and not strike.is_empty() and int(strike.id) != last_strike:
			var hitbox: Rect2 = strike.rect
			hitbox.position -= position
			if hitbox.intersects(weak_rect()):
				last_strike = int(strike.id)
				health -= 1
				strike_hits += 1
				hurt = 0.5
				hit_this_opening = true
				result.hit = true
				if health == 4:
					phase = 2
					state = "transition"
					age = 0
					projectiles.clear()
				elif health <= 0:
					state = "defeat"
					age = 0
					projectiles.clear()
	previous_player = p
	if is_instance_valid(throat):
		throat.position = head_position()
		throat.energy = maxf(0.15,0.5 + (age/duration() if state == "warning" else 0.0) + (1.1 if state == "attack" and attack == 0 else 0.0) - (age*0.2 if state == "defeat" else 0))
	result.complete = completed
	queue_redraw()
	return result

func _poly(points: Array, color: Color) -> void:
	var poly := PackedVector2Array(points)
	draw_colored_polygon(poly,color)
	poly.append(poly[0])
	draw_polyline(poly,Color("1a1623"),1)

func _draw() -> void:
	var breath := sin(clock*1.8)*2
	var body := Vector2(264,100+breath)
	var h := head_position()
	var collapse := minf(age/2,1) if state == "defeat" else 0.0
	var wing: float = sin(clock*2.1)*12 - (16*minf(age/0.5,1) if state == "warning" else 0)
	if state == "attack": wing += 18*sin(minf(age/0.5,1)*PI/2)
	wing += collapse*40
	# Segmented tail, two articulated wings, torso, bent neck, jaw, horns, claws.
	var prev := body+Vector2(14,9)
	for n in range(7):
		var next := Vector2(280+n*4,115+sin(clock*2-n*0.6)*(3+n*0.7)+n*2)
		draw_line(prev.round(),next.round(),SCALE.darkened(n*0.07),maxf(2,10-n))
		_poly([next+Vector2(-3,0),next+Vector2(0,-6),next+Vector2(3,0)],GOLD.darkened(0.3))
		prev = next
	_poly([body+Vector2(2,-10),Vector2(312,22+wing),Vector2(305,97+wing/3)],Color("503042"))
	_poly([body+Vector2(-9,-5),Vector2(230,28+wing),Vector2(184,16+wing),Vector2(202,62+wing/2),Vector2(220,53+wing/2),Vector2(231,78+wing/3)],Color("aa4b35") if phase == 2 else Color("743445"))
	for end in [Vector2(184,16+wing),Vector2(202,62+wing/2),Vector2(220,53+wing/2)]:
		draw_line(Vector2(230,28+wing),end.round(),FIRE.darkened(0.2),2)
	_poly([body+Vector2(-15,-18),body+Vector2(11,-20),body+Vector2(24,-2),body+Vector2(15,24),body+Vector2(-8,28),body+Vector2(-20,7)],SCALE)
	_poly([body+Vector2(-13,-10),body+Vector2(-3,-9),body+Vector2(2,20),body+Vector2(-11,24)],FIRE.darkened(0.35))
	var neck := Vector2(244,72+breath)
	draw_line(body+Vector2(-12,-4),neck,DARK,17)
	draw_line(neck,h+Vector2(12,0),DARK,15)
	draw_line(body+Vector2(-13,-5),neck,SCALE,12)
	draw_line(neck,h+Vector2(12,0),SCALE,10)
	draw_line(neck+Vector2(-2,4),h+Vector2(6,5),FIRE if state in ["warning","attack"] else GOLD.darkened(0.45),4)
	for n in range(3):
		var q := neck.lerp(h+Vector2(12,0),n/3.0)
		_poly([q+Vector2(0,-4),q+Vector2(8,-13),q+Vector2(7,-2)],GOLD.darkened(0.2))
	_poly([h+Vector2(12,-7),h+Vector2(2,-10),h+Vector2(-9,-5),h+Vector2(-16,3),h+Vector2(-4,6),h+Vector2(10,3)],FIRE.lightened(0.15) if hurt > 0 else SCALE.lightened(0.2))
	var jaw: float = 6.0 if state == "attack" else (4*age/duration() if state == "warning" else 0)
	_poly([h+Vector2(9,3),h+Vector2(-13,5+jaw),h+Vector2(-5,10+jaw),h+Vector2(11,7)],SCALE.darkened(0.3))
	_poly([h+Vector2(8,-7),h+Vector2(20,-21),h+Vector2(15,-5)],GOLD)
	draw_rect(Rect2(h+Vector2(-5,-4),Vector2(4,2)),CYAN if state == "defeat" else GOLD)
	for n in range(3): draw_line(h+Vector2(-10+n*5,5),h+Vector2(-9+n*5,8),GOLD)
	for side in [0,1]:
		var foot := Vector2(246+side*32,140)
		if side == 0 and state == "warning" and attack == 2: foot = Vector2(target_x,87)
		elif side == 0 and state == "attack" and attack == 2: foot = Vector2(target_x,139 if age < 0.42 else 118)
		var shoulder := body+Vector2(-8+side*23,0)
		var elbow := shoulder.lerp(foot,0.5)+Vector2(-10,0)
		draw_polyline(PackedVector2Array([shoulder,elbow,foot]),DARK,9)
		draw_polyline(PackedVector2Array([shoulder,elbow,foot]),SCALE,6)
		for n in range(3): draw_line(foot+Vector2(-5+n*4,0),foot+Vector2(-7+n*4,4),GOLD,2)
	if state == "warning":
		if attack == 0:
			draw_dashed_line(Vector2(76,140),Vector2(220,140),GOLD,1,4)
		elif attack == 1:
			for n in range(3): draw_dashed_line(Vector2(40,58+n*28),Vector2(217,58+n*28),Color(GOLD,0.45),1,4)
		else: draw_rect(claw_rect(),Color(GOLD,0.25),false,2)
	if state == "attack":
		if attack == 0:
			draw_colored_polygon(fire_polygon(),FIRE)
			draw_line(head_position()+Vector2(-8,5),Vector2(76,130+sin(age*2.5)*6),GOLD,3)
			for n in range(10): draw_rect(Rect2(80+n*14,145,7,1),Color(FIRE,0.5))
		elif attack == 2:
			if age < 0.42: draw_rect(claw_rect(),Color(RED,0.45))
			if age >= 0.18:
				var r := wave_rect()
				_poly([r.position+Vector2(0,10),r.position+Vector2(6,0),r.end],FIRE)
	for bullet in projectiles:
		var p: Vector2 = Vector2(bullet.pos).round()
		draw_line(p+Vector2(11,0),p,Color(FIRE,0.3),3)
		draw_circle(p,4,FIRE)
		draw_rect(Rect2(p-Vector2(2,2),Vector2(4,4)),GOLD)
	if state == "recover" and age > 0.4 and not hit_this_opening:
		var r := weak_rect()
		# Opening plates change the silhouette, not just its tint.
		_poly([r.position+Vector2(-3,0),r.position+Vector2(-8,8),r.position+Vector2(-3,16)],CYAN)
		_poly([r.position+Vector2(22,0),r.position+Vector2(27,8),r.position+Vector2(22,16)],CYAN)
		draw_circle(r.get_center(),5,Color("0d1013"))
		draw_line(r.get_center()-Vector2(3,0),r.get_center()+Vector2(3,0),GOLD,2)
	if recharge_available:
		draw_arc(Vector2(112,137),8,0,TAU,16,CYAN,1)
		_poly([Vector2(112,130),Vector2(116,137),Vector2(112,143),Vector2(108,137)],CYAN)
	for n in range(22):
		var p := Vector2(188+fposmod(n*31.0+clock*7,120),140-fposmod(n*17.0+clock*(7+n%3),120))
		draw_rect(Rect2(p.round(),Vector2(1,2)),Color(CYAN if state == "defeat" else FIRE,0.4))
