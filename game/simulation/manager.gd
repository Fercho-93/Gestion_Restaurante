class_name Manager
extends RefCounted
## El gestor: el personaje que controla el jugador. Camina esquivando muebles y
## personas, usa objetos del local (el ordenador) y habla con la gente.

enum State { LIBRE, ANDANDO, USANDO, HABLANDO }

## Si alguien le corta el paso tanto tiempo (minutos de juego), desiste.
const GIVE_UP_MINUTES := 4.0
## Distancia (celdas) a la que se puede hablar con alguien.
const TALK_DISTANCE := 1.6

var mover: Mover
var state := State.LIBRE
## Celda a la que se dirige.
var destination := Vector2i.ZERO
## Objeto hacia el que va para usarlo ("" si no).
var target_object := ""
## Objeto que está usando ("" si ninguno).
var using := ""
## Persona hacia la que va para hablar: {entity, member} (vacío si no).
var talk_target := {}
## Persona con la que está hablando: {entity, member} (vacío si no).
var talking_to := {}
## Minutos que lleva parado porque alguien le corta el paso.
var blocked_time := 0.0
## Aviso para el jugador cuando no ha podido cumplir la orden ("" si no hay).
var notice := ""
## Textos para describir la orden actual (los pone quien da la orden).
var talk_name := ""
var walk_zone := ""


func _init(start: Vector2i) -> void:
	mover = Mover.new(start, Mover.BASE_SPEED * 1.1)


func walk_to(layout: RestaurantLayout, cell: Vector2i, occupied: Array[Vector2i]) -> void:
	_reset()
	_set_destination(layout, layout.nearest_free_cell(cell, mover.last_cell, occupied), occupied)


func go_use(layout: RestaurantLayout, object_id: String, occupied: Array[Vector2i]) -> void:
	_reset()
	target_object = object_id
	_set_destination(layout, layout.objects[object_id]["uso"], occupied)


func go_talk(layout: RestaurantLayout, target: Dictionary, target_cell: Vector2i, occupied: Array[Vector2i]) -> void:
	_reset()
	talk_target = target
	_set_destination(layout, layout.nearest_free_cell(target_cell, mover.last_cell, occupied), occupied)


## Deja lo que esté haciendo (levantarse del ordenador, terminar una conversación...).
func stop() -> void:
	_reset()
	mover.halt()


## Avanza `minutes`. `occupied`: celdas con otras personas. `can_enter(cell)`: si puede
## entrar en una casilla. `target_cell`: dónde está ahora la persona con la que va a
## hablar (null si ya no está). Devuelve lo que empieza a hacer:
## {"usar": id} o {"hablar": {entity, member}} o {} si nada nuevo.
func step(minutes: float, layout: RestaurantLayout, occupied: Array[Vector2i], can_enter: Callable, target_cell = null) -> Dictionary:
	if state != State.ANDANDO:
		return {}
	if not talk_target.is_empty():
		if target_cell == null:
			_reset()
			mover.halt()
			notice = "Se ha ido antes de que llegaras"
			return {}
		if mover.at_center() and Vector2(mover.last_cell).distance_to(Vector2(target_cell)) <= TALK_DISTANCE:
			mover.halt()
			talking_to = talk_target
			talk_target = {}
			state = State.HABLANDO
			return { "hablar": talking_to }
		# La persona se ha movido: se replanifica hacia ella.
		if Vector2(destination).distance_to(Vector2(target_cell)) > TALK_DISTANCE or mover.arrived():
			destination = layout.nearest_free_cell(target_cell, mover.last_cell, occupied)
			_plan(layout, occupied)
	var before := mover.pos
	mover.step(minutes, can_enter)
	if mover.pos == before and not mover.arrived():
		# Alguien le corta el paso: cada medio minuto busca otro camino; si tarda mucho, desiste.
		var previous := blocked_time
		blocked_time += minutes
		if floori(blocked_time / 0.5) != floori(previous / 0.5):
			if occupied.has(destination) and talk_target.is_empty() and target_object == "":
				destination = layout.nearest_free_cell(destination, mover.last_cell, occupied)
			_plan(layout, occupied)
		if blocked_time > GIVE_UP_MINUTES:
			_reset()
			mover.halt()
			notice = "No puede pasar"
		return {}
	blocked_time = 0.0
	if not mover.arrived() or not talk_target.is_empty():
		return {}
	if target_object != "":
		using = target_object
		target_object = ""
		state = State.USANDO
		return { "usar": using }
	state = State.LIBRE
	return {}


func describe() -> String:
	if notice != "" and state == State.LIBRE:
		return notice
	match state:
		State.ANDANDO:
			if target_object == "ordenador":
				return "Yendo al ordenador"
			if not talk_target.is_empty():
				return "Yendo a hablar con " + talk_name if talk_name != "" else "Yendo a hablar"
			if blocked_time > 0.0:
				return "Esperando a que le dejen pasar"
			return "Yendo a " + walk_zone if walk_zone != "" else "Andando"
		State.USANDO:
			return "En el ordenador" if using == "ordenador" else "Usando " + using
		State.HABLANDO:
			return "Hablando con " + talk_name if talk_name != "" else "Hablando"
	return "Libre"


func _set_destination(layout: RestaurantLayout, cell: Vector2i, occupied: Array[Vector2i]) -> void:
	destination = cell
	state = State.ANDANDO
	if not _plan(layout, occupied):
		# Sin camino posible (rodeado de muebles o gente): se queda donde está.
		_reset()
		notice = "No hay forma de llegar"


## Calcula el camino evitando a la gente; si así no hay, por donde se pueda (y ya
## esperará a que se aparten). Devuelve si hay forma de llegar.
func _plan(layout: RestaurantLayout, occupied: Array[Vector2i]) -> bool:
	if mover.try_go_to(layout, destination, occupied):
		return true
	return mover.go_to(layout, destination)


func _reset() -> void:
	state = State.LIBRE
	target_object = ""
	using = ""
	talk_target = {}
	talking_to = {}
	blocked_time = 0.0
	notice = ""
