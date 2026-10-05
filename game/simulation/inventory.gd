class_name Inventory
extends RefCounted
## Existencias de materias primas (cantidad por ingrediente, en su unidad).

var stock: Dictionary = {}


func amount(ingredient_id: String) -> float:
	return stock.get(ingredient_id, 0.0)


func can_make(recipe: Dictionary) -> bool:
	var parts: Dictionary = recipe["ingredientes"]
	for ingredient_id in parts:
		if amount(ingredient_id) < float(parts[ingredient_id]):
			return false
	return true


func consume(recipe: Dictionary) -> void:
	var parts: Dictionary = recipe["ingredientes"]
	for ingredient_id in parts:
		stock[ingredient_id] = amount(ingredient_id) - float(parts[ingredient_id])


## Compra lo que falte hasta llegar a las cantidades objetivo. Devuelve el coste.
func restock_to(targets: Dictionary, ingredients: Dictionary) -> float:
	var cost := 0.0
	for ingredient_id in targets:
		var missing := float(targets[ingredient_id]) - amount(ingredient_id)
		if missing > 0.0:
			stock[ingredient_id] = amount(ingredient_id) + missing
			cost += missing * float(ingredients[ingredient_id]["precio_base"])
	return cost
