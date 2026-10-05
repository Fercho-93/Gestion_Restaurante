class_name PersonSprite
extends Node2D
## Persona provisional (cliente o empleado) dibujada por código, con una animación
## sencilla de caminar. Se sustituirá por los personajes animados definitivos.

const SKIN_TONES := [Color("f1c7a5"), Color("d9a37e"), Color("a56b46"), Color("7a4b2f")]
const CLOTHES := [Color("e05a5a"), Color("4f8fdb"), Color("58b368"), Color("e0a23b"), Color("9b6fd1"), Color("e07fb1"), Color("3fb3b0")]

var role := "cliente"
var body_color := Color.WHITE
var skin := Color("f1c7a5")
var moving := false
var seated := false
var carrying := false
var working := false
## Texto corto en un bocadillo (estado del grupo) y color del ánimo.
var bubble := ""
var bubble_color := Color.WHITE
## Entidad de la simulación que representa (CustomerGroup o StaffMember).
var entity = null

var _time := 0.0


func setup(person_role: String, seed_value: int) -> void:
	role = person_role
	skin = SKIN_TONES[seed_value % SKIN_TONES.size()]
	body_color = CLOTHES[seed_value % CLOTHES.size()]
	_time = float(seed_value % 10)


func _process(delta: float) -> void:
	_time += delta * (Game.clock.speed if moving or working else 1.0)
	queue_redraw()


func _draw() -> void:
	var bob := 0.0
	if moving:
		bob = absf(sin(_time * 10.0)) * -4.0
	elif working:
		bob = sin(_time * 6.0) * 1.5
	var lift := -8.0 if seated else 0.0
	var o := Vector2(0, bob + lift)

	# Sombra.
	draw_set_transform(Vector2.ZERO, 0.0, Vector2(1.0, 0.45))
	draw_circle(Vector2.ZERO, 14.0, Color(0, 0, 0, 0.18))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

	# Piernas.
	if not seated:
		var step := sin(_time * 10.0) * 3.0 if moving else 0.0
		draw_rect(Rect2(o + Vector2(-7, -14 + step), Vector2(5, 14 - step)), Color("3a3a48"))
		draw_rect(Rect2(o + Vector2(2, -14 - step), Vector2(5, 14 + step)), Color("3a3a48"))

	# Cuerpo.
	var shirt := body_color
	if role == "camarero":
		shirt = Color("fafafa")
	elif role == "cocinero":
		shirt = Color("f2f2f2")
	draw_rect(Rect2(o + Vector2(-10, -38), Vector2(20, 26)), shirt)
	draw_circle(o + Vector2(0, -38), 10.0, shirt)
	if role == "camarero":
		draw_rect(Rect2(o + Vector2(-9, -24), Vector2(18, 14)), Color("2b2b35"))
	elif role == "cocinero":
		draw_rect(Rect2(o + Vector2(-9, -30), Vector2(18, 20)), Color("dfe7ea"))

	# Cabeza.
	draw_circle(o + Vector2(0, -52), 10.0, skin)
	if role == "cocinero":
		draw_rect(Rect2(o + Vector2(-9, -72), Vector2(18, 12)), Color.WHITE)
		draw_circle(o + Vector2(0, -73), 9.0, Color.WHITE)
	else:
		draw_arc(o + Vector2(0, -53), 10.0, PI, TAU, 12, Color("3b2a20"), 5.0)

	# Bandeja con plato.
	if carrying:
		draw_set_transform(o + Vector2(14, -34), 0.0, Vector2(1.0, 0.45))
		draw_circle(Vector2.ZERO, 10.0, Color.WHITE)
		draw_circle(Vector2.ZERO, 6.0, Color("e0a23b"))
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

	# Bocadillo de estado.
	if bubble != "":
		var center := o + Vector2(16, -80)
		draw_circle(center, 13.0, Color.WHITE)
		draw_arc(center, 13.0, 0.0, TAU, 20, bubble_color, 3.0)
		var font := ThemeDB.fallback_font
		draw_string(font, center + Vector2(-13, 6), bubble, HORIZONTAL_ALIGNMENT_CENTER, 26, 16, Color("2b2b35"))
