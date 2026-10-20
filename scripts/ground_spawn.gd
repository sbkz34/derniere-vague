class_name GroundSpawn
extends Node3D
## A patch of loose earth outdoors where zombies claw their way up (instead of a window).

var room := ""


func build(pos: Vector3, p_room: String, dirt: Material) -> void:
	room = p_room
	global_position = pos
	# A low mound of earth so the player can see where they come from.
	var mound := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = 0.9
	sm.height = 0.35
	mound.mesh = sm
	mound.material_override = dirt
	mound.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mound.set_meta("merge", true)
	add_child(mound)
	mound.position.y = 0.0
	mound.scale = Vector3(1.0, 1.0, 0.8)
