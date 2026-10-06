class_name Toasts
extends VBoxContainer
## Avisos que aparecen un momento (un plato que se cae, un cliente habitual...). Tocar uno
## lleva la cámara al sitio donde ha pasado.

signal pressed(cell: Vector2i)

const LIFETIME := 7.0
const MAX_SHOWN := 4


func _ready() -> void:
	add_theme_constant_override("separation", 10)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func add(text: String, cell: Vector2i) -> void:
	var b := Button.new()
	b.text = text
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.add_theme_font_size_override("font_size", 28)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.13, 0.16, 0.2, 0.96)
	style.set_corner_radius_all(14)
	style.border_color = Color("ffd54f")
	style.border_width_left = 8
	style.content_margin_left = 20
	style.content_margin_right = 20
	style.content_margin_top = 10
	style.content_margin_bottom = 10
	for state in ["normal", "hover", "pressed", "focus"]:
		b.add_theme_stylebox_override(state, style)
	for color_name in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		b.add_theme_color_override(color_name, Color.WHITE)
	b.pressed.connect(func():
		pressed.emit(cell)
		b.queue_free())
	add_child(b)
	while get_child_count() > MAX_SHOWN:
		var oldest := get_child(0)
		remove_child(oldest)
		oldest.queue_free()
	var tween := create_tween()
	tween.tween_interval(LIFETIME)
	tween.tween_property(b, "modulate:a", 0.0, 0.6)
	tween.tween_callback(b.queue_free)


## ¿Hay un aviso bajo ese punto de la pantalla?
func covers(screen_pos: Vector2) -> bool:
	for child in get_children():
		if child is Control and child.get_global_rect().has_point(screen_pos):
			return true
	return false
