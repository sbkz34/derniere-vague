class_name Interactable
extends Area3D
## Something the player can use when standing in its zone (a box in front of it).
## The player's reach area overlaps these; the one the camera faces most is shown and used.

var enabled := true
## Point the player should be looking towards (for picking between several zones).
var focus_point := Vector3.ZERO


func setup_zone(size: Vector3, offset := Vector3.ZERO) -> void:
	collision_layer = G.L_INTERACT
	collision_mask = 0
	monitoring = false
	monitorable = true
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	shape.shape = box
	shape.position = offset
	add_child(shape)


## Text shown at the bottom of the screen, or "" when there is nothing to do.
func get_hint(_player: Node) -> String:
	return ""


## Called once when the player presses the use button.
func interact(_player: Node) -> void:
	pass


## True for things used by holding the button (barricade repair).
func is_hold() -> bool:
	return false


## Called every frame while the button is held (only when is_hold()).
func hold(_player: Node, _delta: float) -> void:
	pass


func price_text(price: int) -> String:
	return "[%d]" % price


func use_text() -> String:
	if G.input_mode == "touch":
		return "Touchez ACTION pour"
	return "Appuyez sur %s pour" % G.button_name("use" if G.input_mode == "pad" else "interact")


func hold_text() -> String:
	if G.input_mode == "touch":
		return "Maintenez ACTION pour"
	return "Maintenez %s pour" % G.button_name("use" if G.input_mode == "pad" else "interact")
