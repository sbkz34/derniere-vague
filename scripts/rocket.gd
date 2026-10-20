class_name Rocket
extends Node3D
## Rocket from the launcher: flies straight, leaves smoke, and explodes on the first wall or
## zombie it touches. A direct hit adds the weapon damage to the blast. Walls stop the blast,
## explosions can leave crawlers, and standing too close hurts.

const LIFE := 4.0

var weapon: Dictionary = {}
var velocity := Vector3.ZERO
var player: Player
var director: Node
var _life := LIFE
var _trail: CPUParticles3D
var _done := false

static var _body_mat: StandardMaterial3D
static var _fire_mat: StandardMaterial3D
static var _smoke_mat: StandardMaterial3D
static var _smoke_mesh: BoxMesh


func setup(p_weapon: Dictionary, p_velocity: Vector3, p_player: Player, p_director: Node) -> void:
	weapon = p_weapon
	velocity = p_velocity
	player = p_player
	director = p_director


static func _init_mats() -> void:
	if _body_mat:
		return
	_body_mat = StandardMaterial3D.new()
	_body_mat.albedo_color = Color(0.3, 0.33, 0.24)
	_body_mat.roughness = 0.6
	_fire_mat = StandardMaterial3D.new()
	_fire_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_fire_mat.albedo_color = Color(1.0, 0.7, 0.3)
	_smoke_mat = StandardMaterial3D.new()
	_smoke_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_smoke_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_smoke_mat.vertex_color_use_as_albedo = true
	_smoke_mesh = BoxMesh.new()
	_smoke_mesh.size = Vector3(0.12, 0.12, 0.12)


func _color() -> Color:
	var tier := int(weapon.get("up", 0))
	return Color(1.0, 0.55, 0.15) if tier == 0 else G.tier_color(tier)


func _ready() -> void:
	_init_mats()
	physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	var body := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = 0.035
	cm.bottom_radius = 0.045
	cm.height = 0.42
	body.mesh = cm
	body.material_override = _body_mat
	body.rotation.x = -PI / 2
	add_child(body)
	var flame := MeshInstance3D.new()
	var fm := SphereMesh.new()
	fm.radius = 0.06
	fm.height = 0.16
	flame.mesh = fm
	var fire := _fire_mat.duplicate() as StandardMaterial3D
	fire.albedo_color = _color().lerp(Color(1, 1, 0.8), 0.3)
	flame.material_override = fire
	flame.position.z = 0.26
	add_child(flame)
	var light := OmniLight3D.new()
	light.light_color = _color()
	light.light_energy = 2.0
	light.omni_range = 3.5
	add_child(light)
	light.position.z = 0.3
	_trail = CPUParticles3D.new()
	_trail.amount = 48
	_trail.lifetime = 0.7
	_trail.local_coords = false
	_trail.mesh = _smoke_mesh
	_trail.material_override = _smoke_mat
	_trail.gravity = Vector3(0, 0.6, 0)
	_trail.direction = Vector3(0, 0, 1)
	_trail.spread = 25.0
	_trail.initial_velocity_min = 0.3
	_trail.initial_velocity_max = 0.8
	_trail.scale_amount_min = 0.6
	_trail.scale_amount_max = 1.6
	var ramp := Gradient.new()
	var smoke := Color(0.55, 0.53, 0.5, 0.55)
	if int(weapon.get("up", 0)) >= G.MAX_TIER:
		smoke = Color(0.75, 0.12, 0.08, 0.6)
	ramp.set_color(0, smoke)
	ramp.set_color(1, Color(smoke.r, smoke.g, smoke.b, 0.0))
	_trail.color_ramp = ramp
	_trail.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_trail)
	_trail.position.z = 0.3
	_trail.emitting = true


func _physics_process(delta: float) -> void:
	if _done:
		return
	_life -= delta
	var from := global_position
	var to := from + velocity * delta
	var exclude: Array[RID] = []
	if player:
		exclude.append(player.get_rid())
	var q := PhysicsRayQueryParameters3D.create(from, to + velocity.normalized() * 0.15, G.L_WORLD | G.L_ZOMBIE, exclude)
	var hit := get_world_3d().direct_space_state.intersect_ray(q)
	if not hit.is_empty():
		var n: Vector3 = hit.normal
		_explode(hit.position + n * 0.15, hit.collider as Zombie)
		return
	global_position = to
	if _life <= 0.0:
		_explode(global_position, null)


func _explode(pos: Vector3, direct: Zombie) -> void:
	_done = true
	var parent := get_parent()
	var radius: float = G.WEAPONS[weapon.id].splash
	var blast_dmg: float = G.stat(weapon, "splash_dmg")
	Fx.blast(parent, pos, radius * 0.7, _color())
	Fx.blast(parent, pos, radius * 0.35, Color(1.0, 0.9, 0.6))
	G.play_at("grenade_explode", pos, parent, 3.0, randf_range(0.8, 0.95))
	var any_hit := false
	var any_kill := false
	var space := get_world_3d().direct_space_state
	for z in get_tree().get_nodes_in_group("zombies"):
		var zz := z as Zombie
		if zz == null or not zz.alive:
			continue
		var target := zz.aim_point()
		var d := target.distance_to(pos)
		var dmg := 0.0
		if zz == direct:
			dmg += float(G.stat(weapon, "dmg"))
		if d <= radius:
			var q := PhysicsRayQueryParameters3D.create(pos, target, G.L_WORLD)
			if space.intersect_ray(q).is_empty():
				dmg += blast_dmg * (1.0 - 0.6 * d / radius)
		if dmg <= 0.0:
			continue
		var res := zz.take_damage(dmg, target, (target - pos).normalized(), false, "rocket", weapon.id)
		any_hit = any_hit or res != ""
		any_kill = any_kill or res == "kill"
		if res == "hit" and director and director.has_method("maybe_crawler"):
			director.maybe_crawler(zz)
	if player:
		var pd := player.global_position.distance_to(pos)
		if pd < radius * 2.0:
			player.shake(clampf(1.0 - pd / (radius * 2.0), 0.0, 1.0) * 0.6)
		# Too close: the blast hurts (not a one-shot).
		if pd < 3.0:
			player.take_hit(15.0 + 25.0 * (1.0 - pd / 3.0), pos)
		if any_hit:
			player.hit_confirmed.emit(any_kill, false)
			G.play("killmarker" if any_kill else "hitmarker", -4.0)
	# Let the smoke trail fade out on its own.
	if _trail:
		var tp := _trail.global_transform
		remove_child(_trail)
		parent.add_child(_trail)
		_trail.global_transform = tp
		_trail.emitting = false
		var t := parent.get_tree().create_timer(1.0)
		var trail := _trail
		t.timeout.connect(func(): if is_instance_valid(trail): trail.queue_free())
	queue_free()
