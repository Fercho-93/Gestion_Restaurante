class_name LocalFactory
extends RefCounted
## Genera la distribución de un local a partir del tamaño de su comedor.
## El comedor queda a la izquierda y a la derecha una columna de 4 casillas con la cocina,
## el almacén y el despacho. Todos los locales tienen los mismos puestos y caminos, solo
## cambia el tamaño: el comedor viene vacío, sin mesas ni decoración.

const BACK_WIDTH := 4
const MIN_HEIGHT := 8


## `comedor_w` x `alto` casillas de comedor; el local mide `comedor_w + 4` de ancho.
static func build(comedor_w: int, alto: int) -> Dictionary:
	var h := maxi(alto, MIN_HEIGHT)
	var kh := h - 4
	var queue: Array = []
	for i in 6:
		queue.append([-1, h - 2 - i])
	var counter: Array = []
	for y in kh - 1:
		counter.append([comedor_w, y])
	return {
		"tamano": [comedor_w + BACK_WIDTH, h],
		"ambiente": 50,
		"limpieza": 70,
		"zonas": [
			{ "nombre": "Comedor", "rect": [0, 0, comedor_w, h], "color": "e9c79a", "construible": true },
			{ "nombre": "Cocina", "rect": [comedor_w, 0, BACK_WIDTH, kh], "color": "b9d4d8" },
			{ "nombre": "Almacén", "rect": [comedor_w, kh, BACK_WIDTH, 2], "color": "c9c0b4", "bloqueada": true },
			{ "nombre": "Despacho", "rect": [comedor_w, h - 2, BACK_WIDTH, 2], "color": "d9bf9b", "construible": true },
		],
		"objetos": [
			{ "id": "ordenador", "nombre": "Ordenador", "celda": [comedor_w + 2, h - 1], "uso": [comedor_w + 1, h - 1] },
			{ "id": "cafetera", "nombre": "Cafetera", "celda": [comedor_w, 1], "uso": [comedor_w - 1, 1], "sentado": false },
		],
		"muebles": [],
		"barra_cocina": counter,
		"puerta_cocina": [comedor_w, kh - 1],
		"obstaculos": [[comedor_w + 3, h - 2], [comedor_w + 3, h - 1]],
		"pase": [comedor_w - 1, 2],
		"recepcion": [0, h - 2],
		"puestos_camareros": [[comedor_w - 1, 0], [comedor_w - 2, 0], [comedor_w - 1, h - 1], [maxi(1, comedor_w - 5), 0]],
		"puesto_gestor": [comedor_w - 2, h - 3],
		"puestos_cocina": [[comedor_w + 1, 1], [comedor_w + 1, kh - 2]],
		"aparicion": [-2, h - 1],
		"cola": queue,
	}
