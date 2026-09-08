extends RefCounted
## Milo's segmented pixel silhouette, drawn from a table of limb offsets.
##
## Pure drawing: nothing here reads or mutates player state, so the same routine
## paints the live character, every afterimage in the trail, and anything else
## that needs to show Milo. The two values a pose genuinely needs from the
## player - the breathing clock and the remaining wall grip - arrive as
## parameters instead of being reached for.

const WHITE: Color = Color("f8f8f2")
const CYAN: Color = Color("61e7ff")
const MAGENTA: Color = Color("ff5fcb")
const RED: Color = Color("ff5a67")
const INK: Color = Color("0d1013")

## Grip below this fraction turns the wall-cling accent magenta as a warning.
const GRIP_WARNING: float = 0.23


static func figure(canvas: CanvasItem, origin: Vector2, direction: int, tint: Color, pose: String, frame: int, detailed: bool, visual_clock: float = 0.0, grip: float = 1.0, costume: int = 0) -> void:
	# Original segmented pixel silhouette: pose changes each limb and helmet.
	var head: Vector2 = Vector2(-3, -14)
	var torso: Rect2 = Rect2(-2, -9, 5, 5)
	var rear_hand: Vector2 = Vector2(-4, -5)
	var front_hand: Vector2 = Vector2(4, -5)
	var rear_foot: Vector2 = Vector2(-2, -1)
	var front_foot: Vector2 = Vector2(2, -1)
	var rear_knee: Vector2 = Vector2(-2, -3)
	var front_knee: Vector2 = Vector2(2, -3)
	var accent: Color = CYAN
	var head_size: Vector2 = Vector2(6, 5)
	match pose:
		"melee":
			head += Vector2(2, 1)
			front_hand = Vector2(13, -12)
			rear_hand = Vector2(-6, -5)
			front_foot = Vector2(4, -1)
		"idle", "respawn":
			var breath: float = 1.0 if sin(visual_clock * 2.8) > 0.55 else 0.0
			head.y += breath
			torso.position.y += breath
			front_hand.y -= breath
		"start":
			head += Vector2(1, 1)
			torso.position += Vector2(1, 1)
			rear_hand = Vector2(-4, -6)
			front_hand = Vector2(3, -7)
			front_foot.x = 3
		"run":
			var stride: Array[Vector4] = [Vector4(-2, 0, 2, -1), Vector4(-2, -1, 1, 0), Vector4(-1, -2, 0, 0), Vector4(0, -1, -1, 0), Vector4(2, 0, -2, -1), Vector4(2, -1, -1, 0), Vector4(1, -2, 0, 0), Vector4(0, -1, 1, 0)]
			var legs: Vector4 = stride[frame]
			var bob: float = -1.0 if frame % 4 >= 2 else 0.0
			head += Vector2(1, bob)
			torso.position += Vector2(0, bob)
			rear_foot = Vector2(-1 + legs.x, -1 + legs.y)
			front_foot = Vector2(1 + legs.z, -1 + legs.w)
			rear_knee = Vector2(-1 + legs.x * 0.5, -3 + legs.y)
			front_knee = Vector2(1 + legs.z * 0.5, -3 + legs.w)
			rear_hand = Vector2(-2 - legs.z, -6 - legs.w)
			front_hand = Vector2(2 - legs.x, -6 - legs.y)
		"skid":
			head += Vector2(-1, 1)
			torso.position += Vector2(-1, 1)
			front_knee = Vector2(2, -3)
			front_foot = Vector2(4, -1)
			rear_foot = Vector2(-3, -1)
			front_hand = Vector2(4, -7)
			rear_hand = Vector2(-5, -7)
		"takeoff", "land":
			head.y += 2
			torso.position.y += 2
			torso.size.y = 4
			front_knee = Vector2(3, -3)
			rear_knee = Vector2(-3, -3)
			front_hand = Vector2(4, -4)
			rear_hand = Vector2(-4, -4)
		"rise", "wall_jump", "double_jump", "bounce":
			head.y -= 1
			front_hand = Vector2(3, -10)
			rear_hand = Vector2(-4, -6)
			front_knee = Vector2(3, -5)
			front_foot = Vector2(2, -3)
			rear_foot = Vector2(-3, -1)
			if pose == "wall_jump":
				rear_hand = Vector2(-5, -10)
				rear_foot = Vector2(-4, -3)
			if pose == "double_jump":
				accent = MAGENTA
				rear_hand = Vector2(-4, -11)
				front_hand = Vector2(4, -11)
			if pose == "bounce":
				torso.size.y = 6
				front_hand = Vector2(4, -12)
				rear_hand = Vector2(-4, -12)
				front_foot = Vector2(1, -1)
		"fall", "focus":
			front_hand = Vector2(5, -9)
			rear_hand = Vector2(-5, -9)
			front_foot = Vector2(3, -1)
			rear_foot = Vector2(-3, -2)
			if pose == "focus":
				front_foot = Vector2(2, -3)
				rear_foot = Vector2(-2, -3)
		"wall_cling", "wall_slide":
			head.x += 1
			front_hand = Vector2(4, -12)
			rear_hand = Vector2(4, -8)
			front_knee = Vector2(3, -5)
			front_foot = Vector2(4, -3)
			rear_foot = Vector2(-2, -1)
			if pose == "wall_slide":
				head.y += 1
				front_hand.y += 1
			if grip < GRIP_WARNING:
				accent = MAGENTA
		"dash", "air_dash":
			head = Vector2(0, -12)
			torso = Rect2(-4, -9, 7, 4)
			rear_hand = Vector2(-6, -8)
			front_hand = Vector2(5, -7)
			rear_knee = Vector2(-4, -4)
			front_knee = Vector2(-1, -4)
			rear_foot = Vector2(-6, -3)
			front_foot = Vector2(-3, -1)
			accent = CYAN if frame % 2 == 0 else MAGENTA
			if detailed:
				var smear: float = float(frame % 3) * 2.0
				_box(canvas, origin, Rect2(-11 - smear, -10, 7 + smear, 2), Color(accent, 0.65), direction)
				_box(canvas, origin, Rect2(-8 - smear, -6, 5 + smear, 1), accent, direction)
		"strike":
			head = Vector2(-3, -15)
			torso = Rect2(-2, -10, 4, 6)
			front_hand = Vector2(4, -12)
			rear_hand = Vector2(-4, -12)
			front_knee = Vector2(1, -4)
			rear_knee = Vector2(-1, -4)
			front_foot = Vector2(0, -1)
			rear_foot = Vector2(-1, -1)
			accent = MAGENTA
		"hit":
			head += Vector2(-2, 1)
			rear_hand = Vector2(-6, -9)
			front_hand = Vector2(5, -10)
			front_foot.x = 4
			accent = RED
		"goal":
			head.y -= 1
			front_hand = Vector2(5, -15)
			rear_hand = Vector2(-4, -6)
	# Quarter-world-pixel artwork: 4x the old effective detail, shared by all poses.
	# The ivory helmet, cyan visor and chronometer keep Milo recognizable.
	var cloth: Color = [Color("c89a59"), Color("eee0b6"), Color("63848d"), Color("677ab3")][clampi(costume, 0, 3)]
	var trim: Color = [Color("775039"), Color("bb5554"), Color("ca985b"), Color("df77bd")][clampi(costume, 0, 3)]
	if not detailed:
		cloth = tint
		trim = tint
	elif pose == "hit":
		cloth = RED
	var shade: Color = cloth.darkened(0.35)
	var helmet: Color = Color("e8e6d5") if detailed else tint
	var dark: Color = Color("283642") if detailed else tint
	# Articulated limbs retain the existing pose offsets and timing.
	_limb(canvas, origin, Vector2(-1, -5), rear_knee, dark, direction)
	_limb(canvas, origin, rear_knee, rear_foot, shade, direction, 1.5)
	_limb(canvas, origin, torso.position + Vector2(0, 1), rear_hand, shade, direction, 1.75)
	_box(canvas, origin, Rect2(rear_foot + Vector2(-1, -0.5), Vector2(3, 1.5)), dark, direction)
	_box(canvas, origin, torso.grow(0.5), INK if detailed else tint, direction)
	_box(canvas, origin, torso, cloth, direction)
	_box(canvas, origin, Rect2(torso.position, Vector2(1, torso.size.y)), shade, direction)
	_limb(canvas, origin, Vector2(1, -5), front_knee, dark, direction, 2)
	_limb(canvas, origin, front_knee, front_foot, cloth, direction, 1.75)
	_box(canvas, origin, Rect2(front_foot + Vector2(-1, -0.5), Vector2(3, 1.5)), dark, direction)
	_limb(canvas, origin, torso.position + Vector2(torso.size.x - 1, 1), front_hand, cloth, direction, 1.75)
	# Rounded stepped helmet rather than a six-pixel solid block.
	_box(canvas, origin, Rect2(head + Vector2(0.25, -0.5), Vector2(5.25, 6)), INK if detailed else tint, direction)
	_box(canvas, origin, Rect2(head + Vector2(-0.5, 0.5), Vector2(6.75, 4)), INK if detailed else tint, direction)
	_box(canvas, origin, Rect2(head + Vector2(0, 0.75), Vector2(5.75, 3.75)), helmet, direction)
	_box(canvas, origin, Rect2(head + Vector2(0.75, 0), Vector2(4.5, 5)), helmet, direction)
	if detailed:
		# Fabric folds, seams, belt, bronze buckle and leather satchel.
		_box(canvas, origin, Rect2(torso.position + Vector2(1.25, 0.5), Vector2(0.5, torso.size.y - 1)), cloth.lightened(0.25), direction)
		_box(canvas, origin, Rect2(torso.position + Vector2(3, 1), Vector2(0.25, 2.5)), shade, direction)
		_box(canvas, origin, Rect2(-2.5, -5.25, 5.5, 0.75), trim.darkened(0.4), direction)
		_box(canvas, origin, Rect2(0, -5.5, 1, 1), Color("ecc57a"), direction)
		_box(canvas, origin, Rect2(-3.25, -6, 1.75, 2.5), trim.darkened(0.15), direction)
		_box(canvas, origin, Rect2(-3, -5.75, 1.25, 0.5), trim.lightened(0.25), direction)
		_box(canvas, origin, Rect2(front_foot + Vector2(-0.75, 0.5), Vector2(2.5, 0.25)), Color("a0b2b5"), direction)
		# Visor rim, reflected glass, face/nose and separate one-quarter-pixel eye.
		_box(canvas, origin, Rect2(head + Vector2(2, 1.5), Vector2(4, 2.75)), dark, direction)
		_box(canvas, origin, Rect2(head + Vector2(2.25, 1.75), Vector2(3.5, 1.75)), Color("238b9f"), direction)
		_box(canvas, origin, Rect2(head + Vector2(2.25, 1.75), Vector2(3.25, 0.5)), accent, direction)
		_box(canvas, origin, Rect2(head + Vector2(3.5, 2.5), Vector2(2.25, 1)), Color("d99c7b"), direction)
		_box(canvas, origin, Rect2(head + Vector2(4.5, 2.5), Vector2(0.5, 0.5)), INK, direction)
		_box(canvas, origin, Rect2(head + Vector2(1, 0.25), Vector2(3.25, 0.5)), WHITE, direction)
		_box(canvas, origin, Rect2(head + Vector2(0, 1.75), Vector2(1.5, 2)), Color("758b98"), direction)
		_box(canvas, origin, Rect2(head + Vector2(0.25, 2), Vector2(0.75, 0.75)), accent, direction)
		_box(canvas, origin, Rect2(head + Vector2(1.5, 4.25), Vector2(3.5, 0.5)), Color("91a4ad"), direction)
		match costume:
			0: # Stitched hide and shaggy fur mantle.
				for n in range(7):
					_box(canvas, origin, Rect2(torso.position + Vector2(-0.75 + n * 0.85, -0.25), Vector2(1, 1.25 + (n % 2) * 0.5)), Color("e2c194") if n % 2 == 0 else trim, direction)
				for n in range(3):
					_box(canvas, origin, Rect2(torso.position + Vector2(2.5, 1.75 + n * 0.75), Vector2(0.75, 0.25)), Color("f1d39f"), direction)
			1: # Linen chiton, crimson drape, bronze clasp and sandal straps.
				_box(canvas, origin, Rect2(torso.position + Vector2(-0.5, 0), Vector2(1.75, torso.size.y + 0.75)), trim, direction)
				_box(canvas, origin, Rect2(-2, -4.75, 5, 1.5), cloth, direction)
				for n in range(3):
					_box(canvas, origin, Rect2(-1.75 + n * 1.5, -4.5, 0.5, 1), shade, direction)
				_box(canvas, origin, Rect2(torso.position + Vector2(0, 0.5), Vector2(0.75, 0.75)), Color("ffd27e"), direction)
				_box(canvas, origin, Rect2(front_foot + Vector2(-0.5, -0.75), Vector2(1.75, 0.5)), trim, direction)
			2: # Work jacket, copper goggles and utility harness.
				_box(canvas, origin, Rect2(head + Vector2(1, -0.25), Vector2(4.5, 1)), trim.darkened(0.3), direction)
				for x in [2.0, 4.0]:
					_box(canvas, origin, Rect2(head + Vector2(x, -0.5), Vector2(1.5, 1.25)), trim, direction)
					_box(canvas, origin, Rect2(head + Vector2(x + 0.25, -0.25), Vector2(1, 0.5)), CYAN, direction)
				_box(canvas, origin, Rect2(torso.position + Vector2(0.75, 0), Vector2(0.75, torso.size.y)), trim, direction)
				_box(canvas, origin, Rect2(torso.position + Vector2(3, 2.25), Vector2(1.25, 1)), shade, direction)
			3: # Armored survival suit, magenta shoulder plates and circuitry.
				_box(canvas, origin, Rect2(torso.position + Vector2(-0.75, 0), Vector2(2, 1.5)), trim, direction)
				_box(canvas, origin, Rect2(torso.position + Vector2(3.75, 0), Vector2(1.75, 1.25)), Color("b7c9e8"), direction)
				_box(canvas, origin, Rect2(torso.position + Vector2(1.75, 2.5), Vector2(2.5, 0.25)), CYAN, direction)
				_box(canvas, origin, Rect2(front_knee + Vector2(-0.75, -0.5), Vector2(1.5, 1)), trim, direction)
		# Constant time-traveler signatures, anchored to the posed torso/hand.
		_box(canvas, origin, Rect2(torso.position + Vector2(2, 0.75), Vector2(1.75, 1.75)), dark, direction)
		_box(canvas, origin, Rect2(torso.position + Vector2(2.25, 1), Vector2(1.25, 1.25)), accent, direction)
		_box(canvas, origin, Rect2(torso.position + Vector2(2.75, 1), Vector2(0.25, 0.75)), WHITE, direction)
		_box(canvas, origin, Rect2(front_hand - Vector2(0.75, 0.75), Vector2(1.25, 0.75)), accent, direction)
		if pose == "strike":
			_limb(canvas, origin, Vector2(-3, 1), Vector2(0, 5), accent, direction, 1)
			_limb(canvas, origin, Vector2(0, 5), Vector2(3, 1), accent, direction, 1)
		if pose == "double_jump" or pose == "focus":
			for index in range(4):
				var p: Vector2 = Vector2(-7 if index % 2 == 0 else 6, -15 if index < 2 else -2)
				_box(canvas, origin, Rect2(p, Vector2(2, 1)), accent, direction)
		if pose == "wall_cling" or pose == "wall_slide":
			_box(canvas, origin, Rect2(5, -12, 1, 8), Color(accent, 0.7), direction)
		if pose == "goal":
			_box(canvas, origin, Rect2(4, -20, 3, 3), CYAN, direction)
			_box(canvas, origin, Rect2(5, -19, 1, 1), INK, direction)


## Pixel shatter that replaces the silhouette on death. `progress` runs 0 to 1.
static func death(canvas: CanvasItem, progress: float) -> void:
	for index in range(10):
		var angle: float = float(index) * TAU / 10.0
		var point: Vector2 = Vector2(cos(angle), sin(angle)) * progress * 18.0 + Vector2(0, -7)
		var tint: Color = WHITE if index % 3 == 0 else (CYAN if index % 2 == 0 else RED)
		canvas.draw_rect(Rect2(point.round(), Vector2(2, 2)), Color(tint, 1.0 - progress))


static func _box(canvas: CanvasItem, origin: Vector2, rectangle: Rect2, color: Color, direction: int) -> void:
	var result: Rect2 = rectangle
	if direction < 0:
		result.position.x = -rectangle.position.x - rectangle.size.x
	result.position = (result.position + origin).snapped(Vector2(0.25, 0.25))
	canvas.draw_rect(result, color)


static func _limb(canvas: CanvasItem, origin: Vector2, start: Vector2, end: Vector2, color: Color, direction: int, width: float = 2.0) -> void:
	var length: int = maxi(1, int(ceilf(maxf(absf(end.x - start.x), absf(end.y - start.y)) * 4.0)))
	for index in range(length + 1):
		var point: Vector2 = start.lerp(end, float(index) / float(length)).snapped(Vector2(0.25, 0.25))
		_box(canvas, origin, Rect2(point - Vector2.ONE * width / 2.0, Vector2(width, width)), color, direction)
