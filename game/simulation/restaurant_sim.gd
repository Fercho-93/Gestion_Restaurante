class_name RestaurantSim
extends RefCounted
## Simulación del restaurante: clientes, sala, cocina, inventario y caja.
## Lógica pura: no dibuja nada. Las escenas leen su estado y escuchan sus señales.

signal day_closed(report: Dictionary)
signal group_left(group: CustomerGroup)
## El gestor ha llegado a un objeto y empieza a usarlo (p. ej. "ordenador").
signal manager_started_using(object_id: String)
## El gestor ha llegado junto a alguien y empieza a hablar: {entity, member}.
signal manager_started_talking(target: Dictionary)
## Algo que merece un aviso en pantalla (un plato que se cae, un crítico...).
signal announcement(text: String, cell: Vector2i)

const MINUTES_PER_DAY := 24 * 60
## Hora a la que llega el pedido diario de materia prima.
const RESTOCK_HOUR := 11
## Duración (minutos, a velocidad normal) de cada acción del camarero.
const WAITER_ACTION_TIME := { "pedido": 1.5, "servir": 0.5, "cobrar": 1.5, "recoger": 0.5,
	"acomodar": 0.3, "limpiar_mesa": 1.0, "fregar": 1.5 }
## Tareas de sala y su prioridad (menor = antes).
const WAITER_PRIORITY := { "servir": 0, "cobrar": 1, "acomodar": 2, "pedido": 3,
	"recoger_mesa": 4, "fregar": 5 }
const CLEANING_TASKS := ["recoger_mesa", "fregar"]
## Manchas en el suelo como mucho (y cuánto restan a la limpieza cada una).
const MAX_STAINS := 12
const REGULAR_NAMES := ["Don Ramón", "Doña Encarna", "Pepe el del quiosco", "Sofía", "Tomás", "Luisa"]
## Lo que cuesta la tarta de cumpleaños que invita la casa.
const CAKE_COST := 6.0
## Energía del gestor: lo que gasta por minuto según lo que hace, y lo que da un café.
const ENERGY_DRAIN := { "base": 0.05, "andando": 0.05, "trabajando": 0.09 }
const COFFEE_MINUTES := 2.0
const COFFEE_ENERGY := 35.0
## Tráfico: si alguien no puede avanzar, cada tanto busca otro camino; si sigue
## atascado, se aparta a un lado; y como último recurso pasa igualmente.
const REPLAN_EVERY := 0.5
const SIDESTEP_AFTER := 1.5
const GHOST_AFTER := 4.0

var layout: RestaurantLayout
var recipes: Dictionary
var ingredients: Dictionary
## receta_id -> precio de venta
var menu: Dictionary = {}
var staff: Array[StaffMember] = []
var manager: Manager
var groups: Array[CustomerGroup] = []
## Platos pendientes de empezar: [{grupo, receta}]
var kitchen_queue: Array[Dictionary] = []
var inventory := Inventory.new()
var finances: Finances
var demand: Demand
## Reputación de 0 a 1. Hace que venga más o menos gente.
var reputation := 0.5
var opening_hour: int
var last_entry_hour: int
var fixed_costs: Dictionary
var stock_targets: Dictionary
var rng := RandomNumberGenerator.new()
## Reloj absoluto en minutos de juego.
var minutes := 0.0
var day_stats: Dictionary = {}
## Manchas en el suelo: celda -> quien la está limpiando (o null).
var stains: Dictionary = {}
## Veces que alguien ha tenido que "atravesar" a otro por un atasco imposible.
var forced_passes := 0
var _next_group_id := 1


## data: {ingredients, recipes, start, demand} tal y como los carga GameData.
func _init(data: Dictionary, start_minutes: float, random_seed: int = -1) -> void:
	if random_seed >= 0:
		rng.seed = random_seed
	else:
		rng.randomize()
	ingredients = data["ingredients"]
	recipes = data["recipes"]
	var start: Dictionary = data["start"]
	layout = RestaurantLayout.new(start["local"])
	demand = Demand.new(data["demand"])
	finances = Finances.new(float(start["dinero_inicial"]))
	opening_hour = int(start["hora_apertura"])
	last_entry_hour = int(start["ultima_entrada"])
	fixed_costs = start["costes_fijos_dia"]
	stock_targets = start["stock_objetivo"]
	for item in start["carta"]:
		menu[item["receta"]] = float(item["precio"])
	var waiter_count := 0
	var cook_count := 0
	for d in start["personal"]:
		var cell: Vector2i
		if d["puesto"] == StaffMember.ROLE_COOK:
			cell = layout.cook_stations[cook_count % layout.cook_stations.size()]
			cook_count += 1
		else:
			cell = layout.waiter_homes[waiter_count % layout.waiter_homes.size()]
			waiter_count += 1
		staff.append(StaffMember.new(d, staff.size() + 1, cell))
	manager = Manager.new(layout.manager_home)
	minutes = start_minutes
	_reset_day_stats()
	_restock()


func update(dt: float) -> void:
	var previous := minutes
	minutes += dt
	if _crossed(previous, minutes, RESTOCK_HOUR * 60):
		_restock()
	_spawn_customers(dt)
	_update_groups(dt)
	_update_waiters(dt)
	_update_cooks(dt)
	_update_staff_mood(dt)
	_update_manager(dt)
	groups = groups.filter(func(g: CustomerGroup): return g.state != CustomerGroup.State.FUERA)
	if _crossed(previous, minutes, 0):
		_close_day()


func hour() -> int:
	return (int(minutes) % MINUTES_PER_DAY) / 60


func is_open_for_new_customers() -> bool:
	return hour() >= opening_hour and hour() < last_entry_hour


func waiters() -> Array[StaffMember]:
	return staff.filter(func(s: StaffMember): return s.puesto == StaffMember.ROLE_WAITER)


func cooks() -> Array[StaffMember]:
	return staff.filter(func(s: StaffMember): return s.puesto == StaffMember.ROLE_COOK)


func customers_inside() -> int:
	var n := 0
	for g in groups:
		if g.state != CustomerGroup.State.SALIENDO:
			n += g.size
	return n


func average_stars() -> float:
	return 1.0 + reputation * 4.0


## Quien está parado sin hacer nada en `cell` se aparta a una casilla libre de al lado
## que no esté en el camino de `requester`.
func _ask_to_move_aside(cell: Vector2i, requester_key: String, requester: Mover) -> void:
	for a in agents():
		var other: Mover = a[0]
		if a[1] == requester_key or other.last_cell != cell or not other.arrived() or not _is_idle(a[1]):
			continue
		var in_the_way := requester.path.slice(0, 4)
		in_the_way.append(requester.last_cell)
		var sides: Array[Vector2i] = [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1),
				Vector2i(1, 1), Vector2i(-1, 1), Vector2i(1, -1), Vector2i(-1, -1)]
		for d in sides:
			var c := cell + d
			if layout.can_stand(c) and not in_the_way.has(c) and cell_free_for(c, a[1]) \
					and not layout.find_path(cell, c).is_empty() and layout.find_path(cell, c).size() == 2:
				other.go_to(layout, c)
				return
		return


## ¿Está esa persona parada sin nada que hacer (y por tanto puede apartarse)?
func _is_idle(key: String) -> bool:
	if key == "m":
		return manager.state == Manager.State.LIBRE
	if key.begins_with("s"):
		for s in staff:
			if "s%d" % s.id == key:
				return s.puesto == StaffMember.ROLE_WAITER and s.task.is_empty() and not s.talking
	return false


# --- Gestor -----------------------------------------------------------------

func order_manager_walk(cell: Vector2i) -> void:
	_end_talk()
	_stop_manager_work()
	manager.walk_to(layout, cell, cells_taken_by_others("m"))


func order_manager_use(object_id: String) -> void:
	_end_talk()
	_stop_manager_work()
	manager.go_use(layout, object_id, cells_taken_by_others("m"))


## Ir a hablar con alguien: entity es un CustomerGroup (con el índice del miembro) o un
## StaffMember.
func order_manager_talk(entity, member: int = 0) -> void:
	_end_talk()
	_stop_manager_work()
	var target := { "entity": entity, "member": member }
	var cell = person_cell(target)
	if cell != null:
		manager.go_talk(layout, target, cell, cells_taken_by_others("m"))


## El gestor deja lo que estaba haciendo (levantarse, terminar la conversación).
func stop_manager() -> void:
	_end_talk()
	manager.stop()


## El gestor hace él mismo una tarea de sala: {tipo, grupo|mesa|celda}.
func order_manager_task(task: Dictionary) -> void:
	if manager.exhausted():
		announcement.emit("Estás demasiado cansado para trabajar: tómate un café", manager.mover.last_cell)
		return
	_end_talk()
	_stop_manager_work()
	manager.stop()
	start_task(manager, task)
	manager.state = Manager.State.TRABAJANDO


## Trabajo continuo del gestor: "sala" (atender mesas), "limpieza" o "" (dejarlo).
func set_manager_covering(mode: String) -> void:
	if mode != "" and manager.exhausted():
		announcement.emit("Estás demasiado cansado para trabajar: tómate un café", manager.mover.last_cell)
		return
	_end_talk()
	_stop_manager_work()
	manager.stop()
	manager.covering = mode


func order_manager_clean_table(table: RestaurantLayout.Table) -> void:
	if table.dirty and table.cleaner == null:
		order_manager_task({ "tipo": "recoger_mesa", "mesa": table })


func order_manager_mop(cell: Vector2i) -> void:
	if stains.has(cell) and stains[cell] == null:
		order_manager_task({ "tipo": "fregar", "celda": cell })


func _stop_manager_work() -> void:
	if not manager.task.is_empty():
		_end_waiter_task(manager)
	manager.covering = ""


## Celda donde está una persona ({entity, member}), o null si ya no está en el local.
func person_cell(target: Dictionary):
	var e = target["entity"]
	if e is StaffMember:
		return e.mover.last_cell if staff.has(e) else null
	if e is CustomerGroup:
		if not groups.has(e) or e.state == CustomerGroup.State.FUERA:
			return null
		return e.members[target["member"]].last_cell
	return null


# --- Tráfico: nadie atraviesa a nadie ---------------------------------------------

## Todas las personas que se mueven por el local: [mover, clave]. Los miembros de un
## mismo grupo comparten clave y pueden ir juntos.
func agents() -> Array:
	var list := [[manager.mover, "m"]]
	for s in staff:
		list.append([s.mover, "s%d" % s.id])
	for g in groups:
		for m in g.members:
			list.append([m, "g%d" % g.id])
	return list


## Casillas ocupadas (o reservadas al ir de camino) por todos menos `key`.
func cells_taken_by_others(key: String) -> Array[Vector2i]:
	var cells: Array[Vector2i] = []
	for a in agents():
		if a[1] != key:
			cells.append_array(a[0].occupied_cells())
	return cells


## ¿Puede `key` entrar en la casilla? La entrada/salida de la calle no cuenta.
## `swap_from`: si se indica, se permite cruzarse con quien quiere ir justo a esa casilla
## (dos personas que se encuentran de frente se intercambian el sitio).
func cell_free_for(cell: Vector2i, key: String, swap_from: Variant = null) -> bool:
	if cell == layout.spawn_cell:
		return true
	for a in agents():
		if a[1] == key:
			continue
		var other: Mover = a[0]
		if not other.occupied_cells().has(cell):
			continue
		if swap_from != null and other.is_moving() and other.last_cell == cell and other.path[0] == swap_from:
			continue
		return false
	return true


## ¿Cortaría el paso en diagonal de `from` a `to` al de alguien que hace la diagonal
## contraria? (no pisarían la misma casilla, pero se atravesarían por el medio)
func crosses_diagonal(from: Vector2i, to: Vector2i, key: String) -> bool:
	var d := to - from
	if d.x == 0 or d.y == 0:
		return false
	var corner_a := from + Vector2i(d.x, 0)
	var corner_b := from + Vector2i(0, d.y)
	for a in agents():
		if a[1] == key:
			continue
		var other: Mover = a[0]
		if other.is_moving() and not other.at_center():
			if (other.last_cell == corner_a and other.path[0] == corner_b) or (other.last_cell == corner_b and other.path[0] == corner_a):
				return true
	return false


## Hace caminar a alguien respetando a los demás y resolviendo atascos.
func _walk(m: Mover, key: String, dt: float) -> void:
	if m.arrived():
		m.wait_time = 0.0
		return
	var before := m.pos
	if m.is_moving():
		m.step(dt, func(c: Vector2i) -> bool:
			return cell_free_for(c, key, m.last_cell if m.ghost else null) and not crosses_diagonal(m.last_cell, c, key))
	if m.pos != before:
		m.wait_time = 0.0
		return
	var previous := m.wait_time
	m.wait_time += dt
	# Quien esté parado sin hacer nada en medio se aparta en cuanto alguien quiere pasar.
	if m.blocked:
		_ask_to_move_aside(m.path[0], key, m)
	if floori(m.wait_time / REPLAN_EVERY) != floori(previous / REPLAN_EVERY):
		_unblock(m, key)


func _unblock(m: Mover, key: String) -> void:
	var others := cells_taken_by_others(key)
	var goal := m.goal
	# Si alguien está parado justo en su destino (y no es una silla), vale la de al lado.
	if others.has(goal) and goal != layout.spawn_cell and not layout.is_sittable(goal):
		goal = layout.nearest_free_cell(goal, m.last_cell, others)
	if m.wait_time >= GHOST_AFTER and not m.ghost:
		if m.path.is_empty():
			m.go_to(layout, goal)
		m.ghost = true
		forced_passes += 1
		return
	if m.try_go_to(layout, goal, others) and (m.path.is_empty() or cell_free_for(m.path[0], key)):
		return
	if m.path.is_empty():
		m.go_to(layout, goal)
	# Si quien le corta el paso está parado sin hacer nada, le pide que se aparte.
	if not m.path.is_empty():
		_ask_to_move_aside(m.path[0], key, m)
	if m.wait_time >= SIDESTEP_AFTER and m.at_center():
		# Atasco cara a cara: se aparta a una casilla libre de al lado.
		var sides: Array[Vector2i] = [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]
		sides.shuffle()
		for d in sides:
			var c := m.last_cell + d
			if layout.can_stand(c) and cell_free_for(c, key) and not others.has(c):
				m.path.clear()
				m.path.append(c)
				return


## Cansancio del gestor: se gasta energía, el café la recupera y agotado no puede trabajar.
func _update_manager_energy(dt: float) -> void:
	var m := manager
	var drain: float = ENERGY_DRAIN["base"]
	if m.state == Manager.State.TRABAJANDO:
		drain += ENERGY_DRAIN["trabajando"]
	elif m.mover.is_moving():
		drain += ENERGY_DRAIN["andando"]
	if m.state == Manager.State.USANDO and m.using == "cafetera":
		drain = 0.0
		m.coffee_left -= dt
		if m.coffee_left <= 0.0:
			m.energy = minf(100.0, m.energy + COFFEE_ENERGY)
			m.stop()
	var was_ok := not m.exhausted()
	m.energy = maxf(0.0, m.energy - drain * dt)
	m.mover.speed = Mover.BASE_SPEED * m.speed_factor()
	if was_ok and m.exhausted():
		_stop_manager_work()
		if m.state == Manager.State.TRABAJANDO:
			m.state = Manager.State.LIBRE
		announcement.emit("Estás agotado: tómate un café para recuperarte", m.mover.last_cell)


func _update_manager(dt: float) -> void:
	_update_manager_energy(dt)
	# Trabajando en sala (una tarea suelta o atendiendo/limpiando de continuo).
	if manager.state == Manager.State.TRABAJANDO or (manager.state == Manager.State.LIBRE and manager.covering != ""):
		_walk(manager.mover, "m", dt)
		if manager.task.is_empty() and manager.covering != "":
			var allowed: Array = CLEANING_TASKS if manager.covering == "limpieza" else ["servir", "cobrar", "acomodar", "pedido"]
			manager.state = Manager.State.TRABAJANDO if _assign_waiter_task(manager, allowed) else Manager.State.LIBRE
		elif not manager.task.is_empty():
			_progress_waiter_task(manager, dt)
		if manager.task.is_empty() and manager.state == Manager.State.TRABAJANDO and manager.covering == "":
			manager.state = Manager.State.LIBRE
		return
	# Si le han pedido paso estando libre, se aparta.
	if manager.state == Manager.State.LIBRE and manager.mover.is_moving():
		_walk(manager.mover, "m", dt)
		return
	var target: Dictionary = manager.talk_target
	if manager.state == Manager.State.HABLANDO:
		target = manager.talking_to
		if person_cell(target) == null:
			stop_manager()
			manager.notice = "Se ha ido"
			return
	var can_enter := func(c: Vector2i) -> bool:
		return cell_free_for(c, "m") and not crosses_diagonal(manager.mover.last_cell, c, "m")
	var event := manager.step(dt, layout, cells_taken_by_others("m"), can_enter,
			person_cell(target) if not target.is_empty() else null)
	if event.has("usar"):
		if event["usar"] == "cafetera":
			manager.coffee_left = COFFEE_MINUTES
		manager_started_using.emit(event["usar"])
	elif event.has("hablar"):
		var who = event["hablar"]["entity"]
		if who is StaffMember:
			who.talking = true
		manager_started_talking.emit(event["hablar"])


func _end_talk() -> void:
	var who = manager.talking_to.get("entity")
	if who is StaffMember:
		who.talking = false


# --- Clientes ---------------------------------------------------------------

func _spawn_customers(dt: float) -> void:
	if not is_open_for_new_customers():
		return
	var multiplier := 0.5 + reputation
	for i in demand.arrivals(hour(), dt, multiplier, rng):
		var g := CustomerGroup.new()
		g.id = _next_group_id
		_next_group_id += 1
		g.size = demand.random_size(rng)
		g.patience_factor = rng.randf_range(0.7, 1.3)
		for m in g.size:
			var member := Mover.new(layout.spawn_cell, Mover.BASE_SPEED * rng.randf_range(0.8, 1.0))
			member.jitter = Vector2(rng.randf_range(-0.25, 0.25), rng.randf_range(-0.25, 0.25))
			g.members.append(member)
		_give_personality(g)
		groups.append(g)


## Algunos grupos son especiales: habituales, críticos, cumpleaños, familias con niños.
func _give_personality(g: CustomerGroup) -> void:
	if g.size >= 3 and rng.randf() < 0.45:
		g.child_member = g.size - 1
	if g.size >= 3 and rng.randf() < 0.08:
		g.birthday = true
	if g.size == 1 and rng.randf() < 0.06:
		g.is_critic = true
	elif reputation > 0.45 and rng.randf() < 0.12:
		g.regular_name = REGULAR_NAMES[rng.randi() % REGULAR_NAMES.size()]
		g.mood_bonus += 0.1
		announcement.emit("Ha llegado %s, cliente habitual" % g.regular_name, layout.spawn_cell)


func _update_groups(dt: float) -> void:
	_update_queue_positions()
	for g in groups:
		g.state_time += dt
		for m in g.members:
			_walk(m, "g%d" % g.id, dt)
		match g.state:
			CustomerGroup.State.LLEGANDO:
				if g.all_arrived():
					g.set_state(CustomerGroup.State.EN_COLA)
			CustomerGroup.State.EN_COLA:
				pass  # Esperan a que alguien les acompañe a una mesa.
			CustomerGroup.State.YENDO_A_MESA:
				if g.all_arrived():
					g.set_state(CustomerGroup.State.ESPERANDO_PEDIR)
			CustomerGroup.State.COMIENDO:
				g.eat_time_left -= dt
				if g.eat_time_left <= 0.0:
					g.set_state(CustomerGroup.State.ESPERANDO_CUENTA)
			CustomerGroup.State.SALIENDO:
				if g.all_arrived():
					g.set_state(CustomerGroup.State.FUERA)
		if g.is_fed_up():
			_leave_angry(g, _fed_up_reason(g))


## Un niño que se aburre esperando la comida se levanta a corretear y luego vuelve.
func _update_child(g: CustomerGroup, dt: float) -> void:
	if g.child_member < 0 or g.table == null:
		return
	var kid := g.members[g.child_member]
	var seat := g.table.seats[g.child_member]
	var waiting_food := g.state == CustomerGroup.State.ESPERANDO_COMIDA
	match g.child_state:
		"":
			if waiting_food and kid.arrived() and kid.last_cell == seat:
				g.child_timer += dt
				if g.child_timer > 6.0 and rng.randf() < dt * 0.15:
					var spot := _random_free_cell_near(g.table.cell, 3)
					if spot != Vector2i(-999, -999):
						kid.go_to(layout, spot)
						g.child_state = "jugando"
						g.child_timer = 0.0
		"jugando":
			g.child_timer += dt
			if not waiting_food or (kid.arrived() and g.child_timer > 2.5):
				kid.go_to(layout, seat)
				g.child_state = "volviendo"
		"volviendo":
			if kid.arrived() and kid.last_cell == seat:
				g.child_state = ""
				g.child_timer = 0.0


func _random_free_cell_near(center: Vector2i, radius: int) -> Vector2i:
	var options: Array[Vector2i] = []
	var taken := cells_taken_by_others("")
	for dx in range(-radius, radius + 1):
		for dy in range(-radius, radius + 1):
			var c := center + Vector2i(dx, dy)
			if c.x >= 0 and layout.can_stand(c) and not taken.has(c) and not stains.has(c):
				options.append(c)
	return options[rng.randi() % options.size()] if not options.is_empty() else Vector2i(-999, -999)


## Un grupo muy enfadado se queja en voz alta y molesta a las mesas de al lado.
func _maybe_complain(g: CustomerGroup) -> void:
	if g.complained or g.table == null or not CustomerGroup.PATIENCE.has(g.state):
		return
	# Se quejan cuando la espera pasa de vez y media su paciencia (poco antes de irse).
	if g.state_time < 1.5 * g.patience_limit() and g.mood() > 0.3:
		return
	g.complained = true
	g.shout_until = minutes + 4.0
	for other in groups:
		if other != g and other.table != null and Vector2(other.table.cell).distance_to(Vector2(g.table.cell)) <= 3.5:
			other.mood_bonus -= 0.04


## Los grupos que esperan mesa forman cola en la calle, en orden de llegada.
func _update_queue_positions() -> void:
	var index := 0
	for g in groups:
		if g.state != CustomerGroup.State.LLEGANDO and g.state != CustomerGroup.State.EN_COLA:
			continue
		var target := layout.queue_cells[mini(index, layout.queue_cells.size() - 1)]
		index += 1
		if g.queue_cell != target:
			g.queue_cell = target
			for m in g.members:
				m.go_to(layout, target)


## Mesa libre, limpia y del tamaño justo para el grupo (o null si no hay).
func free_table_for(g: CustomerGroup) -> RestaurantLayout.Table:
	var best: RestaurantLayout.Table = null
	for table in layout.tables:
		if table.group == null and not table.dirty and table.capacity() >= g.size:
			if best == null or table.capacity() < best.capacity():
				best = table
	return best


## El primer grupo de la cola (el que lleva más esperando).
func first_in_queue() -> CustomerGroup:
	for g in groups:
		if g.state == CustomerGroup.State.EN_COLA:
			return g
	return null


## Lleva al grupo a su mesa (ya reservada en g.table).
func _seat(g: CustomerGroup) -> void:
	if g.birthday:
		announcement.emit("¡Hay un cumpleaños en una mesa!", g.table.cell)
	for i in g.members.size():
		g.members[i].go_to(layout, g.table.seats[i])
	g.set_state(CustomerGroup.State.YENDO_A_MESA)


## Limpieza que perciben los clientes: baja con las manchas y las mesas sin recoger.
func cleanliness() -> float:
	var dirty_tables := 0
	for t in layout.tables:
		if t.dirty:
			dirty_tables += 1
	return clampf(layout.limpieza + 20.0 - 7.0 * stains.size() - 5.0 * dirty_tables, 0.0, 100.0)


func _add_stain_near(cell: Vector2i) -> void:
	if stains.size() >= MAX_STAINS:
		return
	var options: Array[Vector2i] = []
	for dx in range(-2, 3):
		for dy in range(-2, 3):
			var c := cell + Vector2i(dx, dy)
			if c.x >= 0 and layout.can_stand(c) and not stains.has(c):
				options.append(c)
	if not options.is_empty():
		stains[options[rng.randi() % options.size()]] = null


func _fed_up_reason(g: CustomerGroup) -> String:
	match g.state:
		CustomerGroup.State.EN_COLA: return "No había mesa"
		CustomerGroup.State.ESPERANDO_PEDIR: return "Nadie les tomó nota"
		CustomerGroup.State.ESPERANDO_COMIDA: return "La comida tardó demasiado"
		CustomerGroup.State.ESPERANDO_CUENTA: return "Se fueron sin pagar"
	return "Se cansaron de esperar"


func _leave_angry(g: CustomerGroup, reason: String) -> void:
	g.left_angry = true
	g.leave_reason = reason
	g.satisfaction = rng.randf_range(5.0, 15.0)
	day_stats["grupos_perdidos"] += 1
	day_stats["motivos_perdida"][reason] = day_stats["motivos_perdida"].get(reason, 0) + 1
	_update_reputation(g.satisfaction)
	_leave(g)


func _leave(g: CustomerGroup) -> void:
	if g.table != null:
		# Si han llegado a comer, dejan la mesa con platos sucios (y a veces alguna mancha).
		if not g.dishes.is_empty():
			g.table.dirty = true
			if rng.randf() < 0.25:
				_add_stain_near(g.table.cell)
		g.table.group = null
		g.table = null
	kitchen_queue = kitchen_queue.filter(func(t: Dictionary): return t["grupo"] != g)
	g.set_state(CustomerGroup.State.SALIENDO)
	for m in g.members:
		m.go_to(layout, layout.spawn_cell)
	group_left.emit(g)


func _update_reputation(satisfaction: float) -> void:
	reputation = clampf(reputation + (satisfaction / 100.0 - reputation) * 0.03, 0.0, 1.0)


# --- Camareros (y el gestor cuando echa una mano) ---------------------------------

func _update_waiters(dt: float) -> void:
	for w in waiters():
		if w.talking:
			continue
		_walk(w.mover, "s%d" % w.id, dt)
		if w.task.is_empty():
			_assign_waiter_task(w)
		else:
			_preempt_cleaning(w)
		if w.task.is_empty():
			# Vuelve a su sitio, si no se lo ha ocupado nadie.
			if w.mover.arrived() and w.mover.last_cell != w.home and cell_free_for(w.home, "s%d" % w.id):
				w.mover.go_to(layout, w.home)
		else:
			_progress_waiter_task(w, dt)


## Busca la tarea más urgente para `w` (camarero o gestor). `allowed`: si no está vacío,
## solo esas tareas. Devuelve si ha cogido alguna.
func _assign_waiter_task(w, allowed: Array = []) -> bool:
	var best := _find_task(allowed)
	if best.is_empty():
		return false
	start_task(w, best)
	return true


## La tarea pendiente más urgente (sin cogerla todavía), o vacío si no hay.
func _find_task(allowed: Array = []) -> Dictionary:
	var best := {}
	var queue_head := first_in_queue()
	for g in groups:
		if g.waiter != null:
			continue
		var kind := ""
		if g.is_food_ready():
			kind = "servir"
		elif g.state == CustomerGroup.State.ESPERANDO_CUENTA:
			kind = "cobrar"
		elif g.state == CustomerGroup.State.ESPERANDO_PEDIR:
			kind = "pedido"
		elif g.state == CustomerGroup.State.EN_COLA and free_table_for(g) != null:
			kind = "acomodar"
		if kind != "":
			best = _better_task(best, { "tipo": kind, "grupo": g, "edad": g.state_time }, allowed)
	# Si hay gente esperando mesa, recoger las mesas sucias corre prisa.
	var queue_waiting := queue_head != null and free_table_for(queue_head) == null
	for table in layout.tables:
		if table.dirty and table.cleaner == null:
			var cleanup := { "tipo": "recoger_mesa", "mesa": table, "edad": 0.0 }
			if queue_waiting and table.capacity() >= queue_head.size:
				cleanup["prioridad"] = 1.5
			best = _better_task(best, cleanup, allowed)
	for cell in stains:
		if stains[cell] == null:
			best = _better_task(best, { "tipo": "fregar", "celda": cell, "edad": 0.0 }, allowed)
	return best


## Si está limpiando y un cliente necesita algo, lo deja y atiende al cliente.
func _preempt_cleaning(w) -> void:
	if w.task.is_empty() or not CLEANING_TASKS.has(w.task["tipo"]) or w.task.get("prioridad", 9.0) < 2.0:
		return
	if w.task["fase"] == "atender":
		return
	var urgent := _find_task(["servir", "cobrar", "acomodar", "pedido"])
	if not urgent.is_empty():
		_end_waiter_task(w)
		start_task(w, urgent)


func _better_task(current: Dictionary, candidate: Dictionary, allowed: Array) -> Dictionary:
	if not allowed.is_empty() and not allowed.has(candidate["tipo"]):
		return current
	if current.is_empty():
		return candidate
	var a: float = candidate.get("prioridad", WAITER_PRIORITY[candidate["tipo"]])
	var b: float = current.get("prioridad", WAITER_PRIORITY[current["tipo"]])
	if a < b or (a == b and candidate["edad"] > current["edad"]):
		return candidate
	return current


## Empieza una tarea {tipo, grupo|mesa|celda} para un camarero o el gestor.
func start_task(w, task: Dictionary) -> void:
	w.task = task
	w.task["tiempo"] = 0.0
	match task["tipo"]:
		"servir":
			task["grupo"].waiter = w
			task["fase"] = "ir_pase"
			w.mover.go_to(layout, layout.pass_cell)
		"cobrar", "pedido":
			task["grupo"].waiter = w
			task["fase"] = "ir_mesa"
			w.mover.go_to(layout, task["grupo"].table.service_cell)
		"acomodar":
			var g: CustomerGroup = task["grupo"]
			g.waiter = w
			g.table = free_table_for(g)
			g.table.group = g
			task["fase"] = "ir_recepcion"
			w.mover.go_to(layout, layout.reception_cell)
		"recoger_mesa":
			task["mesa"].cleaner = w
			task["fase"] = "ir_mesa"
			w.mover.go_to(layout, task["mesa"].service_cell)
		"fregar":
			stains[task["celda"]] = w
			task["fase"] = "ir_mesa"
			w.mover.go_to(layout, task["celda"])


func _progress_waiter_task(w, dt: float) -> void:
	var g: CustomerGroup = w.task.get("grupo")
	if g != null and (g.state == CustomerGroup.State.SALIENDO or g.state == CustomerGroup.State.FUERA):
		_end_waiter_task(w)
		return
	if w.task["tipo"] == "fregar" and not stains.has(w.task["celda"]):
		_end_waiter_task(w)
		return
	match w.task["fase"]:
		"ir_pase":
			if w.mover.arrived():
				w.task["fase"] = "recoger"
				w.task["tiempo"] = WAITER_ACTION_TIME["recoger"] / w.speed_factor()
		"recoger":
			w.task["tiempo"] -= dt
			if w.task["tiempo"] <= 0.0:
				w.task["fase"] = "ir_mesa"
				w.mover.go_to(layout, g.table.service_cell)
		"ir_recepcion":
			if w.mover.arrived():
				w.task["fase"] = "atender"
				w.task["tiempo"] = WAITER_ACTION_TIME["acomodar"] / w.speed_factor()
		"ir_mesa":
			if w.mover.arrived():
				var action: String = w.task["tipo"]
				if action == "recoger_mesa":
					action = "limpiar_mesa"
				w.task["fase"] = "atender"
				w.task["tiempo"] = WAITER_ACTION_TIME[action] / w.speed_factor()
		"atender":
			w.task["tiempo"] -= dt
			if w.task["tiempo"] <= 0.0:
				_finish_task(w)
		"llevar":
			if w.mover.arrived():
				_end_waiter_task(w)


func _finish_task(w) -> void:
	var g: CustomerGroup = w.task.get("grupo")
	match w.task["tipo"]:
		"pedido":
			g.service_scores.append(w.effective_trato())
			_take_order(g)
		"servir":
			if _drops_plate(w):
				# Se repite el plato: vuelve a la cocina y el suelo queda manchado.
				var who: String = w.nombre if w is StaffMember else "ti"
				announcement.emit("¡A %s se le ha caído un plato!" % who if who != "ti" else "¡Se te ha caído un plato!", w.mover.last_cell)
				g.food_quality_sum -= g.food_quality_sum / maxf(1.0, float(g.dishes_ready))
				g.dishes_ready -= 1
				kitchen_queue.append({ "grupo": g, "receta": g.dishes[0] })
				g.mood_bonus -= 0.08
				_add_stain_near(w.mover.last_cell)
			else:
				g.service_scores.append(w.effective_trato())
				_serve(g)
		"cobrar":
			g.service_scores.append(w.effective_trato())
			_charge(g)
		"acomodar":
			g.service_scores.append(w.effective_trato())
			_seat(g)
		"recoger_mesa":
			w.task["mesa"].dirty = false
		"fregar":
			stains.erase(w.task["celda"])
	_end_waiter_task(w)


func _end_waiter_task(w) -> void:
	var g: CustomerGroup = w.task.get("grupo")
	if g != null and g.waiter == w:
		g.waiter = null
		# Si iba a acompañarles y no llegó a hacerlo, la mesa vuelve a quedar libre.
		if w.task["tipo"] == "acomodar" and g.state == CustomerGroup.State.EN_COLA and g.table != null:
			g.table.group = null
			g.table = null
	var table = w.task.get("mesa")
	if table != null and table.cleaner == w:
		table.cleaner = null
	var cell = w.task.get("celda")
	if cell != null and stains.has(cell) and stains[cell] == w:
		stains[cell] = null
	w.task = {}


func _take_order(g: CustomerGroup) -> void:
	var longest_prep := 0.0
	for i in g.size:
		var recipe_id := _choose_dish()
		if recipe_id == "":
			_leave_angry(g, "No quedaba comida")
			return
		var recipe: Dictionary = recipes[recipe_id]
		inventory.consume(recipe)
		g.dishes.append(recipe_id)
		g.bill += menu[recipe_id]
		g.fair_bill += float(recipe["precio_sugerido"])
		longest_prep = maxf(longest_prep, float(recipe["tiempo_prep_min"]))
		kitchen_queue.append({ "grupo": g, "receta": recipe_id })
	g.food_patience_extra = longest_prep
	g.set_state(CustomerGroup.State.ESPERANDO_COMIDA)


## Elige un plato de la carta. Los platos caros respecto a su valor se piden menos.
func _choose_dish() -> String:
	var options: Array[String] = []
	var weights: Array[float] = []
	var total := 0.0
	for recipe_id in menu:
		if not inventory.can_make(recipes[recipe_id]):
			continue
		var value: float = float(recipes[recipe_id]["precio_sugerido"]) / menu[recipe_id]
		var weight := pow(clampf(value, 0.3, 2.0), 2.0)
		options.append(recipe_id)
		weights.append(weight)
		total += weight
	if options.is_empty():
		return ""
	var roll := rng.randf() * total
	for i in options.size():
		roll -= weights[i]
		if roll <= 0.0:
			return options[i]
	return options[-1]


## ¿Se le cae el plato a quien sirve? Más probable con prisa o desanimado.
func _drops_plate(w) -> bool:
	var chance := 0.03
	if w is StaffMember:
		if w.now < w.rushed_until:
			chance += 0.05
		if w.moral < 40.0:
			chance += 0.03
	return rng.randf() < chance


func _serve(g: CustomerGroup) -> void:
	g.eat_time_left = rng.randf_range(20.0, 35.0) + 2.0 * g.size
	g.set_state(CustomerGroup.State.COMIENDO)


func _charge(g: CustomerGroup) -> void:
	g.set_state(CustomerGroup.State.SALIENDO)
	var service := 50.0
	if not g.service_scores.is_empty():
		service = 0.0
		for s in g.service_scores:
			service += s
		service /= g.service_scores.size()
	g.satisfaction = Satisfaction.score({
		"comida": g.food_quality_sum / maxi(1, g.dishes.size()),
		"tiempo": clampf(100.0 - g.wait_penalty * 50.0, 0.0, 100.0),
		"trato": service,
		"ambiente": layout.ambiente,
		"limpieza": cleanliness(),
		"calidad_precio": Satisfaction.value_for_money(g.bill, g.fair_bill),
	})
	# Lo que haya hecho el gestor por ellos (disculpas, invitaciones...) cuenta.
	g.satisfaction = clampf(g.satisfaction + g.mood_bonus * 40.0, 0.0, 100.0)
	if g.is_critic:
		# La reseña de un crítico pesa como la de muchos clientes.
		reputation = clampf(reputation + (g.satisfaction / 100.0 - reputation) * 0.3, 0.0, 1.0)
		announcement.emit("¡Era un crítico gastronómico! Su reseña: %.1f/5" % (1.0 + g.satisfaction / 25.0), g.members[0].last_cell)
	# Las propinas son del personal, no entran en la caja del restaurante.
	var tip := g.bill * maxf(0.0, (g.satisfaction - 70.0) / 300.0)
	finances.earn("ventas", g.bill)
	day_stats["propinas_personal"] += tip
	day_stats["grupos_servidos"] += 1
	day_stats["clientes_servidos"] += g.size
	day_stats["satisfaccion_total"] += g.satisfaction
	_update_reputation(g.satisfaction)
	_leave(g)


# --- Ánimo del personal ------------------------------------------------------------

## El trabajo continuo cansa y desanima poco a poco; los ratos tranquilos lo recuperan.
func _update_staff_mood(dt: float) -> void:
	for s in staff:
		s.now = minutes
		s.mover.speed = Mover.BASE_SPEED * s.speed_factor()
		if s.is_busy():
			s.moral = maxf(0.0, s.moral - dt * 0.03)
		else:
			s.moral = minf(100.0, s.moral + dt * 0.02)


# --- Cocina -----------------------------------------------------------------

func _update_cooks(dt: float) -> void:
	for c in cooks():
		while c.tickets.size() < c.cooking_capacity() and not kitchen_queue.is_empty():
			var ticket: Dictionary = kitchen_queue.pop_front()
			var recipe: Dictionary = recipes[ticket["receta"]]
			ticket["tiempo"] = float(recipe["tiempo_prep_min"]) * lerpf(1.4, 0.7, c.velocidad / 100.0)
			c.tickets.append(ticket)
		for ticket in c.tickets:
			ticket["tiempo"] -= dt
		for ticket in c.tickets.filter(func(t: Dictionary): return t["tiempo"] <= 0.0):
			_finish_dish(c, ticket)
		c.tickets = c.tickets.filter(func(t: Dictionary): return t["tiempo"] > 0.0)


func _finish_dish(cook: StaffMember, ticket: Dictionary) -> void:
	var g: CustomerGroup = ticket["grupo"]
	var recipe_id: String = ticket["receta"]
	if g.state != CustomerGroup.State.ESPERANDO_COMIDA:
		day_stats["platos_tirados"] += 1
		return
	var difficulty := float(recipes[recipe_id]["dificultad"])
	g.food_quality_sum += clampf(cook.effective_skill() + 15.0 - difficulty * 5.0 + rng.randf_range(-8.0, 8.0), 0.0, 100.0)
	g.dishes_ready += 1
	day_stats["platos"][recipe_id] = day_stats["platos"].get(recipe_id, 0) + 1


# --- Día --------------------------------------------------------------------

func _restock() -> void:
	var cost := inventory.restock_to(stock_targets, ingredients)
	if cost > 0.0:
		finances.spend("materia_prima", cost)


func _close_day() -> void:
	# Por la noche el gestor descansa.
	manager.energy = 100.0
	# El servicio de limpieza de la noche deja el local impecable para mañana.
	for t in layout.tables:
		t.dirty = false
		t.cleaner = null
	stains.clear()
	var wages := 0.0
	for s in staff:
		wages += s.salario_dia
		# Una noche de descanso: el ánimo vuelve en parte a lo normal.
		s.moral = lerpf(s.moral, 70.0, 0.4)
	finances.spend("personal", wages)
	for k in fixed_costs:
		finances.spend(k, float(fixed_costs[k]))
	var report := finances.close_day()
	var served: int = day_stats["grupos_servidos"]
	report.merge(day_stats)
	report["dia"] = int(minutes) / MINUTES_PER_DAY
	report["satisfaccion_media"] = day_stats["satisfaccion_total"] / served if served > 0 else 0.0
	report["reputacion"] = average_stars()
	_reset_day_stats()
	day_closed.emit(report)


func _reset_day_stats() -> void:
	day_stats = {
		"grupos_servidos": 0,
		"clientes_servidos": 0,
		"grupos_perdidos": 0,
		"motivos_perdida": {},
		"satisfaccion_total": 0.0,
		"propinas_personal": 0.0,
		"platos": {},
		"platos_tirados": 0,
		"invitaciones": 0.0,
	}


## ¿Se ha pasado por el minuto `minute_of_day` entre `a` y `b`?
static func _crossed(a: float, b: float, minute_of_day: int) -> bool:
	return floori((a - minute_of_day) / MINUTES_PER_DAY) != floori((b - minute_of_day) / MINUTES_PER_DAY)
