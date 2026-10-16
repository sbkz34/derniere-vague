class_name DamageIndicator
extends Control
## Red arcs around the centre of the screen pointing to where each hit came from (front = top,
## behind = bottom). They follow the camera as the player turns, and fade out.

const LIFE := 1.4

var player: Player
var _hits: Array = []   # [world direction, time left]


func add_hit(world_dir: Vector3) -> void:
	world_dir.y = 0.0
	if world_dir.length() < 0.01:
		return
	_hits.append([world_dir.normalized(), LIFE])
	if _hits.size() > 6:
		_hits.pop_front()


func _process(delta: float) -> void:
	for h in _hits:
		h[1] -= delta
	_hits = _hits.filter(func(h): return h[1] > 0.0)
	queue_redraw()


func _draw() -> void:
	if player == null or _hits.is_empty():
		return
	var c := size / 2
	var r := minf(size.x, size.y) * 0.33
	var yaw := player._yaw
	var fwd := Vector3(-sin(yaw), 0, -cos(yaw))
	var right := Vector3(cos(yaw), 0, -sin(yaw))
	for h in _hits:
		var d: Vector3 = h[0]
		var a := atan2(d.dot(right), d.dot(fwd))   # 0 = straight ahead
		var screen := -PI / 2 + a
		var alpha := clampf(float(h[1]) / LIFE, 0.0, 1.0)
		draw_arc(c, r, screen - 0.32, screen + 0.32, 24, Color(0, 0, 0, 0.5 * alpha), 16.0, true)
		draw_arc(c, r, screen - 0.3, screen + 0.3, 24, Color(1.0, 0.12, 0.08, 0.85 * alpha), 11.0, true)
		# A small arrowhead on the outside of the arc.
		var tip := c + Vector2(cos(screen), sin(screen)) * (r + 20)
		var l := c + Vector2(cos(screen - 0.08), sin(screen - 0.08)) * (r + 6)
		var rr := c + Vector2(cos(screen + 0.08), sin(screen + 0.08)) * (r + 6)
		draw_colored_polygon(PackedVector2Array([tip, l, rr]), Color(1.0, 0.12, 0.08, 0.85 * alpha))
