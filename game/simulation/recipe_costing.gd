class_name RecipeCosting
extends RefCounted
## Escandallo: coste de materia prima de una receta y márgenes.


## Coste de una receta según los precios de los ingredientes (precio por unidad).
static func cost(recipe: Dictionary, ingredients: Dictionary) -> float:
	var total := 0.0
	var parts: Dictionary = recipe["ingredientes"]
	for ingredient_id in parts:
		total += float(parts[ingredient_id]) * float(ingredients[ingredient_id]["precio_base"])
	return total


## Porcentaje del precio de venta que se va en materia prima (0-1).
static func food_cost_ratio(recipe_cost: float, sale_price: float) -> float:
	return recipe_cost / sale_price if sale_price > 0.0 else 1.0


static func margin(recipe_cost: float, sale_price: float) -> float:
	return sale_price - recipe_cost
