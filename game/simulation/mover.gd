class_name Mover
extends RefCounted
## Algo que camina por la rejilla siguiendo un camino de celdas (clientes y personal).

## Velocidad base en celdas por minuto de juego.
const BASE_SPEED := 4.0

## Posición en coordenadas de rejilla (con decimales mientras camina).
var pos: Vector2
var path: Array[Vector2i] = []
var speed := BASE_SPEED
var facing := Vector2.DOWN
## Pequeño desplazamiento visual para que los miembros de un grupo no se pisen.
var jitter := Vector2.ZERO


func _init(start: Vector2i, walk_speed: float = BASE_SPEED) -> void:
	pos = Vector2(start)
	speed = walk_speed


func cell() -> Vector2i:
	return Vector2i(roundi(pos.x), roundi(pos.y))


func go_to(layout: RestaurantLayout, target: Vector2i) -> void:
	path = layout.find_path(cell(), target)
	if path.is_empty() and target != cell():
		# Sin camino posible: va en línea recta para no quedarse atascado.
		path = [target]
	if not path.is_empty() and pos == Vector2(path[0]):
		path.pop_front()


func is_moving() -> bool:
	return not path.is_empty()


func step(minutes: float) -> void:
	var distance := speed * minutes
	while distance > 0.0 and not path.is_empty():
		var target := Vector2(path[0])
		var to_target := target - pos
		var d := to_target.length()
		if d > 0.0:
			facing = to_target / d
		if d <= distance:
			pos = target
			distance -= d
			path.pop_front()
		else:
			pos += to_target / d * distance
			distance = 0.0
