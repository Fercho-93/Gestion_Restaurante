extends Control
## Pantalla de inicio: el jugador elige en qué barrio abre su restaurante. Cada barrio
## tiene su gente, sus precios, su alquiler y sus horas fuertes.
## Estilo "selector de nivel" de videojuego: ciudad nocturna con parallax, tarjetas con
## emblema, barras de estadísticas por segmentos y un color de ambiente por barrio.

const INK := Color("eef2ff")
const SOFT_INK := Color("b4bfdc")
const FAINT_INK := Color("7f8cab")
const PANEL := Color(0.045, 0.06, 0.125, 0.88)
const DEFAULT_COLOR := Color("4fc3f7")

## Color de ambiente de cada barrio (acento de su tarjeta y tinte del cielo).
const DISTRICT_COLORS := {
	"universitario": Color("4fc3f7"),
	"acomodado": Color("ffd166"),
	"alternativo": Color("ff6fb5"),
	"oficinas": Color("9aa8ff"),
}

const BG_SHADER := """
shader_type canvas_item;
uniform vec3 tint = vec3(0.31, 0.76, 0.97);
float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}
void fragment() {
	vec2 uv = UV;
	vec3 top = vec3(0.015, 0.02, 0.07);
	vec3 hor = mix(vec3(0.05, 0.06, 0.17), tint * 0.5, 0.6);
	vec3 col = mix(top, hor, pow(uv.y, 1.5));
	col += tint * 0.22 * smoothstep(0.6, 1.0, uv.y);
	// luna / foco de luz lejano
	float d = distance(uv * vec2(1.78, 1.0), vec2(1.35, 0.26));
	col += tint * 0.16 * smoothstep(0.55, 0.0, d);
	col += vec3(1.0) * 0.10 * smoothstep(0.07, 0.04, d);
	// estrellas parpadeantes
	vec2 g = uv * vec2(170.0, 96.0);
	vec2 id = floor(g);
	float h = hash(id);
	vec2 f = fract(g) - 0.5;
	float tw = 0.5 + 0.5 * sin(TIME * (1.0 + h * 3.0) + h * 40.0);
	float star = step(0.968, h) * smoothstep(0.38, 0.0, length(f)) * tw;
	col += vec3(star) * (1.0 - uv.y) * 0.9;
	// viñeta
	float v = smoothstep(1.15, 0.25, distance(uv, vec2(0.5)));
	col *= mix(0.5, 1.0, v);
	// líneas de escaneo muy sutiles
	col *= 0.97 + 0.03 * sin(uv.y * 900.0);
	COLOR = vec4(col, 1.0);
}
"""

var _cards: Array = []
var _ids: Array = []
var _selected := -1
var _tint := DEFAULT_COLOR
var _bg_mat: ShaderMaterial
var _skyline: Skyline
var _grid: GridContainer
var _subtitle: Label
var _bold: FontVariation
var _tint_tween: Tween


# --- Piezas dibujadas a mano -------------------------------------------------------------

## Silueta de ciudad en dos capas con ventanas que parpadean y parallax con el ratón.
class Skyline extends Control:
	var tint := Color("4fc3f7")
	var _layers: Array = []
	var _time := 0.0
	var _par := 0.0

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		set_anchors_preset(Control.PRESET_FULL_RECT)
		resized.connect(_build)

	func _build() -> void:
		_layers.clear()
		if size.x < 10.0:
			return
		var rng := RandomNumberGenerator.new()
		rng.seed = 20481
		var specs: Array = [
			{"hmin": 0.22, "hmax": 0.46, "wmin": 70.0, "wmax": 140.0, "par": 14.0, "lit": 0.25},
			{"hmin": 0.10, "hmax": 0.30, "wmin": 90.0, "wmax": 190.0, "par": 36.0, "lit": 0.16},
		]
		for spec in specs:
			var buildings: Array = []
			var x := -220.0
			while x < size.x + 220.0:
				var w: float = rng.randf_range(spec["wmin"], spec["wmax"])
				var h: float = rng.randf_range(spec["hmin"], spec["hmax"]) * size.y
				var wins: Array = []
				var cols: int = int(w / 18.0)
				var rows: int = int(h / 26.0)
				for cx in cols:
					for ry in rows:
						if rng.randf() < float(spec["lit"]):
							wins.append(Vector3(cx * 18.0 + 7.0, ry * 26.0 + 14.0, rng.randf() * TAU))
				buildings.append({"x": x, "w": w, "h": h, "wins": wins})
				x += w + rng.randf_range(0.0, 14.0)
			_layers.append({"par": float(spec["par"]), "b": buildings})
		queue_redraw()

	func _process(delta: float) -> void:
		_time += delta
		if size.x > 0.0:
			var target := clampf(get_local_mouse_position().x / size.x - 0.5, -0.5, 0.5)
			_par = lerpf(_par, target, minf(1.0, delta * 3.0))
		queue_redraw()

	func _draw() -> void:
		var base_y := size.y
		for li in _layers.size():
			var layer: Dictionary = _layers[li]
			var off: float = -_par * float(layer["par"])
			var body := Color(0.05, 0.07, 0.15).lerp(tint, 0.12)
			if li == 1:
				body = Color(0.015, 0.02, 0.05).lerp(tint, 0.04)
			for b in layer["b"]:
				var bx: float = float(b["x"]) + off
				var bw: float = b["w"]
				var bh: float = b["h"]
				var top := base_y - bh
				draw_rect(Rect2(bx, top, bw, bh + 2.0), body)
				draw_rect(Rect2(bx, top, bw, 2.0), Color(tint, 0.35 if li == 0 else 0.18))
				for w in b["wins"]:
					var v: Vector3 = w
					var a := 0.35 + 0.65 * (0.5 + 0.5 * sin(_time * 0.7 + v.z))
					var c := Color(1.0, 0.83, 0.5, a * 0.9)
					if fmod(v.z, 2.0) > 1.0:
						c = Color(tint.lerp(Color.WHITE, 0.4), a * 0.8)
					draw_rect(Rect2(bx + v.x, top + v.y, 5.0, 8.0), c)
		# neblina baja
		draw_rect(Rect2(0, base_y - 90.0, size.x, 90.0), Color(tint, 0.06))


## Emblema circular de cada barrio (birrete, corona, estrella, torres).
class Emblem extends Control:
	var kind := ""
	var col := Color.WHITE
	var active := false:
		set(v):
			active = v
			set_process(v)
			queue_redraw()
	var _t := 0.0

	func _init(k: String, c: Color) -> void:
		kind = k
		col = c
		custom_minimum_size = Vector2(92, 92)
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		set_process(false)

	func _process(delta: float) -> void:
		_t += delta
		queue_redraw()

	func _draw() -> void:
		var c := size / 2.0
		draw_circle(c, 44.0, Color(col, 0.12 if not active else 0.22))
		draw_arc(c, 44.0, 0.0, TAU, 64, Color(col, 0.55 if not active else 1.0), 2.0, true)
		if active:
			draw_arc(c, 50.0, _t * 2.2, _t * 2.2 + 1.5, 24, Color(col, 0.9), 3.0, true)
			draw_arc(c, 50.0, _t * 2.2 + PI, _t * 2.2 + PI + 0.7, 16, Color(col, 0.5), 3.0, true)
		var solid := Color(col, 1.0)
		var soft := Color(col, 0.65)
		match kind:
			"universitario":
				draw_colored_polygon(PackedVector2Array([c + Vector2(0, -17), c + Vector2(27, -5), c + Vector2(0, 7), c + Vector2(-27, -5)]), solid)
				draw_colored_polygon(PackedVector2Array([c + Vector2(-14, 2), c + Vector2(-14, 14), c + Vector2(0, 21), c + Vector2(14, 14), c + Vector2(14, 2), c + Vector2(0, 9)]), soft)
				draw_line(c + Vector2(24, -4), c + Vector2(24, 12), solid, 2.0)
				draw_circle(c + Vector2(24, 14), 2.5, solid)
			"acomodado":
				draw_colored_polygon(PackedVector2Array([c + Vector2(-22, 12), c + Vector2(-22, -10), c + Vector2(-11, 1), c + Vector2(0, -17), c + Vector2(11, 1), c + Vector2(22, -10), c + Vector2(22, 12)]), solid)
				draw_rect(Rect2(c + Vector2(-22, 15), Vector2(44, 6)), soft)
				draw_circle(c + Vector2(0, 4), 3.0, Color(0.05, 0.06, 0.12))
			"alternativo":
				var pts := PackedVector2Array()
				for i in 10:
					var r := 25.0 if i % 2 == 0 else 10.5
					var a := -PI / 2.0 + i * PI / 5.0
					pts.append(c + Vector2(cos(a), sin(a)) * r)
				draw_colored_polygon(pts, solid)
			_:
				draw_rect(Rect2(c + Vector2(-23, -2), Vector2(13, 23)), soft)
				draw_rect(Rect2(c + Vector2(-7, -21), Vector2(15, 42)), solid)
				draw_rect(Rect2(c + Vector2(11, -10), Vector2(13, 31)), soft)
				var dark := Color(0.05, 0.06, 0.12)
				for row in 4:
					draw_rect(Rect2(c + Vector2(-3, -16 + row * 9), Vector2(3, 4)), dark)
					draw_rect(Rect2(c + Vector2(3, -16 + row * 9), Vector2(3, 4)), dark)


## Barra de estadística por segmentos, al estilo de los atributos de un RPG.
class SegBar extends Control:
	const SEGS := 10
	var value := 0.0
	var col := Color.WHITE
	var shown := 0.0:
		set(v):
			shown = v
			queue_redraw()

	func _init(v: float, c: Color) -> void:
		value = clampf(v, 0.0, 1.0)
		col = c
		custom_minimum_size = Vector2(60, 14)
		size_flags_horizontal = Control.SIZE_EXPAND_FILL
		size_flags_vertical = Control.SIZE_SHRINK_CENTER
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func grow() -> void:
		create_tween().tween_property(self, "shown", value, 0.8).set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_OUT)

	func _draw() -> void:
		var gap := 4.0
		var w := (size.x - gap * (SEGS - 1)) / SEGS
		var filled := shown * SEGS
		for i in SEGS:
			var r := Rect2(i * (w + gap), 0.0, w, size.y)
			draw_rect(r, Color(1, 1, 1, 0.08))
			var f := clampf(filled - i, 0.0, 1.0)
			if f > 0.0:
				draw_rect(Rect2(r.position, Vector2(w * f, r.size.y)), col)


## Tarjeta de barrio: se ilumina y crece al seleccionarla; el resto se atenúa.
class Card extends PanelContainer:
	signal chosen(index: int)
	var index := 0
	var col := Color.WHITE
	var emblem: Emblem
	var bars: Array = []
	var glow := 0.0
	var shade := 0.62:
		set(v):
			shade = v
			modulate = Color(shade, shade, shade * 1.04, alpha)
	var alpha := 0.0:
		set(v):
			alpha = v
			modulate = Color(shade, shade, shade * 1.04, alpha)
	var _style: StyleBoxFlat
	var _tw: Tween

	func _init(i: int, c: Color) -> void:
		index = i
		col = c
		size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_style = StyleBoxFlat.new()
		_style.bg_color = PANEL
		_style.set_corner_radius_all(20)
		_style.set_border_width_all(2)
		_style.border_color = Color(c, 0.25)
		_style.content_margin_left = 28
		_style.content_margin_right = 28
		_style.content_margin_top = 26
		_style.content_margin_bottom = 26
		_style.shadow_color = Color(c, 0.0)
		_style.shadow_size = 0
		add_theme_stylebox_override("panel", _style)
		modulate = Color(shade, shade, shade * 1.04, alpha)
		resized.connect(func(): pivot_offset = size / 2.0)
		mouse_entered.connect(func(): chosen.emit(index))
		gui_input.connect(_on_gui_input)

	func _on_gui_input(e: InputEvent) -> void:
		if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
			chosen.emit(index)

	func _set_glow(g: float) -> void:
		glow = g
		_style.border_color = Color(col, lerpf(0.25, 1.0, g))
		_style.shadow_color = Color(col, 0.5 * g)
		_style.shadow_size = int(36.0 * g)
		_style.bg_color = PANEL.lerp(Color(col.r * 0.12 + 0.03, col.g * 0.12 + 0.04, col.b * 0.12 + 0.09, 0.92), g)

	func set_selected(on: bool) -> void:
		if _tw and _tw.is_valid():
			_tw.kill()
		_tw = create_tween().set_parallel(true).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		_tw.tween_property(self, "scale", Vector2.ONE * (1.045 if on else 1.0), 0.22)
		_tw.tween_property(self, "shade", 1.0 if on else 0.62, 0.22)
		_tw.tween_method(_set_glow, glow, 1.0 if on else 0.0, 0.22)
		z_index = 2 if on else 0
		emblem.active = on

	func intro(delay: float) -> void:
		var t := create_tween()
		t.tween_interval(delay)
		t.tween_property(self, "alpha", 1.0, 0.55).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		t.tween_callback(func():
			for b in bars:
				b.grow())


# --- Montaje de la pantalla --------------------------------------------------------------

func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_bold = FontVariation.new()
	_bold.base_font = ThemeDB.fallback_font
	_bold.variation_embolden = 0.45

	var base := ColorRect.new()  # color base por si el shader no se dibuja
	base.color = Color("060914")
	base.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(base)
	var bg := ColorRect.new()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	_bg_mat = ShaderMaterial.new()
	var bg_shader := Shader.new()
	bg_shader.code = BG_SHADER
	_bg_mat.shader = bg_shader
	bg.material = _bg_mat
	add_child(bg)
	_skyline = Skyline.new()
	add_child(_skyline)

	var scroll := ScrollContainer.new()
	scroll.set_anchors_preset(Control.PRESET_FULL_RECT)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(scroll)
	var margin := MarginContainer.new()
	margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	margin.size_flags_vertical = Control.SIZE_EXPAND_FILL
	for side in ["left", "right"]:
		margin.add_theme_constant_override("margin_" + side, 70)
	margin.add_theme_constant_override("margin_top", 36)
	margin.add_theme_constant_override("margin_bottom", 30)
	scroll.add_child(margin)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 14)
	column.size_flags_vertical = Control.SIZE_EXPAND_FILL
	margin.add_child(column)

	_build_title(column)
	column.add_child(_spacer(true))

	_grid = GridContainer.new()
	_grid.columns = 4
	_grid.add_theme_constant_override("h_separation", 26)
	_grid.add_theme_constant_override("v_separation", 26)
	_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	column.add_child(_grid)

	var max_flow := 1.0
	for barrio_id in GameData.barrios:
		max_flow = maxf(max_flow, _flow(GameData.barrios[barrio_id]))
	var i := 0
	for barrio_id in GameData.barrios:
		var card := _card(GameData.barrios[barrio_id], i, max_flow)
		_grid.add_child(card)
		_cards.append(card)
		_ids.append(barrio_id)
		card.chosen.connect(_select)
		card.intro(0.25 + 0.14 * i)
		i += 1

	column.add_child(_spacer(true))
	var hint := _label("Flechas para elegir   ·   Intro para abrir   ·   o toca una tarjeta", 20, FAINT_INK)
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(hint)

	resized.connect(_on_resized)
	_on_resized()
	_apply_tint(DEFAULT_COLOR)
	_select(0)


func _on_resized() -> void:
	_grid.columns = 4 if size.x >= 1500.0 else 2


func _build_title(column: VBoxContainer) -> void:
	var title := _label("GESTIÓN", 104, INK, true)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.autowrap_mode = TextServer.AUTOWRAP_OFF
	var spaced := FontVariation.new()
	spaced.base_font = ThemeDB.fallback_font
	spaced.variation_embolden = 0.6
	spaced.spacing_glyph = 12
	title.add_theme_font_override("font", spaced)
	title.add_theme_color_override("font_shadow_color", Color(DEFAULT_COLOR, 0.55))
	title.add_theme_constant_override("shadow_offset_x", 0)
	title.add_theme_constant_override("shadow_offset_y", 0)
	title.add_theme_constant_override("shadow_outline_size", 22)
	column.add_child(title)

	var sub := _label("RESTAURANTE", 40, DEFAULT_COLOR, true)
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub.autowrap_mode = TextServer.AUTOWRAP_OFF
	var sub_font := FontVariation.new()
	sub_font.base_font = ThemeDB.fallback_font
	sub_font.variation_embolden = 0.4
	sub_font.spacing_glyph = 26
	sub.add_theme_font_override("font", sub_font)
	column.add_child(sub)
	_subtitle = sub

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 22)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	var choose := _label("ELIGE TU BARRIO", 24, SOFT_INK)
	choose.autowrap_mode = TextServer.AUTOWRAP_OFF
	var line_a := _line()
	var line_b := _line()
	row.add_child(line_a)
	row.add_child(choose)
	row.add_child(line_b)
	column.add_child(row)

	title.modulate.a = 0.0
	sub.modulate.a = 0.0
	row.modulate.a = 0.0
	var t := create_tween().set_parallel(true)
	t.tween_property(title, "modulate:a", 1.0, 0.7).set_trans(Tween.TRANS_CUBIC)
	t.tween_property(sub, "modulate:a", 1.0, 0.7).set_delay(0.15).set_trans(Tween.TRANS_CUBIC)
	t.tween_property(row, "modulate:a", 1.0, 0.7).set_delay(0.3).set_trans(Tween.TRANS_CUBIC)
	var pulse := choose.create_tween().set_loops()
	pulse.tween_property(choose, "modulate:a", 0.45, 1.1).set_trans(Tween.TRANS_SINE)
	pulse.tween_property(choose, "modulate:a", 1.0, 1.1).set_trans(Tween.TRANS_SINE)


func _line() -> Control:
	var r := ColorRect.new()
	r.color = Color(1, 1, 1, 0.22)
	r.custom_minimum_size = Vector2(120, 2)
	r.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	return r


func _spacer(expand: bool) -> Control:
	var s := Control.new()
	s.custom_minimum_size = Vector2(0, 8)
	if expand:
		s.size_flags_vertical = Control.SIZE_EXPAND_FILL
	return s


# --- Selección --------------------------------------------------------------------------

func _select(i: int) -> void:
	if i == _selected or i < 0 or i >= _cards.size():
		return
	if _selected >= 0:
		_cards[_selected].set_selected(false)
	_selected = i
	_cards[i].set_selected(true)
	var target: Color = DISTRICT_COLORS.get(_ids[i], DEFAULT_COLOR)
	if _tint_tween and _tint_tween.is_valid():
		_tint_tween.kill()
	_tint_tween = create_tween()
	_tint_tween.tween_method(_apply_tint, _tint, target, 0.5).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)


func _apply_tint(c: Color) -> void:
	_tint = c
	_bg_mat.set_shader_parameter("tint", Vector3(c.r, c.g, c.b))
	_skyline.tint = c
	_subtitle.add_theme_color_override("font_color", c)
	_subtitle.add_theme_color_override("font_outline_color", c)


func _unhandled_input(event: InputEvent) -> void:
	if _cards.is_empty():
		return
	var n := _cards.size()
	if event.is_action_pressed("ui_left") or event.is_action_pressed("ui_up"):
		_select((maxi(_selected, 0) - 1 + n) % n)
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("ui_right") or event.is_action_pressed("ui_down"):
		_select((maxi(_selected, 0) + 1) % n)
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("ui_accept") and _selected >= 0:
		Game.start(_ids[_selected])
		get_viewport().set_input_as_handled()


# --- Tarjeta de barrio ------------------------------------------------------------------

func _card(b: Dictionary, index: int, max_flow: float) -> Control:
	var col: Color = DISTRICT_COLORS.get(b["id"], DEFAULT_COLOR)
	var card := Card.new(index, col)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 12)
	card.add_child(box)

	# Cabecera: emblema + "ZONA 0X" + nombre
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 16)
	box.add_child(head)
	var emblem := Emblem.new(b["id"], col)
	card.emblem = emblem
	head.add_child(emblem)
	var titles := VBoxContainer.new()
	titles.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	titles.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	titles.add_theme_constant_override("separation", 2)
	head.add_child(titles)
	titles.add_child(_label("ZONA %02d" % (index + 1), 18, col, true))
	titles.add_child(_label(b["nombre"], 30, INK, true))

	box.add_child(_label(b["descripcion"], 19, SOFT_INK))
	box.add_child(_rule(col))

	# Estadísticas
	var price := float(b["nivel_precios"])
	var rent := float(b["alquiler_dia"])
	var flow := _flow(b)
	card.bars.append(_stat(box, "PRECIOS", clampf(price / 1.5, 0.0, 1.0), col, _price_word(price).capitalize()))
	card.bars.append(_stat(box, "ALQUILER", clampf(rent / 160.0, 0.0, 1.0), col, "%d €/día" % int(rent)))
	card.bars.append(_stat(box, "AFLUENCIA", clampf(flow / max_flow, 0.0, 1.0), col, _flow_word(flow / max_flow)))

	var facts := HFlowContainer.new()
	facts.add_theme_constant_override("h_separation", 8)
	facts.add_theme_constant_override("v_separation", 8)
	box.add_child(facts)
	facts.add_child(_chip(_rush_word(b["grupos_por_hora"]), col))

	var population: Dictionary = b["poblacion"]
	var ids := population.keys()
	ids.sort_custom(func(x, y): return population[x] > population[y])
	var parts: PackedStringArray = []
	for profile_id in ids.slice(0, 3):
		var profile: Dictionary = GameData.perfiles[profile_id]
		parts.append("%s %d%%" % [profile["nombre"], roundi(population[profile_id] * 100.0)])
	box.add_child(_label("GENTE", 16, FAINT_INK, true))
	box.add_child(_label("  ·  ".join(parts), 18, SOFT_INK))

	box.add_child(_label("CONSEJO", 16, FAINT_INK, true))
	box.add_child(_label(b["consejo"], 18, SOFT_INK))

	var push := Control.new()
	push.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.add_child(push)

	var button := Button.new()
	button.text = "ABRIR AQUÍ  »"
	button.focus_mode = Control.FOCUS_NONE
	button.custom_minimum_size = Vector2(0, 64)
	button.add_theme_font_size_override("font_size", 26)
	button.add_theme_font_override("font", _bold)
	for state in ["normal", "hover", "pressed"]:
		var s := StyleBoxFlat.new()
		s.set_corner_radius_all(14)
		s.set_border_width_all(2)
		s.border_color = col
		match state:
			"hover":
				s.bg_color = Color(col, 0.9)
			"pressed":
				s.bg_color = col.darkened(0.15)
			_:
				s.bg_color = Color(col, 0.12)
		button.add_theme_stylebox_override(state, s)
	button.add_theme_color_override("font_color", col)
	button.add_theme_color_override("font_hover_color", Color("0a0e1c"))
	button.add_theme_color_override("font_pressed_color", Color("0a0e1c"))
	button.pressed.connect(Game.start.bind(b["id"]))
	box.add_child(button)
	return card


## Fila de atributo: nombre, barra por segmentos y valor.
func _stat(parent: Control, caption: String, value: float, col: Color, value_text: String) -> SegBar:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	parent.add_child(row)
	var name_label := _label(caption, 17, FAINT_INK, true)
	name_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	name_label.custom_minimum_size = Vector2(104, 0)
	row.add_child(name_label)
	var bar := SegBar.new(value, col)
	row.add_child(bar)
	var val := _label(value_text, 18, INK)
	val.autowrap_mode = TextServer.AUTOWRAP_OFF
	val.custom_minimum_size = Vector2(92, 0)
	val.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	row.add_child(val)
	return bar


func _rule(col: Color) -> Control:
	var r := ColorRect.new()
	r.color = Color(col, 0.28)
	r.custom_minimum_size = Vector2(0, 1)
	return r


func _label(text: String, size: int, color: Color, bold := false) -> Label:
	var l := Label.new()
	l.text = text
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	if bold:
		l.add_theme_font_override("font", _bold)
	return l


func _chip(text: String, col: Color) -> Control:
	var panel := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(col, 0.14)
	style.set_corner_radius_all(8)
	style.set_border_width_all(1)
	style.border_color = Color(col, 0.7)
	style.content_margin_left = 12
	style.content_margin_right = 12
	style.content_margin_top = 4
	style.content_margin_bottom = 4
	panel.add_theme_stylebox_override("panel", style)
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", 18)
	l.add_theme_color_override("font_color", INK)
	panel.add_child(l)
	return panel


static func _price_word(level: float) -> String:
	if level < 0.9:
		return "bajos"
	if level > 1.2:
		return "altos"
	return "medios"


## Total de grupos de clientes que pasan en un día típico.
static func _flow(b: Dictionary) -> float:
	var total := 0.0
	var per_hour: Dictionary = b["grupos_por_hora"]
	for h in per_hour:
		total += float(per_hour[h])
	return total


static func _flow_word(ratio: float) -> String:
	if ratio > 0.85:
		return "Muy alta"
	if ratio > 0.62:
		return "Alta"
	return "Media"


## Cuándo hay más gente: a mediodía, por la noche o en los dos.
static func _rush_word(per_hour: Dictionary) -> String:
	var lunch := float(per_hour.get("13", 0)) + float(per_hour.get("14", 0))
	var dinner := float(per_hour.get("21", 0)) + float(per_hour.get("22", 0))
	if lunch > dinner * 1.6:
		return "Fuerte a mediodía"
	if dinner > lunch * 1.2:
		return "Fuerte por la noche"
	return "Comidas y cenas"
