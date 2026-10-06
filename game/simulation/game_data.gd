extends Node
## Autoload "GameData": carga el contenido del juego desde los JSON de res://data.

const DATA_DIR := "res://data/"

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
	for error in validate():
		push_error(error)


## Todo lo que necesita RestaurantSim para arrancar. Con un barrio, la clientela son sus
## vecinos; sin él, clientes anónimos con la demanda genérica.
func sim_data(barrio_id: String = "") -> Dictionary:
	var data := { "ingredients": ingredients, "recipes": recipes, "start": start, "demand": demand, "muebles": muebles }
	if barrios.has(barrio_id):
		data["barrio"] = barrios[barrio_id]
		data["perfiles"] = perfiles
		data["rasgos"] = rasgos
	return data


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
