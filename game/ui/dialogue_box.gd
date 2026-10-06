class_name DialogueBox
extends PanelContainer
## Cuadro de conversación entre el gestor y otra persona del local. Abajo en pantalla,
## para que se siga viendo el restaurante. Muestra el retrato en 3D de quien habla (con
## su cara según el ánimo), su nombre, unas chapitas con su estado, un bocadillo con lo
## que dice (letra a letra) y las opciones ordenadas por tipo y color.

signal closed

const INK := Color("37474f")
const PAPER := Color("fffaf2")
## Color de la etiqueta del nombre según quién habla.
const ROLE_COLORS := {
	"cliente": Color("f6a5c0"),
	"camarero": Color("90caf9"),
	"cocina": Color("ef9a9a"),
	"gestor": Color("ffd54f"),
}
## Estilo de cada tipo de opción: [fondo, texto].
const OPTION_STYLES := {
	"trabajo": [Color("66bb6a"), Color.WHITE],
	"coste": [Color("ffca28"), Color("4e342e")],
	"aviso": [Color("ffa726"), Color.WHITE],
	"charla": [Color("eceff1"), Color("37474f")],
	"salir": [Color(0, 0, 0, 0), Color("78909c")],
}
const COST_OPTIONS := ["invitar", "tarta", "compensar"]

var target := {}
var _portrait_frame: Panel
var _portrait_viewport: SubViewport
var _portrait_bot: Bot
var _name_pill: PanelContainer
var _name_label: Label
var _chips: HBoxContainer
var _said_label: Label
var _text_label: Label
var _options: GridContainer
var _typing: Tween


func _ready() -> void:
	add_theme_stylebox_override("panel", _rounded(PAPER, 30, Color(0, 0, 0, 0.35), 26))
	var margin := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 26)
	add_child(margin)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 18)
	margin.add_child(column)

	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 26)
	column.add_child(top)
	top.add_child(_build_portrait())

	var right := VBoxContainer.new()
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right.add_theme_constant_override("separation", 12)
	top.add_child(right)
	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 10)
	right.add_child(header)
	_name_pill = PanelContainer.new()
	_name_label = Label.new()
	_name_label.add_theme_font_size_override("font_size", 30)
	_name_label.add_theme_color_override("font_color", INK)
	_name_pill.add_child(_name_label)
	header.add_child(_name_pill)
	_chips = HBoxContainer.new()
	_chips.add_theme_constant_override("separation", 8)
	_chips.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(_chips)
	var close_button := Button.new()
	close_button.text = "×"
	close_button.custom_minimum_size = Vector2(64, 64)
	close_button.add_theme_font_size_override("font_size", 40)
	_style_button(close_button, Color("eceff1"), INK, 32)
	close_button.pressed.connect(close)
	header.add_child(close_button)

	var bubble := PanelContainer.new()
	bubble.custom_minimum_size = Vector2(0, 130)
	bubble.add_theme_stylebox_override("panel", _rounded(Color.WHITE, 24, Color(0, 0, 0, 0.12), 8, Color("e0e0e0"), 2, 24))
	right.add_child(bubble)
	var bubble_column := VBoxContainer.new()
	bubble_column.add_theme_constant_override("separation", 6)
	bubble.add_child(bubble_column)
	_said_label = Label.new()
	_said_label.add_theme_font_size_override("font_size", 24)
	_said_label.add_theme_color_override("font_color", Color("90a4ae"))
	_said_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	bubble_column.add_child(_said_label)
	_text_label = Label.new()
	_text_label.add_theme_font_size_override("font_size", 34)
	_text_label.add_theme_color_override("font_color", INK)
	_text_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	bubble_column.add_child(_text_label)

	_options = GridContainer.new()
	_options.columns = 3
	_options.add_theme_constant_override("h_separation", 14)
	_options.add_theme_constant_override("v_separation", 12)
	column.add_child(_options)
	hide()


## Retrato redondo con el personaje en 3D (su propio mundo, con luz suave).
func _build_portrait() -> Control:
	_portrait_frame = Panel.new()
	_portrait_frame.custom_minimum_size = Vector2(230, 230)
	_portrait_frame.clip_children = CanvasItem.CLIP_CHILDREN_AND_DRAW
	_portrait_frame.add_theme_stylebox_override("panel", _rounded(Color("f6a5c0"), 115))
	var container := SubViewportContainer.new()
	container.stretch = true
	container.set_anchors_preset(Control.PRESET_FULL_RECT)
	_portrait_frame.add_child(container)
	_portrait_viewport = SubViewport.new()
	_portrait_viewport.own_world_3d = true
	_portrait_viewport.transparent_bg = true
	_portrait_viewport.size = Vector2i(230, 230)
	container.add_child(_portrait_viewport)
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_CLEAR_COLOR
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color(0.9, 0.9, 0.95)
	env.environment.ambient_light_energy = 0.55
	_portrait_viewport.add_child(env)
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-30, 200, 0)
	light.light_energy = 0.9
	_portrait_viewport.add_child(light)
	var camera := Camera3D.new()
	camera.position = Vector3(0.0, 0.55, -1.05)
	camera.fov = 38.0
	_portrait_viewport.add_child(camera)
	camera.look_at_from_position(camera.position, Vector3(0, 0.5, 0))
	return _portrait_frame


func open(new_target: Dictionary) -> void:
	target = new_target
	_set_portrait()
	_name_label.text = Conversation.speaker_name(target)
	_name_pill.add_theme_stylebox_override("panel", _rounded(_role_color(), 22, Color(0, 0, 0, 0), 0, Color(0, 0, 0, 0), 0, 18))
	_said_label.visible = false
	_say(Conversation.opening(target, Game.sim))
	_rebuild_options()
	_refresh_chips()
	if not visible:
		show()
		# Aparece con un fundido suave.
		modulate.a = 0.0
		create_tween().tween_property(self, "modulate:a", 1.0, 0.2)


func close() -> void:
	if visible:
		hide()
		target = {}
		closed.emit()


## ¿Es el gestor hablando consigo mismo (qué hacer)?
func is_self() -> bool:
	return target.get("entity") is Manager


func _process(_delta: float) -> void:
	if not visible or target.is_empty():
		return
	# La cara y las chapitas siguen en directo lo que pasa.
	if _portrait_bot != null:
		var mood := _mood()
		_portrait_bot.eyes = Bot.Eyes.ENFADADO if mood < 0.35 else (Bot.Eyes.NORMAL if mood < 0.65 else Bot.Eyes.FELIZ)
	if Engine.get_process_frames() % 20 == 0:
		_refresh_chips()


func _set_portrait() -> void:
	if _portrait_bot != null:
		_portrait_bot.queue_free()
	var look := Bot.appearance_for(target)
	_portrait_bot = Bot.new()
	_portrait_bot.setup(look[0], look[1])
	_portrait_bot.scale = Vector3.ONE
	_portrait_viewport.add_child(_portrait_bot)
	_portrait_bot.rotation.y = PI * 0.92
	_portrait_bot.face_direction(Vector3(0.15, 0, -1))
	_portrait_frame.add_theme_stylebox_override("panel", _rounded(_role_color().lightened(0.35), 115))


## Las opciones cambian según la situación (y según lo ya hablado).
func _rebuild_options() -> void:
	for child in _options.get_children():
		_options.remove_child(child)
		child.queue_free()
	for option in Conversation.options(target, Game.sim):
		var kind := _option_kind(option)
		var b := Button.new()
		b.text = option["texto"]
		b.custom_minimum_size = Vector2(400, 76)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.add_theme_font_size_override("font_size", 27)
		b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_style_button(b, OPTION_STYLES[kind][0], OPTION_STYLES[kind][1], 22)
		b.pressed.connect(_choose.bind(option["id"], option["texto"], option.get("trabajo", false)))
		_options.add_child(b)
	_fit_height.call_deferred()


## El cuadro se ajusta a lo que contiene (crece y encoge hacia arriba desde abajo).
func _fit_height() -> void:
	offset_top = offset_bottom - get_combined_minimum_size().y


func _choose(option_id: String, said: String, is_work: bool) -> void:
	var answer := Conversation.choose(target, option_id, Game.sim)
	_said_label.text = "Tú: «%s»" % said
	_said_label.visible = true
	_say(answer)
	_refresh_chips()
	if option_id == "adios" or is_work:
		# Se despide y el cuadro se cierra solo al momento.
		for b in _options.get_children():
			b.disabled = true
		get_tree().create_timer(1.4).timeout.connect(close)
		return
	_rebuild_options()


## Lo que dice la persona, apareciendo letra a letra.
func _say(text: String) -> void:
	_text_label.text = "«%s»" % text
	_text_label.visible_ratio = 0.0
	if _typing != null:
		_typing.kill()
	_typing = create_tween()
	_typing.tween_property(_text_label, "visible_ratio", 1.0, clampf(text.length() * 0.018, 0.25, 1.2))


func _refresh_chips() -> void:
	for child in _chips.get_children():
		_chips.remove_child(child)
		child.queue_free()
	for chip in _chip_list():
		var pill := PanelContainer.new()
		pill.add_theme_stylebox_override("panel", _rounded(chip[1], 18, Color(0, 0, 0, 0), 0, Color(0, 0, 0, 0), 0, 14))
		var label := Label.new()
		label.text = chip[0]
		label.add_theme_font_size_override("font_size", 22)
		label.add_theme_color_override("font_color", INK)
		pill.add_child(label)
		_chips.add_child(pill)


## Chapitas: [texto, color] con el estado de quien habla.
func _chip_list() -> Array:
	var e = target.get("entity")
	var list := []
	var mood := _mood()
	var mood_color := Color("c8e6c9") if mood >= 0.65 else (Color("fff3c4") if mood >= 0.4 else Color("ffcdd2"))
	if e is Manager:
		list.append(["Energía %d%%" % roundi(e.energy), mood_color])
		list.append([e.describe(), Color("eceff1")])
	elif e is StaffMember:
		list.append(["Ánimo: %s" % e.moral_word(), mood_color])
		list.append([e.describe_task(), Color("eceff1")])
	elif e is CustomerGroup:
		var words := ["Enfadado", "Impaciente", "Contento", "Encantado"]
		var word: String = words[0] if mood < 0.4 else (words[1] if mood < 0.65 else (words[2] if mood < 0.85 else words[3]))
		list.append([word, mood_color])
		var state: String = e.state_name()
		if CustomerGroup.PATIENCE.has(e.state):
			state += " · %d min" % int(e.state_time)
		list.append([state, Color("eceff1")])
		if e.regular_name != "":
			list.append(["Habitual", Color("e1bee7")])
		if e.birthday:
			list.append(["Cumpleaños", Color("f8bbd0")])
	return list


## Ánimo de 0 a 1 de quien habla.
func _mood() -> float:
	var e = target.get("entity")
	if e is Manager:
		return e.energy / 100.0
	if e is StaffMember:
		return e.moral / 100.0
	if e is CustomerGroup:
		return e.mood()
	return 1.0


func _role_color() -> Color:
	var e = target.get("entity")
	if e is Manager:
		return ROLE_COLORS["gestor"]
	if e is StaffMember:
		return ROLE_COLORS["cocina"] if e.puesto == StaffMember.ROLE_COOK else ROLE_COLORS["camarero"]
	return ROLE_COLORS["cliente"]


func _option_kind(option: Dictionary) -> String:
	if option["id"] == "adios":
		return "salir"
	if option.get("trabajo", false):
		return "trabajo"
	if COST_OPTIONS.has(option["id"]):
		return "coste"
	if option["id"] == "prisa":
		return "aviso"
	return "charla"


func _style_button(b: Button, bg: Color, fg: Color, radius: int) -> void:
	var normal := _rounded(bg, radius, Color(0, 0, 0, 0.18) if bg.a > 0.0 else Color(0, 0, 0, 0), 4 if bg.a > 0.0 else 0)
	var hover := _rounded(bg.lightened(0.12) if bg.a > 0.0 else Color(0, 0, 0, 0.06), radius)
	var pressed := _rounded(bg.darkened(0.12) if bg.a > 0.0 else Color(0, 0, 0, 0.1), radius)
	var disabled := _rounded(Color(bg, bg.a * 0.5), radius)
	for state in ["normal", "focus"]:
		b.add_theme_stylebox_override(state, normal)
	b.add_theme_stylebox_override("hover", hover)
	b.add_theme_stylebox_override("pressed", pressed)
	b.add_theme_stylebox_override("disabled", disabled)
	for color_name in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		b.add_theme_color_override(color_name, fg)
	b.add_theme_color_override("font_disabled_color", Color(fg, 0.5))


static func _rounded(color: Color, radius: int, shadow: Color = Color(0, 0, 0, 0), shadow_size: int = 0,
		border: Color = Color(0, 0, 0, 0), border_width: int = 0, padding: int = 0) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.set_corner_radius_all(radius)
	style.shadow_color = shadow
	style.shadow_size = shadow_size
	style.shadow_offset = Vector2(0, shadow_size * 0.4)
	style.border_color = border
	style.set_border_width_all(border_width)
	style.content_margin_left = padding
	style.content_margin_right = padding
	style.content_margin_top = padding * 0.5
	style.content_margin_bottom = padding * 0.5
	return style
