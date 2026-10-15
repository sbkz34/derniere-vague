class_name PowerUp
extends Area3D
## A glowing bonus dropped by a zombie. Walk into it to take it.

signal taken(kind: String, pos: Vector3)

var kind := "ammo"
var _life := 26.0
var _visual: Node3D
var _t := 0.0


func setup(p_kind: String) -> void:
	kind = p_kind
	collision_layer = G.L_PICKUP
	collision_mask = G.L_PLAYER
	monitoring = true
	var cs := CollisionShape3D.new()
	var sp := SphereShape3D.new()
	sp.radius = 0.9
	cs.shape = sp
	add_child(cs)
	body_entered.connect(_on_body)
	var col: Color = G.POWERUPS[kind].color
	var mat := StandardMaterial3D.new()
	mat.albedo_color = col
	mat.emission_enabled = true
	mat.emission = col
	mat.emission_energy_multiplier = 2.5
	var dark := StandardMaterial3D.new()
	dark.albedo_color = Color(0.02, 0.02, 0.02)
	_visual = Node3D.new()
	add_child(_visual)
	_visual.position.y = 1.0
	match kind:
		"ammo":
			_mesh(BoxMesh.new(), Vector3(0.5, 0.32, 0.32), Vector3.ZERO, mat)
			for i in 3:
				_mesh(CylinderMesh.new(), Vector3(0.06, 0.25, 0.06), Vector3(-0.12 + i * 0.12, 0.28, 0), mat)
		"double":
			var l := Label3D.new()
			l.text = "x2"
			l.font_size = 160
			l.pixel_size = 0.005
			l.modulate = col
			l.outline_size = 16
			l.outline_modulate = Color(0.3, 0.2, 0)
			l.double_sided = true
			_visual.add_child(l)
		"insta":
			_mesh(SphereMesh.new(), Vector3(0.45, 0.42, 0.45), Vector3.ZERO, mat)
			_mesh(BoxMesh.new(), Vector3(0.28, 0.14, 0.3), Vector3(0, -0.22, 0.02), mat)
			for x in [-0.1, 0.1]:
				_mesh(SphereMesh.new(), Vector3(0.12, 0.12, 0.12), Vector3(x, 0.02, 0.18), dark)
		"bomb":
			_mesh(SphereMesh.new(), Vector3(0.5, 0.5, 0.5), Vector3.ZERO, mat)
			_mesh(CylinderMesh.new(), Vector3(0.05, 0.25, 0.05), Vector3(0.1, 0.3, 0), dark)
		"carpenter":
			_mesh(BoxMesh.new(), Vector3(0.36, 0.14, 0.14), Vector3(0, 0.25, 0), mat)
			_mesh(CylinderMesh.new(), Vector3(0.07, 0.6, 0.07), Vector3(0, -0.05, 0), mat)
	var light := OmniLight3D.new()
	light.light_color = col
	light.light_energy = 1.2
	light.omni_range = 3.0
	add_child(light)
	light.position.y = 1.0
	var name_label := Label3D.new()
	name_label.text = G.POWERUPS[kind].name
	name_label.font_size = 32
	name_label.pixel_size = 0.004
	name_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	name_label.modulate = col
	name_label.outline_size = 6
	name_label.outline_modulate = Color(0, 0, 0)
	add_child(name_label)
	name_label.position.y = 1.75


func _mesh(mesh: PrimitiveMesh, size: Vector3, pos: Vector3, mat: Material) -> void:
	var mi := MeshInstance3D.new()
	if mesh is BoxMesh:
		(mesh as BoxMesh).size = size
	elif mesh is SphereMesh:
		(mesh as SphereMesh).radius = size.x / 2
		(mesh as SphereMesh).height = size.y
	elif mesh is CylinderMesh:
		(mesh as CylinderMesh).top_radius = size.x
		(mesh as CylinderMesh).bottom_radius = size.x
		(mesh as CylinderMesh).height = size.y
	mi.mesh = mesh
	mi.material_override = mat
	mi.position = pos
	_visual.add_child(mi)


func _process(delta: float) -> void:
	_t += delta
	_life -= delta
	_visual.rotation.y += delta * 2.0
	_visual.position.y = 1.0 + sin(_t * 3.0) * 0.12
	if _life < 6.0:
		visible = fmod(_t, 0.4 if _life > 2.5 else 0.2) < (0.25 if _life > 2.5 else 0.1)
	if _life <= 0.0:
		queue_free()


func _on_body(body: Node) -> void:
	if body.is_in_group("player"):
		taken.emit(kind, global_position)
		G.play("powerup_pick", 2.0)
		queue_free()
