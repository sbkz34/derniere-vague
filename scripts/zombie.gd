class_name Zombie
extends CharacterBody3D
## A zombie: walks up to a window from outside, tears the planks off, climbs in, then chases the
## player through the navigation mesh and attacks at close range.

enum State { APPROACH, TEAR, VAULT, CHASE, ATTACK, DEAD }

const HEAD_Y := 1.56
var attack_range := 1.35
var hit_range := 1.85
var damage := 50.0
var attack_windup := 0.45
var attack_length := 1.1

var state := State.APPROACH
var alive := true
var outside := true
var hp := 150.0
var speed := 1.3
var kind := "walk"   # walk, jog, run, crawl
## Legs blown off by an explosion: drags itself along the floor.
var crawler := false
var window: Barricade
var slot := 0
var director: Node
var player: Player

var agent: NavigationAgent3D
var model: Node3D
var _torso: Node3D
var _head: Node3D
var _arm_l: Node3D
var _arm_r: Node3D
var _leg_l: Node3D
var _leg_r: Node3D
var _phase := 0.0
var _tear_t := 0.0
var _vault_t := 0.0
var _vault_from := Vector3.ZERO
var _attack_t := 0.0
var _attack_hit_done := false
var _repath := 0.0
var _groan_t := 0.0
var _hit_kick := 0.0
var _stuck_t := 0.0
var _stuck_count := 0
var _stuck_pos := Vector3.ZERO
var _approach_from := Vector3.ZERO
var _approach_t := 0.0
var _approach_len := 1.0
var _desired := Vector3.ZERO

static var _mats_skin: Array[StandardMaterial3D] = []
static var _mats_cloth: Array[StandardMaterial3D] = []
static var _mats_pants: Array[StandardMaterial3D] = []
static var _mat_eye: StandardMaterial3D
static var _mat_blood: StandardMaterial3D
static var _meshes := {}


static func _init_shared() -> void:
	if _mat_eye:
		return
	for c in [Color(0.42, 0.5, 0.38), Color(0.5, 0.52, 0.45), Color(0.38, 0.42, 0.4), Color(0.55, 0.48, 0.4)]:
		var m := StandardMaterial3D.new()
		m.albedo_color = c
		m.roughness = 0.9
		_mats_skin.append(m)
	for c in [Color(0.25, 0.2, 0.15), Color(0.18, 0.22, 0.28), Color(0.35, 0.33, 0.3), Color(0.3, 0.12, 0.1), Color(0.15, 0.18, 0.12)]:
		var m := StandardMaterial3D.new()
		m.albedo_color = c
		m.roughness = 1.0
		_mats_cloth.append(m)
	for c in [Color(0.12, 0.12, 0.16), Color(0.22, 0.18, 0.12), Color(0.1, 0.1, 0.1)]:
		var m := StandardMaterial3D.new()
		m.albedo_color = c
		m.roughness = 1.0
		_mats_pants.append(m)
	_mat_eye = StandardMaterial3D.new()
	_mat_eye.albedo_color = Color(1.0, 0.65, 0.1)
	_mat_eye.emission_enabled = true
	_mat_eye.emission = Color(1.0, 0.55, 0.05)
	_mat_eye.emission_energy_multiplier = 4.0
	_mat_blood = StandardMaterial3D.new()
	_mat_blood.albedo_color = Color(0.3, 0.02, 0.02)
	_mat_blood.roughness = 0.5


static func _mesh(size: Vector3) -> BoxMesh:
	var key := str(size)
	if not _meshes.has(key):
		var bm := BoxMesh.new()
		bm.size = size
		_meshes[key] = bm
	return _meshes[key]


func setup(p_director: Node, p_player: Player, p_window: Barricade, p_slot: int, p_hp: float, p_kind: String) -> void:
	director = p_director
	player = p_player
	window = p_window
	slot = p_slot
	hp = p_hp
	kind = p_kind
	match kind:
		"walk":
			speed = randf_range(1.1, 1.5)
		"jog":
			speed = randf_range(2.4, 2.9)
		_:
			speed = randf_range(4.0, 4.6)


func _ready() -> void:
	_init_shared()
	add_to_group("zombies")
	collision_layer = G.L_ZOMBIE
	collision_mask = G.L_WORLD
	_make_body()
	agent = NavigationAgent3D.new()
	agent.path_desired_distance = 0.6
	agent.target_desired_distance = 0.9
	agent.radius = 0.45
	agent.height = 1.8
	agent.max_speed = 7.0
	agent.neighbor_distance = 3.0
	agent.max_neighbors = 6
	agent.time_horizon_agents = 0.8
	agent.avoidance_enabled = false
	add_child(agent)
	agent.velocity_computed.connect(_on_velocity_computed)
	_build_model()
	_place()
	reset_physics_interpolation()
	_groan_t = randf_range(1.0, 5.0)


func _make_body() -> void:
	var cs := CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = 0.33
	cap.height = 1.9
	cs.shape = cap
	cs.position.y = 0.95
	add_child(cs)


## Start further out in the fog and walk up to the window.
func _place() -> void:
	var lateral := window.along * randf_range(-3.0, 3.0)
	_approach_from = window.outside_point(slot) - window.inward * randf_range(7.0, 10.0) + lateral
	_approach_from.y = -0.02
	global_position = _approach_from
	var target := window.outside_point(slot)
	_approach_len = max(0.5, _approach_from.distance_to(target) / max(speed, 1.2))
	_face(target)


## Where the player's aim assist and the bot aim (chest height).
func aim_point() -> Vector3:
	if crawler:
		return global_position + Vector3(0, 0.35, 0) - global_basis.z * 0.45
	return global_position + Vector3(0, 1.25, 0)


func _build_model() -> void:
	model = Node3D.new()
	model.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	add_child(model)
	var skin: StandardMaterial3D = _mats_skin.pick_random()
	var cloth: StandardMaterial3D = _mats_cloth.pick_random()
	var pants: StandardMaterial3D = _mats_pants.pick_random()
	var s := randf_range(0.93, 1.07)
	model.scale = Vector3(s, s, s)
	_leg_l = _limb(model, Vector3(-0.13, 0.95, 0), Vector3(0.17, 0.92, 0.18), pants)
	_leg_r = _limb(model, Vector3(0.13, 0.95, 0), Vector3(0.17, 0.92, 0.18), pants)
	_torso = Node3D.new()
	model.add_child(_torso)
	_torso.position.y = 0.95
	_part(_torso, Vector3(0, 0.32, 0), Vector3(0.46, 0.64, 0.26), cloth)
	if randf() < 0.6:
		_part(_torso, Vector3(randf_range(-0.12, 0.12), 0.25, -0.135), Vector3(0.14, 0.18, 0.02), _mat_blood)
	_head = Node3D.new()
	_torso.add_child(_head)
	_head.position.y = 0.66
	_part(_head, Vector3(0, 0.15, 0), Vector3(0.26, 0.3, 0.27), skin)
	_part(_head, Vector3(-0.065, 0.18, -0.136), Vector3(0.06, 0.035, 0.02), _mat_eye)
	_part(_head, Vector3(0.065, 0.18, -0.136), Vector3(0.06, 0.035, 0.02), _mat_eye)
	_part(_head, Vector3(0, 0.06, -0.136), Vector3(0.12, 0.04, 0.02), _mat_blood)
	_arm_l = _limb(_torso, Vector3(-0.31, 0.58, 0), Vector3(0.13, 0.66, 0.13), skin)
	_arm_r = _limb(_torso, Vector3(0.31, 0.58, 0), Vector3(0.13, 0.66, 0.13), skin)
	# Torn sleeves.
	_part(_arm_l, Vector3(0, -0.1, 0), Vector3(0.15, 0.22, 0.15), cloth)
	_part(_arm_r, Vector3(0, -0.1, 0), Vector3(0.15, 0.22, 0.15), cloth)
	_phase = randf() * TAU


func _limb(parent: Node3D, pivot: Vector3, size: Vector3, mat: Material) -> Node3D:
	var n := Node3D.new()
	parent.add_child(n)
	n.position = pivot
	_part(n, Vector3(0, -size.y / 2, 0), size, mat)
	return n


func _part(parent: Node3D, pos: Vector3, size: Vector3, mat: Material) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = _mesh(size)
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mi)
	mi.position = pos
	return mi


func _face(target: Vector3) -> void:
	var to := target - global_position
	to.y = 0
	if to.length() > 0.05:
		rotation.y = lerp_angle(rotation.y, atan2(-to.x, -to.z), 0.25)


func is_head_hit(p: Vector3) -> bool:
	if crawler:
		return to_local(p).z < -0.75
	return p.y - global_position.y > HEAD_Y * model.scale.y


## An explosion took the legs: slower, lower, weaker, and harder to hit.
func make_crawler() -> void:
	if crawler or not alive or outside:
		return
	crawler = true
	kind = "crawl"
	speed = randf_range(0.8, 1.0)
	attack_range = 1.3
	hit_range = 1.7
	damage = 40.0
	attack_windup = 0.6
	attack_length = 1.4
	_leg_l.visible = false
	_leg_r.visible = false
	for c in get_children():
		var cs := c as CollisionShape3D
		if cs:
			var cap := cs.shape as CapsuleShape3D
			cap.radius = 0.3
			cap.height = 1.5
			cs.rotation.x = PI / 2
			cs.position = Vector3(0, 0.3, -0.4)
	Fx.blood(get_parent(), global_position + Vector3(0, 0.5, 0), Vector3.UP, true)
	G.play_at("crawl", global_position + Vector3(0, 0.3, 0), get_parent(), -2.0)


## Returns "kill", "hit" or "" (already dead).
func take_damage(amount: float, at: Vector3, dir: Vector3, head: bool, how: String, weapon_id: String) -> String:
	if not alive:
		return ""
	if G.insta_kill_time > 0.0:
		amount = max(amount, hp + 1.0)
	hp -= amount
	_hit_kick = 0.35
	Fx.blood(get_parent(), at, dir.lerp(Vector3.UP, 0.3), head)
	if hp <= 0.0:
		var pts := 60
		if how == "knife":
			pts = 130
		elif head:
			pts = 100
		if how != "bomb" and how != "trap":
			G.add_points(pts)
		G.kills += 1
		if head:
			G.headshots += 1
		G.record_kill(self, how, weapon_id, head)
		_die(head, dir)
		return "kill"
	if how != "bomb" and how != "trap":
		G.add_points(10)
	if head:
		G.play_at("headshot", at, get_parent(), -6.0)
	return "hit"


func _die(head: bool, dir: Vector3) -> void:
	alive = false
	state = State.DEAD
	remove_from_group("zombies")
	collision_layer = 0
	collision_mask = 0
	agent.avoidance_enabled = false
	_release_window()
	G.play_at("zombie_death", global_position + Vector3(0, 1.2, 0), get_parent(), -4.0, randf_range(0.85, 1.15))
	if head:
		_head.visible = false
		Fx.blood(get_parent(), global_position + Vector3(0, 1.75, 0), Vector3.UP, true)
		G.play_at("headshot", global_position + Vector3(0, 1.7, 0), get_parent(), -2.0)
	if director:
		director.on_zombie_killed(self)
	# Fall over, backwards along the shot direction.
	var flat := Vector3(dir.x, 0, dir.z).normalized()
	if flat == Vector3.ZERO:
		flat = global_basis.z
	var local := global_basis.inverse() * flat
	var tw := create_tween()
	tw.set_process_mode(Tween.TWEEN_PROCESS_PHYSICS)
	tw.tween_property(model, "rotation", Vector3(1.5 * sign(local.z if abs(local.z) > 0.1 else 1.0), 0, -1.2 * local.x), 0.45).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.parallel().tween_property(model, "position", Vector3(local.x * 0.6, 0.15, local.z * 0.6), 0.45)
	tw.tween_interval(2.5)
	tw.tween_property(model, "position:y", -0.6, 1.5)
	tw.tween_callback(queue_free)


func _physics_process(delta: float) -> void:
	if not alive:
		return
	match state:
		State.APPROACH:
			_approach_t += delta
			var target := window.outside_point(slot)
			var p := clampf(_approach_t / _approach_len, 0.0, 1.0)
			global_position = _approach_from.lerp(Vector3(target.x, -0.02, target.z), p)
			_face(target)
			if p >= 1.0:
				state = State.TEAR
				_tear_t = randf_range(0.6, 1.4)
		State.TEAR:
			_face(window.center)
			if window.is_open():
				if not window.is_busy() and _front_of_queue():
					window.claim(self)
					state = State.VAULT
					_vault_t = 0.0
					_vault_from = global_position
			else:
				_tear_t -= delta
				if _tear_t <= 0.0:
					_tear_t = randf_range(1.2, 1.8) if kind == "walk" else randf_range(0.8, 1.2)
					if window.tear():
						_hit_kick = 0.4
		State.VAULT:
			_vault_t += delta
			var dur := 1.1 if kind == "walk" else 0.7
			var p := clampf(_vault_t / dur, 0.0, 1.0)
			var sill := window.center + Vector3(0, Barricade.SILL + 0.05, 0)
			var inside := window.inside_point()
			var a := _vault_from.lerp(sill, p)
			var b := sill.lerp(inside, p)
			global_position = a.lerp(b, p)
			_face(inside)
			if p >= 1.0:
				_release_window()
				outside = false
				state = State.CHASE
				agent.avoidance_enabled = true
				_stuck_pos = global_position
				_repath = 0.0
		State.CHASE:
			_chase(delta)
		State.ATTACK:
			_attack(delta)


## Frees the window if this zombie was the one climbing through it.
func _release_window() -> void:
	if window and window.climber == self:
		window.release()


func _front_of_queue() -> bool:
	# The waiting zombie closest to the window climbs first.
	var my_d := global_position.distance_to(window.center)
	for z in get_tree().get_nodes_in_group("zombies"):
		var zz := z as Zombie
		if zz and zz != self and zz.window == window and zz.state == State.TEAR:
			if zz.global_position.distance_to(window.center) < my_d - 0.01:
				return false
	return true


## A playing decoy within reach, if any: zombies go for it instead of the player.
func _active_lure() -> Node3D:
	for l in get_tree().get_nodes_in_group("lures"):
		var t := l as Throwable
		if t and t.is_luring() and t.global_position.distance_to(global_position) < 40.0:
			return t
	return null


func _chase(delta: float) -> void:
	var lure := _active_lure()
	if lure == null and (not player or not player.targetable):
		_desired = Vector3.ZERO
		_move(delta)
		return
	var to_player := player.global_position - global_position if player else Vector3(99, 0, 99)
	var flat_d := Vector2(to_player.x, to_player.z).length()
	if player and player.targetable and flat_d < attack_range and abs(to_player.y) < 1.5:
		state = State.ATTACK
		_attack_t = 0.0
		_attack_hit_done = false
		_attack_sound()
		return
	var goal: Vector3 = lure.global_position if lure else player.global_position
	var to_goal := goal - global_position
	var goal_d := Vector2(to_goal.x, to_goal.z).length()
	if lure and goal_d < 1.4:
		# Crowd around the decoy, clawing at it.
		_desired = Vector3.ZERO
		_face(goal)
		_hit_kick = maxf(_hit_kick, 0.15 * absf(sin(_phase * 3.0)))
		_move(delta)
		_stuck_t = 0.0
		return
	_repath -= delta
	if _repath <= 0.0:
		_repath = 0.25
		agent.target_position = goal
	var next := agent.get_next_path_position()
	var dir := next - global_position
	dir.y = 0
	if dir.length() < 0.05 or goal_d < 2.5:
		dir = Vector3(to_goal.x, 0, to_goal.z)
	_desired = dir.normalized() * speed
	_face(global_position + (_desired if _desired.length() > 0.1 else to_goal))
	_move(delta)
	# Unstick: if barely moving for a while far from the player, start over at a window.
	_stuck_t += delta
	if _stuck_t > 5.0:
		if global_position.distance_to(_stuck_pos) < 0.6:
			_stuck_count += 1
			# Far away: start over at a window. Close but blocked for a long time: same.
			if director and (goal_d > 4.0 or _stuck_count >= 3):
				director.respawn(self)
				return
		else:
			_stuck_count = 0
		_stuck_t = 0.0
		_stuck_pos = global_position


func _move(_delta: float) -> void:
	if agent.avoidance_enabled:
		agent.velocity = _desired
	else:
		_on_velocity_computed(_desired)


func _on_velocity_computed(safe: Vector3) -> void:
	if not alive or outside or state == State.VAULT:
		return
	velocity.x = safe.x
	velocity.z = safe.z
	if is_on_floor():
		velocity.y = -1.0
	else:
		velocity.y -= 18.0 * get_physics_process_delta_time()
	move_and_slide()


func _attack_sound() -> void:
	G.play_at("growl", global_position + Vector3(0, 1.6, 0), get_parent(), -2.0, randf_range(0.85, 1.2))


func _attack(delta: float) -> void:
	_attack_t += delta
	_desired = Vector3.ZERO
	_move(delta)
	if player:
		_face(player.global_position)
	if _attack_t > attack_windup and not _attack_hit_done:
		_attack_hit_done = true
		if player and player.targetable:
			var d := player.global_position - global_position
			if Vector2(d.x, d.z).length() < hit_range and abs(d.y) < 1.6:
				player.take_hit(damage, global_position)
	if _attack_t > attack_length:
		state = State.CHASE


func _process(delta: float) -> void:
	if not alive:
		return
	var moving := state == State.APPROACH or state == State.CHASE and Vector2(velocity.x, velocity.z).length() > 0.3
	var spd := speed if moving else 0.0
	_phase += delta * (2.2 + spd * 1.6)
	_hit_kick = maxf(0.0, _hit_kick - delta * 2.5)
	var swing := sin(_phase)
	var leg_amp := 0.0 if not moving else (0.35 if kind == "walk" else 0.8)
	_leg_l.rotation.x = swing * leg_amp
	_leg_r.rotation.x = -swing * leg_amp
	model.position.y = abs(cos(_phase)) * (0.04 if kind == "walk" else 0.08) if moving else 0.0
	match state:
		State.TEAR:
			var claw := sin(_phase * 2.5)
			_arm_l.rotation = Vector3(1.6 + claw * 0.5, 0, 0.1)
			_arm_r.rotation = Vector3(1.6 - claw * 0.5, 0, -0.1)
			_torso.rotation.x = -0.15
		State.ATTACK:
			var p := clampf(_attack_t / 0.45, 0.0, 1.0)
			var swipe := sin(p * PI)
			_arm_l.rotation = Vector3(1.2 + 1.2 * swipe, 0, 0.2 - 0.6 * swipe)
			_arm_r.rotation = Vector3(1.2 + 1.2 * swipe, 0, -0.2 + 0.6 * swipe)
			_torso.rotation.x = -0.25 * swipe
		State.VAULT:
			_arm_l.rotation = Vector3(2.4, 0, 0.2)
			_arm_r.rotation = Vector3(2.4, 0, -0.2)
			_torso.rotation.x = -0.6
		_:
			if kind == "run":
				_arm_l.rotation = Vector3(0.4 - swing * 0.9, 0, 0.15)
				_arm_r.rotation = Vector3(0.4 + swing * 0.9, 0, -0.15)
				_torso.rotation.x = -0.35
			else:
				_arm_l.rotation = Vector3(1.45 + sin(_phase * 0.5) * 0.1, 0, 0.05)
				_arm_r.rotation = Vector3(1.35 + cos(_phase * 0.5) * 0.1, 0, -0.05)
				_torso.rotation.x = -0.12 if kind == "walk" else -0.25
	if crawler:
		# Lying on the belly, pulling forward with alternate arms.
		var pull := sin(_phase * 1.4)
		model.position.y = 0.0
		_torso.position.y = 0.28
		_torso.rotation.x = -1.42
		_arm_l.rotation = Vector3(2.1 + pull * 0.45, 0, 0.25)
		_arm_r.rotation = Vector3(2.1 - pull * 0.45, 0, -0.25)
		_head.rotation.x = 1.1
		if state == State.ATTACK:
			var p := clampf(_attack_t / attack_windup, 0.0, 1.0)
			_arm_r.rotation.x = 2.1 + 0.9 * sin(p * PI)
	_torso.rotation.x -= _hit_kick * 0.6
	_torso.rotation.z = sin(_phase * 0.5) * 0.06
	_head.rotation.z = sin(_phase * 0.35) * 0.15
	_groan_t -= delta
	if _groan_t <= 0.0:
		_groan_t = randf_range(3.0, 8.0)
		G.play_at(["groan1", "groan2", "groan3"].pick_random(), global_position + Vector3(0, 1.6, 0), get_parent(), -6.0, randf_range(0.8, 1.2))
