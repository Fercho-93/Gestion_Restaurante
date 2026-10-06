class_name PersonSheet
extends RefCounted
## La "ficha" de una persona al estilo de los Sims: lo que necesita ahora mismo (barras),
## cómo es (perfil y rasgos), qué le gusta y qué recuerda del restaurante.
## Lógica pura: devuelve un diccionario que la interfaz solo tiene que dibujar.
##   { perfil, resumen, necesidades: [[nombre, 0-1, detalle]], rasgos: [[nombre, descripción]],
##     gustos: [nombres], opinion: texto, recuerdos: [frases] }


static func build(target: Dictionary, sim: RestaurantSim) -> Dictionary:
	var e = target.get("entity")
	if e is Manager:
		return _manager(e)
	if e is StaffMember:
		return _staff(e)
	if e is CustomerGroup:
		return _customer(e, target.get("member", 0), sim)
	return {}


static func _manager(m: Manager) -> Dictionary:
	return {
		"perfil": "Gestor del restaurante",
		"resumen": "Gestor · Eres tú. Puedes atender, limpiar, hablar con la gente y gestionar desde el ordenador.",
		"necesidades": [
			["Energía", m.energy / 100.0, "Un café la recupera" if m.energy < 60.0 else "Con fuerzas"],
			["Trato", m.effective_trato() / 100.0, "Cansado, atiende peor" if m.exhausted() else "Atiende con buena cara"],
		],
		"rasgos": [], "gustos": [], "opinion": "", "recuerdos": [],
	}


static func _staff(s: StaffMember) -> Dictionary:
	var role := "Camarero/a" if s.puesto == StaffMember.ROLE_WAITER else "Cocinero/a"
	return {
		"perfil": role,
		"resumen": "%s · %s · Sueldo %d €/día" % [role, s.describe_task(), int(s.salario_dia)],
		"necesidades": [
			["Ánimo", s.moral / 100.0, s.moral_word().capitalize()],
			["Rapidez", s.velocidad / 100.0, ""],
			["Trato", s.trato / 100.0, ""],
			["Habilidad", s.habilidad / 100.0, ""],
		],
		"rasgos": [], "gustos": [], "opinion": "", "recuerdos": [],
	}


static func _customer(g: CustomerGroup, member: int, sim: RestaurantSim) -> Dictionary:
	var needs := [
		["Ánimo", g.mood(), _mood_detail(g.mood())],
		["Paciencia", _patience(g), _patience_detail(g)],
		["Hambre", _hunger(g), _hunger_detail(g)],
		["Entorno", _surroundings(g, sim), _surroundings_detail(g, sim)],
	]
	if member == g.child_member:
		return {
			"perfil": "Niño/a",
			"resumen": "Niño/a · Viene con su familia. Si la comida tarda, se aburre y se levanta a jugar.",
			"necesidades": needs, "rasgos": [], "gustos": [], "opinion": "", "recuerdos": [],
		}
	var who := g.person(member)
	if who == null:
		return {
			"perfil": "Cliente",
			"resumen": "Cliente de paso · grupo de %d" % g.size,
			"necesidades": needs, "rasgos": [], "gustos": [], "opinion": "", "recuerdos": [],
		}
	var traits := []
	for t in who.traits:
		traits.append([t["nombre"], t["descripcion"]])
	var likes := []
	for recipe_id in who.favorites:
		if sim.recipes.has(recipe_id):
			likes.append(sim.recipes[recipe_id]["nombre"])
	var visits := "Primera vez aquí" if who.visits == 0 else "Ha venido %d %s" % [who.visits, "vez" if who.visits == 1 else "veces"]
	return {
		"perfil": who.profile["nombre"],
		"resumen": "%s · Suele gastar unos %d € · %s" % [who.nombre, roundi(who.budget), visits],
		"necesidades": needs,
		"rasgos": traits,
		"gustos": likes,
		"opinion": _opinion_text(who),
		"recuerdos": who.memories.slice(0, 2),
	}


## Paciencia que le queda en la espera actual (1 = toda; 0 = a punto de irse).
static func _patience(g: CustomerGroup) -> float:
	if not CustomerGroup.PATIENCE.has(g.state):
		return 1.0
	return clampf(1.0 - g.state_time / (2.0 * g.patience_limit()), 0.0, 1.0)


static func _patience_detail(g: CustomerGroup) -> String:
	if not CustomerGroup.PATIENCE.has(g.state):
		return "No está esperando"
	var p := _patience(g)
	if p > 0.6:
		return "Espera tranquilo"
	return "Se le acaba la paciencia" if p > 0.3 else "¡A punto de irse!"


## Lo que le queda de hambre (barra llena = saciado, como en los Sims).
static func _hunger(g: CustomerGroup) -> float:
	match g.state:
		CustomerGroup.State.COMIENDO:
			var total := maxf(1.0, g.eat_time_left + g.state_time)
			return lerpf(0.3, 1.0, clampf(g.state_time / total, 0.0, 1.0))
		CustomerGroup.State.ESPERANDO_CUENTA, CustomerGroup.State.SALIENDO, CustomerGroup.State.FUERA:
			return 1.0 if not g.dishes.is_empty() else 0.25
	return clampf(0.3 - g.state_time / 120.0, 0.1, 0.3)


static func _hunger_detail(g: CustomerGroup) -> String:
	match g.state:
		CustomerGroup.State.COMIENDO:
			return "Comiendo"
		CustomerGroup.State.ESPERANDO_CUENTA, CustomerGroup.State.SALIENDO:
			return "Satisfecho" if not g.dishes.is_empty() else "Se va con hambre"
	return "Tiene hambre"


## Cómo percibe el local (ambiente y limpieza, según lo que le importe a cada uno).
static func _surroundings(g: CustomerGroup, sim: RestaurantSim) -> float:
	var ambience := 50.0 + (sim.layout.ambiente - 50.0) * g.factor("valor_ambiente")
	var clean := 100.0 - (100.0 - sim.cleanliness()) * g.factor("limpieza")
	return clampf((ambience + clean) / 200.0, 0.0, 1.0)


static func _surroundings_detail(g: CustomerGroup, sim: RestaurantSim) -> String:
	var clean := 100.0 - (100.0 - sim.cleanliness()) * g.factor("limpieza")
	if clean < 55.0:
		return "Le molesta la suciedad"
	if g.complained or g.has_trait("ruidoso"):
		return "Mucho ruido"
	return "Se está a gusto" if _surroundings(g, sim) > 0.6 else "El local no le dice mucho"


static func _mood_detail(mood: float) -> String:
	if mood >= 0.85:
		return "Encantado"
	if mood >= 0.65:
		return "Contento"
	return "Impaciente" if mood >= 0.4 else "Enfadado"


static func _opinion_text(who: Neighbor) -> String:
	if who.visits == 0:
		return "Aún no conoce el sitio"
	if who.is_regular():
		return "Cliente habitual: le encanta el sitio"
	if who.opinion >= 0.65:
		return "Le gusta el sitio"
	if who.opinion >= 0.45:
		return "No tiene una opinión clara"
	return "No le convence el sitio"
