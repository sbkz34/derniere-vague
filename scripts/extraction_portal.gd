class_name ExtractionPortal
extends Interactable
## The sealed door at the back of the cemetery chapel. It opens once the four lanterns burn;
## stepping through starts the final stand.

var open := false
var objective: Node
var front := Vector3.ZERO

var _panel: MeshInstance3D
var _glow: MeshInstance3D
var _glow_mat: StandardMaterial3D
var _light: OmniLight3D
var _t := 0.0
var _chains: Array[Node3D] = []


## `pos`: foot of the door on the wall; `inward`: the direction it faces (into the chapel).
func build(pos: Vector3, inward: Vector3, stone: Material, wood: Material) -> void:
	front = pos + inward * 2.5
	global_position = pos + inward * 1.2 + Vector3(0, 1.0, 0)
	focus_point = pos + Vector3(0, 1.4, 0)
	var on_x := absf(inward.x) > 0.5
	setup_zone(Vector3(2.0, 2.4, 3.0) if on_x else Vector3(3.0, 2.4, 2.0))
	var holder := Node3D.new()
	add_child(holder)
	holder.global_position = pos
	holder.look_at(pos - inward, Vector3.UP)
	# Arch: two pillars and a lintel standing proud of the wall.
	for sx in [-1, 1]:
		_box(holder, Vector3(1.1 * sx, 1.4, 0.2), Vector3(0.35, 2.8, 0.4), stone)
	_box(holder, Vector3(0, 2.95, 0.2), Vector3(2.6, 0.4, 0.45), stone)
	_box(holder, Vector3(0, 3.3, 0.2), Vector3(1.2, 0.3, 0.4), stone)
	_panel = _box(holder, Vector3(0, 1.35, 0.12), Vector3(1.85, 2.7, 0.1), wood)
	# Chains and a seal across the closed door.
	var iron := StandardMaterial3D.new()
	iron.albedo_color = Color(0.12, 0.12, 0.13)
	iron.metallic = 0.6
	for k in [-1, 1]:
		var c := _box(holder, Vector3(0, 1.4, 0.2), Vector3(2.2, 0.06, 0.04), iron)
		c.rotation.z = 0.75 * k
		_chains.append(c)
	_glow_mat = StandardMaterial3D.new()
	_glow_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_glow_mat.albedo_color = Color(0.6, 0.85, 1.0)
	_glow = _box(holder, Vector3(0, 1.35, 0.1), Vector3(1.85, 2.7, 0.04), _glow_mat)
	_glow.visible = false
	_light = OmniLight3D.new()
	_light.light_color = Color(0.55, 0.8, 1.0)
	_light.light_energy = 0.0
	_light.omni_range = 9.0
	holder.add_child(_light)
	_light.position = Vector3(0, 1.5, 1.2)


func _box(parent: Node3D, pos: Vector3, size: Vector3, mat: Material) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	mi.material_override = mat
	parent.add_child(mi)
	mi.position = pos
	return mi


func set_open(on: bool) -> void:
	open = on
	_panel.visible = not on
	_glow.visible = on
	for c in _chains:
		c.visible = not on


func get_hint(_player: Node) -> String:
	return objective.portal_hint() if objective else ""


func interact(_player: Node) -> void:
	if objective:
		objective.start_final()


func _process(delta: float) -> void:
	if not open:
		return
	_t += delta
	var pulse := 0.5 + 0.5 * sin(_t * 2.5)
	_glow_mat.albedo_color = Color(0.45, 0.75, 1.0).lerp(Color(0.9, 0.97, 1.0), pulse)
	_light.light_energy = 2.0 + 1.5 * pulse
