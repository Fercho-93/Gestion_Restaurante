class_name StartScreen
extends Control
## Pantalla de inicio: el jugador elige en qué barrio abre su restaurante. Cada barrio
## tiene su gente, sus precios, su alquiler y sus horas fuertes.
## Estilo de selector de nivel, pero luminoso y artesanal: cielo de día, ciudad plana en
## azules y grises, nubes que pasan y tarjetas blancas con contorno y sombra suave.

const INK := Color("2c3e55")  # azul grisáceo oscuro
const SOFT_INK := Color("55657a")
const FAINT_INK := Color("8190a3")
const PAPER := Color("fbfdff")
const DEFAULT_COLOR := Color("8ec1ec")

## Acento (pastel) de cada barrio.
const DISTRICT_COLORS := {
	"universitario": Color("8ec1ec"),
	"acomodado": Color("e6c98b"),
	"alternativo": Color("eaa9bf"),
	"oficinas": Color("a9b7e6"),
}

const BG_SHADER := """
shader_type canvas_item;
void fragment() {
	vec3 top = vec3(0.72, 0.85, 0.96);
	vec3 low = vec3(0.95, 0.97, 0.99);
	vec3 col = mix(top, low, smoothstep(0.0, 0.85, UV.y));
	// sol grande y suave
	float d = distance(UV * vec2(1.78, 1.0), vec2(1.45, 0.24));
	col = mix(col, vec3(1.0, 0.98, 0.93), smoothstep(0.34, 0.0, d) * 0.55);
	col = mix(col, vec3(1.0, 0.99, 0.95), smoothstep(0.085, 0.075, d));
	COLOR = vec4(col, 1.0);
}
"""

var _cards: Array = []
var _ids: Array = []
var _selected := -1
var _grid: GridContainer
var _bold: FontVariation


# --- Piezas dibujadas a mano -------------------------------------------------------------

## Ciudad plana en dos capas, nubes a la deriva y un poco de parallax con el ratón.
class Skyline extends Control:
	var _layers: Array = []
	var _clouds: Array = []
	var _time := 0.0
	var _par := 0.0

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		set_anchors_preset(Control.PRESET_FULL_RECT)
		resized.connect(_build)

	func _build() -> void:
		_layers.clear()
		_clouds.clear()
		if size.x < 10.0:
			return
		var rng := RandomNumberGenerator.new()
		rng.seed = 7741
		var specs: Array = [
			{"hmin": 0.20, "hmax": 0.42, "wmin": 70.0, "wmax": 140.0, "par": 12.0, "body": Color("cfdeee"), "win": Color("e6eff8")},
			{"hmin": 0.09, "hmax": 0.27, "wmin": 90.0, "wmax": 190.0, "par": 30.0, "body": Color("b4c8de"), "win": Color("d6e3f1")},
		]
		for spec in specs:
			var buildings: Array = []
			var x := -220.0
			while x < size.x + 220.0:
				var w: float = rng.randf_range(spec["wmin"], spec["wmax"])
				var h: float = rng.randf_range(spec["hmin"], spec["hmax"]) * size.y
				var wins: Array = []
				var cols: int = int(w / 20.0)
				var rows: int = int(h / 28.0)
				for cx in cols:
					for ry in rows:
						if rng.randf() < 0.55:
							wins.append(Vector2(cx * 20.0 + 8.0, ry * 28.0 + 14.0))
				buildings.append({"x": x, "w": w, "h": h, "wins": wins})
				x += w + rng.randf_range(0.0, 12.0)
			_layers.append({"par": float(spec["par"]), "body": spec["body"], "win": spec["win"], "b": buildings})
		for i in 6:
			_clouds.append({
				"x": rng.randf_range(0.0, size.x),
				"y": rng.randf_range(0.05, 0.38) * size.y,
				"s": rng.randf_range(0.7, 1.4),
				"v": rng.randf_range(6.0, 16.0),
			})
		queue_redraw()

	func _process(delta: float) -> void:
		_time += delta
		if size.x > 0.0:
			var target := clampf(get_local_mouse_position().x / size.x - 0.5, -0.5, 0.5)
			_par = lerpf(_par, target, minf(1.0, delta * 3.0))
		queue_redraw()

	func _draw() -> void:
		for c in _clouds:
			var cx: float = fposmod(float(c["x"]) + _time * float(c["v"]), size.x + 400.0) - 200.0
			var s: float = c["s"]
			var p := Vector2(cx, c["y"])
			var white := Color(1, 1, 1, 0.85)
			draw_circle(p, 26.0 * s, white)
			draw_circle(p + Vector2(30, 6) * s, 32.0 * s, white)
			draw_circle(p + Vector2(66, 8) * s, 24.0 * s, white)
			draw_rect(Rect2(p + Vector2(-20, 8) * s, Vector2(104, 22) * s), white)
		var base_y := size.y
		for layer in _layers:
			var off: float = -_par * float(layer["par"])
			var body: Color = layer["body"]
			var win: Color = layer["win"]
			for b in layer["b"]:
				var bx: float = float(b["x"]) + off
				var bh: float = b["h"]
				var top := base_y - bh
				draw_rect(Rect2(bx, top, b["w"], bh + 2.0), body)
				for w in b["wins"]:
					var v: Vector2 = w
					draw_rect(Rect2(bx + v.x, top + v.y, 6.0, 10.0), win)
		draw_rect(Rect2(0, base_y - 26.0, size.x, 26.0), Color("e4edf6"))


## Emblema redondo de cada barrio (birrete, corona, estrella, torres).
class Emblem extends Control:
	var kind := ""
	var col := Color.WHITE
	var ink := Color("2c3e55")
	var active := false:
		set(v):
			active = v
			queue_redraw()

	func _init(k: String, c: Color) -> void:
		kind = k
		col = c
		custom_minimum_size = Vector2(88, 88)
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		var c := size / 2.0
		draw_circle(c, 42.0, col if active else col.lightened(0.45))
		draw_arc(c, 41.0, 0.0, TAU, 48, ink, 3.0, true)
		match kind:
			"universitario":
				draw_colored_polygon(PackedVector2Array([c + Vector2(0, -16), c + Vector2(26, -5), c + Vector2(0, 7), c + Vector2(-26, -5)]), ink)
				draw_colored_polygon(PackedVector2Array([c + Vector2(-14, 2), c + Vector2(-14, 13), c + Vector2(0, 20), c + Vector2(14, 13), c + Vector2(14, 2), c + Vector2(0, 9)]), ink.lightened(0.15))
				draw_line(c + Vector2(23, -4), c + Vector2(23, 11), ink, 2.5)
				draw_circle(c + Vector2(23, 13), 2.5, ink)
			"acomodado":
				draw_colored_polygon(PackedVector2Array([c + Vector2(-21, 11), c + Vector2(-21, -10), c + Vector2(-10, 1), c + Vector2(0, -16), c + Vector2(10, 1), c + Vector2(21, -10), c + Vector2(21, 11)]), ink)
				draw_rect(Rect2(c + Vector2(-21, 14), Vector2(42, 6)), ink.lightened(0.15))
			"alternativo":
				var pts := PackedVector2Array()
				for i in 10:
					var r := 24.0 if i % 2 == 0 else 10.0
					var a := -PI / 2.0 + i * PI / 5.0
					pts.append(c + Vector2(cos(a), sin(a)) * r)
				draw_colored_polygon(pts, ink)
			_:
				draw_rect(Rect2(c + Vector2(-22, -2), Vector2(13, 22)), ink.lightened(0.15))
				draw_rect(Rect2(c + Vector2(-7, -20), Vector2(15, 40)), ink)
				draw_rect(Rect2(c + Vector2(11, -10), Vector2(12, 30)), ink.lightened(0.15))
				for row in 4:
					draw_rect(Rect2(c + Vector2(-3, -15 + row * 9), Vector2(3, 4)), PAPER)
					draw_rect(Rect2(c + Vector2(3, -15 + row * 9), Vector2(3, 4)), PAPER)


## Barra de estadística por segmentos redondeados.
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
		create_tween().tween_property(self, "shown", value, 0.7).set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_OUT)

	func _draw() -> void:
		var gap := 4.0
		var w := (size.x - gap * (SEGS - 1)) / SEGS
		var filled := shown * SEGS
		var empty := StyleBoxFlat.new()
		empty.bg_color = Color("e1eaf3")
		empty.set_corner_radius_all(4)
		var full := StyleBoxFlat.new()
		full.bg_color = col.darkened(0.12)
		full.set_corner_radius_all(4)
		for i in SEGS:
			var r := Rect2(i * (w + gap), 0.0, w, size.y)
			draw_style_box(full if i < ceili(filled) and filled - i > 0.5 else empty, r)


## Tarjeta de barrio: al seleccionarla se levanta y se tiñe de su color.
class Card extends PanelContainer:
	signal chosen(index: int)
	var index := 0
	var col := Color.WHITE
	var emblem: Emblem
	var bars: Array = []
	var glow := 0.0
	var alpha := 0.0:
		set(v):
			alpha = v
			modulate = Color(1, 1, 1, alpha)
	var _style: StyleBoxFlat
	var _tw: Tween

	func _init(i: int, c: Color) -> void:
		index = i
		col = c
		size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_style = StyleBoxFlat.new()
		_style.bg_color = Color("fbfdff")
		_style.set_corner_radius_all(22)
		_style.set_border_width_all(2)
		_style.border_color = Color("2c3e55")
		_style.content_margin_left = 26
		_style.content_margin_right = 26
		_style.content_margin_top = 24
		_style.content_margin_bottom = 24
		_style.shadow_color = Color(0.17, 0.24, 0.33, 0.14)
		_style.shadow_size = 8
		_style.shadow_offset = Vector2(0, 6)
		add_theme_stylebox_override("panel", _style)
		modulate = Color(1, 1, 1, 0.0)
		resized.connect(func(): pivot_offset = size / 2.0)
		mouse_entered.connect(func(): chosen.emit(index))
		gui_input.connect(_on_gui_input)

	func _on_gui_input(e: InputEvent) -> void:
		if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
			chosen.emit(index)

	func _set_glow(g: float) -> void:
		glow = g
		_style.bg_color = Color("fbfdff").lerp(col.lightened(0.7), g)
		_style.set_border_width_all(2 + int(round(g)))
		_style.shadow_size = int(8.0 + 10.0 * g)
		_style.shadow_offset = Vector2(0, 6.0 + 6.0 * g)
		_style.shadow_color = Color(0.17, 0.24, 0.33, 0.14 + 0.08 * g)

	func set_selected(on: bool) -> void:
		if _tw and _tw.is_valid():
			_tw.kill()
		_tw = create_tween().set_parallel(true).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		_tw.tween_property(self, "scale", Vector2.ONE * (1.035 if on else 1.0), 0.25)
		_tw.tween_method(_set_glow, glow, 1.0 if on else 0.0, 0.25)
		z_index = 2 if on else 0
		emblem.active = on

	func intro(delay: float) -> void:
		var t := create_tween()
		t.tween_interval(delay)
		t.tween_property(self, "alpha", 1.0, 0.5).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		t.tween_callback(func():
			for b in bars:
				b.grow())


# --- Montaje de la pantalla --------------------------------------------------------------

func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_bold = FontVariation.new()
	_bold.base_font = ThemeDB.fallback_font
	_bold.variation_embolden = 0.4

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
	add_child(Skyline.new())

	var scroll := ScrollContainer.new()
	scroll.set_anchors_preset(Control.PRESET_FULL_RECT)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(scroll)
	var margin := MarginContainer.new()
	margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	margin.size_flags_vertical = Control.SIZE_EXPAND_FILL
	for side in ["left", "right"]:
		margin.add_theme_constant_override("margin_" + side, 70)
	margin.add_theme_constant_override("margin_top", 44)
	margin.add_theme_constant_override("margin_bottom", 36)
	scroll.add_child(margin)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 12)
	column.size_flags_vertical = Control.SIZE_EXPAND_FILL
	margin.add_child(column)

	var title := _label("Gestión Restaurante", 76, INK, true)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(title)
	var sub := _label("¿En qué barrio abres tu restaurante?", 30, SOFT_INK)
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(sub)
	for n in [title, sub]:
		n.modulate.a = 0.0
		create_tween().tween_property(n, "modulate:a", 1.0, 0.7).set_trans(Tween.TRANS_CUBIC)

	column.add_child(_spacer())
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
		card.intro(0.2 + 0.12 * i)
		i += 1
	column.add_child(_spacer())

	var hint := _label("Flechas para moverte  ·  Intro para confirmar", 20, FAINT_INK)
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(hint)

	resized.connect(_on_resized)
	_on_resized()
	_select(0)


func _on_resized() -> void:
	_grid.columns = 4 if size.x >= 1500.0 else 2


func _spacer() -> Control:
	var s := Control.new()
	s.custom_minimum_size = Vector2(0, 8)
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
		Game.choose_barrio(_ids[_selected])
		get_viewport().set_input_as_handled()


# --- Tarjeta de barrio ------------------------------------------------------------------

func _card(b: Dictionary, index: int, max_flow: float) -> Control:
	var col: Color = DISTRICT_COLORS.get(b["id"], DEFAULT_COLOR)
	var card := Card.new(index, col)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 12)
	card.add_child(box)

	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 16)
	box.add_child(head)
	var emblem := Emblem.new(b["id"], col)
	card.emblem = emblem
	head.add_child(emblem)
	var name_label := _label(b["nombre"], 32, INK, true)
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	head.add_child(name_label)

	box.add_child(_label(b["descripcion"], 19, SOFT_INK))

	var price := float(b["nivel_precios"])
	var rent := float(b["alquiler_dia"])
	var flow := _flow(b)
	card.bars.append(_stat(box, "Precios", clampf(price / 1.5, 0.0, 1.0), col, _price_word(price).capitalize()))
	card.bars.append(_stat(box, "Locales", clampf(rent / 160.0, 0.0, 1.0), col, _land_word(rent)))
	card.bars.append(_stat(box, "Afluencia", clampf(flow / max_flow, 0.0, 1.0), col, _flow_word(flow / max_flow)))

	var facts := HFlowContainer.new()
	box.add_child(facts)
	facts.add_child(_chip(_rush_word(b["grupos_por_hora"]), col))

	var population: Dictionary = b["poblacion"]
	var ids := population.keys()
	ids.sort_custom(func(x, y): return population[x] > population[y])
	var parts: PackedStringArray = []
	for profile_id in ids.slice(0, 3):
		var profile: Dictionary = GameData.perfiles[profile_id]
		parts.append("%s %d%%" % [profile["nombre"], roundi(population[profile_id] * 100.0)])
	box.add_child(_label("Gente: " + "  ·  ".join(parts), 18, FAINT_INK))
	box.add_child(_label(b["consejo"], 18, SOFT_INK))

	var push := Control.new()
	push.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.add_child(push)

	var button := Button.new()
	button.text = "Elegir barrio"
	button.focus_mode = Control.FOCUS_NONE
	button.custom_minimum_size = Vector2(0, 62)
	button.add_theme_font_size_override("font_size", 26)
	button.add_theme_font_override("font", _bold)
	for state in ["normal", "hover", "pressed"]:
		var s := StyleBoxFlat.new()
		s.set_corner_radius_all(16)
		s.set_border_width_all(2)
		s.border_color = INK
		match state:
			"hover":
				s.bg_color = col
			"pressed":
				s.bg_color = col.darkened(0.1)
			_:
				s.bg_color = col.lightened(0.45)
		button.add_theme_stylebox_override(state, s)
	for key in ["font_color", "font_hover_color", "font_pressed_color"]:
		button.add_theme_color_override(key, INK)
	button.pressed.connect(Game.choose_barrio.bind(b["id"]))
	box.add_child(button)
	return card


## Fila de atributo: nombre, barra por segmentos y valor.
func _stat(parent: Control, caption: String, value: float, col: Color, value_text: String) -> SegBar:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	parent.add_child(row)
	var name_label := _label(caption, 18, FAINT_INK)
	name_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	name_label.custom_minimum_size = Vector2(96, 0)
	row.add_child(name_label)
	var bar := SegBar.new(value, col)
	row.add_child(bar)
	var val := _label(value_text, 18, INK, true)
	val.autowrap_mode = TextServer.AUTOWRAP_OFF
	val.custom_minimum_size = Vector2(92, 0)
	val.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	row.add_child(val)
	return bar


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
	style.bg_color = col.lightened(0.5)
	style.set_corner_radius_all(14)
	style.content_margin_left = 14
	style.content_margin_right = 14
	style.content_margin_top = 4
	style.content_margin_bottom = 4
	panel.add_theme_stylebox_override("panel", style)
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", 18)
	l.add_theme_color_override("font_color", INK)
	panel.add_child(l)
	return panel


## Lo caro que es comprar un local en el barrio.
static func _land_word(rent: float) -> String:
	if rent < 80.0:
		return "Baratos"
	if rent < 120.0:
		return "Medios"
	if rent < 140.0:
		return "Caros"
	return "Muy caros"


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
