class_name Menu
extends CanvasLayer
## Title screen, pause menu, options and game over. Works with touch, mouse and gamepad
## (buttons take focus so the D-pad / stick and A navigate).

signal play_pressed
signal resume_pressed
signal quit_to_title
signal restart_pressed
signal continue_pressed
signal save_quit_pressed
signal abandon_pressed

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
var _pad_info: Label
var _lobby: Control
var _lobby_level: Label
var _lobby_xp: ProgressBar
var _lobby_xp_text: Label
var _lobby_maps: HBoxContainer
var _lobby_weapons: GridContainer
var _weapon_preview: LobbyVisuals.WeaponPreview
var _weapon_name: Label
var _weapon_note: Label
var _stat_bars := {}
var _map_preview: LobbyVisuals.MapPreview
var _map_plan: LobbyVisuals.MapPlan
var _map_name: Label
var _map_desc: Label
## The level behind the menus (for the map plan), set by main.
var level: Node
var _continue: Button


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
	_lobby = _build_lobby()
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
	_continue = _button(v, "Continuer", func(): continue_pressed.emit())
	_continue.name = "Continue"
	var play := _button(v, "Nouvelle partie", show_lobby)
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
	_button(v, "Sauvegarder et quitter", func(): save_quit_pressed.emit())
	_button(v, "Abandonner la partie", func(): abandon_pressed.emit())
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


## Lobby: player level, the map (live view + plan) and the starting weapon (turning 3D
## preview, stats, cards unlocked by level), then start.
func _build_lobby() -> Control:
	var s := _screen(0.65)
	var cc := CenterContainer.new()
	cc.set_anchors_preset(Control.PRESET_FULL_RECT)
	s.add_child(cc)
	var panel := PanelContainer.new()
	cc.add_child(panel)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
	panel.add_child(v)

	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 18)
	v.add_child(top)
	var title := _big_label(top, "PRÉPARATION", 40, Color(0.9, 0.9, 0.88))
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	_lobby_level = Label.new()
	_lobby_level.add_theme_font_size_override("font_size", 28)
	_lobby_level.add_theme_color_override("font_color", Color(1, 0.85, 0.35))
	top.add_child(_lobby_level)
	_lobby_xp = ProgressBar.new()
	_lobby_xp.custom_minimum_size = Vector2(300, 20)
	_lobby_xp.show_percentage = false
	_lobby_xp.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_lobby_xp.add_theme_stylebox_override("fill", _flat(Color(0.85, 0.15, 0.08)))
	_lobby_xp.add_theme_stylebox_override("background", _flat(Color(0.15, 0.1, 0.1)))
	top.add_child(_lobby_xp)
	_lobby_xp_text = Label.new()
	_lobby_xp_text.add_theme_font_size_override("font_size", 18)
	top.add_child(_lobby_xp_text)

	var cols := HBoxContainer.new()
	cols.add_theme_constant_override("separation", 24)
	v.add_child(cols)

	# Map column.
	var mc := VBoxContainer.new()
	mc.add_theme_constant_override("separation", 6)
	cols.add_child(mc)
	_section(mc, "CARTE")
	_map_preview = LobbyVisuals.MapPreview.new(Vector2i(520, 150))
	mc.add_child(_map_preview)
	var map_row := HBoxContainer.new()
	map_row.add_theme_constant_override("separation", 12)
	mc.add_child(map_row)
	_map_name = Label.new()
	_map_name.add_theme_font_size_override("font_size", 24)
	_map_name.add_theme_color_override("font_color", Color(1, 0.9, 0.8))
	map_row.add_child(_map_name)
	_map_desc = Label.new()
	_map_desc.add_theme_font_size_override("font_size", 15)
	_map_desc.add_theme_color_override("font_color", Color(0.75, 0.72, 0.7))
	_map_desc.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	map_row.add_child(_map_desc)
	_map_plan = LobbyVisuals.MapPlan.new(Vector2(520, 228))
	mc.add_child(_map_plan)
	_lobby_maps = HBoxContainer.new()
	_lobby_maps.add_theme_constant_override("separation", 8)
	mc.add_child(_lobby_maps)

	# Weapon column.
	var wc := VBoxContainer.new()
	wc.add_theme_constant_override("separation", 6)
	cols.add_child(wc)
	_section(wc, "ARME DE DÉPART")
	_weapon_preview = LobbyVisuals.WeaponPreview.new(Vector2i(560, 170))
	wc.add_child(_weapon_preview)
	var name_row := HBoxContainer.new()
	wc.add_child(name_row)
	_weapon_name = Label.new()
	_weapon_name.add_theme_font_size_override("font_size", 26)
	_weapon_name.add_theme_color_override("font_color", Color(1, 0.9, 0.8))
	_weapon_name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_row.add_child(_weapon_name)
	_weapon_note = Label.new()
	_weapon_note.add_theme_font_size_override("font_size", 16)
	_weapon_note.add_theme_color_override("font_color", Color(1, 0.55, 0.4))
	name_row.add_child(_weapon_note)
	var stats := GridContainer.new()
	stats.columns = 4
	stats.add_theme_constant_override("h_separation", 10)
	stats.add_theme_constant_override("v_separation", 2)
	wc.add_child(stats)
	for pair in [["dmg", "Dégâts"], ["rate", "Cadence"], ["acc", "Précision"], ["mag", "Chargeur"]]:
		var l := Label.new()
		l.text = pair[1]
		l.add_theme_font_size_override("font_size", 15)
		l.custom_minimum_size = Vector2(80, 0)
		stats.add_child(l)
		var bar := ProgressBar.new()
		bar.max_value = 1.0
		bar.step = 0.01
		bar.show_percentage = false
		bar.custom_minimum_size = Vector2(170, 12)
		bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		bar.add_theme_stylebox_override("fill", _flat(Color(0.9, 0.8, 0.6)))
		bar.add_theme_stylebox_override("background", _flat(Color(0.18, 0.15, 0.14)))
		stats.add_child(bar)
		_stat_bars[pair[0]] = bar
	_lobby_weapons = GridContainer.new()
	_lobby_weapons.columns = 4
	_lobby_weapons.add_theme_constant_override("h_separation", 8)
	_lobby_weapons.add_theme_constant_override("v_separation", 8)
	wc.add_child(_lobby_weapons)

	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 20)
	v.add_child(row)
	var go := _button(row, "Lancer la partie", func(): play_pressed.emit())
	go.name = "Go"
	_button(row, "Retour", show_title)
	return s


func _flat(c: Color) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = c
	sb.set_corner_radius_all(4)
	return sb


func _section(parent: Control, text: String) -> void:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", 18)
	l.add_theme_color_override("font_color", Color(0.9, 0.3, 0.25))
	parent.add_child(l)


func _small_button(parent: Control, text: String, cb: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(250, 40)
	b.add_theme_font_size_override("font_size", 18)
	b.pressed.connect(cb)
	parent.add_child(b)
	return b


func _show_weapon_info(id: String, unlocked: bool, need: int) -> void:
	_weapon_preview.show_weapon(id)
	_weapon_preview.modulate = Color(1, 1, 1) if unlocked else Color(0.25, 0.25, 0.25)
	_weapon_name.text = G.WEAPONS[id].name
	_weapon_note.text = "" if unlocked else "Débloquée au niveau %d" % need
	var r := LobbyVisuals.ratings(id)
	for k in _stat_bars:
		var bar: ProgressBar = _stat_bars[k]
		var tw := bar.create_tween()
		tw.tween_property(bar, "value", float(r[k]), 0.25)


func show_lobby() -> void:
	hide_all()
	var lv := G.level()
	var lo := G.xp_for_level(lv)
	var hi := G.xp_for_level(lv + 1)
	_lobby_level.text = "Niveau %d" % lv
	_lobby_xp.min_value = lo
	_lobby_xp.max_value = hi
	_lobby_xp.value = G.xp
	_lobby_xp_text.text = "%d / %d XP" % [G.xp, hi]
	_map_plan.level = level
	_map_plan.queue_redraw()
	_map_name.text = G.MAPS[G.map_id].name
	_map_desc.text = G.MAPS[G.map_id].desc
	for c in _lobby_maps.get_children():
		c.queue_free()
	for c in _lobby_weapons.get_children():
		c.queue_free()
	var map_group := ButtonGroup.new()
	for id in G.MAPS:
		var b := _small_button(_lobby_maps, G.MAPS[id].name, func():
			G.map_id = id
			_map_name.text = G.MAPS[id].name
			_map_desc.text = G.MAPS[id].desc)
		b.toggle_mode = true
		b.button_group = map_group
		b.button_pressed = id == G.map_id
	var soon := _small_button(_lobby_maps, "Nouvelle carte — bientôt", func(): pass)
	soon.disabled = true
	var weapon_group := ButtonGroup.new()
	for pair in G.START_WEAPONS:
		var id: String = pair[0]
		var need: int = pair[1]
		var unlocked := lv >= need
		var b := Button.new()
		b.custom_minimum_size = Vector2(134, 74)
		b.add_theme_font_size_override("font_size", 15)
		b.text = LobbyVisuals.short_name(id) if unlocked else "Niv. %d" % need
		b.icon = LobbyVisuals.weapon_icon(b, id, Vector2i(240, 90))
		b.expand_icon = true
		b.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
		b.vertical_icon_alignment = VERTICAL_ALIGNMENT_TOP
		if unlocked:
			b.toggle_mode = true
			b.button_group = weapon_group
			b.button_pressed = id == G.start_weapon
			b.pressed.connect(func():
				G.start_weapon = id
				_show_weapon_info(id, true, need))
		else:
			b.add_theme_color_override("icon_normal_color", Color(0.08, 0.08, 0.08))
			b.add_theme_color_override("icon_hover_color", Color(0.15, 0.15, 0.15))
			b.add_theme_color_override("icon_focus_color", Color(0.15, 0.15, 0.15))
			b.add_theme_color_override("icon_pressed_color", Color(0.15, 0.15, 0.15))
			b.add_theme_color_override("font_color", Color(1, 0.55, 0.4))
			b.pressed.connect(func(): _show_weapon_info(id, false, need))
		b.focus_entered.connect(func(): _show_weapon_info(id, unlocked, need))
		_lobby_weapons.add_child(b)
	_show_weapon_info(G.start_weapon, true, 1)
	_lobby.visible = true
	_focus(_lobby.find_child("Go", true, false))


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
	_slider(v, "Taille de l'interface", "hud_scale", 0.6, 1.3, 0.05)
	_slider(v, "Marge des bords (écran incurvé)", "hud_margin", 0.0, 0.12, 0.01)
	_check(v, "Assistance à la visée (manette / tactile)", "aim_assist")
	_check(v, "Inverser l'axe vertical", "invert_y")
	_check(v, "Vibrations de la manette", "vibration")
	_check(v, "Afficher les images par seconde", "show_fps")
	_choice(v, "Images par seconde max.", "max_fps", [[60, "60"], [90, "90"], [120, "120"]])
	_choice(v, "Résolution 3D", "render_scale", [[1.0, "100 %"], [0.85, "85 %"], [0.75, "75 %"], [0.6, "60 %"], [0.5, "50 %"]])
	_pad_info = Label.new()
	_pad_info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_pad_info.add_theme_font_size_override("font_size", 20)
	_pad_info.add_theme_color_override("font_color", Color(0.7, 0.85, 1.0))
	v.add_child(_pad_info)
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
	for c in [_title, _pause, _options, _over, _lobby]:
		c.visible = false


func show_title() -> void:
	hide_all()
	var lines: Array[String] = ["Niveau %d" % G.level()]
	if G.best_round > 0:
		lines.append("record : manche %d" % G.best_round)
	_best.text = " — ".join(lines)
	_continue.visible = G.has_save()
	if _continue.visible:
		var d := G.read_save()
		_continue.text = "Continuer — manche %d" % int(d.get("round", 1))
	_title.visible = true
	_focus(_continue if _continue.visible else _title.find_child("Play", true, false))


func show_pause() -> void:
	hide_all()
	_pause.visible = true
	_focus(_pause.find_child("Resume", true, false))


func show_game_over(rounds: int, best: bool) -> void:
	hide_all()
	_over_title.text = "VOUS AVEZ SURVÉCU %d MANCHE%s" % [rounds, "S" if rounds > 1 else ""]
	var lines := "Zombies éliminés : %d\nTirs à la tête : %d\nPoints gagnés : %d" % [G.kills, G.headshots, G.total_points]
	lines += "\n\n+%d XP" % G.last_xp_gain
	if G.level() > G.last_level_before:
		lines += "  —  NIVEAU %d !" % G.level()
		var unlocked := G.unlocks_between(G.last_level_before, G.level())
		if not unlocked.is_empty():
			lines += "\nNouvelle arme de départ : " + ", ".join(unlocked)
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
			for screen in [_title, _pause, _options, _over, _lobby]:
				if screen.visible:
					for name in ["Continue", "Play", "Resume", "Again", "Back", "Go"]:
						var b: Node = screen.find_child(name, true, false)
						if b:
							(b as Control).grab_focus()
							get_viewport().set_input_as_handled()
							return


func is_open() -> bool:
	return _title.visible or _pause.visible or _options.visible or _over.visible or _lobby.visible


func options_open() -> bool:
	return _options.visible


func _process(_delta: float) -> void:
	if _options.visible and _pad_info:
		var pads := Input.get_connected_joypads()
		var names: Array[String] = []
		for d in pads:
			names.append("%s (n°%d)" % [Input.get_joy_name(d), d])
		var t := "Manette : " + (", ".join(names) if not names.is_empty() else "aucune détectée")
		if G.last_pad_input != "":
			t += "\nDernière touche : " + G.last_pad_input
		_pad_info.text = t
