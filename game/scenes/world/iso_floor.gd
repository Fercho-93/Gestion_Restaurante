extends Node2D
## Suelo isométrico provisional dibujado por código (hasta tener gráficos).
## Pinta la calle y las zonas del local, y resalta la celda seleccionada.

const STREET_COLOR := Color("9aa3a8")

var layout: RestaurantLayout
var selected_cell := Vector2i(-999, -999)


func setup(restaurant_layout: RestaurantLayout) -> void:
	layout = restaurant_layout
	queue_redraw()


func select(cell: Vector2i) -> void:
	selected_cell = cell
	queue_redraw()


func _draw() -> void:
	if layout == null:
		return
	var r := layout.region
	for x in range(r.position.x, r.end.x):
		for y in range(r.position.y, r.end.y):
			var cell := Vector2i(x, y)
			var poly := Iso.cell_polygon(cell)
			var color := _cell_color(cell)
			if (x + y) % 2 == 0:
				color = color.darkened(0.06)
			if cell == selected_cell:
				color = color.lerp(Color.WHITE, 0.5)
			draw_colored_polygon(poly, color)
			draw_polyline(poly + PackedVector2Array([poly[0]]), Color(0, 0, 0, 0.12), 1.0)


func _cell_color(cell: Vector2i) -> Color:
	if cell.x < 0:
		return STREET_COLOR
	for zone in layout.zones:
		if zone["rect"].has_point(cell):
			return zone["color"]
	return Color("dddddd")
