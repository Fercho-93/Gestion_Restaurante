class_name StaffMember
extends RefCounted
## Un empleado del restaurante. Atributos de 0 a 100.

const ROLE_WAITER := "camarero"
const ROLE_COOK := "cocinero"

var id: int
var nombre: String
var puesto: String
var velocidad: float
var trato: float
var habilidad: float
var salario_dia: float
var mover: Mover
## Dónde espera cuando no tiene nada que hacer.
var home: Vector2i
## Camareros: tarea actual {tipo, grupo, fase, tiempo} o vacía si está libre.
var task: Dictionary = {}
## Cocineros: platos que está preparando [{grupo, receta, tiempo}].
var tickets: Array[Dictionary] = []
## Está hablando con el gestor (los camareros se paran mientras tanto).
var talking := false


func _init(d: Dictionary, staff_id: int, start_cell: Vector2i) -> void:
	id = staff_id
	nombre = d["nombre"]
	puesto = d["puesto"]
	velocidad = float(d.get("velocidad", 50))
	trato = float(d.get("trato", 50))
	habilidad = float(d.get("habilidad", 50))
	salario_dia = float(d["salario_dia"])
	home = start_cell
	mover = Mover.new(start_cell, Mover.BASE_SPEED * speed_factor())


## Multiplicador de rapidez: 0.75 (lento) a 1.25 (rápido).
func speed_factor() -> float:
	return lerpf(0.75, 1.25, velocidad / 100.0)


## Cuántos platos puede llevar a la vez un cocinero.
func cooking_capacity() -> int:
	return 2 + int(habilidad / 40.0)


func is_busy() -> bool:
	return not task.is_empty() or not tickets.is_empty()


func is_carrying_food() -> bool:
	return task.get("tipo", "") == "servir" and task.get("fase", "") == "ir_mesa"


func describe_task() -> String:
	if puesto == ROLE_COOK:
		return "Cocinando %d plato(s)" % tickets.size() if not tickets.is_empty() else "Libre"
	match task.get("tipo", ""):
		"pedido": return "Tomando nota"
		"servir": return "Sirviendo platos"
		"cobrar": return "Cobrando"
	return "Libre"
