class_name Brute
extends Zombie
## "Colosse": every tenth round a huge armoured zombie bursts into the building. Slow at first,
## furious once badly hurt. Insta-kill does nothing to it, the bomb and traps only bruise it,
## and it always leaves a bonus behind when it falls.

const SCALE := 1.45

var spawn_pos := Vector3.ZERO
var max_hp := 5000.0
var enraged := false
var _visor: StandardMaterial3D
var _light: OmniLight3D
var _roar_t := 4.0

static var _armor: StandardMaterial3D
static var _chain: StandardMaterial3D


static func _init_brute_mats() -> void:
	if _armor:
		return
	_armor = StandardMaterial3D.new()
	_armor.albedo_color = Color(0.55, 0.52, 0.48)
	_armor.metallic = 0.35
	_armor.roughness = 0.45
	_chain = StandardMaterial3D.new()
	_chain.albedo_color = Color(0.22, 0.2, 0.18)
	_chain.metallic = 0.8
	_chain.roughness = 0.5


func setup_brute(p_director: Node, p_player: Player, pos: Vector3, p_hp: float) -> void:
	director = p_director
	player = p_player
	spawn_pos = pos
	hp = p_hp
	max_hp = p_hp
	kind = "brute"
	speed = 2.0
	attack_range = 1.9
	hit_range = 2.6
	damage = 75.0
	attack_windup = 0.7
	attack_length = 1.8


func _make_body() -> void:
	var cs := CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = 0.55
	cap.height = 2.75
	cs.shape = cap
	cs.position.y = 1.375
	add_child(cs)


func _place() -> void:
	outside = false
	state = State.CHASE
	global_position = spawn_pos
	agent.radius = 0.7
	agent.height = 2.7
	agent.avoidance_enabled = true
	_stuck_pos = spawn_pos
	if player:
		_face(player.global_position)


func aim_point() -> Vector3:
	return global_position + Vector3(0, 1.85, 0)


func is_head_hit(p: Vector3) -> bool:
	return p.y - global_position.y > 2.4


func make_crawler() -> void:
	pass


func _build_model() -> void:
	super._build_model()
	_init_brute_mats()
	model.scale = Vector3(SCALE * 1.1, SCALE, SCALE * 1.1)
	# Helmet with a glowing slit, shoulder plates, a chest plate and a hanging chain.
	_visor = StandardMaterial3D.new()
	_visor.albedo_color = Color(1.0, 0.75, 0.2)
	_visor.emission_enabled = true
	_visor.emission = Color(1.0, 0.6, 0.1)
	_visor.emission_energy_multiplier = 5.0
	_part(_head, Vector3(0, 0.17, 0), Vector3(0.32, 0.34, 0.32), _armor)
	_part(_head, Vector3(0, 0.19, -0.165), Vector3(0.24, 0.045, 0.02), _visor)
	_part(_head, Vector3(0, 0.36, 0), Vector3(0.06, 0.06, 0.3), _armor)
	_part(_torso, Vector3(0, 0.38, -0.02), Vector3(0.52, 0.42, 0.32), _armor)
	_part(_torso, Vector3(-0.33, 0.62, 0), Vector3(0.24, 0.12, 0.3), _armor)
	_part(_torso, Vector3(0.33, 0.62, 0), Vector3(0.24, 0.12, 0.3), _armor)
	for i in 5:
		_part(_torso, Vector3(-0.2 + i * 0.1, 0.48 - i * 0.07, -0.17), Vector3(0.07, 0.04, 0.03), _chain)
	_part(_arm_r, Vector3(0, -0.62, 0), Vector3(0.2, 0.2, 0.2), _chain)
	_part(_arm_l, Vector3(0, -0.62, 0), Vector3(0.2, 0.2, 0.2), _chain)
	_light = OmniLight3D.new()
	_light.light_color = Color(1.0, 0.6, 0.15)
	_light.light_energy = 0.8
	_light.omni_range = 3.0
	_head.add_child(_light)
	_light.position = Vector3(0, 0.2, -0.4)


func _attack_sound() -> void:
	G.play_at("growl", global_position + Vector3(0, 2.4, 0), get_parent(), 2.0, randf_range(0.5, 0.6))


func _attack(delta: float) -> void:
	var was_done := _attack_hit_done
	super._attack(delta)
	if _attack_hit_done and not was_done:
		G.play_at("brute_smash", global_position - global_basis.z * 1.2, get_parent(), 0.0, randf_range(0.9, 1.05))
		if player and player.global_position.distance_to(global_position) < 6.0:
			player.shake(0.35)


func take_damage(amount: float, at: Vector3, dir: Vector3, head: bool, how: String, weapon_id: String) -> String:
	if not alive:
		return ""
	if how == "bomb":
		amount = minf(amount, max_hp * 0.25)
	elif how == "trap":
		amount = minf(amount, max_hp * 0.04)
	hp -= amount
	_hit_kick = 0.12
	Fx.blood(get_parent(), at, dir.lerp(Vector3.UP, 0.3), head)
	if not enraged and hp < max_hp * 0.5 and hp > 0.0:
		_enrage()
	if hp <= 0.0:
		G.add_points(500)
		G.kills += 1
		if head:
			G.headshots += 1
		G.record_kill(self, how, weapon_id, head)
		_die(head, dir)
		return "kill"
	if how != "bomb" and how != "trap":
		G.add_points(10)
	if head:
		G.play_at("headshot", at, get_parent(), -8.0, 0.7)
	return "hit"


func _enrage() -> void:
	enraged = true
	speed = 3.8
	attack_windup = 0.5
	_visor.albedo_color = Color(1.0, 0.15, 0.05)
	_visor.emission = Color(1.0, 0.1, 0.02)
	_light.light_color = Color(1.0, 0.15, 0.05)
	_light.light_energy = 1.4
	G.play_at("brute_roar", global_position + Vector3(0, 2.4, 0), get_parent(), 4.0, 1.1)
	if player and player.global_position.distance_to(global_position) < 12.0:
		player.shake(0.3)


func _die(head: bool, dir: Vector3) -> void:
	super._die(head, dir)
	_light.light_energy = 0.0
	G.play_at("brute_roar", global_position + Vector3(0, 2.0, 0), get_parent(), 3.0, 0.7)
	Fx.blast(get_parent(), global_position + Vector3(0, 1.4, 0), 2.2, Color(1.0, 0.5, 0.15))
	if director and director.has_method("on_brute_killed"):
		director.on_brute_killed(self)


func _process(delta: float) -> void:
	super._process(delta)
	if not alive:
		return
	# Heavy, swaying steps; arms hang low.
	if state == State.CHASE:
		_arm_l.rotation = Vector3(0.3 + sin(_phase) * 0.35, 0, 0.25)
		_arm_r.rotation = Vector3(0.3 - sin(_phase) * 0.35, 0, -0.25)
		_torso.rotation.x = -0.3 if enraged else -0.12
	_roar_t -= delta
	if _roar_t <= 0.0:
		_roar_t = randf_range(5.0, 9.0)
		G.play_at("brute_roar", global_position + Vector3(0, 2.4, 0), get_parent(), -2.0, randf_range(0.9, 1.1))
