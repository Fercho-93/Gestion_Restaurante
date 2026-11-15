extends Control
## Pantalla de inicio: el jugador elige en qué barrio abre su restaurante. Cada barrio
## tiene su gente, sus precios, su alquiler y sus horas fuertes.
## Estilo minimalista con paneles de cristal translúcido sobre un fondo claro en azules, grises y blancos.

const INK := Color("2c3e55")  # azul grisáceo oscuro
const SOFT_INK := Color("5d6b7c")
const FAINT_INK := Color("8693a3")
const ACCENT := Color("b7d4ee")  # único acento: azul claro
const GLASS_LINE := Color(1, 1, 1, 0.95)

const BG_SHADER := """
shader_type canvas_item;
float blob(vec2 uv, vec2 c, float r) {
	return smoothstep(r, 0.0, distance(uv, c));
}
void fragment() {
	vec3 col = mix(vec3(0.95, 0.97, 0.99), vec3(0.89, 0.93, 0.97), UV.y);
	col = mix(col, vec3(0.75, 0.86, 0.96), blob(UV, vec2(0.1, 0.08), 0.65) * 0.75);
	col = mix(col, vec3(0.8, 0.88, 0.96), blob(UV, vec2(0.92, 0.5), 0.65) * 0.65);
	col = mix(col, vec3(1.0), blob(UV, vec2(0.5, 0.3), 0.45) * 0.6);
	col = mix(col, vec3(0.82, 0.86, 0.91), blob(UV, vec2(0.25, 1.0), 0.55) * 0.5);
	COLOR = vec4(col, 1.0);
}
"""

const GLASS_SHADER := """
shader_type canvas_item;
uniform vec2 rect_size = vec2(100.0);
uniform float radius = 26.0;
uniform float strength = 1.0;
void fragment() {
	vec2 p = (UV - 0.5) * rect_size;
	vec2 q = abs(p) - rect_size * 0.5 + vec2(radius);
	float d = length(max(q, 0.0)) + min(max(q.x, q.y), 0.0) - radius;
	float edge = 1.0 - smoothstep(-1.0, 0.0, d);
	// velo de cristal: blanco arriba, azul muy claro abajo
	vec3 c = mix(vec3(1.0), vec3(0.92, 0.96, 1.0), UV.y);
	float alpha = mix(0.7, 0.45, UV.y) * strength;
	COLOR = vec4(c, alpha * edge);
}
"""


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	var base := ColorRect.new()  # color base por si el shader no se dibuja
	base.color = Color("e3eef9")
	base.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(base)
	var bg := ColorRect.new()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	var bg_mat := ShaderMaterial.new()
	var bg_shader := Shader.new()
	bg_shader.code = BG_SHADER
	bg_mat.shader = bg_shader
	bg.material = bg_mat
	add_child(bg)

	var scroll := ScrollContainer.new()
	scroll.set_anchors_preset(Control.PRESET_FULL_RECT)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(scroll)
	var margin := MarginContainer.new()
	margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for side in ["left", "right"]:
		margin.add_theme_constant_override("margin_" + side, 64)
	margin.add_theme_constant_override("margin_top", 56)
	margin.add_theme_constant_override("margin_bottom", 56)
	scroll.add_child(margin)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 20)
	margin.add_child(column)

	column.add_child(_label("Gestión Restaurante", 60, INK, true))
	column.add_child(_label("¿En qué barrio abres tu restaurante? Cada barrio tiene su gente, sus precios y su ritmo.", 28, SOFT_INK))
	var gap := Control.new()
	gap.custom_minimum_size = Vector2(0, 14)
	column.add_child(gap)

	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 28)
	grid.add_theme_constant_override("v_separation", 28)
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	column.add_child(grid)
	for barrio_id in GameData.barrios:
		grid.add_child(_card(GameData.barrios[barrio_id]))


## Panel de cristal: desenfoque del fondo + velo claro + borde fino.
func _glass(radius: int) -> PanelContainer:
	var root := PanelContainer.new()
	root.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	root.add_theme_stylebox_override("panel", StyleBoxEmpty.new())
	var blur := ColorRect.new()
	blur.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var mat := ShaderMaterial.new()
	var shader := Shader.new()
	shader.code = GLASS_SHADER
	mat.shader = shader
	mat.set_shader_parameter("radius", float(radius))
	blur.material = mat
	blur.resized.connect(func(): mat.set_shader_parameter("rect_size", blur.size))
	root.add_child(blur)
	var border := Panel.new()
	border.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var bs := StyleBoxFlat.new()
	bs.draw_center = false
	bs.set_corner_radius_all(radius)
	bs.set_border_width_all(1)
	bs.border_color = GLASS_LINE
	border.add_theme_stylebox_override("panel", bs)
	root.add_child(border)
	return root


func _card(b: Dictionary) -> Control:
	var card := _glass(28)
	var inner := MarginContainer.new()
	for side in ["left", "right"]:
		inner.add_theme_constant_override("margin_" + side, 34)
	inner.add_theme_constant_override("margin_top", 30)
	inner.add_theme_constant_override("margin_bottom", 30)
	card.add_child(inner)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 16)
	inner.add_child(box)

	box.add_child(_label(b["nombre"], 38, INK, true))
	box.add_child(_label(b["descripcion"], 24, SOFT_INK))

	var facts := HFlowContainer.new()
	facts.add_theme_constant_override("h_separation", 10)
	facts.add_theme_constant_override("v_separation", 10)
	box.add_child(facts)
	facts.add_child(_chip("Precios " + _price_word(float(b["nivel_precios"]))))
	facts.add_child(_chip("Alquiler %d €/día" % int(b["alquiler_dia"])))
	facts.add_child(_chip(_rush_word(b["grupos_por_hora"])))

	var population: Dictionary = b["poblacion"]
	var ids := population.keys()
	ids.sort_custom(func(x, y): return population[x] > population[y])
	var parts: PackedStringArray = []
	for profile_id in ids:
		var profile: Dictionary = GameData.perfiles[profile_id]
		parts.append("%s %d%%" % [profile["nombre"], roundi(population[profile_id] * 100.0)])
	box.add_child(_label("  ·  ".join(parts), 22, FAINT_INK))

	box.add_child(_label(b["consejo"], 22, SOFT_INK))
	var button := Button.new()
	button.text = "Abrir aquí"
	button.custom_minimum_size = Vector2(0, 72)
	button.add_theme_font_size_override("font_size", 28)
	for state in ["normal", "hover", "pressed", "focus"]:
		var s := StyleBoxFlat.new()
		s.set_corner_radius_all(20)
		s.set_border_width_all(1)
		match state:
			"hover":
				s.bg_color = ACCENT
				s.border_color = Color.WHITE
			"pressed":
				s.bg_color = ACCENT.darkened(0.08)
				s.border_color = Color.WHITE
			_:
				s.bg_color = Color(ACCENT, 0.45)
				s.border_color = Color(1, 1, 1, 0.9)
		button.add_theme_stylebox_override(state, s)
	button.add_theme_color_override("font_color", INK)
	button.add_theme_color_override("font_hover_color", INK)
	button.add_theme_color_override("font_pressed_color", INK)
	button.add_theme_color_override("font_focus_color", INK)
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
		l.add_theme_constant_override("outline_size", 1)
		l.add_theme_color_override("font_outline_color", color)
	return l


func _chip(text: String) -> Control:
	var panel := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(ACCENT, 0.22)
	style.set_corner_radius_all(16)
	style.set_border_width_all(1)
	style.border_color = Color(ACCENT, 0.9)
	style.content_margin_left = 14
	style.content_margin_right = 14
	style.content_margin_top = 4
	style.content_margin_bottom = 4
	panel.add_theme_stylebox_override("panel", style)
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", 22)
	l.add_theme_color_override("font_color", INK)
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
