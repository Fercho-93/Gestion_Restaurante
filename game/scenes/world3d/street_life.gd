extends Node3D
## Vida en la calle: gente del barrio que pasa por la acera de fuera. Es solo decorado
## (no entra ni se puede tocar), pero deja intuir que el barrio está vivo: hay más gente a
## las horas fuertes, en los barrios con más ambiente, y de vez en cuando alguien se para
## a mirar el local.

## Carril de la acera por donde pasan (lejos de la puerta y de la cola).
const LANE_X := -2.85
## Celdas por minuto de juego.
const WALK_SPEED := 2.2
## Probabilidad por minuto de juego de que aparezca alguien, según la hora.
const BASE_RATE := 0.16

var sim: RestaurantSim
## [{bot, y, dir, pause_at, pause_left}]
var _walkers: Array[Dictionary] = []
var _rng := RandomNumberGenerator.new()
var _length := 10.0


func setup(restaurant_sim: RestaurantSim) -> void:
	sim = restaurant_sim
	_length = float(sim.layout.size.y)
	_rng.randomize()


func _process(delta: float) -> void:
	if sim == null:
		return
	var minutes := delta * Game.clock.speed * SimClock.MINUTES_PER_SECOND
	if minutes <= 0.0:
		for w in _walkers:
			w["bot"].pose = Bot.Pose.DE_PIE
		return
	if _rng.randf() < minutes * BASE_RATE * _busyness():
		_spawn()
	for w in _walkers:
		_step(w, minutes)
	for w in _walkers.filter(func(x: Dictionary): return x["y"] < -2.0 or x["y"] > _length + 1.0):
		w["bot"].queue_free()
	_walkers = _walkers.filter(func(x: Dictionary): return x["y"] >= -2.0 and x["y"] <= _length + 1.0)


## Cuánta gente hay en la calle ahora (0 de madrugada, más a las horas de comer y cenar).
func _busyness() -> float:
	var h := sim.hour()
	var street := float(sim.barrio.get("ambiente_calle", 1.0))
	if h < 8:
		return 0.1 * street
	var per_hour: Dictionary = sim.demand.groups_per_hour
	return street * (0.6 + 0.25 * float(per_hour.get(h, 0.5)))


func _spawn() -> void:
	if _walkers.size() >= 6:
		return
	var bot := Bot.new()
	bot.setup(Bot.Role.CLIENTE, 5000 + _rng.randi() % 5000)
	add_child(bot)
	var dir := 1.0 if _rng.randf() < 0.5 else -1.0
	var w := {
		"bot": bot,
		"y": -1.5 if dir > 0.0 else _length + 0.5,
		"dir": dir,
		# Uno de cada cuatro se para un momento a mirar el restaurante.
		"pause_at": _rng.randf_range(2.0, _length - 2.0) if _rng.randf() < 0.25 else -100.0,
		"pause_left": _rng.randf_range(1.0, 2.5),
		"x": LANE_X + _rng.randf_range(-0.12, 0.12),
	}
	bot.position = Vector3(w["x"], 0, w["y"])
	_walkers.append(w)


func _step(w: Dictionary, minutes: float) -> void:
	var bot: Bot = w["bot"]
	if w["pause_at"] > -50.0 and absf(w["y"] - w["pause_at"]) < 0.1 and w["pause_left"] > 0.0:
		# Se ha parado a mirar el local (mira hacia dentro).
		w["pause_left"] -= minutes
		bot.pose = Bot.Pose.DE_PIE
		bot.face_direction(Vector3(1, 0, 0))
		return
	var before: float = w["y"]
	w["y"] += w["dir"] * WALK_SPEED * minutes
	if w["pause_at"] > -50.0 and w["pause_left"] > 0.0 and signf(w["pause_at"] - before) != signf(w["pause_at"] - w["y"]):
		w["y"] = w["pause_at"]
	bot.position = Vector3(w["x"], 0, w["y"])
	bot.pose = Bot.Pose.ANDANDO
	bot.face_direction(Vector3(0, 0, w["dir"]))
