extends Control
## Pantalla de inicio: el jugador elige en qué barrio abre su restaurante. Cada barrio
## tiene su gente, sus precios, su alquiler y sus horas fuertes.
## Estilo minimalista con paneles de cristal esmerilado sobre un fondo oscuro y suave.

const INK := Color("f4f1ea")
const SOFT_INK := Color(0.96, 0.94, 0.9, 0.62)
const FAINT_INK := Color(0.96, 0.94, 0.9, 0.42)
const ACCENT := Color("d9c7a3")  # único acento: champán suave
const GLASS_LINE := Color(1, 1, 1, 0.2)

const BG_SHADER := """
shader_type canvas_item;
float blob(vec2 uv, vec2 c, float r) {
	return smoothstep(r, 0.0, distance(uv, c));
}
void fragment() {
	vec3 col = mix(vec3(0.075, 0.08, 0.095), vec3(0.13, 0.135, 0.15), UV.y);
	col += vec3(0.85, 0.75, 0.6) * blob(UV, vec2(0.12, 0.1), 0.55) * 0.16;
	col += vec3(0.6, 0.68, 0.8) * blob(UV, vec2(0.9, 0.45), 0.6) * 0.13;
	col += vec3(0.8, 0.8, 0.85) * blob(UV, vec2(0.35, 0.95), 0.6) * 0.1;
	COLOR = vec4(col, 1.0);
}
"""

const GLASS_SHADER := """
shader_type canvas_item;
uniform sampler2D screen_tex : hint_screen_texture, filter_linear_mipmap;
uniform vec2 rect_size = vec2(100.0);
uniform float radius = 26.0;
uniform float blur = 3.0;
uniform vec4 tint : source_color = vec4(1.0, 1.0, 1.0, 0.07);
void fragment() {
	vec2 p = (UV - 0.5) * rect_size;
	vec2 q = abs(p) - rect_size * 0.5 + vec2(radius);
	float d = length(max(q, 0.0)) + min(max(q.x, q.y), 0.0) - radius;
	float a = 1.0 - smoothstep(-1.0, 0.0, d);
	vec3 c = textureLod(screen_tex, SCREEN_UV, blur).rgb;
	c = mix(c, tint.rgb, tint.a);
	c += vec3(0.05) * (1.0 - UV.y);  // brillo sutil arriba
	COLOR = vec4(c, a);
}
"""


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
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
func _glass(radius: int, tint_alpha := 0.07) -> PanelContainer:
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
	mat.set_shader_parameter("tint", Color(1, 1, 1, tint_alpha))
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
				s.bg_color = Color(1, 1, 1, 0.16)
				s.border_color = Color(ACCENT, 0.7)
			"pressed":
				s.bg_color = Color(1, 1, 1, 0.24)
				s.border_color = ACCENT
			_:
				s.bg_color = Color(1, 1, 1, 0.07)
				s.border_color = Color(1, 1, 1, 0.28)
		button.add_theme_stylebox_override(state, s)
	button.add_theme_color_override("font_color", INK)
	button.add_theme_color_override("font_hover_color", ACCENT)
	button.add_theme_color_override("font_pressed_color", ACCENT)
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
	style.bg_color = Color(1, 1, 1, 0.05)
	style.set_corner_radius_all(16)
	style.set_border_width_all(1)
	style.border_color = Color(1, 1, 1, 0.22)
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
