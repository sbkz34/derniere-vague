class_name LobbyVisuals
extends RefCounted
## Visuals for the lobby: 3D renders of the weapons (icons and a turning preview), a live view
## of the map and a drawn plan of it.


## A small isolated 3D scene (own world) with a light, for rendering a weapon model.
static func _stage(size: Vector2i, bg: Color, transparent: bool) -> SubViewport:
	var sv := SubViewport.new()
	sv.size = size
	sv.own_world_3d = true
	sv.transparent_bg = transparent
	sv.msaa_3d = Viewport.MSAA_2X
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = bg
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.7, 0.68, 0.66)
	env.ambient_light_energy = 0.9
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.glow_enabled = true
	env.glow_intensity = 0.5
	var we := WorldEnvironment.new()
	we.environment = env
	sv.add_child(we)
	var key := DirectionalLight3D.new()
	key.light_energy = 1.3
	key.light_color = Color(1.0, 0.92, 0.85)
	key.rotation_degrees = Vector3(-35, 60, 0)
	sv.add_child(key)
	var rim := DirectionalLight3D.new()
	rim.light_energy = 0.8
	rim.light_color = Color(1.0, 0.35, 0.25)
	rim.rotation_degrees = Vector3(-20, -120, 0)
	sv.add_child(rim)
	return sv


## Builds the gun centred on the origin, seen from its right side by a camera on +X.
static func _gun_on_stage(sv: SubViewport, weapon_id: String, tier: int, fill: float, camo := "") -> Node3D:
	var pivot := Node3D.new()
	sv.add_child(pivot)
	var model := GunShapes.build_model(weapon_id, G.gun_mats_for(tier, camo))
	var sh := GunShapes.shape(weapon_id)
	var length: float = sh.muzzle.x
	model.position = Vector3(0, -0.02, length / 2.0 - sh.grip.x)
	pivot.add_child(model)
	var cam := Camera3D.new()
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	# Fit the length of the gun (horizontal) in the viewport, with a margin.
	var aspect := float(sv.size.x) / float(sv.size.y)
	# Short guns are not blown up: at least 0.26 m of height in view.
	cam.size = maxf(length * fill / aspect, 0.26)
	cam.position = Vector3(2.0, 0.0, 0.0)
	cam.rotation_degrees = Vector3(0, 90, 0)
	cam.current = true
	sv.add_child(cam)
	return pivot


## A still render of the weapon (transparent background) for a button icon. The render's
## viewport is parented to `holder` so it stays alive as long as the button.
static func weapon_icon(holder: Node, weapon_id: String, size: Vector2i) -> Texture2D:
	var sv := _stage(size, Color(0, 0, 0, 0), true)
	_gun_on_stage(sv, weapon_id, 0, 1.15)
	sv.render_target_update_mode = SubViewport.UPDATE_ONCE
	holder.add_child(sv)
	return sv.get_texture()


## Short name for a card: the last word ("Mitraillette Vipère" -> "Vipère").
static func short_name(weapon_id: String) -> String:
	var parts: PackedStringArray = String(G.WEAPONS[weapon_id].name).split(" ")
	return parts[parts.size() - 1]


## 0..1 ratings of a weapon against the others, for the lobby's stat bars.
static func ratings(weapon_id: String) -> Dictionary:
	var best := {"dmg": 0.0, "rate": 0.0, "acc": 0.0, "mag": 0.0, "mob": 0.0}
	var mine := {}
	for id in G.WEAPONS:
		var w: Dictionary = G.WEAPONS[id]
		if w.kind == "wonder":
			continue
		var r := {"dmg": float(w.dmg) * float(w.pellets), "rate": 1.0 / float(w.rof),
			"acc": 1.0 / (float(w.spread) + float(w.ads_spread) + 0.5), "mag": float(w.mag),
			"mob": float(w.speed)}
		for k in r:
			best[k] = maxf(best[k], r[k])
		if id == weapon_id:
			mine = r
	var out := {}
	for k in best:
		out[k] = clampf(sqrt(mine.get(k, 0.0) / maxf(best[k], 0.001)), 0.05, 1.0)
	out["mob"] = clampf((mine.get("mob", 1.0) - 0.75) / 0.35, 0.05, 1.0)
	return out


## Large turning preview of the selected weapon.
class WeaponPreview:
	extends SubViewportContainer

	var _sv: SubViewport
	var _pivot: Node3D
	var _t := 0.0
	var _id := ""

	func _init(view_size: Vector2i) -> void:
		stretch = true
		custom_minimum_size = Vector2(view_size)
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		_sv = LobbyVisuals._stage(view_size * 2, Color(0.035, 0.02, 0.02), false)
		add_child(_sv)

	## `camo`: "*" = the camouflage chosen for that weapon.
	func show_weapon(weapon_id: String, camo := "*") -> void:
		if camo == "*":
			camo = G.camo_for(weapon_id)
		if weapon_id + "/" + camo == _id:
			return
		_id = weapon_id + "/" + camo
		for c in _sv.get_children():
			if c is Camera3D or (c is Node3D and not c is DirectionalLight3D and not c is WorldEnvironment):
				c.queue_free()
		_pivot = LobbyVisuals._gun_on_stage(_sv, weapon_id, 0, 1.45, camo)
		_t = 0.0

	func _process(delta: float) -> void:
		if not is_visible_in_tree() or _pivot == null:
			return
		_t += delta
		_pivot.rotation.y = sin(_t * 0.7) * 0.45
		_pivot.rotation.x = sin(_t * 0.5) * 0.08


## Live view of the map: the level's own world seen from a camera that tours a few spots.
class MapPreview:
	extends SubViewportContainer

	const SPOTS := [
		[Vector3(1.5, 1.8, 4.5), Vector3(-2.5, 1.3, -7.0)],
		[Vector3(10.5, 1.9, 4.0), Vector3(16.5, 0.9, -5.5)],
		[Vector3(11.0, 1.9, 15.5), Vector3(18.2, 1.3, 10.0)],
		[Vector3(1.0, 1.9, 9.5), Vector3(4.6, 1.3, 20.4)],
	]
	var _sv: SubViewport
	var _cam: Camera3D
	var _t := 0.0

	func _init(view_size: Vector2i) -> void:
		stretch = true
		custom_minimum_size = Vector2(view_size)
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		_sv = SubViewport.new()
		_sv.size = view_size
		_sv.own_world_3d = false
		_sv.render_target_update_mode = SubViewport.UPDATE_WHEN_VISIBLE
		add_child(_sv)
		_cam = Camera3D.new()
		_cam.fov = 70
		_sv.add_child(_cam)

	func _ready() -> void:
		# Share the main viewport's world: the map that is already built behind the menu.
		_sv.world_3d = get_tree().root.world_3d
		_cam.current = true

	func _process(delta: float) -> void:
		if not is_visible_in_tree():
			return
		_t += delta
		var seg := 5.0
		var i := int(_t / seg) % SPOTS.size()
		var p := fmod(_t, seg) / seg
		var spot: Array = SPOTS[i]
		var from: Vector3 = spot[0]
		var look: Vector3 = spot[1]
		var side := (look - from).cross(Vector3.UP).normalized()
		_cam.global_position = from + side * (p - 0.5) * 1.6
		_cam.look_at(look)


## Plan of the map drawn from the level itself: rooms, doors with prices, windows, perks, box
## and forge.
class MapPlan:
	extends Control

	var level: Node

	func _init(min_size: Vector2) -> void:
		custom_minimum_size = min_size
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		draw_rect(Rect2(Vector2.ZERO, size), Color(0.05, 0.07, 0.09, 0.95))
		if level == null:
			return
		var lo := Vector2(INF, INF)
		var hi := Vector2(-INF, -INF)
		for id in Level.ROOMS:
			lo = lo.min(Level.ROOMS[id].min)
			hi = hi.max(Level.ROOMS[id].max)
		var pad := 18.0
		var k := minf((size.x - pad * 2) / (hi.x - lo.x), (size.y - pad * 2) / (hi.y - lo.y))
		var origin := (size - (hi - lo) * k) / 2.0
		var to_px := func(p: Vector2) -> Vector2: return origin + (p - lo) * k
		var font := ThemeDB.fallback_font
		var line := Color(0.55, 0.75, 0.95, 0.9)
		for id in Level.ROOMS:
			var r: Dictionary = Level.ROOMS[id]
			var a: Vector2 = to_px.call(r.min)
			var b: Vector2 = to_px.call(r.max)
			draw_rect(Rect2(a, b - a), Color(0.12, 0.18, 0.24, 0.9))
			draw_rect(Rect2(a, b - a), line, false, 2.0)
			var name: String = r.name
			var fs := 13
			var w := font.get_string_size(name, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
			draw_string(font, Vector2((a.x + b.x) / 2 - w / 2, (a.y + b.y) / 2 - 8), name, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(0.85, 0.92, 1.0))
		for win in level.windows:
			var c: Vector2 = to_px.call(Vector2(win.center.x, win.center.z))
			var al := Vector2(win.along.x, win.along.z) * k
			draw_line(c - al, c + al, Color(0.75, 0.5, 0.25), 5.0)
		for door in level.doors:
			var dp: Vector3 = door.focus_point
			var c2: Vector2 = to_px.call(Vector2(dp.x, dp.z))
			draw_circle(c2, 5.0, Color(1, 0.8, 0.3))
			var t := "%d" % door.price
			var tw := font.get_string_size(t, HORIZONTAL_ALIGNMENT_LEFT, -1, 11).x
			draw_string(font, c2 + Vector2(-tw / 2, 17), t, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(1, 0.85, 0.4))
		for n in level.get_children():
			var col := Color.TRANSPARENT
			var label := ""
			if n is PerkMachine:
				col = G.PERKS[n.perk_id].color
			elif n is MysteryBox:
				col = Color(0.4, 0.9, 1.0)
				label = "?"
			elif n is Forge:
				col = Color(0.75, 0.4, 1.0)
				label = "F"
			elif n is WallBuy:
				col = Color(0.9, 0.9, 0.85)
			if col.a == 0.0:
				continue
			var fp: Vector3 = n.focus_point
			var c3: Vector2 = to_px.call(Vector2(fp.x, fp.z))
			if n is WallBuy:
				draw_rect(Rect2(c3 - Vector2(4, 4), Vector2(8, 8)), col)
			else:
				draw_circle(c3, 7.0, col)
			if label != "":
				draw_string(font, c3 + Vector2(-4, 5), label, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color(0, 0, 0))
		# Start position.
		var sp: Vector2 = to_px.call(Vector2(level.player_start.x, level.player_start.z))
		draw_colored_polygon(PackedVector2Array([sp + Vector2(0, -8), sp + Vector2(6, 6), sp + Vector2(-6, 6)]), Color(0.3, 1.0, 0.4))
