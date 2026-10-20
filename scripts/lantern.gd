class_name Lantern
extends Interactable
## A "lanterne des morts": a medieval stone column with a little lantern chamber on top, lit to
## guide the souls. The Village has four; relighting all of them opens the way out.

var id := ""
var center := Vector3.ZERO
var lit := false
var paid := false
var defending := false
var progress := 0.0
var objective: Node

var _flame: MeshInstance3D
var _flame_mat: StandardMaterial3D
var _light: OmniLight3D
var _ring: MeshInstance3D
var _ring_mat: StandardMaterial3D
var _t := 0.0


func build(pos: Vector3, p_id: String, stone: Material, nav_parent: Node3D) -> void:
	id = p_id
	center = pos
	global_position = pos + Vector3(0, 1.0, 0)
	focus_point = pos + Vector3(0, 1.8, 0)
	setup_zone(Vector3(3.4, 2.4, 3.4))
	var body := StaticBody3D.new()
	body.collision_layer = G.L_WORLD
	body.collision_mask = 0
	var cs := CollisionShape3D.new()
	var cyl := CylinderShape3D.new()
	cyl.radius = 0.6
	cyl.height = 4.6
	cs.shape = cyl
	cs.position.y = 2.3
	body.add_child(cs)
	nav_parent.add_child(body)
	body.global_position = pos
	var holder := Node3D.new()
	add_child(holder)
	holder.global_position = pos
	_mesh_box(holder, Vector3(0, 0.25, 0), Vector3(1.2, 0.5, 1.2), stone)
	_mesh_box(holder, Vector3(0, 0.6, 0), Vector3(0.9, 0.2, 0.9), stone)
	var col := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = 0.3
	cm.bottom_radius = 0.38
	cm.height = 2.8
	cm.radial_segments = 10
	col.mesh = cm
	col.material_override = stone
	col.set_meta("merge", true)
	holder.add_child(col)
	col.position.y = 2.1
	_mesh_box(holder, Vector3(0, 3.55, 0), Vector3(0.8, 0.1, 0.8), stone)
	for sx in [-1, 1]:
		for sz in [-1, 1]:
			_mesh_box(holder, Vector3(0.3 * sx, 3.9, 0.3 * sz), Vector3(0.09, 0.6, 0.09), stone)
	_mesh_box(holder, Vector3(0, 4.25, 0), Vector3(0.8, 0.1, 0.8), stone)
	var cap := MeshInstance3D.new()
	var capm := CylinderMesh.new()
	capm.top_radius = 0.0
	capm.bottom_radius = 0.5
	capm.height = 0.8
	capm.radial_segments = 4
	cap.mesh = capm
	cap.material_override = stone
	cap.set_meta("merge", true)
	holder.add_child(cap)
	cap.position.y = 4.7
	cap.rotation.y = PI / 4
	_mesh_box(holder, Vector3(0, 5.3, 0), Vector3(0.06, 0.45, 0.06), stone)
	_mesh_box(holder, Vector3(0, 5.38, 0), Vector3(0.26, 0.06, 0.06), stone)
	_flame_mat = StandardMaterial3D.new()
	_flame_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_flame_mat.albedo_color = Color(1.0, 0.45, 0.15)
	_flame = MeshInstance3D.new()
	var fm := SphereMesh.new()
	fm.radius = 0.13
	fm.height = 0.3
	_flame.mesh = fm
	_flame.material_override = _flame_mat
	holder.add_child(_flame)
	_flame.position.y = 3.85
	_light = OmniLight3D.new()
	_light.light_color = Color(1.0, 0.5, 0.2)
	_light.light_energy = 0.2
	_light.omni_range = 3.0
	holder.add_child(_light)
	_light.position.y = 3.85
	# Ring on the ground showing the area to hold during the defence.
	_ring_mat = StandardMaterial3D.new()
	_ring_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_ring_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_ring_mat.albedo_color = Color(0.5, 0.8, 1.0, 0.35)
	_ring = MeshInstance3D.new()
	var tm := TorusMesh.new()
	tm.inner_radius = 7.8
	tm.outer_radius = 8.0
	tm.rings = 48
	tm.ring_segments = 4
	_ring.mesh = tm
	_ring.material_override = _ring_mat
	_ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	holder.add_child(_ring)
	_ring.position.y = 0.05
	_ring.scale = Vector3(1, 0.1, 1)
	_ring.visible = false


func _mesh_box(parent: Node3D, pos: Vector3, size: Vector3, mat: Material) -> void:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	mi.material_override = mat
	mi.set_meta("merge", true)
	parent.add_child(mi)
	mi.position = pos


func get_hint(_player: Node) -> String:
	return objective.lantern_hint(self) if objective else ""


func interact(_player: Node) -> void:
	if objective:
		objective.try_light(self)


func set_state(state: String) -> void:
	defending = state == "defend"
	lit = state == "lit"
	_ring.visible = defending
	if lit:
		monitorable = false


func _process(delta: float) -> void:
	_t += delta
	var flick := 0.85 + 0.15 * sin(_t * 17.0) * sin(_t * 7.3)
	if lit:
		_flame_mat.albedo_color = Color(0.75, 0.92, 1.0)
		_light.light_color = Color(0.55, 0.8, 1.0)
		_light.light_energy = 3.0 * flick
		_light.omni_range = 11.0
		_flame.scale = Vector3.ONE * (1.3 + 0.1 * sin(_t * 9.0))
	elif defending:
		var p := clampf(progress, 0.0, 1.0)
		_flame_mat.albedo_color = Color(1.0, 0.45, 0.15).lerp(Color(0.75, 0.92, 1.0), p)
		_light.light_color = _flame_mat.albedo_color
		_light.light_energy = (0.5 + 2.5 * p) * flick
		_light.omni_range = 4.0 + 7.0 * p
		_flame.scale = Vector3.ONE * (0.6 + 0.7 * p) * flick
		_ring_mat.albedo_color.a = 0.25 + 0.15 * sin(_t * 4.0)
	else:
		# A dying ember.
		_flame_mat.albedo_color = Color(0.7, 0.25, 0.08)
		_light.light_color = Color(1.0, 0.4, 0.15)
		_light.light_energy = 0.25 * flick
		_light.omni_range = 2.5
		_flame.scale = Vector3.ONE * 0.45
