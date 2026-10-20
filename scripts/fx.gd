class_name Fx
extends RefCounted
## Small visual effects built on the fly: blood, dust, energy beams and blasts.

static var _blood_mat: StandardMaterial3D
static var _dust_mat: StandardMaterial3D
static var _cube: BoxMesh
static var _tracer_mat: StandardMaterial3D
static var _tracer_mesh: BoxMesh
static var _spark_mat: StandardMaterial3D


static func _mats() -> void:
	if _blood_mat:
		return
	_blood_mat = StandardMaterial3D.new()
	_blood_mat.albedo_color = Color(0.35, 0.02, 0.02)
	_blood_mat.roughness = 0.4
	_blood_mat.vertex_color_use_as_albedo = false
	_dust_mat = StandardMaterial3D.new()
	_dust_mat.albedo_color = Color(0.55, 0.52, 0.48)
	_dust_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_cube = BoxMesh.new()
	_cube.size = Vector3(0.05, 0.05, 0.05)


static func _burst(parent: Node, pos: Vector3, dir: Vector3, mat: Material, amount: int,
		speed: float, life: float, size: float, gravity := 9.8) -> void:
	if parent == null or not parent.is_inside_tree():
		return
	_mats()
	var p := CPUParticles3D.new()
	p.one_shot = true
	p.amount = amount
	p.lifetime = life
	p.explosiveness = 1.0
	p.mesh = _cube
	p.material_override = mat
	p.direction = dir
	p.spread = 35.0
	p.initial_velocity_min = speed * 0.4
	p.initial_velocity_max = speed
	p.gravity = Vector3(0, -gravity, 0)
	p.scale_amount_min = size * 0.5
	p.scale_amount_max = size
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(p)
	p.global_position = pos
	p.emitting = true
	var t := p.get_tree().create_timer(life + 0.2)
	t.timeout.connect(p.queue_free)


static func blood(parent: Node, pos: Vector3, dir: Vector3, big := false) -> void:
	_mats()
	_burst(parent, pos, dir, _blood_mat, 22 if big else 9, 4.5 if big else 2.5, 0.6, 1.6 if big else 1.0)


static func impact(parent: Node, pos: Vector3, normal: Vector3) -> void:
	_mats()
	_burst(parent, pos + normal * 0.02, normal, _dust_mat, 6, 2.0, 0.35, 0.6, 4.0)


static func beam(parent: Node, from: Vector3, to: Vector3, color: Color) -> void:
	if parent == null or not parent.is_inside_tree():
		return
	var mi := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	var length := from.distance_to(to)
	cm.top_radius = 0.035
	cm.bottom_radius = 0.035
	cm.height = length
	cm.radial_segments = 6
	mi.mesh = cm
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m.albedo_color = Color(color.r, color.g, color.b, 0.9)
	mi.material_override = m
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mi)
	mi.global_position = (from + to) / 2
	var dir := (to - from).normalized()
	var up := Vector3.UP if abs(dir.dot(Vector3.UP)) < 0.99 else Vector3.RIGHT
	mi.look_at(to, up)
	mi.rotate_object_local(Vector3.RIGHT, PI / 2)
	var tw := mi.create_tween()
	tw.tween_property(m, "albedo_color:a", 0.0, 0.18)
	tw.tween_callback(mi.queue_free)


static func blast(parent: Node, pos: Vector3, radius: float, color: Color) -> void:
	if parent == null or not parent.is_inside_tree():
		return
	var mi := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = 0.5
	sm.height = 1.0
	sm.radial_segments = 16
	sm.rings = 8
	mi.mesh = sm
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m.albedo_color = Color(color.r, color.g, color.b, 0.7)
	mi.material_override = m
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mi)
	mi.global_position = pos
	mi.scale = Vector3.ONE * 0.3
	var light := OmniLight3D.new()
	light.light_color = color
	light.light_energy = 3.0
	light.omni_range = radius * 2.5
	mi.add_child(light)
	var tw := mi.create_tween()
	tw.tween_property(mi, "scale", Vector3.ONE * radius * 2.0, 0.25).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(m, "albedo_color:a", 0.0, 0.35)
	tw.parallel().tween_property(light, "light_energy", 0.0, 0.35)
	tw.tween_callback(mi.queue_free)


## A red tracer streaking from the muzzle to where the bullet stopped (ultimate weapons).
static func tracer(parent: Node, from: Vector3, to: Vector3) -> void:
	if parent == null or not parent.is_inside_tree():
		return
	if _tracer_mat == null:
		_tracer_mat = StandardMaterial3D.new()
		_tracer_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_tracer_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		_tracer_mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
		_tracer_mat.albedo_color = Color(1.0, 0.12, 0.06, 1.0)
		_tracer_mesh = BoxMesh.new()
		_tracer_mesh.size = Vector3(0.018, 0.018, 1.0)
		_spark_mat = StandardMaterial3D.new()
		_spark_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_spark_mat.albedo_color = Color(1.0, 0.2, 0.1)
	var d := to - from
	var dist := d.length()
	if dist < 0.5:
		return
	var seg := minf(2.2, dist * 0.6)
	var mi := MeshInstance3D.new()
	mi.mesh = _tracer_mesh
	mi.material_override = _tracer_mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mi)
	var dir := d / dist
	var up := Vector3.UP if absf(dir.y) < 0.98 else Vector3.RIGHT
	var basis := Basis.looking_at(dir, up) * Basis.from_scale(Vector3(1, 1, seg))
	var start := from + dir * seg * 0.5
	var finish := to - dir * seg * 0.5
	mi.global_transform = Transform3D(basis, start)
	var tw := mi.create_tween()
	tw.tween_property(mi, "global_position", finish, maxf(0.03, (dist - seg) / 260.0))
	tw.tween_callback(mi.queue_free)
	# A red spark where it lands.
	_burst(parent, to - dir * 0.05, -dir, _spark_mat, 5, 2.5, 0.25, 0.5, 6.0)
