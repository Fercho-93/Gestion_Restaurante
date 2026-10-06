class_name RestaurantLayout
extends RefCounted
## Distribución física del local: rejilla, zonas, mesas, puestos y caminos (A*).
## La calle ocupa las columnas negativas (x < 0), por donde llegan y se van los clientes.

const STREET_WIDTH := 3
## Huecos alrededor de una mesa según sus plazas.
const SEAT_OFFSETS := {
	2: [Vector2i(-1, 0), Vector2i(1, 0)],
	4: [Vector2i(-1, 0), Vector2i(1, 0), Vector2i(0, -1), Vector2i(0, 1)],
}


class Table:
	var id: int
	var cell: Vector2i
	var seats: Array[Vector2i] = []
	## Celda desde la que el camarero atiende la mesa.
	var service_cell: Vector2i
	## Grupo sentado (o reservado para sentarse): CustomerGroup o null si está libre.
	var group = null
	## Quedan platos sucios del grupo anterior: no se puede sentar nadie hasta recogerla.
	var dirty := false
	## Quien la está recogiendo ahora mismo (o null).
	var cleaner = null

	func capacity() -> int:
		return seats.size()


var size: Vector2i
## Rejilla completa, calle incluida.
var region: Rect2i
## Zonas: {nombre, rect: Rect2i, color: Color, bloqueada: bool}
var zones: Array[Dictionary] = []
var tables: Array[Table] = []
var spawn_cell: Vector2i
var queue_cells: Array[Vector2i] = []
var pass_cell: Vector2i
## Dónde se recibe a los clientes de la cola para acompañarlos a su mesa.
var reception_cell: Vector2i
## Dónde esperan los camareros cuando no tienen trabajo (uno por camarero).
var waiter_homes: Array[Vector2i] = []
var manager_home: Vector2i
## Objetos que el gestor puede usar: id -> {nombre, celda: Vector2i, uso: Vector2i}
var objects: Dictionary = {}
var cook_stations: Array[Vector2i] = []
var counter_cells: Array[Vector2i] = []
## Muebles que no se pueden atravesar (fogones, estanterías, plantas...).
var obstacles: Array[Vector2i] = []
var ambiente: float
var limpieza: float
## Rejilla de paso para todos: muebles, mesas y sillas son obstáculos. Las sillas
## (y la del ordenador) se abren solo para quien va a sentarse o se levanta de ellas.
var astar := AStarGrid2D.new()
## Celdas en las que uno se puede sentar: celda -> true
var _sittable := {}


func _init(d: Dictionary) -> void:
	size = v2i(d["tamano"])
	region = Rect2i(-STREET_WIDTH, 0, size.x + STREET_WIDTH, size.y)
	spawn_cell = v2i(d["aparicion"])
	pass_cell = v2i(d["pase"])
	reception_cell = v2i(d["recepcion"])
	for c in d["puestos_camareros"]:
		waiter_homes.append(v2i(c))
	manager_home = v2i(d["puesto_gestor"])
	for o in d.get("objetos", []):
		objects[o["id"]] = { "nombre": o["nombre"], "celda": v2i(o["celda"]), "uso": v2i(o["uso"]) }
	ambiente = float(d["ambiente"])
	limpieza = float(d["limpieza"])
	for c in d["cola"]:
		queue_cells.append(v2i(c))
	for c in d["puestos_cocina"]:
		cook_stations.append(v2i(c))
	for c in d["barra_cocina"]:
		counter_cells.append(v2i(c))
	for c in d.get("obstaculos", []):
		obstacles.append(v2i(c))
	# El fogón está junto a cada puesto de cocina.
	for c in cook_stations:
		obstacles.append(c + Vector2i(1, 0))
	for z in d["zonas"]:
		var r: Array = z["rect"]
		zones.append({
			"nombre": z["nombre"],
			"rect": Rect2i(int(r[0]), int(r[1]), int(r[2]), int(r[3])),
			"color": Color(z["color"]),
			"bloqueada": z.get("bloqueada", false),
		})
	for t in d["mesas"]:
		var table := Table.new()
		table.id = tables.size()
		table.cell = v2i(t["celda"])
		for offset in SEAT_OFFSETS[int(t["plazas"])]:
			table.seats.append(table.cell + offset)
		table.service_cell = table.cell + Vector2i(1, 1)
		tables.append(table)
	_build_navigation()


func _build_navigation() -> void:
	astar.region = region
	astar.cell_size = Vector2.ONE
	astar.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES
	astar.update()
	for zone in zones:
		if zone["bloqueada"]:
			astar.fill_solid_region(zone["rect"])
	for c in counter_cells + obstacles:
		astar.set_point_solid(c)
	for table in tables:
		astar.set_point_solid(table.cell)
		for seat in table.seats:
			_sittable[seat] = true
	for o in objects.values():
		astar.set_point_solid(o["celda"])
		_sittable[o["uso"]] = true
	for seat in _sittable:
		astar.set_point_solid(seat)
	# Quien pasa por la calle evita la fila de la cola (como haría la gente).
	for c in queue_cells:
		astar.set_point_weight_scale(c, 4.0)


## Camino de celdas (incluye el origen) esquivando muebles y las celdas `occupied`.
## Vacío si no hay camino.
func find_path(from: Vector2i, to: Vector2i, occupied: Array[Vector2i] = []) -> Array[Vector2i]:
	if not region.has_point(from) or not region.has_point(to):
		return []
	var changed: Array[Vector2i] = []
	# Se puede salir de una silla y llegar a una silla.
	for c in [from, to]:
		if _sittable.has(c) and astar.is_point_solid(c):
			astar.set_point_solid(c, false)
			changed.append(c)
	var blocked: Array[Vector2i] = []
	for c in occupied:
		if c != from and c != to and region.has_point(c) and not astar.is_point_solid(c):
			astar.set_point_solid(c)
			blocked.append(c)
	var path := astar.get_id_path(from, to)
	for c in blocked:
		astar.set_point_solid(c, false)
	for c in changed:
		astar.set_point_solid(c)
	return path


func is_sittable(cell: Vector2i) -> bool:
	return _sittable.has(cell)


## ¿Se puede estar de pie en esta celda? (no es mueble ni silla)
func can_stand(cell: Vector2i) -> bool:
	return region.has_point(cell) and not astar.is_point_solid(cell)


## Celda libre para estar de pie más cercana a `cell` (y, a igualdad, a `from`).
func nearest_free_cell(cell: Vector2i, from: Vector2i, occupied: Array[Vector2i] = []) -> Vector2i:
	if can_stand(cell) and not occupied.has(cell):
		return cell
	var best := cell
	var best_d := INF
	for dx in range(-3, 4):
		for dy in range(-3, 4):
			var c := cell + Vector2i(dx, dy)
			if not can_stand(c) or occupied.has(c):
				continue
			var d := Vector2(dx, dy).length() + Vector2(c - from).length() * 0.01
			if d < best_d:
				best = c
				best_d = d
	return best


func table_at(cell: Vector2i) -> Table:
	for t in tables:
		if t.cell == cell:
			return t
	return null


func zone_name_at(cell: Vector2i) -> String:
	if cell.x < 0:
		return "Calle"
	for zone in zones:
		if zone["rect"].has_point(cell):
			return zone["nombre"]
	return ""


static func v2i(a: Array) -> Vector2i:
	return Vector2i(int(a[0]), int(a[1]))
