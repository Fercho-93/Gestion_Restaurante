extends Node
## Autoload "Game": el reloj y la simulación del restaurante en marcha.
## Las escenas leen Game.sim y escuchan las señales de Game.clock y Game.sim.

## Paso máximo de simulación en minutos de juego (para que x4 sea igual de preciso).
const MAX_STEP := 0.25

var clock := SimClock.new(1, 11, 30)
var sim: RestaurantSim


func _ready() -> void:
	sim = RestaurantSim.new(GameData.sim_data(), clock.total_minutes)


func _process(delta: float) -> void:
	var pending := clock.advance(delta)
	while pending > 0.0:
		var step := minf(pending, MAX_STEP)
		sim.update(step)
		pending -= step
