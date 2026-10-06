class_name BuildMode
extends Node3D
## Modo construcción: con el juego en pausa se compran, colocan, giran, mueven y venden
## muebles. Muestra un "fantasma" del mueble y sus casillas en verde (se puede) o rojo (no
## se puede, con el motivo). La interfaz (BuildPanel) solo llama a estas funciones.

signal changed

enum Mode { NADA, COLOCANDO, ELEGIDO }

const OK_COLOR := Color(0.3, 0.85, 0.4, 0.55)
const BAD_COLOR := Color(0.95, 0.3, 0.3, 0.55)
const PICK_COLOR := Color(1.0, 0.82, 0.3, 0.6)
const AREA_COLOR := Color(1, 1, 1, 0.16)

var active := false
var mode := Mode.NADA
var sim: RestaurantSim
var camera: IsoCamera
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


func setup(restaurant_sim: RestaurantSim, iso_camera: IsoCamera) -> void:
	sim = restaurant_sim
	camera = iso_camera
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
	message = "Elige un mueble abajo o toca uno del local para moverlo o venderlo."
	_set_mode(Mode.NADA)


func exit() -> void:
	if not active:
		return
	active = false
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


## Un toque en el local: mueve el fantasma, o elige el mueble tocado.
func tap(screen_pos: Vector2) -> void:
	var ground := camera.screen_to_ground(screen_pos)
	var c := Vector2i(roundi(ground.x), roundi(ground.z))
	if mode == Mode.COLOCANDO:
		cell = c
		message = ""
		_refresh()
		return
	var f := sim.layout.furniture_at(c)
	if f.is_empty():
		message = "Ahí no hay ningún mueble. Elige uno abajo para comprarlo."
		_set_mode(Mode.NADA)
		return
	uid = f["uid"]
	tipo = f["tipo"]
	cell = f["celda"]
	rot = f["rot"]
	message = ""
	_set_mode(Mode.ELEGIDO)


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
		var result := sim.buy_furniture(tipo, cell, rot)
		if result == "":
			message = "Comprado: %s%s. Toca otro sitio para poner otro igual." % [_name(tipo), "" if price == 0.0 else " (%d €)" % int(price)]
		else:
			message = result
		_refresh()
	else:
		var result := sim.move_furniture(uid, cell, rot)
		if result == "":
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
	var result := sim.sell_furniture(uid)
	if result == "":
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
