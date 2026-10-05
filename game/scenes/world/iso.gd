class_name Iso
extends RefCounted
## Conversión entre celdas de la rejilla isométrica y coordenadas de pantalla.

const TILE_WIDTH := 128.0
const TILE_HEIGHT := 64.0


## Centro en pantalla de la celda (x, y).
static func cell_to_screen(cell: Vector2i) -> Vector2:
	return grid_to_screen(Vector2(cell))


## Igual que cell_to_screen pero con posiciones de rejilla con decimales.
static func grid_to_screen(p: Vector2) -> Vector2:
	return Vector2((p.x - p.y) * TILE_WIDTH / 2.0, (p.x + p.y) * TILE_HEIGHT / 2.0)


## Celda que contiene un punto de pantalla.
static func screen_to_cell(pos: Vector2) -> Vector2i:
	var fx := pos.x / TILE_WIDTH + pos.y / TILE_HEIGHT
	var fy := pos.y / TILE_HEIGHT - pos.x / TILE_WIDTH
	return Vector2i(floori(fx + 0.5), floori(fy + 0.5))


## Los cuatro vértices del rombo de una celda, escalado respecto a su centro.
static func cell_polygon(cell: Vector2i, scale: float = 1.0) -> PackedVector2Array:
	var c := cell_to_screen(cell)
	return diamond(c, scale)


## Rombo isométrico centrado en `center`.
static func diamond(center: Vector2, scale: float = 1.0) -> PackedVector2Array:
	var hw := TILE_WIDTH / 2.0 * scale
	var hh := TILE_HEIGHT / 2.0 * scale
	return PackedVector2Array([center + Vector2(0, -hh), center + Vector2(hw, 0), center + Vector2(0, hh), center + Vector2(-hw, 0)])
