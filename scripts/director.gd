class_name Director
extends Node
## Runs the rounds: how many zombies, how tough and fast, where they come from, the pause
## between rounds and the bonuses they drop.

signal round_started(n: int)
signal round_ended(n: int)
signal powerup_activated(kind: String)
signal dog_round_started(n: int)

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
## Special rounds with zombie dogs: the first on round 5 or 6, then every 4 to 6 rounds.
var dog_round := false
var next_dog_round := 0
var _last_kill_pos := Vector3.ZERO
var _dog_rounds_done := 0
## Every tenth round a Colosse joins in, some time after the round starts.
var _brute_pending := false
var _brute_t := 0.0


func start() -> void:
	G.round_num = 0
	intermission = 3.0
	in_round = false
	dog_round = false
	_brute_pending = false
	next_dog_round = randi_range(5, 6)


## Resumes a saved game: the next round to play is `round`.
func start_at(next_round: int, p_next_dog: int, p_dogs_done: int) -> void:
	G.round_num = maxi(0, next_round - 1)
	intermission = 5.0
	in_round = false
	dog_round = false
	_brute_pending = false
	next_dog_round = maxi(p_next_dog, next_round)
	if next_dog_round % 10 == 0:
		next_dog_round += 1
	_dog_rounds_done = p_dogs_done


func _process(delta: float) -> void:
	if not G.playing or player == null or player.dead:
		return
	if not in_round:
		intermission -= delta
		if intermission <= 0.0:
			_begin_round()
		return
	if _brute_pending:
		_brute_t -= delta
		# Comes when its time is up, or once it is the only one left to come.
		if _brute_t <= 0.0 or to_spawn <= 1:
			_spawn_brute()
	if to_spawn > (1 if _brute_pending else 0) and alive < (_max_dogs() if dog_round else MAX_ALIVE):
		_spawn_t -= delta
		if _spawn_t <= 0.0:
			if dog_round:
				_spawn_t = randf_range(2.0, 3.5)
				_spawn_dog()
			else:
				_spawn_t = G.spawn_delay(G.round_num) * randf_range(0.7, 1.3)
				_spawn_one()
	if to_spawn <= 0 and alive <= 0:
		_end_round()


func _begin_round() -> void:
	G.round_num += 1
	in_round = true
	_drops = 0
	repair_points_left = 500
	dog_round = G.round_num == next_dog_round
	if dog_round:
		next_dog_round = G.round_num + randi_range(4, 6)
		if next_dog_round % 10 == 0:
			next_dog_round += 1
		to_spawn = clampi(4 + G.round_num / 2, 6, 20)
		_spawn_t = 4.0
		level.set_storm(true)
		G.play("howl", 0.0)
		G.play("round_start", -4.0)
		G.say("MANCHE SPÉCIALE : LES MOLOSSES", Color(1.0, 0.45, 0.15))
		round_started.emit(G.round_num)
		dog_round_started.emit(G.round_num)
		return
	to_spawn = G.zombie_count(G.round_num)
	_spawn_t = 1.5
	if is_brute_round(G.round_num):
		_brute_pending = true
		_brute_t = randf_range(12.0, 22.0)
		to_spawn += 1
	G.play("round_start", -2.0)
	round_started.emit(G.round_num)


func _end_round() -> void:
	in_round = false
	intermission = 10.0
	if dog_round:
		# The last dog leaves a full ammo refill behind, and the storm clears.
		dog_round = false
		_dog_rounds_done += 1
		level.set_storm(false)
		_drop(_last_kill_pos, "ammo")
	G.play("round_end", -2.0)
	round_ended.emit(G.round_num)


func is_brute_round(r: int) -> bool:
	return r > 0 and r % 10 == 0


func brute_health(r: int) -> float:
	return maxf(5000.0, G.zombie_health(r) * 8.0)


func _spawn_brute() -> void:
	_brute_pending = false
	var pos := _dog_spot()
	var b := Brute.new()
	b.setup_brute(self, player, pos, brute_health(G.round_num))
	zombie_parent.add_child(b)
	Fx.blast(zombie_parent, pos + Vector3(0, 1.4, 0), 2.4, Color(1.0, 0.55, 0.2))
	G.play_at("thunder", pos + Vector3(0, 1, 0), zombie_parent, 0.0, 0.8)
	G.play("brute_roar", 0.0)
	G.say("LE COLOSSE EST LÀ", Color(1.0, 0.4, 0.15))
	player.shake(0.4)
	to_spawn -= 1
	alive += 1


## The Colosse always leaves a bonus behind.
func on_brute_killed(b: Brute) -> void:
	var kinds := ["ammo", "double", "insta", "carpenter"]
	_drop(b.global_position, kinds.pick_random())
	G.say("COLOSSE ABATTU", Color(1.0, 0.85, 0.4))


## Explosions can tear the legs off the zombies they do not kill.
func maybe_crawler(z: Zombie) -> void:
	if z is Dog or z is Brute or z.crawler or z.outside or not z.alive:
		return
	if randf() < 0.55:
		z.make_crawler()


## Dogs at the same time: 3 on the first dog round, one more each time, at most 6.
func _max_dogs() -> int:
	return mini(3 + _dog_rounds_done, 6)


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


## A spot on the navigation mesh in an open room, away from the player.
func _dog_spot() -> Vector3:
	var map := level.nav.get_navigation_map()
	var best := Vector3.ZERO
	var best_d := -1.0
	for i in 16:
		var p := NavigationServer3D.map_get_random_point(map, 1, true)
		if not level.unlocked.get(level.room_at(p), false):
			continue
		var d := p.distance_to(player.global_position)
		if d >= 7.0 and d <= 18.0:
			return p
		if d > best_d:
			best_d = d
			best = p
	return best


func _spawn_dog() -> void:
	var pos := _dog_spot()
	var d := Dog.new()
	d.setup_dog(self, player, pos, G.dog_health(G.round_num))
	zombie_parent.add_child(d)
	Fx.blast(zombie_parent, pos + Vector3(0, 1.0, 0), 1.6, Color(0.55, 0.75, 1.0))
	G.play_at("thunder", pos + Vector3(0, 1, 0), zombie_parent, -2.0, randf_range(0.9, 1.1))
	to_spawn -= 1
	alive += 1


## Sends a stuck zombie back outside a window (it keeps its health and does not count twice).
func respawn(z: Zombie) -> void:
	var hp := z.hp
	var kind := z.kind
	z.alive = false
	z.remove_from_group("zombies")
	z.queue_free()
	if z is Brute:
		var nb := Brute.new()
		nb.setup_brute(self, player, _dog_spot(), (z as Brute).max_hp)
		nb.hp = hp
		zombie_parent.add_child(nb)
		return
	if z is Dog:
		var nd := Dog.new()
		nd.setup_dog(self, player, _dog_spot(), hp)
		zombie_parent.add_child(nd)
		return
	var w := _pick_window()
	if w == null:
		alive -= 1
		return
	var nz := Zombie.new()
	nz.setup(self, player, w, _waiting_at(w), hp, "walk" if kind == "crawl" else kind)
	zombie_parent.add_child(nz)


func on_zombie_killed(z: Zombie) -> void:
	alive -= 1
	_last_kill_pos = z.global_position
	_kills_since_drop += 1
	if _drops < MAX_DROPS_PER_ROUND and not z.outside and randf() < DROP_CHANCE + _kills_since_drop * 0.001:
		_drops += 1
		_kills_since_drop = 0
		_drop(z.global_position)


func _drop(pos: Vector3, kind := "") -> void:
	var kinds := ["ammo", "double", "insta", "bomb", "carpenter", "ammo", "double", "insta"]
	var p := PowerUp.new()
	p.setup(kind if kind != "" else kinds.pick_random())
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
