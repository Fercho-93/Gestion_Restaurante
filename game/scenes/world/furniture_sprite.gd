class_name FurnitureSprite
extends Node2D
## Mueble provisional dibujado como un bloque isométrico.

## kind -> [escala del rombo, altura en px, color de la cara superior]
const STYLES := {
	"mesa": [0.55, 22.0, Color("a0673a")],
	"silla": [0.28, 10.0, Color("7a4a26")],
	"barra": [0.9, 34.0, Color("c7ccd1")],
	"fogon": [0.7, 30.0, Color("4a4f55")],
}

var kind := "mesa"


func _init(furniture_kind: String = "mesa") -> void:
	kind = furniture_kind


func _draw() -> void:
	var style: Array = STYLES[kind]
	var top := Iso.diamond(Vector2(0, -style[1]), style[0])
	var base := Iso.diamond(Vector2.ZERO, style[0])
	var color: Color = style[2]
	# Cara izquierda y derecha.
	draw_colored_polygon(PackedVector2Array([top[3], top[2], base[2], base[3]]), color.darkened(0.25))
	draw_colored_polygon(PackedVector2Array([top[2], top[1], base[1], base[2]]), color.darkened(0.4))
	draw_colored_polygon(top, color)
	if kind == "fogon":
		for offset in [Vector2(-14, 0), Vector2(14, 0)]:
			draw_circle(Vector2(0, -style[1]) + offset, 6.0, Color("e2553b"))
	if kind == "mesa":
		draw_colored_polygon(Iso.diamond(Vector2(0, -style[1]), 0.35), Color("f4efe6"))
