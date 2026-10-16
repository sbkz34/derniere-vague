class_name PowerSwitch
extends Interactable
## The breaker: until it is thrown, perk machines and the Forge have no power.

signal switched(silent: bool)

var _lever: Node3D
var _lamp: StandardMaterial3D
var _light: OmniLight3D


func build(pos: Vector3, inward: Vector3, metal: Material) -> void:
	global_position = pos + inward * 0.9
	focus_point = pos
	var on_x := absf(inward.z) > 0.5
	setup_zone(Vector3(2.0, 2.0, 1.8) if on_x else Vector3(1.8, 2.0, 2.0))
	var holder := Node3D.new()
	add_child(holder)
	holder.global_position = pos
	holder.look_at(pos - inward, Vector3.UP)
	var box := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(0.7, 0.9, 0.25)
	box.mesh = bm
	box.material_override = metal
	holder.add_child(box)
	box.position.z = 0.12
	var stripes := StandardMaterial3D.new()
	stripes.albedo_color = Color(0.9, 0.75, 0.1)
	var band := MeshInstance3D.new()
	var bb := BoxMesh.new()
	bb.size = Vector3(0.72, 0.08, 0.26)
	band.mesh = bb
	band.material_override = stripes
	holder.add_child(band)
	band.position = Vector3(0, 0.36, 0.12)
	_lever = Node3D.new()
	holder.add_child(_lever)
	_lever.position = Vector3(0.15, -0.05, 0.27)
	var handle := MeshInstance3D.new()
	var hm := BoxMesh.new()
	hm.size = Vector3(0.06, 0.32, 0.06)
	handle.mesh = hm
	var dark := StandardMaterial3D.new()
	dark.albedo_color = Color(0.1, 0.1, 0.1)
	handle.material_override = dark
	_lever.add_child(handle)
	handle.position.y = 0.14
	var knob := MeshInstance3D.new()
	var km := BoxMesh.new()
	km.size = Vector3(0.12, 0.08, 0.08)
	knob.mesh = km
	var red := StandardMaterial3D.new()
	red.albedo_color = Color(0.8, 0.1, 0.05)
	knob.material_override = red
	_lever.add_child(knob)
	knob.position.y = 0.3
	_lever.rotation.x = 0.5
	_lamp = StandardMaterial3D.new()
	_lamp.albedo_color = Color(1, 0.1, 0.05)
	_lamp.emission_enabled = true
	_lamp.emission = Color(1, 0.1, 0.05)
	_lamp.emission_energy_multiplier = 3.0
	var lamp := MeshInstance3D.new()
	var lm := SphereMesh.new()
	lm.radius = 0.05
	lm.height = 0.1
	lamp.mesh = lm
	lamp.material_override = _lamp
	holder.add_child(lamp)
	lamp.position = Vector3(-0.2, 0.2, 0.26)
	var label := Label3D.new()
	label.text = "COURANT"
	label.font_size = 44
	label.pixel_size = 0.004
	label.outline_size = 8
	label.modulate = Color(0.95, 0.9, 0.7)
	label.outline_modulate = Color(0, 0, 0)
	holder.add_child(label)
	label.position = Vector3(0, 0.6, 0.26)
	_light = OmniLight3D.new()
	_light.light_color = Color(1, 0.2, 0.1)
	_light.light_energy = 0.5
	_light.omni_range = 2.0
	holder.add_child(_light)
	_light.position = Vector3(0, 0, 0.6)


func get_hint(_player: Node) -> String:
	if not enabled:
		return ""
	return "%s rétablir le courant" % use_text()


func interact(_player: Node) -> void:
	if not enabled:
		return
	turn_on(false)


func turn_on(silent: bool) -> void:
	if not enabled:
		return
	enabled = false
	_lamp.albedo_color = Color(0.2, 1, 0.3)
	_lamp.emission = Color(0.2, 1, 0.3)
	_light.light_color = Color(0.2, 1, 0.3)
	if silent:
		_lever.rotation.x = PI - 0.5
	else:
		var tw := create_tween()
		tw.tween_property(_lever, "rotation:x", PI - 0.5, 0.25).set_trans(Tween.TRANS_BACK)
		G.play("power_on", 0.0)
		G.say("LE COURANT EST RÉTABLI", Color(0.5, 1.0, 0.6))
	switched.emit(silent)
