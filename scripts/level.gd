class_name Level
extends Node3D
## Builds the map in code: four rooms (Hall, Atelier, Réserve, Laboratoire), boarded windows,
## doors to buy, wall weapons, perk machines, the mystery box and the upgrade forge.
## The interior lives under a NavigationRegion3D that is re-baked when a door opens.

signal nav_ready
signal room_unlocked(room: String)

const H := 3.4
const T := 0.3

const ROOMS := {
	"hall": {"name": "Hall", "min": Vector2(-7, -7), "max": Vector2(7, 7)},
	"atelier": {"name": "Atelier", "min": Vector2(7, -6), "max": Vector2(19, 7)},
	"reserve": {"name": "Réserve", "min": Vector2(-7, 7), "max": Vector2(7, 21)},
	"labo": {"name": "Laboratoire", "min": Vector2(7, 7), "max": Vector2(19, 21)},
}

## The rooms of this map (the Bunker's by default; other maps set their own).
var rooms: Dictionary = ROOMS
## Outdoor spots where zombies climb out of the ground (none in the Bunker).
var ground_spawns: Array[GroundSpawn] = []
## Camera spots for the lobby's live view: [position, look at].
var preview_spots: Array = [
	[Vector3(1.5, 1.8, 4.5), Vector3(-2.5, 1.3, -7.0)],
	[Vector3(10.5, 1.9, 4.0), Vector3(16.5, 0.9, -5.5)],
	[Vector3(11.0, 1.9, 15.5), Vector3(18.2, 1.3, 10.0)],
	[Vector3(1.0, 1.9, 9.5), Vector3(4.6, 1.3, 20.4)],
]
## Title screen camera: drifts around `menu_orbit[0]` looking towards `menu_orbit[1]`.
var menu_orbit: Array = [Vector3(1.5, 1.9, 3.5), Vector3(-2.5, 1.5, -7.0)]
var nav: NavigationRegion3D
var windows: Array[Barricade] = []
var doors: Array[BuyDoor] = []
var unlocked := {"hall": true, "atelier": false, "reserve": false, "labo": false}
var player_start := Vector3(0, 0.2, 2.0)
var lights: Array[OmniLight3D] = []
var _flicker: OmniLight3D
var power_switch: PowerSwitch
var trap: ZapTrap
var _power_t := 0.0
var _baking := false
var env: Environment
var moon: DirectionalLight3D
var _bake_again := false

var m_concrete: StandardMaterial3D
var m_brick: StandardMaterial3D
var m_tiles: StandardMaterial3D
var m_floor_concrete: StandardMaterial3D
var m_wood: StandardMaterial3D
var m_wood_floor: StandardMaterial3D
var m_metal: StandardMaterial3D
var m_dirt: StandardMaterial3D
var m_ceiling: StandardMaterial3D
var m_chalk: StandardMaterial3D
var m_board: StandardMaterial3D
var m_bark: StandardMaterial3D
var m_bulb: StandardMaterial3D


func _tex_mat(path: String, tint := Color(1, 1, 1), scale := 0.4, rough := 0.9) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_texture = load(path)
	m.albedo_color = tint
	m.uv1_triplanar = true
	m.uv1_world_triplanar = true
	m.uv1_scale = Vector3(scale, scale, scale)
	m.roughness = rough
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	return m


func _make_materials() -> void:
	m_concrete = _tex_mat("res://assets/tex/concrete.png", Color(0.95, 0.93, 0.88))
	m_brick = _tex_mat("res://assets/tex/brick.png", Color(0.9, 0.85, 0.85), 0.5)
	m_tiles = _tex_mat("res://assets/tex/tiles.png", Color(1, 1, 1), 0.33, 0.6)
	m_floor_concrete = _tex_mat("res://assets/tex/concrete.png", Color(0.6, 0.6, 0.58), 0.3)
	m_wood = _tex_mat("res://assets/tex/wood.png", Color(1, 1, 1), 0.8, 0.8)
	m_wood.uv1_world_triplanar = false
	m_wood_floor = _tex_mat("res://assets/tex/wood.png", Color(0.75, 0.7, 0.65), 0.35, 0.7)
	m_metal = _tex_mat("res://assets/tex/metal.png", Color(1, 1, 1), 0.6, 0.5)
	m_metal.metallic = 0.3
	m_dirt = _tex_mat("res://assets/tex/dirt.png", Color(0.8, 0.8, 0.8), 0.15)
	m_ceiling = _tex_mat("res://assets/tex/concrete.png", Color(0.35, 0.35, 0.36), 0.3)
	m_bark = StandardMaterial3D.new()
	m_bark.albedo_color = Color(0.1, 0.08, 0.07)
	m_bark.roughness = 1.0
	m_chalk = StandardMaterial3D.new()
	m_chalk.albedo_color = Color(0.92, 0.92, 0.86)
	m_chalk.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m_board = StandardMaterial3D.new()
	m_board.albedo_color = Color(0.06, 0.08, 0.07)
	m_board.roughness = 0.95
	m_bulb = StandardMaterial3D.new()
	m_bulb.albedo_color = Color(1, 0.9, 0.7)
	m_bulb.emission_enabled = true
	m_bulb.emission = Color(1, 0.8, 0.5)
	m_bulb.emission_energy_multiplier = 4.0


func build() -> void:
	_make_materials()
	_environment()
	_make_nav()
	_floors_and_ceilings()
	_walls()
	_outside()
	_props()
	_lights()
	_windows()
	_doors()
	_buyables()
	merge_static()


## Called once the player and the director exist (maps with an objective need them).
func attach(_player: Node, _director: Node) -> void:
	pass


func _make_nav() -> void:
	nav = NavigationRegion3D.new()
	nav.name = "Nav"
	var nm := NavigationMesh.new()
	nm.geometry_parsed_geometry_type = NavigationMesh.PARSED_GEOMETRY_STATIC_COLLIDERS
	nm.geometry_collision_mask = G.L_WORLD
	nm.cell_size = 0.25
	nm.cell_height = 0.25
	nm.agent_radius = 0.5
	nm.agent_height = 1.75
	nm.agent_max_climb = 0.25
	nm.agent_max_slope = 40.0
	nm.region_min_size = 4.0
	nav.navigation_mesh = nm
	add_child(nav)
	nav.bake_finished.connect(_on_bake_finished)


# ------------------------------------------------------------------------------------------------
# Geometry helpers
# ------------------------------------------------------------------------------------------------
func box(parent: Node3D, center: Vector3, size: Vector3, mat: Material, collide := true) -> Node3D:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	mi.material_override = mat
	mi.set_meta("merge", true)
	if not collide:
		parent.add_child(mi)
		mi.position = center
		return mi
	var body := StaticBody3D.new()
	body.collision_layer = G.L_WORLD
	body.collision_mask = 0
	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = size
	cs.shape = bs
	body.add_child(cs)
	body.add_child(mi)
	parent.add_child(body)
	body.position = center
	return body


func cylinder(parent: Node3D, center: Vector3, radius: float, height: float, mat: Material, collide := true) -> Node3D:
	var mi := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = radius
	cm.bottom_radius = radius
	cm.height = height
	cm.radial_segments = 12
	mi.mesh = cm
	mi.material_override = mat
	mi.set_meta("merge", true)
	if not collide:
		parent.add_child(mi)
		mi.position = center
		return mi
	var body := StaticBody3D.new()
	body.collision_layer = G.L_WORLD
	body.collision_mask = 0
	var cs := CollisionShape3D.new()
	var shape := CylinderShape3D.new()
	shape.radius = radius
	shape.height = height
	cs.shape = shape
	body.add_child(cs)
	body.add_child(mi)
	parent.add_child(body)
	body.position = center
	return body


## A wall from a to b (axis-aligned, on the floor) with openings [start, end, bottom, top]
## measured along the wall from a.
func wall(a: Vector3, b: Vector3, openings: Array, mat: Material) -> void:
	var length := a.distance_to(b)
	var axis := (b - a) / length
	openings.sort_custom(func(x, y): return x[0] < y[0])
	var cursor := 0.0
	for o in openings:
		if o[0] > cursor:
			_wall_piece(a, axis, length, cursor, o[0], 0.0, H, mat)
		if o[2] > 0.0:
			_wall_piece(a, axis, length, o[0], o[1], 0.0, o[2], mat)
		if o[3] < H:
			_wall_piece(a, axis, length, o[0], o[1], o[3], H, mat)
		cursor = o[1]
	if cursor < length:
		_wall_piece(a, axis, length, cursor, length, 0.0, H, mat)


func _wall_piece(a: Vector3, axis: Vector3, length: float, s: float, e: float, y0: float,
		y1: float, mat: Material) -> void:
	var s2 := s - (T / 2 if s <= 0.001 else 0.0)
	var e2 := e + (T / 2 if e >= length - 0.001 else 0.0)
	var mid := a + axis * ((s2 + e2) / 2) + Vector3(0, (y0 + y1) / 2, 0)
	var seg := e2 - s2
	var size := Vector3(seg, y1 - y0, T) if abs(axis.x) > 0.5 else Vector3(T, y1 - y0, seg)
	box(nav, mid, size, mat)


# ------------------------------------------------------------------------------------------------
# Map
# ------------------------------------------------------------------------------------------------
func _environment() -> void:
	var we := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.012, 0.014, 0.022)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.36, 0.38, 0.48)
	env.ambient_light_energy = 0.55
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.tonemap_exposure = 1.05
	env.fog_enabled = true
	env.fog_light_color = Color(0.07, 0.08, 0.11)
	env.fog_density = 0.035
	env.glow_enabled = true
	env.glow_intensity = 0.7
	env.glow_bloom = 0.04
	env.glow_hdr_threshold = 1.0
	env.adjustment_enabled = true
	env.adjustment_saturation = 0.85
	env.adjustment_contrast = 1.08
	we.environment = env
	add_child(we)
	self.env = env
	moon = DirectionalLight3D.new()
	moon.light_color = Color(0.55, 0.62, 0.9)
	moon.light_energy = 0.3
	moon.rotation_degrees = Vector3(-50, 35, 0)
	moon.shadow_enabled = false
	add_child(moon)


func _floors_and_ceilings() -> void:
	var floor_mats := {"hall": m_tiles, "atelier": m_floor_concrete, "reserve": m_wood_floor, "labo": m_tiles}
	for id in rooms:
		var r: Dictionary = rooms[id]
		var mn: Vector2 = r.min
		var mx: Vector2 = r.max
		var c := (mn + mx) / 2
		var s := mx - mn
		box(nav, Vector3(c.x, -0.1, c.y), Vector3(s.x + T, 0.2, s.y + T), floor_mats[id])
		box(self, Vector3(c.x, H + 0.1, c.y), Vector3(s.x + T, 0.2, s.y + T), m_ceiling, false)
		# Ceiling beams.
		for i in range(1, int(s.x / 3.5) + 1):
			box(self, Vector3(mn.x + i * s.x / (int(s.x / 3.5) + 1), H - 0.15, c.y),
				Vector3(0.25, 0.3, s.y), m_wood, false)


func _walls() -> void:
	var win := func(s: float, e: float) -> Array: return [s, e, Barricade.SILL, Barricade.TOP]
	var door := func(s: float, e: float) -> Array: return [s, e, 0.0, 2.6]
	wall(Vector3(-7, 0, -7), Vector3(7, 0, -7), [win.call(3.5, 5.5)], m_concrete)
	wall(Vector3(7, 0, -6), Vector3(19, 0, -6), [win.call(5.0, 7.0)], m_brick)
	wall(Vector3(-7, 0, -7), Vector3(-7, 0, 21), [win.call(8.0, 10.0), win.call(21.0, 23.0)], m_concrete)
	wall(Vector3(19, 0, -6), Vector3(19, 0, 21), [win.call(6.0, 8.0), win.call(21.0, 23.0)], m_brick)
	wall(Vector3(-7, 0, 21), Vector3(19, 0, 21), [win.call(6.0, 8.0), win.call(19.0, 21.0)], m_concrete)
	wall(Vector3(7, 0, -7), Vector3(7, 0, 7), [door.call(5.5, 8.5)], m_concrete)
	wall(Vector3(7, 0, 7), Vector3(7, 0, 21), [door.call(5.0, 8.0)], m_concrete)
	wall(Vector3(-7, 0, 7), Vector3(7, 0, 7), [door.call(5.5, 8.5)], m_concrete)
	wall(Vector3(7, 0, 7), Vector3(19, 0, 7), [door.call(4.5, 7.5)], m_brick)
	# Skirting / wainscot in the lab for a different look.
	for z in [7.2, 20.8]:
		box(self, Vector3(13, 0.5, z), Vector3(11.7, 1.0, 0.06), m_metal, false)


func _outside() -> void:
	var outside := Node3D.new()
	outside.name = "Outside"
	add_child(outside)
	box(outside, Vector3(6, -0.07, 7), Vector3(110, 0.1, 110), m_dirt)
	var rng := RandomNumberGenerator.new()
	rng.seed = 42
	var placed := 0
	while placed < 26:
		var p := Vector3(rng.randf_range(-40, 52), 0, rng.randf_range(-35, 50))
		if p.x > -11 and p.x < 23 and p.z > -11 and p.z < 25:
			continue
		placed += 1
		var hgt := rng.randf_range(4.0, 8.0)
		cylinder(outside, p + Vector3(0, hgt / 2, 0), rng.randf_range(0.15, 0.3), hgt, m_bark, false)
		for k in rng.randi_range(2, 4):
			var b := MeshInstance3D.new()
			var bm := BoxMesh.new()
			bm.size = Vector3(0.08, rng.randf_range(1.2, 2.5), 0.08)
			b.mesh = bm
			b.material_override = m_bark
			outside.add_child(b)
			b.position = p + Vector3(0, hgt * rng.randf_range(0.5, 0.9), 0)
			b.rotation = Vector3(rng.randf_range(-0.9, 0.9), rng.randf(), rng.randf_range(-0.9, 0.9))
	# Broken fence posts and rocks near the building.
	for i in 30:
		var ang := rng.randf() * TAU
		var p := Vector3(6, 0, 7) + Vector3(cos(ang) * rng.randf_range(16, 22), 0, sin(ang) * rng.randf_range(16, 22))
		if rng.randf() < 0.5:
			box(outside, p + Vector3(0, 0.6, 0), Vector3(0.15, 1.2, 0.15), m_wood, false)
		else:
			var rock := box(outside, p + Vector3(0, 0.2, 0), Vector3(rng.randf_range(0.5, 1.2), 0.5, rng.randf_range(0.5, 1.0)), m_floor_concrete, false)
			rock.rotation.y = rng.randf() * TAU


func _props() -> void:
	# Hall: overturned table, crates, barrels.
	var table := box(nav, Vector3(3.2, 0.45, -3.0), Vector3(2.0, 0.9, 0.12), m_wood)
	table.rotation.y = 0.3
	# Props stand flush against the walls: no gap a player fits in but a zombie does not.
	box(nav, Vector3(-5.45, 0.45, -6.4), Vector3(0.9, 0.9, 0.9), m_wood)
	box(nav, Vector3(-6.4, 0.45, -6.4), Vector3(0.9, 0.9, 0.9), m_wood)
	box(nav, Vector3(-5.9, 1.3, -6.4), Vector3(0.8, 0.8, 0.8), m_wood)
	cylinder(nav, Vector3(6.45, 0.5, 6.45), 0.38, 1.0, m_metal)
	cylinder(nav, Vector3(5.68, 0.5, 6.45), 0.38, 1.0, m_metal)
	# Atelier: workbench, shelves, crates.
	box(nav, Vector3(9.5, 0.45, 6.2), Vector3(2.6, 0.9, 1.0), m_wood)
	box(nav, Vector3(9.5, 1.2, 6.55), Vector3(2.6, 0.6, 0.15), m_metal)
	box(nav, Vector3(18.3, 1.0, -2.5), Vector3(0.7, 2.0, 2.4), m_metal)
	box(nav, Vector3(12.0, 0.45, 2.0), Vector3(1.0, 0.9, 1.0), m_wood)
	box(nav, Vector3(12.9, 0.4, 2.3), Vector3(0.8, 0.8, 0.8), m_wood)
	# Réserve: rows of racks.
	for z in [11.0, 16.5]:
		box(nav, Vector3(-2.5, 1.0, z), Vector3(3.5, 2.0, 0.6), m_metal)
		for k in 3:
			box(nav, Vector3(-3.6 + k * 1.1, 2.2, z), Vector3(0.7, 0.4, 0.5), m_wood)
	box(nav, Vector3(3.5, 0.45, 15.0), Vector3(0.9, 0.9, 0.9), m_wood)
	# Labo: lab benches and a tank.
	box(nav, Vector3(11.0, 0.45, 13.0), Vector3(2.2, 0.9, 1.0), m_metal)
	box(nav, Vector3(15.5, 0.45, 13.0), Vector3(2.2, 0.9, 1.0), m_metal)
	cylinder(nav, Vector3(13.0, 1.1, 18.5), 0.7, 2.2, m_metal)
	var liquid := StandardMaterial3D.new()
	liquid.albedo_color = Color(0.2, 1.0, 0.4)
	liquid.emission_enabled = true
	liquid.emission = Color(0.15, 0.9, 0.35)
	liquid.emission_energy_multiplier = 1.5
	cylinder(self, Vector3(13.0, 1.2, 18.5), 0.72, 0.6, liquid, false)


func _lights() -> void:
	var defs := [
		[Vector3(0, 3.0, -2.5), Color(1.0, 0.8, 0.55)],
		[Vector3(-1.5, 3.0, 4.0), Color(1.0, 0.8, 0.55)],
		[Vector3(11.0, 3.0, 0.5), Color(1.0, 0.75, 0.5)],
		[Vector3(16.0, 3.0, 0.5), Color(1.0, 0.75, 0.5)],
		[Vector3(0.5, 3.0, 11.0), Color(1.0, 0.85, 0.65)],
		[Vector3(0.5, 3.0, 17.5), Color(1.0, 0.85, 0.65)],
		[Vector3(11.0, 3.0, 14.5), Color(0.7, 1.0, 0.8)],
		[Vector3(16.5, 3.0, 17.0), Color(0.7, 1.0, 0.8)],
	]
	for d in defs:
		var l := OmniLight3D.new()
		l.light_color = d[1]
		l.light_energy = 1.5
		l.omni_range = 9.0
		l.omni_attenuation = 1.2
		add_child(l)
		l.position = d[0]
		lights.append(l)
		var bulb := MeshInstance3D.new()
		var sm := SphereMesh.new()
		sm.radius = 0.09
		sm.height = 0.18
		bulb.mesh = sm
		bulb.material_override = m_bulb
		add_child(bulb)
		bulb.position = d[0] + Vector3(0, 0.05, 0)
		box(self, d[0] + Vector3(0, 0.2, 0), Vector3(0.02, 0.4, 0.02), m_bark, false)
	_flicker = lights[1]


func _windows() -> void:
	var defs := [
		[Vector3(-2.5, 0, -7), Vector3(0, 0, 1), "hall"],
		[Vector3(-7, 0, 2), Vector3(1, 0, 0), "hall"],
		[Vector3(13, 0, -6), Vector3(0, 0, 1), "atelier"],
		[Vector3(19, 0, 1), Vector3(-1, 0, 0), "atelier"],
		[Vector3(-7, 0, 15), Vector3(1, 0, 0), "reserve"],
		[Vector3(0, 0, 21), Vector3(0, 0, -1), "reserve"],
		[Vector3(19, 0, 16), Vector3(-1, 0, 0), "labo"],
		[Vector3(13, 0, 21), Vector3(0, 0, -1), "labo"],
	]
	for d in defs:
		var b := Barricade.new()
		b.room = d[2]
		add_child(b)
		b.build(d[0], d[1], 2.0, m_wood)
		windows.append(b)


func _doors() -> void:
	var defs := [
		[Vector3(7, 0, 0), Vector3(0, 0, 1), 750, ["hall", "atelier"]],
		[Vector3(0, 0, 7), Vector3(1, 0, 0), 1000, ["hall", "reserve"]],
		[Vector3(13, 0, 7), Vector3(1, 0, 0), 1250, ["atelier", "labo"]],
		[Vector3(7, 0, 13.5), Vector3(0, 0, 1), 1250, ["reserve", "labo"]],
	]
	for d in defs:
		var door := BuyDoor.new()
		add_child(door)
		var rooms: Array[String] = []
		rooms.assign(d[3])
		door.build(d[0], d[1], 3.0, 2.6, d[2], rooms, nav, m_wood, m_metal)
		door.opened.connect(_on_door_opened)
		doors.append(door)


func _buyables() -> void:
	var walls := [
		[Vector3(6.84, 1.5, -4.5), Vector3(-1, 0, 0), "k14"],
		[Vector3(-6.84, 1.5, -3.5), Vector3(1, 0, 0), "grele"],
		[Vector3(9.5, 1.5, -5.84), Vector3(0, 0, 1), "vipere"],
		[Vector3(-6.84, 1.5, 9.5), Vector3(1, 0, 0), "faucon"],
		[Vector3(9.5, 1.5, 7.16), Vector3(0, 0, 1), "ouragan"],
		[Vector3(3.5, 1.5, 6.84), Vector3(0, 0, -1), "uzi"],
		[Vector3(18.84, 1.5, 4.5), Vector3(-1, 0, 0), "hache"],
	]
	for d in walls:
		var wb := WallBuy.new()
		add_child(wb)
		wb.build(d[0], d[1], d[2], m_chalk, m_board)
	var perks := [
		[Vector3(-5.0, 0, 6.35), Vector3(0, 0, -1), "second_souffle"],
		[Vector3(17.0, 0, 6.35), Vector3(0, 0, -1), "cuirasse"],
		[Vector3(8.6, 0, 20.35), Vector3(0, 0, -1), "main_leste"],
		[Vector3(4.6, 0, 20.35), Vector3(0, 0, -1), "double_detente"],
		[Vector3(-6.35, 0, 19.0), Vector3(1, 0, 0), "pied_leger"],
	]
	for d in perks:
		var pm := PerkMachine.new()
		add_child(pm)
		pm.build(d[0], d[1], d[2], m_metal, nav)
	var mb := MysteryBox.new()
	add_child(mb)
	mb.build(Vector3(16.5, 0, -5.45), Vector3(0, 0, 1), m_wood, m_metal, G.gun_mats(), nav)
	var forge := Forge.new()
	add_child(forge)
	forge.build(Vector3(18.2, 0, 10.0), Vector3(-1, 0, 0), m_metal, G.gun_mats(), nav)
	power_switch = PowerSwitch.new()
	add_child(power_switch)
	power_switch.build(Vector3(18.85, 1.4, 19.0), Vector3(-1, 0, 0), m_metal)
	power_switch.switched.connect(_on_power)
	# Electric trap across the Hall / Atelier doorway, switch on the hall wall beside it.
	trap = ZapTrap.new()
	add_child(trap)
	trap.build(Vector3(6.84, 1.4, 2.5), Vector3(-1, 0, 0), Vector3(7, 0, -1.42), Vector3(7, 0, 1.42), doors[0], m_metal)
	_apply_power_lights(false)


## Before the breaker is thrown the lights are weak and stutter; afterwards they come up full.
func _apply_power_lights(on: bool) -> void:
	for l in lights:
		l.light_energy = 1.5 if on else 0.75


func _on_power(silent: bool) -> void:
	G.set_power(true)
	if silent:
		_apply_power_lights(true)
	else:
		_power_t = 1.2


## Restores a saved game where the power was already on (no sound, no message).
func restore_power() -> void:
	if power_switch:
		power_switch.turn_on(true)


# ------------------------------------------------------------------------------------------------
# Rooms, doors, navigation
# ------------------------------------------------------------------------------------------------
## Dog rounds: thick reddish fog and a darker sky; back to normal when the round ends.
func set_storm(on: bool) -> void:
	var tw := create_tween().set_parallel(true)
	tw.tween_property(env, "fog_density", 0.075 if on else 0.035, 3.0)
	tw.tween_property(env, "fog_light_color", Color(0.16, 0.06, 0.04) if on else Color(0.07, 0.08, 0.11), 3.0)
	tw.tween_property(moon, "light_color", Color(1.0, 0.45, 0.3) if on else Color(0.55, 0.62, 0.9), 3.0)


func room_at(p: Vector3) -> String:
	for id in rooms:
		var r: Dictionary = rooms[id]
		if p.x >= r.min.x and p.x <= r.max.x and p.z >= r.min.y and p.z <= r.max.y:
			return id
	return ""


## Fewer draw calls for phones: the static pieces of scenery (walls, floors, props, facade
## details) are merged into one mesh per material and per 12 m cell. Cells stay small so each
## merged piece is still lit only by the lamps near it.
func merge_static(cell := 12.0) -> void:
	var groups := {}
	var inv := global_transform.affine_inverse()
	for n in find_children("*", "MeshInstance3D", true, false):
		var mi := n as MeshInstance3D
		if not mi.has_meta("merge") or mi.mesh == null or mi.material_override == null or not mi.visible:
			continue
		var xf := inv * mi.global_transform
		var c := xf.origin
		var key := [mi.material_override, int(floor(c.x / cell)), int(floor(c.z / cell))]
		if not groups.has(key):
			groups[key] = []
		groups[key].append([mi, xf])
	for key in groups:
		var items: Array = groups[key]
		if items.size() < 2:
			continue
		var st := SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		for it in items:
			var mi: MeshInstance3D = it[0]
			st.append_from(mi.mesh, 0, it[1])
		var merged := MeshInstance3D.new()
		merged.mesh = st.commit()
		merged.material_override = key[0]
		merged.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(merged)
		for it in items:
			var mi: MeshInstance3D = it[0]
			mi.get_parent().remove_child(mi)
			mi.free()


## Line shown on the HUD for the map's objective ("" when there is none).
func objective_text() -> String:
	return ""


## Map-specific state for the saved game.
func save_state() -> Dictionary:
	return {}


func load_state(_d: Dictionary) -> void:
	pass


func active_ground_spawns() -> Array[GroundSpawn]:
	var out: Array[GroundSpawn] = []
	for g in ground_spawns:
		if unlocked.get(g.room, false):
			out.append(g)
	return out


func active_windows() -> Array[Barricade]:
	var out: Array[Barricade] = []
	for w in windows:
		if unlocked.get(w.room, false):
			out.append(w)
	return out


func _on_door_opened(door: BuyDoor) -> void:
	var said := false
	for r in door.rooms:
		if not unlocked[r]:
			unlocked[r] = true
			room_unlocked.emit(r)
			if not said and not rooms[r].get("silent", false):
				said = true
				G.say(rooms[r].get("msg", "%s ouvert" % rooms[r].name), Color(1, 0.85, 0.4))
	await get_tree().process_frame
	await get_tree().physics_frame
	bake()


func bake() -> void:
	if _baking:
		_bake_again = true
		return
	_baking = true
	nav.bake_navigation_mesh(true)


func _on_bake_finished() -> void:
	_baking = false
	if _bake_again:
		_bake_again = false
		bake()
		return
	nav_ready.emit()


func _process(delta: float) -> void:
	if _power_t > 0.0:
		# Lights stutter on one after another as the current comes back.
		_power_t -= delta
		var on_frac := 1.0 - _power_t / 1.2
		for i in lights.size():
			var lit := float(i) / lights.size() < on_frac
			lights[i].light_energy = (1.5 if lit else 0.75) * (randf_range(0.6, 1.0) if lit and _power_t > 0.0 else 1.0)
		if _power_t <= 0.0:
			_apply_power_lights(true)
		return
	var full := 1.5 if G.power_on else 0.75
	if not G.power_on and randf() < delta * 1.5:
		var l := lights[randi() % lights.size()]
		l.light_energy = randf_range(0.05, 0.4) if randf() < 0.6 else full
	if _flicker and randf() < delta * 2.0:
		_flicker.light_energy = randf_range(0.2, full) if randf() < 0.5 else full
