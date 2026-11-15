class_name StaffMember
extends RefCounted
## Un empleado del restaurante. Atributos de 0 a 100.

const ROLE_WAITER := "camarero"
const ROLE_COOK := "cocinero"
## Lo que puede hacer cada empleado, a elección del gestor: id -> [nombre, qué hace].
const ROLES := {
	"cocina": ["Cocina", "Prepara los platos."],
	"sala": ["Sala", "Toma nota, sirve y cobra en las mesas."],
	"barra": ["Barra", "Sirve las copas de la barra y la mantiene limpia."],
	"acomodador": ["Acompañar", "Recibe a los clientes y los lleva a su mesa."],
	"limpieza": ["Limpieza", "Recoge las mesas, friega el suelo y limpia la barra."],
}
## Tareas de sala que hace cada rol (los demás roles no las hacen).
const ROLE_TASKS := {
	"cocina": [],
	"sala": ["servir", "cobrar", "pedido"],
	"barra": ["barra", "limpiar_barra"],
	"acomodador": ["acomodar"],
	"limpieza": ["recoger_mesa", "fregar", "limpiar_barra"],
}

var id: int
var nombre: String
## "camarero" para todos los de sala, barra, limpieza y acompañamiento; "cocinero" en cocina.
var puesto: String
## Lo que hace: una de las claves de ROLES.
var rol: String
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
	rol = d.get("rol", "cocina" if d["puesto"] == ROLE_COOK else "sala")
	puesto = ROLE_COOK if rol == "cocina" else ROLE_WAITER
	velocidad = float(d.get("velocidad", 50))
	trato = float(d.get("trato", 50))
	habilidad = float(d.get("habilidad", 50))
	salario_dia = float(d["salario_dia"])
	home = start_cell
	mover = Mover.new(start_cell, Mover.BASE_SPEED * speed_factor())


func set_rol(new_rol: String) -> void:
	rol = new_rol
	puesto = ROLE_COOK if rol == "cocina" else ROLE_WAITER


func rol_name() -> String:
	return ROLES[rol][0]


## Lo bien que le iría un rol según sus características (0-100).
func aptitude(for_rol: String) -> float:
	match for_rol:
		"cocina":
			return habilidad * 0.6 + velocidad * 0.4
		"sala":
			return trato * 0.6 + velocidad * 0.4
		"barra":
			return trato * 0.5 + velocidad * 0.3 + habilidad * 0.2
		"acomodador":
			return trato * 0.8 + velocidad * 0.2
		_:
			return velocidad * 0.8 + habilidad * 0.2


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
		"barra": return "Sirviendo en la barra"
		"limpiar_barra": return "Limpiando la barra"
	return "Libre"
