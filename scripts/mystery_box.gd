class_name MysteryBox
extends Interactable
## Pay, the lid opens, weapons spin above the box and one is offered for a few seconds.

enum State { IDLE, ROLLING, READY }

var state := State.IDLE
var _lid: Node3D
var _display: Node3D
var _label: Label3D
var _result := ""
var _timer := 0.0
var _swap := 0.0
var _swap_every := 0.08
var _mats: Dictionary
var _light: OmniLight3D


func build(pos: Vector3, facing: Vector3, wood: Material, metal: Material, mats: Dictionary,
		nav_parent: Node3D) -> void:
	_mats = mats
	global_position = pos + facing * 1.1 + Vector3(0, 1.0, 0)
	focus_point = pos + Vector3(0, 0.8, 0)
	setup_zone(Vector3(2.4, 2.0, 2.0) if abs(facing.z) > 0.5 else Vector3(2.0, 2.0, 2.4))

	var body := StaticBody3D.new()
	body.collision_layer = G.L_WORLD
	body.collision_mask = 0
	nav_parent.add_child(body)
	body.global_position = pos
	body.look_at(pos - facing, Vector3.UP)
	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = Vector3(1.6, 0.8, 0.8)
	cs.shape = bs
	cs.position.y = 0.4
	body.add_child(cs)
	_box(body, Vector3(0, 0.38, 0), Vector3(1.6, 0.66, 0.8), wood)
	for x in [-0.78, 0.78]:
		_box(body, Vector3(x, 0.38, 0), Vector3(0.06, 0.7, 0.84), metal)
	_lid = Node3D.new()
	body.add_child(_lid)
	_lid.position = Vector3(0, 0.71, -0.4)
	var lid_mesh := _box(_lid, Vector3(0, 0.06, 0.4), Vector3(1.62, 0.12, 0.82), wood)
	lid_mesh.name = "LidMesh"
	var q := StandardMaterial3D.new()
	q.albedo_color = Color(0.4, 0.9, 1.0)
	q.emission_enabled = true
	q.emission = Color(0.3, 0.8, 1.0)
	q.emission_energy_multiplier = 1.6
	for side in [-1, 1]:
		var l := Label3D.new()
		l.text = "?"
		l.font_size = 120
		l.pixel_size = 0.004
		l.modulate = Color(0.5, 0.95, 1.0)
		l.outline_size = 10
		l.outline_modulate = Color(0, 0.15, 0.25)
		body.add_child(l)
		l.position = Vector3(0.45 * side, 0.4, 0.41)
	var price_label := Label3D.new()
	price_label.text = "%d" % G.BOX_PRICE
	price_label.font_size = 40
	price_label.pixel_size = 0.004
	price_label.modulate = Color(1, 0.85, 0.3)
	price_label.outline_size = 8
	price_label.outline_modulate = Color(0, 0, 0)
	body.add_child(price_label)
	price_label.position = Vector3(0, 0.4, 0.41)

	_display = Node3D.new()
	body.add_child(_display)
	_display.position = Vector3(0, 1.15, 0)
	_label = Label3D.new()
	_label.font_size = 40
	_label.pixel_size = 0.004
	_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_label.outline_size = 8
	_label.outline_modulate = Color(0, 0, 0)
	_label.modulate = Color(0.6, 1, 1)
	body.add_child(_label)
	_label.position = Vector3(0, 1.6, 0)
	_light = OmniLight3D.new()
	_light.light_color = Color(0.4, 0.85, 1.0)
	_light.light_energy = 0.7
	_light.omni_range = 3.5
	body.add_child(_light)
	_light.position = Vector3(0, 1.2, 0)


func _box(parent: Node3D, pos: Vector3, size: Vector3, mat: Material) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	mi.material_override = mat
	parent.add_child(mi)
	mi.position = pos
	return mi


func get_hint(player: Node) -> String:
	match state:
		State.IDLE:
			return "%s ouvrir la caisse mystère %s" % [use_text(), price_text(G.BOX_PRICE)]
		State.READY:
			return "%s prendre : %s" % [use_text(), G.WEAPONS[_result].name]
	return ""


func interact(player: Node) -> void:
	match state:
		State.IDLE:
			if G.spend(G.BOX_PRICE):
				_start(player)
		State.READY:
			player.give_weapon(_result, 0)
			_close()


func _start(player: Node) -> void:
	state = State.ROLLING
	_timer = 4.0
	_swap = 0.0
	_swap_every = 0.07
	var pool: Array = []
	for id in G.BOX_POOL:
		if not player.has_weapon(id):
			pool.append(id)
	if pool.is_empty():
		pool = ["titan"]
	_result = pool[randi() % pool.size()]
	var tw := create_tween()
	tw.tween_property(_lid, "rotation:x", -1.9, 0.5).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	G.play_at("box", global_position, get_parent())
	_light.light_energy = 1.6


func _close() -> void:
	state = State.IDLE
	_clear_display()
	_label.text = ""
	_light.light_energy = 0.7
	var tw := create_tween()
	tw.tween_property(_lid, "rotation:x", 0.0, 0.4)


func _clear_display() -> void:
	for c in _display.get_children():
		c.queue_free()


func _show(id: String) -> void:
	_clear_display()
	var m := GunShapes.build_model(id, _mats, 1.0)
	_display.add_child(m)
	m.rotation.y = PI / 2
	var sh := GunShapes.shape(id)
	m.position = Vector3(sh.muzzle.x * 0.5 - sh.grip.x, 0, 0)
	_label.text = G.WEAPONS[id].name


func _process(delta: float) -> void:
	match state:
		State.ROLLING:
			_timer -= delta
			_swap -= delta
			_display.position.y = lerp(_display.position.y, 1.35, delta * 2.0)
			if _swap <= 0.0:
				_swap_every *= 1.08
				_swap = _swap_every
				var ids: Array = G.BOX_POOL
				_show(ids[randi() % ids.size()])
			if _timer <= 0.0:
				_show(_result)
				state = State.READY
				_timer = 9.0
		State.READY:
			_timer -= delta
			_display.position.y = 1.35 - (9.0 - _timer) * 0.04
			if _timer <= 0.0:
				_close()
		_:
			_display.position.y = 1.0
