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
## Limpieza del local: la base más lo que aportan los suelos.
var limpieza: float
var limpieza_base: float
## Catálogo de muebles: id -> datos (de muebles.json).
var catalog: Dictionary = {}
## Muebles colocados: {uid, tipo, celda: Vector2i, rot: 0-3}
var furniture: Array[Dictionary] = []
var kitchen_door := Vector2i(-999, -999)
## Acabados: suelos (celda -> id del material) y paredes (clave -> {estilo, abertura, adorno}).
## Las paredes son la del fondo ("N" + columna) y la de la fachada a la calle ("O" + fila,
## salvo la puerta). Son solo decoración: no cambian por dónde pasa la gente.
var floor_catalog: Dictionary = {}
var wall_catalog: Dictionary = {}
var floors := {}
var walls := {}
## Paredes interiores (tabiques) y puertas: celda -> "pared" o "puerta". Las paredes ocupan
## su casilla y no se atraviesan; las puertas sí.
var inner_walls := {}
## Filas de la fachada que son la puerta (no se pueden editar).
var door_rows: Array[int] = []
## Habitaciones: tipos (de habitaciones.json) y las creadas {id, tipo, rect: Rect2i}.
var room_types: Dictionary = {}
var rooms: Array[Dictionary] = []
var _next_room_id := 1
## Objetos que trae el local de fábrica (la cafetera); el resto salen de los muebles.
var _fixed_objects := {}
## Taburetes colocados.
var stools: Array[Vector2i] = []
var _furniture_ambience := 0.0
var _ref_floor_ambience := 0.0
var _ref_floor_cleanliness := 0.0
var _ref_wall_ambience := 0.0
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


const DEFAULT_FLOORS := { "Comedor": "vinilico", "Cocina": "cocina", "Almacén": "cocina", "Despacho": "oficina" }
const DEFAULT_WALL := "crema"
const DEFAULT_WINDOW := "ventana"
const WALL_HEIGHT := 1.6


## `finishes`: {suelos: id -> datos, paredes: {estilos, aberturas, adornos}} (de los JSON).
func _init(d: Dictionary, furniture_catalog: Dictionary = {}, finishes: Dictionary = {}) -> void:
	catalog = furniture_catalog
	floor_catalog = finishes.get("suelos", {})
	wall_catalog = finishes.get("paredes", {})
	room_types = finishes.get("habitaciones", {})
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
	_fixed_objects = objects.duplicate(true)
	ambiente_base = float(d["ambiente"])
	ambiente = ambiente_base
	if d.has("puerta_cocina"):
		kitchen_door = v2i(d["puerta_cocina"])
	limpieza = float(d["limpieza"])
	limpieza_base = limpieza
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
	_init_finishes()
	_init_rooms()
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
	# Lo que cuelga del techo no ocupa el suelo.
	for c in (def.get("huella", [[0, 0]]) if not def.get("techo", false) else []):
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
	var all := furniture_all_at(cell)
	return all[0] if not all.is_empty() else {}


## Todos los muebles de esta celda: el de abajo y lo que cuelga del techo encima.
func furniture_all_at(cell: Vector2i) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for f in furniture:
		var fp := footprint(f["tipo"], f["celda"], f["rot"])
		if fp["solid"].has(cell) or fp["seats"].has(cell) or (catalog.get(f["tipo"], {}).get("techo", false) and f["celda"] == cell):
			out.append(f)
	return out


## ¿Se puede poner (o mover) este mueble aquí? Devuelve "" si sí, o el motivo si no.
## `ignore_uid` es el mueble que se está moviendo; `people`, celdas con gente encima.
func placement_problem(tipo: String, cell: Vector2i, rot: int, ignore_uid: int = -1, people: Array[Vector2i] = []) -> String:
	if not catalog.has(tipo):
		return "Mueble desconocido"
	var fp := footprint(tipo, cell, rot)
	if catalog[tipo].get("techo", false):
		# Colgar algo del techo: vale cualquier casilla del comedor o del despacho.
		if not buildable.has(cell) and not _is_hangable(cell):
			return "Aquí no se puede colgar"
		return ""
	var def: Dictionary = catalog[tipo]
	if def.get("solo_en", "") != "":
		for c in fp["solid"]:
			var room := room_at(c)
			if room.is_empty() or room["tipo"] != def["solo_en"]:
				return "Esto va dentro de %s" % room_types.get(def["solo_en"], {}).get("dentro_de", "una habitación")
	elif def.get("tipo", "") == "mesa":
		for c in fp["solid"] + fp["seats"]:
			if not room_at(c).is_empty():
				return "Las mesas van en el comedor, no en una habitación"
	for c in fp["solid"] + fp["seats"]:
		if inner_walls.has(c):
			return "Ahí hay una pared"
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
	must_reach.append_array(use_cells())
	must_reach.append_array(stools)
	must_reach.append_array(bar_posts())
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
	_furniture_ambience = 0.0
	stools.clear()
	objects = _fixed_objects.duplicate(true)
	for f in furniture:
		var def: Dictionary = catalog.get(f["tipo"], {})
		_furniture_ambience += float(def.get("ambiente", 0))
		if def.get("taburete", false):
			stools.append(f["celda"])
		if def.has("objeto"):
			# Un mueble que el gestor puede usar (el ordenador): se sienta en la casilla de uso.
			objects[def["objeto"]] = { "nombre": def["nombre"], "celda": f["celda"],
					"uso": f["celda"] + rotate_cell(v2i(def["uso"]), f["rot"]), "sentado": true }
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
	_recompute_finish_effects()
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
	for c in inner_walls:
		if inner_walls[c] == "pared":
			astar.set_point_solid(c)
	for table in tables:
		astar.set_point_solid(table.cell)
		for seat in table.seats:
			_sittable[seat] = true
	for o in objects.values():
		astar.set_point_solid(o["celda"])
		if o["sentado"]:
			_sittable[o["uso"]] = true
	for c in stools:
		_sittable[c] = true
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


# --- Acabados: suelos y paredes ------------------------------------------------------------

func _is_hangable(cell: Vector2i) -> bool:
	for zone in zones:
		if zone["rect"].has_point(cell) and not zone["bloqueada"] and zone["nombre"] != "Cocina":
			return true
	return false


func _init_finishes() -> void:
	if floor_catalog.is_empty():
		return
	for zone in zones:
		var id: String = DEFAULT_FLOORS.get(zone["nombre"], "vinilico")
		if not floor_catalog.has(id):
			continue
		var r: Rect2i = zone["rect"]
		for x in range(r.position.x, r.end.x):
			for y in range(r.position.y, r.end.y):
				floors[Vector2i(x, y)] = id
	var style := DEFAULT_WALL if wall_catalog.get("estilos", {}).has(DEFAULT_WALL) else ""
	if style == "":
		return
	door_rows.clear()
	for dy in range(-1, 2):
		door_rows.append(maxi(reception_cell.y + dy, 0))
	for x in size.x:
		walls["N%d" % x] = { "estilo": style, "abertura": "", "adorno": "" }
		if wall_catalog["aberturas"].has(DEFAULT_WINDOW) and x % 3 == 1 and absf(x - size.x * 0.55) > 2.2:
			walls["N%d" % x]["abertura"] = DEFAULT_WINDOW
	# La fachada es una cristalera: deja ver la calle y la cola desde dentro.
	var shopfront := "ventanal" if wall_catalog["aberturas"].has("ventanal") else ""
	for z in size.y:
		if not door_rows.has(z):
			walls["O%d" % z] = { "estilo": style, "abertura": shopfront, "adorno": "" }
	var ambience := _wall_ambience()
	_ref_wall_ambience = ambience
	_ref_floor_ambience = _floor_ambience()
	_ref_floor_cleanliness = _floor_cleanliness()


## ¿Se puede pintar esta casilla? (solo el interior, no el almacén)
func floor_paintable(cell: Vector2i) -> bool:
	if not floors.has(cell):
		return false
	for zone in zones:
		if zone["rect"].has_point(cell):
			return not zone["bloqueada"]
	return false


## Cambia el suelo de estas casillas (las no pintables se ignoran). Devuelve cuántas cambian.
func set_floor(cells: Array, material: String) -> int:
	var changed := 0
	for c in cells:
		if floor_paintable(c) and floors[c] != material:
			floors[c] = material
			changed += 1
	if changed > 0:
		_recompute_finish_effects()
	return changed


## Casillas que cambiarían de material si se pintaran con `material`.
func floor_changes(cells: Array, material: String) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for c in cells:
		if floor_paintable(c) and floors[c] != material:
			out.append(c)
	return out


## Todas las casillas pintables de la zona (comedor, cocina o despacho) que contiene `cell`.
func zone_floor_cells(cell: Vector2i) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for zone in zones:
		if zone["rect"].has_point(cell) and not zone["bloqueada"]:
			var r: Rect2i = zone["rect"]
			for x in range(r.position.x, r.end.x):
				for y in range(r.position.y, r.end.y):
					out.append(Vector2i(x, y))
	return out


## Segmentos de pared de un lado ("N" o "O") en orden.
func wall_keys(side: String) -> Array[String]:
	var out: Array[String] = []
	var count := size.x if side == "N" else size.y
	for i in count:
		if walls.has("%s%d" % [side, i]):
			out.append("%s%d" % [side, i])
	return out


## Por qué no se puede poner `id` en la parte `part` ("estilo", "abertura" o "adorno") de este
## segmento. "" si se puede; con id "" se quita lo que haya.
func wall_problem(key: String, part: String, id: String) -> String:
	if not walls.has(key):
		return "Ahí no se puede" if not (key.begins_with("O") and door_rows.has(int(key.substr(1)))) else "Es la puerta del local"
	var seg: Dictionary = walls[key]
	if id == "":
		return "No hay nada que quitar" if part == "estilo" or seg[part] == "" else ""
	if seg[part] == id:
		return "Ya está puesto"
	if part == "abertura" and seg["adorno"] != "":
		return "Quita antes lo que cuelga de esa pared"
	if part == "adorno" and seg["abertura"] != "":
		return "Ahí hay una ventana"
	return ""


func set_wall_part(key: String, part: String, id: String) -> void:
	if not walls.has(key):
		return
	walls[key][part] = id
	_recompute_finish_effects()


## Aportación de los suelos: ambiente medio del comedor y limpieza media de todo el local,
## respecto a como viene de serie.
func _floor_ambience() -> float:
	var total := 0.0
	var count := 0
	for zone in zones:
		if zone["nombre"] != "Comedor":
			continue
		var r: Rect2i = zone["rect"]
		for x in range(r.position.x, r.end.x):
			for y in range(r.position.y, r.end.y):
				total += float(floor_catalog.get(floors.get(Vector2i(x, y), ""), {}).get("ambiente", 0))
				count += 1
	return total / count if count > 0 else 0.0


func _floor_cleanliness() -> float:
	var total := 0.0
	var count := 0
	for c in floors:
		if floor_paintable(c):
			total += float(floor_catalog.get(floors[c], {}).get("limpieza", 0))
			count += 1
	return total / count if count > 0 else 0.0


func _wall_ambience() -> float:
	var styles: Dictionary = wall_catalog.get("estilos", {})
	var total := 0.0
	var style_total := 0.0
	for key in walls:
		var seg: Dictionary = walls[key]
		style_total += float(styles.get(seg["estilo"], {}).get("ambiente", 0))
		total += float(wall_catalog.get("aberturas", {}).get(seg["abertura"], {}).get("ambiente", 0))
		total += float(wall_catalog.get("adornos", {}).get(seg["adorno"], {}).get("ambiente", 0))
	# El estilo cuenta como media de la pared (hasta +3 con todo de lo mejor).
	return total + (style_total / walls.size() if not walls.is_empty() else 0.0)


func _recompute_finish_effects() -> void:
	var extra := 0.0
	var clean := 0.0
	if not floor_catalog.is_empty():
		extra = (_floor_ambience() - _ref_floor_ambience) + (_wall_ambience() - _ref_wall_ambience)
		clean = _floor_cleanliness() - _ref_floor_cleanliness
	ambiente = clampf(ambiente_base + _furniture_ambience + extra, 0.0, 100.0)
	limpieza = clampf(limpieza_base + clean, 0.0, 100.0)


# --- Habitaciones --------------------------------------------------------------------------

## El despacho de fábrica es una habitación más.
func _init_rooms() -> void:
	if not room_types.has("despacho"):
		return
	for zone in zones:
		if zone["nombre"] == "Despacho":
			rooms.append({ "id": _next_room_id, "tipo": "despacho", "rect": zone["rect"] })
			_next_room_id += 1


## La habitación que contiene esta casilla, o {}.
func room_at(cell: Vector2i) -> Dictionary:
	for r in rooms:
		if r["rect"].has_point(cell):
			return r
	return {}


func rooms_of(tipo: String) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for r in rooms:
		if r["tipo"] == tipo:
			out.append(r)
	return out


static func rect_between(a: Vector2i, b: Vector2i) -> Rect2i:
	var top_left := Vector2i(mini(a.x, b.x), mini(a.y, b.y))
	return Rect2i(top_left, Vector2i(absi(a.x - b.x) + 1, absi(a.y - b.y) + 1))


## Muebles de este tipo que hay dentro de la habitación.
func furniture_in(room: Dictionary, tipo: String = "") -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for f in furniture:
		if room["rect"].has_point(f["celda"]) and (tipo == "" or f["tipo"] == tipo):
			out.append(f)
	return out


## ¿Tiene la habitación todo lo que necesita para funcionar?
func room_ready(room: Dictionary) -> bool:
	for need in room_types.get(room["tipo"], {}).get("necesita", []):
		if furniture_in(room, need).is_empty():
			return false
	return true


## Lo que le falta a la habitación (nombres de muebles), o [] si está completa.
func room_missing(room: Dictionary) -> Array[String]:
	var out: Array[String] = []
	for need in room_types.get(room["tipo"], {}).get("necesita", []):
		if furniture_in(room, need).is_empty():
			out.append(catalog.get(need, {}).get("nombre", need))
	return out


## Por qué no se puede crear una habitación de este tipo en este rectángulo ("" si se puede).
func room_problem(tipo: String, rect: Rect2i) -> String:
	if not room_types.has(tipo):
		return "Habitación desconocida"
	var minimum := int(room_types[tipo]["minimo"])
	if rect.size.x * rect.size.y < minimum:
		return "Es muy pequeña: necesita al menos %d casillas" % minimum
	for x in range(rect.position.x, rect.end.x):
		for y in range(rect.position.y, rect.end.y):
			if not buildable.has(Vector2i(x, y)):
				return "Ahí no cabe: choca con la cocina, la puerta o un puesto del personal"
	for r in rooms:
		if r["rect"].intersects(rect):
			return "Se solapa con otra habitación"
	for t in tables:
		if rect.has_point(t.cell) or t.seats.any(func(c: Vector2i): return rect.has_point(c)):
			return "Hay mesas dentro: muévelas antes"
	return ""


func add_room(tipo: String, rect: Rect2i) -> int:
	var id := _next_room_id
	_next_room_id += 1
	rooms.append({ "id": id, "tipo": tipo, "rect": rect })
	return id


## Por qué no se puede derribar la habitación ("" si se puede): antes hay que retirar su equipo.
func room_removal_problem(room: Dictionary) -> String:
	var needed := 0
	for f in furniture_in(room):
		if catalog.get(f["tipo"], {}).get("solo_en", "") == room["tipo"]:
			needed += 1
	return "" if needed == 0 else "Antes retira lo que hay dentro (%d mueble%s de la habitación)" % [needed, "" if needed == 1 else "s"]


func remove_room(id: int) -> void:
	rooms = rooms.filter(func(r: Dictionary): return r["id"] != id)


## Casillas desde las que se usa cada mueble de equipo (delante del inodoro, del perchero...).
func use_cells(room_tipo: String = "") -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for f in furniture:
		var def: Dictionary = catalog.get(f["tipo"], {})
		if not def.has("uso") or def.has("objeto"):
			continue
		if room_tipo != "" and def.get("solo_en", "") != room_tipo:
			continue
		out.append(f["celda"] + rotate_cell(v2i(def["uso"]), f["rot"]))
	return out


## Casillas desde las que se usa cada inodoro de unos baños (un puesto = un inodoro).
func stall_cells(room: Dictionary) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for f in furniture_in(room, "inodoro"):
		out.append(f["celda"] + rotate_cell(v2i(catalog["inodoro"]["uso"]), f["rot"]))
	return out


## Taburetes de las barras que funcionan (tienen mostrador).
func bar_stools() -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for room in rooms_of("barra"):
		if room_ready(room):
			for f in furniture_in(room, "taburete"):
				out.append(f["celda"])
	return out


## Casillas de uso de las habitaciones de este tipo que funcionan.
func working_use_cells(room_tipo: String) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for room in rooms_of(room_tipo):
		if not room_ready(room):
			continue
		for f in furniture_in(room):
			var def: Dictionary = catalog.get(f["tipo"], {})
			if def.get("solo_en", "") == room_tipo and def.has("uso"):
				out.append(f["celda"] + rotate_cell(v2i(def["uso"]), f["rot"]))
	return out


## Sitios donde puede ponerse quien sirve la barra: casillas libres dentro de una barra
## que funciona, pegadas a su mostrador.
func bar_posts() -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for room in rooms_of("barra"):
		if not room_ready(room):
			continue
		var counters := furniture_in(room, "barra_bar")
		var r: Rect2i = room["rect"]
		for x in range(r.position.x, r.end.x):
			for y in range(r.position.y, r.end.y):
				var c := Vector2i(x, y)
				if astar == null or not can_stand(c) or reserved.has(c) or _sittable.has(c):
					continue
				for f in counters:
					if absi(f["celda"].x - c.x) <= 1 and absi(f["celda"].y - c.y) <= 1:
						out.append(c)
						break
	return out


# --- Paredes interiores y puertas --------------------------------------------------------

## Por qué no se pueden poner estas paredes (o puertas) ("" si se puede).
func inner_wall_problem(cells: Array, kind: String, people: Array[Vector2i] = []) -> String:
	if cells.is_empty():
		return "No hay nada que construir ahí"
	var changes := 0
	for c in cells:
		if not buildable.has(c):
			return "Ahí no se puede construir (cocina, puertas de la calle o puestos del personal)"
		if inner_walls.get(c, "") == kind:
			continue
		if kind == "puerta" and inner_walls.get(c, "") != "pared":
			return "Las puertas van en una pared"
		if not furniture_all_at(c).is_empty():
			return "Hay un mueble en medio"
		if people.has(c):
			return "Hay alguien en medio"
		changes += 1
	if changes == 0:
		return "Ya está construido"
	# Se prueba de verdad: todo el local tiene que seguir siendo accesible.
	var saved := inner_walls.duplicate()
	for c in cells:
		inner_walls[c] = kind
	_rebuild()
	var problem := accessibility_problem()
	inner_walls = saved
	_rebuild()
	return "Cerraría el paso: deja una puerta" if problem != "" else ""


func set_inner_walls(cells: Array, kind: String) -> int:
	var changed := 0
	for c in cells:
		if inner_walls.get(c, "") != kind:
			inner_walls[c] = kind
			changed += 1
	if changed > 0:
		_rebuild()
	return changed


func remove_inner_walls(cells: Array) -> int:
	var removed := 0
	for c in cells:
		if inner_walls.erase(c):
			removed += 1
	if removed > 0:
		_rebuild()
	return removed


## Línea de casillas entre dos toques (en horizontal o vertical, la dirección más larga).
static func line_between(a: Vector2i, b: Vector2i) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	if absi(b.x - a.x) >= absi(b.y - a.y):
		for x in range(mini(a.x, b.x), maxi(a.x, b.x) + 1):
			out.append(Vector2i(x, a.y))
	else:
		for y in range(mini(a.y, b.y), maxi(a.y, b.y) + 1):
			out.append(Vector2i(a.x, y))
	return out


## Casillas del anillo que rodea a una habitación y cuál de ellas queda como puerta
## (la más cercana a la recepción). Solo las que se pueden construir.
func ring_around(rect: Rect2i) -> Dictionary:
	var cells: Array[Vector2i] = []
	var door := Vector2i(-999, -999)
	var best := INF
	for x in range(rect.position.x - 1, rect.end.x + 1):
		for y in range(rect.position.y - 1, rect.end.y + 1):
			var c := Vector2i(x, y)
			if rect.has_point(c) or not buildable.has(c):
				continue
			if not furniture_all_at(c).is_empty() or inner_walls.has(c):
				continue
			cells.append(c)
			var corner := (x < rect.position.x or x >= rect.end.x) and (y < rect.position.y or y >= rect.end.y)
			var d := Vector2(c - reception_cell).length()
			if not corner and d < best:
				best = d
				door = c
	return { "celdas": cells, "puerta": door }


## Equipo básico para una habitación de este tipo y tamaño, colocado como se haría a mano:
## los inodoros y lavabos contra una pared mirando hacia dentro, la barra con el mostrador,
## el sitio del camarero y los taburetes en fila... Lista de {tipo, celda, rot}; con "uno"
## solo hace falta que se pueda poner el primero de los que lleven la misma etiqueta.
func plan_equipment(tipo: String, rect: Rect2i) -> Array[Dictionary]:
	var items: Array[Dictionary] = []
	var x0 := rect.position.x
	var y0 := rect.position.y
	var w := rect.size.x
	var h := rect.size.y
	match tipo:
		"aseos":
			if w == 1:
				# Pasillo estrecho: el inodoro y el lavabo uno tras otro.
				items.append({ "tipo": "inodoro", "celda": Vector2i(x0, y0), "rot": 0 })
				items.append({ "tipo": "lavabo", "celda": Vector2i(x0, y0 + 2), "rot": 0 })
			else:
				var stalls := clampi(w - 1, 1, 3)
				for i in stalls:
					items.append({ "tipo": "inodoro", "celda": Vector2i(x0 + i, y0), "rot": 0 })
				for i in range(stalls, mini(w, stalls + 2)):
					items.append({ "tipo": "lavabo", "celda": Vector2i(x0 + i, y0), "rot": 0 })
		"ropero":
			items.append({ "tipo": "perchero", "celda": Vector2i(x0, y0), "rot": 0 })
			if w * h >= 6:
				items.append({ "tipo": "perchero", "celda": Vector2i(x0 + w - 1, y0), "rot": 0 })
		"barra":
			var counters := w if h >= 3 else maxi(1, w - 1)
			for i in counters:
				items.append({ "tipo": "barra_bar", "celda": Vector2i(x0 + i, y0), "rot": 0 })
			var stools_row := y0 + h - 1 if h >= 2 else y0
			for i in mini(counters, 4):
				if stools_row != y0:
					items.append({ "tipo": "taburete", "celda": Vector2i(x0 + i, stools_row), "rot": 0 })
		"despacho":
			for y in range(y0, y0 + h):
				for x in range(x0, x0 + w):
					for rot in 4:
						items.append({ "tipo": "ordenador", "celda": Vector2i(x, y), "rot": rot, "uno": "ordenador" })
	return items
