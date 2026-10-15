class_name Menu
extends CanvasLayer
## Title screen, pause menu, options and game over. Works with touch, mouse and gamepad
## (buttons take focus so the D-pad / stick and A navigate).

signal play_pressed
signal resume_pressed
signal quit_to_title
signal restart_pressed

var _root: Control
var _title: Control
var _pause: Control
var _options: Control
var _over: Control
var _over_title: Label
var _over_stats: Label
var _best: Label
var _options_back_to: Control
var _theme: Theme


func _ready() -> void:
	layer = 20
	process_mode = Node.PROCESS_MODE_ALWAYS
	_theme = _make_theme()
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.theme = _theme
	add_child(_root)
	_title = _build_title()
	_pause = _build_pause()
	_options = _build_options()
	_over = _build_over()
	hide_all()


func _make_theme() -> Theme:
	var t := Theme.new()
	t.default_font_size = 30
	var normal := StyleBoxFlat.new()
	normal.bg_color = Color(0.08, 0.06, 0.06, 0.85)
	normal.border_color = Color(0.45, 0.1, 0.08)
	normal.set_border_width_all(2)
	normal.set_corner_radius_all(6)
	normal.content_margin_left = 24
	normal.content_margin_right = 24
	normal.content_margin_top = 10
	normal.content_margin_bottom = 10
	var hover := normal.duplicate() as StyleBoxFlat
	hover.bg_color = Color(0.25, 0.05, 0.04, 0.95)
	hover.border_color = Color(0.95, 0.25, 0.2)
	var pressed := hover.duplicate() as StyleBoxFlat
	pressed.bg_color = Color(0.4, 0.06, 0.05, 1)
	t.set_stylebox("normal", "Button", normal)
	t.set_stylebox("hover", "Button", hover)
	t.set_stylebox("focus", "Button", hover)
	t.set_stylebox("pressed", "Button", pressed)
	t.set_color("font_color", "Button", Color(0.92, 0.9, 0.86))
	t.set_color("font_hover_color", "Button", Color(1, 1, 1))
	t.set_color("font_focus_color", "Button", Color(1, 1, 1))
	t.set_font_size("font_size", "Button", 30)
	t.set_font_size("font_size", "Label", 26)
	t.set_font_size("font_size", "CheckButton", 26)
	t.set_font_size("font_size", "OptionButton", 26)
	t.set_stylebox("normal", "OptionButton", normal)
	t.set_stylebox("hover", "OptionButton", hover)
	t.set_stylebox("focus", "OptionButton", hover)
	t.set_stylebox("pressed", "OptionButton", pressed)
	var panel := StyleBoxFlat.new()
	panel.bg_color = Color(0.03, 0.02, 0.02, 0.88)
	panel.border_color = Color(0.4, 0.08, 0.06)
	panel.set_border_width_all(2)
	panel.set_corner_radius_all(10)
	panel.content_margin_left = 36
	panel.content_margin_right = 36
	panel.content_margin_top = 28
	panel.content_margin_bottom = 28
	t.set_stylebox("panel", "PanelContainer", panel)
	return t


func _screen(dim := 0.55) -> Control:
	var c := Control.new()
	c.set_anchors_preset(Control.PRESET_FULL_RECT)
	var bg := ColorRect.new()
	bg.color = Color(0, 0, 0, dim)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	c.add_child(bg)
	_root.add_child(c)
	return c


func _center_box(parent: Control) -> VBoxContainer:
	var cc := CenterContainer.new()
	cc.set_anchors_preset(Control.PRESET_FULL_RECT)
	parent.add_child(cc)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 14)
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	cc.add_child(v)
	return v


func _big_label(parent: Control, text: String, size: int, color: Color) -> Label:
	var l := Label.new()
	l.text = text
	var s := LabelSettings.new()
	s.font_size = size
	s.font_color = color
	s.outline_size = 12
	s.outline_color = Color(0, 0, 0)
	l.label_settings = s
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	parent.add_child(l)
	return l


func _button(parent: Control, text: String, cb: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(380, 64)
	b.pressed.connect(cb)
	parent.add_child(b)
	return b


func _build_title() -> Control:
	var s := _screen(0.35)
	var v := _center_box(s)
	_big_label(v, "DERNIÈRE VAGUE", 96, Color(0.85, 0.08, 0.05))
	_big_label(v, "Survivez aux vagues de morts-vivants", 28, Color(0.85, 0.82, 0.78))
	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, 24)
	v.add_child(spacer)
	var play := _button(v, "Jouer", func(): play_pressed.emit())
	play.name = "Play"
	_button(v, "Options", func(): _open_options(_title))
	if not OS.has_feature("mobile"):
		_button(v, "Quitter", func(): get_tree().quit())
	_best = _big_label(v, "", 24, Color(1, 0.85, 0.4))
	return s


func _build_pause() -> Control:
	var s := _screen(0.6)
	var v := _center_box(s)
	_big_label(v, "PAUSE", 72, Color(0.9, 0.9, 0.88))
	var r := _button(v, "Reprendre", func(): resume_pressed.emit())
	r.name = "Resume"
	_button(v, "Options", func(): _open_options(_pause))
	_button(v, "Abandonner", func(): quit_to_title.emit())
	return s


func _build_over() -> Control:
	var s := _screen(0.7)
	var v := _center_box(s)
	_over_title = _big_label(v, "", 64, Color(0.85, 0.08, 0.05))
	_over_stats = _big_label(v, "", 28, Color(0.9, 0.88, 0.84))
	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, 20)
	v.add_child(spacer)
	var again := _button(v, "Rejouer", func(): restart_pressed.emit())
	again.name = "Again"
	_button(v, "Menu principal", func(): quit_to_title.emit())
	return s


func _build_options() -> Control:
	var s := _screen(0.75)
	var cc := CenterContainer.new()
	cc.set_anchors_preset(Control.PRESET_FULL_RECT)
	s.add_child(cc)
	var panel := PanelContainer.new()
	cc.add_child(panel)
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(760, 560)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	panel.add_child(scroll)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 12)
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(v)
	_big_label(v, "OPTIONS", 48, Color(0.9, 0.9, 0.88))
	_slider(v, "Sensibilité souris", "sens_mouse", 0.03, 0.5, 0.01)
	_slider(v, "Sensibilité manette", "sens_pad", 0.3, 2.5, 0.05)
	_slider(v, "Sensibilité tactile", "sens_touch", 0.3, 2.5, 0.05)
	_slider(v, "Volume", "volume", 0.0, 1.0, 0.05)
	_check(v, "Assistance à la visée (manette / tactile)", "aim_assist")
	_check(v, "Inverser l'axe vertical", "invert_y")
	_check(v, "Vibrations de la manette", "vibration")
	_check(v, "Afficher les images par seconde", "show_fps")
	_choice(v, "Images par seconde max.", "max_fps", [[60, "60"], [90, "90"], [120, "120"]])
	_choice(v, "Résolution 3D", "render_scale", [[1.0, "100 %"], [0.85, "85 %"], [0.75, "75 %"], [0.6, "60 %"], [0.5, "50 %"]])
	var back := _button(v, "Retour", _close_options)
	back.name = "Back"
	back.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	return s


func _row(parent: Control, text: String) -> HBoxContainer:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 16)
	parent.add_child(h)
	var l := Label.new()
	l.text = text
	l.custom_minimum_size = Vector2(380, 0)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	h.add_child(l)
	return h


func _slider(parent: Control, text: String, key: String, lo: float, hi: float, step: float) -> void:
	var h := _row(parent, text)
	var sl := HSlider.new()
	sl.min_value = lo
	sl.max_value = hi
	sl.step = step
	sl.value = float(G.settings[key])
	sl.custom_minimum_size = Vector2(300, 40)
	sl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sl.value_changed.connect(func(val):
		G.settings[key] = val
		G.apply_settings())
	h.add_child(sl)


func _check(parent: Control, text: String, key: String) -> void:
	var c := CheckButton.new()
	c.text = text
	c.button_pressed = bool(G.settings[key])
	c.toggled.connect(func(on):
		G.settings[key] = on
		G.apply_settings())
	parent.add_child(c)


func _choice(parent: Control, text: String, key: String, values: Array) -> void:
	var h := _row(parent, text)
	var ob := OptionButton.new()
	for i in values.size():
		ob.add_item(values[i][1], i)
		if is_equal_approx(float(values[i][0]), float(G.settings[key])):
			ob.select(i)
	ob.item_selected.connect(func(i):
		G.settings[key] = values[i][0]
		G.apply_settings())
	h.add_child(ob)


func hide_all() -> void:
	for c in [_title, _pause, _options, _over]:
		c.visible = false


func show_title() -> void:
	hide_all()
	_best.text = ("Record : manche %d" % G.best_round) if G.best_round > 0 else ""
	_title.visible = true
	_focus(_title.find_child("Play", true, false))


func show_pause() -> void:
	hide_all()
	_pause.visible = true
	_focus(_pause.find_child("Resume", true, false))


func show_game_over(rounds: int, best: bool) -> void:
	hide_all()
	_over_title.text = "VOUS AVEZ SURVÉCU %d MANCHE%s" % [rounds, "S" if rounds > 1 else ""]
	var lines := "Zombies éliminés : %d\nTirs à la tête : %d\nPoints gagnés : %d" % [G.kills, G.headshots, G.total_points]
	if best:
		lines += "\n\nNOUVEAU RECORD !"
	_over_stats.text = lines
	_over.visible = true
	_focus(_over.find_child("Again", true, false))


func _open_options(from: Control) -> void:
	_options_back_to = from
	hide_all()
	_options.visible = true
	_focus(_options.find_child("Back", true, false))


func _close_options() -> void:
	G.save_settings()
	hide_all()
	if _options_back_to:
		_options_back_to.visible = true
		var first := _options_back_to.find_child("Play", true, false)
		if first == null:
			first = _options_back_to.find_child("Resume", true, false)
		_focus(first)


func _focus(c: Node) -> void:
	if c is Control and G.input_mode == "pad":
		(c as Control).grab_focus.call_deferred()


func _input(event: InputEvent) -> void:
	# First gamepad press in a menu: give focus to its first button.
	if not is_open():
		return
	if (event is InputEventJoypadButton and event.pressed) or (event is InputEventJoypadMotion and abs(event.axis_value) > 0.5):
		if get_viewport().gui_get_focus_owner() == null:
			for screen in [_title, _pause, _options, _over]:
				if screen.visible:
					for name in ["Play", "Resume", "Again", "Back"]:
						var b: Node = screen.find_child(name, true, false)
						if b:
							(b as Control).grab_focus()
							get_viewport().set_input_as_handled()
							return


func is_open() -> bool:
	return _title.visible or _pause.visible or _options.visible or _over.visible


func options_open() -> bool:
	return _options.visible
