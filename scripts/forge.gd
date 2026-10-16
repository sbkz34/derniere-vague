class_name Forge
extends Interactable
## The upgrade machine: hand over your weapon, it comes back stronger (new name, more damage,
## bigger magazine, glowing parts).

enum State { IDLE, WORKING, READY }

var state := State.IDLE
var _weapon := ""
var _tier := 1
var _timer := 0.0
var _display: Node3D
var _label: Label3D
var _core: MeshInstance3D
var _mats: Dictionary
var _light: OmniLight3D
var _t := 0.0


func build(pos: Vector3, facing: Vector3, metal: Material, mats: Dictionary, nav_parent: Node3D) -> void:
	_mats = mats
	global_position = pos + facing * 1.3 + Vector3(0, 1.0, 0)
	focus_point = pos + Vector3(0, 1.2, 0)
	setup_zone(Vector3(2.6, 2.0, 2.0) if abs(facing.z) > 0.5 else Vector3(2.0, 2.0, 2.6))
	var body := StaticBody3D.new()
	body.collision_layer = G.L_WORLD
	body.collision_mask = 0
	nav_parent.add_child(body)
	body.global_position = pos
	body.look_at(pos - facing, Vector3.UP)
	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = Vector3(2.0, 2.4, 1.2)
	cs.shape = bs
	cs.position.y = 1.2
	body.add_child(cs)
	var dark := StandardMaterial3D.new()
	dark.albedo_color = Color(0.08, 0.06, 0.1)
	dark.roughness = 0.6
	_box(body, Vector3(0, 0.45, 0), Vector3(2.0, 0.9, 1.2), metal)
	_box(body, Vector3(-0.8, 1.6, 0), Vector3(0.4, 1.6, 1.2), metal)
	_box(body, Vector3(0.8, 1.6, 0), Vector3(0.4, 1.6, 1.2), metal)
	_box(body, Vector3(0, 2.3, 0), Vector3(2.0, 0.25, 1.2), metal)
	_box(body, Vector3(0, 1.6, -0.45), Vector3(1.2, 1.4, 0.3), dark)
	var glow := StandardMaterial3D.new()
	glow.albedo_color = Color(0.7, 0.3, 1.0)
	glow.emission_enabled = true
	glow.emission = Color(0.65, 0.25, 1.0)
	glow.emission_energy_multiplier = 2.0
	_core = _box(body, Vector3(0, 0.93, 0.0), Vector3(1.1, 0.06, 0.8), glow)
	for x in [-0.6, 0.6]:
		_box(body, Vector3(x, 1.6, 0.61), Vector3(0.06, 1.3, 0.02), glow)
	var title := Label3D.new()
	title.text = "LA FORGE"
	title.font_size = 64
	title.pixel_size = 0.004
	title.modulate = Color(0.85, 0.6, 1.0)
	title.outline_size = 10
	title.outline_modulate = Color(0.1, 0, 0.2)
	body.add_child(title)
	title.position = Vector3(0, 2.3, 0.62)
	var price_label := Label3D.new()
	price_label.text = "Amélioration %d / %d / %d" % G.UPGRADE_PRICES
	price_label.font_size = 36
	price_label.pixel_size = 0.004
	price_label.modulate = Color(1, 0.85, 0.3)
	price_label.outline_size = 8
	price_label.outline_modulate = Color(0, 0, 0)
	body.add_child(price_label)
	price_label.position = Vector3(0, 0.55, 0.61)
	_display = Node3D.new()
	body.add_child(_display)
	_display.position = Vector3(0, 1.3, 0.1)
	_label = Label3D.new()
	_label.font_size = 36
	_label.pixel_size = 0.004
	_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_label.modulate = Color(0.85, 0.6, 1.0)
	_label.outline_size = 8
	_label.outline_modulate = Color(0, 0, 0)
	body.add_child(_label)
	_label.position = Vector3(0, 1.85, 0.3)
	_light = OmniLight3D.new()
	_light.light_color = Color(0.65, 0.3, 1.0)
	_light.light_energy = 0.8
	_light.omni_range = 4.0
	body.add_child(_light)
	_light.position = Vector3(0, 1.4, 1.0)


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
	if not G.power_on:
		return "Forge : pas de courant"
	match state:
		State.IDLE:
			var w: Dictionary = player.current_weapon()
			if w.is_empty():
				return ""
			var tier := int(w.up)
			if tier >= G.MAX_TIER:
				return "Arme au niveau maximum"
			return "%s améliorer l'arme (niveau %s) %s" % [use_text(), G.TIER_NAMES[tier + 1], price_text(G.UPGRADE_PRICES[tier])]
		State.READY:
			return "%s récupérer : %s" % [use_text(), G.weapon_name({"id": _weapon, "up": _tier})]
	return "La forge travaille…"


func interact(player: Node) -> void:
	if not G.power_on:
		return
	match state:
		State.IDLE:
			var w: Dictionary = player.current_weapon()
			if w.is_empty() or int(w.up) >= G.MAX_TIER or not player.can_drink():
				return
			if not G.spend(G.UPGRADE_PRICES[int(w.up)]):
				return
			_weapon = w.id
			_tier = int(w.up) + 1
			G.stat_add("upgrades")
			if _tier >= G.MAX_TIER:
				G.stat_add("ultimes")
			player.remove_current_weapon()
			state = State.WORKING
			_timer = 3.2
			G.play_at("forge", global_position, get_parent())
			_show(_weapon, _tier - 1)
			_label.text = ""
			_light.light_energy = 2.0
		State.READY:
			player.give_weapon(_weapon, _tier)
			state = State.IDLE
			_clear()
			_label.text = ""
			_light.light_energy = 0.8


func _clear() -> void:
	for c in _display.get_children():
		c.queue_free()


func _show(id: String, tier: int) -> void:
	_clear()
	var m := GunShapes.build_model(id, G.gun_mats_for(tier), 1.0)
	_display.add_child(m)
	m.rotation.y = PI / 2
	var sh := GunShapes.shape(id)
	m.position = Vector3(sh.muzzle.x * 0.5 - sh.grip.x, 0, 0)


func _process(delta: float) -> void:
	_t += delta
	var m: StandardMaterial3D = null
	if _core:
		m = _core.material_override as StandardMaterial3D
	match state:
		State.WORKING:
			_timer -= delta
			_display.rotation.y += delta * 6.0
			if m:
				m.emission_energy_multiplier = 2.0 + 2.0 * abs(sin(_t * 12.0))
			if _timer <= 0.0:
				state = State.READY
				_timer = 15.0
				_display.rotation.y = 0.0
				_show(_weapon, _tier)
				_label.text = G.weapon_name({"id": _weapon, "up": _tier})
				_label.modulate = G.tier_color(_tier)
		State.READY:
			_timer -= delta
			_display.position.y = 1.3 + sin(_t * 2.0) * 0.05
			if _timer <= 0.0:
				state = State.IDLE
				_clear()
				_label.text = ""
				_light.light_energy = 0.8
		_:
			if m:
				m.emission_energy_multiplier = (1.6 + 0.4 * sin(_t * 2.0)) if G.power_on else 0.05
			_light.light_energy = 0.8 if G.power_on else 0.0
