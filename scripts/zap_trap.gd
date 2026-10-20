class_name ZapTrap
extends Interactable
## Electric barbed wire across a doorway. Needs the power; for 1000 points it fries every
## zombie walking through for 30 s (no points for those kills), then needs time to recharge.
## It hurts the player too.

const PRICE := 1000
const ACTIVE_TIME := 30.0
const COOLDOWN := 45.0
const TICK := 0.25

var door: BuyDoor
var zone := AABB()
var active_t := 0.0
var cool_t := 0.0
var _tick_t := 0.0
var _zap_t := 0.0
var _arc_t := 0.0
var _ends: Array[Vector3] = []   # pairs of emitter points (world)
var _segs: Array[MeshInstance3D] = []
var _lamp: StandardMaterial3D
var _light: OmniLight3D
var _arc_mat: StandardMaterial3D
var _seg_mesh: BoxMesh
var _had_power := false

const SEGS_PER_ARC := 7


## `panel_pos` / `inward`: the switch on the wall. `a` and `b`: the bottoms of the two posts
## on either side of the doorway.
func build(panel_pos: Vector3, inward: Vector3, a: Vector3, b: Vector3, p_door: BuyDoor, metal: Material) -> void:
	door = p_door
	global_position = panel_pos + inward * 0.9
	focus_point = panel_pos
	var on_x := absf(inward.z) > 0.5
	setup_zone(Vector3(1.8, 2.0, 1.6) if on_x else Vector3(1.6, 2.0, 1.8))
	# The killing zone: the doorway between the posts, a little thick.
	var lo := Vector3(minf(a.x, b.x), 0.0, minf(a.z, b.z))
	var hi := Vector3(maxf(a.x, b.x), 2.2, maxf(a.z, b.z))
	var thick := Vector3(0.7, 0, 0) if absf(a.x - b.x) < 0.1 else Vector3(0, 0, 0.7)
	zone = AABB(lo - thick, hi - lo + thick * 2.0)

	var holder := Node3D.new()
	add_child(holder)
	holder.global_position = panel_pos
	holder.look_at(panel_pos - inward, Vector3.UP)
	_box(holder, Vector3(0, 0, 0.1), Vector3(0.55, 0.7, 0.2), metal)
	var warn := StandardMaterial3D.new()
	warn.albedo_color = Color(0.95, 0.8, 0.1)
	_box(holder, Vector3(0, 0.27, 0.205), Vector3(0.5, 0.1, 0.02), warn)
	_lamp = StandardMaterial3D.new()
	_lamp.emission_enabled = true
	_lamp.emission_energy_multiplier = 3.0
	var lamp := _box(holder, Vector3(0, 0.05, 0.215), Vector3(0.12, 0.12, 0.03), _lamp)
	lamp.name = "Lamp"
	var label := Label3D.new()
	label.text = "PIÈGE\n%d" % PRICE
	label.font_size = 40
	label.pixel_size = 0.004
	label.outline_size = 8
	label.modulate = Color(0.6, 0.85, 1.0)
	label.outline_modulate = Color(0, 0, 0)
	holder.add_child(label)
	label.position = Vector3(0, 0.6, 0.22)

	var post_mat := StandardMaterial3D.new()
	post_mat.albedo_color = Color(0.25, 0.25, 0.27)
	post_mat.metallic = 0.6
	var coil := StandardMaterial3D.new()
	coil.albedo_color = Color(0.7, 0.45, 0.2)
	coil.metallic = 0.8
	coil.roughness = 0.35
	for p in [a, b]:
		_box(self, p + Vector3(0, 1.0, 0) - global_position, Vector3(0.1, 2.0, 0.1), post_mat).set_meta("merge", true)
		for h in [0.35, 0.95, 1.55]:
			_box(self, p + Vector3(0, h, 0) - global_position, Vector3(0.16, 0.12, 0.16), coil).set_meta("merge", true)
	for h in [0.35, 0.95, 1.55]:
		_ends.append(a + Vector3(0, h, 0))
		_ends.append(b + Vector3(0, h, 0))
	# Barbed wire strands, always there.
	var wire := StandardMaterial3D.new()
	wire.albedo_color = Color(0.35, 0.33, 0.3)
	wire.metallic = 0.7
	for i in range(0, _ends.size(), 2):
		var w := MeshInstance3D.new()
		var wm := BoxMesh.new()
		wm.size = Vector3(0.015, 0.015, 1.0)
		w.mesh = wm
		w.material_override = wire
		add_child(w)
		_place_seg(w, _ends[i] + Vector3(0, -0.06, 0), _ends[i + 1] + Vector3(0, -0.06, 0))

	_arc_mat = StandardMaterial3D.new()
	_arc_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_arc_mat.albedo_color = Color(0.75, 0.9, 1.0)
	_seg_mesh = BoxMesh.new()
	_seg_mesh.size = Vector3(0.035, 0.035, 1.0)
	for i in (_ends.size() / 2) * SEGS_PER_ARC:
		var s := MeshInstance3D.new()
		s.mesh = _seg_mesh
		s.material_override = _arc_mat
		s.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		s.visible = false
		add_child(s)
		_segs.append(s)
	_light = OmniLight3D.new()
	_light.light_color = Color(0.5, 0.75, 1.0)
	_light.light_energy = 0.0
	_light.omni_range = 5.0
	add_child(_light)
	_light.global_position = (a + b) / 2.0 + Vector3(0, 1.2, 0)
	_set_lamp()


func _box(parent: Node3D, pos: Vector3, size: Vector3, mat: Material) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	mi.material_override = mat
	parent.add_child(mi)
	mi.position = pos
	return mi


func _place_seg(mi: Node3D, p: Vector3, q: Vector3) -> void:
	var d := q - p
	var length := d.length()
	if length < 0.001:
		mi.visible = false
		return
	var up := Vector3.UP if absf(d.normalized().y) < 0.95 else Vector3.RIGHT
	var basis := Basis.looking_at(d, up) * Basis.from_scale(Vector3(1, 1, length))
	mi.global_transform = Transform3D(basis, (p + q) / 2.0)


func is_active() -> bool:
	return active_t > 0.0


func get_hint(_player: Node) -> String:
	if not G.power_on:
		return "Piège électrique : pas de courant"
	if door and door.enabled:
		return "Piège électrique : ouvrez d'abord la porte"
	if active_t > 0.0:
		return ""
	if cool_t > 0.0:
		return "Piège électrique : recharge (%d s)" % ceili(cool_t)
	return "%s activer le piège électrique %s" % [use_text(), price_text(PRICE)]


func interact(_player: Node) -> void:
	if not G.power_on or active_t > 0.0 or cool_t > 0.0 or (door and door.enabled):
		return
	if not G.spend(PRICE):
		return
	active_t = ACTIVE_TIME
	_tick_t = 0.0
	G.play_at("zap", global_position, get_parent(), 2.0, 0.8)
	G.play_at("power_on", global_position, get_parent(), -4.0, 1.4)
	_set_lamp()


func _set_lamp() -> void:
	var c := Color(0.25, 0.25, 0.25)
	if G.power_on:
		c = Color(0.3, 0.7, 1.0) if active_t > 0.0 else (Color(1.0, 0.25, 0.1) if cool_t > 0.0 else Color(0.2, 1.0, 0.3))
	_lamp.albedo_color = c
	_lamp.emission = c


func _physics_process(delta: float) -> void:
	if cool_t > 0.0:
		cool_t -= delta
		if cool_t <= 0.0:
			_set_lamp()
	if active_t <= 0.0:
		return
	active_t -= delta
	if active_t <= 0.0:
		cool_t = COOLDOWN
		_light.light_energy = 0.0
		for s in _segs:
			s.visible = false
		_set_lamp()
		return
	_tick_t -= delta
	if _tick_t > 0.0:
		return
	_tick_t = TICK
	for z in get_tree().get_nodes_in_group("zombies"):
		var zz := z as Zombie
		if zz == null or not zz.alive or not zone.has_point(zz.global_position + Vector3(0, 0.5, 0)):
			continue
		var at := zz.aim_point()
		zz.take_damage(zz.hp + 1.0, at, Vector3.UP, false, "trap", "")
		Fx.blast(get_parent(), at, 0.5, Color(0.6, 0.85, 1.0))
		G.play_at("zap", at, get_parent(), 0.0, randf_range(0.9, 1.2))
	var player := get_tree().get_first_node_in_group("player") as Player
	if player and zone.has_point(player.global_position + Vector3(0, 0.5, 0)):
		player.take_hit(35.0, player.global_position + Vector3(0, 1, 0))


func _process(delta: float) -> void:
	_set_lamp_power()
	if active_t <= 0.0:
		return
	_zap_t -= delta
	if _zap_t <= 0.0:
		_zap_t = randf_range(0.25, 0.6)
		G.play_at("zap", _ends[randi() % _ends.size()], get_parent(), -6.0, randf_range(0.8, 1.3))
	_arc_t -= delta
	if _arc_t > 0.0:
		return
	_arc_t = 0.05
	_light.light_energy = randf_range(1.0, 2.5)
	# Jagged arcs between each pair of emitters, redrawn many times a second.
	var k := 0
	for i in range(0, _ends.size(), 2):
		var p := _ends[i]
		var q := _ends[i + 1]
		var prev := p
		for j in SEGS_PER_ARC:
			var f := float(j + 1) / SEGS_PER_ARC
			var nxt := p.lerp(q, f)
			if j < SEGS_PER_ARC - 1:
				nxt += Vector3(randf_range(-0.08, 0.08), randf_range(-0.14, 0.14), randf_range(-0.08, 0.08))
			var s := _segs[k]
			s.visible = randf() > 0.06
			_place_seg(s, prev, nxt)
			prev = nxt
			k += 1



## The lamp goes from grey to green when the power comes on.
func _set_lamp_power() -> void:
	if G.power_on != _had_power:
		_had_power = G.power_on
		_set_lamp()
