class_name Iso
extends RefCounted
## Conversión entre celdas de la rejilla isométrica y coordenadas de pantalla.

const TILE_WIDTH := 128.0
const TILE_HEIGHT := 64.0


## Centro en pantalla de la celda (x, y).
static func cell_to_screen(cell: Vector2i) -> Vector2:
	return Vector2((cell.x - cell.y) * TILE_WIDTH / 2.0, (cell.x + cell.y) * TILE_HEIGHT / 2.0)


## Celda que contiene un punto de pantalla.
static func screen_to_cell(pos: Vector2) -> Vector2i:
	var fx := pos.x / TILE_WIDTH + pos.y / TILE_HEIGHT
	var fy := pos.y / TILE_HEIGHT - pos.x / TILE_WIDTH
	return Vector2i(floori(fx + 0.5), floori(fy + 0.5))


## Los cuatro vértices del rombo de una celda.
static func cell_polygon(cell: Vector2i) -> PackedVector2Array:
	var c := cell_to_screen(cell)
	var hw := TILE_WIDTH / 2.0
	var hh := TILE_HEIGHT / 2.0
	return PackedVector2Array([c + Vector2(0, -hh), c + Vector2(hw, 0), c + Vector2(0, hh), c + Vector2(-hw, 0)])
