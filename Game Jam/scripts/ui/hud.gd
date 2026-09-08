extends Node2D
const DrawText = preload("res://scripts/ui/draw_text.gd")
const INK := Color("0d1013")
const WHITE := Color("f8f8f2")
const CYAN := Color("61e7ff")
const PINK := Color("ff5fcb")
const RED := Color("ff5a67")
const GOLD := Color("ffd15c")
const MUTED := Color("a6b3bf")

var game: Node2D

func _draw() -> void:
	if game.state in ["menu", "story"]:
		return
	draw_rect(Rect2(0, 0, 320, 28), INK)
	draw_line(Vector2(8, 27), Vector2(312, 27), Color("263740"))
	DrawText.text(self, Vector2(8, 9), "REMAINING", 8, MUTED)
	DrawText.text(self, Vector2(8, 24), DrawText.timer(game.remaining), 14, RED if game.remaining < 5.0 else WHITE)
	DrawText.text(self, Vector2(109, 10), "%02d / 04" % (game.level_index + 1), 8, GOLD)
	DrawText.text(self, Vector2(109, 23), String(game.data.title), 9, WHITE)
	DrawText.text(self, Vector2(247, 10), "TIME FROZEN" if game.frozen else "TIME MOVING", 9, CYAN if game.frozen else WHITE)
	DrawText.text(self, Vector2(247, 23), "DASH", 8, MUTED)
	for i in range(2):
		var rect := Rect2(273 + i * 19, 16, 15, 6)
		draw_rect(rect, CYAN if i < game.player.dash_charges else MUTED, i < game.player.dash_charges)
		if i < game.player.dash_charges:
			draw_line(rect.position + Vector2(5, 1), rect.position + Vector2(8, 3), INK)
			draw_line(rect.position + Vector2(8, 3), rect.position + Vector2(5, 5), INK)
	draw_rect(Rect2(0, 164, 320, 16), INK)
	draw_line(Vector2(8, 164), Vector2(312, 164), Color("263740"))
	_draw_epoch_icon(Vector2(12, 172))
	DrawText.text(self, Vector2(21, 175), String(game.data.epoch).to_upper(), 8, CYAN)
	DrawText.text(self, Vector2(145, 175), "R RETRY", 8, MUTED)
	DrawText.text(self, Vector2(196, 175), "X FOCUS", 8, MUTED)
	DrawText.text(self, Vector2(253, 175), "ESC PAUSE", 8, MUTED)
	var progress: float = game.route_progress()
	draw_line(Vector2(8, 162), Vector2(8 + 304 * progress, 162), CYAN)
	var notice_y: float = 54.0
	if game.intro_left > 0.0 and game.state == "playing" and not game.paused:
		notice_y = maxf(notice_y, _instruction(33, String(game.data.hint)) + 4)
	if game.dash_flash > 0.0:
		DrawText.text(self, Vector2(79, 21), "-2s", 8, PINK)
	if game.field_multiplier != 1.0:
		DrawText.text(self, Vector2(214, 22), "x%.1f" % game.field_multiplier, 7, CYAN if game.field_multiplier < 1.0 else GOLD)
	elif game.player.extra_jumps > 0:
		draw_rect(Rect2(228, 17, 3, 3), CYAN)
	if game.anchor_flash > 0.0:
		notice_y = _instruction(notice_y, "ANCHOR SET / DASHES RESTORED", CYAN) + 4
		draw_rect(Rect2(0, 28, 320, 136), Color(CYAN, game.anchor_flash * 0.035))
	if game.death_flash > 0.0:
		draw_rect(Rect2(0, 28, 320, 136), Color(RED, game.death_flash * 0.18))
		_instruction(notice_y, game.death_reason, RED)
		for i in range(9):
			var direction := Vector2(cos(float(i) * TAU / 9), sin(float(i) * TAU / 9))
			var p: Vector2 = game.death_screen_position + Vector2(0, -7) + direction * (1.0 - game.death_flash) * 30.0
			draw_rect(Rect2(p.round(), Vector2(2, 2)), Color(WHITE if i % 3 == 0 else RED, game.death_flash))
	if is_instance_valid(game.dragon) and game.dragon.active:
		draw_rect(Rect2(53, 29, 214, 23), Color(INK, 0.95))
		DrawText.center(self, 38, "PYRAX / THE LAST FLAME / II" if game.dragon.phase == 2 else "PYRAX / THE LAST FLAME / I", 8, GOLD)
		for n in range(8):
			draw_rect(Rect2(85 + n * 19, 41, 16, 3), RED if n < game.dragon.health else Color("30333d"))
		var cue: String = _boss_cue(game.dragon)
		draw_rect(Rect2(0, 165, 320, 15), INK)
		DrawText.center(self, 175, cue, 8, CYAN if game.dragon.state == "recover" else GOLD)
	if game.paused:
		_panel("PAUSED", "SPACE: JUMP x2 / WALL + JUMP\nDOWN + SHIFT: STRIKE / J: MELEE", "ENTER / ESC  RESUME", CYAN)
		DrawText.center(self, 149, "HOLD X IN AIR TO FREEZE AND PLAN", 9, CYAN)
	elif game.state == "clear":
		_panel("TIMELINE RESTORED", "%s  /  %.2fs active" % [String(game.data.title), game.level_world], "ENTER / ESPACIO  REPETIR NIVEL", GOLD)
	elif game.state == "complete":
		_draw_completion()

## The two attack-dependent lines come from the pattern itself, so the HUD never
## indexes an array by an attack number it would have to keep in sync.
func _boss_cue(dragon: Node2D) -> String:
	match dragon.state:
		"prepare": return "READ THE DRAGON / MOVE TO ADVANCE"
		"warning": return dragon.pattern().warning_cue()
		"attack": return dragon.pattern().attack_cue()
		"recover": return "OPEN HEAD: J STRIKE / CYAN CELL REFILLS"
		"transition": return "PHASE II / THE FURNACE AWAKENS"
		"defeat": return "THE LAST FLAME FALLS"
	return ""


func _instruction(y: float, value: String, color: Color = GOLD) -> float:
	var paragraph := DrawText.paragraph(value, 284)
	paragraph.alignment = HORIZONTAL_ALIGNMENT_CENTER
	var height: float = paragraph.get_size().y + 8
	draw_rect(Rect2(10, y, 300, height), Color(INK, 0.96))
	paragraph.draw(get_canvas_item(), Vector2(18, y + 4), color)
	return y + height

func _draw_epoch_icon(p: Vector2) -> void:
	if game.chapter_index == 0:
		draw_polyline(PackedVector2Array([p + Vector2(-5, 4), p + Vector2(0, -5), p + Vector2(5, 4), p + Vector2(-5, 4)]), CYAN)
	elif game.chapter_index == 1:
		draw_rect(Rect2(p + Vector2(-5, -5), Vector2(10, 2)), CYAN)
		for x in [-3, 3]:
			draw_line(p + Vector2(x, -2), p + Vector2(x, 4), CYAN)
	elif game.chapter_index == 2:
		draw_rect(Rect2(p + Vector2(-4, -4), Vector2(8, 8)), GOLD, false)
		draw_rect(Rect2(p + Vector2(-1, -1), Vector2(2, 2)), CYAN)
	else:
		draw_line(p + Vector2(-4, -4), p + Vector2(1, 1), PINK, 2)
		draw_line(p + Vector2(4, -4), p + Vector2(-1, 4), CYAN, 2)

func _panel(title: String, detail: String, prompt: String, color: Color) -> void:
	draw_rect(Rect2(0, 28, 320, 136), Color(INK, 0.85))
	var paragraph := DrawText.paragraph(detail, 264)
	paragraph.alignment = HORIZONTAL_ALIGNMENT_CENTER
	var prompt_y: float = 92 + paragraph.get_size().y + 15
	draw_rect(Rect2(20, 57, 280, prompt_y - 57 + 9), INK)
	draw_line(Vector2(20, 57), Vector2(300, 57), color)
	DrawText.center(self, 80, title, 15, color)
	paragraph.draw(get_canvas_item(), Vector2(28, 92), WHITE)
	DrawText.center(self, prompt_y, prompt, 9, GOLD)

func _draw_completion() -> void:
	draw_rect(Rect2(0, 0, 320, 180), INK)
	draw_line(Vector2(20, 15), Vector2(300, 15), CYAN)
	DrawText.center(self, 32, "THE LAST FLAME IS STILL", 13, WHITE)
	DrawText.center(self, 46, "And for a moment, time belonged to you.", 9, CYAN)
	var par_time: float = game.total_par_time()
	var rank: String = "S / THE STILL POINT" if game.total_world <= par_time and game.total_deaths == 0 else ("A / TIME TRAVELER" if game.total_world <= par_time * 1.5 and game.total_deaths < 10 else "B / NEVER STOP TRYING")
	DrawText.center(self, 64, rank, 10, GOLD)
	var labels: Array[String] = ["WORLD TIME CONSUMED", "REAL TIME", "DISTANCE TRAVELED", "TOTAL DEATHS", "DASHES / TIME PAID"]
	var values: Array[String] = ["%.2f s" % game.total_world, DrawText.timer(game.total_real), "%.1f m" % (game.total_distance / 16.0), str(game.total_deaths), "%d / %.0fs" % [game.total_dashes, game.total_dash_cost]]
	for i in range(labels.size()):
		var y: float = 83 + i * 13
		DrawText.text(self, Vector2(40, y), labels[i], 9, MUTED)
		var value_width: float = ThemeDB.fallback_font.get_string_size(values[i], HORIZONTAL_ALIGNMENT_LEFT, -1, 9).x
		DrawText.text(self, Vector2(280 - value_width, y), values[i], 9, WHITE)
	draw_line(Vector2(51, 142), Vector2(269, 142), Color("263740"))
	DrawText.center(self, 158, "PRESS ENTER TO REPLAY", 10, GOLD)
	DrawText.center(self, 173, "STILL//MOVING    /    CHRONOPHOBIA", 8, CYAN)
