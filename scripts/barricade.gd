class_name Barricade
extends Interactable
## A window boarded up with planks. Zombies tear planks off from outside and climb in once it is
## open; the player repairs it from inside (hold the use button) for a few points per plank.

const MAX_PLANKS := 6
const SILL := 1.0
const TOP := 2.3
const REPAIR_TIME := 0.75

var room := ""
var planks := MAX_PLANKS
var center := Vector3.ZERO      # centre of the opening on the wall's centre line (y = 0)
var inward := Vector3.FORWARD   # points into the room
var along := Vector3.RIGHT      # wall direction
var width := 2.0
var busy := false               # a zombie is climbing through
var climber: Node = null
var _busy_since := 0.0
var _plank_nodes: Array[Node3D] = []
var _repair_timer := 0.0
var _rest: Array[Transform3D] = []


func build(p_center: Vector3, p_inward: Vector3, p_width: float, wood: Material) -> void:
	center = p_center
	inward = p_inward.normalized()
	along = Vector3(-inward.z, 0, inward.x)
	width = p_width
	global_position = center + inward * 1.1 + Vector3(0, 1.0, 0)
	focus_point = center + Vector3(0, 1.6, 0)
	var rot_y := 0.0 if abs(along.x) > 0.5 else PI / 2
	setup_zone(Vector3(width + 1.2, 2.0, 1.8) if rot_y == 0.0 else Vector3(1.8, 2.0, width + 1.2))

	# Player blocker in the opening (zombies pass through it: they do not collide with the world
	# while climbing).
	var blocker := StaticBody3D.new()
	blocker.collision_layer = G.L_PLAYER_BLOCK
	blocker.collision_mask = 0
	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = Vector3(width, TOP - SILL, 0.3) if rot_y == 0.0 else Vector3(0.3, TOP - SILL, width)
	cs.shape = bs
	blocker.add_child(cs)
	add_child(blocker)
	blocker.global_position = center + Vector3(0, (SILL + TOP) / 2, 0)

	var rng := RandomNumberGenerator.new()
	rng.seed = int(abs(center.x * 13.0 + center.z * 7.0))
	for i in MAX_PLANKS:
		var plank := MeshInstance3D.new()
		var mesh := BoxMesh.new()
		mesh.size = Vector3(width + 0.35, 0.17, 0.05)
		plank.mesh = mesh
		plank.material_override = wood
		add_child(plank)
		var y := SILL + 0.18 + i * (TOP - SILL - 0.36) / (MAX_PLANKS - 1)
		plank.global_position = center + inward * (0.2 + 0.01 * i) + Vector3(0, y, 0)
		plank.rotation = Vector3(0, rot_y, rng.randf_range(-0.35, 0.35))
		_plank_nodes.append(plank)
		_rest.append(plank.global_transform)


## Zombie pulls one plank. Returns false when there was nothing left.
func tear() -> bool:
	if planks <= 0:
		return false
	planks -= 1
	var plank := _plank_nodes[planks]
	var tw := plank.create_tween()
	var out := plank.global_position - inward * 1.2 + Vector3(0, -0.6, 0)
	tw.tween_property(plank, "global_position", out, 0.25)
	tw.parallel().tween_property(plank, "rotation:x", 1.4, 0.25)
	tw.tween_callback(func(): plank.visible = false)
	G.play_at("plank_break", plank.global_position, self, -2.0, randf_range(0.9, 1.1))
	return true


func repair_one() -> void:
	if planks >= MAX_PLANKS:
		return
	var plank := _plank_nodes[planks]
	planks += 1
	plank.visible = true
	var target := _rest[planks - 1]
	plank.global_transform = target.translated(inward * 0.8 + Vector3(0, -0.5, 0))
	var tw := plank.create_tween()
	tw.tween_property(plank, "global_transform", target, 0.18)
	G.play_at("plank_place", target.origin, self, 0.0, randf_range(0.9, 1.1))


func repair_all() -> void:
	while planks < MAX_PLANKS:
		repair_one()


## One zombie climbs through at a time. A claim older than a few seconds (its zombie vanished
## without letting go) no longer counts, so the window can never stay blocked.
func claim(z: Node) -> void:
	busy = true
	climber = z
	_busy_since = Time.get_ticks_msec() / 1000.0


func release() -> void:
	busy = false
	climber = null


func is_busy() -> bool:
	if not busy:
		return false
	if climber == null or not is_instance_valid(climber) or Time.get_ticks_msec() / 1000.0 - _busy_since > 4.0:
		release()
		return false
	return true


func is_open() -> bool:
	return planks <= 0


func outside_point(slot := 0) -> Vector3:
	var lateral := (slot % 3 - 1) * 0.8
	var back := 0.75 + (slot / 3) * 0.9
	return center - inward * back + along * lateral


func inside_point() -> Vector3:
	return center + inward * 1.0


func get_hint(player: Node) -> String:
	if planks >= MAX_PLANKS:
		return ""
	return "%s réparer la barricade" % hold_text()


func is_hold() -> bool:
	return true


func hold(player: Node, delta: float) -> void:
	if planks >= MAX_PLANKS:
		_repair_timer = 0.0
		return
	_repair_timer += delta
	if _repair_timer >= REPAIR_TIME:
		_repair_timer = 0.0
		repair_one()
		if player.director and player.director.repair_points_left > 0:
			player.director.repair_points_left -= 10
			G.add_points(10)
