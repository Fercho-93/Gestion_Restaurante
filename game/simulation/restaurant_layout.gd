class_name RestaurantLayout
extends RefCounted
## Distribución física del local: rejilla, zonas, mesas, puestos y caminos (A*).
## La calle ocupa las columnas negativas (x < 0), por donde llegan y se van los clientes.
## Los muebles (mesas y decoración) se pueden comprar, mover, girar y vender en el modo
## construcción: cada cambio rehace las mesas, los caminos y el ambiente del local.

const STREET_WIDTH := 3
## Huecos alrededor de una mesa según sus plazas.
const SEAT_OFFSETS := {
	2: [Vector2i(-1, 0), Vector2i(1, 0)],
	4: [Vector2i(-1, 0), Vector2i(1, 0), Vector2i(0, -1), Vector2i(0, 1)],
}


class Table:
	var id: int
	## Mueble del que sale esta mesa.
	var uid: int
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
## Ambiente del local (0-100): el del local vacío más lo que aporta cada mueble.
var ambiente: float
var ambiente_base: float
var limpieza: float
## Catálogo de muebles: id -> datos (de muebles.json).
var catalog: Dictionary = {}
## Muebles colocados: {uid, tipo, celda: Vector2i, rot: 0-3}
var furniture: Array[Dictionary] = []
var kitchen_door := Vector2i(-999, -999)
## Celdas donde se pueden poner muebles: celda -> true
var buildable := {}
## Celdas que deben quedar libres (puestos, pase, recepción, usos de objetos...): celda -> true
var reserved := {}
var _fixed_obstacles: Array[Vector2i] = []
var _next_uid := 1
## Rejilla de paso para todos: muebles, mesas y sillas son obstáculos. Las sillas
## (y la del ordenador) se abren solo para quien va a sentarse o se levanta de ellas.
var astar := AStarGrid2D.new()
## Celdas en las que uno se puede sentar: celda -> true
var _sittable := {}


func _init(d: Dictionary, furniture_catalog: Dictionary = {}) -> void:
	catalog = furniture_catalog
	size = v2i(d["tamano"])
	region = Rect2i(-STREET_WIDTH, 0, size.x + STREET_WIDTH, size.y)
	spawn_cell = v2i(d["aparicion"])
	pass_cell = v2i(d["pase"])
	reception_cell = v2i(d["recepcion"])
	for c in d["puestos_camareros"]:
		waiter_homes.append(v2i(c))
	manager_home = v2i(d["puesto_gestor"])
	for o in d.get("objetos", []):
		objects[o["id"]] = { "nombre": o["nombre"], "celda": v2i(o["celda"]), "uso": v2i(o["uso"]),
				"sentado": o.get("sentado", true) }
	ambiente_base = float(d["ambiente"])
	ambiente = ambiente_base
	if d.has("puerta_cocina"):
		kitchen_door = v2i(d["puerta_cocina"])
	limpieza = float(d["limpieza"])
	for c in d["cola"]:
		queue_cells.append(v2i(c))
	for c in d["puestos_cocina"]:
		cook_stations.append(v2i(c))
	for c in d["barra_cocina"]:
		counter_cells.append(v2i(c))
	for c in d.get("obstaculos", []):
		_fixed_obstacles.append(v2i(c))
	# El fogón está junto a cada puesto de cocina.
	for c in cook_stations:
		_fixed_obstacles.append(c + Vector2i(1, 0))
	for z in d["zonas"]:
		var r: Array = z["rect"]
		zones.append({
			"nombre": z["nombre"],
			"rect": Rect2i(int(r[0]), int(r[1]), int(r[2]), int(r[3])),
			"color": Color(z["color"]),
			"bloqueada": z.get("bloqueada", false),
			"construible": z.get("construible", false),
		})
	_find_buildable_cells()
	for m in d.get("muebles", []):
		furniture.append({ "uid": _next_uid, "tipo": m["tipo"], "celda": v2i(m["celda"]), "rot": int(m.get("rot", 0)) })
		_next_uid += 1
	# Partidas antiguas: mesas sin catálogo de muebles.
	for t in d.get("mesas", []):
		var tipo := "mesa_%d" % int(t["plazas"])
		if not catalog.has(tipo):
			catalog[tipo] = { "id": tipo, "nombre": "Mesa", "tipo": "mesa", "plazas": int(t["plazas"]), "precio": 0, "ambiente": 0 }
		furniture.append({ "uid": _next_uid, "tipo": tipo, "celda": v2i(t["celda"]), "rot": 0 })
		_next_uid += 1
	_rebuild()


func _find_buildable_cells() -> void:
	for c in [pass_cell, reception_cell, manager_home, kitchen_door, spawn_cell]:
		reserved[c] = true
	for c in waiter_homes + queue_cells:
		reserved[c] = true
	for o in objects.values():
		reserved[o["celda"]] = true
		reserved[o["uso"]] = true
	for zone in zones:
		if not zone["construible"]:
			continue
		var rect: Rect2i = zone["rect"]
		for x in range(rect.position.x, rect.end.x):
			for y in range(rect.position.y, rect.end.y):
				var c := Vector2i(x, y)
				if not counter_cells.has(c) and not _fixed_obstacles.has(c) and not reserved.has(c):
					buildable[c] = true


# --- Muebles -------------------------------------------------------------------

## Gira una celda relativa un cuarto de vuelta `rot` veces.
static func rotate_cell(c: Vector2i, rot: int) -> Vector2i:
	for i in posmod(rot, 4):
		c = Vector2i(-c.y, c.x)
	return c


## Celdas que ocupa un mueble: {solid: celdas que bloquea, seats: sillas de las mesas}.
func footprint(tipo: String, cell: Vector2i, rot: int) -> Dictionary:
	var def: Dictionary = catalog.get(tipo, {})
	var solid: Array[Vector2i] = []
	var seats: Array[Vector2i] = []
	for c in def.get("huella", [[0, 0]]):
		solid.append(cell + rotate_cell(v2i(c), rot))
	if def.get("tipo", "") == "mesa":
		for offset in SEAT_OFFSETS[int(def["plazas"])]:
			seats.append(cell + rotate_cell(offset, rot))
	return { "solid": solid, "seats": seats }


func furniture_by_uid(uid: int) -> Dictionary:
	for f in furniture:
		if f["uid"] == uid:
			return f
	return {}


## Mueble que ocupa esta celda (contando las sillas de las mesas), o {}.
func furniture_at(cell: Vector2i) -> Dictionary:
	for f in furniture:
		var fp := footprint(f["tipo"], f["celda"], f["rot"])
		if fp["solid"].has(cell) or fp["seats"].has(cell):
			return f
	return {}


## ¿Se puede poner (o mover) este mueble aquí? Devuelve "" si sí, o el motivo si no.
## `ignore_uid` es el mueble que se está moviendo; `people`, celdas con gente encima.
func placement_problem(tipo: String, cell: Vector2i, rot: int, ignore_uid: int = -1, people: Array[Vector2i] = []) -> String:
	if not catalog.has(tipo):
		return "Mueble desconocido"
	var fp := footprint(tipo, cell, rot)
	var taken := {}
	for f in furniture:
		if f["uid"] == ignore_uid:
			continue
		var other := footprint(f["tipo"], f["celda"], f["rot"])
		for c in other["solid"] + other["seats"]:
			taken[c] = true
	for c in fp["solid"] + fp["seats"]:
		if not buildable.has(c):
			return "Aquí no se puede poner" if not reserved.has(c) else "Ese sitio tiene que quedar libre"
		if taken.has(c):
			return "Choca con otro mueble"
		if people.has(c):
			return "Hay alguien en medio"
	# Se prueba de verdad: todo el local tiene que seguir siendo accesible.
	var saved := furniture.duplicate(true)
	var moving := furniture_by_uid(ignore_uid)
	if not moving.is_empty():
		moving["celda"] = cell
		moving["rot"] = rot
	else:
		furniture.append({ "uid": -1, "tipo": tipo, "celda": cell, "rot": rot })
	_rebuild()
	var problem := accessibility_problem()
	furniture.assign(saved)
	_rebuild()
	return problem


## ¿Queda todo el local accesible? (mesas, sillas, pase, puestos, objetos...) "" si sí.
func accessibility_problem() -> String:
	var from := reception_cell
	var must_reach: Array[Vector2i] = [pass_cell, manager_home]
	if kitchen_door != Vector2i(-999, -999):
		must_reach.append(kitchen_door)
	must_reach.append_array(waiter_homes)
	for o in objects.values():
		must_reach.append(o["uso"])
	for c in must_reach:
		if find_path(from, c).is_empty():
			return "Cortaría el paso por el local"
	for t in tables:
		if t.service_cell == Vector2i(-999, -999):
			return "No quedaría hueco para atender la mesa"
		if find_path(from, t.service_cell).is_empty():
			return "No se podría llegar a una mesa"
		for seat in t.seats:
			if find_path(from, seat).is_empty():
				return "No se podría llegar a una silla"
	return ""


## Añade un mueble sin comprobar nada (para eso está placement_problem). Devuelve su uid.
func add_furniture(tipo: String, cell: Vector2i, rot: int = 0) -> int:
	var uid := _next_uid
	_next_uid += 1
	furniture.append({ "uid": uid, "tipo": tipo, "celda": cell, "rot": posmod(rot, 4) })
	_rebuild()
	return uid


func move_furniture(uid: int, cell: Vector2i, rot: int) -> void:
	var f := furniture_by_uid(uid)
	if f.is_empty():
		return
	f["celda"] = cell
	f["rot"] = posmod(rot, 4)
	_rebuild()


func remove_furniture(uid: int) -> void:
	furniture = furniture.filter(func(f: Dictionary): return f["uid"] != uid)
	_rebuild()


## La mesa que sale de un mueble (o null si no es una mesa).
func table_for(uid: int) -> Table:
	for t in tables:
		if t.uid == uid:
			return t
	return null


## Rehace mesas, obstáculos, caminos y ambiente a partir de los muebles.
## Las mesas que siguen existiendo conservan su estado (grupo, sucia...).
func _rebuild() -> void:
	var old := {}
	for t in tables:
		old[t.uid] = t
	tables.clear()
	obstacles = _fixed_obstacles.duplicate()
	ambiente = ambiente_base
	for f in furniture:
		var def: Dictionary = catalog.get(f["tipo"], {})
		ambiente += float(def.get("ambiente", 0))
		var fp := footprint(f["tipo"], f["celda"], f["rot"])
		if def.get("tipo", "") == "mesa":
			var table: Table = old.get(f["uid"], Table.new())
			table.uid = f["uid"]
			table.id = tables.size()
			table.cell = f["celda"]
			table.seats.assign(fp["seats"])
			tables.append(table)
		else:
			obstacles.append_array(fp["solid"])
	ambiente = clampf(ambiente, 0.0, 100.0)
	_build_navigation()
	for t in tables:
		t.service_cell = _service_cell_for(t)


## Celda junto a la mesa desde la que el camarero atiende (de pie, sin ser una silla).
func _service_cell_for(t: Table) -> Vector2i:
	for d in [Vector2i(1, 1), Vector2i(-1, 1), Vector2i(1, -1), Vector2i(-1, -1),
			Vector2i(0, 1), Vector2i(0, -1), Vector2i(1, 0), Vector2i(-1, 0)]:
		var c: Vector2i = t.cell + d
		if c.x >= 0 and can_stand(c):
			return c
	return Vector2i(-999, -999)


func _build_navigation() -> void:
	_sittable.clear()
	astar = AStarGrid2D.new()
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
		if o["sentado"]:
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
