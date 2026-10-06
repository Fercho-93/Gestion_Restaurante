class_name Satisfaction
extends RefCounted
## Satisfacción del cliente (0-100) a partir de sus componentes (cada uno 0-100).

const WEIGHTS := {
	"comida": 0.35,
	"tiempo": 0.20,
	"trato": 0.15,
	"ambiente": 0.10,
	"limpieza": 0.10,
	"calidad_precio": 0.10,
}


static func score(parts: Dictionary) -> float:
	var total := 0.0
	for k in WEIGHTS:
		total += WEIGHTS[k] * clampf(float(parts.get(k, 50.0)), 0.0, 100.0)
	return total


## 100 si se paga lo justo o menos; baja rápido al cobrar por encima de lo normal (más
## rápido aún para quien mira mucho el precio: `sensitivity` > 1).
static func value_for_money(paid: float, fair: float, sensitivity: float = 1.0) -> float:
	if paid <= 0.0:
		return 100.0
	var ratio := paid / fair
	return clampf(100.0 - (ratio - 1.0) * 150.0 * sensitivity, 0.0, 100.0)


## Puntuación tipo reseña: de 1 a 5 estrellas.
static func stars(value: float) -> int:
	return clampi(1 + int(value / 20.0), 1, 5)
