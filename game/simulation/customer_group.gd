class_name CustomerGroup
extends RefCounted
## Un grupo de clientes que llega, espera, se sienta, pide, come, paga y se va.

enum State {
	LLEGANDO,
	EN_COLA,
	YENDO_A_MESA,
	ESPERANDO_PEDIR,
	ESPERANDO_COMIDA,
	COMIENDO,
	ESPERANDO_CUENTA,
	SALIENDO,
	FUERA,
}

const STATE_NAMES := {
	State.LLEGANDO: "Llegando",
	State.EN_COLA: "Esperando mesa",
	State.YENDO_A_MESA: "Sentándose",
	State.ESPERANDO_PEDIR: "Quiere pedir",
	State.ESPERANDO_COMIDA: "Esperando la comida",
	State.COMIENDO: "Comiendo",
	State.ESPERANDO_CUENTA: "Quiere pagar",
	State.SALIENDO: "Se va",
	State.FUERA: "Fuera",
}

## Minutos que un grupo tolera en cada espera antes de empezar a enfadarse.
## Si espera el doble, se marcha.
const PATIENCE := {
	State.EN_COLA: 24.0,
	State.ESPERANDO_PEDIR: 13.0,
	State.ESPERANDO_COMIDA: 24.0,
	State.ESPERANDO_CUENTA: 13.0,
}

var id: int
var size: int
var members: Array[Mover] = []
var state: State = State.LLEGANDO
## Minutos que lleva en el estado actual.
var state_time := 0.0
## Unos grupos son más pacientes que otros.
var patience_factor := 1.0
## Minutos extra de paciencia mientras esperan la comida (según lo que tarden los platos).
var food_patience_extra := 0.0
var table: RestaurantLayout.Table = null
var queue_cell := Vector2i(-999, -999)
## Camarero (StaffMember) que le está atendiendo ahora mismo.
var waiter = null
var dishes: Array[String] = []
var dishes_ready := 0
var eat_time_left := 0.0
var bill := 0.0
## Lo que costaría la cuenta a precios "normales" de mercado.
var fair_bill := 0.0
## Penalización acumulada por esperas excesivas (0 = ninguna).
var wait_penalty := 0.0
var food_quality_sum := 0.0
var service_scores: Array[float] = []
var satisfaction := -1.0
var left_angry := false
var leave_reason := ""
## Lo que ha hecho el gestor por ellos (disculpas, invitaciones...): sube el ánimo.
var mood_bonus := 0.0
## Minutos extra de paciencia en la espera actual (p. ej. tras disculparse el gestor).
var patience_bonus := 0.0
## Conversaciones ya tenidas con el gestor: opción -> true (no se repiten los efectos).
var talked := {}
## Euros que se les ha invitado (se descuentan de la cuenta).
var comp_value := 0.0
## Cliente habitual (nombre) o "" si no lo es.
var regular_name := ""
## Crítico gastronómico de incógnito (su reseña pesa mucho en la reputación).
var is_critic := false
## Celebran un cumpleaños.
var birthday := false
## Miembro que es un niño (-1 si no hay): se aburre y se levanta a corretear.
var child_member := -1
## El niño: "" (en su sitio), "jugando" o "volviendo".
var child_state := ""
var child_timer := 0.0
## Ya se han quejado en voz alta (solo una vez).
var complained := false
## Hasta qué minuto se les oye quejarse ("¡Oiga!").
var shout_until := -1.0
## Vecino (Neighbor) que es cada miembro, o null (niños, clientes anónimos).
var people: Array = []


func set_state(new_state: State) -> void:
	if PATIENCE.has(state):
		var limit := patience_limit()
		wait_penalty += maxf(0.0, state_time - limit) / limit
	state = new_state
	state_time = 0.0
	patience_bonus = 0.0


func patience_limit() -> float:
	if not PATIENCE.has(state):
		return INF
	var extra := food_patience_extra if state == State.ESPERANDO_COMIDA else 0.0
	return (PATIENCE[state] + extra) * patience_factor + patience_bonus


func is_fed_up() -> bool:
	return state_time > 2.0 * patience_limit()


## Ánimo del grupo de 0 (furioso) a 1 (contento).
func mood() -> float:
	var current := 0.0
	if PATIENCE.has(state):
		current = maxf(0.0, state_time - patience_limit()) / patience_limit()
	return clampf(1.0 - 0.5 * (wait_penalty + current) + mood_bonus, 0.0, 1.0)


## Levantan la mano para llamar al camarero si llevan un rato esperando a pedir o pagar.
func hand_raised() -> bool:
	return (state == State.ESPERANDO_PEDIR or state == State.ESPERANDO_CUENTA) \
			and state_time > 0.5 * patience_limit() and waiter == null


func is_food_ready() -> bool:
	return state == State.ESPERANDO_COMIDA and not dishes.is_empty() and dishes_ready >= dishes.size()


func all_arrived() -> bool:
	for m in members:
		if not m.arrived():
			return false
	return true


## Vecino que es el miembro `member` (o null si no se sabe quién es).
func person(member: int) -> Neighbor:
	return people[member] if member >= 0 and member < people.size() else null


## Media del perfil y rasgos de los adultos del grupo para un efecto (1.0 si son anónimos).
func factor(effect: String) -> float:
	var total := 0.0
	var count := 0
	for p in people:
		if p != null:
			total += p.factor(effect)
			count += 1
	return total / count if count > 0 else 1.0


## ¿Alguien del grupo tiene este rasgo?
func has_trait(trait_id: String) -> bool:
	for p in people:
		if p != null and p.has_trait(trait_id):
			return true
	return false


func state_name() -> String:
	return STATE_NAMES[state]
