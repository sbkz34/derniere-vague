class_name WeaponView
extends Node3D
## First-person arms and weapon, attached to the camera. Purely visual: the player script tells
## it what happens (shot, reload, swap, knife, drink) and it animates.

var _gun: Node3D
var _gun_holder: Node3D
var _arms: Node3D
var _flash: MeshInstance3D
var _flash_light: OmniLight3D
var _knife: Node3D
var _bottle: MeshInstance3D
var _bottle_mat: StandardMaterial3D
var _kind := "pistol"
var _muzzle := Vector3.ZERO

var ads := 0.0
var hidden_by_scope := false
var _kick := 0.0
var _kick_rot := 0.0
var _bob := 0.0
var _sway := Vector2.ZERO
var _flash_t := 0.0
var _anim := ""          # "", "reload", "swap", "knife", "drink"
var _anim_t := 0.0
var _anim_len := 1.0
var _pending_weapon: Dictionary = {}
var _pending_set := false
var _skin: StandardMaterial3D
var _sleeve: StandardMaterial3D
var _glove: StandardMaterial3D


func _ready() -> void:
	physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	_skin = StandardMaterial3D.new()
	_skin.albedo_color = Color(0.72, 0.55, 0.42)
	_skin.roughness = 0.8
	_sleeve = StandardMaterial3D.new()
	_sleeve.albedo_color = Color(0.17, 0.2, 0.14)
	_sleeve.roughness = 0.9
	_glove = StandardMaterial3D.new()
	_glove.albedo_color = Color(0.08, 0.07, 0.06)
	_glove.roughness = 0.9
	_gun_holder = Node3D.new()
	add_child(_gun_holder)

	var fm := StandardMaterial3D.new()
	fm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	fm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	fm.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	fm.albedo_color = Color(1.0, 0.75, 0.3, 0.9)
	fm.billboard_mode = BaseMaterial3D.BILLBOARD_DISABLED
	_flash = MeshInstance3D.new()
	var q := QuadMesh.new()
	q.size = Vector2(0.18, 0.18)
	_flash.mesh = q
	_flash.material_override = fm
	_flash.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_flash.visible = false
	_flash_light = OmniLight3D.new()
	_flash_light.light_color = Color(1.0, 0.75, 0.4)
	_flash_light.light_energy = 2.5
	_flash_light.omni_range = 5.0
	_flash_light.visible = false
	add_child(_flash_light)

	_knife = Node3D.new()
	add_child(_knife)
	var blade := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(0.012, 0.035, 0.22)
	blade.mesh = bm
	var steel := StandardMaterial3D.new()
	steel.albedo_color = Color(0.75, 0.77, 0.8)
	steel.metallic = 0.9
	steel.roughness = 0.2
	blade.material_override = steel
	blade.position = Vector3(0, 0, -0.14)
	_knife.add_child(blade)
	_box(_knife, Vector3(0, 0, 0), Vector3(0.03, 0.035, 0.09), _glove)
	_box(_knife, Vector3(0.0, -0.02, 0.06), Vector3(0.07, 0.07, 0.12), _glove)
	_box(_knife, Vector3(0.0, -0.03, 0.2), Vector3(0.08, 0.08, 0.22), _sleeve)
	_knife.visible = false

	_bottle_mat = StandardMaterial3D.new()
	_bottle_mat.emission_enabled = true
	_bottle_mat.emission_energy_multiplier = 1.2
	_bottle = MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = 0.022
	cm.bottom_radius = 0.035
	cm.height = 0.17
	_bottle.mesh = cm
	_bottle.material_override = _bottle_mat
	add_child(_bottle)
	_bottle.visible = false


func _box(parent: Node3D, pos: Vector3, size: Vector3, mat: Material) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mi)
	mi.position = pos
	return mi


func _build(w: Dictionary) -> void:
	if _gun:
		_gun.queue_free()
		_gun = null
	if _flash.get_parent():
		_flash.get_parent().remove_child(_flash)
	if w.is_empty():
		return
	var sh := GunShapes.shape(w.id)
	_kind = sh.kind
	_gun = GunShapes.build_model(w.id, G.gun_mats_for(w.up))
	_gun_holder.add_child(_gun)
	_muzzle = _gun.get_meta("muzzle")
	_gun.add_child(_flash)
	_flash.position = _muzzle + Vector3(0, 0, -0.06)
	# Right hand on the grip, forearm going down and back; left hand forward on the gun
	# (or under the right hand for pistols).
	var right := Node3D.new()
	_gun.add_child(right)
	_box(right, Vector3(0.0, -0.03, 0.02), Vector3(0.07, 0.085, 0.09), _glove)
	var r_arm := _box(right, Vector3(0.03, -0.12, 0.13), Vector3(0.075, 0.075, 0.24), _skin)
	r_arm.rotation.x = 0.6
	var r_sleeve := _box(right, Vector3(0.05, -0.22, 0.27), Vector3(0.095, 0.095, 0.22), _sleeve)
	r_sleeve.rotation.x = 0.6
	var length: float = _gun.get_meta("length")
	if _kind in ["pistol", "revolver"]:
		_box(right, Vector3(-0.045, -0.05, 0.03), Vector3(0.06, 0.07, 0.08), _glove)
	else:
		var left := Node3D.new()
		_gun.add_child(left)
		left.position = Vector3(-0.02, -0.035, -min(0.42, length * 0.45))
		left.rotation = Vector3(0, -0.3, 0.3)
		_box(left, Vector3(0, 0, 0), Vector3(0.07, 0.075, 0.09), _glove)
		var l_arm := _box(left, Vector3(-0.05, -0.08, 0.14), Vector3(0.075, 0.075, 0.24), _skin)
		l_arm.rotation.x = 0.5
		var l_sleeve := _box(left, Vector3(-0.08, -0.16, 0.3), Vector3(0.095, 0.095, 0.22), _sleeve)
		l_sleeve.rotation.x = 0.5


func set_weapon(w: Dictionary, animate := true) -> void:
	if not animate or _gun == null:
		_build(w)
		_anim = ""
		return
	_pending_weapon = w
	_pending_set = true
	play_anim("swap", 0.5)


func play_anim(name: String, length: float) -> void:
	_anim = name
	_anim_t = 0.0
	_anim_len = max(0.05, length)
	if name == "knife":
		_knife.visible = true
	if name == "drink":
		_bottle.visible = true


func set_bottle_color(c: Color) -> void:
	_bottle_mat.albedo_color = c
	_bottle_mat.emission = c


func shot(kick: float) -> void:
	_kick = min(_kick + 0.03 + kick * 0.01, 0.12)
	_kick_rot = min(_kick_rot + 0.04 + kick * 0.02, 0.35)
	_flash_t = 0.05
	_flash.rotation.z = randf() * TAU
	_flash.scale = Vector3.ONE * randf_range(0.8, 1.3)


func muzzle_global() -> Vector3:
	if _gun:
		return _gun.to_global(_muzzle)
	return global_position


func add_sway(look_delta: Vector2) -> void:
	_sway += look_delta * 0.002
	_sway = _sway.limit_length(0.08)


func hip_pos() -> Vector3:
	if _kind in ["pistol", "revolver"]:
		return Vector3(0.17, -0.2, -0.5)
	if _kind == "wonder":
		return Vector3(0.2, -0.25, -0.46)
	return Vector3(0.19, -0.23, -0.36)


func ads_pos() -> Vector3:
	if _kind in ["pistol", "revolver"]:
		return Vector3(0.0, -0.085, -0.42)
	if _kind == "sniper":
		return Vector3(0.0, -0.13, -0.24)
	if _kind == "wonder":
		return Vector3(0.0, -0.15, -0.4)
	if _kind in ["shotgun", "double"]:
		return Vector3(0.0, -0.095, -0.3)
	return Vector3(0.0, -0.1, -0.3)


func update_view(delta: float, speed: float, sprinting: bool, on_floor: bool) -> void:
	var base := hip_pos().lerp(ads_pos(), ads)
	var rot := Vector3.ZERO
	# Walk bob.
	if on_floor and speed > 0.5:
		_bob += delta * speed * (1.3 if sprinting else 1.9)
	var bob_amt := (0.012 if not sprinting else 0.03) * (1.0 - ads * 0.85) * clampf(speed / 4.0, 0.0, 1.5)
	base += Vector3(cos(_bob) * bob_amt, abs(sin(_bob)) * bob_amt, 0)
	if sprinting:
		base += Vector3(-0.05, -0.04, 0.05)
		rot += Vector3(-0.25, 0.6, 0.15)
	# Recoil.
	_kick = move_toward(_kick, 0.0, delta * 0.6)
	_kick_rot = move_toward(_kick_rot, 0.0, delta * 3.0)
	base.z += _kick
	rot.x += _kick_rot
	# Sway follows the look motion and settles back.
	_sway = _sway.lerp(Vector2.ZERO, clamp(delta * 8.0, 0.0, 1.0))
	rot.y += _sway.x * (1.0 - ads * 0.8)
	rot.x += _sway.y * (1.0 - ads * 0.8)
	# One-shot animations.
	if _anim != "":
		_anim_t += delta
		var p: float = clamp(_anim_t / _anim_len, 0.0, 1.0)
		var dip := sin(p * PI)
		match _anim:
			"reload":
				base += Vector3(-0.03, -0.12, 0.04) * dip
				rot += Vector3(-0.45, 0.25, 0.6) * dip
			"swap":
				base += Vector3(0, -0.45, 0.1) * dip
				rot += Vector3(-0.6, 0, 0) * dip
				if p >= 0.5 and _pending_set:
					_build(_pending_weapon)
					_pending_set = false
			"knife":
				base += Vector3(-0.05, -0.25, 0.05) * dip
				_knife.position = Vector3(0.1 - 0.25 * p, -0.15 + 0.05 * dip, -0.35 - 0.15 * dip)
				_knife.rotation = Vector3(-0.2, 0.9 - 1.6 * p, -0.4)
			"drink":
				base += Vector3(0, -0.5, 0.1) * min(1.0, dip * 2.0)
				var lift: float = clamp(p * 3.0, 0.0, 1.0) * clamp((1.0 - p) * 4.0, 0.0, 1.0)
				_bottle.position = Vector3(0.02, -0.35 + 0.25 * lift, -0.25)
				_bottle.rotation = Vector3(0.3 + 1.2 * lift, 0, 0)
		if p >= 1.0:
			if _anim == "knife":
				_knife.visible = false
			if _anim == "drink":
				_bottle.visible = false
			if _anim == "swap" and _pending_set:
				_build(_pending_weapon)
				_pending_set = false
			_anim = ""
	_gun_holder.position = _gun_holder.position.lerp(base, clamp(delta * 18.0, 0.0, 1.0))
	_gun_holder.rotation = _gun_holder.rotation.lerp(rot, clamp(delta * 14.0, 0.0, 1.0))
	_gun_holder.visible = not hidden_by_scope
	# Muzzle flash.
	if _flash_t > 0.0:
		_flash_t -= delta
		_flash.visible = true
		_flash_light.visible = true
		_flash_light.global_position = muzzle_global()
	else:
		_flash.visible = false
		_flash_light.visible = false
