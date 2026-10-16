class_name Throwable
extends Node3D
## A thrown grenade or decoy. Simple ballistic flight with bounces off the world, then:
## grenade — explodes after its fuse; decoy — plays music for a while, attracting the zombies,
## then explodes much harder.

const GRAVITY := 14.0
const RADIUS := 0.08

var kind := "grenade"
var velocity := Vector3.ZERO
var director: Node
var _fuse := 2.2
var _resting := false
var _lure_t := 0.0
var _light: OmniLight3D
var _blink := 0.0
var _music: AudioStreamPlayer3D
var _mesh: Node3D

static var _mats := {}


static func _mat(name: String, c: Color, emit := false) -> StandardMaterial3D:
	if not _mats.has(name):
		var m := StandardMaterial3D.new()
		m.albedo_color = c
		m.roughness = 0.6
		if emit:
			m.emission_enabled = true
			m.emission = c
			m.emission_energy_multiplier = 3.0
		_mats[name] = m
	return _mats[name]


func setup(p_kind: String, p_velocity: Vector3, p_director: Node) -> void:
	kind = p_kind
	velocity = p_velocity
	director = p_director
	_fuse = 2.2 if kind == "grenade" else 1.0


func _ready() -> void:
	_mesh = Node3D.new()
	add_child(_mesh)
	if kind == "grenade":
		var body := MeshInstance3D.new()
		var sm := SphereMesh.new()
		sm.radius = 0.07
		sm.height = 0.16
		body.mesh = sm
		body.material_override = _mat("grenade", Color(0.18, 0.24, 0.12))
		_mesh.add_child(body)
		var cap := MeshInstance3D.new()
		var cm := CylinderMesh.new()
		cm.top_radius = 0.025
		cm.bottom_radius = 0.025
		cm.height = 0.05
		cap.mesh = cm
		cap.material_override = _mat("cap", Color(0.5, 0.5, 0.5))
		cap.position.y = 0.09
		_mesh.add_child(cap)
	else:
		# Decoy: a little tin drummer-box with a glowing dial.
		var box := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = Vector3(0.14, 0.18, 0.12)
		box.mesh = bm
		box.material_override = _mat("decoy", Color(0.75, 0.15, 0.12))
		_mesh.add_child(box)
		var dial := MeshInstance3D.new()
		var dm := BoxMesh.new()
		dm.size = Vector3(0.08, 0.08, 0.13)
		dial.mesh = dm
		dial.material_override = _mat("decoy_glow", Color(1.0, 0.85, 0.3), true)
		dial.position.y = 0.03
		_mesh.add_child(dial)
	_light = OmniLight3D.new()
	_light.light_color = Color(1, 0.2, 0.1) if kind == "grenade" else Color(1.0, 0.8, 0.3)
	_light.light_energy = 0.0
	_light.omni_range = 2.5
	add_child(_light)
	if kind == "decoy":
		add_to_group("lures")


## Zombies go for this while it plays.
func is_luring() -> bool:
	return kind == "decoy" and _resting and _lure_t > 0.0


func _physics_process(delta: float) -> void:
	if not _resting:
		velocity.y -= GRAVITY * delta
		var from := global_position
		var to := from + velocity * delta
		var space := get_world_3d().direct_space_state
		var q := PhysicsRayQueryParameters3D.create(from, to + velocity.normalized() * RADIUS, G.L_WORLD)
		var hit := space.intersect_ray(q)
		if hit.is_empty():
			global_position = to
			_mesh.rotation += Vector3(7.0, 3.0, 0.0) * delta
		else:
			var n: Vector3 = hit.normal
			global_position = hit.position + n * RADIUS
			velocity = velocity.bounce(n) * 0.4
			if n.y > 0.7:
				velocity.x *= 0.6
				velocity.z *= 0.6
			if velocity.length() > 1.5:
				G.play_at("plank_place", global_position, get_parent(), -12.0, 1.8)
			if n.y > 0.7 and velocity.length() < 1.2:
				_resting = true
				velocity = Vector3.ZERO
				_mesh.rotation = Vector3(0, _mesh.rotation.y, 0)
				if kind == "decoy":
					_start_lure()
	_tick(delta)


func _start_lure() -> void:
	_lure_t = 8.0
	_music = AudioStreamPlayer3D.new()
	_music.stream = G.sound("decoy")
	_music.unit_size = 8.0
	_music.max_distance = 50.0
	add_child(_music)
	_music.play()


func _tick(delta: float) -> void:
	_blink += delta
	if kind == "grenade":
		_fuse -= delta
		_light.light_energy = 1.5 if fmod(_blink, 0.5 if _fuse > 0.8 else 0.18) < 0.08 else 0.0
		if _fuse <= 0.0:
			_explode(4.5, 250.0 + 40.0 * G.round_num, "grenade")
	elif _resting:
		_lure_t -= delta
		_light.light_energy = 1.2 + 0.8 * sin(_blink * 10.0)
		_mesh.position.y = 0.09 + absf(sin(_blink * 9.0)) * 0.04
		if _lure_t <= 0.0:
			_explode(5.5, 100000.0, "grenade")


func _explode(radius: float, damage: float, how: String) -> void:
	set_physics_process(false)
	var pos := global_position + Vector3(0, 0.3, 0)
	Fx.blast(get_parent(), pos, radius * 0.6, Color(1.0, 0.55, 0.15))
	G.play_at("grenade_explode", pos, get_parent(), 2.0, randf_range(0.9, 1.1))
	var player := get_tree().get_first_node_in_group("player") as Player
	if player:
		var d := player.global_position.distance_to(pos)
		if d < radius * 2.0:
			player.shake(clampf(1.0 - d / (radius * 2.0), 0.0, 1.0) * 0.5)
	var any_hit := false
	var any_kill := false
	for z in get_tree().get_nodes_in_group("zombies"):
		var zz := z as Zombie
		if zz == null or not zz.alive:
			continue
		var target := zz.aim_point()
		var dist := target.distance_to(pos)
		if dist > radius:
			continue
		# Walls stop the blast.
		var q := PhysicsRayQueryParameters3D.create(pos, target, G.L_WORLD)
		if not get_world_3d().direct_space_state.intersect_ray(q).is_empty():
			continue
		var dmg := damage * (1.0 - 0.6 * dist / radius)
		var res := zz.take_damage(dmg, target, (target - pos).normalized(), false, how, "")
		any_hit = any_hit or res != ""
		any_kill = any_kill or res == "kill"
		if res == "hit" and director and director.has_method("maybe_crawler"):
			director.maybe_crawler(zz)
	if player and any_hit:
		player.hit_confirmed.emit(any_kill, false)
	queue_free()
