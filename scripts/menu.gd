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
signal map_selected(id: String)

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
var _challenges: Control
var _challenge_list: VBoxContainer
var _armory: Control
var _armory_grid: GridContainer
var _armory_preview: LobbyVisuals.WeaponPreview
var _armory_name: Label
var _armory_kills: Label
var _armory_camos: HBoxContainer
var _armory_weapon := "p9"
var _pad_buttons := {}
var _capturing := ""
var _capture_t := 0.0
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
	_challenges = _build_challenges()
	_armory = _build_armory()
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
	_button(v, "Défis", show_challenges)
	_button(v, "Armurerie", show_armory)
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
	_map_preview.spots = level.preview_spots
	_map_name.text = G.MAPS[G.map_id].name
	_map_desc.text = G.MAPS[G.map_id].desc
	for c in _lobby_maps.get_children():
		c.queue_free()
	for c in _lobby_weapons.get_children():
		c.queue_free()
	var map_group := ButtonGroup.new()
	for id in G.MAPS:
		var b := _small_button(_lobby_maps, G.MAPS[id].name, func():
			if id != G.map_id:
				_map_name.text = "Chargement…"
				_map_desc.text = G.MAPS[id].name
				map_selected.emit(id))
		b.toggle_mode = true
		b.button_group = map_group
		b.button_pressed = id == G.map_id
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
	_section(v, "BOUTONS DE LA MANETTE")
	for pair in G.PAD_ACTIONS:
		var action: String = pair[0]
		var h := _row(v, pair[1])
		var b := Button.new()
		b.custom_minimum_size = Vector2(260, 44)
		b.pressed.connect(func(): _start_capture(action))
		h.add_child(b)
		_pad_buttons[action] = b
	var reset := _small_button(v, "Boutons par défaut", func():
		G.reset_pad_map()
		_refresh_pad_buttons())
	reset.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	_refresh_pad_buttons()
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
	for c in [_title, _pause, _options, _over, _lobby, _challenges, _armory]:
		if c:
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
		var map_name: String = G.MAPS.get(str(d.get("map", "bunker")), G.MAPS.bunker).name
		_continue.text = "Continuer — %s, manche %d" % [map_name, int(d.get("round", 1))]
	_title.visible = true
	_focus(_continue if _continue.visible else _title.find_child("Play", true, false))


func show_pause() -> void:
	hide_all()
	_pause.visible = true
	_focus(_pause.find_child("Resume", true, false))


## The Village's happy ending.
func show_extraction(rounds: int, bonus: int) -> void:
	show_game_over(rounds, false)
	_over_title.text = "EXTRACTION RÉUSSIE"
	_over_title.label_settings.font_color = Color(0.7, 0.9, 1.0)
	var lines := _over_stats.text
	lines = lines.replace("\n\n+%d XP" % G.last_xp_gain, "\n\nManche %d — vous êtes sorti du Village !\n+%d XP (dont %d pour l'extraction)" % [rounds, G.last_xp_gain + bonus, bonus])
	lines += "\n\nArme secrète débloquée : ???  (elle arrive bientôt)"
	_over_stats.text = lines


func show_game_over(rounds: int, best: bool) -> void:
	hide_all()
	_over_title.label_settings.font_color = Color(0.85, 0.08, 0.05)
	_over_title.text = "VOUS AVEZ SURVÉCU %d MANCHE%s" % [rounds, "S" if rounds > 1 else ""]
	var lines := "Zombies éliminés : %d\nTirs à la tête : %d\nPoints gagnés : %d" % [G.kills, G.headshots, G.total_points]
	lines += "\n\n+%d XP" % G.last_xp_gain
	if G.session_challenge_xp > 0:
		lines += "  (+%d XP de défis)" % G.session_challenge_xp
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
	if _capturing != "":
		_capture_input(event)
		return
	# First gamepad press in a menu: give focus to its first button.
	if not is_open():
		return
	if (event is InputEventJoypadButton and event.pressed) or (event is InputEventJoypadMotion and abs(event.axis_value) > 0.5):
		if get_viewport().gui_get_focus_owner() == null:
			for screen in [_title, _pause, _options, _over, _lobby, _challenges, _armory]:
				if screen.visible:
					for name in ["Continue", "Play", "Resume", "Again", "Back", "Go"]:
						var b: Node = screen.find_child(name, true, false)
						if b:
							(b as Control).grab_focus()
							get_viewport().set_input_as_handled()
							return


func is_open() -> bool:
	return _title.visible or _pause.visible or _options.visible or _over.visible or _lobby.visible \
			or _challenges.visible or _armory.visible


func options_open() -> bool:
	return _options.visible


func _process(delta: float) -> void:
	if _capturing != "":
		_capture_t -= delta
		if _capture_t <= 0.0:
			_capturing = ""
			_refresh_pad_buttons()
	if _options.visible and _pad_info:
		var pads := Input.get_connected_joypads()
		var names: Array[String] = []
		for d in pads:
			names.append("%s (n°%d)" % [Input.get_joy_name(d), d])
		var t := "Manette : " + (", ".join(names) if not names.is_empty() else "aucune détectée")
		if G.last_pad_input != "":
			t += "\nDernière touche : " + G.last_pad_input
		_pad_info.text = t



# ------------------------------------------------------------------------------------------------
# Gamepad remapping
# ------------------------------------------------------------------------------------------------
func _refresh_pad_buttons() -> void:
	for action in _pad_buttons:
		var b: Button = _pad_buttons[action]
		b.text = G.pad_binding_name(G.pad_map.get(action, G.PAD_DEFAULT[action]))


func _start_capture(action: String) -> void:
	_capturing = action
	_capture_t = 6.0
	_refresh_pad_buttons()
	(_pad_buttons[action] as Button).text = "Appuyez sur un bouton…"


## The next gamepad button (or trigger) pressed becomes the action's button. Échap cancels.
func _capture_input(event: InputEvent) -> void:
	var binding := ""
	if event is InputEventJoypadButton and event.pressed:
		if event.button_index == JOY_BUTTON_START:
			return
		binding = "b%d" % event.button_index
	elif event is InputEventJoypadMotion and event.axis_value > 0.6 and (event.axis == JOY_AXIS_TRIGGER_LEFT or event.axis == JOY_AXIS_TRIGGER_RIGHT):
		binding = "a%d" % event.axis
	elif event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		binding = "cancel"
	if binding == "":
		return
	get_viewport().set_input_as_handled()
	var action := _capturing
	_capturing = ""
	if binding != "cancel":
		G.set_pad_binding(action, binding)
	_refresh_pad_buttons()
	# Keep the focus on the button so the menu stays usable with the pad.
	(_pad_buttons[action] as Button).grab_focus.call_deferred()


# ------------------------------------------------------------------------------------------------
# Challenges
# ------------------------------------------------------------------------------------------------
func _build_challenges() -> Control:
	var s := _screen(0.75)
	var cc := CenterContainer.new()
	cc.set_anchors_preset(Control.PRESET_FULL_RECT)
	s.add_child(cc)
	var panel := PanelContainer.new()
	cc.add_child(panel)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
	panel.add_child(v)
	_big_label(v, "DÉFIS", 48, Color(0.9, 0.9, 0.88))
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(900, 470)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	v.add_child(scroll)
	_challenge_list = VBoxContainer.new()
	_challenge_list.add_theme_constant_override("separation", 8)
	_challenge_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_challenge_list)
	var back := _button(v, "Retour", show_title)
	back.name = "Back"
	back.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	return s


func show_challenges() -> void:
	hide_all()
	for c in _challenge_list.get_children():
		c.queue_free()
	for i in G.CHALLENGES.size():
		var c: Dictionary = G.CHALLENGES[i]
		var t := G.challenge_tier(i)
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 14)
		_challenge_list.add_child(row)
		var name_box := VBoxContainer.new()
		name_box.custom_minimum_size = Vector2(330, 0)
		row.add_child(name_box)
		var title := Label.new()
		title.add_theme_font_size_override("font_size", 22)
		var stars := ""
		for k in 3:
			stars += "★" if k < t else "☆"
		title.text = "%s  %s" % [c.name, stars]
		title.add_theme_color_override("font_color", Color(1, 0.85, 0.35) if t >= 3 else Color(0.95, 0.92, 0.88))
		name_box.add_child(title)
		var desc := Label.new()
		desc.add_theme_font_size_override("font_size", 15)
		desc.add_theme_color_override("font_color", Color(0.72, 0.7, 0.68))
		var goal: int = c.goals[mini(t, 2)]
		desc.text = (c.desc % goal) if t < 3 else "Terminé"
		name_box.add_child(desc)
		var bar := ProgressBar.new()
		bar.custom_minimum_size = Vector2(320, 16)
		bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		bar.show_percentage = false
		bar.max_value = goal
		bar.value = mini(G.pstat(c.stat), goal)
		bar.add_theme_stylebox_override("fill", _flat(Color(0.3, 0.8, 0.4) if t >= 3 else Color(0.85, 0.2, 0.1)))
		bar.add_theme_stylebox_override("background", _flat(Color(0.15, 0.1, 0.1)))
		row.add_child(bar)
		var num := Label.new()
		num.add_theme_font_size_override("font_size", 17)
		num.custom_minimum_size = Vector2(110, 0)
		num.text = "%d / %d" % [mini(G.pstat(c.stat), goal), goal]
		row.add_child(num)
		var reward := Label.new()
		reward.add_theme_font_size_override("font_size", 17)
		reward.add_theme_color_override("font_color", Color(1, 0.85, 0.35))
		reward.text = ("+%d XP" % int(c.xp[t])) if t < 3 else "✓"
		row.add_child(reward)
	_challenges.visible = true
	_focus(_challenges.find_child("Back", true, false))


# ------------------------------------------------------------------------------------------------
# Armory: kills per weapon and camouflages
# ------------------------------------------------------------------------------------------------
func _build_armory() -> Control:
	var s := _screen(0.75)
	var cc := CenterContainer.new()
	cc.set_anchors_preset(Control.PRESET_FULL_RECT)
	s.add_child(cc)
	var panel := PanelContainer.new()
	cc.add_child(panel)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
	panel.add_child(v)
	_big_label(v, "ARMURERIE", 48, Color(0.9, 0.9, 0.88))
	var cols := HBoxContainer.new()
	cols.add_theme_constant_override("separation", 24)
	v.add_child(cols)
	_armory_grid = GridContainer.new()
	_armory_grid.columns = 4
	_armory_grid.add_theme_constant_override("h_separation", 8)
	_armory_grid.add_theme_constant_override("v_separation", 8)
	cols.add_child(_armory_grid)
	var right := VBoxContainer.new()
	right.add_theme_constant_override("separation", 8)
	cols.add_child(right)
	_armory_preview = LobbyVisuals.WeaponPreview.new(Vector2i(560, 200))
	right.add_child(_armory_preview)
	_armory_name = Label.new()
	_armory_name.add_theme_font_size_override("font_size", 26)
	_armory_name.add_theme_color_override("font_color", Color(1, 0.9, 0.8))
	right.add_child(_armory_name)
	_armory_kills = Label.new()
	_armory_kills.add_theme_font_size_override("font_size", 17)
	_armory_kills.add_theme_color_override("font_color", Color(0.75, 0.72, 0.7))
	right.add_child(_armory_kills)
	_section(right, "CAMOUFLAGE")
	_armory_camos = HBoxContainer.new()
	_armory_camos.add_theme_constant_override("separation", 6)
	right.add_child(_armory_camos)
	var back := _button(v, "Retour", show_title)
	back.name = "Back"
	back.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	return s


func show_armory() -> void:
	hide_all()
	for c in _armory_grid.get_children():
		c.queue_free()
	var group := ButtonGroup.new()
	for id in G.WEAPONS:
		var b := Button.new()
		b.custom_minimum_size = Vector2(128, 70)
		b.add_theme_font_size_override("font_size", 14)
		b.text = "%s — %d" % [LobbyVisuals.short_name(id), int(G.weapon_kills.get(id, 0))]
		b.icon = LobbyVisuals.weapon_icon(b, id, Vector2i(240, 90))
		b.expand_icon = true
		b.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
		b.vertical_icon_alignment = VERTICAL_ALIGNMENT_TOP
		b.toggle_mode = true
		b.button_group = group
		b.button_pressed = id == _armory_weapon
		b.pressed.connect(func(): _show_armory_weapon(id))
		b.focus_entered.connect(func(): _show_armory_weapon(id))
		_armory_grid.add_child(b)
	# The Village's secret weapon: a mystery until someone gets out.
	var secret := Button.new()
	secret.custom_minimum_size = Vector2(128, 70)
	secret.add_theme_font_size_override("font_size", 22)
	secret.text = "???"
	secret.toggle_mode = true
	secret.button_group = group
	secret.add_theme_color_override("font_color", Color(0.6, 0.85, 1.0))
	secret.pressed.connect(_show_secret)
	secret.focus_entered.connect(_show_secret)
	_armory_grid.add_child(secret)
	_show_armory_weapon(_armory_weapon)
	_armory.visible = true
	_focus(_armory.find_child("Back", true, false))


func _show_secret() -> void:
	_armory_preview.show_weapon("desint", "")
	_armory_preview.modulate = Color(0, 0, 0)
	_armory_name.text = "???"
	if G.pstat("extractions") > 0:
		_armory_kills.text = "Débloquée ! Elle arrive dans une prochaine mise à jour."
	else:
		_armory_kills.text = "Réussissez une extraction au Village pour la débloquer."
	for c in _armory_camos.get_children():
		c.queue_free()


func _show_armory_weapon(id: String, preview_camo := "*") -> void:
	_armory_weapon = id
	_armory_preview.modulate = Color(1, 1, 1)
	_armory_preview.show_weapon(id, preview_camo)
	_armory_name.text = G.WEAPONS[id].name
	var kills := int(G.weapon_kills.get(id, 0))
	var next := ""
	for c in G.CAMOS:
		if kills < int(c[2]):
			next = " — prochain camouflage à %d" % int(c[2])
			break
	_armory_kills.text = "%d éliminations%s" % [kills, next]
	for c in _armory_camos.get_children():
		c.queue_free()
	var group := ButtonGroup.new()
	for c in G.CAMOS:
		var camo: String = c[0]
		var unlocked := G.is_camo_unlocked(id, camo)
		var b := Button.new()
		b.custom_minimum_size = Vector2(88, 88)
		b.add_theme_font_size_override("font_size", 13)
		b.text = c[1] if unlocked else "%d" % int(c[2])
		b.vertical_icon_alignment = VERTICAL_ALIGNMENT_TOP
		b.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
		b.expand_icon = true
		if camo != "":
			b.icon = load("res://assets/tex/camo_%s.png" % camo)
		if not unlocked:
			b.add_theme_color_override("icon_normal_color", Color(0.2, 0.2, 0.2))
			b.add_theme_color_override("font_color", Color(1, 0.55, 0.4))
		b.toggle_mode = true
		b.button_group = group
		b.button_pressed = G.camo_for(id) == camo
		b.pressed.connect(func():
			if unlocked:
				G.camo_choice[id] = camo
				G.save_settings()
				_show_armory_weapon(id)
			else:
				# Locked: a look at it on the weapon, without equipping it.
				_show_armory_weapon(id, camo))
		_armory_camos.add_child(b)
