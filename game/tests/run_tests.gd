extends SceneTree
## Pruebas de la simulación, sin pantalla. Ejecutar desde la raíz del repo:
##   godot --headless --path game -s res://tests/run_tests.gd

var _failures := 0
var _checks := 0


func _init() -> void:
	test_clock_starts_at_given_time()
	test_clock_advances_with_speed()
	test_clock_pause_and_resume()
	test_clock_emits_hour_and_day()
	test_iso_round_trip()
	test_data_is_valid()
	test_recipe_cost()
	print("\n%d comprobaciones, %d fallos" % [_checks, _failures])
	quit(1 if _failures > 0 else 0)


func check(condition: bool, message: String) -> void:
	_checks += 1
	if not condition:
		_failures += 1
		printerr("FALLO: ", message)


func test_clock_starts_at_given_time() -> void:
	var clock := SimClock.new(3, 12)
	check(clock.get_day() == 3 and clock.get_hour() == 12 and clock.get_minute() == 0, "hora inicial")
	check(clock.get_time_text() == "Día 3 · 12:00", "texto de hora: " + clock.get_time_text())


func test_clock_advances_with_speed() -> void:
	var clock := SimClock.new(1, 10)
	clock.advance(30.0)
	check(clock.get_hour() == 10 and clock.get_minute() == 30, "x1: 30 s = 30 min")
	clock.set_speed(4)
	clock.advance(15.0)
	check(clock.get_hour() == 11 and clock.get_minute() == 30, "x4: 15 s = 60 min")


func test_clock_pause_and_resume() -> void:
	var clock := SimClock.new(1, 10)
	clock.set_speed(2)
	clock.toggle_pause()
	check(clock.is_paused(), "pausado")
	clock.advance(100.0)
	check(clock.get_hour() == 10 and clock.get_minute() == 0, "en pausa no avanza")
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


func test_iso_round_trip() -> void:
	for x in range(-3, 15):
		for y in range(-3, 15):
			var cell := Vector2i(x, y)
			var center := Iso.cell_to_screen(cell)
			check(Iso.screen_to_cell(center) == cell, "ida y vuelta iso %s" % str(cell))
			check(Iso.screen_to_cell(center + Vector2(40, 10)) == cell, "punto dentro del rombo %s" % str(cell))


func test_data_is_valid() -> void:
	var data = load("res://simulation/game_data.gd").new()
	data.load_all()
	check(data.ingredients.size() > 0, "hay ingredientes")
	check(data.recipes.size() > 0, "hay recetas")
	check(data.validate().is_empty(), "datos coherentes: %s" % str(data.validate()))
	data.free()


func test_recipe_cost() -> void:
	var ingredients := { "a": { "precio_base": 2.0 }, "b": { "precio_base": 0.5 } }
	var recipe := { "ingredientes": { "a": 1.5, "b": 4 } }
	var cost := RecipeCosting.cost(recipe, ingredients)
	check(is_equal_approx(cost, 5.0), "escandallo = 5.0, salió %f" % cost)
	check(is_equal_approx(RecipeCosting.food_cost_ratio(cost, 20.0), 0.25), "food cost 25%")
	check(is_equal_approx(RecipeCosting.margin(cost, 20.0), 15.0), "margen 15")
