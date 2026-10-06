class_name RestaurantLayout
extends RefCounted
## Distribución física del local: rejilla, zonas, mesas, puestos y caminos (A*).
## La calle ocupa las columnas negativas (x < 0), por donde llegan y se van los clientes.

const STREET_WIDTH := 2
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
	## Grupo sentado (CustomerGroup) o null si está libre.
	var group = null

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
var waiter_home: Vector2i
var manager_home: Vector2i
## Objetos que el gestor puede usar: id -> {nombre, celda: Vector2i, uso: Vector2i}
var objects: Dictionary = {}
var cook_stations: Array[Vector2i] = []
var counter_cells: Array[Vector2i] = []
## Muebles que no se pueden atravesar (fogones, estanterías, plantas...).
var obstacles: Array[Vector2i] = []
var ambiente: float
var limpieza: float
var astar := AStarGrid2D.new()
## Rejilla del gestor: además de lo anterior, las sillas también son obstáculos
## (los clientes sí necesitan llegar a ellas para sentarse).
var manager_astar := AStarGrid2D.new()


func _init(d: Dictionary) -> void:
	size = v2i(d["tamano"])
	region = Rect2i(-STREET_WIDTH, 0, size.x + STREET_WIDTH, size.y)
	spawn_cell = v2i(d["aparicion"])
	pass_cell = v2i(d["pase"])
	waiter_home = v2i(d["puesto_camareros"])
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
	for grid in [astar, manager_astar]:
		grid.region = region
		grid.cell_size = Vector2.ONE
		grid.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES
		grid.update()
		for zone in zones:
			if zone["bloqueada"]:
				grid.fill_solid_region(zone["rect"])
		for c in counter_cells + obstacles:
			grid.set_point_solid(c)
		for table in tables:
			grid.set_point_solid(table.cell)
		for o in objects.values():
			grid.set_point_solid(o["celda"])
	for table in tables:
		for seat in table.seats:
			manager_astar.set_point_solid(seat)
	# La silla del ordenador: el gestor sí se sienta en ella.
	for o in objects.values():
		manager_astar.set_point_solid(o["uso"], false)


## Camino del gestor esquivando muebles y las celdas ocupadas por personas.
## Vacío si no hay camino.
func manager_path(from: Vector2i, to: Vector2i, occupied: Array[Vector2i] = []) -> Array[Vector2i]:
	if not region.has_point(from) or not region.has_point(to):
		return []
	var blocked: Array[Vector2i] = []
	for c in occupied:
		if c != from and c != to and region.has_point(c) and not manager_astar.is_point_solid(c):
			manager_astar.set_point_solid(c)
			blocked.append(c)
	var path := manager_astar.get_id_path(from, to)
	for c in blocked:
		manager_astar.set_point_solid(c, false)
	return path


func manager_can_stand(cell: Vector2i) -> bool:
	return region.has_point(cell) and not manager_astar.is_point_solid(cell)


## Celda libre para el gestor más cercana a `cell` (y, a igualdad, a `from`).
func nearest_manager_cell(cell: Vector2i, from: Vector2i, occupied: Array[Vector2i] = []) -> Vector2i:
	if manager_can_stand(cell) and not occupied.has(cell):
		return cell
	var best := cell
	var best_d := INF
	for dx in range(-3, 4):
		for dy in range(-3, 4):
			var c := cell + Vector2i(dx, dy)
			if not manager_can_stand(c) or occupied.has(c):
				continue
			var d := Vector2(dx, dy).length() + Vector2(c - from).length() * 0.01
			if d < best_d:
				best = c
				best_d = d
	return best


## Camino de celdas entre dos puntos (incluye el origen). Vacío si no hay camino.
func find_path(from: Vector2i, to: Vector2i) -> Array[Vector2i]:
	if not region.has_point(from) or not region.has_point(to):
		return []
	return astar.get_id_path(from, to)


func is_walkable(cell: Vector2i) -> bool:
	return region.has_point(cell) and not astar.is_point_solid(cell)


func zone_name_at(cell: Vector2i) -> String:
	if cell.x < 0:
		return "Calle"
	for zone in zones:
		if zone["rect"].has_point(cell):
			return zone["nombre"]
	return ""


static func v2i(a: Array) -> Vector2i:
	return Vector2i(int(a[0]), int(a[1]))
