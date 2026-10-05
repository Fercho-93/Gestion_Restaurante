extends Node
## Autoload "GameData": carga el contenido del juego desde los JSON de res://data.

const DATA_DIR := "res://data/"

## id -> diccionario con los datos del ingrediente.
var ingredients: Dictionary = {}
## id -> diccionario con los datos de la receta.
var recipes: Dictionary = {}


func _ready() -> void:
	load_all()


func load_all() -> void:
	ingredients = _load_by_id("ingredients.json")
	recipes = _load_by_id("recipes.json")
	for error in validate():
		push_error(error)


## Comprueba que el contenido es coherente. Devuelve la lista de errores.
func validate() -> Array[String]:
	var errors: Array[String] = []
	for recipe_id in recipes:
		var recipe: Dictionary = recipes[recipe_id]
		for ingredient_id in recipe["ingredientes"]:
			if not ingredients.has(ingredient_id):
				errors.append("Receta '%s' usa ingrediente desconocido '%s'" % [recipe_id, ingredient_id])
	return errors


static func _load_by_id(file_name: String) -> Dictionary:
	var path := DATA_DIR + file_name
	var text := FileAccess.get_file_as_string(path)
	var parsed = JSON.parse_string(text)
	if not parsed is Array:
		push_error("No se pudo leer %s" % path)
		return {}
	var by_id := {}
	for entry in parsed:
		by_id[entry["id"]] = entry
	return by_id
