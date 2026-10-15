class_name Dog
extends Zombie
## "Molosse": a burning zombie dog of the special rounds. Appears inside the building in a flash,
## runs straight at the player, bites fast, and bursts into embers when killed.

var spawn_pos := Vector3.ZERO
var _legs: Array[Node3D] = []
var _jaw: Node3D
var _tail: Node3D
var _body: Node3D

static var _dog_skin: StandardMaterial3D
static var _dog_ember: StandardMaterial3D
static var _dog_eye: StandardMaterial3D


static func _init_dog_mats() -> void:
	if _dog_skin:
		return
	_dog_skin = StandardMaterial3D.new()
	_dog_skin.albedo_color = Color(0.11, 0.08, 0.07)
	_dog_skin.roughness = 0.9
	_dog_ember = StandardMaterial3D.new()
	_dog_ember.albedo_color = Color(1.0, 0.4, 0.1)
	_dog_ember.emission_enabled = true
	_dog_ember.emission = Color(1.0, 0.35, 0.05)
	_dog_ember.emission_energy_multiplier = 2.5
	_dog_eye = StandardMaterial3D.new()
	_dog_eye.albedo_color = Color(1.0, 0.2, 0.05)
	_dog_eye.emission_enabled = true
	_dog_eye.emission = Color(1.0, 0.15, 0.02)
	_dog_eye.emission_energy_multiplier = 5.0


func setup_dog(p_director: Node, p_player: Player, pos: Vector3, p_hp: float) -> void:
	director = p_director
	player = p_player
	spawn_pos = pos
	hp = p_hp
	kind = "dog"
	speed = randf_range(5.6, 6.4)
	attack_range = 1.25
	hit_range = 1.7
	# Three bites to go down without Cuirasse, one bite every 1.5 s at most.
	damage = 34.0
	attack_windup = 0.3
	attack_length = 1.5


func _make_body() -> void:
	var cs := CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = 0.38
	cap.height = 1.1
	cs.shape = cap
	cs.position.y = 0.55
	add_child(cs)


func _place() -> void:
	outside = false
	state = State.CHASE
	global_position = spawn_pos
	agent.avoidance_enabled = true
	_stuck_pos = spawn_pos
	if player:
		_face(player.global_position)


func aim_point() -> Vector3:
	return global_position + Vector3(0, 0.65, 0)


func is_head_hit(p: Vector3) -> bool:
	var local := to_local(p)
	return local.z < -0.4 and local.y > 0.5


func _build_model() -> void:
	_init_dog_mats()
	model = Node3D.new()
	model.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	add_child(model)
	_body = Node3D.new()
	model.add_child(_body)
	_body.position.y = 0.62
	_part(_body, Vector3(0, 0, 0), Vector3(0.36, 0.36, 0.95), _dog_skin)
	_part(_body, Vector3(0, 0.05, -0.38), Vector3(0.42, 0.42, 0.3), _dog_skin)
	# Glowing cracks along the back and flanks.
	_part(_body, Vector3(0, 0.185, 0.0), Vector3(0.08, 0.02, 0.7), _dog_ember)
	_part(_body, Vector3(0.185, 0.0, 0.1), Vector3(0.02, 0.12, 0.35), _dog_ember)
	_part(_body, Vector3(-0.185, 0.04, -0.05), Vector3(0.02, 0.1, 0.3), _dog_ember)
	_head = Node3D.new()
	_body.add_child(_head)
	_head.position = Vector3(0, 0.18, -0.55)
	_part(_head, Vector3(0, 0, -0.08), Vector3(0.28, 0.26, 0.3), _dog_skin)
	_part(_head, Vector3(0, -0.04, -0.3), Vector3(0.18, 0.13, 0.22), _dog_skin)
	_part(_head, Vector3(-0.08, 0.06, -0.235), Vector3(0.06, 0.04, 0.02), _dog_eye)
	_part(_head, Vector3(0.08, 0.06, -0.235), Vector3(0.06, 0.04, 0.02), _dog_eye)
	_part(_head, Vector3(-0.09, 0.17, 0.0), Vector3(0.06, 0.12, 0.05), _dog_skin)
	_part(_head, Vector3(0.09, 0.17, 0.0), Vector3(0.06, 0.12, 0.05), _dog_skin)
	_jaw = Node3D.new()
	_head.add_child(_jaw)
	_jaw.position = Vector3(0, -0.11, -0.2)
	_part(_jaw, Vector3(0, 0, -0.1), Vector3(0.16, 0.05, 0.2), _dog_skin)
	_part(_jaw, Vector3(0, 0.03, -0.12), Vector3(0.12, 0.02, 0.16), _dog_ember)
	for pos in [Vector3(-0.13, -0.1, -0.35), Vector3(0.13, -0.1, -0.35), Vector3(-0.13, -0.1, 0.35), Vector3(0.13, -0.1, 0.35)]:
		var leg := _limb(_body, pos, Vector3(0.1, 0.55, 0.1), _dog_skin)
		_legs.append(leg)
	_tail = Node3D.new()
	_body.add_child(_tail)
	_tail.position = Vector3(0, 0.1, 0.47)
	_part(_tail, Vector3(0, 0, 0.18), Vector3(0.05, 0.05, 0.36), _dog_skin)
	_tail.rotation.x = 0.5
	# Keep the zombie animation code happy: these exist on zombies.
	_torso = _body
	_arm_l = _legs[0]
	_arm_r = _legs[1]
	_leg_l = _legs[2]
	_leg_r = _legs[3]
	var light := OmniLight3D.new()
	light.light_color = Color(1.0, 0.4, 0.1)
	light.light_energy = 0.6
	light.omni_range = 2.2
	model.add_child(light)
	light.position = Vector3(0, 0.9, 0)
	_phase = randf() * TAU


func _attack_sound() -> void:
	G.play_at("bark", global_position + Vector3(0, 0.8, 0), get_parent(), 0.0, randf_range(0.9, 1.15))


func _die(_head: bool, _dir: Vector3) -> void:
	alive = false
	state = State.DEAD
	remove_from_group("zombies")
	collision_layer = 0
	collision_mask = 0
	agent.avoidance_enabled = false
	G.play_at("dog_death", global_position + Vector3(0, 0.6, 0), get_parent(), -2.0, randf_range(0.9, 1.1))
	Fx.blast(get_parent(), global_position + Vector3(0, 0.6, 0), 1.2, Color(1.0, 0.45, 0.1))
	Fx.blood(get_parent(), global_position + Vector3(0, 0.7, 0), Vector3.UP, true)
	if director:
		director.on_zombie_killed(self)
	var tw := create_tween()
	tw.set_process_mode(Tween.TWEEN_PROCESS_PHYSICS)
	tw.tween_property(model, "scale", Vector3(1.3, 0.05, 1.3), 0.18)
	tw.tween_callback(queue_free)


func _process(delta: float) -> void:
	if not alive:
		return
	var moving := state == State.CHASE and Vector2(velocity.x, velocity.z).length() > 0.5
	_phase += delta * (4.0 + (speed * 2.2 if moving else 0.0))
	_hit_kick = maxf(0.0, _hit_kick - delta * 3.0)
	var g := sin(_phase)
	var amp := 0.9 if moving else 0.08
	_legs[0].rotation.x = g * amp
	_legs[1].rotation.x = g * amp * 0.85
	_legs[2].rotation.x = -g * amp
	_legs[3].rotation.x = -g * amp * 0.85
	_body.position.y = 0.62 + (absf(cos(_phase)) * 0.07 if moving else 0.0)
	_body.rotation.x = cos(_phase) * 0.08 * (1.0 if moving else 0.2) - _hit_kick * 0.4
	_tail.rotation.y = sin(_phase * 1.7) * 0.6
	if state == State.ATTACK:
		var p := clampf(_attack_t / attack_windup, 0.0, 1.0)
		_jaw.rotation.x = 0.7 * sin(p * PI)
		_head.rotation.x = -0.3 * sin(p * PI)
	else:
		_jaw.rotation.x = 0.15 + 0.1 * sin(_phase * 2.0)
		_head.rotation.x = 0.0
	_groan_t -= delta
	if _groan_t <= 0.0:
		_groan_t = randf_range(2.0, 5.0)
		G.play_at("growl", global_position + Vector3(0, 0.7, 0), get_parent(), -3.0, randf_range(1.3, 1.6))
