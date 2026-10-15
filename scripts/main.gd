extends Node3D
## Entry point: builds the level, the player and the round director, and switches between the
## title screen, playing, pause and game over. Also hosts the automated test modes.

var level: Level
var player: Player
var director: Director
var hud: Hud
var touch: TouchControls
var menu: Menu
var zombies: Node3D
var menu_cam: Camera3D
var ambient: AudioStreamPlayer
var _menu_t := 0.0
var _game_over_pending := false
var _elapsed := 0.0
var _shot_t := 0.0
var _shot_n := 0
var _status_t := 0.0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	get_tree().paused = false
	Engine.time_scale = 1.0
	G.playing = false
	G.apply_settings()

	level = Level.new()
	level.name = "Level"
	level.process_mode = Node.PROCESS_MODE_PAUSABLE
	add_child(level)
	level.build()
	zombies = Node3D.new()
	zombies.name = "Zombies"
	zombies.process_mode = Node.PROCESS_MODE_PAUSABLE
	add_child(zombies)

	player = Player.new()
	player.name = "Player"
	player.process_mode = Node.PROCESS_MODE_PAUSABLE
	add_child(player)
	player.spawn_at(level.player_start, 0.0)
	player.level = level

	director = Director.new()
	director.name = "Director"
	director.process_mode = Node.PROCESS_MODE_PAUSABLE
	director.level = level
	director.player = player
	director.zombie_parent = zombies
	add_child(director)
	player.director = director

	var touch_layer := CanvasLayer.new()
	touch_layer.layer = 10
	touch_layer.process_mode = Node.PROCESS_MODE_PAUSABLE
	add_child(touch_layer)
	touch = TouchControls.new()
	touch_layer.add_child(touch)
	touch.pause_pressed.connect(_toggle_pause)
	player.touch = touch

	hud = Hud.new()
	hud.process_mode = Node.PROCESS_MODE_PAUSABLE
	add_child(hud)
	hud.build(player, director)
	hud.visible = false
	touch.visible = false

	menu = Menu.new()
	add_child(menu)
	menu.play_pressed.connect(_start_game)
	menu.resume_pressed.connect(_resume)
	menu.quit_to_title.connect(_to_title)
	menu.restart_pressed.connect(_restart)

	menu_cam = Camera3D.new()
	menu_cam.fov = 70
	add_child(menu_cam)
	menu_cam.current = true

	ambient = AudioStreamPlayer.new()
	var amb := G.sound("ambient")   # loops (set in its .import file)
	if amb:
		ambient.stream = amb
		ambient.volume_db = -8.0
		add_child(ambient)
		ambient.play()

	player.died.connect(_on_player_died)
	director.round_started.connect(_on_round_started)

	level.bake()
	await level.nav_ready

	if G.autostart or G.bot_mode or G.tour_mode or G.view_test:
		G.autostart = false
		_start_game()
	else:
		menu.show_title()
	if G.ui_test:
		_run_ui_test()
	if G.view_test:
		_run_view_test()


func _start_game() -> void:
	menu.hide_all()
	G.reset_session()
	G.playing = true
	hud.visible = true
	touch.visible = G.input_mode == "touch"
	player.cam.current = true
	director.start()
	_capture_mouse(true)
	if G.tour_mode:
		_run_tour()


func _restart() -> void:
	G.autostart = true
	_reload()


func _to_title() -> void:
	G.autostart = false
	_reload()


func _reload() -> void:
	get_tree().paused = false
	Engine.time_scale = 1.0
	G.playing = false
	get_tree().reload_current_scene()


func _capture_mouse(on: bool) -> void:
	if OS.has_feature("mobile") or G.bot_mode or G.tour_mode:
		return
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED if on else Input.MOUSE_MODE_VISIBLE


func _toggle_pause() -> void:
	if not G.playing or player.dead:
		return
	if get_tree().paused:
		_resume()
	else:
		get_tree().paused = true
		menu.show_pause()
		touch.visible = false
		_capture_mouse(false)


func _resume() -> void:
	menu.hide_all()
	get_tree().paused = false
	touch.visible = G.input_mode == "touch"
	_capture_mouse(true)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause"):
		if menu.options_open():
			return
		if get_tree().paused:
			_resume()
		else:
			_toggle_pause()


func _notification(what: int) -> void:
	# Pause when the app goes to the background (phone call, home button…).
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT or what == NOTIFICATION_APPLICATION_PAUSED:
		if G.playing and not get_tree().paused and not player.dead and not G.bot_mode and not G.tour_mode:
			_toggle_pause()


func _on_round_started(n: int) -> void:
	if G.quit_after_round > 0 and n > G.quit_after_round:
		print("[test] reached round %d: kills=%d headshots=%d points=%d hp=%.0f" % [n, G.kills, G.headshots, G.points, player.hp])
		_screenshot("final")
		get_tree().quit()


func _on_player_died() -> void:
	if _game_over_pending:
		return
	_game_over_pending = true
	G.play("game_over", 0.0)
	Engine.time_scale = 0.35
	if G.bot_mode:
		print("[test] player died at round %d" % G.round_num)
	await get_tree().create_timer(1.2, true, false, true).timeout
	Engine.time_scale = 1.0
	G.playing = false
	var best := G.round_num > G.best_round
	if best:
		G.best_round = G.round_num
		G.save_settings()
	hud.visible = false
	touch.visible = false
	_capture_mouse(false)
	menu.show_game_over(G.round_num, best)
	if G.bot_mode:
		_screenshot("gameover")
		get_tree().quit()


func _process(delta: float) -> void:
	touch.show_action = player.hint != "" and player.interact_target != null
	if not G.playing and menu_cam.current:
		# Slow drift around the hall for the title screen.
		_menu_t += delta
		var a := _menu_t * 0.08
		menu_cam.global_position = Vector3(1.5 + sin(a) * 2.0, 1.9, 3.5 + cos(a) * 1.0)
		menu_cam.look_at(Vector3(-2.5 + sin(a * 0.7) * 2.0, 1.5, -7.0))
	if not G.playing:
		return
	_elapsed += delta
	if G.screenshot_dir != "" and G.bot_mode:
		_shot_t += delta
		if _shot_t > 12.0:
			_shot_t = 0.0
			_screenshot("bot")
	if G.bot_mode:
		_status_t += delta
		if _status_t > 10.0:
			_status_t = 0.0
			print("[test] t=%.0fs round=%d alive=%d to_spawn=%d kills=%d points=%d hp=%.0f fps=%d" % [_elapsed, G.round_num, director.alive, director.to_spawn, G.kills, G.points, player.hp, Engine.get_frames_per_second()])
			for z in get_tree().get_nodes_in_group("zombies"):
				var zz := z as Zombie
				print("   zombie state=%s pos=%s outside=%s room=%s planks=%d busy=%s" % [Zombie.State.keys()[zz.state], zz.global_position.snapped(Vector3.ONE * 0.1), zz.outside, zz.window.room, zz.window.planks, zz.window.busy])
		_bot_economy()
	if G.quit_after_time > 0.0 and _elapsed > G.quit_after_time:
		print("[test] time limit: round=%d kills=%d" % [G.round_num, G.kills])
		_screenshot("timeout")
		get_tree().quit()


## The bot buys what it can afford, to exercise the shops during automated tests.
func _bot_economy() -> void:
	if player.interact_target and not player.interact_target is Barricade:
		return
	if G.points >= 1500 and not player.has_weapon("faucon"):
		G.points -= 1400
		player.give_weapon("faucon", false)


func _screenshot(tag: String) -> void:
	if G.screenshot_dir == "":
		return
	DirAccess.make_dir_recursive_absolute(G.screenshot_dir)
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	_shot_n += 1
	img.save_png("%s/%02d_%s.png" % [G.screenshot_dir, _shot_n, tag])


# ------------------------------------------------------------------------------------------------
# Tour (automated visual check): opens every door, visits each spot, shows each weapon.
# ------------------------------------------------------------------------------------------------
func _wait(t: float) -> void:
	await get_tree().create_timer(t).timeout


func _pose(pos: Vector3, look: Vector3) -> void:
	player.global_position = pos
	player.reset_physics_interpolation()
	var to := (look - (pos + Vector3(0, 1.62, 0))).normalized()
	player._yaw = atan2(-to.x, -to.z)
	player._pitch = asin(clampf(to.y, -1.0, 1.0))


func _run_tour() -> void:
	director.set_process(false)
	G.points = 100000
	await _wait(1.0)
	_pose(Vector3(0, 0, 3), Vector3(-2.5, 1.5, -7))
	await _wait(0.6)
	await _screenshot("hall_start")
	_pose(Vector3(4, 0, -2), Vector3(6.85, 1.5, -4.5))
	await _wait(0.6)
	await _screenshot("wallbuy_k14")
	for d in level.doors:
		d.interact(player)
	await level.nav_ready
	await _wait(1.2)
	_pose(Vector3(13, 0, -1.5), Vector3(16.5, 0.8, -5.5))
	await _wait(0.6)
	await _screenshot("atelier_box")
	for it in level.get_children():
		if it is MysteryBox:
			it.interact(player)
	await _wait(2.0)
	await _screenshot("box_rolling")
	await _wait(2.5)
	await _screenshot("box_ready")
	_pose(Vector3(13, 0, 1.5), Vector3(17, 1.4, 6.4))
	await _wait(0.6)
	await _screenshot("perk_cuirasse")
	_pose(Vector3(1, 0, 15), Vector3(4.6, 1.4, 20.4))
	await _wait(0.6)
	await _screenshot("reserve_perks")
	_pose(Vector3(13, 0, 10), Vector3(18.2, 1.3, 10))
	await _wait(0.6)
	await _screenshot("labo_forge")
	# Each weapon in hand (hip and aimed).
	_pose(Vector3(0, 0, 3), Vector3(-2.5, 1.5, -7))
	for id in G.WEAPONS:
		player.give_weapon(id, id == "faucon" or id == "desint", false)
		await _wait(0.5)
		await _screenshot("weapon_" + id)
	player.give_weapon("faucon", true, false)
	await _wait(0.4)
	# Zombies: one climbing in at the north window, one standing in the hall.
	var north: Barricade = level.windows[0]
	var z1 := Zombie.new()
	z1.setup(director, player, north, 0, 500.0, "run")
	zombies.add_child(z1)
	var z2 := Zombie.new()
	z2.setup(director, player, north, 1, 500.0, "walk")
	zombies.add_child(z2)
	z2.outside = false
	z2.state = Zombie.State.ATTACK
	z2.global_position = Vector3(1.5, 0, -1.0)
	z2.reset_physics_interpolation()
	z2.agent.avoidance_enabled = false
	player.targetable = false
	_pose(Vector3(-1.0, 0, 2.5), Vector3(-1.5, 1.3, -6.0))
	await _wait(3.0)
	await _screenshot("zombie_window")
	await _wait(4.0)
	await _screenshot("zombie_tearing")
	_pose(Vector3(1.0, 0, 1.6), Vector3(1.5, 1.2, -1.0))
	z2._attack_t = 0.2
	await _wait(0.15)
	await _screenshot("zombie_close")
	G.bot_mode = true
	player.targetable = true
	player._bot_target = null
	director.set_process(true)
	G.round_num = 3
	director.to_spawn = 6
	director.in_round = true
	await _wait(10.0)
	await _screenshot("fight")
	get_tree().quit()


## UI check: title screen, then the game with the touch controls, pause and game over.
func _run_ui_test() -> void:
	await _wait(1.5)
	await _screenshot("title")
	G.input_mode = "touch"
	G.input_mode_changed.emit("touch")
	_start_game()
	await _wait(5.0)
	await _screenshot("touch_hud")
	G.input_mode = "pad"
	G.input_mode_changed.emit("pad")
	_toggle_pause()
	await _wait(0.5)
	await _screenshot("pause")
	_resume()
	G.god_mode = false
	player.take_hit(500.0, player.global_position + Vector3(1, 0, 0))
	await _wait(2.5)
	await _screenshot("game_over")
	get_tree().quit()


## Weapon view check: hip / aimed, reload phases, hit markers, HUD size and margins.
func _run_view_test() -> void:
	director.set_process(false)
	await _wait(1.0)
	_pose(Vector3(0, 0, 3), Vector3(-2.5, 1.5, -7))
	for id in ["vipere", "faucon", "grele", "p9"]:
		player.give_weapon(id, false, false)
		player.debug_ads = false
		await _wait(0.6)
		await _screenshot(id + "_hip")
		player.debug_ads = true
		await _wait(0.6)
		await _screenshot(id + "_ads")
	player.debug_ads = false
	for id in ["faucon", "grele", "machoire", "taureau"]:
		player.give_weapon(id, false, false)
		await _wait(0.5)
		var w := player.current_weapon()
		w.mag = 0
		player.start_reload()
		var t := player._reload_t
		for frac in [0.2, 0.35, 0.5, 0.65, 0.78]:
			await _wait(t * (frac - (0.0 if frac == 0.2 else [0.2, 0.35, 0.5, 0.65, 0.78][[0.2, 0.35, 0.5, 0.65, 0.78].find(frac) - 1])))
			await _screenshot("%s_reload_%d" % [id, int(frac * 100)])
		await _wait(t * 0.3)
	player.hit_confirmed.emit(false, false)
	await _wait(0.03)
	await _screenshot("hitmarker")
	player.hit_confirmed.emit(true, true)
	await _wait(0.03)
	await _screenshot("killmarker")
	G.settings.hud_scale = 0.8
	G.settings.hud_margin = 0.08
	G.round_num = 7
	hud._on_round_started(7)
	await _wait(2.0)
	await _screenshot("hud_small_margin")
	get_tree().quit()
