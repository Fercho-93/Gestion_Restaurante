extends Control
## Pantalla de inicio: el jugador elige en qué barrio abre su restaurante. Cada barrio
## tiene su gente, sus precios, su alquiler y sus horas fuertes.

const BG := Color("f6efe4")
const INK := Color("2b2f3a")
const SOFT_INK := Color("6b6f7a")
const ACCENT := Color("e07a3f")
const BARRIO_COLORS := {
	"universitario": Color("4f8fd8"),
	"acomodado": Color("b08a3e"),
	"alternativo": Color("b0569a"),
	"oficinas": Color("4a9a7c"),
}


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	var bg := ColorRect.new()
	bg.color = BG
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	var scroll := ScrollContainer.new()
	scroll.set_anchors_preset(Control.PRESET_FULL_RECT)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(scroll)
	var margin := MarginContainer.new()
	margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for side in ["left", "right"]:
		margin.add_theme_constant_override("margin_" + side, 64)
	margin.add_theme_constant_override("margin_top", 40)
	margin.add_theme_constant_override("margin_bottom", 40)
	scroll.add_child(margin)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 26)
	margin.add_child(column)

	column.add_child(_label("Gestión Restaurante", 64, INK, true))
	column.add_child(_label("¿En qué barrio abres tu restaurante? Cada barrio tiene su gente, sus precios y su ritmo.", 32, SOFT_INK))

	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 26)
	grid.add_theme_constant_override("v_separation", 26)
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	column.add_child(grid)
	for barrio_id in GameData.barrios:
		grid.add_child(_card(GameData.barrios[barrio_id]))


func _card(b: Dictionary) -> Control:
	var color: Color = BARRIO_COLORS.get(b["id"], ACCENT)
	var card := PanelContainer.new()
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var style := StyleBoxFlat.new()
	style.bg_color = Color.WHITE
	style.set_corner_radius_all(26)
	style.border_color = color
	style.border_width_top = 12
	style.shadow_size = 10
	style.shadow_color = Color(0, 0, 0, 0.12)
	style.content_margin_left = 30
	style.content_margin_right = 30
	style.content_margin_top = 24
	style.content_margin_bottom = 24
	card.add_theme_stylebox_override("panel", style)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 14)
	card.add_child(box)

	box.add_child(_label(b["nombre"], 42, color.darkened(0.25), true))
	box.add_child(_label(b["descripcion"], 26, INK))

	var facts := HBoxContainer.new()
	facts.add_theme_constant_override("separation", 12)
	box.add_child(facts)
	facts.add_child(_chip("Precios " + _price_word(float(b["nivel_precios"])), color))
	facts.add_child(_chip("Alquiler %d €/día" % int(b["alquiler_dia"]), color))
	facts.add_child(_chip(_rush_word(b["grupos_por_hora"]), color))

	var people := HFlowContainer.new()
	people.add_theme_constant_override("h_separation", 10)
	people.add_theme_constant_override("v_separation", 10)
	box.add_child(people)
	var population: Dictionary = b["poblacion"]
	var ids := population.keys()
	ids.sort_custom(func(x, y): return population[x] > population[y])
	for profile_id in ids:
		var profile: Dictionary = GameData.perfiles[profile_id]
		people.add_child(_chip("%s %d%%" % [profile["nombre"], roundi(population[profile_id] * 100.0)], Color("8a8f9c"), true))

	box.add_child(_label("Consejo: " + b["consejo"], 24, SOFT_INK))
	var button := Button.new()
	button.text = "Abrir aquí"
	button.custom_minimum_size = Vector2(0, 84)
	button.add_theme_font_size_override("font_size", 32)
	for state in ["normal", "hover", "pressed", "focus"]:
		var bs := StyleBoxFlat.new()
		bs.bg_color = color if state != "pressed" else color.darkened(0.2)
		bs.set_corner_radius_all(20)
		button.add_theme_stylebox_override(state, bs)
	button.add_theme_color_override("font_color", Color.WHITE)
	button.add_theme_color_override("font_hover_color", Color.WHITE)
	button.add_theme_color_override("font_pressed_color", Color.WHITE)
	button.pressed.connect(Game.start.bind(b["id"]))
	box.add_child(button)
	return card


func _label(text: String, size: int, color: Color, bold := false) -> Label:
	var l := Label.new()
	l.text = text
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	if bold:
		l.add_theme_constant_override("outline_size", 2)
		l.add_theme_color_override("font_outline_color", color)
	return l


func _chip(text: String, color: Color, soft := false) -> Control:
	var panel := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(color, 0.14) if soft else color
	style.set_corner_radius_all(16)
	style.content_margin_left = 14
	style.content_margin_right = 14
	style.content_margin_top = 4
	style.content_margin_bottom = 4
	panel.add_theme_stylebox_override("panel", style)
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", 24)
	l.add_theme_color_override("font_color", INK if soft else Color.WHITE)
	panel.add_child(l)
	return panel


static func _price_word(level: float) -> String:
	if level < 0.9:
		return "bajos"
	if level > 1.2:
		return "altos"
	return "medios"


## Cuándo hay más gente: a mediodía, por la noche o en los dos.
static func _rush_word(per_hour: Dictionary) -> String:
	var lunch := float(per_hour.get("13", 0)) + float(per_hour.get("14", 0))
	var dinner := float(per_hour.get("21", 0)) + float(per_hour.get("22", 0))
	if lunch > dinner * 1.6:
		return "Fuerte a mediodía"
	if dinner > lunch * 1.2:
		return "Fuerte por la noche"
	return "Comidas y cenas"
