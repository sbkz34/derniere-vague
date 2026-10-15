class_name WallBuy
extends Interactable
## A chalk drawing of a weapon on a wall: buy the weapon, or ammo for it once you own it.

var weapon_id := "k14"
var price := 500


func build(pos: Vector3, inward: Vector3, p_weapon: String, chalk: Material, board: Material) -> void:
	weapon_id = p_weapon
	price = G.WEAPONS[weapon_id].price
	global_position = pos + inward * 0.9
	focus_point = pos
	var on_x := absf(inward.z) > 0.5
	setup_zone(Vector3(1.8, 2.0, 1.6) if on_x else Vector3(1.6, 2.0, 1.8))

	var holder := Node3D.new()
	add_child(holder)
	holder.global_position = pos + inward * 0.02
	holder.look_at(holder.global_position - inward, Vector3.UP)
	# look_at points -Z at the wall, so the drawing (which faces +Z) faces the room.
	var bd := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(1.5, 0.75, 0.02)
	bd.mesh = bm
	bd.material_override = board
	holder.add_child(bd)
	var drawing := GunShapes.build_drawing(weapon_id, chalk, 1.15 if GunShapes.shape(weapon_id).muzzle.x > 0.5 else 2.2)
	holder.add_child(drawing)
	drawing.position = Vector3(0, 0.02, 0.02)
	var name_label := Label3D.new()
	name_label.text = G.WEAPONS[weapon_id].name
	name_label.font_size = 40
	name_label.pixel_size = 0.004
	name_label.modulate = Color(0.95, 0.95, 0.9)
	name_label.outline_size = 8
	name_label.outline_modulate = Color(0, 0, 0, 0.8)
	holder.add_child(name_label)
	name_label.position = Vector3(0, 0.5, 0.03)
	var price_label := Label3D.new()
	price_label.text = "%d" % price
	price_label.font_size = 44
	price_label.pixel_size = 0.004
	price_label.modulate = Color(1, 0.85, 0.3)
	price_label.outline_size = 8
	price_label.outline_modulate = Color(0, 0, 0, 0.8)
	holder.add_child(price_label)
	price_label.position = Vector3(0, -0.5, 0.03)


func ammo_price(player: Node) -> int:
	var w: Dictionary = player.get_weapon(weapon_id)
	if w.is_empty():
		return price
	return 1500 + 1000 * int(w.up) if int(w.up) > 0 else max(250, price / 2)


func get_hint(player: Node) -> String:
	var name: String = G.WEAPONS[weapon_id].name
	if player.has_weapon(weapon_id):
		if player.ammo_full(weapon_id):
			return "Munitions pleines"
		return "%s acheter des munitions %s" % [use_text(), price_text(ammo_price(player))]
	return "%s acheter : %s %s" % [use_text(), name, price_text(price)]


func interact(player: Node) -> void:
	if player.has_weapon(weapon_id):
		if player.ammo_full(weapon_id):
			return
		if G.spend(ammo_price(player)):
			player.refill_ammo(weapon_id)
	elif G.spend(price):
		player.give_weapon(weapon_id, 0)
