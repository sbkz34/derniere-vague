class_name TouchControls
extends Control
## On-screen controls for phones: a floating stick on the left, drag anywhere on the right to
## look, and buttons. Hidden as soon as a gamepad is used, shown again on the next touch.

signal pause_pressed

var move := Vector2.ZERO
var sprint := false
var fire := false
var ads := false
var action := false
var action_pressed := false
var reload_pressed := false
var swap_pressed := false
var knife_pressed := false
var jump_pressed := false
var show_action := false
var action_label := "ACTION"

var _look := Vector2.ZERO
var _touches := {}          # index -> role
var _stick_base := Vector2.ZERO
var _stick_pos := Vector2.ZERO
var _stick_index := -1
var _font: Font

const STICK_R := 95.0


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_font = ThemeDB.fallback_font
	G.input_mode_changed.connect(_on_mode)
	_on_mode(G.input_mode)


func _on_mode(mode: String) -> void:
	visible = mode == "touch"
	if not visible:
		_release_all()


func _release_all() -> void:
	_touches.clear()
	_stick_index = -1
	move = Vector2.ZERO
	sprint = false
	fire = false
	ads = false
	action = false


func consume_look() -> Vector2:
	var d := _look
	_look = Vector2.ZERO
	return d


func _buttons() -> Dictionary:
	# Buttons keep clear of the screen edges by the margin set in the options.
	var m := size.x * float(G.settings.hud_margin)
	var w := size.x - m
	var h := size.y
	var b := {
		"fire": [Vector2(w - 165, h - 175), 78.0, "TIR"],
		"ads": [Vector2(w - 330, h - 105), 52.0, "VISER"],
		"jump": [Vector2(w - 330, h - 255), 46.0, "SAUT"],
		"reload": [Vector2(w - 230, h - 330), 44.0, "RECH."],
		"knife": [Vector2(w - 470, h - 80), 42.0, "COUTEAU"],
		"swap": [Vector2(w - 95, h - 330), 40.0, "ARME"],
		"pause": [Vector2(56 + m, 56), 32.0, "II"],
	}
	if show_action:
		b["action"] = [Vector2(w - 480, h - 230), 56.0, "ACTION"]
	return b


func _hit_button(p: Vector2) -> String:
	var b := _buttons()
	for name in b:
		var def: Array = b[name]
		if p.distance_to(def[0]) <= def[1] * 1.15:
			return name
	return ""


func _input(event: InputEvent) -> void:
	if not G.playing or get_tree().paused:
		if event is InputEventScreenTouch and not event.pressed:
			_touches.erase(event.index)
		return
	if event is InputEventScreenTouch:
		if G.input_mode != "touch":
			return
		var p: Vector2 = event.position
		if event.pressed:
			var btn := _hit_button(p)
			if btn != "":
				_touches[event.index] = btn
				_press(btn, true)
			elif p.x < size.x * 0.42 and p.y > size.y * 0.25:
				_touches[event.index] = "stick"
				_stick_index = event.index
				_stick_base = p
				_stick_pos = p
			else:
				_touches[event.index] = "look"
		else:
			var role: String = _touches.get(event.index, "")
			_touches.erase(event.index)
			if role == "stick":
				_stick_index = -1
				move = Vector2.ZERO
				sprint = false
			elif role != "" and role != "look":
				_press(role, false)
		queue_redraw()
	elif event is InputEventScreenDrag:
		var role: String = _touches.get(event.index, "")
		if role == "stick":
			_stick_pos = event.position
			var v: Vector2 = (_stick_pos - _stick_base) / STICK_R
			if v.length() > 1.0:
				# Drag the base along so the stick never "sticks" at the edge.
				_stick_base = _stick_pos - v.normalized() * STICK_R
				v = v.normalized()
			move = v
			sprint = v.length() > 0.92 and v.y < -0.6
			queue_redraw()
		elif role == "look" or role == "fire" or role == "ads":
			_look += event.relative


func _press(btn: String, down: bool) -> void:
	match btn:
		"fire":
			fire = down
		"ads":
			ads = down
		"action":
			action = down
			if down:
				action_pressed = true
		"reload":
			if down:
				reload_pressed = true
		"swap":
			if down:
				swap_pressed = true
		"knife":
			if down:
				knife_pressed = true
		"jump":
			if down:
				jump_pressed = true
		"pause":
			if down:
				pause_pressed.emit()


func _process(_delta: float) -> void:
	if visible:
		queue_redraw()


func _draw() -> void:
	var b := _buttons()
	var active := {}
	for idx in _touches:
		active[_touches[idx]] = true
	for name in b:
		var def: Array = b[name]
		var on: bool = active.has(name)
		var col := Color(1, 1, 1, 0.28 if on else 0.13)
		if name == "fire":
			col = Color(1, 0.3, 0.25, 0.4 if on else 0.22)
		elif name == "action":
			col = Color(1, 0.85, 0.3, 0.45 if on else 0.3)
		draw_circle(def[0], def[1], col)
		draw_arc(def[0], def[1], 0, TAU, 40, Color(1, 1, 1, 0.45), 2.0, true)
		var text: String = def[2]
		var fs := 22 if def[1] > 45.0 else 17
		var tw := _font.get_string_size(text, HORIZONTAL_ALIGNMENT_CENTER, -1, fs).x
		draw_string(_font, def[0] + Vector2(-tw / 2, fs * 0.35), text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(1, 1, 1, 0.85))
	if _stick_index >= 0:
		draw_circle(_stick_base, STICK_R, Color(1, 1, 1, 0.1))
		draw_arc(_stick_base, STICK_R, 0, TAU, 48, Color(1, 1, 1, 0.35), 2.0, true)
		draw_circle(_stick_base + move * STICK_R, 40.0, Color(1, 1, 1, 0.35 if not sprint else 0.55))
	else:
		var hint_pos := Vector2(size.x * 0.17, size.y * 0.72)
		draw_arc(hint_pos, STICK_R * 0.8, 0, TAU, 48, Color(1, 1, 1, 0.12), 2.0, true)
