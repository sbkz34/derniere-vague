class_name VillageLevel
extends Level
## "Le Village": a French village at night in the fog, about three times the Bunker. Outdoor
## areas (the square, the high street, the wash-house by the river, the cemetery) where the dead
## climb out of the ground, and buildings with boarded windows (café, town hall, church, barn,
## chapel). Four "lanternes des morts" to relight; then the chapel door leads out.

const V_ROOMS := {
	# The chapel comes first: it sits inside the cemetery and room_at() takes the first match.
	"chapelle": {"name": "Chapelle", "min": Vector2(52, -4), "max": Vector2(58, 4), "indoor": true, "silent": true},
	"place": {"name": "Place", "min": Vector2(-12, -10), "max": Vector2(12, 10)},
	"cafe": {"name": "Café", "min": Vector2(-24, -8), "max": Vector2(-12, 4), "indoor": true},
	"mairie": {"name": "Mairie", "min": Vector2(-8, -22), "max": Vector2(8, -10), "indoor": true, "msg": "La mairie est ouverte"},
	"lavoir": {"name": "Lavoir", "min": Vector2(-12, 10), "max": Vector2(12, 22), "msg": "Le lavoir est ouvert"},
	"rue": {"name": "Grand-Rue", "min": Vector2(12, -5), "max": Vector2(40, 5), "msg": "La Grand-Rue est ouverte"},
	"eglise": {"name": "Église", "min": Vector2(24, -21), "max": Vector2(36, -5), "indoor": true, "msg": "L'église est ouverte"},
	"ferme": {"name": "Grange", "min": Vector2(18, 5), "max": Vector2(34, 19), "indoor": true, "msg": "La grange est ouverte"},
	"cimetiere": {"name": "Cimetière", "min": Vector2(40, -14), "max": Vector2(58, 14), "msg": "Le cimetière est ouvert"},
}
const CHURCH_H := 7.5

var m_pierre: StandardMaterial3D
var m_enduit: StandardMaterial3D
var m_paves: StandardMaterial3D
var m_tuiles: StandardMaterial3D
var m_herbe: StandardMaterial3D
var m_water: StandardMaterial3D
var m_glass: StandardMaterial3D
var m_leaves: StandardMaterial3D
var m_shutters: Array[StandardMaterial3D] = []
var objective: Extraction
var lanterns: Array[Lantern] = []
var portal: ExtractionPortal


func build() -> void:
	rooms = V_ROOMS
	unlocked = {}
	for id in rooms:
		unlocked[id] = id == "place" or id == "cafe"
	player_start = Vector3(0, 0.2, 5.5)
	preview_spots = [
		[Vector3(-3.0, 1.9, 7.5), Vector3(0.0, 1.6, -9.0)],
		[Vector3(14.0, 1.9, 2.5), Vector3(30.0, 2.5, -6.0)],
		[Vector3(42.0, 1.9, 9.0), Vector3(54.0, 1.6, 0.0)],
		[Vector3(-8.0, 1.9, 12.0), Vector3(2.0, 1.0, 18.0)],
	]
	menu_orbit = [Vector3(-3.0, 2.0, 7.0), Vector3(0.0, 1.8, -9.0)]
	_make_materials()
	_village_materials()
	_environment()
	moon.light_energy = 0.42
	_make_nav()
	_v_ground()
	_v_houses()
	_v_buildings()
	_v_walls()
	_v_props()
	_v_cemetery()
	_v_lights()
	_v_windows()
	_v_doors()
	_v_buyables()
	_v_spawns()
	_v_objective()
	_v_scenery()
	_apply_power_lights(false)
	merge_static()


func attach(p_player: Node, p_director: Node) -> void:
	objective.player = p_player
	objective.director = p_director


func objective_text() -> String:
	return objective.objective_text()


func save_state() -> Dictionary:
	return objective.save_state()


func load_state(d: Dictionary) -> void:
	objective.load_state(d)


func _village_materials() -> void:
	m_pierre = _tex_mat("res://assets/tex/pierre.png", Color(0.95, 0.92, 0.88), 0.35)
	m_enduit = _tex_mat("res://assets/tex/enduit.png", Color(0.95, 0.92, 0.86), 0.3)
	m_paves = _tex_mat("res://assets/tex/paves.png", Color(0.9, 0.9, 0.92), 0.4)
	m_tuiles = _tex_mat("res://assets/tex/tuiles.png", Color(0.85, 0.8, 0.78), 0.45)
	m_herbe = _tex_mat("res://assets/tex/herbe.png", Color(0.9, 0.95, 0.9), 0.25, 1.0)
	m_water = StandardMaterial3D.new()
	m_water.albedo_color = Color(0.03, 0.06, 0.07)
	m_water.roughness = 0.05
	m_water.metallic = 0.4
	m_water.emission_enabled = true
	m_water.emission = Color(0.02, 0.05, 0.06)
	m_glass = StandardMaterial3D.new()
	m_glass.albedo_color = Color(0.03, 0.04, 0.05)
	m_glass.roughness = 0.2
	m_leaves = StandardMaterial3D.new()
	m_leaves.albedo_color = Color(0.07, 0.12, 0.06)
	m_leaves.roughness = 1.0
	for c in [Color(0.22, 0.32, 0.26), Color(0.2, 0.27, 0.38), Color(0.38, 0.26, 0.18), Color(0.45, 0.43, 0.38)]:
		var m := StandardMaterial3D.new()
		m.albedo_color = c
		m.roughness = 0.9
		m_shutters.append(m)


# ------------------------------------------------------------------------------------------------
# Helpers
# ------------------------------------------------------------------------------------------------
## Floor of a zone, cut in tiles so each piece only gets the lights near it.
func _floor(mn: Vector2, mx: Vector2, mat: Material, tile := 6.0) -> void:
	var size := mx - mn
	var nx := maxi(1, ceili(size.x / tile))
	var nz := maxi(1, ceili(size.y / tile))
	var sx := size.x / nx
	var sz := size.y / nz
	for i in nx:
		for j in nz:
			box(nav, Vector3(mn.x + sx * (i + 0.5), -0.1, mn.y + sz * (j + 0.5)), Vector3(sx, 0.2, sz), mat)


## Wall along x at `z` from x0 to x1; openings as [x_start, x_end, "win" | "door"].
func _wall_x(z: float, x0: float, x1: float, ops: Array, mat: Material) -> void:
	var o: Array = []
	for op in ops:
		o.append([op[0] - x0, op[1] - x0, Barricade.SILL if op[2] == "win" else 0.0, Barricade.TOP if op[2] == "win" else 2.6])
	wall(Vector3(x0, 0, z), Vector3(x1, 0, z), o, mat)


## Wall along z at `x` from z0 to z1; openings as [z_start, z_end, "win" | "door"].
func _wall_z(x: float, z0: float, z1: float, ops: Array, mat: Material) -> void:
	var o: Array = []
	for op in ops:
		o.append([op[0] - z0, op[1] - z0, Barricade.SILL if op[2] == "win" else 0.0, Barricade.TOP if op[2] == "win" else 2.6])
	wall(Vector3(x, 0, z0), Vector3(x, 0, z1), o, mat)


## Pitched tile roof over a rectangle; the ridge runs along the longer side.
func _roof(mn: Vector2, mx: Vector2, base_y: float, height := 2.2) -> void:
	var c := (mn + mx) / 2.0
	var s := mx - mn
	var mi := MeshInstance3D.new()
	var pm := PrismMesh.new()
	if s.x >= s.y:
		pm.size = Vector3(s.y + 0.8, height, s.x + 0.8)
		mi.rotation.y = PI / 2
	else:
		pm.size = Vector3(s.x + 0.8, height, s.y + 0.8)
	mi.mesh = pm
	mi.material_override = m_tuiles
	mi.set_meta("merge", true)
	add_child(mi)
	mi.position = Vector3(c.x, base_y + height / 2.0, c.y)


## A house nobody can enter: a solid block with a roof and shuttered windows on `faces`
## ("n", "s", "e", "w": the sides that face the streets).
func _house(mn: Vector2, mx: Vector2, h: float, faces: String, mat: Material = null) -> void:
	var c := (mn + mx) / 2.0
	var s := mx - mn
	box(nav, Vector3(c.x, h / 2.0, c.y), Vector3(s.x, h, s.y), mat if mat else m_enduit)
	_roof(mn, mx, h)
	var rng := RandomNumberGenerator.new()
	rng.seed = int(absf(mn.x * 31.0 + mn.y * 17.0))
	for f in faces:
		var along_x := f == "n" or f == "s"
		var length := s.x if along_x else s.y
		var n := maxi(1, int(length / 3.2))
		var normal := Vector3(0, 0, -1) if f == "n" else (Vector3(0, 0, 1) if f == "s" else (Vector3(1, 0, 0) if f == "e" else Vector3(-1, 0, 0)))
		var face_pos := Vector3(c.x, 0, c.y) + normal * ((s.y if along_x else s.x) / 2.0 + 0.03)
		var shutter: StandardMaterial3D = m_shutters[rng.randi() % m_shutters.size()]
		for storey in ([1.7, 4.4] if h > 5.5 else [1.7]):
			for i in n:
				var t := (float(i) + 0.5) / n - 0.5
				var p := face_pos + (Vector3(1, 0, 0) if along_x else Vector3(0, 0, 1)) * t * length + Vector3(0, storey, 0)
				var closed := rng.randf() < 0.45
				_decor(p, Vector3(1.0, 1.35, 0.05) if along_x else Vector3(0.05, 1.35, 1.0), m_glass)
				var side := Vector3(1, 0, 0) if along_x else Vector3(0, 0, 1)
				if closed:
					_decor(p + normal * 0.02, Vector3(1.0, 1.35, 0.05) if along_x else Vector3(0.05, 1.35, 1.0), shutter)
				else:
					for k in [-1, 1]:
						_decor(p + side * 0.78 * k + normal * 0.02, Vector3(0.5, 1.35, 0.05) if along_x else Vector3(0.05, 1.35, 0.5), shutter)
				_decor(p + Vector3(0, -0.75, 0) + normal * 0.05, Vector3(1.15, 0.08, 0.14) if along_x else Vector3(0.14, 0.08, 1.15), m_pierre)


func _decor(pos: Vector3, size: Vector3, mat: Material) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.set_meta("merge", true)
	add_child(mi)
	mi.position = pos
	return mi


func _label(text: String, pos: Vector3, facing: Vector3, size := 64, color := Color(0.95, 0.9, 0.75)) -> void:
	var l := Label3D.new()
	l.text = text
	l.font_size = size
	l.pixel_size = 0.006
	l.outline_size = 10
	l.modulate = color
	l.outline_modulate = Color(0.05, 0.04, 0.03)
	add_child(l)
	l.global_position = pos
	l.look_at(pos - facing, Vector3.UP)


func _ceiling(mn: Vector2, mx: Vector2, y: float) -> void:
	var c := (mn + mx) / 2.0
	var s := mx - mn
	box(self, Vector3(c.x, y + 0.1, c.y), Vector3(s.x + T, 0.2, s.y + T), m_ceiling, false)


# ------------------------------------------------------------------------------------------------
# The map
# ------------------------------------------------------------------------------------------------
func _v_ground() -> void:
	_floor(Vector2(-12, -10), Vector2(12, 10), m_paves)                # place
	_floor(Vector2(12, -5), Vector2(40, 5), m_paves)                   # rue
	_floor(Vector2(-12, 10), Vector2(12, 22), m_herbe)                 # lavoir
	_floor(Vector2(-24, -8), Vector2(-12, 4), m_wood_floor)            # café
	_floor(Vector2(-8, -22), Vector2(8, -10), m_tiles)                 # mairie
	_floor(Vector2(24, -21), Vector2(36, -5), m_paves)                 # église
	_floor(Vector2(18, 5), Vector2(34, 19), m_dirt)                    # grange
	_floor(Vector2(40, -14), Vector2(58, -2), m_herbe)                 # cimetière north
	_floor(Vector2(40, 2), Vector2(58, 14), m_herbe)                   # cimetière south
	_floor(Vector2(40, -2), Vector2(52, 2), m_paves)                   # cemetery path
	_floor(Vector2(52, -4), Vector2(58, -2), m_pierre)                 # chapelle
	_floor(Vector2(52, -2), Vector2(58, 2), m_pierre)
	_floor(Vector2(52, 2), Vector2(58, 4), m_pierre)
	# The open country all around (not walkable: the village edges keep you in).
	var outside := Node3D.new()
	outside.name = "Outside"
	add_child(outside)
	box(outside, Vector3(17, -0.08, 2), Vector3(220, 0.1, 180), m_herbe, false)


func _v_houses() -> void:
	_house(Vector2(-14, -22), Vector2(-8, -10), 6.5, "s")
	_house(Vector2(8, -22), Vector2(14, -10), 6.0, "s")
	_house(Vector2(-24, -14), Vector2(-12, -8), 6.0, "e")
	_house(Vector2(-24, 4), Vector2(-12, 22), 6.5, "e")
	_house(Vector2(12, -12), Vector2(24, -5), 6.5, "sw")
	_house(Vector2(36, -14), Vector2(40, -5), 6.0, "s")
	_house(Vector2(12, 5), Vector2(18, 22), 6.0, "nw")
	_house(Vector2(34, 5), Vector2(40, 14), 6.0, "n")


## The buildings you go into: café, town hall, church, barn and chapel.
func _v_buildings() -> void:
	# Café de la Place: door opening onto the square, two windows at the back.
	_wall_x(-8, -24, -12, [], m_enduit)
	_wall_x(4, -24, -12, [], m_enduit)
	_wall_z(-24, -8, 4, [[-6, -4, "win"], [0, 2, "win"]], m_enduit)
	_wall_z(-12, -8, 4, [[-4, -1, "door"]], m_enduit)
	_ceiling(Vector2(-24, -8), Vector2(-12, 4), H)
	_roof(Vector2(-24, -8), Vector2(-12, 4), H + 0.2, 2.6)
	_label("CAFÉ DE LA PLACE", Vector3(-11.8, 3.0, -2.5), Vector3(1, 0, 0), 56)
	# Awning over the door.
	var awning := _decor(Vector3(-11.3, 2.85, -2.5), Vector3(1.2, 0.08, 3.6), m_shutters[0])
	awning.rotation.z = -0.25
	# Mairie: stone, a flag and its motto.
	_wall_x(-22, -8, 8, [[-6, -4, "win"], [4, 6, "win"]], m_pierre)
	_wall_x(-10, -8, 8, [[-1.5, 1.5, "door"]], m_pierre)
	_wall_z(-8, -22, -10, [], m_pierre)
	_wall_z(8, -22, -10, [], m_pierre)
	_ceiling(Vector2(-8, -22), Vector2(8, -10), H)
	_roof(Vector2(-8, -22), Vector2(8, -10), H + 0.2, 2.6)
	_label("MAIRIE", Vector3(0, 3.0, -9.8), Vector3(0, 0, 1), 72)
	_label("LIBERTÉ · ÉGALITÉ · FRATERNITÉ", Vector3(0, 2.75, -9.8), Vector3(0, 0, 1), 24)
	var pole := _decor(Vector3(2.6, 3.2, -9.3), Vector3(0.05, 0.05, 1.3), m_metal)
	pole.rotation.x = 0.5
	for i in 3:
		var col: Color = [Color(0.1, 0.2, 0.6), Color(0.9, 0.9, 0.9), Color(0.8, 0.1, 0.1)][i]
		var fm := StandardMaterial3D.new()
		fm.albedo_color = col
		_decor(Vector3(2.6 + 0.25 * i + 0.25, 3.3, -8.75), Vector3(0.25, 0.5, 0.02), fm)
	# Church: tall stone walls, rose window, bell tower; the Forge waits inside.
	_wall_x(-21, 24, 36, [[26, 28, "win"]], m_pierre)
	_wall_x(-5, 24, 36, [[28.5, 31.5, "door"]], m_pierre)
	_wall_z(24, -21, -5, [[-19, -17, "win"]], m_pierre)
	_wall_z(36, -21, -5, [[-19, -17, "win"]], m_pierre)
	for seg in [[Vector3(30, 0, -21), Vector3(12.3, 0, 0.3)], [Vector3(30, 0, -5), Vector3(12.3, 0, 0.3)],
			[Vector3(24, 0, -13), Vector3(0.3, 0, 16.3)], [Vector3(36, 0, -13), Vector3(0.3, 0, 16.3)]]:
		var p: Vector3 = seg[0]
		var sz: Vector3 = seg[1]
		box(self, Vector3(p.x, (H + CHURCH_H) / 2.0, p.z), Vector3(sz.x, CHURCH_H - H, sz.z), m_pierre, false)
	_ceiling(Vector2(24, -21), Vector2(36, -5), CHURCH_H)
	_roof(Vector2(24, -21), Vector2(36, -5), CHURCH_H + 0.2, 4.0)
	box(self, Vector3(34, CHURCH_H + 3.5, -19), Vector3(4, 7.0, 4), m_pierre, false)
	var spire := MeshInstance3D.new()
	var sm := CylinderMesh.new()
	sm.top_radius = 0.0
	sm.bottom_radius = 2.9
	sm.height = 6.0
	sm.radial_segments = 4
	spire.mesh = sm
	spire.material_override = m_tuiles
	add_child(spire)
	spire.position = Vector3(34, CHURCH_H + 10.0, -19)
	spire.rotation.y = PI / 4
	var rose_mat := StandardMaterial3D.new()
	rose_mat.albedo_color = Color(0.55, 0.25, 0.12)
	rose_mat.emission_enabled = true
	rose_mat.emission = Color(0.8, 0.35, 0.12)
	rose_mat.emission_energy_multiplier = 0.7
	var rose := MeshInstance3D.new()
	var rm := CylinderMesh.new()
	rm.top_radius = 1.0
	rm.bottom_radius = 1.0
	rm.height = 0.06
	rm.radial_segments = 16
	rose.mesh = rm
	rose.material_override = rose_mat
	add_child(rose)
	rose.position = Vector3(30, 5.3, -4.8)
	rose.rotation.x = PI / 2
	for k in 4:
		var bar := _decor(Vector3(30, 5.3, -4.76), Vector3(2.0, 0.1, 0.05), m_pierre)
		bar.rotation.z = PI / 4 * k
	# Barn: wooden walls, hay.
	_wall_x(5, 18, 34, [[24.5, 27.5, "door"]], m_wood)
	_wall_x(19, 18, 34, [[21, 23, "win"], [29, 31, "win"]], m_wood)
	_wall_z(18, 5, 19, [], m_wood)
	_wall_z(34, 5, 19, [[15.5, 17.5, "win"]], m_wood)
	_ceiling(Vector2(18, 5), Vector2(34, 19), H)
	_roof(Vector2(18, 5), Vector2(34, 19), H + 0.2, 3.0)
	_label("GRANGE", Vector3(26, 3.0, 4.8), Vector3(0, 0, -1), 48)
	# Chapel at the back of the cemetery: open arch, the sealed door inside.
	_wall_z(52, -4, 4, [[-1.5, 1.5, "door"]], m_pierre)
	_wall_x(-4, 52, 58, [], m_pierre)
	_wall_x(4, 52, 58, [], m_pierre)
	_ceiling(Vector2(52, -4), Vector2(58, 4), H)
	_roof(Vector2(52, -4), Vector2(58, 4), H + 0.2, 2.8)
	_decor(Vector3(55, H + 3.4, 0), Vector3(0.12, 1.2, 0.12), m_pierre)
	_decor(Vector3(55, H + 3.6, 0), Vector3(0.12, 0.12, 0.6), m_pierre)


## Stone walls between the outdoor areas (with gates to buy) and around the cemetery; the river.
func _v_walls() -> void:
	_wall_x(10, -12, 12, [[-1.5, 1.5, "door"]], m_pierre)            # place / lavoir
	_wall_z(12, -5, 5, [[-1.5, 1.5, "door"]], m_pierre)              # place / rue
	_wall_z(40, -14, 14, [[-1.5, 1.5, "door"]], m_pierre)            # rue / cimetière
	_wall_x(-14, 40, 58, [], m_pierre)
	_wall_x(14, 40, 58, [], m_pierre)
	_wall_z(58, -14, 14, [], m_pierre)
	# River: a low parapet you cannot climb over (an invisible wall above it), dark water.
	box(nav, Vector3(0, 0.45, 22.2), Vector3(24, 0.9, 0.45), m_pierre)
	var block := StaticBody3D.new()
	block.collision_layer = G.L_WORLD
	block.collision_mask = 0
	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = Vector3(24, 4.0, 0.4)
	cs.shape = bs
	block.add_child(cs)
	nav.add_child(block)
	block.position = Vector3(0, 2.9, 22.2)
	var water := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(90, 9)
	water.mesh = pm
	water.material_override = m_water
	add_child(water)
	water.position = Vector3(0, -0.45, 27)
	box(self, Vector3(0, -0.4, 31.8), Vector3(90, 0.3, 0.6), m_dirt, false)


func _v_props() -> void:
	# Fountain in the middle of the square.
	cylinder(nav, Vector3(0, 0.35, -1), 1.8, 0.7, m_pierre)
	var pool := MeshInstance3D.new()
	var pc := CylinderMesh.new()
	pc.top_radius = 1.6
	pc.bottom_radius = 1.6
	pc.height = 0.05
	pool.mesh = pc
	pool.material_override = m_water
	add_child(pool)
	pool.position = Vector3(0, 0.71, -1)
	cylinder(nav, Vector3(0, 1.1, -1), 0.25, 1.5, m_pierre)
	cylinder(self, Vector3(0, 1.9, -1), 0.6, 0.15, m_pierre, false)
	# War memorial.
	box(nav, Vector3(7, 0.3, 6), Vector3(1.6, 0.6, 1.6), m_pierre)
	box(nav, Vector3(7, 1.8, 6), Vector3(0.6, 2.6, 0.6), m_pierre)
	_label("À NOS MORTS", Vector3(7, 1.4, 5.68), Vector3(0, 0, -1), 28)
	# Plane trees on the square and café terrace tables.
	for p in [Vector3(-6.5, 0, -6.5), Vector3(6.5, 0, -6.5)]:
		_tree(p, 4.5)
	for p in [Vector3(-9.8, 0, -5.8), Vector3(-9.8, 0, 1.6)]:
		cylinder(nav, p + Vector3(0, 0.38, 0), 0.45, 0.76, m_metal)
	# Cars left in the high street, one with its headlights still on.
	_car(Vector3(17.0, 0, 2.4), 0.12, Color(0.35, 0.08, 0.06), false)
	_car(Vector3(33.6, 0, -2.6), -0.25, Color(0.15, 0.2, 0.28), true)
	box(nav, Vector3(23.5, 0.45, -4.1), Vector3(1.4, 0.9, 0.8), m_wood)
	# Wash-house: a basin under a tiled roof on pillars.
	box(nav, Vector3(-4, 0.3, 16.5), Vector3(5.0, 0.6, 3.0), m_pierre)
	var basin := MeshInstance3D.new()
	var bp := PlaneMesh.new()
	bp.size = Vector2(4.4, 2.4)
	basin.mesh = bp
	basin.material_override = m_water
	add_child(basin)
	basin.position = Vector3(-4, 0.55, 16.5)
	for sx in [-1, 1]:
		for sz in [-1, 1]:
			cylinder(nav, Vector3(-4 + 2.9 * sx, 1.4, 16.5 + 2.0 * sz), 0.15, 2.8, m_wood)
	_roof(Vector2(-7.3, 14.1), Vector2(-0.7, 18.9), 2.8, 1.6)
	_tree(Vector3(8.5, 0, 19.5), 4.0)
	# Barn: hay bales and a cart.
	for p in [Vector3(20.0, 0.45, 17.6), Vector3(21.3, 0.45, 17.6), Vector3(20.6, 1.35, 17.6), Vector3(32.4, 0.45, 7.0)]:
		box(nav, p, Vector3(1.2, 0.9, 0.9), m_dirt)
	box(nav, Vector3(28.5, 0.5, 11.5), Vector3(2.4, 1.0, 1.4), m_wood)
	# Church pews.
	for z in [-15.0, -12.5, -10.0]:
		for x in [27.0, 33.0]:
			box(nav, Vector3(x, 0.45, z), Vector3(3.2, 0.9, 0.6), m_wood)
	# Café counter.
	box(nav, Vector3(-21.8, 0.55, -5.0), Vector3(0.8, 1.1, 4.0), m_wood)


func _tree(p: Vector3, h: float) -> void:
	cylinder(nav, p + Vector3(0, h / 2.0, 0), 0.28, h, m_bark)
	for k in 3:
		var leaf := MeshInstance3D.new()
		var sm := SphereMesh.new()
		sm.radius = 1.6 - 0.3 * k
		sm.height = 2.4 - 0.4 * k
		leaf.mesh = sm
		leaf.material_override = m_leaves
		leaf.set_meta("merge", true)
		add_child(leaf)
		leaf.position = p + Vector3(0.4 * (k - 1), h + 0.4 + 0.9 * k, 0.3 * (1 - k))


func _car(p: Vector3, rot: float, color: Color, lights_on: bool) -> void:
	var paint := StandardMaterial3D.new()
	paint.albedo_color = color
	paint.metallic = 0.3
	paint.roughness = 0.5
	var body := box(nav, p + Vector3(0, 0.6, 0), Vector3(4.0, 0.8, 1.8), paint)
	body.rotation.y = rot
	var cabin := _decor(Vector3(-0.3, 0.7, 0), Vector3(2.0, 0.65, 1.6), m_glass)
	cabin.reparent(body, false)
	cabin.position = Vector3(-0.3, 0.7, 0)
	for sx in [-1, 1]:
		for sz in [-1, 1]:
			var wheel := _decor(Vector3.ZERO, Vector3(0.6, 0.6, 0.25), m_bark)
			wheel.reparent(body, false)
			wheel.position = Vector3(1.3 * sx, -0.3, 0.85 * sz)
	if lights_on:
		var lamp := StandardMaterial3D.new()
		lamp.albedo_color = Color(1.0, 0.95, 0.8)
		lamp.emission_enabled = true
		lamp.emission = Color(1.0, 0.9, 0.7)
		lamp.emission_energy_multiplier = 3.0
		for sz in [-1, 1]:
			var hl := _decor(Vector3.ZERO, Vector3(0.05, 0.15, 0.3), lamp)
			hl.reparent(body, false)
			hl.position = Vector3(2.02, 0.1, 0.6 * sz)
		var spot := SpotLight3D.new()
		spot.light_color = Color(1.0, 0.92, 0.75)
		spot.light_energy = 3.0
		spot.spot_range = 14.0
		spot.spot_angle = 28.0
		body.add_child(spot)
		spot.position = Vector3(2.1, 0.1, 0)
		spot.rotation = Vector3(-0.08, -PI / 2, 0)


func _v_cemetery() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	for x in [43.0, 45.4, 47.8, 50.2]:
		for z in [-11.5, -8.5, -5.5, 5.5, 8.5, 11.5]:
			if absf(x - 47.8) < 0.5 and absf(z - 5.5) < 0.5:
				continue   # room for the lantern
			var stone := box(nav, Vector3(x, 0.45, z), Vector3(0.75, 0.9, 0.2), m_pierre)
			stone.rotation = Vector3(rng.randf_range(-0.08, 0.08), rng.randf_range(-0.15, 0.15), rng.randf_range(-0.1, 0.1))
			_decor(Vector3(x, 0.06, z + (0.95 if z < 0 else -0.95)), Vector3(0.85, 0.12, 1.7), m_pierre)
			if rng.randf() < 0.4:
				_decor(Vector3(x, 1.15, z), Vector3(0.08, 0.5, 0.08), m_pierre)
				_decor(Vector3(x, 1.25, z), Vector3(0.36, 0.08, 0.08), m_pierre)
	for p in [Vector3(42, 0, -2.8), Vector3(42, 0, 2.8), Vector3(51, 0, -12.5), Vector3(51, 0, 12.5)]:
		cylinder(nav, p + Vector3(0, 0.6, 0), 0.22, 1.2, m_bark)
		var c := MeshInstance3D.new()
		var cm := CylinderMesh.new()
		cm.top_radius = 0.0
		cm.bottom_radius = 0.75
		cm.height = 5.0
		c.mesh = cm
		c.material_override = m_leaves
		c.set_meta("merge", true)
		add_child(c)
		c.position = p + Vector3(0, 3.4, 0)


func _lamp(p: Vector3) -> void:
	cylinder(nav, p + Vector3(0, 1.8, 0), 0.08, 3.6, m_metal)
	box(self, p + Vector3(0, 3.7, 0), Vector3(0.35, 0.4, 0.35), m_metal, false)
	var bulb := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = 0.12
	sm.height = 0.24
	bulb.mesh = sm
	bulb.material_override = m_bulb
	add_child(bulb)
	bulb.position = p + Vector3(0, 3.45, 0)
	var l := OmniLight3D.new()
	l.light_color = Color(1.0, 0.78, 0.5)
	l.light_energy = 1.5
	l.omni_range = 11.0
	l.omni_attenuation = 1.3
	add_child(l)
	l.position = p + Vector3(0, 3.3, 0)
	lights.append(l)


func _bulb(p: Vector3, color := Color(1.0, 0.8, 0.55)) -> void:
	var l := OmniLight3D.new()
	l.light_color = color
	l.light_energy = 1.5
	l.omni_range = 9.0
	l.omni_attenuation = 1.2
	add_child(l)
	l.position = p
	lights.append(l)
	var bulb := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = 0.09
	sm.height = 0.18
	bulb.mesh = sm
	bulb.material_override = m_bulb
	add_child(bulb)
	bulb.position = p + Vector3(0, 0.05, 0)


func _v_lights() -> void:
	for p in [Vector3(-10.8, 0, -8.8), Vector3(10.8, 0, -8.8), Vector3(10.8, 0, 8.8), Vector3(-10.8, 0, 8.8),
			Vector3(18.5, 0, -4.4), Vector3(27.0, 0, 4.4), Vector3(36.5, 0, -4.4),
			Vector3(10.6, 0, 20.6), Vector3(42.0, 0, -4.0)]:
		_lamp(p)
	_bulb(Vector3(-18, 3.0, -2), Color(1.0, 0.75, 0.45))
	_bulb(Vector3(0, 3.0, -16))
	_bulb(Vector3(30, 5.5, -16), Color(1.0, 0.7, 0.4))
	_bulb(Vector3(30, 5.5, -9), Color(1.0, 0.7, 0.4))
	_bulb(Vector3(22, 3.0, 12))
	_bulb(Vector3(30, 3.0, 12))
	_bulb(Vector3(-4, 2.5, 16.5), Color(0.9, 0.85, 0.7))
	_bulb(Vector3(55, 3.0, 0), Color(0.6, 0.75, 1.0))
	_flicker = lights[lights.size() - 1]


func _v_windows() -> void:
	var defs := [
		[Vector3(-24, 0, -5), Vector3(1, 0, 0), "cafe"],
		[Vector3(-24, 0, 1), Vector3(1, 0, 0), "cafe"],
		[Vector3(-5, 0, -22), Vector3(0, 0, 1), "mairie"],
		[Vector3(5, 0, -22), Vector3(0, 0, 1), "mairie"],
		[Vector3(27, 0, -21), Vector3(0, 0, 1), "eglise"],
		[Vector3(24, 0, -18), Vector3(1, 0, 0), "eglise"],
		[Vector3(36, 0, -18), Vector3(-1, 0, 0), "eglise"],
		[Vector3(22, 0, 19), Vector3(0, 0, -1), "ferme"],
		[Vector3(30, 0, 19), Vector3(0, 0, -1), "ferme"],
		[Vector3(34, 0, 16.5), Vector3(-1, 0, 0), "ferme"],
	]
	for d in defs:
		var b := Barricade.new()
		b.room = d[2]
		add_child(b)
		b.build(d[0], d[1], 2.0, m_wood)
		windows.append(b)


func _v_doors() -> void:
	# Order matters: saved games store opened doors by index.
	var defs := [
		[Vector3(0, 0, -10), Vector3(1, 0, 0), 1000, ["place", "mairie"]],
		[Vector3(12, 0, 0), Vector3(0, 0, 1), 1000, ["place", "rue"]],
		[Vector3(0, 0, 10), Vector3(1, 0, 0), 750, ["place", "lavoir"]],
		[Vector3(30, 0, -5), Vector3(1, 0, 0), 1250, ["rue", "eglise"]],
		[Vector3(26, 0, 5), Vector3(1, 0, 0), 1250, ["rue", "ferme"]],
		[Vector3(40, 0, 0), Vector3(0, 0, 1), 2000, ["rue", "cimetiere", "chapelle"]],
	]
	for d in defs:
		var door := BuyDoor.new()
		add_child(door)
		var rs: Array[String] = []
		rs.assign(d[3])
		door.build(d[0], d[1], 3.0, 2.6, d[2], rs, nav, m_wood, m_metal)
		door.opened.connect(_on_door_opened)
		doors.append(door)


func _v_buyables() -> void:
	var walls := [
		[Vector3(-23.84, 1.5, -2.0), Vector3(1, 0, 0), "k14"],
		[Vector3(-18.0, 1.5, 3.84), Vector3(0, 0, -1), "grele"],
		[Vector3(-9.6, 1.5, -9.84), Vector3(0, 0, 1), "uzi"],
		[Vector3(0.0, 1.5, -21.84), Vector3(0, 0, 1), "vipere"],
		[Vector3(7.84, 1.5, -16.0), Vector3(-1, 0, 0), "hache"],
		[Vector3(16.0, 1.5, -4.84), Vector3(0, 0, 1), "faucon"],
		[Vector3(18.16, 1.5, 12.0), Vector3(1, 0, 0), "ouragan"],
	]
	for d in walls:
		var wb := WallBuy.new()
		add_child(wb)
		wb.build(d[0], d[1], d[2], m_chalk, m_board)
	var perks := [
		[Vector3(-14.0, 0, -7.35), Vector3(0, 0, 1), "double_detente"],
		[Vector3(-11.35, 0, 7.5), Vector3(1, 0, 0), "second_souffle"],
		[Vector3(-7.35, 0, -19.5), Vector3(1, 0, 0), "cuirasse"],
		[Vector3(21.0, 0, -4.5), Vector3(0, 0, 1), "pied_leger"],
		[Vector3(21.0, 0, 5.65), Vector3(0, 0, 1), "main_leste"],
	]
	for d in perks:
		var pm := PerkMachine.new()
		add_child(pm)
		pm.build(d[0], d[1], d[2], m_metal, nav)
	var mb := MysteryBox.new()
	add_child(mb)
	mb.build(Vector3(-19.0, 0, -7.45), Vector3(0, 0, 1), m_wood, m_metal, G.gun_mats(), nav)
	var forge := Forge.new()
	add_child(forge)
	forge.build(Vector3(32.0, 0, -20.2), Vector3(0, 0, 1), m_metal, G.gun_mats(), nav)
	power_switch = PowerSwitch.new()
	add_child(power_switch)
	power_switch.build(Vector3(-7.85, 1.4, -14.5), Vector3(1, 0, 0), m_metal)
	power_switch.switched.connect(_on_power)
	# Electric wire across the cemetery gate; its switch on the high street side.
	trap = ZapTrap.new()
	add_child(trap)
	trap.build(Vector3(39.84, 1.4, -3.0), Vector3(-1, 0, 0), Vector3(40, 0, -1.42), Vector3(40, 0, 1.42), doors[5], m_metal)


func _v_spawns() -> void:
	var defs := [
		[Vector3(-9.0, 0, -7.5), "place"], [Vector3(9.5, 0, -7.5), "place"],
		[Vector3(9.5, 0, 8.0), "place"], [Vector3(-4.5, 0, 8.5), "place"],
		[Vector3(14.5, 0, -3.3), "rue"], [Vector3(22.0, 0, 3.4), "rue"],
		[Vector3(27.5, 0, -3.3), "rue"], [Vector3(37.5, 0, 0.5), "rue"],
		[Vector3(-9.0, 0, 12.5), "lavoir"], [Vector3(9.0, 0, 13.0), "lavoir"],
		[Vector3(-9.5, 0, 20.5), "lavoir"], [Vector3(3.0, 0, 20.5), "lavoir"],
		[Vector3(44.2, 0, -10.0), "cimetiere"], [Vector3(49.0, 0, -7.0), "cimetiere"],
		[Vector3(44.2, 0, 10.0), "cimetiere"], [Vector3(49.0, 0, 7.0), "cimetiere"],
		[Vector3(55.5, 0, -10.0), "cimetiere"], [Vector3(55.5, 0, 10.0), "cimetiere"],
	]
	for d in defs:
		var g := GroundSpawn.new()
		add_child(g)
		g.build(d[0], d[1], m_dirt)
		ground_spawns.append(g)


func _v_objective() -> void:
	objective = Extraction.new()
	objective.name = "Extraction"
	add_child(objective)
	var defs := [
		["place", Vector3(-6.5, 0, 6.0)],
		["lavoir", Vector3(6.5, 0, 15.5)],
		["rue", Vector3(35.5, 0, 3.0)],
		["cimetiere", Vector3(47.8, 0, 5.2)],
	]
	for d in defs:
		var l := Lantern.new()
		add_child(l)
		l.build(d[1], d[0], m_pierre, nav)
		l.objective = objective
		lanterns.append(l)
	objective.lanterns = lanterns
	portal = ExtractionPortal.new()
	add_child(portal)
	portal.build(Vector3(57.85, 0, 0), Vector3(-1, 0, 0), m_pierre, m_wood)
	portal.objective = objective
	objective.portal = portal


## Fields, woods and a few far houses lost in the fog.
func _v_scenery() -> void:
	var outside := get_node("Outside") as Node3D
	var rng := RandomNumberGenerator.new()
	rng.seed = 11
	var placed := 0
	while placed < 60:
		var p := Vector3(rng.randf_range(-60, 90), 0, rng.randf_range(-50, 60))
		if p.x > -30 and p.x < 64 and p.z > -28 and p.z < 33:
			continue
		placed += 1
		var hgt := rng.randf_range(5.0, 9.0)
		cylinder(outside, p + Vector3(0, hgt / 2, 0), rng.randf_range(0.2, 0.35), hgt, m_bark, false)
		var leaf := MeshInstance3D.new()
		var sm := SphereMesh.new()
		sm.radius = rng.randf_range(1.5, 2.6)
		sm.height = sm.radius * 1.6
		leaf.mesh = sm
		leaf.material_override = m_leaves
		leaf.set_meta("merge", true)
		outside.add_child(leaf)
		leaf.position = p + Vector3(0, hgt, 0)
