class_name BuildMode
extends Node3D
## Modo construcción: con el juego en pausa se compran, colocan, giran, mueven y venden
## muebles. Muestra un "fantasma" del mueble y sus casillas en verde (se puede) o rojo (no
## se puede, con el motivo). La interfaz (BuildPanel) solo llama a estas funciones.

signal changed

enum Mode { NADA, COLOCANDO, ELEGIDO, PINTANDO, PARED, HABITACION, TABIQUE }

const OK_COLOR := Color(0.3, 0.85, 0.4, 0.55)
const BAD_COLOR := Color(0.95, 0.3, 0.3, 0.55)
const PICK_COLOR := Color(1.0, 0.82, 0.3, 0.6)
const AREA_COLOR := Color(1, 1, 1, 0.16)

var active := false
var mode := Mode.NADA
var sim: RestaurantSim
var camera: IsoCamera
## Suelos, paredes y ventanas del escenario (para señalar y elegir segmentos de pared).
var finishes: RoomFinishes
## Suelo con el que se pinta y tamaño del pincel: "casilla", "3x3" o "zona".
var floor_material := ""
var brush := "casilla"
## Qué se pone en la pared: parte ("estilo", "abertura" o "adorno") e id ("" = quitar),
## y si se aplica a un "tramo" o a la "pared" entera.
var wall_part := ""
var wall_id := ""
var wall_scope := "tramo"
## Habitación que se dibuja ("" = derribar) y la primera esquina ya marcada.
## Paredes interiores: herramienta ("pared", "puerta", "quitar" o "rodear") y primer extremo.
var inner_tool := ""
var inner_corner := Vector2i(-999, -999)
## Al crear una habitación: con paredes y puerta, con el equipo básico y con suelo a juego.
var room_walls := true
var room_equip := true
var room_floor := true
## Dibujo arrastrando (como en los Sims): de dónde a dónde, y qué se ve mientras tanto.
var drag_from := Vector2i(-999, -999)
var drag_to := Vector2i(-999, -999)
var dragging := false
var _preview_cells: Array[Vector2i] = []
var _preview_ring: Array[Vector2i] = []
var _preview_ok := false
## Fotos para deshacer (la última es el estado anterior a la última reforma).
var _undo: Array[Dictionary] = []
const MAX_UNDO := 25
var room_type := ""
var room_corner := Vector2i(-999, -999)
## Mueble del catálogo que se está colocando (nuevo o movido).
var tipo := ""
## Mueble que se mueve o está elegido (-1 si es uno nuevo).
var uid := -1
var cell := Vector2i.ZERO
var rot := 0
## Por qué no se puede colocar aquí ("" si se puede).
var problem := ""
## Lo último que ha pasado (compra, venta...), para enseñarlo en la interfaz.
var message := ""
var _speed_before := 1
var _ghost: Node3D
var _tiles: Node3D
var _area: Node3D


func setup(restaurant_sim: RestaurantSim, iso_camera: IsoCamera, room_finishes: RoomFinishes = null) -> void:
	sim = restaurant_sim
	camera = iso_camera
	finishes = room_finishes
	_tiles = Node3D.new()
	add_child(_tiles)
	_area = Node3D.new()
	_area.visible = false
	add_child(_area)
	for c in sim.layout.buildable:
		_area.add_child(_tile(c, AREA_COLOR, 0.012))
	sim.layout_changed.connect(_refresh)


func enter() -> void:
	if active:
		return
	active = true
	_speed_before = Game.clock.speed
	Game.clock.set_speed(0)
	sim.begin_build_session()
	sim.stop_manager()
	_area.visible = true
	_undo.clear()
	message = "Elige un mueble abajo o toca uno del local para moverlo o venderlo."
	_set_mode(Mode.NADA)


func exit() -> void:
	if not active:
		return
	active = false
	if finishes != null:
		finishes.highlight_wall("")
	_area.visible = false
	_set_mode(Mode.NADA)
	Game.clock.set_speed(maxi(1, _speed_before))


## Elegir un mueble del catálogo para colocarlo.
func choose(new_tipo: String) -> void:
	tipo = new_tipo
	uid = -1
	if mode != Mode.COLOCANDO:
		rot = 0
		var center := camera.screen_to_ground(get_viewport().get_visible_rect().size * Vector2(0.5, 0.42))
		cell = _nearest_buildable(Vector2i(roundi(center.x), roundi(center.z)))
	message = ""
	_set_mode(Mode.COLOCANDO)


## Elegir un suelo para pintar.
func choose_floor(id: String) -> void:
	floor_material = id
	message = ""
	_set_mode(Mode.PINTANDO)


func set_brush(new_brush: String) -> void:
	brush = new_brush
	_refresh()


## Elegir qué poner en las paredes ("estilo", "abertura" o "adorno"; id "" = quitar).
func choose_wall(part: String, id: String) -> void:
	wall_part = part
	wall_id = id
	message = ""
	_set_mode(Mode.PARED)


## Elegir una habitación para dibujarla (tipo "" = derribar la que se toque).
func choose_room(tipo: String) -> void:
	room_type = tipo
	room_corner = Vector2i(-999, -999)
	message = ""
	if tipo == "__equipar":
		message = "Toca una habitación para equiparla con lo básico que le falte."
	elif tipo != "":
		var def: Dictionary = sim.layout.room_types[tipo]
		var needs: Array[String] = []
		for n in def["necesita"]:
			needs.append(String(sim.layout.catalog.get(n, {}).get("nombre", n)).to_lower())
		message = "%s: toca dos esquinas opuestas. Necesita: %s." % [def["nombre"], ", ".join(needs)]
	_set_mode(Mode.HABITACION)


func choose_inner(tool: String) -> void:
	inner_tool = tool
	inner_corner = Vector2i(-999, -999)
	message = ""
	match tool:
		"pared":
			message = "Pared: toca donde empieza y donde acaba (en línea recta)."
		"puerta":
			message = "Puerta: toca un trozo de pared para abrir una puerta."
		"quitar":
			message = "Toca la pared o la puerta que quieras tirar."
		"rodear":
			message = "Toca dentro de una habitación para rodearla con paredes y una puerta."
	_set_mode(Mode.TABIQUE)


## Guarda cómo está el local antes de una reforma, para poder deshacerla.
func _checkpoint() -> Dictionary:
	return sim.snapshot()


func _commit(snap: Dictionary) -> void:
	_undo.append(snap)
	if _undo.size() > MAX_UNDO:
		_undo.pop_front()


func can_undo() -> bool:
	return not _undo.is_empty()


## Deshace la última reforma (y devuelve lo que costó).
func undo() -> void:
	if _undo.is_empty():
		return
	sim.restore(_undo.pop_back())
	message = "Deshecho."
	_set_mode(Mode.NADA if mode == Mode.ELEGIDO else mode)


func set_room_option(option: String, on: bool) -> void:
	match option:
		"paredes":
			room_walls = on
		"equipo":
			room_equip = on
		"suelo":
			room_floor = on
	if dragging:
		_update_preview()
	_refresh()


func _room_options() -> Dictionary:
	return { "paredes": room_walls, "equipo": room_equip, "suelo": room_floor }


## ¿Se dibuja arrastrando con la herramienta actual?
func is_drag_tool() -> bool:
	return active and ((mode == Mode.HABITACION and room_type != "" and room_type != "__equipar") or (mode == Mode.TABIQUE and inner_tool == "pared"))


func _cell_at(screen_pos: Vector2) -> Vector2i:
	var ground := camera.screen_to_ground(screen_pos)
	return Vector2i(roundi(ground.x), roundi(ground.z))


func drag_begin(screen_pos: Vector2) -> void:
	if not is_drag_tool():
		return
	dragging = true
	drag_from = _cell_at(screen_pos)
	drag_to = drag_from
	room_corner = Vector2i(-999, -999)
	inner_corner = Vector2i(-999, -999)
	_update_preview()
	_refresh()


func drag_update(screen_pos: Vector2) -> void:
	if not dragging:
		return
	var c := _cell_at(screen_pos)
	if c == drag_to:
		return
	drag_to = c
	_update_preview()
	_refresh()


func drag_cancel() -> void:
	if not dragging:
		return
	dragging = false
	message = ""
	_refresh()


## Suelta: si la vista previa estaba en verde, se construye.
func drag_end(screen_pos: Vector2) -> void:
	if not dragging:
		return
	drag_to = _cell_at(screen_pos)
	_update_preview()
	dragging = false
	if mode == Mode.HABITACION:
		_make_room(drag_from, drag_to)
	else:
		_make_wall(drag_from, drag_to)
	_refresh()


## Calcula qué se vería: las casillas y si se puede, con el precio.
func _update_preview() -> void:
	_preview_cells.clear()
	_preview_ring.clear()
	if mode == Mode.HABITACION:
		var rect := RestaurantLayout.rect_between(drag_from, drag_to)
		for x in range(rect.position.x, rect.end.x):
			for y in range(rect.position.y, rect.end.y):
				_preview_cells.append(Vector2i(x, y))
		var def: Dictionary = sim.layout.room_types[room_type]
		var problem := sim.layout.room_problem(room_type, rect)
		var plan := sim.room_plan_cost(room_type, rect, _room_options())
		if room_walls:
			_preview_ring.assign(sim.layout.ring_around(rect)["celdas"])
		var total: float = 0.0 if sim.free_build else plan["total"]
		if problem == "" and total > sim.finances.money:
			problem = "No hay dinero suficiente"
		_preview_ok = problem == ""
		var head := "%s %d×%d" % [def["nombre"], rect.size.x, rect.size.y]
		message = "%s · %d €" % [head, int(total)] if problem == "" else "%s: %s" % [head, problem]
	else:
		var line := RestaurantLayout.line_between(drag_from, drag_to)
		_preview_cells.assign(line)
		var problem := sim.layout.inner_wall_problem(line, "pared", sim.people_cells())
		var cost := 0.0 if sim.free_build else sim.inner_cost(line, "pared")
		if problem == "" and cost > sim.finances.money:
			problem = "No hay dinero suficiente"
		_preview_ok = problem == ""
		message = "Pared de %d casillas · %d €" % [line.size(), int(cost)] if problem == "" else "Pared: " + problem


func _make_room(a: Vector2i, b: Vector2i) -> void:
	var snap := _checkpoint()
	var rect := RestaurantLayout.rect_between(a, b)
	var plan := sim.room_plan_cost(room_type, rect, _room_options())
	var result := sim.create_room(room_type, a, b, _room_options())
	if result == "":
		_commit(snap)
		var def: Dictionary = sim.layout.room_types[room_type]
		var parts: Array[String] = []
		if room_equip:
			parts.append("con su equipo")
		if room_walls and not sim.last_room_note.contains("sin paredes"):
			parts.append("con paredes y puerta")
		message = "%s %s%s%s." % [def["nombre"], def.get("creada", "creada"), "" if parts.is_empty() else " (" + ", ".join(parts) + ")", "" if sim.free_build else " · −%d €" % int(plan["total"])]
		if sim.last_room_note != "":
			message += " Ojo: " + sim.last_room_note + "."
		elif not room_equip:
			message += " Ahora pon su equipo."
	else:
		message = result
	room_corner = Vector2i(-999, -999)


func _make_wall(a: Vector2i, b: Vector2i) -> void:
	var snap := _checkpoint()
	var line := RestaurantLayout.line_between(a, b)
	var cost := sim.inner_cost(line, "pared")
	var result := sim.build_inner(line, "pared")
	if result == "":
		_commit(snap)
		message = "Pared de %d casillas%s." % [line.size(), "" if sim.free_build else " (−%d €)" % int(cost)]
	else:
		message = result
	inner_corner = Vector2i(-999, -999)


func set_wall_scope(scope: String) -> void:
	wall_scope = scope
	_refresh()


## Un toque en el local: mueve el fantasma, pinta, cambia una pared o elige el mueble tocado.
func tap(screen_pos: Vector2) -> void:
	if mode == Mode.TABIQUE:
		_tap_inner(screen_pos)
		return
	if mode == Mode.HABITACION:
		_tap_room(screen_pos)
		return
	if mode == Mode.PARED:
		_tap_wall(screen_pos)
		return
	if mode == Mode.PINTANDO:
		_tap_floor(screen_pos)
		return
	var ground := camera.screen_to_ground(screen_pos)
	var c := Vector2i(roundi(ground.x), roundi(ground.z))
	if mode == Mode.COLOCANDO:
		cell = c
		message = ""
		_refresh()
		return
	var here := sim.layout.furniture_all_at(c)
	if here.is_empty():
		message = "Ahí no hay ningún mueble. Elige uno abajo para comprarlo."
		_set_mode(Mode.NADA)
		return
	# Si hay dos cosas en la casilla (una mesa y una lámpara colgante), tocar otra vez pasa a la siguiente.
	var f: Dictionary = here[0]
	if mode == Mode.ELEGIDO:
		for i in here.size():
			if here[i]["uid"] == uid:
				f = here[(i + 1) % here.size()]
				break
	uid = f["uid"]
	tipo = f["tipo"]
	cell = f["celda"]
	rot = f["rot"]
	message = ""
	_set_mode(Mode.ELEGIDO)


## Paredes interiores: líneas (dos toques), puertas, derribos y rodear una habitación.
func _tap_inner(screen_pos: Vector2) -> void:
	var ground := camera.screen_to_ground(screen_pos)
	var c := Vector2i(roundi(ground.x), roundi(ground.z))
	var result := ""
	match inner_tool:
		"pared":
			if inner_corner == Vector2i(-999, -999):
				inner_corner = c
				message = "Toca dónde acaba la pared."
				_refresh()
				return
			_make_wall(inner_corner, c)
		"puerta":
			var snap := _checkpoint()
			result = sim.build_inner([c], "puerta")
			message = "Puerta abierta." if result == "" else result
			if result == "":
				_commit(snap)
		"quitar":
			var snap2 := _checkpoint()
			result = sim.demolish_inner([c])
			message = "Derribado." if result == "" else result
			if result == "":
				_commit(snap2)
		"rodear":
			var snap3 := _checkpoint()
			result = sim.surround_room(c)
			message = "Habitación rodeada con una puerta." if result == "" else result
			if result == "":
				_commit(snap3)
	_refresh()


## Dibujar una habitación: un toque marca una esquina y el siguiente la esquina opuesta.
func _tap_room(screen_pos: Vector2) -> void:
	var ground := camera.screen_to_ground(screen_pos)
	var c := Vector2i(roundi(ground.x), roundi(ground.z))
	if room_type == "":
		var snap := _checkpoint()
		var result := sim.remove_room_at(c)
		message = "Habitación derribada." if result == "" else result
		if result == "":
			_commit(snap)
		_refresh()
		return
	if room_type == "__equipar":
		var snap2 := _checkpoint()
		var result2 := sim.equip_room_at(c)
		message = "Equipada con lo básico." if result2 == "" else result2
		if result2 == "":
			_commit(snap2)
		_refresh()
		return
	if room_corner == Vector2i(-999, -999):
		room_corner = c
		message = "Toca la esquina de enfrente para cerrar la habitación (o arrastra)."
		_refresh()
		return
	_make_room(room_corner, c)
	_refresh()


func _tap_floor(screen_pos: Vector2) -> void:
	if finishes != null and finishes.pick_wall(camera, screen_pos) != "":
		message = "Eso es una pared. Toca el suelo para pintarlo."
		_refresh()
		return
	var ground := camera.screen_to_ground(screen_pos)
	var c := Vector2i(roundi(ground.x), roundi(ground.z))
	var cells: Array = []
	match brush:
		"zona":
			cells = sim.layout.zone_floor_cells(c)
		"3x3":
			for dx in range(-1, 2):
				for dy in range(-1, 2):
					cells.append(c + Vector2i(dx, dy))
		_:
			cells = [c]
	if not sim.layout.floor_paintable(c):
		message = "Ahí no se puede pintar el suelo."
		_refresh()
		return
	var snap := _checkpoint()
	var result := sim.paint_floor(cells, floor_material)
	if result["problema"] != "":
		message = result["problema"]
	else:
		_commit(snap)
		var cost: float = result["coste"]
		message = "Pintado: %d casillas%s." % [result["casillas"], "" if cost <= 0.0 else " (−%d €)" % int(cost)]
	_refresh()


func _tap_wall(screen_pos: Vector2) -> void:
	var key := finishes.pick_wall(camera, screen_pos) if finishes != null else ""
	if key == "":
		message = "Toca una pared para cambiarla."
		_refresh()
		return
	var keys: Array[String] = [key]
	if wall_scope == "pared":
		keys = sim.layout.wall_keys(key.substr(0, 1))
	var done := 0
	var spent := 0.0
	var first_problem := ""
	var wall_snap := _checkpoint()
	for k in keys:
		var price := 0.0 if sim.free_build else sim.wall_part_price(wall_part, wall_id)
		var problem := sim.change_wall(k, wall_part, wall_id)
		if problem == "":
			done += 1
			spent += price
		elif first_problem == "" and not (keys.size() > 1 and problem in ["Ya está puesto", "No hay nada que quitar", "Ahí hay una ventana", "Quita antes lo que cuelga de esa pared"]):
			first_problem = problem
	if done == 0:
		message = first_problem if first_problem != "" else "Ahí no se puede."
	else:
		_commit(wall_snap)
		message = "Hecho en %d tramo%s%s." % [done, "" if done == 1 else "s", "" if spent <= 0.0 else " (−%d €)" % int(spent)]
	if finishes != null:
		finishes.highlight_wall(key)
	_refresh()


func turn() -> void:
	if mode == Mode.COLOCANDO:
		rot = posmod(rot + 1, 4)
		_refresh()
	elif mode == Mode.ELEGIDO:
		var result := sim.move_furniture(uid, cell, posmod(rot + 1, 4))
		if result == "":
			rot = posmod(rot + 1, 4)
			message = "Girado."
		else:
			message = "No se puede girar: " + result.to_lower()
		_refresh()


## Comprar el mueble nuevo o dejar el que se mueve en su sitio nuevo.
func confirm() -> void:
	if mode != Mode.COLOCANDO:
		return
	if uid == -1:
		var price := 0.0 if sim.free_build else sim.furniture_price(tipo)
		var snap := _checkpoint()
		var result := sim.buy_furniture(tipo, cell, rot)
		if result == "":
			_commit(snap)
			message = "Comprado: %s%s. Toca otro sitio para poner otro igual." % [_name(tipo), "" if price == 0.0 else " (%d €)" % int(price)]
		else:
			message = result
		_refresh()
	else:
		var snap2 := _checkpoint()
		var result := sim.move_furniture(uid, cell, rot)
		if result == "":
			_commit(snap2)
			message = "Movido."
			_set_mode(Mode.ELEGIDO)
		else:
			message = result
			_refresh()


func start_move() -> void:
	if mode != Mode.ELEGIDO:
		return
	var locked := sim.furniture_locked(uid)
	if locked != "":
		message = locked
		_refresh()
		return
	message = "Toca dónde quieres ponerlo."
	_set_mode(Mode.COLOCANDO)


func sell() -> void:
	if mode != Mode.ELEGIDO:
		return
	var value := sim.resale_value(uid)
	var snap := _checkpoint()
	var result := sim.sell_furniture(uid)
	if result == "":
		_commit(snap)
		message = "Vendido: %s%s." % [_name(tipo), "" if value == 0.0 else " (+%d €)" % int(value)]
		_set_mode(Mode.NADA)
	else:
		message = result
		_refresh()


func cancel() -> void:
	message = ""
	_set_mode(Mode.NADA)


func display_name() -> String:
	return _name(tipo)


func _name(t: String) -> String:
	return sim.layout.catalog.get(t, {}).get("nombre", t)


func _set_mode(new_mode: Mode) -> void:
	mode = new_mode
	if mode == Mode.NADA:
		uid = -1
	if finishes != null and mode != Mode.PARED:
		finishes.highlight_wall("")
	_refresh()


func refresh() -> void:
	_refresh()


## Vuelve a dibujar el fantasma y las casillas, y comprueba si se puede colocar.
func _refresh() -> void:
	if _ghost != null:
		_ghost.queue_free()
		_ghost = null
	for child in _tiles.get_children():
		child.queue_free()
	problem = ""
	if not active:
		changed.emit()
		return
	if mode == Mode.COLOCANDO:
		problem = sim.build_problem(tipo, cell, rot) if uid == -1 else sim.move_problem(uid, cell, rot)
		_ghost = FurnitureModels.build(sim.layout.catalog[tipo], rot, true)
		_ghost.position = Vector3(cell.x, 0.02, cell.y)
		add_child(_ghost)
		_draw_footprint(OK_COLOR if problem == "" else BAD_COLOR)
	elif mode == Mode.TABIQUE or mode == Mode.HABITACION:
		if dragging:
			for c in _preview_cells:
				_tiles.add_child(_tile(c, OK_COLOR if _preview_ok else BAD_COLOR, 0.02))
			for c in _preview_ring:
				_tiles.add_child(_tile(c, Color(0.45, 0.65, 0.95, 0.5), 0.02))
		elif mode == Mode.TABIQUE and inner_corner != Vector2i(-999, -999):
			_tiles.add_child(_tile(inner_corner, PICK_COLOR, 0.02))
		elif mode == Mode.HABITACION and room_corner != Vector2i(-999, -999):
			_tiles.add_child(_tile(room_corner, PICK_COLOR, 0.02))
	elif mode == Mode.ELEGIDO:
		var f := sim.layout.furniture_by_uid(uid)
		if f.is_empty():
			mode = Mode.NADA
		else:
			cell = f["celda"]
			rot = f["rot"]
			_draw_footprint(PICK_COLOR)
	changed.emit()


func _draw_footprint(color: Color) -> void:
	var fp := sim.layout.footprint(tipo, cell, rot)
	for c in fp["solid"]:
		_tiles.add_child(_tile(c, color, 0.02))
	for c in fp["seats"]:
		_tiles.add_child(_tile(c, Color(color, color.a * 0.6), 0.02))


func _tile(c: Vector2i, color: Color, height: float) -> MeshInstance3D:
	var m := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(0.94, 0.94)
	m.mesh = plane
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.material_override = mat
	m.position = Vector3(c.x, height, c.y)
	return m


## La casilla más cercana a `c` donde cabe el mueble que se va a colocar (o `c` si no hay).
func _nearest_buildable(c: Vector2i) -> Vector2i:
	var candidates: Array = sim.layout.buildable.keys()
	candidates.sort_custom(func(a: Vector2i, b: Vector2i): return Vector2(a - c).length() < Vector2(b - c).length())
	for b in candidates.slice(0, 40):
		if sim.layout.furniture_at(b).is_empty() and sim.layout.placement_problem(tipo, b, rot, -1, sim.people_cells()) == "":
			return b
	return c
