class_name Extraction
extends Node
## The Village objective. Four "lanternes des morts" can be relit, one after another: the k-th
## from round ROUNDS[k] for PRICES[k] points, followed by a defence (stay near it for 60 s
## while the dead climb out around it). With all four alight the chapel door opens; going
## through starts the final stand, and surviving it is a successful extraction.

signal extracted

const ROUNDS := [5, 10, 15, 20]
const PRICES := [10000, 25000, 50000, 75000]
const DEFENSE_TIME := 60.0
const DEFENSE_RADIUS := 8.0
const FINAL_TIME := 90.0
const FINAL_RADIUS := 8.0

var lanterns: Array[Lantern] = []
var portal: ExtractionPortal
var player: Player
var director: Director

var lit_count := 0
var active: Lantern = null
var defense_t := 0.0
var final_running := false
var final_t := 0.0
var done := false
var _spawn_t := 0.0
var _extra: Array[Zombie] = []


func next_round() -> int:
	return ROUNDS[mini(lit_count, ROUNDS.size() - 1)]


func next_price() -> int:
	return PRICES[mini(lit_count, PRICES.size() - 1)]


func lantern_hint(l: Lantern) -> String:
	if l.lit or l == active or done:
		return ""
	if active:
		return "Lanterne des morts — défendez d'abord l'autre lanterne"
	if G.round_num < next_round():
		return "Lanterne des morts — elle pourra être rallumée à la manche %d" % next_round()
	if l.paid:
		return "%s reprendre la défense de la lanterne" % l.use_text()
	return "%s rallumer la lanterne des morts %s" % [l.use_text(), l.price_text(next_price())]


func portal_hint() -> String:
	if done or final_running:
		return ""
	if not portal.open:
		return "Une porte scellée… Rallumez les quatre lanternes des morts (%d/4)" % lit_count
	return "%s franchir la porte : extraction (tenir %d s)" % [portal.use_text(), int(FINAL_TIME)]


func try_light(l: Lantern) -> void:
	if l.lit or active or done or G.round_num < next_round():
		return
	if not l.paid:
		if not G.spend(next_price()):
			return
		l.paid = true
	active = l
	defense_t = 0.0
	_spawn_t = 1.0
	_extra.clear()
	l.progress = 0.0
	l.set_state("defend")
	G.play("thunder", 0.0, 0.8)
	G.say("DÉFENDEZ LA LANTERNE !", Color(0.6, 0.85, 1.0))
	# The last two lanterns also wake a Colosse.
	if lit_count >= 2:
		director.spawn_brute_near(l.center)


func start_final() -> void:
	if not portal.open or final_running or done:
		return
	final_running = true
	final_t = 0.0
	_spawn_t = 0.5
	_extra.clear()
	G.play("brute_roar", 0.0, 0.8)
	G.say("TENEZ BON JUSQU'À L'OUVERTURE !", Color(0.6, 0.85, 1.0))
	director.spawn_brute_near(portal.front + Vector3(-6, 0, 0))


func _alive_extra() -> int:
	var n := 0
	for z in _extra:
		if is_instance_valid(z) and z.alive:
			n += 1
	return n


func _spawn_near(pos: Vector3, radius: float) -> void:
	var kind := director._kind_for_round(G.round_num)
	if kind == "walk":
		kind = "jog"
	_extra.append(director.spawn_rise_near(pos, radius, G.zombie_health(G.round_num), kind))


func _process(delta: float) -> void:
	if not G.playing or player == null or done or player.dead:
		return
	if active:
		var near := player.global_position.distance_to(active.center) <= DEFENSE_RADIUS and not player.downed
		if near:
			defense_t += delta
		active.progress = defense_t / DEFENSE_TIME
		_spawn_t -= delta
		if _spawn_t <= 0.0:
			_spawn_t = maxf(1.1, 2.6 - 0.4 * lit_count)
			if _alive_extra() < 6 + 2 * lit_count:
				_spawn_near(active.center, 10.0)
		if defense_t >= DEFENSE_TIME:
			_relit(active)
	elif final_running:
		if player.global_position.distance_to(portal.front) <= FINAL_RADIUS and not player.downed:
			final_t += delta
		_spawn_t -= delta
		if _spawn_t <= 0.0:
			_spawn_t = 0.9
			if _alive_extra() < 16:
				_spawn_near(portal.front + Vector3(-5, 0, 0), 9.0)
		if final_t >= FINAL_TIME:
			done = true
			final_running = false
			extracted.emit()


func _relit(l: Lantern) -> void:
	l.paid = false
	l.progress = 1.0
	l.set_state("lit")
	lit_count += 1
	active = null
	G.play("challenge", 0.0, 0.8)
	G.say("LANTERNE RALLUMÉE — %d/4" % lit_count, Color(0.6, 0.85, 1.0))
	if lit_count >= lanterns.size():
		portal.set_open(true)
		G.play("power_on", 0.0, 0.7)
		await get_tree().create_timer(2.5).timeout
		G.say("LA PORTE DE LA CHAPELLE S'EST OUVERTE", Color(0.75, 0.92, 1.0))


func objective_text() -> String:
	if done:
		return ""
	if final_running:
		var t := "EXTRACTION — tenez encore %d s" % ceili(FINAL_TIME - final_t)
		if player.global_position.distance_to(portal.front) > FINAL_RADIUS:
			t += " — retournez à la porte !"
		return t
	if active:
		var t := "DÉFENSE DE LA LANTERNE — %d s" % ceili(DEFENSE_TIME - defense_t)
		if player.global_position.distance_to(active.center) > DEFENSE_RADIUS:
			t += " — rapprochez-vous !"
		return t
	if lit_count >= lanterns.size():
		return "La porte de la chapelle est ouverte : extraction possible"
	var line := "Lanternes des morts : %d/4" % lit_count
	if G.round_num < next_round():
		line += " — la prochaine à la manche %d" % next_round()
	else:
		line += " — prochaine : %d points" % next_price()
	return line


func save_state() -> Dictionary:
	var lit: Array = []
	var paid: Array = []
	for l in lanterns:
		if l.lit:
			lit.append(l.id)
		elif l.paid or l == active:
			# A defence under way when the game is saved starts over, already paid for.
			paid.append(l.id)
	return {"lit": lit, "paid": paid}


func load_state(d: Dictionary) -> void:
	var lit: Array = d.get("lit", [])
	var paid: Array = d.get("paid", [])
	for l in lanterns:
		if lit.has(l.id):
			l.lit = true
			l.progress = 1.0
			l.set_state("lit")
			lit_count += 1
		elif paid.has(l.id):
			l.paid = true
	if lit_count >= lanterns.size():
		portal.set_open(true)
