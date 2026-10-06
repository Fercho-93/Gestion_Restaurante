extends Node
## Autoload "Game": el reloj y la simulación del restaurante en marcha.
## Las escenas leen Game.sim y escuchan las señales de Game.clock y Game.sim.
## La partida empieza al elegir barrio (Game.start).

## Paso máximo de simulación en minutos de juego (para que x4 sea igual de preciso).
const MAX_STEP := 0.25
const MAIN_SCENE := "res://scenes/main/main.tscn"
## Barrio si se abre el restaurante directamente sin pasar por la pantalla de inicio.
const DEFAULT_BARRIO := "alternativo"

var clock := SimClock.new(1, 11, 30)
var sim: RestaurantSim:
	get:
		if _sim == null:
			_sim = RestaurantSim.new(GameData.sim_data(DEFAULT_BARRIO), clock.total_minutes)
		return _sim
var _sim: RestaurantSim


## Empieza una partida nueva en el barrio elegido y abre el restaurante.
func start(barrio_id: String) -> void:
	clock = SimClock.new(1, 11, 30)
	_sim = RestaurantSim.new(GameData.sim_data(barrio_id), clock.total_minutes)
	get_tree().change_scene_to_file(MAIN_SCENE)


func _process(delta: float) -> void:
	if _sim == null:
		return
	var pending := clock.advance(delta)
	while pending > 0.0:
		var step := minf(pending, MAX_STEP)
		_sim.update(step)
		pending -= step
