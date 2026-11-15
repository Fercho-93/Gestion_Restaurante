class_name LocalSelect
extends Control
## Segundo paso de la partida: con el barrio elegido, se compra el local donde abrir.
## Se parte de un presupuesto (como en los Sims): lo que cuesta el local sale de ahí y
## lo que sobra es el dinero para amueblar, decorar y contratar.

const INK := StartScreen.INK
const SOFT_INK := StartScreen.SOFT_INK
const FAINT_INK := StartScreen.FAINT_INK
const PAPER := StartScreen.PAPER
const ACCENT := Color("8ec1ec")
const GOOD := Color("4f9d6b")
const WARN := Color("c0773b")
const BAD := Color("c0574b")
## Si sobra menos que esto, se avisa de que no llega para equipar el local.
const LOW_MONEY := 12000
const START_SCENE := "res://scenes/start/start_screen.tscn"

var _barrio: Dictionary
var _ids: Array = []
var _cards: Array = []
var _selected := -1
var _grid: GridContainer
var _bold: FontVariation
var _left_label: Label
var _left_value: Label
var _price_value: Label
var _remaining_value: Label
var _note: Label
var _buy: Button


# --- Plano de un local -------------------------------------------------------------------

## Plano del local visto desde arriba, todos a la misma escala para comparar tamaños.
class PlanView extends Control:
	const MAX_W := 19.0  # calle (3) + el local más ancho (16)
	const MAX_H := 14.0
	var zones: Array = []
	var grid := Vector2i.ZERO
	var tint := Color.WHITE

	func _init(local: Dictionary, c: Color) -> void:
		tint = c
		grid = Vector2i(int(local["tamano"][0]), int(local["tamano"][1]))
		zones = local["zonas"]
		custom_minimum_size = Vector2(0, 190)
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		var cell := minf(size.x / MAX_W, size.y / MAX_H)
		var total := Vector2(cell * (grid.x + 3), cell * grid.y)
		var origin := Vector2((size.x - total.x) / 2.0, size.y - total.y)
		var ink := Color("2c3e55")
		# La calle, por donde entra la gente.
		draw_rect(Rect2(origin, Vector2(cell * 3, total.y)), Color("dfe8f1"))
		draw_line(origin + Vector2(cell * 1.5, 0), origin + Vector2(cell * 1.5, total.y), Color("c3d1df"), 2.0)
		var base := origin + Vector2(cell * 3, 0)
		for z in zones:
			var r: Array = z["rect"]
			var rect := Rect2(base + Vector2(float(r[0]), float(r[1])) * cell, Vector2(float(r[2]), float(r[3])) * cell)
			var fill := Color(z["color"])
			if z["nombre"] == "Comedor":
				fill = tint.lightened(0.55)
			draw_rect(rect, fill)
			draw_rect(rect, Color(ink, 0.55), false, 1.5)
		draw_rect(Rect2(base, Vector2(grid.x, grid.y) * cell), ink, false, 2.5)
		# La puerta, en la pared que da a la calle.
		var door_y := base.y + cell * (grid.y - 2.5)
		draw_rect(Rect2(base.x - 3.0, door_y, 6.0, cell * 1.4), Color("fbfdff"))
		var font := ThemeDB.fallback_font
		for z in zones:
			if z["nombre"] == "Comedor":
				var r: Array = z["rect"]
				var center := base + Vector2(float(r[0]) + float(r[2]) / 2.0, float(r[1]) + float(r[3]) / 2.0) * cell
				draw_string(font, center + Vector2(-22, 4), "Comedor", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(ink, 0.75))
			elif z["nombre"] == "Cocina":
				var r2: Array = z["rect"]
				var c2 := base + Vector2(float(r2[0]) + float(r2[2]) / 2.0, float(r2[1]) + float(r2[3]) / 2.0) * cell
				draw_string(font, c2 + Vector2(-16, 4), "Cocina", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(ink, 0.75))


## Tarjeta de local: se levanta al seleccionarla.
class LocalCard extends PanelContainer:
	signal chosen(index: int)
	var index := 0
	var affordable := true
	var glow := 0.0
	var _style: StyleBoxFlat
	var _tw: Tween
	var _alpha := 0.0:
		set(v):
			_alpha = v
			_refresh_modulate()

	func _init(i: int, can_buy: bool) -> void:
		index = i
		affordable = can_buy
		size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_style = StyleBoxFlat.new()
		_style.bg_color = Color("fbfdff")
		_style.set_corner_radius_all(22)
		_style.set_border_width_all(2)
		_style.border_color = Color("2c3e55")
		for side in ["left", "right"]:
			_style.set("content_margin_" + side, 20)
		_style.content_margin_top = 18
		_style.content_margin_bottom = 18
		_style.shadow_color = Color(0.17, 0.24, 0.33, 0.14)
		_style.shadow_size = 8
		_style.shadow_offset = Vector2(0, 6)
		add_theme_stylebox_override("panel", _style)
		modulate = Color(1, 1, 1, 0.0)
		resized.connect(func(): pivot_offset = size / 2.0)
		mouse_entered.connect(func(): chosen.emit(index))
		gui_input.connect(_on_gui_input)

	func _refresh_modulate() -> void:
		var shade := 1.0 if affordable else 0.86
		modulate = Color(shade, shade, shade, _alpha)

	func _on_gui_input(e: InputEvent) -> void:
		if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
			chosen.emit(index)

	func _set_glow(g: float) -> void:
		glow = g
		_style.bg_color = Color("fbfdff").lerp(Color("e6f1fb"), g)
		_style.set_border_width_all(2 + int(round(g)))
		_style.shadow_size = int(8.0 + 10.0 * g)
		_style.shadow_offset = Vector2(0, 6.0 + 6.0 * g)

	func set_selected(on: bool) -> void:
		if _tw and _tw.is_valid():
			_tw.kill()
		_tw = create_tween().set_parallel(true).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		_tw.tween_property(self, "scale", Vector2.ONE * (1.035 if on else 1.0), 0.25)
		_tw.tween_method(_set_glow, glow, 1.0 if on else 0.0, 0.25)
		z_index = 2 if on else 0

	func intro(delay: float) -> void:
		var t := create_tween()
		t.tween_interval(delay)
		t.tween_property(self, "_alpha", 1.0, 0.45).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)


# --- Montaje -----------------------------------------------------------------------------

func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_barrio = GameData.barrios.get(Game.pending_barrio, {})
	if _barrio.is_empty():
		# Sin barrio elegido (por ejemplo, al abrir esta escena directamente): vuelve a la portada.
		get_tree().change_scene_to_file.call_deferred(START_SCENE)
		return
	_bold = FontVariation.new()
	_bold.base_font = ThemeDB.fallback_font
	_bold.variation_embolden = 0.4

	var base := ColorRect.new()
	base.color = Color("e3eef9")
	base.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(base)
	var bg := ColorRect.new()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	var bg_mat := ShaderMaterial.new()
	var bg_shader := Shader.new()
	bg_shader.code = StartScreen.BG_SHADER
	bg_mat.shader = bg_shader
	bg.material = bg_mat
	add_child(bg)
	add_child(StartScreen.Skyline.new())

	var scroll := ScrollContainer.new()
	scroll.set_anchors_preset(Control.PRESET_FULL_RECT)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(scroll)
	var margin := MarginContainer.new()
	margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	margin.size_flags_vertical = Control.SIZE_EXPAND_FILL
	for side in ["left", "right"]:
		margin.add_theme_constant_override("margin_" + side, 56)
	margin.add_theme_constant_override("margin_top", 28)
	margin.add_theme_constant_override("margin_bottom", 28)
	scroll.add_child(margin)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 12)
	column.size_flags_vertical = Control.SIZE_EXPAND_FILL
	margin.add_child(column)

	column.add_child(_header())

	var title := _label("Elige tu local", 60, INK, true)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(title)
	var sub := _label("%s · Con lo que te sobre tendrás que amueblarlo, decorarlo y contratar." % _barrio["nombre"], 26, SOFT_INK)
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(sub)
	for n in [title, sub]:
		n.modulate.a = 0.0
		create_tween().tween_property(n, "modulate:a", 1.0, 0.6).set_trans(Tween.TRANS_CUBIC)

	column.add_child(_spacer())
	_grid = GridContainer.new()
	_grid.columns = 5
	_grid.add_theme_constant_override("h_separation", 22)
	_grid.add_theme_constant_override("v_separation", 22)
	_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	column.add_child(_grid)
	var first_affordable := -1
	var i := 0
	for local_id in GameData.locales:
		var card := _card(local_id, i)
		_grid.add_child(card)
		_cards.append(card)
		_ids.append(local_id)
		card.chosen.connect(_select)
		card.intro(0.15 + 0.1 * i)
		if first_affordable < 0 and _price(local_id) <= GameData.NEW_GAME_MONEY:
			first_affordable = i
		i += 1
	column.add_child(_spacer())

	var soon := _label("Próximamente: locales con terraza, con doble planta y solares vacíos para construir desde cero.", 19, FAINT_INK)
	soon.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(soon)
	column.add_child(_budget_bar())

	resized.connect(_on_resized)
	_on_resized()
	_select(maxi(first_affordable, 0))


func _on_resized() -> void:
	_grid.columns = 5 if size.x >= 1700.0 else 3


func _header() -> Control:
	var row := HBoxContainer.new()
	var back := Button.new()
	back.text = "‹  Cambiar de barrio"
	back.focus_mode = Control.FOCUS_NONE
	back.add_theme_font_size_override("font_size", 22)
	back.add_theme_color_override("font_color", INK)
	back.add_theme_color_override("font_hover_color", INK)
	for state in ["normal", "hover", "pressed"]:
		var s := StyleBoxFlat.new()
		s.set_corner_radius_all(14)
		s.set_border_width_all(2)
		s.border_color = INK
		s.content_margin_left = 18
		s.content_margin_right = 18
		s.content_margin_top = 8
		s.content_margin_bottom = 8
		s.bg_color = ACCENT.lightened(0.5) if state == "normal" else ACCENT
		back.add_theme_stylebox_override(state, s)
	back.pressed.connect(_back)
	row.add_child(back)
	return row


## Barra inferior: presupuesto, precio del local y lo que queda, con el botón de comprar.
func _budget_bar() -> Control:
	var panel := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = PAPER
	style.set_corner_radius_all(22)
	style.set_border_width_all(2)
	style.border_color = INK
	style.content_margin_left = 28
	style.content_margin_right = 20
	style.content_margin_top = 14
	style.content_margin_bottom = 14
	style.shadow_color = Color(0.17, 0.24, 0.33, 0.14)
	style.shadow_size = 8
	style.shadow_offset = Vector2(0, 6)
	panel.add_theme_stylebox_override("panel", style)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 30)
	panel.add_child(row)

	var money := _money_block("Presupuesto", "%s €" % HUD.format_money(GameData.NEW_GAME_MONEY), INK)
	row.add_child(money[0])
	row.add_child(_label("−", 40, FAINT_INK, true))
	var price := _money_block("Local", "—", INK)
	_price_value = price[1]
	row.add_child(price[0])
	row.add_child(_label("=", 40, FAINT_INK, true))
	var left := _money_block("Te quedan", "—", GOOD)
	_remaining_value = left[1]
	row.add_child(left[0])

	_note = _label("", 20, SOFT_INK)
	_note.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_note.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(_note)

	_buy = Button.new()
	_buy.text = "Comprar y abrir  »"
	_buy.focus_mode = Control.FOCUS_NONE
	_buy.custom_minimum_size = Vector2(320, 70)
	_buy.add_theme_font_size_override("font_size", 28)
	_buy.add_theme_font_override("font", _bold)
	for state in ["normal", "hover", "pressed", "disabled"]:
		var s := StyleBoxFlat.new()
		s.set_corner_radius_all(16)
		s.set_border_width_all(2)
		s.border_color = INK if state != "disabled" else FAINT_INK
		match state:
			"hover":
				s.bg_color = ACCENT
			"pressed":
				s.bg_color = ACCENT.darkened(0.1)
			"disabled":
				s.bg_color = Color("e6ecf2")
			_:
				s.bg_color = ACCENT.lightened(0.3)
		_buy.add_theme_stylebox_override(state, s)
	for key in ["font_color", "font_hover_color", "font_pressed_color"]:
		_buy.add_theme_color_override(key, INK)
	_buy.add_theme_color_override("font_disabled_color", FAINT_INK)
	_buy.pressed.connect(_purchase)
	row.add_child(_buy)
	return panel


## Devuelve [contenedor, etiqueta del valor] para poder actualizarlo después.
func _money_block(caption: String, value: String, color: Color) -> Array:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 0)
	box.add_child(_label(caption, 18, FAINT_INK))
	var v := _label(value, 34, color, true)
	v.autowrap_mode = TextServer.AUTOWRAP_OFF
	box.add_child(v)
	return [box, v]


func _card(local_id: String, index: int) -> Control:
	var local: Dictionary = GameData.locales[local_id]
	var price := _price(local_id)
	var can_buy := price <= GameData.NEW_GAME_MONEY
	var card := LocalCard.new(index, can_buy)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	card.add_child(box)
	box.add_child(_label(local["nombre"], 28, INK, true))
	var plan := LocalFactory.build(int(local["comedor"][0]), int(local["comedor"][1]))
	box.add_child(PlanView.new(plan, StartScreen.DEFAULT_COLOR))

	var layout := RestaurantLayout.new(plan, GameData.muebles)
	var tables := int(layout.buildable.size() / 5.0)
	box.add_child(_label("%d × %d casillas · caben unas %d mesas" % [plan["tamano"][0], plan["tamano"][1], tables], 18, FAINT_INK))
	box.add_child(_label(local["descripcion"], 19, SOFT_INK))
	var push := Control.new()
	push.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.add_child(push)
	var price_label := _label("%s €" % HUD.format_money(price), 34, INK if can_buy else BAD, true)
	price_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	box.add_child(price_label)
	box.add_child(_label("Tasas: %d €/día" % roundi(price / GameData.TAX_DIVISOR) if can_buy else "Fuera de tu presupuesto", 18, FAINT_INK if can_buy else BAD))
	return card


func _price(local_id: String) -> int:
	return GameData.local_price(local_id, Game.pending_barrio)


# --- Selección y compra ------------------------------------------------------------------

func _select(i: int) -> void:
	if i == _selected or i < 0 or i >= _cards.size():
		return
	if _selected >= 0:
		_cards[_selected].set_selected(false)
	_selected = i
	_cards[i].set_selected(true)
	var price := _price(_ids[i])
	var remaining := GameData.NEW_GAME_MONEY - price
	_price_value.text = "%s €" % HUD.format_money(price)
	_remaining_value.text = "%s €" % HUD.format_money(remaining)
	var can_buy := remaining >= 0
	_buy.disabled = not can_buy
	var color := GOOD
	if not can_buy:
		color = BAD
		_note.text = "Este local no te llega. Elige uno más barato."
	elif remaining < LOW_MONEY:
		color = WARN
		_note.text = "Te quedará muy poco para muebles, decoración y personal."
	else:
		_note.text = "Con lo que sobre amueblarás el local y contratarás personal."
	_remaining_value.add_theme_color_override("font_color", color)


func _purchase() -> void:
	if _selected < 0 or _buy.disabled:
		return
	Game.start(Game.pending_barrio, _ids[_selected])


func _back() -> void:
	get_tree().change_scene_to_file(START_SCENE)


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
	elif event.is_action_pressed("ui_accept"):
		_purchase()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("ui_cancel"):
		_back()
		get_viewport().set_input_as_handled()


# --- Utilidades --------------------------------------------------------------------------

func _spacer() -> Control:
	var s := Control.new()
	s.custom_minimum_size = Vector2(0, 8)
	s.size_flags_vertical = Control.SIZE_EXPAND_FILL
	return s


func _label(text: String, size: int, color: Color, bold := false) -> Label:
	var l := Label.new()
	l.text = text
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	if bold:
		l.add_theme_font_override("font", _bold)
	return l
