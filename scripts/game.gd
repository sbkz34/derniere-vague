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
		"kick": 1.2, "ads_fov": 60.0, "speed": 1.0, "price": 0, "akimbo": true},
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
		"sound": "shotgun", "kick": 7.0, "ads_fov": 62.0, "speed": 0.95, "price": 0, "akimbo": true},
	"taureau": {"name": "Revolver Taureau", "up_name": "Minotaure", "kind": "pistol",
		"auto": false, "dmg": 320, "hs": 3.0, "rof": 0.4, "mag": 6, "reserve": 48, "reload": 2.6,
		"spread": 1.8, "ads_spread": 0.2, "pellets": 1, "pierce": 1, "sound": "revolver",
		"kick": 4.0, "ads_fov": 55.0, "speed": 1.0, "price": 0, "akimbo": true},
	"desint": {"name": "Désintégrateur", "up_name": "Annihilateur", "kind": "wonder",
		"auto": false, "dmg": 1500, "hs": 1.0, "rof": 0.35, "mag": 8, "reserve": 64, "reload": 2.8,
		"spread": 0.5, "ads_spread": 0.0, "pellets": 1, "pierce": 0, "sound": "energy",
		"kick": 2.5, "ads_fov": 58.0, "speed": 1.0, "price": 0, "splash": 3.0,
		"splash_dmg": 900},
	"uzi": {"name": "Mini Uzi", "up_name": "Essaim", "kind": "smg", "auto": true,
		"dmg": 45, "hs": 2.5, "rof": 0.05, "mag": 32, "reserve": 224, "reload": 1.7,
		"spread": 3.4, "ads_spread": 1.3, "pellets": 1, "pierce": 0, "sound": "smg",
		"kick": 0.6, "ads_fov": 60.0, "speed": 1.08, "price": 1000, "akimbo": true},
	"rpg": {"name": "Lance-roquettes Tonnerre", "up_name": "Fin du Monde", "kind": "launcher",
		"auto": false, "dmg": 600, "hs": 1.0, "rof": 0.6, "mag": 1, "reserve": 10, "reload": 2.6,
		"spread": 0.8, "ads_spread": 0.1, "pellets": 1, "pierce": 0, "sound": "rocket_fire",
		"kick": 5.0, "ads_fov": 55.0, "speed": 0.88, "price": 0, "splash": 4.5, "splash_dmg": 1400},
	# Melee: no ammo; one swing hits up to `cleave` zombies within `range` in front.
	"hache": {"name": "Hache de guerre", "up_name": "Fendeuse d'Âmes", "kind": "melee",
		"auto": true, "dmg": 700, "hs": 1.0, "rof": 1.05, "mag": 0, "reserve": 0, "reload": 0.1,
		"spread": 0.0, "ads_spread": 0.0, "pellets": 1, "pierce": 0, "sound": "axe_swing",
		"kick": 0.0, "ads_fov": 75.0, "speed": 0.95, "price": 1500, "melee": true, "range": 2.6,
		"cleave": 3, "windup": 0.3, "akimbo": true},
	"sabre": {"name": "Sabre", "up_name": "Lame du Crépuscule", "kind": "melee",
		"auto": true, "dmg": 450, "hs": 1.0, "rof": 0.45, "mag": 0, "reserve": 0, "reload": 0.1,
		"spread": 0.0, "ads_spread": 0.0, "pellets": 1, "pierce": 0, "sound": "sabre_swing",
		"kick": 0.0, "ads_fov": 75.0, "speed": 1.1, "price": 0, "melee": true, "range": 2.4,
		"cleave": 2, "windup": 0.12, "akimbo": true},
}
## "leurre" is not a weapon: three decoys for the LB slot.
const BOX_POOL := ["leurre", "titan", "aiguille", "machoire", "taureau", "desint", "faucon", "ouragan",
		"vipere", "grele", "k14", "desint", "titan", "machoire", "sabre", "rpg", "sabre", "rpg"]

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
## Perk machines and the Forge need the breaker thrown.
var power_on := false
signal power_changed(on: bool)
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
var gadget_test := false
var special_test := false
var progress_test := false
var weapon_test := false
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
const START_WEAPONS := [["p9", 1], ["k14", 3], ["vipere", 5], ["uzi", 7], ["grele", 8],
		["hache", 10], ["faucon", 12], ["sabre", 14], ["taureau", 16], ["ouragan", 20], ["rpg", 25]]
var xp := 0
var start_weapon := "p9"
var map_id := "bunker"
var last_xp_gain := 0
## Experience from challenges completed during the current game (shown at game over).
var session_challenge_xp := 0
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
	apply_pad_map()
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
	gadget_test = args.has("--gadgettest")
	special_test = args.has("--specialtest")
	progress_test = args.has("--progresstest")
	weapon_test = args.has("--weapontest")
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
	power_on = false
	session_challenge_xp = 0
	# Level-ups are counted from here (challenges can raise the level during the game).
	last_level_before = level()
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


func set_power(on: bool) -> void:
	if power_on == on:
		return
	power_on = on
	power_changed.emit(on)


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
	_btn("knife", JOY_BUTTON_B); _btn("knife", JOY_BUTTON_RIGHT_STICK)
	_add("grenade"); _key("grenade", KEY_G); _btn("grenade", JOY_BUTTON_RIGHT_SHOULDER)
	_add("decoy"); _key("decoy", KEY_H); _btn("decoy", JOY_BUTTON_LEFT_SHOULDER)
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
			var a := "use" if action == "interact" or action == "reload" else action
			if pad_map.has(a):
				return pad_binding_name(pad_map[a])
			return action
		"touch":
			return {"use": "ACTION", "interact": "ACTION", "reload": "RECHARGER"}.get(action, action)
		_:
			return {"use": "E", "interact": "E", "reload": "R", "swap": "1/2", "knife": "V",
				"jump": "Espace", "fire": "Clic gauche", "ads": "Clic droit", "grenade": "G",
				"decoy": "H"}.get(action, action)


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
	stats = cfg.get_value("progress", "stats", {})
	weapon_kills = cfg.get_value("progress", "weapon_kills", {})
	challenges_done = cfg.get_value("progress", "challenges", {})
	camo_choice = cfg.get_value("progress", "camos", {})
	var pm: Dictionary = cfg.get_value("pad", "map", {})
	for k in pm:
		if PAD_DEFAULT.has(k):
			pad_map[k] = str(pm[k])
	apply_pad_map()
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
	cfg.set_value("progress", "stats", stats)
	cfg.set_value("progress", "weapon_kills", weapon_kills)
	cfg.set_value("progress", "challenges", challenges_done)
	cfg.set_value("progress", "camos", camo_choice)
	cfg.set_value("pad", "map", pad_map)
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
# Challenges and camouflages (kept between games)
# ------------------------------------------------------------------------------------------------
signal challenge_done(text: String)
signal camo_unlocked(text: String)

## Each challenge has three tiers; each tier gives its experience once.
const CHALLENGES := [
	{"name": "Tueur", "stat": "kills", "desc": "Éliminer %d zombies", "goals": [100, 500, 2000], "xp": [300, 1000, 3000]},
	{"name": "Tireur d'élite", "stat": "headshots", "desc": "%d tirs à la tête mortels", "goals": [50, 250, 1000], "xp": [300, 1000, 3000]},
	{"name": "Survivant", "stat": "round", "desc": "Atteindre la manche %d", "goals": [10, 20, 30], "xp": [500, 1500, 4000]},
	{"name": "Dresseur", "stat": "dog_kills", "desc": "Abattre %d molosses", "goals": [20, 100, 300], "xp": [300, 1000, 2500]},
	{"name": "Tombeur de Colosse", "stat": "brute_kills", "desc": "Abattre %d Colosse", "goals": [1, 5, 15], "xp": [800, 2000, 5000]},
	{"name": "Artificier", "stat": "grenade_kills", "desc": "%d éliminations à l'explosif", "goals": [25, 100, 400], "xp": [300, 1000, 2500]},
	{"name": "Électricien", "stat": "trap_kills", "desc": "%d éliminations avec le piège", "goals": [25, 100, 300], "xp": [300, 800, 2000]},
	{"name": "Boucher", "stat": "knife_kills", "desc": "%d éliminations au corps à corps", "goals": [25, 100, 400], "xp": [300, 1000, 2500]},
	{"name": "Forgeron", "stat": "upgrades", "desc": "Améliorer %d fois une arme à la Forge", "goals": [3, 15, 50], "xp": [300, 1000, 2500]},
	{"name": "Arme ultime", "stat": "ultimes", "desc": "Porter %d armes au niveau Ultime", "goals": [1, 5, 20], "xp": [500, 1500, 4000]},
	{"name": "Sans jambes", "stat": "crawler_kills", "desc": "Achever %d rampants", "goals": [10, 50, 200], "xp": [200, 700, 2000]},
]
const TIER_ROMAN := ["I", "II", "III"]
## Camouflages: id, name, kills needed with that weapon.
const CAMOS := [["", "Standard", 0], ["treillis", "Treillis", 50], ["desert", "Désert", 150],
		["cobalt", "Cobalt", 300], ["braise", "Braise", 600], ["obsidienne", "Obsidienne", 1000]]

var stats := {}
var weapon_kills := {}
var challenges_done := {}
var camo_choice := {}


func pstat(key: String) -> int:
	return int(stats.get(key, 0))


func stat_add(key: String, n := 1) -> void:
	stats[key] = pstat(key) + n
	_check_challenges(key)


func stat_max(key: String, v: int) -> void:
	if v > pstat(key):
		stats[key] = v
		_check_challenges(key)


## Current tier (0-2) of a challenge, or 3 when all are done.
func challenge_tier(i: int) -> int:
	for t in 3:
		if not challenges_done.has("%d:%d" % [i, t]):
			return t
	return 3


func _check_challenges(key: String) -> void:
	for i in CHALLENGES.size():
		var c: Dictionary = CHALLENGES[i]
		if c.stat != key:
			continue
		var t := challenge_tier(i)
		while t < 3 and pstat(key) >= int(c.goals[t]):
			challenges_done["%d:%d" % [i, t]] = true
			var gain: int = c.xp[t]
			xp += gain
			session_challenge_xp += gain
			play("challenge", -2.0)
			challenge_done.emit("DÉFI RÉUSSI : %s %s  (+%d XP)" % [c.name, TIER_ROMAN[t], gain])
			save_settings()
			t += 1


## Called for every kill: feeds the challenges and the camouflages.
func record_kill(z: Node, how: String, weapon_id: String, head: bool) -> void:
	stat_add("kills")
	if head:
		stat_add("headshots")
	if z is Dog:
		stat_add("dog_kills")
	elif z is Brute:
		stat_add("brute_kills")
	elif z is Zombie and (z as Zombie).crawler:
		stat_add("crawler_kills")
	match how:
		"grenade", "rocket":
			stat_add("grenade_kills")
		"trap":
			stat_add("trap_kills")
		"knife", "melee":
			stat_add("knife_kills")
	if how in ["gun", "melee", "rocket"] and weapon_id != "" and WEAPONS.has(weapon_id):
		var before := int(weapon_kills.get(weapon_id, 0))
		weapon_kills[weapon_id] = before + 1
		for c in CAMOS:
			if int(c[2]) > 0 and before < int(c[2]) and before + 1 >= int(c[2]):
				# A new camouflage goes straight on the weapon.
				camo_choice[weapon_id] = c[0]
				play("challenge", -4.0, 1.2)
				camo_unlocked.emit("CAMOUFLAGE %s : %s" % [str(c[1]).to_upper(), WEAPONS[weapon_id].name])
				save_settings()


func camo_need(camo: String) -> int:
	for c in CAMOS:
		if c[0] == camo:
			return int(c[2])
	return 999999


func camo_name(camo: String) -> String:
	for c in CAMOS:
		if c[0] == camo:
			return c[1]
	return ""


func is_camo_unlocked(weapon_id: String, camo: String) -> bool:
	return int(weapon_kills.get(weapon_id, 0)) >= camo_need(camo)


func camo_for(weapon_id: String) -> String:
	var c: String = camo_choice.get(weapon_id, "")
	return c if is_camo_unlocked(weapon_id, c) else ""


## The camouflage on the gun body; `dark` is a shaded copy for the darker parts.
func _camo_mat(camo: String, tier: int, dark: bool) -> StandardMaterial3D:
	var key := "camo_%s_%d_%s" % [camo, tier, dark]
	if _gun_mats.has(key):
		return _gun_mats[key]
	var m := StandardMaterial3D.new()
	var tex: Texture2D = load("res://assets/tex/camo_%s.png" % camo)
	m.albedo_texture = tex
	m.uv1_triplanar = true
	m.uv1_scale = Vector3(2.5, 2.5, 2.5)
	m.roughness = 0.5
	m.metallic = 0.25
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	if camo == "braise" or camo == "obsidienne":
		m.emission_enabled = true
		m.emission_texture = tex
		m.emission = Color(1, 1, 1)
		m.emission_energy_multiplier = 1.6
	if tier > 0:
		# Upgraded: the camouflage takes the tier's colour and glow.
		var prefix: String = ["", "up", "gold", "red"][clampi(tier, 0, MAX_TIER)]
		var tm: StandardMaterial3D = gun_mats()[prefix + "_metal"]
		m.albedo_color = (tm.albedo_color * 1.8).clamp(Color(0, 0, 0), Color(1, 1, 1))
		if not m.emission_enabled:
			m.emission_enabled = true
			m.emission = tm.emission
			m.emission_energy_multiplier = tm.emission_energy_multiplier
	if dark:
		m.albedo_color = m.albedo_color * Color(0.55, 0.55, 0.55)
		m.emission_energy_multiplier *= 0.5
	_gun_mats[key] = m
	return m


# ------------------------------------------------------------------------------------------------
# Gamepad buttons (remappable in the options). A binding is "b<button>" or "a<trigger axis>".
# ------------------------------------------------------------------------------------------------
const PAD_ACTIONS := [["fire", "Tirer"], ["ads", "Viser"], ["use", "Action / recharger"],
		["swap", "Changer d'arme"], ["knife", "Couteau"], ["grenade", "Grenade"], ["decoy", "Leurre"],
		["jump", "Sauter"], ["sprint", "Sprinter"]]
const PAD_DEFAULT := {"fire": "a5", "ads": "a4", "use": "b2", "swap": "b3", "knife": "b1",
		"grenade": "b10", "decoy": "b9", "jump": "b0", "sprint": "b7"}
const PAD_NAMES := {"b0": "A", "b1": "B", "b2": "X", "b3": "Y", "b4": "Select", "b5": "Home", "b6": "Start",
		"b7": "L3", "b8": "R3", "b9": "LB", "b10": "RB", "b11": "Haut", "b12": "Bas", "b13": "Gauche",
		"b14": "Droite", "b15": "LT", "b16": "RT", "a4": "LT", "a5": "RT"}
var pad_map := PAD_DEFAULT.duplicate()


func pad_binding_name(binding: String) -> String:
	return PAD_NAMES.get(binding, "Bouton %s" % binding.substr(1))


## Puts the gamepad buttons of the remappable actions back from pad_map.
func apply_pad_map() -> void:
	for pair in PAD_ACTIONS:
		var action: String = pair[0]
		for e in InputMap.action_get_events(action):
			if e is InputEventJoypadButton or e is InputEventJoypadMotion:
				InputMap.action_erase_event(action, e)
	var used := {}
	for pair in PAD_ACTIONS:
		used[pad_map.get(pair[0], PAD_DEFAULT[pair[0]])] = true
	for pair in PAD_ACTIONS:
		var action: String = pair[0]
		var b: String = pad_map.get(action, PAD_DEFAULT[action])
		_bind(action, b)
		# Triggers that some controllers report as buttons on Android (15 = L2, 16 = R2).
		if b == "a5" and not used.has("b16"):
			_bind(action, "b16")
		elif b == "a4" and not used.has("b15"):
			_bind(action, "b15")
		elif b == "b1" and action == "knife" and not used.has("b8"):
			_bind(action, "b8")


func _bind(action: String, b: String) -> void:
	var n := int(b.substr(1))
	if b.begins_with("a"):
		_axis(action, n as JoyAxis, 1.0)
	else:
		_btn(action, n as JoyButton)


## Gives `action` the binding; an action that had it takes the old one instead.
func set_pad_binding(action: String, binding: String) -> void:
	var old: String = pad_map.get(action, PAD_DEFAULT[action])
	for other in pad_map.keys():
		if other != action and pad_map[other] == binding:
			pad_map[other] = old
	pad_map[action] = binding
	apply_pad_map()
	save_settings()


func reset_pad_map() -> void:
	pad_map = PAD_DEFAULT.duplicate()
	apply_pad_map()
	save_settings()


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
			var m := 2 + 2 * tier if w.id == "machoire" else int(ceil(v * TIER_MAG[tier]))
			# Ultimate akimbo: one magazine per gun.
			return m * 2 if is_akimbo(w) else m
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
	if is_akimbo(w):
		return "%s — %s ×2" % [WEAPONS[w.id].up_name, TIER_NAMES[tier]]
	return "%s — %s" % [WEAPONS[w.id].up_name, TIER_NAMES[tier]]


## Ultimate pistols, Mâchoire, Mini Uzi and melee weapons come in pairs.
func is_akimbo(w: Dictionary) -> bool:
	return not w.is_empty() and int(w.up) >= MAX_TIER and bool(WEAPONS[w.id].get("akimbo", false))


func is_melee(w: Dictionary) -> bool:
	return not w.is_empty() and bool(WEAPONS[w.id].get("melee", false))


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


func gun_mats_for(tier: int, camo := "") -> Dictionary:
	var m := gun_mats().duplicate()
	var prefix: String = ["", "up", "gold", "red"][clampi(tier, 0, MAX_TIER)]
	if prefix != "":
		m["metal"] = m[prefix + "_metal"]
		m["dark"] = m[prefix + "_dark"]
		m["glow"] = m[prefix + "_glow"]
		m["wood"] = m[prefix + "_dark"]
	if camo != "":
		m["metal"] = _camo_mat(camo, tier, false)
		m["dark"] = _camo_mat(camo, tier, true)
		m["wood"] = m["metal"] if tier == 0 else m["dark"]
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
