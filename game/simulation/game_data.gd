extends Node
## Autoload "GameData": carga el contenido del juego desde los JSON de res://data.

const DATA_DIR := "res://data/"
## Dinero con el que empieza una partida nueva: con él se compra el local y se equipa.
const NEW_GAME_MONEY := 60000
## Cada día se pagan en tasas e impuestos 1/700 del valor del local.
const TAX_DIVISOR := 700.0

## id -> diccionario con los datos del ingrediente.
var ingredients: Dictionary = {}
## id -> diccionario con los datos de la receta.
var recipes: Dictionary = {}
## Local, personal, carta y dinero con los que empieza la partida.
var start: Dictionary = {}
## Llegada de clientes por hora y tamaño de los grupos.
var demand: Dictionary = {}
## Barrios donde se puede abrir el restaurante, en orden (id -> datos).
var barrios: Dictionary = {}
## Tipos de vecino (estudiante, ejecutivo...) y rasgos de carácter.
var perfiles: Dictionary = {}
var rasgos: Dictionary = {}
## Catálogo de muebles y decoración del modo construcción.
var muebles: Dictionary = {}
## Locales que se pueden comprar (id -> datos), del más pequeño al más grande.
var locales: Dictionary = {}
## Suelos y paredes (estilos, ventanas y adornos) del modo construcción.
var suelos: Dictionary = {}
var paredes: Dictionary = {}
## Tipos de habitación (baños, ropero, barra, despacho).
var habitaciones: Dictionary = {}


func _ready() -> void:
	load_all()


func load_all() -> void:
	ingredients = _by_id(_load_json("ingredients.json"))
	recipes = _by_id(_load_json("recipes.json"))
	start = _load_json("restaurant_start.json")
	demand = _load_json("demand.json")
	barrios = _by_id(_load_json("barrios.json"))
	perfiles = _by_id(_load_json("perfiles.json"))
	rasgos = _by_id(_load_json("rasgos.json"))
	muebles = _by_id(_load_json("muebles.json"))
	locales = _by_id(_load_json("locales.json"))
	suelos = _by_id(_load_json("suelos.json"))
	habitaciones = _by_id(_load_json("habitaciones.json"))
	var walls = _load_json("paredes.json")
	paredes = { "estilos": _by_id(walls["estilos"]), "aberturas": _by_id(walls["aberturas"]), "adornos": _by_id(walls["adornos"]) }
	for error in validate():
		push_error(error)


## Todo lo que necesita RestaurantSim para arrancar. Con un barrio, la clientela son sus
## vecinos; sin él, clientes anónimos con la demanda genérica.
## Con un local, se parte de ese local vacío comprado con el dinero inicial: queda lo que
## sobra y solo el personal imprescindible (un camarero y un cocinero).
func sim_data(barrio_id: String = "", local_id: String = "") -> Dictionary:
	var data := { "ingredients": ingredients, "recipes": recipes, "start": start, "demand": demand, "muebles": muebles,
			"acabados": { "suelos": suelos, "paredes": paredes, "habitaciones": habitaciones } }
	if barrios.has(barrio_id):
		data["barrio"] = barrios[barrio_id]
		data["perfiles"] = perfiles
		data["rasgos"] = rasgos
	if locales.has(local_id):
		var local: Dictionary = locales[local_id]
		var price := local_price(local_id, barrio_id)
		var begin: Dictionary = start.duplicate(true)
		begin["local"] = LocalFactory.build(int(local["comedor"][0]), int(local["comedor"][1]))
		begin["dinero_inicial"] = NEW_GAME_MONEY - price
		begin["personal"] = _basic_crew(begin["personal"])
		data["start"] = begin
		data["local_comprado"] = { "id": local_id, "nombre": local["nombre"], "precio": price,
				"tasas_dia": roundf(price / TAX_DIVISOR) }
	return data


## Lo que cuesta un local en un barrio: el precio base por lo caro que sea el suelo allí.
func local_price(local_id: String, barrio_id: String) -> int:
	var base := float(locales[local_id]["precio"])
	var factor := float(barrios[barrio_id]["alquiler_dia"]) / 100.0 if barrios.has(barrio_id) else 1.0
	return roundi(base * factor / 500.0) * 500


## El camarero y el cocinero más baratos de la plantilla.
static func _basic_crew(all: Array) -> Array:
	var cheapest := {}
	for p in all:
		var role: String = p["puesto"]
		if not cheapest.has(role) or float(p["salario_dia"]) < float(cheapest[role]["salario_dia"]):
			cheapest[role] = p
	return cheapest.values()


## Comprueba que el contenido es coherente. Devuelve la lista de errores.
func validate() -> Array[String]:
	var errors: Array[String] = []
	for recipe_id in recipes:
		var recipe: Dictionary = recipes[recipe_id]
		for ingredient_id in recipe["ingredientes"]:
			if not ingredients.has(ingredient_id):
				errors.append("Receta '%s' usa ingrediente desconocido '%s'" % [recipe_id, ingredient_id])
	for item in start.get("carta", []):
		if not recipes.has(item["receta"]):
			errors.append("La carta incluye la receta desconocida '%s'" % item["receta"])
	for ingredient_id in start.get("stock_objetivo", {}):
		if not ingredients.has(ingredient_id):
			errors.append("Stock objetivo de ingrediente desconocido '%s'" % ingredient_id)
	for barrio_id in barrios:
		for profile_id in barrios[barrio_id]["poblacion"]:
			if not perfiles.has(profile_id):
				errors.append("Barrio '%s' tiene un perfil desconocido '%s'" % [barrio_id, profile_id])
	for profile_id in perfiles:
		for trait_id in perfiles[profile_id]["rasgos"]:
			if not rasgos.has(trait_id):
				errors.append("Perfil '%s' usa un rasgo desconocido '%s'" % [profile_id, trait_id])
		for recipe_id in perfiles[profile_id]["gustos"]:
			if not recipes.has(recipe_id):
				errors.append("Perfil '%s' le gusta una receta desconocida '%s'" % [profile_id, recipe_id])
	for local_id in locales:
		var size: Array = locales[local_id]["comedor"]
		if size.size() != 2 or int(size[1]) < LocalFactory.MIN_HEIGHT:
			errors.append("El local '%s' tiene un comedor con tamaño no válido" % local_id)
	for m in start.get("local", {}).get("muebles", []):
		if not muebles.has(m["tipo"]):
			errors.append("El local empieza con un mueble desconocido '%s'" % m["tipo"])
	return errors


static func _load_json(file_name: String) -> Variant:
	var path := DATA_DIR + file_name
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(path))
	if parsed == null:
		push_error("No se pudo leer %s" % path)
	return parsed


static func _by_id(entries: Variant) -> Dictionary:
	var by_id := {}
	if entries is Array:
		for entry in entries:
			by_id[entry["id"]] = entry
	return by_id
