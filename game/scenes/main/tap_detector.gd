class_name TapDetector
extends RefCounted
## Distingue un toque de un arrastre o un pellizco. Un toque es un único dedo que se
## apoya y se levanta casi sin moverse. No depende del número que el navegador dé a
## cada dedo (en los móviles reales no tiene por qué empezar en 0).

## Dedos apoyados ahora mismo: índice -> true
var _down := {}
var _finger := -1
var _start := Vector2.ZERO
var _cancelled := false


## Procesa un evento. Si completa un toque, devuelve su posición; si no, null.
func feed(event: InputEvent, slop: float) -> Variant:
	if event is InputEventScreenDrag:
		if event.index == _finger and event.position.distance_to(_start) >= slop:
			_cancelled = true
		return null
	if not event is InputEventScreenTouch:
		return null
	if event.pressed:
		_down[event.index] = true
		if _down.size() == 1:
			_finger = event.index
			_start = event.position
			_cancelled = false
		else:
			_cancelled = true
		return null
	_down.erase(event.index)
	if event.index != _finger:
		return null
	_finger = -1
	if _cancelled or event.position.distance_to(_start) >= slop:
		return null
	return event.position
