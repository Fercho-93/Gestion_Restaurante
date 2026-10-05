class_name IsoCamera
extends Camera3D
## Cámara isométrica ortográfica. Arrastrar con un dedo para mover, pellizcar con dos
## (o rueda del ratón) para hacer zoom.

const PITCH_DEG := -35.264
const YAW_DEG := 45.0
const DISTANCE := 40.0
const MIN_SIZE := 4.0
const MAX_SIZE := 16.0
## Zona por la que se puede mover el centro de la cámara.
const BOUNDS := Rect2(-3, -1, 16, 12)

var target := Vector3.ZERO
var _touches := {}
var _pinch_start_distance := 0.0
var _pinch_start_size := 1.0


func _ready() -> void:
	projection = PROJECTION_ORTHOGONAL
	size = 10.5
	near = 0.1
	far = 200.0
	rotation_degrees = Vector3(PITCH_DEG, YAW_DEG, 0)
	_apply()


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
		else:
			_touches.erase(event.index)
		if _touches.size() == 2:
			_pinch_start_distance = _touch_distance()
			_pinch_start_size = size
	elif event is InputEventScreenDrag:
		_touches[event.index] = event.position
		if _touches.size() == 1:
			_pan(event.relative)
			get_viewport().set_input_as_handled()
		elif _touches.size() == 2 and _pinch_start_distance > 0.0:
			size = clampf(_pinch_start_size * _pinch_start_distance / _touch_distance(), MIN_SIZE, MAX_SIZE)
			get_viewport().set_input_as_handled()
	elif event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			size = clampf(size / 1.1, MIN_SIZE, MAX_SIZE)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			size = clampf(size * 1.1, MIN_SIZE, MAX_SIZE)


func _pan(relative: Vector2) -> void:
	var units_per_pixel := size / get_viewport().get_visible_rect().size.y
	var right := global_transform.basis.x
	right.y = 0.0
	var forward := -global_transform.basis.z
	forward.y = 0.0
	target -= right.normalized() * relative.x * units_per_pixel
	target += forward.normalized() * relative.y * units_per_pixel / sin(deg_to_rad(-PITCH_DEG))
	target.x = clampf(target.x, BOUNDS.position.x, BOUNDS.end.x)
	target.z = clampf(target.z, BOUNDS.position.y, BOUNDS.end.y)
	_apply()


func _apply() -> void:
	position = target + global_transform.basis.z * DISTANCE


func _touch_distance() -> float:
	var points: Array = _touches.values()
	return (points[0] as Vector2).distance_to(points[1])
