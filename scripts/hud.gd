class_name Hud
extends CanvasLayer
## In-game display: round counter, points, ammo, perks, crosshair, hints, messages, damage.

var player: Player
var director: Director

var _root: Control
var _round: Label
var _points: Label
var _popups: VBoxContainer
var _weapon: Label
var _ammo: Label
var _hint: Label
var _msg: Label
var _msg_t := 0.0
var _perks: HBoxContainer
var _powerups: Label
var _vignette: TextureRect
var _flash: ColorRect
var _down: ColorRect
var _cross: Crosshair
var _fps: Label
var _reload_tip: Label
var _round_tween: Tween
var _hurt_t := 0.0
var _br: VBoxContainer

const RED := Color(0.78, 0.05, 0.03)


func _ls(size: int, color := Color.WHITE, outline := 6) -> LabelSettings:
	var s := LabelSettings.new()
	s.font_size = size
	s.font_color = color
	s.outline_size = outline
	s.outline_color = Color(0, 0, 0, 0.85)
	s.shadow_size = 0
	return s


func _label(parent: Control, size: int, color := Color.WHITE, outline := 6) -> Label:
	var l := Label.new()
	l.label_settings = _ls(size, color, outline)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(l)
	return l


func build(p_player: Player, p_director: Director) -> void:
	player = p_player
	director = p_director
	layer = 5
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_root)

	# Damage vignette: transparent centre, red edges.
	_vignette = TextureRect.new()
	var gt := GradientTexture2D.new()
	var g := Gradient.new()
	g.set_color(0, Color(0.6, 0, 0, 0))
	g.set_color(1, Color(0.6, 0, 0, 1))
	g.add_point(0.55, Color(0.6, 0, 0, 0))
	gt.gradient = g
	gt.fill = GradientTexture2D.FILL_RADIAL
	gt.fill_from = Vector2(0.5, 0.5)
	gt.fill_to = Vector2(1.0, 0.5)
	gt.width = 256
	gt.height = 256
	_vignette.texture = gt
	_vignette.stretch_mode = TextureRect.STRETCH_SCALE
	_vignette.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_vignette.set_anchors_preset(Control.PRESET_FULL_RECT)
	_vignette.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_vignette.modulate.a = 0.0
	_root.add_child(_vignette)
	_flash = ColorRect.new()
	_flash.color = Color(0.7, 0, 0, 0)
	_flash.set_anchors_preset(Control.PRESET_FULL_RECT)
	_flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_flash)
	_down = ColorRect.new()
	_down.color = Color(0.15, 0.15, 0.18, 0.55)
	_down.set_anchors_preset(Control.PRESET_FULL_RECT)
	_down.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_down.visible = false
	_root.add_child(_down)

	_cross = Crosshair.new()
	_cross.set_anchors_preset(Control.PRESET_FULL_RECT)
	_cross.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_cross.player = player
	_root.add_child(_cross)

	# Round counter (bottom left) with perk icons above it.
	var bl := VBoxContainer.new()
	bl.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	bl.anchor_top = 1.0
	bl.anchor_bottom = 1.0
	bl.offset_left = 40
	bl.offset_top = -190
	bl.offset_bottom = -20
	bl.grow_vertical = Control.GROW_DIRECTION_BEGIN
	bl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(bl)
	_perks = HBoxContainer.new()
	_perks.add_theme_constant_override("separation", 8)
	bl.add_child(_perks)
	_round = _label(bl, 110, RED, 10)
	_round.text = ""

	# Points, weapon and ammo (bottom right).
	var br := VBoxContainer.new()
	_br = br
	br.anchor_left = 1.0
	br.anchor_right = 1.0
	br.anchor_top = 1.0
	br.anchor_bottom = 1.0
	br.offset_left = -420
	br.offset_right = -40
	br.offset_top = -230
	br.offset_bottom = -24
	br.alignment = BoxContainer.ALIGNMENT_END
	br.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(br)
	_popups = VBoxContainer.new()
	_popups.alignment = BoxContainer.ALIGNMENT_END
	_popups.custom_minimum_size = Vector2(0, 70)
	br.add_child(_popups)
	_points = _label(br, 44, Color(1, 0.88, 0.35), 8)
	_points.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_weapon = _label(br, 24, Color(0.9, 0.9, 0.88))
	_weapon.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_ammo = _label(br, 40, Color.WHITE, 8)
	_ammo.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT

	# Hint (bottom centre) and active bonuses above it.
	_hint = _label(_root, 26, Color(1, 1, 1), 7)
	_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hint.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_hint.anchor_left = 0.15
	_hint.anchor_right = 0.85
	_hint.offset_left = 0
	_hint.offset_right = 0
	_hint.offset_top = -150
	_hint.offset_bottom = -110
	_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_powerups = _label(_root, 26, Color(1, 0.9, 0.4), 7)
	_powerups.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_powerups.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_powerups.anchor_left = 0.2
	_powerups.anchor_right = 0.8
	_powerups.offset_left = 0
	_powerups.offset_right = 0
	_powerups.offset_top = -195
	_powerups.offset_bottom = -155
	_reload_tip = _label(_root, 24, Color(1, 1, 1), 6)
	_reload_tip.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_reload_tip.set_anchors_preset(Control.PRESET_CENTER)
	_reload_tip.anchor_left = 0.3
	_reload_tip.anchor_right = 0.7
	_reload_tip.offset_left = 0
	_reload_tip.offset_right = 0
	_reload_tip.offset_top = 50
	_reload_tip.offset_bottom = 85

	_msg = _label(_root, 42, Color.WHITE, 9)
	_msg.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_msg.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_msg.anchor_left = 0.1
	_msg.anchor_right = 0.9
	_msg.offset_left = 0
	_msg.offset_right = 0
	_msg.offset_top = 90
	_msg.offset_bottom = 150
	_msg.modulate.a = 0.0

	_fps = _label(_root, 18, Color(0.7, 1, 0.7), 4)
	_fps.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	_fps.offset_left = -140
	_fps.offset_top = 8
	_fps.offset_right = -12

	G.input_mode_changed.connect(_layout)
	_layout(G.input_mode)
	G.points_changed.connect(_on_points)
	G.message.connect(_on_message)
	player.weapons_changed.connect(_refresh_weapon)
	player.perks_changed.connect(_refresh_perks)
	player.hurt.connect(_on_hurt)
	player.hit_confirmed.connect(_cross.hitmarker)
	player.downed_changed.connect(func(d): _down.visible = d)
	director.round_started.connect(_on_round_started)
	director.round_ended.connect(_on_round_ended)
	_on_points(G.points, 0)
	_refresh_weapon()
	_refresh_perks()


## On phones the fire button sits bottom right, so points and ammo move to the top right.
func _layout(mode: String) -> void:
	if mode == "touch":
		_br.anchor_top = 0.0
		_br.anchor_bottom = 0.0
		_br.offset_top = -40
		_br.offset_bottom = 200
		_br.offset_right = -24
	else:
		_br.anchor_top = 1.0
		_br.anchor_bottom = 1.0
		_br.offset_top = -230
		_br.offset_bottom = -24
		_br.offset_right = -40


func _on_points(points: int, delta: int) -> void:
	_points.text = "%d" % points
	if delta == 0:
		return
	var l := _label(_popups, 30 if abs(delta) < 100 else 34, Color(1, 0.9, 0.4) if delta > 0 else Color(1, 0.35, 0.3), 6)
	l.text = ("+%d" % delta) if delta > 0 else ("%d" % delta)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	var tw := l.create_tween()
	tw.tween_property(l, "modulate:a", 0.0, 0.9).set_delay(0.3)
	tw.tween_callback(l.queue_free)
	if _popups.get_child_count() > 4:
		_popups.get_child(0).queue_free()


func _refresh_weapon() -> void:
	var w := player.current_weapon()
	if w.is_empty():
		_weapon.text = ""
		_ammo.text = ""
		return
	_weapon.text = G.weapon_name(w)
	_weapon.label_settings.font_color = Color(0.95, 0.6, 1.0) if w.up else Color(0.9, 0.9, 0.88)
	_ammo.text = "%d / %d" % [w.mag, w.reserve]
	var low: bool = w.mag <= int(G.stat(w, "mag")) / 4
	_ammo.label_settings.font_color = Color(1, 0.35, 0.3) if low else Color.WHITE


func _refresh_perks() -> void:
	for c in _perks.get_children():
		c.queue_free()
	for id in player.perks:
		var info: Dictionary = G.PERKS[id]
		var p := PanelContainer.new()
		var sb := StyleBoxFlat.new()
		sb.bg_color = info.color.darkened(0.2)
		sb.border_color = info.color.lightened(0.4)
		sb.set_border_width_all(2)
		sb.set_corner_radius_all(8)
		p.add_theme_stylebox_override("panel", sb)
		p.custom_minimum_size = Vector2(46, 46)
		var l := _label(p, 26, Color.WHITE, 5)
		l.text = info.icon
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		_perks.add_child(p)


func _on_message(text: String, color: Color) -> void:
	_msg.text = text
	_msg.label_settings.font_color = color
	_msg.modulate.a = 1.0
	_msg_t = 2.2


func _on_hurt(_dir: Vector3, _amount: float) -> void:
	_hurt_t = 0.35
	_flash.color.a = 0.25


func _on_round_started(n: int) -> void:
	if _round_tween:
		_round_tween.kill()
	_round.text = "%d" % n
	_round.label_settings.font_color = Color(1, 1, 1)
	_round_tween = create_tween()
	_round_tween.tween_property(_round, "modulate:a", 0.2, 0.25)
	_round_tween.tween_property(_round, "modulate:a", 1.0, 0.25)
	_round_tween.tween_property(_round, "modulate:a", 0.2, 0.25)
	_round_tween.tween_property(_round, "modulate:a", 1.0, 0.25)
	_round_tween.tween_property(_round.label_settings, "font_color", RED, 1.5)
	if n == 1:
		G.say("Manche 1 — tenez bon", Color(0.95, 0.3, 0.25))


func _on_round_ended(_n: int) -> void:
	if _round_tween:
		_round_tween.kill()
	_round_tween = create_tween().set_loops(5)
	_round_tween.tween_property(_round, "modulate:a", 0.15, 0.5)
	_round_tween.tween_property(_round, "modulate:a", 1.0, 0.5)


func _process(delta: float) -> void:
	if player == null:
		return
	# Hint text.
	_hint.text = player.hint
	# Low ammo / reload reminder.
	var w := player.current_weapon()
	_reload_tip.text = ""
	if not w.is_empty() and w.mag <= int(G.stat(w, "mag")) / 4:
		if w.mag == 0 and w.reserve == 0:
			_reload_tip.text = "PLUS DE MUNITIONS"
		elif player._reload_t <= 0.0:
			_reload_tip.text = "Recharger [%s]" % G.button_name("reload")
	_refresh_weapon()
	# Bonuses.
	var parts: Array[String] = []
	if G.double_points_time > 0.0:
		parts.append("Double points %d" % ceil(G.double_points_time))
	if G.insta_kill_time > 0.0:
		parts.append("Élimination instantanée %d" % ceil(G.insta_kill_time))
	_powerups.text = "   ".join(parts)
	# Damage feedback.
	var missing := 1.0 - player.hp / player.max_hp
	_vignette.modulate.a = lerpf(_vignette.modulate.a, clampf(missing * 1.1, 0.0, 0.95), clampf(delta * 6.0, 0.0, 1.0))
	if _hurt_t > 0.0:
		_hurt_t -= delta
	_flash.color.a = maxf(0.0, _flash.color.a - delta * 0.8)
	# Message fade.
	if _msg_t > 0.0:
		_msg_t -= delta
		if _msg_t < 0.6:
			_msg.modulate.a = maxf(0.0, _msg_t / 0.6)
	_fps.visible = bool(G.settings.show_fps)
	if _fps.visible:
		_fps.text = "%d FPS" % Engine.get_frames_per_second()
	_cross.queue_redraw()
