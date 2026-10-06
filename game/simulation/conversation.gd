class_name Conversation
extends RefCounted
## Lo que se dicen el gestor y la gente del local. Las frases salen del estado real de la
## simulación y algunas opciones tienen efectos: calmar a un cliente, invitarle a algo,
## animar o meter prisa a un empleado...

const CUSTOMER_NAMES := ["Carmen", "Javier", "Lucía", "Manuel", "Elena", "Pablo", "Rosa",
	"Andrés", "Marta", "Diego", "Isabel", "Sergio", "Nuria", "Raúl", "Pilar", "Óscar"]

## Lo que cuesta invitar a un postre o a una ronda.
const TREAT_COST := 4.5
## Cuánto sube el ánimo (0-1) cada cosa que hace el gestor.
const APOLOGY_MOOD := 0.15
const APOLOGY_PATIENCE := 6.0
const TREAT_MOOD := 0.3
const CHAT_MOOD := 0.05
const PRAISE_MORAL := 10.0
const RUSH_MORAL := 12.0
const RUSH_MINUTES := 60.0


static func speaker_name(target: Dictionary) -> String:
	var e = target["entity"]
	if e is Manager:
		return "Tú (gestor)"
	if e is StaffMember:
		return "%s (%s)" % [e.nombre, "camarero" if e.puesto == StaffMember.ROLE_WAITER else "cocina"]
	if e is CustomerGroup:
		var who := customer_name(e, target["member"])
		return who + (" · cliente" if e.size == 1 else " · cliente, grupo de %d" % e.size)
	return ""


static func customer_name(g: CustomerGroup, member: int) -> String:
	if member == 0 and g.regular_name != "":
		return g.regular_name
	if member == g.child_member:
		return ["Lucas", "Martina", "Hugo", "Vera"][g.id % 4] + " (niño)"
	return CUSTOMER_NAMES[(g.id * 5 + member * 3) % CUSTOMER_NAMES.size()]


## Opciones disponibles ahora mismo: [{id, texto}].
static func options(target: Dictionary, sim: RestaurantSim) -> Array:
	var e = target["entity"]
	var list := []
	if e is Manager:
		if e.energy < 90.0:
			list.append({ "id": "cafe", "texto": "Ir a tomar un café", "trabajo": true })
		if e.covering != "sala":
			list.append({ "id": "cubrir_sala", "texto": "Ponerme a atender mesas", "trabajo": true })
		if e.covering != "limpieza":
			list.append({ "id": "cubrir_limpieza", "texto": "Ponerme a limpiar", "trabajo": true })
		if e.covering != "":
			list.append({ "id": "dejar", "texto": "Dejar lo que estoy haciendo", "trabajo": true })
		list.append({ "id": "adios", "texto": "Nada por ahora" })
		return list
	if e is StaffMember:
		list.append({ "id": "trabajo", "texto": "¿Cómo va el trabajo?" })
		list.append({ "id": "como_estas", "texto": "¿Cómo estás?" })
		list.append({ "id": "felicitar", "texto": "¡Buen trabajo!" })
		list.append({ "id": "prisa", "texto": "Hay que ir más rápido" })
		list.append({ "id": "adios", "texto": "Sigue así" })
		return list
	var g: CustomerGroup = e
	# El gestor puede hacer él mismo el trabajo de un camarero con este grupo.
	if g.waiter == null:
		if g.state == CustomerGroup.State.EN_COLA and sim.free_table_for(g) != null:
			list.append({ "id": "acomodar", "texto": "Acompáñenme, tienen mesa", "trabajo": true })
		elif g.state == CustomerGroup.State.ESPERANDO_PEDIR:
			list.append({ "id": "pedido", "texto": "Les tomo nota yo", "trabajo": true })
		elif g.is_food_ready():
			list.append({ "id": "servir", "texto": "Les traigo la comida", "trabajo": true })
		elif g.state == CustomerGroup.State.ESPERANDO_CUENTA:
			list.append({ "id": "cobrar", "texto": "Les cobro yo", "trabajo": true })
	list.append({ "id": "que_tal", "texto": "¿Qué tal todo?" })
	var waiting := CustomerGroup.PATIENCE.has(g.state)
	if waiting and g.mood() < 0.9 and not g.talked.has("disculpa"):
		list.append({ "id": "disculpa", "texto": "Disculpen la espera" })
	var at_table := g.state in [CustomerGroup.State.ESPERANDO_COMIDA, CustomerGroup.State.COMIENDO, CustomerGroup.State.ESPERANDO_CUENTA]
	if at_table and g.birthday and not g.talked.has("tarta"):
		list.append({ "id": "tarta", "texto": "¡Felicidades! La tarta invita la casa (%.0f €)" % RestaurantSim.CAKE_COST })
	if at_table and not g.talked.has("invitar"):
		list.append({ "id": "invitar", "texto": "Les invito al postre (%.2f €)" % TREAT_COST })
	if g.state == CustomerGroup.State.SALIENDO and g.left_angry and not g.talked.has("compensar"):
		list.append({ "id": "compensar", "texto": "Lo siento mucho, la próxima vez invita la casa" })
	elif not g.dishes.is_empty() or g.state == CustomerGroup.State.SALIENDO:
		list.append({ "id": "mejorar", "texto": "¿Qué podríamos mejorar?" })
	else:
		list.append({ "id": "precios", "texto": "¿Qué le parecen los precios?" })
	list.append({ "id": "adios", "texto": "Que disfruten" })
	return list


## Lo primero que dice la persona al acercarse el gestor.
static func opening(target: Dictionary, sim: RestaurantSim) -> String:
	var e = target["entity"]
	if e is Manager:
		var tired := "" if e.energy >= 70.0 else " (Estoy %s.)" % e.energy_word()
		match e.covering:
			"sala":
				return "Estoy atendiendo mesas. ¿Sigo o hago otra cosa?" + tired
			"limpieza":
				return "Estoy limpiando el local. ¿Sigo o hago otra cosa?" + tired
		return "¿Qué hago ahora?" + tired
	if e is StaffMember:
		var mood_hint := "" if e.moral >= 40.0 else " (Se le ve cansado.)"
		if e.puesto == StaffMember.ROLE_COOK:
			return ("¿Sí, jefe? Aquí, entre fogones." if e.tickets.is_empty() else "¡Dígame, jefe! Tengo %d plato(s) al fuego." % e.tickets.size()) + mood_hint
		return ("¿Sí, jefe? Estoy libre." if e.task.is_empty() else "¡Dígame, jefe! Estaba %s." % e.describe_task().to_lower()) + mood_hint
	var g: CustomerGroup = e
	var mood := g.mood()
	if g.regular_name != "" and g.state != CustomerGroup.State.SALIENDO and not g.talked.has("saludo"):
		return "¡Hombre, jefe! Aquí estamos otra vez, como siempre."
	if g.is_critic and g.state in [CustomerGroup.State.ESPERANDO_COMIDA, CustomerGroup.State.COMIENDO]:
		return "Mmm… Nada, nada. Solo tomaba unas notas."
	if g.birthday and g.state in [CustomerGroup.State.ESPERANDO_PEDIR, CustomerGroup.State.ESPERANDO_COMIDA, CustomerGroup.State.COMIENDO]:
		return "¡Hoy celebramos un cumpleaños!"
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


## Elige una opción: aplica su efecto y devuelve la respuesta de la persona.
static func choose(target: Dictionary, option_id: String, sim: RestaurantSim) -> String:
	var e = target["entity"]
	if e is Manager:
		match option_id:
			"cafe":
				sim.order_manager_use("cafetera")
				return "Un cafecito y como nuevo."
			"cubrir_sala":
				sim.set_manager_covering("sala")
				return "Manos a la obra: a atender mesas."
			"cubrir_limpieza":
				sim.set_manager_covering("limpieza")
				return "A dejar el local reluciente."
			"dejar":
				sim.set_manager_covering("")
				return "Vale, lo dejo."
		return "Sigo a lo mío."
	if e is StaffMember:
		return _staff_choice(e, option_id, sim)
	var g: CustomerGroup = e
	if option_id in ["acomodar", "pedido", "servir", "cobrar"]:
		sim.order_manager_task({ "tipo": option_id, "grupo": g })
		match option_id:
			"acomodar":
				return "¡Estupendo, gracias!"
			"pedido":
				return "Perfecto, ahora le decimos."
			"servir":
				return "¡Gracias, tenemos hambre!"
		return "Muy bien, gracias."
	var first_time := not g.talked.has(option_id)
	g.talked[option_id] = true
	match option_id:
		"que_tal":
			if first_time:
				# A un habitual le alegra mucho que el jefe le salude.
				g.mood_bonus += CHAT_MOOD * (3.0 if g.regular_name != "" else 1.0)
				if g.regular_name != "":
					g.talked["saludo"] = true
					return "¡Siempre da gusto venir aquí, jefe!"
			if g.state == CustomerGroup.State.COMIENDO or g.state == CustomerGroup.State.ESPERANDO_CUENTA:
				return _food_opinion(g, sim, target["member"])
			var mood := g.mood()
			if mood > 0.7:
				return "Muy bien, el sitio es agradable. Gracias por preguntar."
			return "Bueno… la espera se está haciendo larga." if mood > 0.4 else "Mal. Estamos pensando en irnos."
		"disculpa":
			g.mood_bonus += APOLOGY_MOOD
			g.patience_bonus += APOLOGY_PATIENCE
			return "Bueno, se agradece. Esperaremos un poco más."
		"invitar":
			g.mood_bonus += TREAT_MOOD
			g.comp_value += TREAT_COST
			sim.finances.spend("invitaciones", TREAT_COST)
			sim.day_stats["invitaciones"] += TREAT_COST
			return "¡Vaya, qué detalle! Muchas gracias."
		"tarta":
			g.mood_bonus += 0.4
			sim.finances.spend("invitaciones", RestaurantSim.CAKE_COST)
			sim.day_stats["invitaciones"] += RestaurantSim.CAKE_COST
			return "¡Qué ilusión! ¡Muchísimas gracias!"
		"compensar":
			# Un cliente que se iba enfadado no se va tan mal: la reputación sufre menos.
			sim.reputation = minf(1.0, sim.reputation + 0.01)
			sim.finances.spend("invitaciones", TREAT_COST)
			sim.day_stats["invitaciones"] += TREAT_COST
			return "Bueno… le tomo la palabra. Quizá volvamos."
		"mejorar":
			if first_time:
				g.mood_bonus += CHAT_MOOD
			return worst_aspect(g, sim)
		"precios":
			return "La carta parece %s." % _price_word(sim)
		"adios":
			return "¡Gracias!" if g.mood() > 0.4 else "Ya…"
	return ""


static func _staff_choice(s: StaffMember, option_id: String, sim: RestaurantSim) -> String:
	match option_id:
		"trabajo":
			return _work_report(s, sim)
		"como_estas":
			var line := "Estoy %s, jefe." % s.moral_word()
			if s.moral < 40.0:
				line += " Llevamos un ritmo muy duro."
			elif sim.minutes < s.rushed_until:
				line += " Voy a tope, como me pidió."
			return line
		"felicitar":
			# Felicitar seguido pierde efecto: cuenta entero si ha pasado al menos una hora.
			var gain := PRAISE_MORAL if sim.minutes - s.last_praise >= 60.0 else PRAISE_MORAL * 0.2
			s.moral = minf(100.0, s.moral + gain)
			s.last_praise = sim.minutes
			return "¡Gracias, jefe! Así da gusto." if gain >= PRAISE_MORAL else "Gracias… ya me lo había dicho."
		"prisa":
			s.rushed_until = sim.minutes + RUSH_MINUTES
			s.moral = maxf(0.0, s.moral - RUSH_MORAL)
			return "Vale, vale… voy más rápido." if s.moral >= 40.0 else "¡Más rápido no puedo, jefe!"
		"adios":
			return "¡A mandar!"
	return ""


## Lo peor de la experiencia del cliente hasta ahora, dicho por él.
static func worst_aspect(g: CustomerGroup, sim: RestaurantSim) -> String:
	var aspects := {}
	if g.dishes_ready > 0:
		aspects["comida"] = g.food_quality_sum / float(g.dishes_ready)
	var current := 0.0
	if CustomerGroup.PATIENCE.has(g.state):
		current = maxf(0.0, g.state_time - g.patience_limit()) / g.patience_limit()
	aspects["tiempo"] = clampf(100.0 - (g.wait_penalty + current) * 50.0, 0.0, 100.0)
	if not g.service_scores.is_empty():
		var service := 0.0
		for v in g.service_scores:
			service += v
		aspects["trato"] = service / g.service_scores.size()
	aspects["ambiente"] = sim.layout.ambiente
	aspects["limpieza"] = sim.cleanliness()
	if not g.dishes.is_empty():
		aspects["precio"] = Satisfaction.value_for_money(g.bill, g.fair_bill)
	var worst := "tiempo"
	for k in aspects:
		if aspects[k] < aspects[worst]:
			worst = k
	if aspects[worst] >= 75.0:
		return "Sinceramente, nada. Está todo muy bien."
	match worst:
		"comida":
			return "La comida podría estar mejor hecha."
		"tiempo":
			return "Las esperas. Se tarda mucho en todo."
		"trato":
			return "El servicio, la verdad, un poco seco."
		"ambiente":
			return "El local es algo soso. Le falta ambiente."
		"limpieza":
			return "La limpieza deja que desear."
		"precio":
			return "Para lo que es, es caro."
	return "Nada en especial."


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
