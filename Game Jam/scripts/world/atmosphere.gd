@tool
extends Node2D
## Fixed illumination plus explicit-clock details. No idle-time flicker.
var chapter := 0
var clock := 0.0
var lights: Array[PointLight2D] = []
var points: Array[Vector2] = []
var extent := Vector2.ZERO
static func make_light(color: Color, radius: float, energy: float) -> PointLight2D:
	var gradient := Gradient.new()
	gradient.colors = PackedColorArray([Color.WHITE,Color(1,1,1,0)])
	var texture := GradientTexture2D.new()
	texture.gradient = gradient
	texture.width = 64
	texture.height = 64
	texture.fill = GradientTexture2D.FILL_RADIAL
	texture.fill_from = Vector2(0.5,0.5)
	texture.fill_to = Vector2(1,0.5)
	var light := PointLight2D.new()
	light.texture = texture
	light.texture_scale = radius/32
	light.color = color
	light.energy = energy
	return light
func setup(data: Dictionary) -> void:
	chapter = int(data.chapter)
	extent = Vector2(data.width,data.height)
	for r: Rect2 in data.solids:
		if r.size.x >= 70:
			var p := r.position+Vector2(minf(r.size.x*0.55,120),-34)
			if points.any(func(q): return q.distance_to(p)<65): continue
			points.append(p)
			var light := make_light([Color("ffca74"),Color("ff9845"),Color("ff713c"),Color("ff5fcb")][chapter] if lights.size()%2==0 else Color("61e7ff"),72,0.48)
			light.position = p
			add_child(light)
			lights.append(light)
			if lights.size() >= 10: break
	if bool(data.get("boss",false)):
		for offset in [Vector2(58,101),Vector2(181,45),Vector2(283,87)]:
			var p: Vector2 = data.arena.position+offset
			points.append(p)
			var light := make_light(Color("ff862e"),94,0.55)
			light.position = p
			add_child(light)
			lights.append(light)
	queue_redraw()
func world_step(dt: float) -> void:
	clock += dt
	for i in range(lights.size()): lights[i].energy = 0.48+sin(clock*2+i)*0.06
	queue_redraw()
func cool_after_defeat(amount: float) -> void:
	for light in lights:
		light.color = Color("ff862e").lerp(Color("61e7ff"),clampf(amount,0,1))
		light.energy = lerpf(0.5,0.3,clampf(amount,0,1))
func _draw() -> void:
	for i in range(points.size()):
		var p: Vector2 = points[i]
		var cyan := Color("61e7ff")
		var gold := Color("ffd15c")
		var tint: Color = cyan if i%2 else gold
		# Restrained layered light shafts keep the platform silhouette unobscured.
		for n in range(3):
			draw_colored_polygon(PackedVector2Array([p+Vector2(-2,-42),p+Vector2(6,-42),p+Vector2(36+n*9,35),p+Vector2(-19-n*5,35)]),Color(tint,0.018))
		match chapter:
			0:
				draw_polyline(PackedVector2Array([p+Vector2(-9,-20),p+Vector2(-4,-11),p+Vector2(-6,-3),p]),Color(cyan,0.7),1)
				for n in range(3):
					var end := p+Vector2(24+n*7+sin(clock+n)*2,-4+n*4)
					draw_line(p+Vector2(24+n*7,-40),end,Color("2e4b3f"),1)
			1:
				draw_rect(Rect2(p+Vector2(-3,-2),Vector2(6,13)),Color("8b6540"))
				draw_colored_polygon(PackedVector2Array([p+Vector2(-4,0),p+Vector2(sin(clock*5)*2,-10),p+Vector2(4,0)]),Color("ff862e"))
				draw_line(p+Vector2(-24,34),p+Vector2(25,34),Color(gold,0.22))
			2:
				for n in range(8):
					var direction := Vector2.from_angle(n*TAU/8+clock*0.65)
					draw_line(p+direction*8,p+direction*13,Color("58616b"),3)
				draw_arc(p,8,0,TAU,16,Color("869196"),2)
				draw_rect(Rect2(p+Vector2(-19,18),Vector2(38,5)),Color("704532"))
			_:
				draw_colored_polygon(PackedVector2Array([p+Vector2(-26,33),p+Vector2(-21,4),p+Vector2(-12,-3),p+Vector2(-2,33)]),Color("263329"))
				draw_rect(Rect2(p+Vector2(14,-28),Vector2(8,61)),Color("41332e"))
				draw_rect(Rect2(p+Vector2(10,-32),Vector2(16,5)),Color("695340"))
				for n in range(5): draw_line(p+Vector2(16,-21+n*8),p+Vector2(21,-23+n*8),Color("657c88"))
				draw_arc(p,16,clock*0.3,clock*0.3+2,12,Color(cyan,0.4))
				draw_arc(p,21,clock*0.3+3,clock*0.3+5,12,Color("ff5fcb"))
		for n in range(7):
			var dust := p+Vector2(fposmod(n*11+clock*3,52)-26,16-fposmod(n*9+clock*5,52))
			draw_rect(Rect2(dust.round(),Vector2.ONE),Color(tint,0.3))
