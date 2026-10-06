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
		check(not layout.is_walkable(table.cell), "la mesa bloquea el paso")
		check(layout.is_walkable(table.service_cell), "se puede atender la mesa %d" % table.id)
		for seat in table.seats:
			check(layout.is_walkable(seat), "se puede llegar a la silla %s" % str(seat))
			var path := layout.find_path(layout.spawn_cell, seat)
			check(not path.is_empty(), "camino de la calle a la silla %s" % str(seat))
			for c in path:
				check(layout.is_walkable(c), "el camino no atraviesa obstáculos")
	check(not layout.find_path(layout.waiter_home, layout.pass_cell).is_empty(), "camino al pase")


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
