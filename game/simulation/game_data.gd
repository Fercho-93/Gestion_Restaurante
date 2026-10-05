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


func _ready() -> void:
	load_all()


func load_all() -> void:
	ingredients = _by_id(_load_json("ingredients.json"))
	recipes = _by_id(_load_json("recipes.json"))
	start = _load_json("restaurant_start.json")
	demand = _load_json("demand.json")
	for error in validate():
		push_error(error)


## Todo lo que necesita RestaurantSim para arrancar.
func sim_data() -> Dictionary:
	return { "ingredients": ingredients, "recipes": recipes, "start": start, "demand": demand }


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
