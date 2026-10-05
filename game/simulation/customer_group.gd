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
	State.EN_COLA: 15.0,
	State.ESPERANDO_PEDIR: 8.0,
	State.ESPERANDO_COMIDA: 15.0,
	State.ESPERANDO_CUENTA: 8.0,
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


func set_state(new_state: State) -> void:
	if PATIENCE.has(state):
		var limit := patience_limit()
		wait_penalty += maxf(0.0, state_time - limit) / limit
	state = new_state
	state_time = 0.0


func patience_limit() -> float:
	if not PATIENCE.has(state):
		return INF
	var extra := food_patience_extra if state == State.ESPERANDO_COMIDA else 0.0
	return (PATIENCE[state] + extra) * patience_factor


func is_fed_up() -> bool:
	return state_time > 2.0 * patience_limit()


## Ánimo del grupo de 0 (furioso) a 1 (contento).
func mood() -> float:
	var current := 0.0
	if PATIENCE.has(state):
		current = maxf(0.0, state_time - patience_limit()) / patience_limit()
	return clampf(1.0 - 0.5 * (wait_penalty + current), 0.0, 1.0)


func is_food_ready() -> bool:
	return state == State.ESPERANDO_COMIDA and not dishes.is_empty() and dishes_ready >= dishes.size()


func all_arrived() -> bool:
	for m in members:
		if m.is_moving():
			return false
	return true


func state_name() -> String:
	return STATE_NAMES[state]
