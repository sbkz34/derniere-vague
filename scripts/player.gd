class_name Player
extends CharacterBody3D
## First-person player: movement, looking (mouse, gamepad, touch), weapons, knife, perks,
## health and interaction with the world.

signal died
signal downed_changed(is_down: bool)
signal weapons_changed
signal perks_changed
signal hurt(from_dir: Vector3, amount: float)
signal hit_confirmed(kill: bool, head: bool)

const MAX_WEAPONS := 2
const BASE_FOV := 75.0
const WALK := 4.6
const SPRINT := 6.9
const GRAVITY := 18.0
const JUMP := 6.0
const KNIFE_DMG := 150.0

var director: Node
var level: Level
var touch: Node    # TouchControls, gives move / look / buttons on phones

var head: Node3D
var cam: Camera3D
var view: WeaponView
var reach: Area3D

var inv: Array[Dictionary] = []
var cur := 0
var perks: Array[String] = []
var second_souffle_bought := 0

var max_hp := 100.0
var hp := 100.0
var downed := false
var dead := false
var targetable := true
var _regen_wait := 0.0
var _invuln := 0.0   # short grace after a hit, so several bites at once cannot stack

var _yaw := 0.0
var _pitch := 0.0
var _fire_cd := 0.0
var _reload_t := 0.0
var _swap_t := 0.0
var _knife_t := 0.0
var _drink_t := 0.0
var _drink_perk := ""
var _ads_held := false
var _ads_prev := false
var _sprinting := false
var _stamina := 4.0
var _step_dist := 0.0
var _was_on_floor := true
var _shake := 0.0
var _snap_t := 0.0
var _snap_yaw := 0.0
var _snap_pitch := 0.0
var _semi_ready := true
var _down_t := 0.0
var interact_target: Interactable
var hint := ""

# Bot mode (automated test): aims at the nearest zombie and fires.
var _bot_target: Node3D
var _bot_retarget := 0.0
var debug_ads := false   # tests: hold aim


func _ready() -> void:
	add_to_group("player")
	collision_layer = G.L_PLAYER
	collision_mask = G.L_WORLD | G.L_ZOMBIE | G.L_PLAYER_BLOCK
	floor_snap_length = 0.3
	var cs := CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = 0.35
	cap.height = 1.8
	cs.shape = cap
	cs.position.y = 0.9
	add_child(cs)
	head = Node3D.new()
	head.position.y = 1.62
	head.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	add_child(head)
	cam = Camera3D.new()
	cam.fov = BASE_FOV
	cam.near = 0.03
	cam.far = 120.0
	head.add_child(cam)
	view = WeaponView.new()
	cam.add_child(view)
	reach = Area3D.new()
	reach.collision_layer = 0
	reach.collision_mask = G.L_INTERACT
	reach.monitoring = true
	reach.monitorable = false
	var rs := CollisionShape3D.new()
	var sp := SphereShape3D.new()
	sp.radius = 0.4
	rs.shape = sp
	reach.add_child(rs)
	reach.position.y = 1.0
	add_child(reach)
	give_weapon("p9", 0, false)


func spawn_at(p: Vector3, yaw: float) -> void:
	global_position = p
	_yaw = yaw
	_pitch = 0.0
	rotation.y = _yaw
	reset_physics_interpolation()


# ------------------------------------------------------------------------------------------------
# Weapons API (used by wall buys, the box and the forge)
# ------------------------------------------------------------------------------------------------
func current_weapon() -> Dictionary:
	if inv.is_empty():
		return {}
	return inv[cur]


func has_weapon(id: String) -> bool:
	for w in inv:
		if w.id == id:
			return true
	return false


func get_weapon(id: String) -> Dictionary:
	for w in inv:
		if w.id == id:
			return w
	return {}


func ammo_full(id: String) -> bool:
	var w := get_weapon(id)
	if w.is_empty():
		return false
	return w.reserve >= G.stat(w, "reserve") and w.mag >= G.stat(w, "mag")


func refill_ammo(id: String) -> void:
	var w := get_weapon(id)
	if w.is_empty():
		return
	w.reserve = G.stat(w, "reserve")
	weapons_changed.emit()


func refill_all() -> void:
	for w in inv:
		w.reserve = G.stat(w, "reserve")
	weapons_changed.emit()


func give_weapon(id: String, tier: int, animate := true) -> void:
	var w := G.new_weapon(id, tier)
	for i in inv.size():
		if inv[i].id == id:
			inv[i] = w
			cur = i
			_equip(animate)
			return
	if inv.size() < MAX_WEAPONS:
		inv.append(w)
		cur = inv.size() - 1
	else:
		inv[cur] = w
	_equip(animate)
	if animate:
		G.say(G.weapon_name(w), Color(0.9, 0.9, 0.8))


func remove_current_weapon() -> void:
	if inv.is_empty():
		return
	inv.remove_at(cur)
	cur = clamp(cur, 0, max(0, inv.size() - 1))
	_equip(true)


func _equip(animate: bool) -> void:
	_reload_t = 0.0
	_swap_t = 0.5 if animate else 0.0
	view.set_weapon(current_weapon(), animate)
	weapons_changed.emit()


## Switching weapons cancels a reload in progress (the magazine stays as it was).
func swap_weapon() -> void:
	if inv.size() < 2 or _swap_t > 0.0 or _knife_t > 0.0 or _drink_t > 0.0 or downed:
		return
	cur = (cur + 1) % inv.size()
	_equip(true)


# ------------------------------------------------------------------------------------------------
# Perks
# ------------------------------------------------------------------------------------------------
func has_perk(id: String) -> bool:
	return perks.has(id)


func can_drink() -> bool:
	return not downed and not dead and _drink_t <= 0.0


func drink_perk(id: String) -> void:
	_drink_perk = id
	_drink_t = 1.7
	_reload_t = 0.0
	view.set_bottle_color(G.PERKS[id].color)
	view.play_anim("drink", 1.7)
	G.play("perk", -3.0)


func _finish_drink() -> void:
	var id := _drink_perk
	_drink_perk = ""
	if id == "" or perks.has(id):
		return
	perks.append(id)
	if id == "cuirasse":
		max_hp = 250.0
		hp = max_hp
	if id == "second_souffle":
		second_souffle_bought += 1
	perks_changed.emit()
	G.say(G.PERKS[id].name, G.PERKS[id].color)


func reload_time() -> float:
	var w := current_weapon()
	return float(G.stat(w, "reload")) * (0.5 if has_perk("main_leste") else 1.0)


# ------------------------------------------------------------------------------------------------
# Health
# ------------------------------------------------------------------------------------------------
func take_hit(amount: float, from: Vector3) -> void:
	if downed or dead or G.god_mode or _invuln > 0.0:
		return
	_invuln = 0.5
	hp -= amount
	_regen_wait = 2.8
	_shake = 0.25
	G.play("hurt", 0.0, randf_range(0.9, 1.1))
	G.vibrate(0.6, 0.8, 0.25)
	hurt.emit((from - global_position).normalized(), amount)
	if hp <= 0.0:
		hp = 0.0
		if has_perk("second_souffle"):
			_go_down()
		else:
			_die()


func _go_down() -> void:
	downed = true
	targetable = false
	_down_t = 4.0
	_reload_t = 0.0
	_ads_held = false
	downed_changed.emit(true)
	G.say("Second Souffle…", G.PERKS["second_souffle"].color)


func _revive() -> void:
	downed = false
	targetable = true
	perks.clear()
	max_hp = 100.0
	hp = max_hp
	perks_changed.emit()
	downed_changed.emit(false)
	G.say("Debout !", Color(0.6, 1, 1))


func _die() -> void:
	dead = true
	targetable = false
	died.emit()


# ------------------------------------------------------------------------------------------------
# Per-frame
# ------------------------------------------------------------------------------------------------
func _unhandled_input(event: InputEvent) -> void:
	if not G.playing or get_tree().paused or dead:
		return
	if event is InputEventMouseMotion and event.device != InputEvent.DEVICE_ID_EMULATION:
		if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
			var sens: float = G.settings.sens_mouse * (0.6 if _ads_amount() > 0.5 else 1.0)
			var d: Vector2 = event.relative * sens
			_look(d.x, d.y)
	elif event is InputEventMouseButton and event.pressed and event.device != InputEvent.DEVICE_ID_EMULATION:
		if Input.mouse_mode != Input.MOUSE_MODE_CAPTURED and not OS.has_feature("mobile"):
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _look(dx_deg: float, dy_deg: float) -> void:
	if G.settings.invert_y:
		dy_deg = -dy_deg
	_yaw -= deg_to_rad(dx_deg)
	_pitch = clamp(_pitch - deg_to_rad(dy_deg), deg_to_rad(-85), deg_to_rad(85))
	view.add_sway(Vector2(dx_deg, dy_deg))
	_snap_t = 0.0


func _ads_amount() -> float:
	return view.ads


func _busy() -> bool:
	return _reload_t > 0.0 or _swap_t > 0.0 or _knife_t > 0.0 or _drink_t > 0.0 or downed


func _process(delta: float) -> void:
	if not G.playing or dead:
		return
	_update_look(delta)
	_update_timers(delta)
	_update_interaction(delta)
	_update_weapon(delta)
	# Health regeneration.
	if not downed and hp < max_hp:
		_regen_wait -= delta
		if _regen_wait <= 0.0:
			hp = min(max_hp, hp + max_hp * 0.6 * delta)
	if downed:
		_down_t -= delta
		if _down_t <= 0.0:
			_revive()
	# Camera: shake, aim-down-sights zoom, lowered when downed.
	var w := current_weapon()
	var target_fov := BASE_FOV
	if not w.is_empty():
		target_fov = lerp(BASE_FOV, float(G.WEAPONS[w.id].ads_fov), view.ads)
	cam.fov = lerp(cam.fov, target_fov, clamp(delta * 14.0, 0.0, 1.0))
	_shake = max(0.0, _shake - delta)
	var shake_off := Vector3(randf_range(-1, 1), randf_range(-1, 1), 0) * _shake * 0.03
	head.position = head.position.lerp(Vector3(0, 0.55 if downed else 1.62, 0), clamp(delta * 6.0, 0.0, 1.0))
	head.rotation = Vector3(_pitch, 0, 0) + shake_off
	rotation.y = _yaw
	var hspeed := Vector2(velocity.x, velocity.z).length()
	view.hidden_by_scope = (not w.is_empty() and G.WEAPONS[w.id].kind == "sniper" and view.ads > 0.85)
	view.update_view(delta, hspeed, _sprinting, is_on_floor())


func _update_look(delta: float) -> void:
	var sens_scale := 0.55 if _ads_amount() > 0.5 else 1.0
	var assist := 1.0
	if G.settings.aim_assist and G.input_mode != "kbm" and _crosshair_on_zombie():
		assist = 0.55
	# Gamepad right stick with a response curve.
	var stick := Input.get_vector("look_left", "look_right", "look_up", "look_down")
	if stick.length() > 0.0:
		var mag := stick.length()
		var curved := stick.normalized() * pow(mag, 1.8)
		var rate: float = 210.0 * float(G.settings.sens_pad) * sens_scale * assist
		_look(curved.x * rate * delta, curved.y * rate * 0.75 * delta)
	# Touch look.
	if touch and touch.visible:
		var d: Vector2 = touch.consume_look()
		if d != Vector2.ZERO:
			var k: float = 0.22 * float(G.settings.sens_touch) * sens_scale * assist
			_look(d.x * k, d.y * k)
	# Aim snap when starting to aim (gamepad / touch).
	var ads_now := _ads_input()
	if ads_now and not _ads_prev and G.settings.aim_assist and G.input_mode != "kbm":
		_start_snap()
	_ads_prev = ads_now
	if _snap_t > 0.0:
		_snap_t -= delta
		var k := clampf(delta * 16.0, 0.0, 1.0)
		_yaw = lerp_angle(_yaw, _snap_yaw, k)
		_pitch = lerp(_pitch, _snap_pitch, k)
	if G.bot_mode:
		_bot_aim(delta)


func _ads_input() -> bool:
	if debug_ads:
		return true
	if G.bot_mode:
		return _bot_target != null
	var held := Input.is_action_pressed("ads")
	if touch and touch.visible:
		held = held or touch.ads
	return held


func _fire_input() -> bool:
	if G.bot_mode:
		return _bot_target != null and _bot_on_target()
	var held := Input.is_action_pressed("fire")
	if touch and touch.visible:
		held = held or touch.fire
	return held


func _update_timers(delta: float) -> void:
	_fire_cd -= delta
	_invuln = maxf(0.0, _invuln - delta)
	if _swap_t > 0.0:
		_swap_t -= delta
	if _knife_t > 0.0:
		_knife_t -= delta
	if _drink_t > 0.0:
		_drink_t -= delta
		if _drink_t <= 0.0:
			_finish_drink()
	if _reload_t > 0.0:
		_reload_t -= delta
		if _reload_t <= 0.0:
			var w := current_weapon()
			if not w.is_empty():
				var need: int = int(G.stat(w, "mag")) - int(w.mag)
				var take: int = min(need, int(w.reserve))
				w.mag += take
				w.reserve -= take
				weapons_changed.emit()


func _update_interaction(delta: float) -> void:
	interact_target = null
	hint = ""
	if downed:
		return
	var best: Interactable = null
	var best_dot := -2.0
	var fwd := -cam.global_basis.z
	for a in reach.get_overlapping_areas():
		var it := a as Interactable
		if it == null or not it.enabled:
			continue
		var h := it.get_hint(self)
		if h == "":
			continue
		var to := (it.focus_point - cam.global_position).normalized()
		var d := fwd.dot(to)
		if d > best_dot:
			best_dot = d
			best = it
	if best and best_dot > -0.2:
		interact_target = best
		hint = best.get_hint(self)
	var pressed := Input.is_action_just_pressed("interact")
	var held := Input.is_action_pressed("interact")
	var use_pressed := Input.is_action_just_pressed("use")
	var use_held := Input.is_action_pressed("use")
	if touch and touch.visible:
		pressed = pressed or touch.action_pressed
		held = held or touch.action
	if interact_target:
		if interact_target.is_hold():
			if held or use_held:
				interact_target.hold(self, delta)
		elif pressed or use_pressed:
			interact_target.interact(self)
	elif use_pressed:
		start_reload()
	if touch and touch.visible:
		touch.action_pressed = false


func start_reload() -> void:
	var w := current_weapon()
	if w.is_empty() or _busy():
		return
	if w.mag >= G.stat(w, "mag") or w.reserve <= 0:
		return
	_reload_t = reload_time()
	_ads_held = false
	view.play_reload(_reload_t, w.mag == 0, int(G.stat(w, "mag")) - int(w.mag))


func _update_weapon(delta: float) -> void:
	var w := current_weapon()
	var ads_in := _ads_input() and not _busy() and not w.is_empty()
	view.ads = move_toward(view.ads, 1.0 if ads_in else 0.0, delta * 6.0)
	if Input.is_action_just_pressed("reload") or (touch and touch.visible and touch.reload_pressed):
		start_reload()
	if touch and touch.visible:
		touch.reload_pressed = false
	if Input.is_action_just_pressed("swap") or (touch and touch.visible and touch.swap_pressed):
		swap_weapon()
	if touch and touch.visible:
		touch.swap_pressed = false
	var knife: bool = Input.is_action_just_pressed("knife") or (touch and touch.visible and touch.knife_pressed)
	if touch and touch.visible:
		touch.knife_pressed = false
	if G.bot_mode and _bot_target and global_position.distance_to(_bot_target.global_position) < 1.6:
		knife = true
	if knife and _knife_t <= 0.0 and not downed and _drink_t <= 0.0:
		_do_knife()
	var firing := _fire_input()
	if not firing:
		_semi_ready = true
	if w.is_empty() or _busy() or _sprinting and not firing:
		return
	if firing and _fire_cd <= 0.0:
		var auto: bool = G.WEAPONS[w.id].auto
		if not auto and not _semi_ready:
			return
		_semi_ready = false
		if w.mag <= 0:
			G.play("dryfire", -4.0)
			_fire_cd = 0.25
			if w.reserve > 0:
				start_reload()
			return
		_sprinting = false
		_shoot(w)
		if w.mag <= 0 and w.reserve > 0:
			start_reload()


func _shoot(w: Dictionary) -> void:
	var stats: Dictionary = G.WEAPONS[w.id]
	w.mag -= 1
	var rof: float = G.stat(w, "rof")
	if has_perk("double_detente"):
		rof *= 0.75
	_fire_cd = rof
	var spread: float = lerp(float(G.stat(w, "spread")), float(G.stat(w, "ads_spread")), view.ads)
	var moving := Vector2(velocity.x, velocity.z).length() > 1.0
	if moving:
		spread *= 1.4
	if not is_on_floor():
		spread *= 1.5
	var pellets: int = stats.pellets
	var origin := cam.global_position
	var basis := cam.global_basis
	var any_hit := false
	var any_kill := false
	var any_head := false
	for i in pellets:
		var r := deg_to_rad(spread) * sqrt(randf())
		var a := randf() * TAU
		var dir := (-basis.z + basis.x * tan(r) * cos(a) + basis.y * tan(r) * sin(a)).normalized()
		var res := _fire_ray(origin, dir, w)
		any_hit = any_hit or res.hit
		any_kill = any_kill or res.kill
		any_head = any_head or res.head
	if any_hit:
		hit_confirmed.emit(any_kill, any_head)
		G.play("killmarker" if any_kill else "hitmarker", -4.0, randf_range(0.97, 1.03))
	# Recoil.
	var kick: float = stats.kick * (0.5 if view.ads > 0.5 else 1.0)
	_pitch = clamp(_pitch + deg_to_rad(kick * 0.35), deg_to_rad(-85), deg_to_rad(85))
	_yaw += deg_to_rad(randf_range(-0.15, 0.15) * kick)
	view.shot(kick)
	G.play(stats.sound, -3.0, randf_range(0.95, 1.05) * (1.0 - 0.07 * int(w.up)))
	G.vibrate(0.25, 0.1 + 0.05 * kick, 0.08)
	weapons_changed.emit()


func _fire_ray(origin: Vector3, dir: Vector3, w: Dictionary) -> Dictionary:
	var out := {"hit": false, "kill": false, "head": false}
	var space := get_world_3d().direct_space_state
	var exclude: Array[RID] = [get_rid()]
	var pierce: int = G.stat(w, "pierce")
	var from := origin
	var to := origin + dir * 90.0
	var is_wonder: bool = G.WEAPONS[w.id].kind == "wonder"
	var end_point := to
	while true:
		var q := PhysicsRayQueryParameters3D.create(from, to, G.L_WORLD | G.L_ZOMBIE, exclude)
		var hit := space.intersect_ray(q)
		if hit.is_empty():
			break
		var col: Object = hit.collider
		end_point = hit.position
		if col is Zombie:
			var z := col as Zombie
			var head := z.is_head_hit(hit.position)
			var dmg: float = G.stat(w, "dmg") * (float(G.WEAPONS[w.id].hs) if head else 1.0)
			var res := z.take_damage(dmg, hit.position, dir, head, "gun", w.id)
			out.hit = true
			out.kill = out.kill or res == "kill"
			out.head = out.head or head
			if is_wonder:
				break
			if pierce <= 0:
				break
			pierce -= 1
			exclude.append(z.get_rid())
			from = hit.position
		else:
			Fx.impact(get_parent(), hit.position, hit.normal)
			break
	if is_wonder:
		_wonder_blast(end_point, w)
		Fx.beam(get_parent(), view.muzzle_global(), end_point, _wonder_color(w))
	return out


func _wonder_color(w: Dictionary) -> Color:
	return [Color(0.3, 1.0, 0.5), Color(1.0, 0.3, 0.9), Color(1.0, 0.8, 0.25), Color(1.0, 0.2, 0.1)][clampi(int(w.up), 0, 3)]


func _wonder_blast(pos: Vector3, w: Dictionary) -> void:
	var radius: float = G.WEAPONS[w.id].splash
	var dmg: float = G.stat(w, "splash_dmg")
	Fx.blast(get_parent(), pos, radius, _wonder_color(w))
	for z in get_tree().get_nodes_in_group("zombies"):
		var zz := z as Zombie
		if zz and zz.alive and zz.global_position.distance_to(pos) < radius + 0.5:
			zz.take_damage(dmg, zz.global_position + Vector3(0, 1.0, 0), (zz.global_position - pos).normalized(), false, "gun", w.id)


func _do_knife() -> void:
	_knife_t = 0.55
	_reload_t = 0.0
	view.play_anim("knife", 0.45)
	G.play("knife", -2.0, randf_range(0.9, 1.1))
	var fwd := -cam.global_basis.z
	var best: Zombie = null
	var best_d := 2.3
	for z in get_tree().get_nodes_in_group("zombies"):
		var zz := z as Zombie
		if zz == null or not zz.alive:
			continue
		var to := zz.aim_point() - cam.global_position
		var d := to.length()
		if d < best_d and fwd.dot(to.normalized()) > 0.55:
			best = zz
			best_d = d
	if best:
		var res := best.take_damage(KNIFE_DMG, best.aim_point(), fwd, false, "knife", "")
		hit_confirmed.emit(res == "kill", false)
		G.play("hit", 0.0)
		G.play("killmarker" if res == "kill" else "hitmarker", -4.0)


func _crosshair_on_zombie() -> bool:
	var space := get_world_3d().direct_space_state
	var q := PhysicsRayQueryParameters3D.create(cam.global_position, cam.global_position - cam.global_basis.z * 40.0, G.L_WORLD | G.L_ZOMBIE, [get_rid()])
	var hit := space.intersect_ray(q)
	return not hit.is_empty() and hit.collider is Zombie


func _start_snap() -> void:
	var best: Zombie = null
	var best_ang := deg_to_rad(11.0)
	var fwd := -cam.global_basis.z
	for z in get_tree().get_nodes_in_group("zombies"):
		var zz := z as Zombie
		if zz == null or not zz.alive:
			continue
		var target := zz.aim_point()
		var to := target - cam.global_position
		if to.length() > 30.0:
			continue
		var ang := fwd.angle_to(to.normalized())
		if ang < best_ang and _line_of_sight(target):
			best_ang = ang
			best = zz
	if best:
		var to := (best.aim_point() - cam.global_position).normalized()
		_snap_yaw = atan2(-to.x, -to.z)
		_snap_pitch = asin(clamp(to.y, -1.0, 1.0))
		_snap_t = 0.14


func _line_of_sight(target: Vector3) -> bool:
	var space := get_world_3d().direct_space_state
	var q := PhysicsRayQueryParameters3D.create(cam.global_position, target, G.L_WORLD, [get_rid()])
	return space.intersect_ray(q).is_empty()


func _physics_process(delta: float) -> void:
	if not G.playing or dead:
		return
	var input := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	if touch and touch.visible:
		var tm: Vector2 = touch.move
		if tm.length() > input.length():
			input = tm
	if G.bot_mode:
		input = _bot_move()
	if downed:
		input = Vector2.ZERO
	var w := current_weapon()
	var wspeed: float = 1.0 if w.is_empty() else float(G.WEAPONS[w.id].speed)
	var fast := has_perk("pied_leger")
	# Sprint: hold Shift, click the left stick, or push the touch stick to the edge.
	var want_sprint: bool = Input.is_action_pressed("sprint") or (touch and touch.visible and touch.sprint)
	if Input.is_action_just_pressed("sprint") and G.input_mode == "pad":
		_sprinting = not _sprinting
	elif G.input_mode != "pad":
		_sprinting = want_sprint
	if input.y > -0.3 or view.ads > 0.3 or _reload_t > 0.0 and not fast:
		_sprinting = false
	if _sprinting and not fast:
		_stamina -= delta
		if _stamina <= 0.0:
			_sprinting = false
	else:
		_stamina = min(4.0, _stamina + delta * 0.8)
	var speed := (SPRINT if _sprinting else WALK) * wspeed * (1.15 if fast else 1.0)
	speed *= lerp(1.0, 0.55, view.ads)
	var dir := (global_basis * Vector3(input.x, 0, input.y))
	dir.y = 0
	var target_v := dir * speed
	var accel := 12.0 if is_on_floor() else 3.0
	velocity.x = move_toward(velocity.x, target_v.x, accel * speed * delta)
	velocity.z = move_toward(velocity.z, target_v.z, accel * speed * delta)
	if is_on_floor():
		var jump: bool = Input.is_action_just_pressed("jump") or (touch and touch.visible and touch.jump_pressed)
		if jump and not downed:
			velocity.y = JUMP
	else:
		velocity.y -= GRAVITY * delta
	if touch and touch.visible:
		touch.jump_pressed = false
	move_and_slide()
	# Footsteps and landing.
	var hs := Vector2(velocity.x, velocity.z).length()
	if is_on_floor() and hs > 1.0:
		_step_dist += hs * delta
		if _step_dist > (2.4 if _sprinting else 1.9):
			_step_dist = 0.0
			G.play("step", -14.0, randf_range(0.85, 1.15))
	if is_on_floor() and not _was_on_floor:
		G.play("jump_land", -10.0)
	_was_on_floor = is_on_floor()


# ------------------------------------------------------------------------------------------------
# Bot (automated playtest): walks to keep some distance, turns towards the nearest zombie, fires.
# ------------------------------------------------------------------------------------------------
func _bot_pick() -> void:
	_bot_target = null
	var best := 1e9
	for z in get_tree().get_nodes_in_group("zombies"):
		var zz := z as Zombie
		if zz == null or not zz.alive:
			continue
		var d := global_position.distance_to(zz.global_position)
		if d < best and _line_of_sight(zz.aim_point()):
			best = d
			_bot_target = zz


func _bot_aim(delta: float) -> void:
	_bot_retarget -= delta
	if _bot_retarget <= 0.0 or _bot_target == null or not is_instance_valid(_bot_target) or not (_bot_target as Zombie).alive:
		_bot_retarget = 0.3
		_bot_pick()
	if _bot_target == null:
		var w := current_weapon()
		if not w.is_empty() and w.mag < G.stat(w, "mag"):
			start_reload()
		return
	var to := ((_bot_target as Zombie).aim_point() - cam.global_position).normalized()
	var k := clampf(delta * 10.0, 0.0, 1.0)
	_yaw = lerp_angle(_yaw, atan2(-to.x, -to.z), k)
	_pitch = lerp(_pitch, asin(clamp(to.y, -1.0, 1.0)), k)


func _bot_on_target() -> bool:
	if _bot_target == null or not is_instance_valid(_bot_target):
		return false
	var to := ((_bot_target as Zombie).aim_point() - cam.global_position).normalized()
	return (-cam.global_basis.z).angle_to(to) < deg_to_rad(4.0)


func _bot_move() -> Vector2:
	if _bot_target == null or not is_instance_valid(_bot_target):
		return Vector2.ZERO
	return Vector2.ZERO
