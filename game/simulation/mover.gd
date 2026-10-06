class_name Mover
extends RefCounted
## Algo que camina por la rejilla de casilla en casilla (clientes, personal y gestor).
## Antes de entrar en una casilla pregunta si está libre: así nadie atraviesa a nadie.

## Velocidad base en celdas por minuto de juego.
const BASE_SPEED := 3.0

## Posición en coordenadas de rejilla (con decimales mientras camina).
var pos: Vector2
## Casillas que faltan por recorrer (la primera es a la que se dirige ahora).
var path: Array[Vector2i] = []
var speed := BASE_SPEED
var facing := Vector2.DOWN
## Pequeño desplazamiento visual para que los miembros de un grupo no se pisen.
var jitter := Vector2.ZERO
## Última casilla en la que ha estado parado del todo.
var last_cell: Vector2i
## Adonde quiere llegar.
var goal: Vector2i
## En el último paso no pudo avanzar porque alguien ocupaba la casilla siguiente.
var blocked := false
## Minutos que lleva sin poder avanzar hacia su destino.
var wait_time := 0.0
## Último recurso tras una espera muy larga: puede entrar en la siguiente casilla aunque
## la ocupe alguien que también va andando (atasco cara a cara), nunca alguien parado.
var ghost := false


func _init(start: Vector2i, walk_speed: float = BASE_SPEED) -> void:
	pos = Vector2(start)
	last_cell = start
	goal = start
	speed = walk_speed


func cell() -> Vector2i:
	return Vector2i(roundi(pos.x), roundi(pos.y))


## Está parado en el centro de una casilla (no a medio camino entre dos).
func at_center() -> bool:
	return pos == Vector2(last_cell)


## Casillas que ocupa: la suya y, si va de camino a otra, también esa.
func occupied_cells() -> Array[Vector2i]:
	var cells: Array[Vector2i] = [last_cell]
	if not at_center() and not path.is_empty():
		cells.append(path[0])
	return cells


## Fija el destino y calcula el camino. Si no hay camino, se queda quieto (y lo
## seguirá intentando quien lo mueva). Devuelve si ha encontrado camino.
func go_to(layout: RestaurantLayout, target: Vector2i, occupied: Array[Vector2i] = []) -> bool:
	goal = target
	if try_go_to(layout, target, occupied):
		return true
	_keep_only_current_step()
	return false


## Como go_to, pero si no hay camino deja el que tenía.
func try_go_to(layout: RestaurantLayout, target: Vector2i, occupied: Array[Vector2i] = []) -> bool:
	# Si va a medio camino, primero termina de llegar a la casilla siguiente.
	var walking := not at_center() and not path.is_empty()
	var start := path[0] if walking else last_cell
	if start == target:
		_keep_only_current_step()
		goal = target
		return true
	var new_path := layout.find_path(start, target, occupied)
	if new_path.is_empty():
		return false
	goal = target
	if not walking:
		new_path.pop_front()
	path = new_path
	return true


## Se detiene en cuanto pueda (si va a medio camino, termina de llegar a esa casilla).
func halt() -> void:
	_keep_only_current_step()
	goal = path[0] if not path.is_empty() else last_cell


## Deja solo la casilla a la que va de camino (o nada si está parado).
func _keep_only_current_step() -> void:
	if at_center() or path.is_empty():
		path.clear()
	else:
		path.resize(1)


func is_moving() -> bool:
	return not path.is_empty()


## Ha llegado a su destino y está parado en él.
func arrived() -> bool:
	return path.is_empty() and last_cell == goal


## Avanza `minutes`. `can_enter(cell) -> bool` dice si puede entrar en una casilla.
func step(minutes: float, can_enter: Callable = Callable()) -> void:
	blocked = false
	var distance := speed * minutes
	while distance > 0.0 and not path.is_empty():
		if at_center() and can_enter.is_valid() and not can_enter.call(path[0]):
			blocked = true
			return
		var target := Vector2(path[0])
		var to_target := target - pos
		var d := to_target.length()
		if d > 0.0:
			facing = to_target / d
		if d <= distance:
			pos = target
			distance -= d
			last_cell = path.pop_front()
			ghost = false
		else:
			pos += to_target / d * distance
			distance = 0.0
