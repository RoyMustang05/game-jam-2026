extends RefCounted
## Crisp-text drawing helpers shared by the menu screen, HUD and world labels.
const WHITE := Color("f8f8f2")

static func text(canvas: CanvasItem, pos: Vector2, value: String, size: int = 8, color: Color = WHITE) -> void:
	canvas.draw_string(ThemeDB.fallback_font, pos, value, HORIZONTAL_ALIGNMENT_LEFT, -1, size, color)

static func center(canvas: CanvasItem, y: float, value: String, size: int = 8, color: Color = WHITE) -> void:
	var length: float = ThemeDB.fallback_font.get_string_size(value, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
	text(canvas, Vector2(roundf((320.0 - length) / 2.0), y), value, size, color)

static func paragraph(value: String, width: float, size: int = 9) -> TextParagraph:
	var result := TextParagraph.new()
	result.add_string(value, ThemeDB.fallback_font, size)
	result.width = width
	result.break_flags = TextServer.BREAK_MANDATORY | TextServer.BREAK_WORD_BOUND | TextServer.BREAK_ADAPTIVE
	return result

static func timer(value: float) -> String:
	var centis: int = maxi(0, int(ceil(value * 100.0)))
	return "%02d:%02d.%02d" % [centis / 6000, (centis / 100) % 60, centis % 100]
