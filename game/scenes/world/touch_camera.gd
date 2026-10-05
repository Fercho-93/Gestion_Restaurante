extends Camera2D
## Cámara táctil: arrastrar con un dedo para mover, pellizcar con dos para zoom.
## En escritorio: arrastrar con el ratón y rueda para zoom.

const MIN_ZOOM := 0.4
const MAX_ZOOM := 2.0
## Píxeles que hay que mover el dedo para que cuente como arrastre y no como toque.
const DRAG_THRESHOLD := 12.0

var _touches := {}
var _pinch_start_distance := 0.0
var _pinch_start_zoom := 1.0


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		if event.pressed:
			_touches[event.index] = event.position
		else:
			_touches.erase(event.index)
		if _touches.size() == 2:
			_pinch_start_distance = _touch_distance()
			_pinch_start_zoom = zoom.x
	elif event is InputEventScreenDrag:
		_touches[event.index] = event.position
		if _touches.size() == 1 and event.velocity.length() > DRAG_THRESHOLD:
			position -= event.relative / zoom
			get_viewport().set_input_as_handled()
		elif _touches.size() == 2 and _pinch_start_distance > 0.0:
			_set_zoom_level(_pinch_start_zoom * _touch_distance() / _pinch_start_distance)
			get_viewport().set_input_as_handled()
	elif event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			_set_zoom_level(zoom.x * 1.1)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_set_zoom_level(zoom.x / 1.1)


func _set_zoom_level(value: float) -> void:
	var z := clampf(value, MIN_ZOOM, MAX_ZOOM)
	zoom = Vector2(z, z)


func _touch_distance() -> float:
	var points: Array = _touches.values()
	return (points[0] as Vector2).distance_to(points[1])
