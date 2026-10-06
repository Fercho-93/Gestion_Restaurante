class_name Conversation
extends RefCounted
## Lo que se dicen el gestor y la gente del local. Las respuestas salen del estado real
## de la simulación (lo que esperan, lo que han comido, el trabajo pendiente...).
## De momento hablar no tiene efectos: solo informa.

const CUSTOMER_NAMES := ["Carmen", "Javier", "Lucía", "Manuel", "Elena", "Pablo", "Rosa",
	"Andrés", "Marta", "Diego", "Isabel", "Sergio", "Nuria", "Raúl", "Pilar", "Óscar"]

const CUSTOMER_OPTIONS := [
	{ "id": "que_tal", "texto": "¿Qué tal todo?" },
	{ "id": "precios", "texto": "¿Qué le parecen los precios?" },
	{ "id": "adios", "texto": "Que disfruten" },
]
const STAFF_OPTIONS := [
	{ "id": "trabajo", "texto": "¿Cómo va el trabajo?" },
	{ "id": "animo", "texto": "¡Buen trabajo!" },
	{ "id": "adios", "texto": "Sigue así" },
]


static func speaker_name(target: Dictionary) -> String:
	var e = target["entity"]
	if e is StaffMember:
		return "%s (%s)" % [e.nombre, "camarero" if e.puesto == StaffMember.ROLE_WAITER else "cocina"]
	if e is CustomerGroup:
		var who := customer_name(e, target["member"])
		return who + (" · cliente" if e.size == 1 else " · cliente, grupo de %d" % e.size)
	return ""


static func customer_name(g: CustomerGroup, member: int) -> String:
	return CUSTOMER_NAMES[(g.id * 5 + member * 3) % CUSTOMER_NAMES.size()]


static func options(target: Dictionary) -> Array:
	return STAFF_OPTIONS if target["entity"] is StaffMember else CUSTOMER_OPTIONS


## Lo primero que dice la persona al acercarse el gestor.
static func opening(target: Dictionary, sim: RestaurantSim) -> String:
	var e = target["entity"]
	if e is StaffMember:
		if e.puesto == StaffMember.ROLE_COOK:
			return "¿Sí, jefe? Aquí, entre fogones." if e.tickets.is_empty() else "¡Dígame, jefe! Tengo %d plato(s) al fuego." % e.tickets.size()
		return "¿Sí, jefe? Estoy libre." if e.task.is_empty() else "¡Dígame, jefe! Estaba %s." % e.describe_task().to_lower()
	var g: CustomerGroup = e
	var mood := g.mood()
	match g.state:
		CustomerGroup.State.LLEGANDO, CustomerGroup.State.EN_COLA:
			return "Hola. ¿Queda mucho para que haya mesa?" if mood > 0.5 else "¡Llevamos un buen rato esperando mesa!"
		CustomerGroup.State.YENDO_A_MESA:
			return "¡Hola! Vamos a sentarnos."
		CustomerGroup.State.ESPERANDO_PEDIR:
			return "Buenas. Cuando puedan, nos toman nota." if mood > 0.5 else "¿Nos va a tomar nota alguien o qué?"
		CustomerGroup.State.ESPERANDO_COMIDA:
			if mood > 0.7:
				return "¡Qué bien huele! ¿Falta mucho para la comida?"
			return "La comida está tardando, ¿eh?" if mood > 0.4 else "Esto es una vergüenza, ¡no llega la comida!"
		CustomerGroup.State.COMIENDO:
			return _food_opinion(g, sim, target["member"])
		CustomerGroup.State.ESPERANDO_CUENTA:
			return "¿Nos puede traer la cuenta, por favor?" if mood > 0.4 else "¡Que alguien nos cobre de una vez!"
		CustomerGroup.State.SALIENDO:
			if g.left_angry:
				return "No pienso volver. %s." % g.leave_reason
			return "¡Muchas gracias, volveremos!" if g.satisfaction >= 70.0 else "Adiós."
	return "Hola."


## Respuesta a una de las preguntas del gestor.
static func reply(target: Dictionary, option_id: String, sim: RestaurantSim) -> String:
	var e = target["entity"]
	if e is StaffMember:
		match option_id:
			"trabajo":
				return _work_report(e, sim)
			"animo":
				return "¡Gracias, jefe! Así da gusto."
			"adios":
				return "¡A mandar!"
		return ""
	var g: CustomerGroup = e
	match option_id:
		"que_tal":
			if g.state == CustomerGroup.State.COMIENDO or g.state == CustomerGroup.State.ESPERANDO_CUENTA:
				return _food_opinion(g, sim, target["member"])
			var mood := g.mood()
			if mood > 0.7:
				return "Muy bien, el sitio es agradable."
			return "Bueno… la espera se está haciendo larga." if mood > 0.4 else "Mal. Estamos pensando en irnos."
		"precios":
			if g.dishes.is_empty():
				return "Todavía no hemos pedido, pero la carta parece %s." % _price_word(sim)
			var value := Satisfaction.value_for_money(g.bill, g.fair_bill)
			if value >= 70.0:
				return "Están muy bien para lo que es."
			return "Normales, lo esperado." if value >= 45.0 else "Un poco caro, la verdad."
		"adios":
			return "¡Gracias!" if g.mood() > 0.4 else "Ya…"
	return ""


static func _food_opinion(g: CustomerGroup, sim: RestaurantSim, member: int) -> String:
	if g.dishes.is_empty():
		return "Aún no hemos comido."
	var dish: String = g.dishes[member % g.dishes.size()]
	var name: String = sim.recipes[dish]["nombre"].to_lower()
	var quality := g.food_quality_sum / maxf(1.0, float(g.dishes_ready))
	if quality >= 75.0:
		return "¡El %s está buenísimo!" % name
	if quality >= 50.0:
		return "El %s está correcto." % name
	return "El %s deja bastante que desear…" % name


static func _work_report(s: StaffMember, sim: RestaurantSim) -> String:
	if s.puesto == StaffMember.ROLE_COOK:
		var pending := sim.kitchen_queue.size()
		if pending == 0 and s.tickets.is_empty():
			return "Tranquilo. La cocina está al día."
		if pending <= 3:
			return "Bien. Hay %d plato(s) esperando, vamos sacándolos." % pending
		return "¡Estamos desbordados! Hay %d platos en cola." % pending
	var waiting := 0
	for g in sim.groups:
		if g.state == CustomerGroup.State.ESPERANDO_PEDIR or g.state == CustomerGroup.State.ESPERANDO_CUENTA or g.is_food_ready():
			waiting += 1
	if waiting == 0:
		return "Tranquilo. Todas las mesas están atendidas."
	if waiting <= 2:
		return "Bien. Tengo %d mesa(s) pendiente(s)." % waiting
	return "¡No damos abasto! Hay %d mesas esperando." % waiting


## Cómo de cara ve un cliente la carta en general.
static func _price_word(sim: RestaurantSim) -> String:
	var ratio := 0.0
	for recipe_id in sim.menu:
		ratio += sim.menu[recipe_id] / float(sim.recipes[recipe_id]["precio_sugerido"])
	ratio /= maxf(1.0, float(sim.menu.size()))
	if ratio < 0.95:
		return "barata"
	return "razonable" if ratio <= 1.1 else "cara"
