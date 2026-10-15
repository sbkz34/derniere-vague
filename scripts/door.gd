class_name BuyDoor
extends Interactable
## A boarded doorway between two rooms. Buying it opens the way and unlocks the other room
## (its windows start spawning zombies).

signal opened(door: BuyDoor)

var price := 750
var rooms: Array[String] = []
var blocker: StaticBody3D
var panel: Node3D
var _labels: Array[Label3D] = []


func build(center: Vector3, along: Vector3, width: float, height: float, p_price: int,
		p_rooms: Array[String], nav_parent: Node3D, wood: Material, metal: Material) -> void:
	price = p_price
	rooms = p_rooms
	var on_x := absf(along.x) > 0.5
	var normal := Vector3(0, 0, 1) if on_x else Vector3(1, 0, 0)
	global_position = center + Vector3(0, 1.0, 0)
	focus_point = center + Vector3(0, 1.4, 0)
	setup_zone(Vector3(width + 0.6, 2.0, 3.6) if on_x else Vector3(3.6, 2.0, width + 0.6))

	blocker = StaticBody3D.new()
	blocker.collision_layer = G.L_WORLD
	blocker.collision_mask = 0
	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = Vector3(width, height, 0.35) if on_x else Vector3(0.35, height, width)
	cs.shape = bs
	blocker.add_child(cs)
	nav_parent.add_child(blocker)
	blocker.global_position = center + Vector3(0, height / 2, 0)

	panel = Node3D.new()
	add_child(panel)
	panel.global_position = center
	var rot := 0.0 if on_x else PI / 2
	panel.rotation.y = rot
	# Cross-braced planks with a metal frame.
	for i in 7:
		var p := MeshInstance3D.new()
		var m := BoxMesh.new()
		m.size = Vector3(width / 7.0 - 0.03, height - 0.05, 0.12)
		p.mesh = m
		p.material_override = wood
		panel.add_child(p)
		p.position = Vector3(-width / 2 + (i + 0.5) * width / 7.0, height / 2, 0)
	for k in 2:
		var brace := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = Vector3(sqrt(width * width + height * height) * 0.95, 0.22, 0.08)
		brace.mesh = bm
		brace.material_override = wood
		panel.add_child(brace)
		brace.position = Vector3(0, height / 2, 0.1 * (1 if k == 0 else -1))
		brace.rotation.z = atan2(height, width) * (1 if k == 0 else -1)
	for y in [0.3, height - 0.3]:
		var bar := MeshInstance3D.new()
		var mm := BoxMesh.new()
		mm.size = Vector3(width, 0.12, 0.3)
		bar.mesh = mm
		bar.material_override = metal
		panel.add_child(bar)
		bar.position = Vector3(0, y, 0)
	for side in [-1, 1]:
		var l := Label3D.new()
		l.text = "%d" % price
		l.font_size = 64
		l.pixel_size = 0.004
		l.outline_size = 12
		l.modulate = Color(1, 0.85, 0.3)
		l.outline_modulate = Color(0, 0, 0, 0.9)
		panel.add_child(l)
		l.position = Vector3(0, 1.7, 0.2 * side)
		l.rotation.y = 0.0 if side > 0 else PI
		_labels.append(l)
	var _n := normal


func get_hint(_player: Node) -> String:
	if not enabled:
		return ""
	return "%s ouvrir le passage %s" % [use_text(), price_text(price)]


## Opens without paying (restoring a saved game).
func open_free() -> void:
	if not enabled:
		return
	enabled = false
	monitorable = false
	panel.visible = false
	blocker.queue_free()
	opened.emit(self)


func interact(_player: Node) -> void:
	if not enabled or not G.spend(price):
		return
	enabled = false
	monitorable = false
	G.play_at("door", global_position, get_parent())
	var tw := create_tween()
	tw.tween_property(panel, "position:y", panel.position.y + 3.2, 1.0).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.tween_callback(func(): panel.visible = false)
	blocker.queue_free()
	opened.emit(self)
