class_name BuildPanel
extends Control
## Interfaz del modo construcción: abajo, el catálogo por pestañas (tarjetas con una
## miniatura 3D, el precio y lo que aporta cada mueble); encima, una barra con lo que se
## puede hacer ahora (girar, comprar, mover, vender...) y el motivo si algo no se puede.

signal done

const TABS := [["mesas", "Mesas"], ["decoracion", "Decoración"], ["luces", "Luces"]]
const PAPER := Color("fffaf2")
const INK := Color("37474f")
const GREEN := Color("66bb6a")
const GOLD := Color("ffca28")
const RED := Color("e57373")
const BLUE := Color("5c6bc0")

var build: BuildMode
var _tab := "mesas"
var _tab_buttons := {}
var _cards: HBoxContainer
var _card_buttons := {}
var _bottom: PanelContainer
var _actions: PanelContainer
var _message: Label
var _buttons: HBoxContainer
var _free_toggle: CheckButton


func setup(build_mode: BuildMode) -> void:
	build = build_mode
	build.changed.connect(_refresh)
	_build_ui()
	_show_tab(_tab)
	_refresh()


func _build_ui() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE

	_bottom = PanelContainer.new()
	_bottom.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	_bottom.offset_top = -290
	_bottom.add_theme_stylebox_override("panel", _rounded(PAPER, 0, 18))
	add_child(_bottom)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 12)
	_bottom.add_child(column)

	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 12)
	column.add_child(header)
	for t in TABS:
		var b := Button.new()
		b.text = t[1]
		b.custom_minimum_size = Vector2(220, 66)
		b.add_theme_font_size_override("font_size", 28)
		b.pressed.connect(_show_tab.bind(t[0]))
		header.add_child(b)
		_tab_buttons[t[0]] = b
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(spacer)
	_free_toggle = CheckButton.new()
	_free_toggle.text = "Modo libre (gratis)"
	_free_toggle.add_theme_font_size_override("font_size", 26)
	_free_toggle.add_theme_color_override("font_color", INK)
	_free_toggle.add_theme_color_override("font_pressed_color", INK)
	_free_toggle.add_theme_color_override("font_hover_color", INK)
	_free_toggle.add_theme_color_override("font_hover_pressed_color", INK)
	_free_toggle.toggled.connect(_on_free_toggled)
	header.add_child(_free_toggle)
	var finish := Button.new()
	finish.text = "Listo"
	finish.custom_minimum_size = Vector2(190, 66)
	finish.add_theme_font_size_override("font_size", 30)
	_style(finish, GREEN, Color.WHITE)
	finish.pressed.connect(func(): done.emit())
	header.add_child(finish)

	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(0, 196)
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	column.add_child(scroll)
	_cards = HBoxContainer.new()
	_cards.add_theme_constant_override("separation", 14)
	scroll.add_child(_cards)

	_actions = PanelContainer.new()
	_actions.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	_actions.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_actions.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_actions.offset_bottom = -346
	_actions.add_theme_stylebox_override("panel", _rounded(Color(PAPER, 0.97), 26, 18, true))
	add_child(_actions)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	_actions.add_child(row)
	_message = Label.new()
	_message.add_theme_font_size_override("font_size", 28)
	_message.add_theme_color_override("font_color", INK)
	_message.custom_minimum_size = Vector2(0, 66)
	_message.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(_message)
	_buttons = HBoxContainer.new()
	_buttons.add_theme_constant_override("separation", 10)
	row.add_child(_buttons)


func _on_free_toggled(on: bool) -> void:
	build.sim.free_build = on
	build.message = "Modo libre: los muebles no cuestan nada." if on else ""
	build.refresh()


## ¿Tapa la interfaz este punto de la pantalla?
func covers(screen_pos: Vector2) -> bool:
	return visible and (_bottom.get_global_rect().has_point(screen_pos) or _actions.get_global_rect().has_point(screen_pos))


func _show_tab(tab: String) -> void:
	_tab = tab
	for t in _tab_buttons:
		_style(_tab_buttons[t], BLUE if t == tab else Color("eceff1"), Color.WHITE if t == tab else INK)
	for child in _cards.get_children():
		_cards.remove_child(child)
		child.queue_free()
	_card_buttons.clear()
	for id in build.sim.layout.catalog:
		var def: Dictionary = build.sim.layout.catalog[id]
		if def.get("categoria", "") == tab:
			var card := _card(def)
			_cards.add_child(card)
			_card_buttons[id] = card
	_refresh()


## Tarjeta del catálogo: miniatura 3D, nombre, precio y lo que aporta.
func _card(def: Dictionary) -> Button:
	var card := Button.new()
	card.custom_minimum_size = Vector2(240, 190)
	card.pressed.connect(func(): build.choose(def["id"]))
	var box := VBoxContainer.new()
	box.set_anchors_preset(Control.PRESET_FULL_RECT)
	box.offset_left = 10
	box.offset_right = -10
	box.offset_top = 6
	box.offset_bottom = -6
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_theme_constant_override("separation", 2)
	card.add_child(box)
	box.add_child(_thumbnail(def))
	var title := Label.new()
	title.text = def["nombre"]
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.clip_text = true
	title.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	title.add_theme_font_size_override("font_size", 22)
	title.add_theme_color_override("font_color", INK)
	box.add_child(title)
	var info := Label.new()
	info.text = "%d € · %s" % [int(def["precio"]), _benefit(def)]
	info.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	info.clip_text = true
	info.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	info.add_theme_font_size_override("font_size", 20)
	info.add_theme_color_override("font_color", Color("78909c"))
	box.add_child(info)
	for child in box.get_children():
		child.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return card


static func _benefit(def: Dictionary) -> String:
	if def.get("tipo", "") == "mesa":
		var text := "%d plazas" % int(def["plazas"])
		if float(def.get("ambiente", 0)) > 0.0:
			text += " · +%d amb." % int(def["ambiente"])
		return text
	return "Ambiente +%d" % int(def.get("ambiente", 0))


## Miniatura con el mueble en 3D, vista como en el juego.
func _thumbnail(def: Dictionary) -> Control:
	var container := SubViewportContainer.new()
	container.custom_minimum_size = Vector2(220, 116)
	container.stretch = true
	container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var viewport := SubViewport.new()
	viewport.own_world_3d = true
	viewport.transparent_bg = true
	viewport.size = Vector2i(220, 116)
	viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
	container.add_child(viewport)
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-55, -30, 0)
	viewport.add_child(light)
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_CLEAR_COLOR
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color(0.9, 0.9, 0.95)
	env.environment.ambient_light_energy = 0.6
	viewport.add_child(env)
	var model := FurnitureModels.build(def)
	viewport.add_child(model)
	var wide: bool = def.get("huella", [[0, 0]]).size() > 1
	var center := Vector3(0.5 if wide else 0.0, 0.45, 0.0)
	var cam := Camera3D.new()
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	cam.size = 2.3 if def.get("tipo", "") == "mesa" or wide else 1.6
	cam.rotation_degrees = Vector3(-35.264, 45, 0)
	cam.position = center + cam.basis.z * 10.0
	viewport.add_child(cam)
	return container


## Pone al día la barra de acciones y la tarjeta elegida según lo que pasa en BuildMode.
func _refresh() -> void:
	if build == null or _buttons == null:
		return
	visible = build.active
	_free_toggle.set_pressed_no_signal(build.sim.free_build)
	for id in _card_buttons:
		var chosen: bool = build.mode == BuildMode.Mode.COLOCANDO and build.uid == -1 and build.tipo == id
		_style(_card_buttons[id], Color("fff3c4") if chosen else Color.WHITE, INK, 20, Color("ffb300") if chosen else Color("e0e0e0"))
	for child in _buttons.get_children():
		_buttons.remove_child(child)
		child.queue_free()
	var text := build.message
	var color := INK
	match build.mode:
		BuildMode.Mode.COLOCANDO:
			var moving := build.uid != -1
			if build.problem != "":
				text = "%s: %s" % [build.display_name(), build.problem]
				color = Color("c62828")
			elif text == "":
				text = "%s: toca el suelo para elegir el sitio." % build.display_name()
			_button("Girar", Color("eceff1"), INK, build.turn)
			var price := 0.0 if build.sim.free_build or moving else build.sim.furniture_price(build.tipo)
			var label := "Dejar aquí" if moving else ("Comprar · %d €" % int(price) if price > 0.0 else "Colocar gratis")
			var confirm := _button(label, GOLD if not moving else GREEN, INK if not moving else Color.WHITE, build.confirm)
			confirm.disabled = build.problem != ""
			_button("Cancelar", Color(0, 0, 0, 0), Color("78909c"), build.cancel)
		BuildMode.Mode.ELEGIDO:
			if text == "":
				text = build.display_name()
			var locked := build.sim.furniture_locked(build.uid)
			if locked != "":
				text += " · " + locked
				color = Color("c62828")
			_button("Mover", BLUE, Color.WHITE, build.start_move)
			_button("Girar", Color("eceff1"), INK, build.turn)
			var value := build.sim.resale_value(build.uid)
			_button("Vender" + ("" if value <= 0.0 else " · +%d €" % int(value)), RED, Color.WHITE, build.sell)
			_button("Cerrar", Color(0, 0, 0, 0), Color("78909c"), build.cancel)
	_message.text = text
	_message.add_theme_color_override("font_color", color)
	_actions.visible = text != "" or _buttons.get_child_count() > 0
	# La barra de acciones se recoloca centrada, justo encima del catálogo.
	_place_actions.call_deferred()


func _place_actions() -> void:
	_actions.reset_size()
	var width := _actions.get_combined_minimum_size().x
	_actions.offset_left = -width / 2.0
	_actions.offset_right = width / 2.0
	_actions.offset_bottom = -_bottom.size.y - 14.0
	_actions.offset_top = _actions.offset_bottom - _actions.get_combined_minimum_size().y


func _button(text: String, bg: Color, fg: Color, action: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(150, 66)
	b.add_theme_font_size_override("font_size", 27)
	_style(b, bg, fg)
	b.pressed.connect(action)
	_buttons.add_child(b)
	return b


func _style(b: Button, bg: Color, fg: Color, radius: int = 22, border: Color = Color(0, 0, 0, 0)) -> void:
	for state in ["normal", "focus", "hover", "pressed", "disabled"]:
		var style := StyleBoxFlat.new()
		style.bg_color = bg
		if state == "hover" and bg.a > 0.0:
			style.bg_color = bg.lightened(0.08)
		elif state == "pressed" and bg.a > 0.0:
			style.bg_color = bg.darkened(0.1)
		elif state == "disabled":
			style.bg_color = Color(bg, bg.a * 0.45)
		style.set_corner_radius_all(radius)
		style.content_margin_left = 18
		style.content_margin_right = 18
		if border.a > 0.0:
			style.border_color = border
			style.set_border_width_all(4)
		b.add_theme_stylebox_override(state, style)
	for name in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		b.add_theme_color_override(name, fg)
	b.add_theme_color_override("font_disabled_color", Color(fg, 0.45))


static func _rounded(color: Color, radius: int, padding: int, shadow: bool = false) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.set_corner_radius_all(radius)
	style.content_margin_left = padding + 8
	style.content_margin_right = padding + 8
	style.content_margin_top = padding
	style.content_margin_bottom = padding
	if shadow:
		style.shadow_color = Color(0, 0, 0, 0.25)
		style.shadow_size = 12
	return style
