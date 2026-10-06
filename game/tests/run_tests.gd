extends SceneTree
## Pruebas de la simulación, sin pantalla. Ejecutar desde la raíz del repo:
##   godot --headless --path game -s res://tests/run_tests.gd

var _failures := 0
var _checks := 0


func _initialize() -> void:
	test_clock_starts_at_given_time()
	test_clock_advances_with_speed()
	test_clock_pause_and_resume()
	test_clock_emits_hour_and_day()
	test_data_is_valid()
	test_recipe_cost()
	test_layout_paths_avoid_tables()
	test_mover_reaches_target()
	test_inventory_restock_and_consume()
	test_satisfaction_bounds()
	test_full_day_simulation()
	test_bot_builds_for_every_role()
	test_manager_walks_and_uses_computer()
	test_tap_detector()
	test_manager_avoids_obstacles()
	test_nobody_walks_through_anything()
	test_manager_talks()
	test_talk_effects()
	test_manager_works_and_cleaning()
	test_room_life()
	test_manager_energy()
	test_manager_helps_arriving_customers()
	await test_camera_follows_fingers()
	print("\n%d comprobaciones, %d fallos" % [_checks, _failures])
	quit(1 if _failures > 0 else 0)


func check(condition: bool, message: String) -> void:
	_checks += 1
	if not condition:
		_failures += 1
		printerr("FALLO: ", message)


func load_data() -> Dictionary:
	var data = load("res://simulation/game_data.gd").new()
	data.load_all()
	var result: Dictionary = data.sim_data()
	data.free()
	return result


func test_clock_starts_at_given_time() -> void:
	var clock := SimClock.new(3, 12)
	check(clock.get_day() == 3 and clock.get_hour() == 12 and clock.get_minute() == 0, "hora inicial")
	check(clock.get_time_text() == "Día 3 · 12:00", "texto de hora: " + clock.get_time_text())
	check(SimClock.new(1, 11, 30).get_minute() == 30, "minuto inicial")


func test_clock_advances_with_speed() -> void:
	var clock := SimClock.new(1, 10)
	check(is_equal_approx(clock.advance(30.0), 30.0), "devuelve los minutos avanzados")
	check(clock.get_hour() == 10 and clock.get_minute() == 30, "x1: 30 s = 30 min")
	clock.set_speed(4)
	clock.advance(15.0)
	check(clock.get_hour() == 11 and clock.get_minute() == 30, "x4: 15 s = 60 min")


func test_clock_pause_and_resume() -> void:
	var clock := SimClock.new(1, 10)
	clock.set_speed(2)
	clock.toggle_pause()
	check(clock.is_paused(), "pausado")
	check(clock.advance(100.0) == 0.0, "en pausa no avanza")
	clock.toggle_pause()
	check(clock.speed == 2, "reanuda a la velocidad anterior")


func test_clock_emits_hour_and_day() -> void:
	var clock := SimClock.new(1, 23)
	var events := { "horas": 0, "dias": [] }
	clock.hour_changed.connect(func(_d, _h): events["horas"] += 1)
	clock.day_changed.connect(func(d): events["dias"].append(d))
	clock.set_speed(4)
	clock.advance(30.0) # 120 minutos: 23:00 -> 01:00
	check(events["horas"] == 2, "dos cambios de hora, hubo %d" % events["horas"])
	check(events["dias"] == [2], "cambio al día 2: %s" % str(events["dias"]))


func test_data_is_valid() -> void:
	var data = load("res://simulation/game_data.gd").new()
	data.load_all()
	check(data.ingredients.size() > 0, "hay ingredientes")
	check(data.recipes.size() > 0, "hay recetas")
	check(not data.start.is_empty() and not data.demand.is_empty(), "hay partida inicial y demanda")
	check(data.validate().is_empty(), "datos coherentes: %s" % str(data.validate()))
	data.free()


func test_recipe_cost() -> void:
	var ingredients := { "a": { "precio_base": 2.0 }, "b": { "precio_base": 0.5 } }
	var recipe := { "ingredientes": { "a": 1.5, "b": 4 } }
	var cost := RecipeCosting.cost(recipe, ingredients)
	check(is_equal_approx(cost, 5.0), "escandallo = 5.0, salió %f" % cost)
	check(is_equal_approx(RecipeCosting.food_cost_ratio(cost, 20.0), 0.25), "food cost 25%")
	check(is_equal_approx(RecipeCosting.margin(cost, 20.0), 15.0), "margen 15")


func test_layout_paths_avoid_tables() -> void:
	var layout := RestaurantLayout.new(load_data()["start"]["local"])
	check(layout.tables.size() == 6, "seis mesas")
	for table in layout.tables:
		check(not layout.can_stand(table.cell), "la mesa bloquea el paso")
		check(layout.can_stand(table.service_cell), "se puede atender la mesa %d" % table.id)
		for seat in table.seats:
			check(layout.is_sittable(seat) and not layout.can_stand(seat), "la silla %s no se atraviesa, pero uno se puede sentar" % str(seat))
			var path := layout.find_path(layout.spawn_cell, seat)
			check(not path.is_empty(), "camino de la calle a la silla %s" % str(seat))
			for c in path:
				check(layout.can_stand(c) or c == seat, "el camino no atraviesa obstáculos")
	check(not layout.find_path(layout.waiter_homes[0], layout.pass_cell).is_empty(), "camino al pase")


func test_mover_reaches_target() -> void:
	var layout := RestaurantLayout.new(load_data()["start"]["local"])
	var mover := Mover.new(layout.spawn_cell, 4.0)
	mover.go_to(layout, layout.tables[0].seats[0])
	for i in 400:
		mover.step(0.25)
	check(not mover.is_moving(), "el que camina llega")
	check(mover.cell() == layout.tables[0].seats[0], "llega a la silla")


func test_inventory_restock_and_consume() -> void:
	var data := load_data()
	var inventory := Inventory.new()
	var cost := inventory.restock_to({ "huevo": 10 }, data["ingredients"])
	check(is_equal_approx(cost, 2.5), "10 huevos a 0,25 = 2,5 €")
	check(inventory.can_make(data["recipes"]["tortilla_patatas"]) == false, "sin patatas no hay tortilla")
	inventory.restock_to({ "patata": 1, "cebolla": 1, "aceite_oliva": 1 }, data["ingredients"])
	check(inventory.can_make(data["recipes"]["tortilla_patatas"]), "ya se puede hacer tortilla")
	inventory.consume(data["recipes"]["tortilla_patatas"])
	check(is_equal_approx(inventory.amount("huevo"), 7.0), "gasta 3 huevos")
	check(is_equal_approx(inventory.restock_to({ "huevo": 10 }, data["ingredients"]), 0.75), "solo compra lo que falta")


func test_satisfaction_bounds() -> void:
	var perfect := { "comida": 100, "tiempo": 100, "trato": 100, "ambiente": 100, "limpieza": 100, "calidad_precio": 100 }
	check(is_equal_approx(Satisfaction.score(perfect), 100.0), "satisfacción máxima 100")
	check(is_equal_approx(Satisfaction.score({ "comida": 0, "tiempo": 0, "trato": 0, "ambiente": 0, "limpieza": 0, "calidad_precio": 0 }), 0.0), "mínima 0")
	check(Satisfaction.value_for_money(10.0, 10.0) == 100.0, "precio justo = 100")
	check(Satisfaction.value_for_money(20.0, 10.0) == 0.0, "el doble de caro = 0")
	check(Satisfaction.stars(100.0) == 5 and Satisfaction.stars(0.0) == 1, "estrellas de 1 a 5")


func test_full_day_simulation() -> void:
	var sim := RestaurantSim.new(load_data(), 11 * 60 + 30, 12345)
	var money_start := sim.finances.money
	var reports: Array[Dictionary] = []
	sim.day_closed.connect(func(r: Dictionary): reports.append(r))
	var max_inside := 0
	# Desde las 11:30 del día 1 hasta las 03:00 del día 2.
	while sim.minutes < 24 * 60 + 3 * 60:
		sim.update(0.25)
		max_inside = maxi(max_inside, sim.customers_inside())
		for ingredient_id in sim.inventory.stock:
			if sim.inventory.amount(ingredient_id) < -0.0001:
				check(false, "stock negativo de %s" % ingredient_id)
		var seated := {}
		for g in sim.groups:
			if g.table != null:
				check(not seated.has(g.table.id), "dos grupos en la misma mesa")
				seated[g.table.id] = true
	check(reports.size() == 1, "un informe al cerrar el día")
	if reports.is_empty():
		return
	var r := reports[0]
	print("Día simulado: %d grupos servidos (%d clientes), %d perdidos %s, satisfacción %.0f, beneficio %.2f €, ventas %.2f €" % [
		r["grupos_servidos"], r["clientes_servidos"], r["grupos_perdidos"], str(r["motivos_perdida"]),
		r["satisfaccion_media"], r["beneficio"], r["ingresos"].get("ventas", 0.0)])
	check(r["dia"] == 1, "el informe es del día 1")
	check(r["grupos_servidos"] > 10, "se sirven bastantes grupos")
	check(r["ingresos"].get("ventas", 0.0) > 0.0, "hay ventas")
	check(r["gastos"].has("personal") and r["gastos"].has("alquiler"), "se pagan sueldos y alquiler")
	check(r["satisfaccion_media"] > 30.0 and r["satisfaccion_media"] <= 100.0, "satisfacción razonable")
	check(max_inside > 0, "llegó gente")
	check(sim.groups.is_empty(), "a las 3:00 ya se han ido todos")
	for table in sim.layout.tables:
		check(table.group == null, "mesas libres al final")
	check(not is_equal_approx(sim.finances.money, money_start), "el dinero ha cambiado")


func test_bot_builds_for_every_role() -> void:
	for role in Bot.Role.values():
		var bot := Bot.new()
		bot.setup(role, 5)
		check(bot.get_child_count() > 0, "el personaje %d tiene piezas" % role)
		bot.free()
	var textures: Dictionary = Bot.resources()["eye_textures"]
	for kind in Bot.Eyes.values():
		var img: Image = textures[kind].get_image()
		var lit := 0
		for x in range(0, img.get_width(), 2):
			for y in range(0, img.get_height(), 2):
				if img.get_pixel(x, y).a > 0.5:
					lit += 1
		check(lit > 10, "la expresión de ojos %d se dibuja" % kind)


func _touch(cam: IsoCamera, index: int, pos: Vector2, pressed: bool) -> void:
	var e := InputEventScreenTouch.new()
	e.index = index
	e.position = pos
	e.pressed = pressed
	cam._unhandled_input(e)


func _drag(cam: IsoCamera, index: int, from: Vector2, to: Vector2) -> void:
	var e := InputEventScreenDrag.new()
	e.index = index
	e.position = to
	e.relative = to - from
	cam._unhandled_input(e)


func test_camera_follows_fingers() -> void:
	var cam := IsoCamera.new()
	root.add_child.call_deferred(cam)
	await process_frame
	cam.focus(Vector3(5, 0, 5))
	# Un dedo: el punto del suelo bajo el dedo sigue bajo el dedo, en cualquier dirección.
	var finger := Vector2(900, 500)
	_touch(cam, 0, finger, true)
	# Primero el dedo pasa el margen del toque y empieza el arrastre.
	var start_ground := cam.screen_to_ground(finger)
	_drag(cam, 0, finger, finger + Vector2(0, cam.tap_slop() * 1.5))
	finger += Vector2(0, cam.tap_slop() * 1.5)
	check(cam.screen_to_ground(finger).distance_to(start_ground) < 0.01, "al empezar a arrastrar, el suelo tocado va bajo el dedo")
	for step in [Vector2(60, 0), Vector2(0, -60), Vector2(-60, 0), Vector2(0, 60), Vector2(35, -20)]:
		var grabbed := cam.screen_to_ground(finger)
		_drag(cam, 0, finger, finger + step)
		finger += step
		check(cam.screen_to_ground(finger).distance_to(grabbed) < 0.01, "el suelo sigue al dedo (%s)" % step)
	_touch(cam, 0, finger, false)
	# Arrastrar hacia arriba sube el escenario: la cámara pasa a mirar más abajo en pantalla.
	var center_before := cam.target
	_touch(cam, 0, Vector2(900, 600), true)
	_drag(cam, 0, Vector2(900, 600), Vector2(900, 500))
	_touch(cam, 0, Vector2(900, 500), false)
	var screen_down := cam.screen_to_ground(Vector2(900, 700)) - cam.screen_to_ground(Vector2(900, 500))
	check((cam.target - center_before).dot(screen_down) > 0.0, "arrastrar arriba sube el escenario")
	# El temblor de un toque (unos píxeles) no mueve la cámara.
	var still := cam.target
	_touch(cam, 0, Vector2(900, 500), true)
	_drag(cam, 0, Vector2(900, 500), Vector2(906, 502))
	_drag(cam, 0, Vector2(906, 502), Vector2(912, 504))
	_touch(cam, 0, Vector2(912, 504), false)
	check(cam.target == still, "un toque con temblor no mueve la cámara")
	check(Vector2(12, 4).length() < cam.tap_slop(), "ese temblor cuenta como toque")
	# Pellizco: el punto entre los dedos se queda quieto y el zoom cambia.
	var a := Vector2(300, 400)
	var b := Vector2(500, 400)
	_touch(cam, 0, a, true)
	_touch(cam, 1, b, true)
	var mid_ground := cam.screen_to_ground((a + b) / 2.0)
	var size_before := cam.size
	_drag(cam, 0, a, a - Vector2(50, 0))
	_drag(cam, 1, b, b + Vector2(50, 0))
	a -= Vector2(50, 0)
	b += Vector2(50, 0)
	check(cam.size < size_before, "separar los dedos acerca la cámara")
	check(cam.screen_to_ground((a + b) / 2.0).distance_to(mid_ground) < 0.01, "el zoom va hacia los dedos")
	_touch(cam, 0, a, false)
	_touch(cam, 1, b, false)
	cam.free()


func test_manager_walks_and_uses_computer() -> void:
	var sim := RestaurantSim.new(load_data(), 9 * 60, 7)
	var m := sim.manager
	var layout := sim.layout
	check(m.mover.cell() == layout.manager_home, "el gestor empieza en su sitio")
	check(layout.zone_name_at(layout.objects["ordenador"]["uso"]) == "Despacho", "el ordenador está en el despacho")
	# Andar a una celda libre.
	sim.order_manager_walk(Vector2i(0, 0))
	for i in 200:
		sim.update(0.25)
	check(m.mover.cell() == Vector2i(0, 0) and m.state == Manager.State.LIBRE, "el gestor llega adonde se le manda")
	# Mandarlo a una mesa o a una silla: se queda al lado.
	var table: RestaurantLayout.Table = layout.tables[0]
	sim.order_manager_walk(table.seats[0])
	for i in 200:
		sim.update(0.25)
	check(layout.can_stand(m.mover.cell()) and m.mover.cell().distance_to(table.seats[0]) <= 1.5, "si tocas una silla, se queda al lado")
	# Usar el ordenador: llega, se sienta y avisa una vez.
	var used: Array[String] = []
	sim.manager_started_using.connect(func(id: String): used.append(id))
	sim.order_manager_use("ordenador")
	for i in 400:
		sim.update(0.25)
	check(used == ["ordenador"], "avisa una sola vez de que usa el ordenador")
	check(m.state == Manager.State.USANDO and m.mover.cell() == layout.objects["ordenador"]["uso"], "está sentado en el ordenador")
	sim.stop_manager()
	check(m.state == Manager.State.LIBRE, "se levanta del ordenador")
	# En pausa (sin avanzar la simulación) la orden espera.
	var before := m.mover.pos
	sim.order_manager_walk(Vector2i(3, 3))
	check(m.mover.pos == before and m.state == Manager.State.ANDANDO, "en pausa la orden queda pendiente")


func test_manager_avoids_obstacles() -> void:
	var sim := RestaurantSim.new(load_data(), 9 * 60, 7)
	var layout := sim.layout
	var m := sim.manager
	# Cruzar el local de punta a punta: nunca pisa mesas, sillas ni muebles.
	for target in [Vector2i(0, 9), Vector2i(7, 3), Vector2i(0, 0), Vector2i(10, 2), Vector2i(9, 8)]:
		sim.order_manager_walk(target)
		var ok := true
		for i in 400:
			sim.update(0.1)
			if not layout.can_stand(m.mover.cell()):
				ok = false
		check(ok, "camino hasta %s sin atravesar muebles" % target)
		check(m.mover.last_cell == target, "llega a %s" % target)
	check(layout.zone_name_at(Vector2i(10, 2)) == "Cocina", "se puede entrar en la cocina por la puerta")
	var path := layout.find_path(Vector2i(0, 0), Vector2i(0, 4), [Vector2i(0, 2)])
	check(not path.is_empty() and not path.has(Vector2i(0, 2)), "el camino rodea a una persona")


## Comprueba en cada instante de un día que nadie atraviesa a nadie ni pisa muebles.
func test_nobody_walks_through_anything() -> void:
	var sim := RestaurantSim.new(load_data(), 11 * 60 + 30, 4242)
	var layout := sim.layout
	var overlaps := 0
	var on_furniture := 0
	var report := {}
	sim.day_closed.connect(func(r: Dictionary): report.merge(r))
	# Además, el gestor da vueltas por el comedor entre la gente.
	var walks: Array[Vector2i] = [Vector2i(0, 0), Vector2i(7, 9), Vector2i(7, 0), Vector2i(0, 9), Vector2i(10, 3)]
	var tick := 0
	while sim.minutes < 24 * 60 + 60:
		if tick % 200 == 0:
			sim.order_manager_walk(walks[(tick / 200) % walks.size()])
		tick += 1
		sim.update(0.25)
		var all := sim.agents()
		for i in all.size():
			var mover: Mover = all[i][0]
			var c := mover.cell()
			if not layout.can_stand(c) and not layout.is_sittable(c):
				on_furniture += 1
			for j in range(i + 1, all.size()):
				var other: Mover = all[j][0]
				if all[i][1] == all[j][1] or mover.pos.distance_to(other.pos) >= 0.5:
					continue
				if mover.cell() == layout.spawn_cell or other.cell() == layout.spawn_cell:
					continue
				# Dos personas que se cruzan de frente intercambian casillas: no cuenta.
				var swapping := mover.is_moving() and other.is_moving() \
						and mover.path[0] == other.last_cell and other.path[0] == mover.last_cell
				if not swapping:
					overlaps += 1
	check(overlaps == 0, "nadie comparte casilla con otra persona (%d solapes)" % overlaps)
	check(on_furniture == 0, "nadie pisa mesas, barra ni muebles (%d veces)" % on_furniture)
	var served: int = report.get("clientes_servidos", 0)
	var lost: int = report.get("grupos_perdidos", 0)
	check(served >= 30 and lost <= 10, "el servicio sigue funcionando con tráfico: %d atendidos, %d grupos perdidos" % [served, lost])
	check(sim.forced_passes <= 10, "los cruces forzados son raros: %d" % sim.forced_passes)
	print("Día con tráfico: %d clientes atendidos, %d perdidos, %d pasos forzados" % [served, report.get("grupos_perdidos", 0), sim.forced_passes])
	# Nadie se queda atascado: al final del día no queda nadie esperando para siempre.
	for a in sim.agents():
		check(a[0].wait_time < RestaurantSim.GHOST_AFTER, "nadie se queda atascado")


func test_manager_talks() -> void:
	var sim := RestaurantSim.new(load_data(), 11 * 60 + 30, 3)
	var talks: Array[Dictionary] = []
	sim.manager_started_talking.connect(func(t: Dictionary): talks.append(t))
	# Hablar con un camarero: va hasta él y el camarero se para.
	var waiter := sim.waiters()[0]
	sim.order_manager_talk(waiter)
	for i in 300:
		sim.update(0.1)
		if not talks.is_empty():
			break
	check(talks.size() == 1 and talks[0]["entity"] == waiter, "llega a hablar con el camarero")
	check(waiter.talking and sim.manager.state == Manager.State.HABLANDO, "el camarero se para a hablar")
	check(sim.manager.mover.pos.distance_to(waiter.mover.pos) <= Manager.TALK_DISTANCE, "hablan cerca el uno del otro")
	var opening := Conversation.opening(talks[0], sim)
	check(opening.length() > 5, "el camarero responde: " + opening)
	for option in Conversation.options(talks[0], sim):
		check(Conversation.choose(talks[0], option["id"], sim) != "", "respuesta a '%s'" % option["texto"])
	sim.stop_manager()
	check(not waiter.talking, "al terminar, el camarero vuelve al trabajo")
	# Hablar con clientes en distintos momentos de su visita.
	var states_seen := {}
	for i in 6000:
		sim.update(0.25)
		for g in sim.groups:
			var target := { "entity": g, "member": 0 }
			states_seen[g.state] = true
			check(Conversation.opening(target, sim) != "", "el cliente siempre dice algo")
			for option in Conversation.options(target, sim):
				if option["id"] in ["que_tal", "mejorar", "precios"]:
					check(Conversation.choose(target, option["id"], sim) != "", "y siempre responde")
	check(states_seen.has(CustomerGroup.State.COMIENDO), "se ha probado a hablar con clientes comiendo")
	# Ir a hablar con un cliente que se mueve.
	var g: CustomerGroup = null
	for candidate in sim.groups:
		if candidate.state != CustomerGroup.State.SALIENDO:
			g = candidate
			break
	if g != null:
		talks.clear()
		sim.order_manager_talk(g, 0)
		for i in 600:
			sim.update(0.1)
			if not talks.is_empty() or sim.manager.state == Manager.State.LIBRE:
				break
		check(not talks.is_empty() or sim.manager.notice != "", "llega a hablar con el cliente o avisa de por qué no")


func _tap_event(index: int, pos: Vector2, pressed: bool) -> InputEventScreenTouch:
	var e := InputEventScreenTouch.new()
	e.index = index
	e.position = pos
	e.pressed = pressed
	return e


func _drag_event(index: int, pos: Vector2) -> InputEventScreenDrag:
	var e := InputEventScreenDrag.new()
	e.index = index
	e.position = pos
	return e


func test_tap_detector() -> void:
	var slop := 30.0
	# Los navegadores de móvil numeran los dedos como quieren: 0, 7, números enormes...
	for finger in [0, 7, 1234567]:
		var t := TapDetector.new()
		check(t.feed(_tap_event(finger, Vector2(100, 100), true), slop) == null, "apoyar no es aún un toque")
		t.feed(_drag_event(finger, Vector2(108, 104)), slop)
		var tap = t.feed(_tap_event(finger, Vector2(110, 105), false), slop)
		check(tap == Vector2(110, 105), "toque con el dedo %d y temblor pequeño" % finger)
	# Un arrastre largo no es un toque, aunque el dedo vuelva al sitio.
	var t := TapDetector.new()
	t.feed(_tap_event(3, Vector2(100, 100), true), slop)
	t.feed(_drag_event(3, Vector2(200, 100)), slop)
	t.feed(_drag_event(3, Vector2(101, 100)), slop)
	check(t.feed(_tap_event(3, Vector2(101, 100), false), slop) == null, "un arrastre no es un toque")
	# Un pellizco no es un toque, se suelte el dedo que se suelte primero.
	t.feed(_tap_event(4, Vector2(100, 100), true), slop)
	t.feed(_tap_event(9, Vector2(300, 100), true), slop)
	check(t.feed(_tap_event(9, Vector2(300, 100), false), slop) == null, "soltar un dedo del pellizco no es un toque")
	check(t.feed(_tap_event(4, Vector2(100, 100), false), slop) == null, "soltar el otro dedo tampoco")
	# Y después del pellizco, un toque normal vuelve a funcionar.
	t.feed(_tap_event(11, Vector2(50, 50), true), slop)
	check(t.feed(_tap_event(11, Vector2(52, 51), false), slop) == Vector2(52, 51), "tras un pellizco, los toques siguen funcionando")


func test_talk_effects() -> void:
	var sim := RestaurantSim.new(load_data(), 12 * 60, 11)
	var g := CustomerGroup.new()
	g.id = 99
	g.size = 2
	g.set_state(CustomerGroup.State.ESPERANDO_PEDIR)
	g.state_time = 1.4 * g.patience_limit()
	var target := { "entity": g, "member": 0 }
	var ids := Conversation.options(target, sim).map(func(o): return o["id"])
	check(ids.has("disculpa"), "a un cliente que espera se le pueden pedir disculpas")
	var mood_before := g.mood()
	var limit_before := g.patience_limit()
	Conversation.choose(target, "disculpa", sim)
	check(g.mood() > mood_before and g.patience_limit() > limit_before, "disculparse le calma y le da más paciencia")
	ids = Conversation.options(target, sim).map(func(o): return o["id"])
	check(not ids.has("disculpa"), "no se puede disculpar dos veces por lo mismo")
	# Invitar al postre: cuesta dinero y sube mucho el ánimo y la valoración.
	g.set_state(CustomerGroup.State.COMIENDO)
	var money := sim.finances.money
	var bonus := g.mood_bonus
	Conversation.choose(target, "invitar", sim)
	check(is_equal_approx(sim.finances.money, money - Conversation.TREAT_COST), "invitar cuesta dinero")
	check(g.mood_bonus >= bonus + Conversation.TREAT_MOOD - 0.001, "invitar sube el ánimo")
	check(Conversation.worst_aspect(g, sim) != "", "el cliente sabe decir qué mejorar")
	# Empleados: felicitar anima (no tanto si es seguido); meter prisa acelera y desanima.
	var w := sim.waiters()[0]
	var target_w := { "entity": w, "member": 0 }
	var moral := w.moral
	Conversation.choose(target_w, "felicitar", sim)
	check(w.moral > moral, "felicitar sube el ánimo")
	var after_first := w.moral
	Conversation.choose(target_w, "felicitar", sim)
	check(w.moral - after_first < after_first - moral, "felicitar seguido cuenta menos")
	var speed := w.speed_factor()
	w.now = sim.minutes
	Conversation.choose(target_w, "prisa", sim)
	check(w.speed_factor() > speed * 0.95 and w.moral < after_first + 5.0, "meter prisa acelera pero desanima")
	check(Conversation.choose(target_w, "como_estas", sim).begins_with("Estoy"), "el empleado dice cómo está")
	# El ánimo influye: un camarero quemado trata peor.
	w.moral = 20.0
	var low := w.effective_trato()
	w.moral = 90.0
	check(w.effective_trato() > low, "un empleado animado trata mejor")


func test_manager_works_and_cleaning() -> void:
	var data := load_data()
	data["start"]["personal"] = data["start"]["personal"].filter(func(p): return p["puesto"] != "camarero")
	var sim := RestaurantSim.new(data, 12 * 60, 21)
	check(sim.waiters().is_empty(), "prueba sin camareros: solo el gestor")
	# Llega un grupo: sin nadie que los acomode, esperan en la cola.
	var g := CustomerGroup.new()
	g.id = 500
	g.size = 2
	for i in 2:
		g.members.append(Mover.new(sim.layout.spawn_cell))
	sim.groups.append(g)
	for i in 200:
		sim.update(0.1)
	check(g.state == CustomerGroup.State.EN_COLA, "sin nadie que los acomode, esperan en la cola")
	# El gestor les acompaña a una mesa, les toma nota, sirve y cobra.
	sim.order_manager_task({ "tipo": "acomodar", "grupo": g })
	for i in 400:
		sim.update(0.1)
		if g.state == CustomerGroup.State.ESPERANDO_PEDIR:
			break
	check(g.state == CustomerGroup.State.ESPERANDO_PEDIR, "el gestor les sienta en una mesa")
	var table: RestaurantLayout.Table = g.table
	sim.set_manager_covering("sala")
	for i in 3000:
		sim.update(0.1)
		if g.state == CustomerGroup.State.SALIENDO or g.state == CustomerGroup.State.FUERA:
			break
	check(g.state == CustomerGroup.State.SALIENDO or g.state == CustomerGroup.State.FUERA, "atendiendo mesas, el gestor les sirve y cobra")
	check(not g.left_angry, "y se van contentos, no enfadados")
	check(table.dirty, "al irse, la mesa queda sucia")
	check(sim.free_table_for(g) != table, "una mesa sucia no se puede ocupar")
	# Recoger la mesa y fregar una mancha.
	var free_cells: Array[Vector2i] = []
	for c in [Vector2i(0, 0), Vector2i(0, 1), Vector2i(0, 3), Vector2i(0, 4), Vector2i(0, 6)]:
		if not sim.stains.has(c):
			free_cells.append(c)
	sim.stains[free_cells[0]] = null
	var clean_before := sim.cleanliness()
	sim.stains[free_cells[1]] = null
	check(sim.cleanliness() < clean_before, "las manchas bajan la limpieza")
	sim.order_manager_clean_table(table)
	for i in 600:
		sim.update(0.1)
		if not table.dirty:
			break
	check(not table.dirty, "el gestor recoge la mesa")
	sim.set_manager_covering("limpieza")
	for i in 1500:
		sim.update(0.1)
		if sim.stains.is_empty():
			break
	check(sim.stains.is_empty(), "limpiando, el gestor friega todas las manchas")
	check(sim.manager.describe() != "", "el gestor describe lo que hace")


func _seated_group(sim: RestaurantSim, id: int, size: int, table_index: int) -> CustomerGroup:
	var g := CustomerGroup.new()
	g.id = id
	g.size = size
	var table: RestaurantLayout.Table = sim.layout.tables[table_index]
	for i in size:
		var m := Mover.new(table.seats[i])
		g.members.append(m)
	g.table = table
	table.group = g
	sim.groups.append(g)
	return g


func test_room_life() -> void:
	var sim := RestaurantSim.new(load_data(), 13 * 60, 5)
	var notices: Array[String] = []
	sim.announcement.connect(func(text: String, _cell: Vector2i): notices.append(text))
	# Plato que se cae: vuelve a la cocina, se mancha el suelo y se avisa.
	var g := _seated_group(sim, 701, 2, 0)
	g.set_state(CustomerGroup.State.ESPERANDO_COMIDA)
	g.dishes = ["flan", "flan"]
	g.dishes_ready = 2
	g.food_quality_sum = 160.0
	var w := sim.waiters()[0]
	w.rushed_until = sim.minutes + 999.0
	w.now = sim.minutes
	var drops := 0
	for i in 400:
		if sim._drops_plate(w):
			drops += 1
	check(drops > 10 and drops < 80, "con prisa se caen algunos platos (%d de 400)" % drops)
	sim.rng.seed = 1
	var dropped := false
	for attempt in 200:
		sim.start_task(w, { "tipo": "servir", "grupo": g })
		w.task["fase"] = "atender"
		w.task["tiempo"] = 0.0
		var queue_before := sim.kitchen_queue.size()
		sim._progress_waiter_task(w, 0.1)
		if g.state == CustomerGroup.State.ESPERANDO_COMIDA:
			dropped = true
			check(sim.kitchen_queue.size() == queue_before + 1 and g.dishes_ready == 1, "el plato caído se vuelve a cocinar")
			check(not sim.stains.is_empty(), "el plato caído mancha el suelo")
			check(notices.any(func(t): return t.contains("caído")), "se avisa del plato caído")
			break
		g.set_state(CustomerGroup.State.ESPERANDO_COMIDA)
		g.dishes_ready = 2
	check(dropped, "en algún momento se cae un plato")
	# Queja en voz alta: molesta a la mesa de al lado.
	var angry := _seated_group(sim, 702, 2, 1)
	angry.set_state(CustomerGroup.State.ESPERANDO_PEDIR)
	angry.state_time = 1.8 * angry.patience_limit()
	var neighbour := _seated_group(sim, 703, 2, 3)
	neighbour.set_state(CustomerGroup.State.COMIENDO)
	var before := neighbour.mood()
	sim._maybe_complain(angry)
	check(angry.complained and sim.minutes < angry.shout_until, "un cliente muy enfadado se queja en voz alta")
	check(neighbour.mood() < before, "la queja molesta a la mesa de al lado")
	check(angry.hand_raised(), "quien lleva rato esperando levanta la mano")
	# Crítico: su reseña pesa mucho más que la de un cliente normal.
	var critic := _seated_group(sim, 704, 1, 4)
	critic.is_critic = true
	critic.set_state(CustomerGroup.State.ESPERANDO_CUENTA)
	critic.dishes = ["flan"]
	critic.dishes_ready = 1
	critic.food_quality_sum = 5.0
	critic.bill = 9.0
	critic.fair_bill = 4.5
	critic.service_scores = [5.0]
	critic.wait_penalty = 2.0
	var normal := _seated_group(sim, 706, 1, 5)
	for k in ["dishes", "dishes_ready", "food_quality_sum", "bill", "fair_bill", "service_scores", "wait_penalty"]:
		normal.set(k, critic.get(k))
	normal.set_state(CustomerGroup.State.ESPERANDO_CUENTA)
	var rep := sim.reputation
	sim._charge(normal)
	var normal_drop := rep - sim.reputation
	rep = sim.reputation
	sim._charge(critic)
	check(rep - sim.reputation > normal_drop * 5.0, "un crítico descontento hunde la reputación mucho más que un cliente normal")
	check(notices.any(func(t): return t.contains("crítico")), "se descubre al crítico al irse")
	# Niño que se aburre esperando la comida: se levanta y vuelve a su sitio.
	var family := _seated_group(sim, 705, 3, 3 if neighbour.table != sim.layout.tables[3] else 0)
	family.child_member = 2
	family.set_state(CustomerGroup.State.ESPERANDO_COMIDA)
	var played := false
	for i in 3000:
		sim._update_child(family, 0.1)
		for m in family.members:
			sim._walk(m, "g705", 0.1)
		if family.child_state == "jugando":
			played = true
		if played and family.child_state == "":
			break
	check(played, "el niño se levanta a jugar")
	check(family.child_state == "" and family.members[2].last_cell == family.table.seats[2], "y vuelve a su sitio")


func test_manager_energy() -> void:
	var sim := RestaurantSim.new(load_data(), 12 * 60, 8)
	var m := sim.manager
	# Parado gasta poco; trabajando, bastante más.
	var e0 := m.energy
	for i in 600:
		sim.update(0.1)
	var idle_drain := e0 - m.energy
	check(idle_drain > 0.0, "el día cansa aunque no haga nada")
	sim.set_manager_covering("limpieza")
	sim.stains[Vector2i(0, 0)] = null
	sim.stains[Vector2i(7, 9)] = null
	var e1 := m.energy
	for i in 600:
		sim.update(0.1)
	check(e1 - m.energy > idle_drain, "trabajar cansa más que estar parado")
	# Agotado: más lento y sin poder trabajar.
	var fast := m.speed_factor()
	m.energy = 0.02
	for i in 20:
		sim.update(0.1)
	check(m.exhausted(), "se puede llegar a estar agotado")
	check(m.covering == "" and m.state != Manager.State.TRABAJANDO, "agotado, deja de trabajar")
	check(m.speed_factor() < fast, "cansado va más lento")
	sim.set_manager_covering("sala")
	check(m.covering == "", "agotado no puede ponerse a trabajar")
	# Un café le recupera.
	sim.order_manager_use("cafetera")
	for i in 400:
		sim.update(0.1)
		if m.energy > 20.0:
			break
	check(m.energy >= RestaurantSim.COFFEE_ENERGY - 1.0, "el café le devuelve la energía")
	check(m.state == Manager.State.LIBRE, "después del café queda libre")
	# Por la noche descansa del todo.
	m.energy = 30.0
	while sim.minutes < 24 * 60 + 1:
		sim.update(0.25)
	check(m.energy >= 99.0, "por la noche recupera toda la energía")


## Al tocar a unos clientes recién llegados, el gestor siempre puede ayudarles con la mesa.
func test_manager_helps_arriving_customers() -> void:
	var sim := RestaurantSim.new(load_data(), 13 * 60, 31)
	var g := CustomerGroup.new()
	g.id = 900
	g.size = 2
	for i in 2:
		g.members.append(Mover.new(sim.layout.spawn_cell))
	sim.groups.append(g)
	var target := { "entity": g, "member": 0 }
	var ids := Conversation.options(target, sim).map(func(o): return o["id"])
	check(ids.has("acomodar"), "recién llegados (aún andando), el gestor puede acompañarles a una mesa")
	# Si un camarero ya iba a buscarlos, el gestor le releva.
	var w := sim.waiters()[0]
	sim.start_task(w, { "tipo": "acomodar", "grupo": g })
	ids = Conversation.options(target, sim).map(func(o): return o["id"])
	check(ids.has("acomodar"), "aunque un camarero fuera a por ellos, el gestor puede encargarse")
	Conversation.choose(target, "acomodar", sim)
	check(w.task.is_empty() and g.waiter == sim.manager, "el gestor releva al camarero")
	for i in 600:
		sim.update(0.1)
		if g.state == CustomerGroup.State.ESPERANDO_PEDIR:
			break
	check(g.state == CustomerGroup.State.ESPERANDO_PEDIR, "el gestor les sienta en su mesa")
	# Sin mesas limpias: el gestor puede prepararles una sucia, o al menos tranquilizarles.
	var g2 := CustomerGroup.new()
	g2.id = 901
	g2.size = 2
	for i in 2:
		g2.members.append(Mover.new(sim.layout.spawn_cell))
	sim.groups.append(g2)
	for t in sim.layout.tables:
		if t.group == null:
			t.dirty = true
	var t2 := { "entity": g2, "member": 0 }
	ids = Conversation.options(t2, sim).map(func(o): return o["id"])
	check(ids.has("preparar_mesa"), "si solo hay mesas sucias, el gestor puede preparar una")
	Conversation.choose(t2, "preparar_mesa", sim)
	check(sim.manager.task.get("tipo", "") == "recoger_mesa", "el gestor va a recoger la mesa")
	for t in sim.layout.tables:
		if t.group == null:
			t.group = g
	ids = Conversation.options(t2, sim).map(func(o): return o["id"])
	check(ids.has("sin_mesa"), "sin ninguna mesa, el gestor puede tranquilizarles")
