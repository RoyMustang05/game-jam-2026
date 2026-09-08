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


static func figure(canvas: CanvasItem, origin: Vector2, direction: int, tint: Color, pose: String, frame: int, detailed: bool, visual_clock: float = 0.0, grip: float = 1.0) -> void:
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
	var shade: Color = tint.darkened(0.24) if detailed else tint
	_limb(canvas, origin, Vector2(-1, -5), rear_knee, shade, direction)
	_limb(canvas, origin, rear_knee, rear_foot, shade, direction)
	_limb(canvas, origin, Vector2(-2, -8), rear_hand, shade, direction)
	_box(canvas, origin, Rect2(rear_foot + Vector2(-1, 0), Vector2(3, 1)), shade, direction)
	if detailed:
		_box(canvas, origin, Rect2(head - Vector2.ONE, head_size + Vector2(2, 2)), INK, direction)
		_box(canvas, origin, torso.grow(1), INK, direction)
	_box(canvas, origin, torso, tint, direction)
	_box(canvas, origin, Rect2(torso.position + Vector2(0, torso.size.y - 1), Vector2(torso.size.x, 1)), shade, direction)
	_limb(canvas, origin, Vector2(1, -5), front_knee, tint, direction)
	_limb(canvas, origin, front_knee, front_foot, tint, direction)
	_box(canvas, origin, Rect2(front_foot + Vector2(-1, 0), Vector2(3, 1)), tint, direction)
	_box(canvas, origin, Rect2(head, head_size), tint, direction)
	_box(canvas, origin, Rect2(head + Vector2(0, 4), Vector2(5, 1)), shade, direction)
	_limb(canvas, origin, torso.position + Vector2(torso.size.x - 1, 1), front_hand, tint, direction)
	if detailed:
		_box(canvas, origin, Rect2(head + Vector2(3, 2), Vector2(3, 2)), accent, direction)
		_box(canvas, origin, Rect2(head + Vector2(5, 2), Vector2(1, 1)), WHITE, direction)
		_box(canvas, origin, Rect2(torso.position + Vector2(1, 1), Vector2(1, 2)), accent, direction)
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
	result.position = (result.position + origin).round()
	canvas.draw_rect(result, color)


static func _limb(canvas: CanvasItem, origin: Vector2, start: Vector2, end: Vector2, color: Color, direction: int, width: int = 2) -> void:
	var length: int = maxi(1, int(ceilf(maxf(absf(end.x - start.x), absf(end.y - start.y)))))
	for index in range(length + 1):
		var point: Vector2 = start.lerp(end, float(index) / float(length)).round()
		_box(canvas, origin, Rect2(point - Vector2.ONE, Vector2(width, width)), color, direction)
