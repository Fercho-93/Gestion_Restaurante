class_name IsoCamera
extends Camera3D
## Cámara isométrica ortográfica, con gestos como un mapa:
## - Arrastrar con un dedo: el escenario se queda pegado al dedo.
## - Pellizcar con dos: zoom hacia el punto entre los dedos (y se puede mover a la vez).
## - Rueda del ratón: zoom hacia el puntero.

const PITCH_DEG := -35.264
const YAW_DEG := 45.0
const DISTANCE := 40.0
const MIN_SIZE := 4.0
const MAX_SIZE := 16.0
## Cuánto puede moverse un dedo (en fracción del alto de pantalla) y seguir siendo un toque.
const TAP_SLOP := 0.035
## Zona por la que se puede mover el centro de la cámara.
const BOUNDS := Rect2(-3, -1, 16, 12)

var target := Vector3.ZERO
## Dedos en pantalla: índice -> posición.
var _touches := {}
## Dónde se apoyó el dedo (para no mover la cámara con el temblor de un toque).
var _press_start := Vector2.ZERO
var _panning := false


func _ready() -> void:
	projection = PROJECTION_ORTHOGONAL
	size = 10.5
	near = 0.1
	far = 200.0
	rotation_degrees = Vector3(PITCH_DEG, YAW_DEG, 0)
	_apply()


## Distancia máxima (en píxeles de la vista) para considerar un gesto como toque.
func tap_slop() -> float:
	return get_viewport().get_visible_rect().size.y * TAP_SLOP


func focus(point: Vector3) -> void:
	target = point
	_apply()


## Punto del suelo (y = 0) bajo una posición de la pantalla.
func screen_to_ground(screen_pos: Vector2) -> Vector3:
	var origin := project_ray_origin(screen_pos)
	var dir := project_ray_normal(screen_pos)
	if absf(dir.y) < 0.0001:
		return origin
	return origin + dir * (-origin.y / dir.y)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		if event.pressed:
			_touches[event.index] = event.position
			if _touches.size() == 1:
				_press_start = event.position
				_panning = false
		else:
			_touches.erase(event.index)
	elif event is InputEventScreenDrag:
		var before: Dictionary = _touches.duplicate()
		if not before.has(event.index):
			before[event.index] = event.position - event.relative
		_touches[event.index] = event.position
		var fingers: Array = _touches.keys()
		if fingers.size() == 1:
			# El temblor de un toque no mueve la cámara; al pasar el margen, el suelo
			# que tocaste al principio se pone bajo el dedo.
			if not _panning and event.position.distance_to(_press_start) < tap_slop():
				_touches[event.index] = before[event.index]
				get_viewport().set_input_as_handled()
				return
			_panning = true
			_move_keeping(before[event.index], event.position, size)
		elif event.index in fingers.slice(0, 2):
			var a: int = fingers[0]
			var b: int = fingers[1]
			var old_mid: Vector2 = (before[a] + before[b]) / 2.0
			var new_mid: Vector2 = (_touches[a] + _touches[b]) / 2.0
			var old_gap: float = before[a].distance_to(before[b])
			var new_gap: float = _touches[a].distance_to(_touches[b])
			var new_size := size if new_gap < 1.0 else size * old_gap / new_gap
			_panning = true
			_move_keeping(old_mid, new_mid, new_size)
		get_viewport().set_input_as_handled()
	elif event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			_move_keeping(event.position, event.position, size / 1.1)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_move_keeping(event.position, event.position, size * 1.1)


## Cambia el zoom y mueve la cámara para que el punto del suelo que estaba bajo
## `from_screen` quede ahora bajo `to_screen`.
func _move_keeping(from_screen: Vector2, to_screen: Vector2, new_size: float) -> void:
	var anchor := screen_to_ground(from_screen)
	size = clampf(new_size, MIN_SIZE, MAX_SIZE)
	_apply()
	target += anchor - screen_to_ground(to_screen)
	target.y = 0.0
	target.x = clampf(target.x, BOUNDS.position.x, BOUNDS.end.x)
	target.z = clampf(target.z, BOUNDS.position.y, BOUNDS.end.y)
	_apply()


func _apply() -> void:
	position = target + global_transform.basis.z * DISTANCE
