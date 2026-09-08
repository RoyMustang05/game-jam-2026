extends Node2D
const DrawText = preload("res://scripts/ui/draw_text.gd")
const INK := Color("0d1013")
const WHITE := Color("f8f8f2")
const CYAN := Color("61e7ff")
const PINK := Color("ff5fcb")
const MUTED := Color("a6b3bf")
const GOLD := Color("ffd15c")

var game: Node2D
var buttons: Control
var editor_panel: PanelContainer
var level_choice: OptionButton
var editor_message: Label

func _ready() -> void:
	buttons = Control.new()
	add_child(buttons)
	var play := _button("Jugar", Vector2(15, 137), Vector2(86, 20))
	play.pressed.connect(game.start_new_game)
	var editor := _button("Editor de niveles", Vector2(107, 137), Vector2(148, 20))
	editor.pressed.connect(_show_editor)
	play.focus_neighbor_right = editor.get_path()
	play.focus_neighbor_bottom = editor.get_path()
	editor.focus_neighbor_left = play.get_path()
	editor.focus_neighbor_top = play.get_path()
	play.grab_focus.call_deferred()
	_build_editor_panel()

func _process(_delta: float) -> void:
	buttons.visible = game.state == "menu"
	if game.state != "menu":
		editor_panel.hide()

func _button(label: String, pos: Vector2, dimensions: Vector2) -> Button:
	var button := Button.new()
	button.text = label
	button.position = pos
	button.add_theme_font_size_override("font_size", 9)
	for style: String in ["normal", "hover", "pressed", "focus"]:
		var box := StyleBoxFlat.new()
		box.bg_color = Color("19313e") if style in ["hover", "focus"] else INK
		box.border_color = GOLD if style == "focus" else CYAN
		box.set_border_width_all(1)
		box.set_content_margin_all(3)
		button.add_theme_stylebox_override(style, box)
	button.size = dimensions
	buttons.add_child(button)
	button.set_deferred("size", dimensions)
	return button

func _build_editor_panel() -> void:
	editor_panel = PanelContainer.new()
	editor_panel.position = Vector2(16, 15)
	editor_panel.size = Vector2(288, 150)
	var style := StyleBoxFlat.new()
	style.bg_color = INK
	style.border_color = CYAN
	style.set_border_width_all(1)
	style.set_content_margin_all(9)
	editor_panel.add_theme_stylebox_override("panel", style)
	var panel_theme := Theme.new()
	panel_theme.default_font_size = 8
	editor_panel.theme = panel_theme
	add_child(editor_panel)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 5)
	editor_panel.add_child(column)
	var title := Label.new()
	title.text = "EDITOR DE NIVELES"
	title.add_theme_font_size_override("font_size", 12)
	column.add_child(title)
	level_choice = OptionButton.new()
	for label: String in ["01 · Prehistoria", "02 · Antigüedad", "03 · Industrial", "04 · Futuro colapsado"]:
		level_choice.add_item(label)
	column.add_child(level_choice)
	editor_message = Label.new()
	editor_message.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	editor_message.custom_minimum_size = Vector2(268, 46)
	editor_message.text = "Elige un nivel para abrir su escena en Godot.\nFloors: pintar terreno. Assets: arrastrar objetos.\nCtrl+S: guardar · F6: probar · F8: detener."
	column.add_child(editor_message)
	var row := HBoxContainer.new()
	column.add_child(row)
	var open := Button.new()
	open.text = "Abrir en Godot"
	open.pressed.connect(open_selected_level)
	row.add_child(open)
	var back := Button.new()
	back.text = "Volver al menú"
	back.pressed.connect(_close_editor)
	row.add_child(back)
	editor_panel.hide()

func _show_editor() -> void:
	for child in buttons.get_children():
		child.disabled = true
	editor_panel.show()
	level_choice.grab_focus()

func _close_editor() -> void:
	editor_panel.hide()
	for child in buttons.get_children():
		child.disabled = false
	buttons.get_child(1).grab_focus()

func _input(event: InputEvent) -> void:
	if game.state != "menu":
		return
	if event is InputEventKey and event.echo:
		return
	if not editor_panel.visible and event.is_action_pressed("confirm"):
		var focused: Control = get_viewport().gui_get_focus_owner()
		if focused == buttons.get_child(1):
			_show_editor()
		else:
			game.start_new_game()
		get_viewport().set_input_as_handled()
		return
	if editor_panel.visible and event.is_action_pressed("pause_game"):
		_close_editor()
		get_viewport().set_input_as_handled()

func editor_launch_spec() -> Dictionary:
	# In a source run the running executable IS the installed Godot editor.
	# Export templates cannot service --editor, even if named Godot.
	var project: String = ProjectSettings.globalize_path("res://")
	var executable: String = OS.get_executable_path()
	if not OS.has_feature("editor") or not FileAccess.file_exists(project.path_join("project.godot")) or not FileAccess.file_exists(executable):
		return {}
	return {"executable": executable, "args": PackedStringArray(["--editor", "--path", project, "res://rooms/room_%02d.tscn" % (level_choice.selected + 1)])}

func open_selected_level() -> int:
	var spec: Dictionary = editor_launch_spec()
	var pid: int = -1
	if not spec.is_empty():
		pid = OS.create_process(spec.executable, spec.args)
	if pid < 0:
		editor_message.text = "Para editar, abre este proyecto en Godot y elige rooms/room_%02d.tscn. Esta ejecución no puede abrir el editor. Ctrl+S guarda y F6 prueba." % (level_choice.selected + 1)
	else:
		editor_message.text = "Escena abierta en Godot. Ctrl+S guarda, F6 prueba y F8 detiene. Regresa a esta ventana y pulsa Volver al menú para jugar."
	return pid

func _draw() -> void:
	if game.state != "menu":
		return
	draw_rect(Rect2(0, 0, 320, 180), INK)
	for x in range(0, 320, 16):
		draw_line(Vector2(x, 0), Vector2(x, 180), Color("131a20"))
	for y in range(0, 180, 16):
		draw_line(Vector2(0, y), Vector2(320, y), Color("131a20"))
	var origin := Vector2(253, 81)
	for n in range(12):
		var a: float = float(n) * TAU / 12.0 - PI / 2.0
		var direction := Vector2(cos(a), sin(a))
		draw_line((origin + direction * 49.0).round(), (origin + direction * 53.0).round(), CYAN if n % 3 == 0 else Color("354653"), 2)
	draw_arc(origin, 43, 0.3, 3.0, 18, Color("314650"), 1)
	draw_arc(origin + Vector2(3, -3), 43, 3.5, 5.9, 16, PINK, 1)
	draw_line(origin, origin + Vector2(0, -30), WHITE, 2)
	draw_line(origin, origin + Vector2(22, 12), CYAN, 2)
	draw_rect(Rect2(origin - Vector2(2, 2), Vector2(4, 4)), PINK)
	draw_rect(Rect2(15, 18, 4, 4), CYAN)
	DrawText.text(self, Vector2(24, 23), "CHRONOPHOBIA / CUATRO ERAS FRACTURADAS", 8, MUTED)
	DrawText.text(self, Vector2(14, 65), "STILL", 31)
	DrawText.text(self, Vector2(91, 64), "//", 31, CYAN)
	DrawText.text(self, Vector2(14, 93), "MOVING", 31)
	draw_rect(Rect2(15, 102, 28, 2), PINK)
	DrawText.text(self, Vector2(15, 116), "EL TIEMPO NO TE PERTENECE.", 9, CYAN)
	DrawText.text(self, Vector2(15, 130), "Muévete para crear tiempo. Detente para sobrevivir.", 9)
	draw_line(Vector2(15, 160), Vector2(305, 160), Color("2a3540"))
	DrawText.text(self, Vector2(15, 172), "A/D MOVER   ESPACIO SALTAR   SHIFT DASH   X FOCUS   J GOLPE", 8, MUTED)
	DrawText.text(self, Vector2(278, 151), "01 / 04", 7, CYAN)
