extends RefCounted
## Two separate jobs live here:
##
## 1. draw_environment() / EPOCHS — the epoch backdrops, used at runtime by
##    scripts/ui/level_geometry.gd and in the editor by room_definition.gd.
## 2. build() — the original procedural course generator. The saved scenes in
##    res://rooms/ are the runtime source of truth now, so build() is only used
##    by tools/build_campaign.gd and tools/migrate_rooms.gd to (re)seed them.
const TITLES = ["FIRST TICK", "EYES ON YOU", "BROKEN GEARS", "THE LAST FLAME"]
const EPOCHS = ["PREHISTORY", "ANTIQUITY", "INDUSTRIAL", "FUTURE COLLAPSE"]
const HINTS = ["STOP TO READ THE LUNGE. MOVE TO SURVIVE.", "GOLD AIM LOCKS BEFORE THE SHOT.", "WATCH THE LIGHTS. PACE TO MOVE MACHINERY.", "THE LAST FLAME / J: TEMPORAL STRIKE"]
static func build(index: int) -> Dictionary:
	var i := clampi(index,0,3)
	var width: float = 512 if i == 2 else (888 if i == 3 else 608)
	var lane_width: float = 544 if i == 3 else width
	var rows: int = 5 if i == 2 else (3 if i == 3 else 4)
	var spacing: float = 192 if i<2 else 136
	var height: float = 118+(rows-1)*spacing+38
	var d := {"title":TITLES[i],"epoch":EPOCHS[i],"chapter":i,"room":i,"subtitle":"FRACTURE %02d"%(i+1),"hint":HINTS[i],"width":width,"height":height,"time_limit":110.0 if i<3 else 75.0,"par_time":60.0 if i<3 else 100.0,"spawn":Vector2(25,118),"goal":Vector2(32 if rows%2==0 else lane_width-26,118+(rows-1)*spacing),"echo":false,"boss":i==3,"arena":Rect2(560,246,320,144),"spacing":spacing,"retry_budget":70.0,"solids":[],"spikes":[],"watchers":[],"platforms":[],"barriers":[],"gates":[],"pads":[],"anchors":[],"fields":[],"killzones":[],"signs":[],"crushers":[],"waypoints":[]}
	var gap_plans: Array = [
		[[0,280,64],[1,290,64],[2,272,72],[3,220,112]],
		[[0,312,64],[1,270,72],[2,310,56],[3,240,112]],
		[[0,210,112],[1,300,56],[2,240,96],[3,190,56],[4,260,96]],
		[[0,240,88],[1,270,96],[2,220,64]]]
	for row in range(rows):
		var y := 118.0+row*spacing
		var start := 0.0 if row%2==0 else 32.0
		var end := lane_width-32 if row%2==0 and row != rows-1 else lane_width
		if i==3 and row==2: end=width
		for gap: Array in gap_plans[i]:
			if int(gap[0]) != row: continue
			d.solids.append(Rect2(start,y,float(gap[1])-start,16))
			start = float(gap[1])+float(gap[2])
			d.killzones.append(Rect2(float(gap[1]),y+8,float(gap[2]),4))
			if float(gap[2])>=96:
				var mid := float(gap[1])+float(gap[2])/2
				d.platforms.append({"a":Vector2(mid-10,y-14),"b":Vector2(mid+10,y-32),"size":Vector2(32,8),"speed":24.0,"phase":0.0})
		if start<end: d.solids.append(Rect2(start,y,end-start,16))
		d.waypoints.append(Vector2(24 if row%2==0 else lane_width-16,y))
		d.waypoints.append(Vector2(lane_width-16 if row%2==0 else 16,y))
	# Purposeful climbs and landing pockets replace the old 960px corridors.
	var blocks: Array = [
		[[0,128,24,32],[0,404,24,48],[1,432,24,88],[1,168,24,80],[2,136,24,88],[2,400,24,88],[3,424,24,64],[3,120,24,48]],
		[[0,132,24,48],[0,232,24,32],[0,448,24,56],[1,416,24,88],[1,152,24,88],[2,144,24,80],[2,448,24,64],[3,424,24,80],[3,144,24,72]],
		[[0,112,24,40],[0,376,24,48],[1,392,24,48],[1,200,24,40],[2,120,24,88],[2,368,24,88],[3,368,24,40],[3,104,24,56],[4,112,24,64],[4,392,24,72]],
		[[0,136,24,80],[0,392,24,64],[1,416,24,88],[1,152,24,80],[2,120,24,64],[2,360,24,48]]]
	for b: Array in blocks[i]:
		var tall: float = 128 if i<2 and int(b[0])>0 else float(b[3])
		d.solids.append(Rect2(float(b[1]),118+int(b[0])*spacing-tall,float(b[2]),tall))
	# Every hazardous lane is preceded by cover and has a visible landing.
	if i==0:
		_spike(d,0,194,253,0.0)
		_spike(d,1,218,260,0.25)
		_watcher(d,1,372,0.2)
		_watcher(d,2,472,0.45)
		_watcher(d,3,352,0.25)
		d.barriers.append({"rect":Rect2(370,518,5,176),"kind":"phase"})
		d.signs.append({"pos":Vector2(30,88),"text":"STOP: RAPTOR FREEZES / WATCH ITS CROUCH"})
	elif i==1:
		_watcher(d,0,194,0.0)
		_watcher(d,0,400,0.5)
		_watcher(d,1,352,0.25)
		_watcher(d,2,400,0.15)
		_watcher(d,3,368,0.5)
		_spike(d,2,240,288,0.2)
		d.gates.append({"rect":Rect2(208,326,5,176),"period":3.2,"open_ratio":0.7,"phase":0.3})
		d.barriers.append({"rect":Rect2(392,518,5,176),"kind":"phase"})
		d.signs.append({"pos":Vector2(54,466),"text":"PACE HERE TO OPEN THE GATE"})
	elif i==2:
		_spike(d,0,342,367,0.2)
		for x in [112,246]: d.crushers.append({"rect":Rect2(x,164,28,90),"period":3.4,"phase":0.2 if x==112 else 0.65})
		_watcher(d,2,330,0.1)
		_watcher(d,4,354,0.35)
		d.barriers.append({"rect":Rect2(480,426,32,4),"kind":"fragile"})
		d.fields.append({"rect":Rect2(340,570,105,70),"multiplier":0.5})
		d.crushers.append({"rect":Rect2(208,580,28,82),"period":3.4,"phase":0.4})
		d.signs.append({"pos":Vector2(340,402),"text":"DOWN + SHIFT: BREAK THE FLOOR"})
	else:
		d.solids.append(Rect2(536,0,8,272))
		_watcher(d,0,344,0.3)
		_spike(d,1,210,250,0.1)
		d.barriers.append({"rect":Rect2(384,270,5,120),"kind":"phase"})
		d.solids.append(Rect2(630,350,40,8))
		d.solids.append(Rect2(748,342,32,8))
		d.anchors.append({"pos":Vector2(568,390)})
		d.signs.append({"pos":Vector2(410,365),"text":"PYRAX / OPEN HEAD: J STRIKE"})
	if i<3:
		d.anchors.append({"pos":Vector2(48,118+2*spacing)})
	for row in range(rows):
		var labels: Array = [["01 / OBSERVE","02 / CLAWS AND COVER","03 / THE MINERAL SHAFT","04 / THE LAST CROSSING"],["01 / STAGGERED EYES","02 / THE WATCHFUL ASCENT","03 / GUARDIAN'S GATE","04 / ESCAPE THE TEMPLE"],["01 / THE BELT","02 / CRUSHER POCKETS","03 / THE LIFT SHAFT","04 / STRIKE THE SEAL","05 / LAST SHIFT"],["01 / FRACTURED CORE","02 / BORROWED TIME","03 / THE LAST FLAME"]][i]
		d.signs.append({"pos":Vector2(44,118+row*spacing-110),"text":labels[row]})
	return d
static func _spike(d: Dictionary,row: int,a: float,b: float,phase: float) -> void:
	d.spikes.append({"a":Vector2(a,111+row*float(d.spacing)),"b":Vector2(b,111+row*float(d.spacing)),"speed":28.0,"phase":phase,"size":Vector2(14,14),"lunge":int(d.chapter)<2})
static func _watcher(d: Dictionary,row: int,x: float,phase: float) -> void:
	d.watchers.append({"pos":Vector2(x,74+row*float(d.spacing)),"interval":2.7,"phase":phase,"speed":58.0,"range":168.0})



static func draw_environment(canvas: Node2D, index: int, width: float, world_time: float) -> void:
	var bg := Color("0D1013")
	var cyan := Color("61E7FF")
	var magenta := Color("FF5FCB")
	# The broad middle band gives the silhouette art space beneath the interface.
	canvas.draw_rect(Rect2(0, 31, width, 123), bg.lightened(0.017))
	match index:
		0: _prehistory(canvas, width)
		1: _antiquity(canvas, width)
		2: _industrial(canvas, width, world_time)
		3: _collapse(canvas, width, world_time)
	# Small deterministic motes remain perfectly motionless during frozen time.
	for i in range(int(width / 48.0)):
		var x := float(i * 48 + 21)
		var y := 52.0 + float((i * 37) % 81) + floorf(sin(world_time * 0.6 + float(i)) * 2.0)
		var color := cyan if i % 3 != 0 else magenta
		color.a = 0.16 if index < 3 else 0.26
		canvas.draw_rect(Rect2(x, y, 1, 1), color)
	# The destination has its own restrained architectural frame behind the goal.
	var end_x := width - 30.0
	var frame := Color("263940") if index < 3 else Color("402B42")
	canvas.draw_rect(Rect2(end_x - 17, 112, 3, 42), frame)
	canvas.draw_rect(Rect2(end_x + 14, 112, 3, 42), frame)
	canvas.draw_rect(Rect2(end_x - 17, 109, 34, 3), frame)
	canvas.draw_rect(Rect2(end_x - 13, 106, 26, 1), Color(cyan, 0.20))


static func _prehistory(c: Node2D, width: float) -> void:
	var earth := Color("211E19")
	var jungle := Color("182A25")
	var distant := Color("13201D")
	# Alternating rock ridges make an open clearing, rather than a closed tunnel.
	for i in range(int(width / 130.0) + 1):
		var x := float(i * 130)
		c.draw_colored_polygon(PackedVector2Array([Vector2(x - 25, 154), Vector2(x + 2, 92), Vector2(x + 30, 87), Vector2(x + 55, 108), Vector2(x + 78, 96), Vector2(x + 133, 154)]), distant)
	for tree in [Vector2(59, 55), Vector2(353, 42), Vector2(573, 59)]:
		var x: float = tree.x
		var y: float = tree.y
		c.draw_colored_polygon(PackedVector2Array([Vector2(x - 6, 154), Vector2(x - 1, y + 19), Vector2(x - 12, y + 3), Vector2(x - 9, y), Vector2(x + 3, y + 13), Vector2(x + 13, y - 8), Vector2(x + 16, y - 7), Vector2(x + 7, y + 24), Vector2(x + 9, 154)]), jungle)
		c.draw_rect(Rect2(x - 3, y + 36, 2, 81 - y * 0.2), Color("20352D"))
		c.draw_rect(Rect2(x - 25, y - 7, 31, 10), distant)
		c.draw_rect(Rect2(x - 14, y - 14, 43, 9), distant)
		c.draw_rect(Rect2(x + 20, y - 4, 17, 7), distant)
		c.draw_line(Vector2(x + 27, y + 3), Vector2(x + 27, y + 28), jungle)
		c.draw_rect(Rect2(x + 25, y + 23, 5, 4), jungle)
	for rock in [Vector2(117, 146), Vector2(249, 148), Vector2(500, 145), Vector2(606, 148)]:
		c.draw_colored_polygon(PackedVector2Array([rock + Vector2(-14, 7), rock + Vector2(-9, -6), rock + Vector2(5, -10), rock + Vector2(16, 7)]), earth)
		c.draw_line(rock + Vector2(-6, -6), rock + Vector2(2, -2), Color("374336"))
	# Cyan fissures are sparse visual anchors, never shaped like active spikes.
	for crack_x in [112.0, 401.0, 605.0]:
		c.draw_polyline(PackedVector2Array([Vector2(crack_x, 148), Vector2(crack_x + 3, 142), Vector2(crack_x + 1, 138), Vector2(crack_x + 6, 131)]), Color("285963"), 1.0)
	for i in range(int(width / 23.0)):
		var x := float(i * 23 + 7)
		c.draw_line(Vector2(x, 154), Vector2(x - 3, 149 - i % 3), jungle)
		c.draw_line(Vector2(x, 154), Vector2(x + 3, 151), jungle)
	# A little fossil half-buried behind the route.
	c.draw_line(Vector2(92, 146), Vector2(106, 146), Color("54402B"))
	for x in [94.0, 99.0, 104.0]:
		c.draw_line(Vector2(x, 143), Vector2(x, 150), Color("54402B"))


static func _antiquity(c: Node2D, width: float) -> void:
	var stone := Color("353022")
	var lit_stone := Color("4C402C")
	var lapis := Color("172B3A")
	c.draw_rect(Rect2(0, 83, width, 71), Color("1E211F"))
	for i in range(int(width / 40.0) + 1):
		var x := float(i * 40)
		c.draw_line(Vector2(x, 83), Vector2(x, 101), Color("292B24"))
		c.draw_line(Vector2(x + 20, 103), Vector2(x + 20, 127), Color("292B24"))
	c.draw_line(Vector2(0, 103), Vector2(width, 103), Color("292B24"))
	c.draw_line(Vector2(0, 127), Vector2(width, 127), Color("292B24"))
	for x in [64.0, 147.0, 237.0, 340.0, 460.0, 587.0, 688.0]:
		var top := 45.0 if x > 200 and x < 500 else 65.0
		c.draw_rect(Rect2(x - 8, top, 16, 5), lit_stone)
		c.draw_rect(Rect2(x - 6, top + 5, 12, 85), stone)
		c.draw_rect(Rect2(x - 3, top + 7, 2, 80), lit_stone)
		c.draw_rect(Rect2(x + 2, top + 7, 1, 80), Color("27251E"))
		c.draw_rect(Rect2(x - 8, top + 85, 16, 5), lit_stone)
		c.draw_rect(Rect2(x - 10, top + 90, 20, 3), stone)
	c.draw_rect(Rect2(222, 39, 252, 4), lit_stone)
	c.draw_rect(Rect2(228, 43, 240, 2), stone)
	for i in range(20):
		c.draw_rect(Rect2(229 + i * 12, 37, 5, 2), stone)
	# Recessed lapis mosaics and one fractured sun disk.
	for x in [105.0, 289.0, 530.0]:
		c.draw_rect(Rect2(x - 14, 72, 28, 44), stone)
		c.draw_rect(Rect2(x - 11, 75, 22, 38), lapis)
		c.draw_rect(Rect2(x - 1, 81, 2, 26), Color("31433F"))
		c.draw_rect(Rect2(x - 7, 92, 14, 2), Color("31433F"))
	c.draw_arc(Vector2(393, 63), 22, 0.15, TAU - 0.15, 24, Color("4B3E2B"), 2.0)
	c.draw_line(Vector2(381, 47), Vector2(386, 55), Color("47616A"))
	c.draw_line(Vector2(386, 55), Vector2(381, 59), Color("47616A"))
	# Broken pottery stays below the player's silhouette.
	for x in [119.0, 503.0, 616.0]:
		c.draw_rect(Rect2(x, 145, 6, 8), Color("4B2B24"))
		c.draw_rect(Rect2(x + 1, 143, 4, 2), Color("694031"))


static func _industrial(c: Node2D, width: float, world_time: float) -> void:
	var metal := Color("252B2E")
	var rust := Color("3B2D24")
	var highlight := Color("4B3B2D")
	for i in range(int(width / 100.0) + 1):
		var x := float(i * 100 + 27)
		c.draw_rect(Rect2(x, 64 - i % 3 * 8, 20, 90), Color("19231F"))
		c.draw_rect(Rect2(x - 2, 62 - i % 3 * 8, 24, 3), Color("29312A"))
		c.draw_rect(Rect2(x + 30, 88, 31, 66), Color("1D2525"))
		c.draw_rect(Rect2(x + 35, 96, 6, 4), Color("363B2B"))
		c.draw_rect(Rect2(x + 47, 96, 6, 4), Color("363B2B"))
		var smoke_y := 43.0 - float(i % 3 * 8) - fmod(world_time * 2.0 + float(i * 7), 12.0)
		c.draw_rect(Rect2(x + 1, smoke_y, 18, 9), Color("181E20"))
		c.draw_rect(Rect2(x - 3, smoke_y - 5, 26, 5), Color("151B1D"))
	for x in [73.0, 173.0, 283.0, 437.0, 549.0, 703.0]:
		c.draw_rect(Rect2(x, 47, 4, 107), rust)
		c.draw_rect(Rect2(x + 2, 47, 1, 107), highlight)
		c.draw_line(Vector2(x + 4, 70), Vector2(x + 25, 90), metal)
		c.draw_line(Vector2(x + 4, 111), Vector2(x + 25, 91), metal)
	c.draw_rect(Rect2(0, 48, width, 4), rust)
	c.draw_line(Vector2(0, 53), Vector2(width, 53), highlight)
	for i in range(int(width / 18.0)):
		c.draw_rect(Rect2(i * 18 + 5, 49, 1, 1), Color("61503B"))
	# Large quiet gears reinforce the clockwork epoch without hiding threats.
	for gear in [Vector3(114, 112, 23), Vector3(362, 109, 29), Vector3(654, 104, 26)]:
		var center := Vector2(gear.x, gear.y)
		c.draw_arc(center, gear.z - 4, 0, TAU, 24, metal, 4.0)
		c.draw_arc(center, 6, 0, TAU, 12, rust, 3.0)
		for j in range(8):
			var angle := float(j) * TAU / 8.0 + world_time * 0.11
			var axis := Vector2(cos(angle), sin(angle))
			c.draw_line(center + axis * 8, center + axis * (gear.z - 5), metal, 3.0)
			var tip: Vector2 = (center + axis * gear.z).floor()
			c.draw_rect(Rect2(tip - Vector2(3, 3), Vector2(6, 6)), metal)
	# Thin hanging cables and muted gas tanks, distinct from yellow active rails.
	for x in [210.0, 244.0]:
		c.draw_line(Vector2(x, 55), Vector2(x, 109), Color("2D3335"))
	c.draw_rect(Rect2(497, 126, 17, 28), Color("25352B"))
	c.draw_rect(Rect2(500, 123, 11, 3), Color("324137"))
	c.draw_rect(Rect2(500, 132, 2, 17), Color("344337"))


static func _collapse(c: Node2D, width: float, world_time: float) -> void:
	var ash := Color("25252F")
	var faint := Color("181C24")
	var cyan := Color("284550")
	var magenta := Color("4A2943")
	# Fragments of each former epoch, suspended around a fractured clock face.
	for i in range(int(width / 58.0)):
		var x := float(i * 58 + 24)
		var y := 63.0 + float((i * 29) % 66)
		var fragment_color := ash
		if i % 3 == 0: fragment_color = Color("332D24")
		elif i % 3 == 1: fragment_color = Color("26362E")
		c.draw_colored_polygon(PackedVector2Array([Vector2(x, y), Vector2(x + 23, y - 5), Vector2(x + 34, y + 2), Vector2(x + 27, y + 12), Vector2(x + 8, y + 9)]), fragment_color)
		c.draw_line(Vector2(x + 2, y - 1), Vector2(x + 19, y - 4), cyan if i % 2 == 0 else magenta)
		c.draw_rect(Rect2(x + 9, y + 15, 3, 2), faint)
		c.draw_rect(Rect2(x + 23, y + 19, 2, 2), ash)
	for x in [75.0, 288.0, 590.0, 758.0]:
		c.draw_rect(Rect2(x - 3, 39, 6, 71), faint)
		c.draw_rect(Rect2(x + 8, 49, 2, 89), faint)
		c.draw_line(Vector2(x, 47), Vector2(x + 20, 47), ash)
	# Three parts of the broken core, deliberately offset rather than concentric.
	for center in [Vector2(448, 81), Vector2(445, 85)]:
		c.draw_arc(center, 42, 0.25, 2.25, 24, ash, 3.0)
		c.draw_arc(center + Vector2(3, -4), 42, 2.52, 4.13, 20, ash, 3.0)
		c.draw_arc(center + Vector2(6, 0), 42, 4.45, 6.0, 20, ash, 3.0)
	for i in range(12):
		var angle := float(i) / 12.0 * TAU
		var axis := Vector2(cos(angle), sin(angle))
		c.draw_line(Vector2(448, 81) + axis * 32, Vector2(448, 81) + axis * 37, cyan if i % 2 == 0 else magenta, 1.0)
	var slow_angle := -PI * 0.5 + world_time * 0.04
	c.draw_line(Vector2(448, 81), Vector2(448, 81) + Vector2(cos(slow_angle), sin(slow_angle)) * 25, cyan)
	c.draw_line(Vector2(448, 81), Vector2(431, 87), magenta)
	# Broken temporal seams never use danger red.
	for x in [121.0, 351.0, 616.0, 778.0]:
		c.draw_polyline(PackedVector2Array([Vector2(x, 33), Vector2(x - 4, 57), Vector2(x + 3, 66), Vector2(x - 6, 89), Vector2(x - 2, 109)]), cyan, 1.0)
		c.draw_polyline(PackedVector2Array([Vector2(x + 3, 55), Vector2(x + 7, 68), Vector2(x - 2, 85)]), magenta, 1.0)
	c.draw_line(Vector2(0, 158), Vector2(width, 158), Color("19262D"))
