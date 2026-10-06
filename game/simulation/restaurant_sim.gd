class_name RestaurantSim
extends RefCounted
## Simulación del restaurante: clientes, sala, cocina, inventario y caja.
## Lógica pura: no dibuja nada. Las escenas leen su estado y escuchan sus señales.

signal day_closed(report: Dictionary)
signal group_left(group: CustomerGroup)
## El gestor ha llegado a un objeto y empieza a usarlo (p. ej. "ordenador").
signal manager_started_using(object_id: String)

const MINUTES_PER_DAY := 24 * 60
## Hora a la que llega el pedido diario de materia prima.
const RESTOCK_HOUR := 11
## Duración (minutos, a velocidad normal) de cada acción del camarero.
const WAITER_ACTION_TIME := { "pedido": 1.5, "servir": 0.5, "cobrar": 1.5, "recoger": 0.5 }
## Prioridad de las tareas del camarero (menor = antes).
const WAITER_PRIORITY := { "servir": 0, "cobrar": 1, "pedido": 2 }

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
		var cell := layout.waiter_home
		if d["puesto"] == StaffMember.ROLE_COOK:
			cell = layout.cook_stations[cook_count % layout.cook_stations.size()]
			cook_count += 1
		else:
			cell += Vector2i(0, waiter_count)
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
	var used := manager.step(dt)
	if used != "":
		manager_started_using.emit(used)
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
		groups.append(g)


func _update_groups(dt: float) -> void:
	_update_queue_positions()
	for g in groups:
		g.state_time += dt
		for m in g.members:
			m.step(dt)
		match g.state:
			CustomerGroup.State.LLEGANDO:
				if g.all_arrived():
					g.set_state(CustomerGroup.State.EN_COLA)
			CustomerGroup.State.EN_COLA:
				_try_seat(g)
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


func _try_seat(g: CustomerGroup) -> void:
	var best: RestaurantLayout.Table = null
	for table in layout.tables:
		if table.group == null and table.capacity() >= g.size:
			if best == null or table.capacity() < best.capacity():
				best = table
	if best == null:
		return
	best.group = g
	g.table = best
	for i in g.members.size():
		g.members[i].go_to(layout, best.seats[i])
	g.set_state(CustomerGroup.State.YENDO_A_MESA)


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
		g.table.group = null
		g.table = null
	kitchen_queue = kitchen_queue.filter(func(t: Dictionary): return t["grupo"] != g)
	g.set_state(CustomerGroup.State.SALIENDO)
	for m in g.members:
		m.go_to(layout, layout.spawn_cell)
	group_left.emit(g)


func _update_reputation(satisfaction: float) -> void:
	reputation = clampf(reputation + (satisfaction / 100.0 - reputation) * 0.03, 0.0, 1.0)


# --- Camareros --------------------------------------------------------------

func _update_waiters(dt: float) -> void:
	for w in waiters():
		w.mover.step(dt)
		if w.task.is_empty():
			_assign_waiter_task(w)
		if w.task.is_empty():
			if not w.mover.is_moving() and w.mover.cell() != layout.waiter_home:
				w.mover.go_to(layout, layout.waiter_home)
		else:
			_progress_waiter_task(w, dt)


func _assign_waiter_task(w: StaffMember) -> void:
	var best: CustomerGroup = null
	var best_type := ""
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
		if kind == "":
			continue
		if best == null or WAITER_PRIORITY[kind] < WAITER_PRIORITY[best_type] \
				or (WAITER_PRIORITY[kind] == WAITER_PRIORITY[best_type] and g.state_time > best.state_time):
			best = g
			best_type = kind
	if best == null:
		return
	best.waiter = w
	w.task = { "tipo": best_type, "grupo": best, "tiempo": 0.0 }
	if best_type == "servir":
		w.task["fase"] = "ir_pase"
		w.mover.go_to(layout, layout.pass_cell)
	else:
		w.task["fase"] = "ir_mesa"
		w.mover.go_to(layout, best.table.service_cell)


func _progress_waiter_task(w: StaffMember, dt: float) -> void:
	var g: CustomerGroup = w.task["grupo"]
	if g.state == CustomerGroup.State.SALIENDO or g.state == CustomerGroup.State.FUERA:
		_end_waiter_task(w)
		return
	match w.task["fase"]:
		"ir_pase":
			if not w.mover.is_moving():
				w.task["fase"] = "recoger"
				w.task["tiempo"] = WAITER_ACTION_TIME["recoger"] / w.speed_factor()
		"recoger":
			w.task["tiempo"] -= dt
			if w.task["tiempo"] <= 0.0:
				w.task["fase"] = "ir_mesa"
				w.mover.go_to(layout, g.table.service_cell)
		"ir_mesa":
			if not w.mover.is_moving():
				w.task["fase"] = "atender"
				w.task["tiempo"] = WAITER_ACTION_TIME[w.task["tipo"]] / w.speed_factor()
		"atender":
			w.task["tiempo"] -= dt
			if w.task["tiempo"] <= 0.0:
				g.service_scores.append(w.trato)
				match w.task["tipo"]:
					"pedido": _take_order(g)
					"servir": _serve(g)
					"cobrar": _charge(g)
				_end_waiter_task(w)


func _end_waiter_task(w: StaffMember) -> void:
	var g: CustomerGroup = w.task.get("grupo")
	if g != null and g.waiter == w:
		g.waiter = null
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
		"limpieza": layout.limpieza,
		"calidad_precio": Satisfaction.value_for_money(g.bill, g.fair_bill),
	})
	# Las propinas son del personal, no entran en la caja del restaurante.
	var tip := g.bill * maxf(0.0, (g.satisfaction - 70.0) / 300.0)
	finances.earn("ventas", g.bill)
	day_stats["propinas_personal"] += tip
	day_stats["grupos_servidos"] += 1
	day_stats["clientes_servidos"] += g.size
	day_stats["satisfaccion_total"] += g.satisfaction
	_update_reputation(g.satisfaction)
	_leave(g)


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
	g.food_quality_sum += clampf(cook.habilidad + 15.0 - difficulty * 5.0 + rng.randf_range(-8.0, 8.0), 0.0, 100.0)
	g.dishes_ready += 1
	day_stats["platos"][recipe_id] = day_stats["platos"].get(recipe_id, 0) + 1


# --- Día --------------------------------------------------------------------

func _restock() -> void:
	var cost := inventory.restock_to(stock_targets, ingredients)
	if cost > 0.0:
		finances.spend("materia_prima", cost)


func _close_day() -> void:
	var wages := 0.0
	for s in staff:
		wages += s.salario_dia
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
	}


## ¿Se ha pasado por el minuto `minute_of_day` entre `a` y `b`?
static func _crossed(a: float, b: float, minute_of_day: int) -> bool:
	return floori((a - minute_of_day) / MINUTES_PER_DAY) != floori((b - minute_of_day) / MINUTES_PER_DAY)
