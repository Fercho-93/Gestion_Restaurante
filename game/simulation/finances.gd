class_name Finances
extends RefCounted
## Caja del restaurante y movimientos del día por categoría.

var money: float
var income: Dictionary = {}
var expenses: Dictionary = {}


func _init(initial_money: float) -> void:
	money = initial_money


func earn(category: String, amount: float) -> void:
	money += amount
	income[category] = income.get(category, 0.0) + amount


func spend(category: String, amount: float) -> void:
	money -= amount
	expenses[category] = expenses.get(category, 0.0) + amount


func total(entries: Dictionary) -> float:
	var sum := 0.0
	for k in entries:
		sum += entries[k]
	return sum


## Cierra el día: devuelve el resumen y empieza un día nuevo.
func close_day() -> Dictionary:
	var summary := {
		"ingresos": income.duplicate(),
		"gastos": expenses.duplicate(),
		"beneficio": total(income) - total(expenses),
		"dinero": money,
	}
	income.clear()
	expenses.clear()
	return summary
