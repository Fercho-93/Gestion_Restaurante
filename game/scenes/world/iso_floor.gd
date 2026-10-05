extends Node2D
## Suelo isométrico provisional dibujado por código (hasta tener gráficos).
## Muestra las zonas del local y resalta la celda tocada.

signal cell_tapped(cell: Vector2i)

@export var size := Vector2i(12, 10)

## Zonas provisionales: rectángulo de celdas -> color.
var zones := [
	{ "nombre": "Comedor", "rect": Rect2i(0, 0, 8, 10), "color": Color("e9c79a") },
	{ "nombre": "Cocina", "rect": Rect2i(8, 0, 4, 6), "color": Color("b9d4d8") },
	{ "nombre": "Almacén", "rect": Rect2i(8, 6, 4, 4), "color": Color("c9c0b4") },
]

var selected_cell := Vector2i(-1, -1)


func _draw() -> void:
	for x in size.x:
		for y in size.y:
			var cell := Vector2i(x, y)
			var poly := Iso.cell_polygon(cell)
			var color := _zone_color(cell)
			if (x + y) % 2 == 0:
				color = color.darkened(0.06)
			if cell == selected_cell:
				color = color.lerp(Color.WHITE, 0.5)
			draw_colored_polygon(poly, color)
			draw_polyline(poly + PackedVector2Array([poly[0]]), Color(0, 0, 0, 0.12), 1.0)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch and not event.pressed and not event.canceled:
		var cell := Iso.screen_to_cell(get_global_mouse_position())
		if Rect2i(Vector2i.ZERO, size).has_point(cell):
			selected_cell = cell
			queue_redraw()
			cell_tapped.emit(cell)


func zone_name_at(cell: Vector2i) -> String:
	for zone in zones:
		if zone["rect"].has_point(cell):
			return zone["nombre"]
	return ""


func _zone_color(cell: Vector2i) -> Color:
	for zone in zones:
		if zone["rect"].has_point(cell):
			return zone["color"]
	return Color("dddddd")
