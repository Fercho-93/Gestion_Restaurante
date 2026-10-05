class_name Demand
extends RefCounted
## Cuántos clientes llegan y cómo son.

## Hora (0-23) -> grupos que llegan por hora con reputación media.
var groups_per_hour: Dictionary = {}
## [[tamaño, peso], ...]
var size_weights: Array = []


func _init(d: Dictionary) -> void:
	for h in d["grupos_por_hora"]:
		groups_per_hour[int(h)] = float(d["grupos_por_hora"][h])
	size_weights = d["tamano_grupo"]


## Grupos que llegan en un paso de `minutes` minutos (pasos cortos: 0 o 1).
func arrivals(hour: int, minutes: float, multiplier: float, rng: RandomNumberGenerator) -> int:
	var expected: float = groups_per_hour.get(hour, 0.0) / 60.0 * minutes * multiplier
	return 1 if rng.randf() < expected else 0


func random_size(rng: RandomNumberGenerator) -> int:
	var total := 0.0
	for entry in size_weights:
		total += float(entry[1])
	var roll := rng.randf() * total
	for entry in size_weights:
		roll -= float(entry[1])
		if roll <= 0.0:
			return int(entry[0])
	return int(size_weights[-1][0])
