class_name Director
extends Node
## Runs the rounds: how many zombies, how tough and fast, where they come from, the pause
## between rounds and the bonuses they drop.

signal round_started(n: int)
signal round_ended(n: int)
signal powerup_activated(kind: String)

const MAX_ALIVE := 24
const DROP_CHANCE := 0.03
const MAX_DROPS_PER_ROUND := 4

var level: Level
var player: Player
var zombie_parent: Node3D

var to_spawn := 0
var alive := 0
var in_round := false
var intermission := 0.0
var repair_points_left := 500
var _spawn_t := 0.0
var _drops := 0
var _kills_since_drop := 0


func start() -> void:
	G.round_num = 0
	intermission = 3.0
	in_round = false


func _process(delta: float) -> void:
	if not G.playing or player == null or player.dead:
		return
	if not in_round:
		intermission -= delta
		if intermission <= 0.0:
			_begin_round()
		return
	if to_spawn > 0 and alive < MAX_ALIVE:
		_spawn_t -= delta
		if _spawn_t <= 0.0:
			_spawn_t = G.spawn_delay(G.round_num) * randf_range(0.7, 1.3)
			_spawn_one()
	if to_spawn <= 0 and alive <= 0:
		_end_round()


func _begin_round() -> void:
	G.round_num += 1
	to_spawn = G.zombie_count(G.round_num)
	in_round = true
	_spawn_t = 1.5
	_drops = 0
	repair_points_left = 500
	G.play("round_start", -2.0)
	round_started.emit(G.round_num)


func _end_round() -> void:
	in_round = false
	intermission = 10.0
	G.play("round_end", -2.0)
	round_ended.emit(G.round_num)


func _kind_for_round(r: int) -> String:
	var x := randf()
	if r <= 2:
		return "walk"
	if r == 3:
		return "jog" if x < 0.3 else "walk"
	if r <= 5:
		return "jog" if x < 0.65 else "walk"
	var run_share := clampf((r - 5) * 0.12, 0.0, 0.85)
	if x < run_share:
		return "run"
	return "jog" if x < run_share + 0.6 * (1.0 - run_share) else "walk"


func _pick_window() -> Barricade:
	var wins := level.active_windows()
	if wins.is_empty():
		return null
	# Prefer windows near the player (the three closest), with a little randomness.
	wins.sort_custom(func(a, b): return a.center.distance_to(player.global_position) < b.center.distance_to(player.global_position))
	var n := mini(3, wins.size())
	return wins[randi() % n]


func _waiting_at(w: Barricade) -> int:
	var n := 0
	for z in get_tree().get_nodes_in_group("zombies"):
		var zz := z as Zombie
		if zz and zz.window == w and zz.outside:
			n += 1
	return n


func _spawn_one() -> void:
	var w := _pick_window()
	if w == null:
		return
	var z := Zombie.new()
	z.setup(self, player, w, _waiting_at(w), G.zombie_health(G.round_num), _kind_for_round(G.round_num))
	zombie_parent.add_child(z)
	to_spawn -= 1
	alive += 1


## Sends a stuck zombie back outside a window (it keeps its health and does not count twice).
func respawn(z: Zombie) -> void:
	var hp := z.hp
	var kind := z.kind
	z.alive = false
	z.remove_from_group("zombies")
	z.queue_free()
	var w := _pick_window()
	if w == null:
		alive -= 1
		return
	var nz := Zombie.new()
	nz.setup(self, player, w, _waiting_at(w), hp, kind)
	zombie_parent.add_child(nz)


func on_zombie_killed(z: Zombie) -> void:
	alive -= 1
	_kills_since_drop += 1
	if _drops < MAX_DROPS_PER_ROUND and not z.outside and randf() < DROP_CHANCE + _kills_since_drop * 0.001:
		_drops += 1
		_kills_since_drop = 0
		_drop(z.global_position)


func _drop(pos: Vector3) -> void:
	var kinds := ["ammo", "double", "insta", "bomb", "carpenter", "ammo", "double", "insta"]
	var p := PowerUp.new()
	p.setup(kinds.pick_random())
	zombie_parent.add_child(p)
	p.global_position = Vector3(pos.x, 0.0, pos.z)
	p.taken.connect(_apply_powerup)
	G.play_at("powerup_spawn", pos + Vector3(0, 1, 0), zombie_parent, -2.0)


func _apply_powerup(kind: String, pos: Vector3) -> void:
	var name: String = G.POWERUPS[kind].name
	G.say(name.to_upper() + " !", G.POWERUPS[kind].color)
	match kind:
		"ammo":
			player.refill_all()
		"double":
			G.double_points_time = 30.0
		"insta":
			G.insta_kill_time = 30.0
		"bomb":
			G.play("bomb", 0.0)
			Fx.blast(zombie_parent, pos + Vector3(0, 1, 0), 6.0, Color(1, 0.6, 0.2))
			for z in get_tree().get_nodes_in_group("zombies"):
				var zz := z as Zombie
				if zz and zz.alive:
					zz.take_damage(zz.hp + 1.0, zz.global_position + Vector3(0, 1, 0), Vector3.UP, false, "bomb", "")
			# Kills by the bomb give no points; the bomb itself gives 400.
			G.add_points(400, false)
		"carpenter":
			for w in level.windows:
				w.repair_all()
			G.add_points(200, false)
	powerup_activated.emit(kind)
