extends Node
## Global state, data tables, settings, input map and sound helpers (autoload "G").

signal points_changed(points: int, delta: int)
signal message(text: String, color: Color)
signal input_mode_changed(mode: String)

# Physics layers (bit values).
const L_WORLD := 1
const L_PLAYER := 2
const L_ZOMBIE := 4
const L_INTERACT := 8
const L_PICKUP := 16
## Invisible walls that stop the player but not bullets (window openings).
const L_PLAYER_BLOCK := 32

# ------------------------------------------------------------------------------------------------
# Weapons. dmg is per bullet / pellet; hs = headshot multiplier; rof = seconds between shots.
# ------------------------------------------------------------------------------------------------
const WEAPONS := {
	"p9": {"name": "Pistolet P9", "up_name": "Crocs d'Acier", "kind": "pistol", "auto": false,
		"dmg": 40, "hs": 3.0, "rof": 0.16, "mag": 8, "reserve": 64, "reload": 1.4,
		"spread": 1.6, "ads_spread": 0.3, "pellets": 1, "pierce": 0, "sound": "pistol",
		"kick": 1.2, "ads_fov": 60.0, "speed": 1.0, "price": 0},
	"k14": {"name": "Carabine K14", "up_name": "K14 Éclipse", "kind": "rifle", "auto": false,
		"dmg": 120, "hs": 2.5, "rof": 0.2, "mag": 8, "reserve": 96, "reload": 2.0,
		"spread": 2.0, "ads_spread": 0.15, "pellets": 1, "pierce": 1, "sound": "carbine",
		"kick": 2.2, "ads_fov": 50.0, "speed": 0.95, "price": 500},
	"grele": {"name": "Fusil à pompe Grêle", "up_name": "Tempête de Grêle", "kind": "shotgun",
		"auto": false, "dmg": 60, "hs": 1.5, "rof": 0.85, "mag": 6, "reserve": 54, "reload": 2.8,
		"spread": 6.0, "ads_spread": 4.0, "pellets": 8, "pierce": 0, "sound": "shotgun",
		"kick": 5.0, "ads_fov": 62.0, "speed": 0.95, "price": 500},
	"vipere": {"name": "Mitraillette Vipère", "up_name": "Vipère Écarlate", "kind": "smg",
		"auto": true, "dmg": 55, "hs": 2.5, "rof": 0.075, "mag": 30, "reserve": 180, "reload": 2.0,
		"spread": 2.8, "ads_spread": 0.9, "pellets": 1, "pierce": 0, "sound": "smg",
		"kick": 0.7, "ads_fov": 58.0, "speed": 1.05, "price": 1200},
	"ouragan": {"name": "Mitraillette Ouragan", "up_name": "Œil du Cyclone", "kind": "smg",
		"auto": true, "dmg": 50, "hs": 2.5, "rof": 0.055, "mag": 40, "reserve": 200, "reload": 2.3,
		"spread": 3.2, "ads_spread": 1.1, "pellets": 1, "pierce": 0, "sound": "smg",
		"kick": 0.6, "ads_fov": 58.0, "speed": 1.05, "price": 1500},
	"faucon": {"name": "Fusil d'assaut Faucon", "up_name": "Faucon Pèlerin", "kind": "ar",
		"auto": true, "dmg": 90, "hs": 2.5, "rof": 0.1, "mag": 30, "reserve": 210, "reload": 2.4,
		"spread": 2.4, "ads_spread": 0.4, "pellets": 1, "pierce": 1, "sound": "rifle",
		"kick": 1.0, "ads_fov": 52.0, "speed": 0.95, "price": 1400},
	"titan": {"name": "Mitrailleuse Titan", "up_name": "Colosse", "kind": "lmg", "auto": true,
		"dmg": 120, "hs": 2.0, "rof": 0.09, "mag": 100, "reserve": 400, "reload": 4.5,
		"spread": 3.5, "ads_spread": 0.8, "pellets": 1, "pierce": 2, "sound": "lmg",
		"kick": 1.1, "ads_fov": 55.0, "speed": 0.82, "price": 0},
	"aiguille": {"name": "Fusil de précision Aiguille", "up_name": "Aiguille du Néant",
		"kind": "sniper", "auto": false, "dmg": 700, "hs": 4.0, "rof": 1.1, "mag": 5,
		"reserve": 50, "reload": 3.0, "spread": 8.0, "ads_spread": 0.0, "pellets": 1, "pierce": 4,
		"sound": "sniper", "kick": 6.0, "ads_fov": 28.0, "speed": 0.9, "price": 0},
	"machoire": {"name": "Double canon Mâchoire", "up_name": "Mâchoires de l'Enfer",
		"kind": "shotgun", "auto": false, "dmg": 100, "hs": 1.5, "rof": 0.25, "mag": 2,
		"reserve": 60, "reload": 2.4, "spread": 7.0, "ads_spread": 5.0, "pellets": 10, "pierce": 0,
		"sound": "shotgun", "kick": 7.0, "ads_fov": 62.0, "speed": 0.95, "price": 0},
	"taureau": {"name": "Revolver Taureau", "up_name": "Minotaure", "kind": "pistol",
		"auto": false, "dmg": 320, "hs": 3.0, "rof": 0.4, "mag": 6, "reserve": 48, "reload": 2.6,
		"spread": 1.8, "ads_spread": 0.2, "pellets": 1, "pierce": 1, "sound": "revolver",
		"kick": 4.0, "ads_fov": 55.0, "speed": 1.0, "price": 0},
	"desint": {"name": "Désintégrateur", "up_name": "Annihilateur", "kind": "wonder",
		"auto": false, "dmg": 1500, "hs": 1.0, "rof": 0.35, "mag": 8, "reserve": 64, "reload": 2.8,
		"spread": 0.5, "ads_spread": 0.0, "pellets": 1, "pierce": 0, "sound": "energy",
		"kick": 2.5, "ads_fov": 58.0, "speed": 1.0, "price": 0, "splash": 3.0,
		"splash_dmg": 900},
}
const BOX_POOL := ["titan", "aiguille", "machoire", "taureau", "desint", "faucon", "ouragan",
		"vipere", "grele", "k14", "desint", "titan", "machoire"]

# ------------------------------------------------------------------------------------------------
# Perks (original names). Colours are used by machines and HUD icons.
# ------------------------------------------------------------------------------------------------
const PERKS := {
	"cuirasse": {"name": "Cuirasse", "price": 2500, "color": Color(0.85, 0.12, 0.1),
		"desc": "Encaissez beaucoup plus de coups", "icon": "C"},
	"main_leste": {"name": "Main Leste", "price": 3000, "color": Color(0.2, 0.85, 0.3),
		"desc": "Rechargement deux fois plus rapide", "icon": "M"},
	"double_detente": {"name": "Double Détente", "price": 2000, "color": Color(0.95, 0.55, 0.1),
		"desc": "Cadence de tir augmentée", "icon": "D"},
	"pied_leger": {"name": "Pied Léger", "price": 2000, "color": Color(0.25, 0.55, 1.0),
		"desc": "Plus rapide, sprint illimité", "icon": "P"},
	"second_souffle": {"name": "Second Souffle", "price": 500, "color": Color(0.3, 0.95, 0.95),
		"desc": "Vous relève une fois si vous tombez", "icon": "S"},
}

const POWERUPS := {
	"ammo": {"name": "Munitions max", "color": Color(0.3, 1.0, 0.4)},
	"double": {"name": "Double points", "color": Color(1.0, 0.85, 0.2)},
	"insta": {"name": "Élimination instantanée", "color": Color(1.0, 0.25, 0.2)},
	"bomb": {"name": "Bombe", "color": Color(1.0, 0.6, 0.15)},
	"carpenter": {"name": "Charpentier", "color": Color(0.7, 0.45, 0.25)},
}


const BOX_PRICE := 950

# ------------------------------------------------------------------------------------------------
# Session state
# ------------------------------------------------------------------------------------------------
var points := 500
var round_num := 0
var kills := 0
var headshots := 0
var total_points := 0
var double_points_time := 0.0
var insta_kill_time := 0.0
var input_mode := "kbm"  # "kbm", "pad" or "touch"
var bot_mode := false
var god_mode := false
var tour_mode := false
var ui_test := false
var view_test := false
var window_test := false
var dog_test := false
var save_test := false
var swap_test := false
var save_stage := 0
var autostart := false
var start_points := 500
var quit_after_round := 0
var quit_after_time := 0.0
var screenshot_dir := ""
var playing := false

var settings := {
	"sens_mouse": 0.15,
	"sens_pad": 1.0,
	"sens_touch": 1.0,
	"invert_y": false,
	"max_fps": 120,
	"render_scale": 0.75 if OS.has_feature("mobile") else 1.0,
	"volume": 0.8,
	"show_fps": false,
	"aim_assist": true,
	"vibration": true,
	"hud_scale": 1.0,
	"hud_margin": 0.0,
}
var best_round := 0

# ------------------------------------------------------------------------------------------------
# Progression (kept between games): experience, level, chosen map and starting weapon.
# ------------------------------------------------------------------------------------------------
const MAPS := {
	"bunker": {"name": "Le Bunker", "desc": "Quatre salles, huit fenêtres, une forge."},
}
## Starting weapons and the level that unlocks each.
const START_WEAPONS := [["p9", 1], ["k14", 3], ["vipere", 5], ["grele", 8], ["faucon", 12],
		["taureau", 16], ["ouragan", 20]]
var xp := 0
var start_weapon := "p9"
var map_id := "bunker"
var last_xp_gain := 0
var last_level_before := 1
## Set by "Continuer": the saved game to restore when the level is ready.
var pending_load: Dictionary = {}

const SETTINGS_PATH := "user://settings.cfg"

var _sounds := {}
## Last gamepad input, shown in the options to check how a controller is seen.
var last_pad_input := ""
var _players: Array[AudioStreamPlayer] = []
var _next_player := 0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_setup_input()
	_load_settings()
	apply_settings()
	for i in 12:
		var p := AudioStreamPlayer.new()
		p.bus = "Master"
		add_child(p)
		_players.append(p)
	var args := OS.get_cmdline_user_args()
	# Test switches (after "--" on the command line), used by the automated playtest.
	bot_mode = args.has("--bot")
	god_mode = args.has("--god")
	tour_mode = args.has("--tour")
	ui_test = args.has("--ui")
	view_test = args.has("--viewtest")
	window_test = args.has("--windowtest")
	dog_test = args.has("--dogtest")
	save_test = args.has("--savetest")
	swap_test = args.has("--swaptest")
	for a in args:
		if a.begins_with("--shots="):
			screenshot_dir = a.substr(8)
		elif a.begins_with("--rounds="):
			quit_after_round = int(a.substr(9))
		elif a.begins_with("--time="):
			quit_after_time = float(a.substr(7))
		elif a.begins_with("--points="):
			start_points = int(a.substr(9))
	if DisplayServer.is_touchscreen_available() and OS.has_feature("mobile"):
		input_mode = "touch"
	if args.has("--inputtest"):
		_input_test.call_deferred()


func reset_session() -> void:
	points = start_points
	round_num = 0
	kills = 0
	headshots = 0
	total_points = 0
	double_points_time = 0.0
	insta_kill_time = 0.0
	points_changed.emit(points, 0)


func add_points(amount: int, multiplied := true) -> void:
	if multiplied and double_points_time > 0.0:
		amount *= 2
	points += amount
	total_points += amount
	points_changed.emit(points, amount)


func spend(amount: int) -> bool:
	if points < amount:
		play("denied")
		return false
	points -= amount
	points_changed.emit(points, -amount)
	play("buy")
	return true


func say(text: String, color := Color(1, 1, 1)) -> void:
	message.emit(text, color)


func _process(delta: float) -> void:
	if get_tree().paused:
		return
	if double_points_time > 0.0:
		double_points_time = max(0.0, double_points_time - delta)
	if insta_kill_time > 0.0:
		insta_kill_time = max(0.0, insta_kill_time - delta)


# ------------------------------------------------------------------------------------------------
# Sound
# ------------------------------------------------------------------------------------------------
func sound(name: String) -> AudioStream:
	if not _sounds.has(name):
		var path := "res://assets/sfx/%s.wav" % name
		_sounds[name] = load(path) if ResourceLoader.exists(path) else null
	return _sounds[name]


func play(name: String, volume_db := 0.0, pitch := 1.0) -> void:
	var s := sound(name)
	if s == null:
		return
	var p := _players[_next_player]
	_next_player = (_next_player + 1) % _players.size()
	p.stream = s
	p.volume_db = volume_db
	p.pitch_scale = pitch
	p.play()


func play_at(name: String, pos: Vector3, parent: Node, volume_db := 0.0, pitch := 1.0) -> void:
	var s := sound(name)
	if s == null or parent == null or not parent.is_inside_tree():
		return
	var p := AudioStreamPlayer3D.new()
	p.stream = s
	p.volume_db = volume_db
	p.pitch_scale = pitch
	p.unit_size = 6.0
	p.max_distance = 40.0
	p.attenuation_filter_cutoff_hz = 6000.0
	parent.add_child(p)
	p.global_position = pos
	p.finished.connect(p.queue_free)
	p.play()


func vibrate(weak: float, strong: float, duration: float) -> void:
	if not settings.vibration:
		return
	for d in Input.get_connected_joypads():
		Input.start_joy_vibration(d, weak, strong, duration)


# ------------------------------------------------------------------------------------------------
# Input map (built in code so it is easy to read and to change)
# ------------------------------------------------------------------------------------------------
## Device -1 = any device. Without it an action only reacts to device 0, and on Android the
## gamepad is often not device 0 (another input device can take that slot).
const ANY_DEVICE := -1


func _key(action: String, keycode: Key) -> void:
	var e := InputEventKey.new()
	e.physical_keycode = keycode
	e.device = ANY_DEVICE
	InputMap.action_add_event(action, e)


func _btn(action: String, button: JoyButton) -> void:
	var e := InputEventJoypadButton.new()
	e.button_index = button
	e.device = ANY_DEVICE
	InputMap.action_add_event(action, e)


func _axis(action: String, axis: JoyAxis, value: float) -> void:
	var e := InputEventJoypadMotion.new()
	e.axis = axis
	e.axis_value = value
	e.device = ANY_DEVICE
	InputMap.action_add_event(action, e)


func _mouse(action: String, button: MouseButton) -> void:
	var e := InputEventMouseButton.new()
	e.button_index = button
	InputMap.action_add_event(action, e)


func _add(action: String, deadzone := 0.2) -> void:
	if InputMap.has_action(action):
		InputMap.erase_action(action)
	InputMap.add_action(action, deadzone)


func _setup_input() -> void:
	for a in ["move_forward", "move_back", "move_left", "move_right"]:
		_add(a, 0.15)
	_key("move_forward", KEY_W); _key("move_forward", KEY_Z); _key("move_forward", KEY_UP)
	_key("move_back", KEY_S); _key("move_back", KEY_DOWN)
	_key("move_left", KEY_A); _key("move_left", KEY_Q); _key("move_left", KEY_LEFT)
	_key("move_right", KEY_D); _key("move_right", KEY_RIGHT)
	_axis("move_forward", JOY_AXIS_LEFT_Y, -1.0)
	_axis("move_back", JOY_AXIS_LEFT_Y, 1.0)
	_axis("move_left", JOY_AXIS_LEFT_X, -1.0)
	_axis("move_right", JOY_AXIS_LEFT_X, 1.0)
	for a in ["look_left", "look_right", "look_up", "look_down"]:
		_add(a, 0.12)
	_axis("look_left", JOY_AXIS_RIGHT_X, -1.0)
	_axis("look_right", JOY_AXIS_RIGHT_X, 1.0)
	_axis("look_up", JOY_AXIS_RIGHT_Y, -1.0)
	_axis("look_down", JOY_AXIS_RIGHT_Y, 1.0)

	_add("fire", 0.3); _mouse("fire", MOUSE_BUTTON_LEFT); _axis("fire", JOY_AXIS_TRIGGER_RIGHT, 1.0)
	_add("ads", 0.3); _mouse("ads", MOUSE_BUTTON_RIGHT); _axis("ads", JOY_AXIS_TRIGGER_LEFT, 1.0)
	# Controllers whose triggers are plain buttons: Android L2 / R2 arrive as buttons 15 / 16.
	_btn("ads", JOY_BUTTON_MISC1); _btn("fire", JOY_BUTTON_PADDLE1)
	_add("reload"); _key("reload", KEY_R)
	_add("interact"); _key("interact", KEY_E); _key("interact", KEY_F)
	# Gamepad X/Square does both, like on console: interact when something is in reach, else reload.
	_add("use"); _btn("use", JOY_BUTTON_X)
	_add("swap"); _key("swap", KEY_1); _key("swap", KEY_2); _key("swap", KEY_TAB)
	_btn("swap", JOY_BUTTON_Y)
	_add("knife"); _key("knife", KEY_V); _key("knife", KEY_C); _mouse("knife", MOUSE_BUTTON_MIDDLE)
	_btn("knife", JOY_BUTTON_B); _btn("knife", JOY_BUTTON_RIGHT_SHOULDER)
	_btn("knife", JOY_BUTTON_RIGHT_STICK)
	_add("jump"); _key("jump", KEY_SPACE); _btn("jump", JOY_BUTTON_A)
	_add("sprint"); _key("sprint", KEY_SHIFT); _btn("sprint", JOY_BUTTON_LEFT_STICK)
	_add("pause"); _key("pause", KEY_ESCAPE); _key("pause", KEY_P); _btn("pause", JOY_BUTTON_START)
	# Menus: make sure A confirms and B goes back whatever the device number.
	_btn("ui_accept", JOY_BUTTON_A)
	_btn("ui_cancel", JOY_BUTTON_B)
	for pair in [["ui_up", JOY_BUTTON_DPAD_UP], ["ui_down", JOY_BUTTON_DPAD_DOWN], ["ui_left", JOY_BUTTON_DPAD_LEFT], ["ui_right", JOY_BUTTON_DPAD_RIGHT]]:
		_btn(pair[0], pair[1])


func _input(event: InputEvent) -> void:
	if event is InputEventJoypadButton and event.pressed:
		last_pad_input = "bouton %d (manette %d)" % [event.button_index, event.device]
	elif event is InputEventJoypadMotion and abs(event.axis_value) > 0.5:
		last_pad_input = "axe %d = %.1f (manette %d)" % [event.axis, event.axis_value, event.device]
	var mode := input_mode
	if event is InputEventJoypadButton or (event is InputEventJoypadMotion and abs(event.axis_value) > 0.4):
		mode = "pad"
	elif event is InputEventScreenTouch or event is InputEventScreenDrag:
		mode = "touch"
	elif event is InputEventKey or (event is InputEventMouseButton and event.device != InputEvent.DEVICE_ID_EMULATION):
		mode = "kbm"
	elif event is InputEventMouseMotion and event.device != InputEvent.DEVICE_ID_EMULATION and event.relative.length() > 2.0 and not OS.has_feature("mobile"):
		mode = "kbm"
	if mode != input_mode:
		input_mode = mode
		input_mode_changed.emit(mode)


func button_name(action: String) -> String:
	match input_mode:
		"pad":
			return {"use": "X", "interact": "X", "reload": "X", "swap": "Y", "knife": "B",
				"jump": "A", "fire": "RT", "ads": "LT"}.get(action, action)
		"touch":
			return {"use": "ACTION", "interact": "ACTION", "reload": "RECHARGER"}.get(action, action)
		_:
			return {"use": "E", "interact": "E", "reload": "R", "swap": "1/2", "knife": "V",
				"jump": "Espace", "fire": "Clic gauche", "ads": "Clic droit"}.get(action, action)


# ------------------------------------------------------------------------------------------------
# Settings
# ------------------------------------------------------------------------------------------------
func _load_settings() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(SETTINGS_PATH) != OK:
		return
	for k in settings.keys():
		settings[k] = cfg.get_value("settings", k, settings[k])
	best_round = cfg.get_value("stats", "best_round", 0)
	xp = cfg.get_value("profile", "xp", 0)
	start_weapon = cfg.get_value("profile", "start_weapon", "p9")
	map_id = cfg.get_value("profile", "map", "bunker")
	if not is_unlocked(start_weapon) or not MAPS.has(map_id):
		start_weapon = "p9"
		map_id = "bunker"


func save_settings() -> void:
	var cfg := ConfigFile.new()
	for k in settings.keys():
		cfg.set_value("settings", k, settings[k])
	cfg.set_value("stats", "best_round", best_round)
	cfg.set_value("profile", "xp", xp)
	cfg.set_value("profile", "start_weapon", start_weapon)
	cfg.set_value("profile", "map", map_id)
	cfg.save(SETTINGS_PATH)


## Total experience needed to reach a level (level 2 at 500, then a little more each time).
func xp_for_level(level: int) -> int:
	return 250 * (level - 1) * level


func level_for_xp(amount: int) -> int:
	var lv := 1
	while amount >= xp_for_level(lv + 1):
		lv += 1
	return lv


func level() -> int:
	return level_for_xp(xp)


func unlock_level(weapon_id: String) -> int:
	for pair in START_WEAPONS:
		if pair[0] == weapon_id:
			return pair[1]
	return 999


func is_unlocked(weapon_id: String) -> bool:
	return level() >= unlock_level(weapon_id)


## Experience for the game that just ended: kills, headshots and rounds survived.
func award_game_xp() -> int:
	var gain := kills * 10 + headshots * 5 + maxi(0, round_num - 1) * 75
	last_level_before = level()
	last_xp_gain = gain
	xp += gain
	save_settings()
	return gain


## Starting weapons unlocked between two levels (for the level-up message).
func unlocks_between(from_level: int, to_level: int) -> Array[String]:
	var out: Array[String] = []
	for pair in START_WEAPONS:
		if pair[1] > from_level and pair[1] <= to_level:
			out.append(WEAPONS[pair[0]].name)
	return out


# ------------------------------------------------------------------------------------------------
# Saved game (one slot): written between rounds and from the pause menu, removed at game over.
# ------------------------------------------------------------------------------------------------
const SAVE_PATH := "user://partie.json"


func has_save() -> bool:
	return FileAccess.file_exists(SAVE_PATH)


func read_save() -> Dictionary:
	var f := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if f == null:
		return {}
	var data: Variant = JSON.parse_string(f.get_as_text())
	return data if data is Dictionary else {}


func write_save(data: Dictionary) -> void:
	var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(data, "  "))


func delete_save() -> void:
	if has_save():
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE_PATH))


func apply_settings() -> void:
	Engine.max_fps = int(settings.max_fps)
	AudioServer.set_bus_volume_db(0, linear_to_db(max(0.001, float(settings.volume))))
	var vp := get_viewport()
	if vp:
		vp.scaling_3d_scale = float(settings.render_scale)


# ------------------------------------------------------------------------------------------------
# Weapon helpers
# ------------------------------------------------------------------------------------------------
# Upgrade tiers from the Forge: 0 = normal, 1 = violet, 2 = or (gold), 3 = ultime (red).
const TIER_NAMES := ["", "Violet", "Or", "Ultime"]
const TIER_COLORS := [Color(0.9, 0.9, 0.88), Color(0.85, 0.55, 1.0), Color(1.0, 0.8, 0.25), Color(1.0, 0.25, 0.2)]
const UPGRADE_PRICES := [5000, 9000, 15000]   # price to reach tier 1, 2, 3
const TIER_DMG := [1.0, 2.0, 3.5, 5.5]
const TIER_MAG := [1.0, 1.5, 1.75, 2.0]
const TIER_RESERVE := [1.0, 2.0, 2.5, 3.0]
const TIER_ROF := [1.0, 0.9, 0.85, 0.78]
const TIER_SPREAD := [1.0, 0.8, 0.7, 0.6]
const MAX_TIER := 3


func new_weapon(id: String, tier: int) -> Dictionary:
	var w := {"id": id, "up": tier, "mag": 0, "reserve": 0}
	w.mag = stat(w, "mag")
	w.reserve = stat(w, "reserve")
	return w


## A weapon's stat, with its upgrade tier applied.
func stat(w: Dictionary, key: String) -> Variant:
	var base: Dictionary = WEAPONS[w.id]
	var v: Variant = base.get(key, 0)
	var tier := int(w.up)
	if tier <= 0:
		return v
	match key:
		"dmg", "splash_dmg":
			return v * TIER_DMG[tier]
		"mag":
			if w.id == "machoire":
				return 2 + 2 * tier
			return int(ceil(v * TIER_MAG[tier]))
		"reserve":
			return int(v * TIER_RESERVE[tier])
		"rof":
			return v * TIER_ROF[tier]
		"spread", "ads_spread":
			return v * TIER_SPREAD[tier]
		"pierce":
			return v + tier
	return v


func weapon_name(w: Dictionary) -> String:
	var tier := int(w.up)
	if tier <= 0:
		return WEAPONS[w.id].name
	if tier == 1:
		return WEAPONS[w.id].up_name
	return "%s — %s" % [WEAPONS[w.id].up_name, TIER_NAMES[tier]]


func tier_color(tier: int) -> Color:
	return TIER_COLORS[clampi(tier, 0, MAX_TIER)]


var _gun_mats := {}


## Shared materials for the 3D weapon models (normal and upgraded).
func gun_mats() -> Dictionary:
	if not _gun_mats.is_empty():
		return _gun_mats
	var metal := StandardMaterial3D.new()
	metal.albedo_color = Color(0.2, 0.21, 0.23)
	metal.metallic = 0.7
	metal.roughness = 0.35
	var dark := StandardMaterial3D.new()
	dark.albedo_color = Color(0.06, 0.06, 0.065)
	dark.roughness = 0.6
	var wood := StandardMaterial3D.new()
	wood.albedo_texture = load("res://assets/tex/wood.png")
	wood.albedo_color = Color(0.85, 0.7, 0.6)
	wood.uv1_triplanar = true
	wood.uv1_scale = Vector3(4, 4, 4)
	wood.roughness = 0.7
	var glow := StandardMaterial3D.new()
	glow.albedo_color = Color(0.4, 1.0, 0.5)
	glow.emission_enabled = true
	glow.emission = Color(0.3, 1.0, 0.45)
	glow.emission_energy_multiplier = 2.5
	# Violet (tier 1): kept fairly light so it reads in dark rooms (no reflections on phones).
	var up_metal := _mat(Color(0.42, 0.16, 0.62), 0.35, 0.3, Color(0.4, 0.1, 0.65), 0.25)
	var up_dark := _mat(Color(0.17, 0.05, 0.26), 0.3, 0.4, Color(0.45, 0.1, 0.75), 0.12)
	var up_glow := _mat(Color(1.0, 0.3, 0.9), 0.0, 0.5, Color(1.0, 0.25, 0.85), 3.0)
	_gun_mats = {"metal": metal, "dark": dark, "wood": wood, "glow": glow,
		"up_metal": up_metal, "up_dark": up_dark, "up_glow": up_glow}
	# Gold (tier 2) and ultimate red (tier 3).
	_gun_mats["gold_metal"] = _mat(Color(1.0, 0.76, 0.26), 0.35, 0.28, Color(0.85, 0.58, 0.12), 0.35)
	_gun_mats["gold_dark"] = _mat(Color(0.72, 0.5, 0.12), 0.3, 0.35, Color(0.6, 0.4, 0.06), 0.2)
	_gun_mats["gold_glow"] = _mat(Color(1.0, 0.85, 0.3), 0.0, 0.5, Color(1.0, 0.75, 0.2), 3.0)
	_gun_mats["red_metal"] = _mat(Color(0.6, 0.06, 0.04), 0.35, 0.25, Color(0.9, 0.08, 0.03), 0.3)
	_gun_mats["red_dark"] = _mat(Color(0.16, 0.02, 0.02), 0.3, 0.35, Color(0.9, 0.06, 0.02), 0.18)
	_gun_mats["red_glow"] = _mat(Color(1.0, 0.2, 0.1), 0.0, 0.5, Color(1.0, 0.12, 0.03), 4.0)
	return _gun_mats


func _mat(albedo: Color, metallic: float, rough: float, emission: Color, energy: float) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = albedo
	m.metallic = metallic
	m.roughness = rough
	m.emission_enabled = true
	m.emission = emission
	m.emission_energy_multiplier = energy
	return m


func gun_mats_for(tier: int) -> Dictionary:
	var m := gun_mats().duplicate()
	var prefix: String = ["", "up", "gold", "red"][clampi(tier, 0, MAX_TIER)]
	if prefix != "":
		m["metal"] = m[prefix + "_metal"]
		m["dark"] = m[prefix + "_dark"]
		m["glow"] = m[prefix + "_glow"]
		m["wood"] = m[prefix + "_dark"]
	return m


# ------------------------------------------------------------------------------------------------
# Round formulas
# ------------------------------------------------------------------------------------------------
func zombie_health(r: int) -> float:
	if r < 10:
		return 150.0 + 100.0 * (r - 1)
	return 950.0 * pow(1.1, r - 9)


func zombie_count(r: int) -> int:
	var table := [0, 6, 8, 13, 18, 24]
	if r < table.size():
		return table[r]
	var k := r - 5
	return int(24 + k * 3.5 + k * k * 0.15)


func dog_health(r: int) -> float:
	return zombie_health(r) * 0.4 + 100.0


func spawn_delay(r: int) -> float:
	return max(0.45, 2.0 * pow(0.95, r - 1))


## Test: a gamepad that is not device 0 (common on Android) must drive every action.
func _input_test() -> void:
	var ok := true
	for dev in [0, 3, 17]:
		for pair in [["jump", JOY_BUTTON_A], ["use", JOY_BUTTON_X], ["swap", JOY_BUTTON_Y], ["knife", JOY_BUTTON_B], ["pause", JOY_BUTTON_START]]:
			var e := InputEventJoypadButton.new()
			e.device = dev
			e.button_index = pair[1]
			e.pressed = true
			if not InputMap.event_is_action(e, pair[0]):
				print("[inputtest] FAIL device %d %s" % [dev, pair[0]])
				ok = false
		for pair in [["fire", JOY_AXIS_TRIGGER_RIGHT, 1.0], ["ads", JOY_AXIS_TRIGGER_LEFT, 1.0], ["move_forward", JOY_AXIS_LEFT_Y, -1.0], ["look_right", JOY_AXIS_RIGHT_X, 1.0]]:
			var m := InputEventJoypadMotion.new()
			m.device = dev
			m.axis = pair[1]
			m.axis_value = pair[2]
			if not InputMap.event_is_action(m, pair[0]):
				print("[inputtest] FAIL device %d %s" % [dev, pair[0]])
				ok = false
	# A touch turned into a mouse click must not fire the weapon.
	var t := InputEventMouseButton.new()
	t.device = InputEvent.DEVICE_ID_EMULATION
	t.button_index = MOUSE_BUTTON_LEFT
	t.pressed = true
	if InputMap.event_is_action(t, "fire"):
		print("[inputtest] FAIL emulated mouse fires")
		ok = false
	print("[inputtest] %s" % ("OK" if ok else "FAILED"))
	get_tree().quit()
