class_name PerkMachine
extends Interactable
## A vending machine selling one perk drink.

var perk_id := "cuirasse"
var price := 2500
var _glow: MeshInstance3D
var _t := 0.0


func build(pos: Vector3, facing: Vector3, p_perk: String, metal: Material, nav_parent: Node3D) -> void:
	perk_id = p_perk
	var info: Dictionary = G.PERKS[perk_id]
	price = info.price
	var col: Color = info.color
	global_position = pos + facing * 1.0 + Vector3(0, 1.0, 0)
	focus_point = pos + Vector3(0, 1.3, 0)
	setup_zone(Vector3(2.0, 2.0, 2.0))

	var body := StaticBody3D.new()
	body.collision_layer = G.L_WORLD
	body.collision_mask = 0
	nav_parent.add_child(body)
	body.global_position = pos
	body.look_at(pos - facing, Vector3.UP)
	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = Vector3(1.1, 2.2, 0.8)
	cs.shape = bs
	cs.position.y = 1.1
	body.add_child(cs)

	var tinted := StandardMaterial3D.new()
	tinted.albedo_color = col.darkened(0.35)
	tinted.albedo_texture = (metal as StandardMaterial3D).albedo_texture
	tinted.uv1_triplanar = true
	tinted.uv1_scale = Vector3(1.5, 1.5, 1.5)
	tinted.roughness = 0.5
	tinted.metallic = 0.4
	_add_box(body, Vector3(0, 1.1, 0), Vector3(1.1, 2.2, 0.8), tinted)
	_add_box(body, Vector3(0, 2.28, 0), Vector3(1.2, 0.16, 0.9), metal)

	var glow_mat := StandardMaterial3D.new()
	glow_mat.albedo_color = col
	glow_mat.emission_enabled = true
	glow_mat.emission = col
	glow_mat.emission_energy_multiplier = 2.2
	_glow = _add_box(body, Vector3(0, 1.45, 0.41), Vector3(0.85, 0.75, 0.02), glow_mat)
	var dark := StandardMaterial3D.new()
	dark.albedo_color = Color(0.05, 0.05, 0.05)
	_add_box(body, Vector3(0, 0.55, 0.41), Vector3(0.6, 0.3, 0.03), dark)
	# Bottles on display.
	var bottle_mat := StandardMaterial3D.new()
	bottle_mat.albedo_color = col.lightened(0.2)
	bottle_mat.emission_enabled = true
	bottle_mat.emission = col
	bottle_mat.emission_energy_multiplier = 0.8
	for i in 3:
		var b := MeshInstance3D.new()
		var cm := CylinderMesh.new()
		cm.top_radius = 0.035
		cm.bottom_radius = 0.05
		cm.height = 0.22
		b.mesh = cm
		b.material_override = bottle_mat
		body.add_child(b)
		b.position = Vector3(-0.25 + i * 0.25, 0.95, 0.43)

	var title := Label3D.new()
	title.text = info.name.to_upper()
	title.font_size = 56
	title.pixel_size = 0.0035
	title.outline_size = 10
	title.modulate = Color(1, 1, 1)
	title.outline_modulate = col.darkened(0.6)
	body.add_child(title)
	title.position = Vector3(0, 1.95, 0.43)
	var price_label := Label3D.new()
	price_label.text = "%d" % price
	price_label.font_size = 44
	price_label.pixel_size = 0.0035
	price_label.modulate = Color(1, 0.85, 0.3)
	price_label.outline_size = 8
	price_label.outline_modulate = Color(0, 0, 0)
	body.add_child(price_label)
	price_label.position = Vector3(0, 1.45, 0.44)



func _add_box(parent: Node3D, pos: Vector3, size: Vector3, mat: Material) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	mi.material_override = mat
	parent.add_child(mi)
	mi.position = pos
	return mi


func _process(delta: float) -> void:
	_t += delta
	if _glow:
		var m := _glow.material_override as StandardMaterial3D
		if G.power_on:
			m.emission_energy_multiplier = 1.8 + 0.6 * sin(_t * 3.0) + (0.8 if randf() < 0.01 else 0.0)
		else:
			m.emission_energy_multiplier = 0.05


func get_hint(player: Node) -> String:
	var info: Dictionary = G.PERKS[perk_id]
	if not G.power_on:
		return "%s : pas de courant" % info.name
	if player.has_perk(perk_id):
		return "%s : déjà bu" % info.name
	if perk_id == "second_souffle" and player.second_souffle_bought >= 3:
		return "%s : épuisé" % info.name
	return "%s boire %s (%s) %s" % [use_text(), info.name, info.desc, price_text(price)]


func interact(player: Node) -> void:
	if not G.power_on:
		return
	if player.has_perk(perk_id) or not player.can_drink():
		return
	if perk_id == "second_souffle" and player.second_souffle_bought >= 3:
		return
	if G.spend(price):
		player.drink_perk(perk_id)
