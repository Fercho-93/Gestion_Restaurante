extends Node
## Autoload "GameClock": conecta el SimClock con el bucle de Godot.
## Cualquier escena puede escuchar sus señales (p. ej. GameClock.clock.hour_changed).

var clock := SimClock.new()


func _process(delta: float) -> void:
	clock.advance(delta)
