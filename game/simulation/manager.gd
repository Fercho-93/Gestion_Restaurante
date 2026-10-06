class_name Manager
extends RefCounted
## El gestor: el personaje que controla el jugador. Va adonde le mandan y usa los
## objetos del local (por ejemplo, el ordenador del despacho).

enum State { LIBRE, ANDANDO, USANDO }

const STATE_NAMES := {
	State.LIBRE: "Libre",
	State.ANDANDO: "Andando",
	State.USANDO: "Usando",
}

var mover: Mover
var state := State.LIBRE
## Objeto hacia el que va para usarlo ("" si solo camina).
var target_object := ""
## Objeto que está usando ahora ("" si ninguno).
var using := ""


func _init(start: Vector2i) -> void:
	mover = Mover.new(start, Mover.BASE_SPEED * 1.1)


func walk_to(layout: RestaurantLayout, cell: Vector2i) -> void:
	using = ""
	target_object = ""
	mover.go_to(layout, layout.nearest_walkable(cell))
	state = State.ANDANDO


func go_use(layout: RestaurantLayout, object_id: String) -> void:
	using = ""
	target_object = object_id
	mover.go_to(layout, layout.objects[object_id]["uso"])
	state = State.ANDANDO


func stop_using() -> void:
	using = ""
	if state == State.USANDO:
		state = State.LIBRE


## Avanza `minutes` de juego. Devuelve el objeto que empieza a usar en este paso, si lo hay.
func step(minutes: float) -> String:
	mover.step(minutes)
	if state != State.ANDANDO or mover.is_moving():
		return ""
	if target_object == "":
		state = State.LIBRE
		return ""
	using = target_object
	target_object = ""
	state = State.USANDO
	return using


func describe() -> String:
	match state:
		State.ANDANDO:
			return "Yendo a usar el ordenador" if target_object == "ordenador" else "Andando"
		State.USANDO:
			return "En el ordenador" if using == "ordenador" else "Usando " + using
	return "Libre"
