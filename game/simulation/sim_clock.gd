class_name SimClock
extends RefCounted
## Reloj de la simulación. Lógica pura: no depende de nodos ni de la pantalla.
## Avanza en minutos de juego y emite señales al cambiar de minuto, hora o día.

signal minute_passed(total_minutes: int)
signal hour_changed(day: int, hour: int)
signal day_changed(day: int)
signal speed_changed(speed: int)

## Velocidades disponibles (0 = pausa).
const SPEEDS: Array[int] = [0, 1, 2, 4]
## Minutos de juego por segundo real a velocidad x1.
const MINUTES_PER_SECOND := 1.0
const MINUTES_PER_DAY := 24 * 60

var total_minutes: float = 0.0
var speed: int = 1
## Velocidad antes de pausar, para poder reanudar.
var _speed_before_pause: int = 1


func _init(start_day: int = 1, start_hour: int = 10, start_minute: int = 0) -> void:
	total_minutes = (start_day - 1) * MINUTES_PER_DAY + start_hour * 60 + start_minute


## Avanza el reloj según el tiempo real transcurrido. Devuelve los minutos de juego avanzados.
func advance(real_seconds: float) -> float:
	if speed == 0:
		return 0.0
	var before := int(total_minutes)
	var advanced := real_seconds * MINUTES_PER_SECOND * speed
	total_minutes += advanced
	for m in range(before + 1, int(total_minutes) + 1):
		minute_passed.emit(m)
		if m % 60 == 0:
			hour_changed.emit(_day_of(m), (m % MINUTES_PER_DAY) / 60)
		if m % MINUTES_PER_DAY == 0:
			day_changed.emit(_day_of(m))
	return advanced


func set_speed(new_speed: int) -> void:
	assert(new_speed in SPEEDS, "Velocidad no válida: %d" % new_speed)
	if new_speed == speed:
		return
	if new_speed == 0:
		_speed_before_pause = speed
	speed = new_speed
	speed_changed.emit(speed)


func toggle_pause() -> void:
	set_speed(_speed_before_pause if speed == 0 else 0)


func is_paused() -> bool:
	return speed == 0


func get_day() -> int:
	return _day_of(int(total_minutes))


func get_hour() -> int:
	return (int(total_minutes) % MINUTES_PER_DAY) / 60


func get_minute() -> int:
	return int(total_minutes) % 60


func get_time_text() -> String:
	return "Día %d · %02d:%02d" % [get_day(), get_hour(), get_minute()]


static func _day_of(minutes: int) -> int:
	return minutes / MINUTES_PER_DAY + 1
