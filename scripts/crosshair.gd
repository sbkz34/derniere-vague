class_name Crosshair
extends Control
## Dynamic crosshair (opens with spread), hit markers and the sniper scope.

var player: Player
var _hit_t := 0.0
var _hit_kill := false
var _hit_head := false


const HIT_TIME := 0.3


func hitmarker(kill: bool, head: bool) -> void:
	_hit_t = HIT_TIME
	_hit_kill = kill
	_hit_head = head


func _process(delta: float) -> void:
	if _hit_t > 0.0:
		_hit_t -= delta


func _draw() -> void:
	if player == null:
		return
	var c := size / 2
	var w := player.current_weapon()
	var ads := player.view.ads
	var sniper: bool = not w.is_empty() and G.WEAPONS[w.id].kind == "sniper"
	if sniper and ads > 0.85:
		var r := minf(size.x, size.y) * 0.42
		var black := Color(0, 0, 0, 1)
		draw_rect(Rect2(0, 0, c.x - r, size.y), black)
		draw_rect(Rect2(c.x + r, 0, size.x - c.x - r, size.y), black)
		draw_rect(Rect2(c.x - r, 0, 2 * r, c.y - r), black)
		draw_rect(Rect2(c.x - r, c.y + r, 2 * r, size.y - c.y - r), black)
		# Fill the corners between the square and the circle.
		var pts := PackedVector2Array()
		var steps := 48
		for i in steps + 1:
			var a := TAU * i / steps
			pts.append(c + Vector2(cos(a), sin(a)) * r)
		for i in steps:
			var a0 := pts[i]
			var a1 := pts[i + 1]
			var mid := (a0 + a1) / 2
			var corner := c + (mid - c).normalized() * r * 1.5
			draw_colored_polygon(PackedVector2Array([a0, a1, corner]), black)
		draw_arc(c, r, 0, TAU, 64, Color(0, 0, 0), 6.0)
		draw_line(c - Vector2(r, 0), c + Vector2(r, 0), Color(0, 0, 0, 0.9), 2.0)
		draw_line(c - Vector2(0, r), c + Vector2(0, r), Color(0, 0, 0, 0.9), 2.0)
		draw_circle(c, 2.5, Color(1, 0.2, 0.2))
	elif not w.is_empty() and not player.downed:
		var spread: float = lerpf(float(G.stat(w, "spread")), float(G.stat(w, "ads_spread")), ads)
		var moving := Vector2(player.velocity.x, player.velocity.z).length() > 1.0
		if moving:
			spread *= 1.4
		var cam := player.cam
		var px := tan(deg_to_rad(spread)) / tan(deg_to_rad(cam.fov / 2.0)) * size.y / 2.0
		var gap := maxf(6.0, px)
		var col := Color(1, 1, 1, 0.85 * (1.0 - ads * 0.85))
		var arm := 11.0
		for d in [Vector2.RIGHT, Vector2.LEFT, Vector2.UP, Vector2.DOWN]:
			draw_line(c + d * gap, c + d * (gap + arm), Color(0, 0, 0, col.a * 0.6), 4.0)
			draw_line(c + d * gap, c + d * (gap + arm), col, 2.0)
		if ads > 0.5:
			draw_circle(c, 2.0, Color(1, 1, 1, 0.8))
	if _hit_t > 0.0:
		# Hit marker: an X that pops out then fades. White = hit, yellow = head, red = kill.
		var k := clampf(_hit_t / HIT_TIME, 0.0, 1.0)
		var a := clampf(k * 1.6, 0.0, 1.0)
		var pop := 1.0 + 0.35 * maxf(0.0, (k - 0.7) / 0.3)
		var hc := Color(1, 1, 1, a)
		if _hit_head:
			hc = Color(1, 0.85, 0.2, a)
		if _hit_kill:
			hc = Color(1, 0.18, 0.12, a)
		var inner := 9.0 * pop
		var outer := (24.0 if _hit_kill else 20.0) * pop
		for d in [Vector2(1, 1), Vector2(-1, 1), Vector2(1, -1), Vector2(-1, -1)]:
			var dn: Vector2 = d.normalized()
			draw_line(c + dn * inner, c + dn * outer, Color(0, 0, 0, a * 0.7), 6.0)
			draw_line(c + dn * inner, c + dn * outer, hc, 3.5)
