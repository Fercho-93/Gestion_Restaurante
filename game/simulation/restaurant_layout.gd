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
var cook_stations: Array[Vector2i] = []
var counter_cells: Array[Vector2i] = []
var ambiente: float
var limpieza: float
var astar := AStarGrid2D.new()


func _init(d: Dictionary) -> void:
	size = v2i(d["tamano"])
	region = Rect2i(-STREET_WIDTH, 0, size.x + STREET_WIDTH, size.y)
	spawn_cell = v2i(d["aparicion"])
	pass_cell = v2i(d["pase"])
	waiter_home = v2i(d["puesto_camareros"])
	ambiente = float(d["ambiente"])
	limpieza = float(d["limpieza"])
	for c in d["cola"]:
		queue_cells.append(v2i(c))
	for c in d["puestos_cocina"]:
		cook_stations.append(v2i(c))
	for c in d["barra_cocina"]:
		counter_cells.append(v2i(c))
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
	for c in counter_cells:
		astar.set_point_solid(c)
	for table in tables:
		astar.set_point_solid(table.cell)


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
