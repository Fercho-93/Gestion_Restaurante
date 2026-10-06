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
## Ánimo de 0 a 100: influye en su rapidez, su trato y la calidad de la cocina.
var moral := 70.0
## Hasta qué minuto de juego va "apretado" porque el gestor le ha metido prisa.
var rushed_until := -1.0
## Último minuto en que el gestor le felicitó (las felicitaciones seguidas cuentan menos).
var last_praise := -1000.0
## Minuto de juego actual (lo actualiza la simulación) para los efectos con duración.
var now := 0.0


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


## Multiplicador de rapidez: según su velocidad (0.75 a 1.25), su ánimo y si va con prisa.
func speed_factor() -> float:
	var rush := 1.15 if now < rushed_until else 1.0
	return lerpf(0.75, 1.25, velocidad / 100.0) * lerpf(0.85, 1.1, moral / 100.0) * rush


## Trato al cliente según su ánimo: alguien desanimado atiende peor.
func effective_trato() -> float:
	return clampf(trato * lerpf(0.75, 1.1, moral / 100.0), 0.0, 100.0)


## Habilidad en cocina según su ánimo.
func effective_skill() -> float:
	return clampf(habilidad + (moral - 60.0) * 0.15, 0.0, 100.0)


func moral_word() -> String:
	if moral >= 80.0:
		return "muy contento"
	if moral >= 60.0:
		return "contento"
	if moral >= 40.0:
		return "regular"
	return "quemado"


## Cuántos platos puede llevar a la vez un cocinero.
func cooking_capacity() -> int:
	return 2 + int(habilidad / 40.0)


func is_busy() -> bool:
	return not task.is_empty() or not tickets.is_empty()


func is_carrying_food() -> bool:
	return (task.get("tipo", "") == "servir" and task.get("fase", "") == "ir_mesa") or task.get("fase", "") == "llevar"


func describe_task() -> String:
	if puesto == ROLE_COOK:
		return "Cocinando %d plato(s)" % tickets.size() if not tickets.is_empty() else "Libre"
	match task.get("tipo", ""):
		"pedido": return "Tomando nota"
		"servir": return "Sirviendo platos"
		"cobrar": return "Cobrando"
		"acomodar": return "Acompañando a unos clientes"
		"recoger_mesa": return "Recogiendo una mesa"
		"fregar": return "Fregando el suelo"
	return "Libre"
