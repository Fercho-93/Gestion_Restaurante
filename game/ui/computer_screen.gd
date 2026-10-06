class_name ComputerScreen
extends PanelContainer
## Ordenador del despacho: se abre cuando el gestor se sienta a usarlo y reúne los
## módulos de gestión. El tiempo sigue corriendo mientras está abierto.

signal closed

## Módulos: id -> [título, descripción mientras no esté hecho]
const MODULES := {
	"resumen": ["Resumen", ""],
	"carta": ["Carta y precios", "Activar y quitar platos, cambiar precios y ver el coste y el margen de cada plato."],
	"personal": ["Personal", "Ver a tus empleados, contratar entre candidatos, despedir y ajustar sueldos."],
	"pedidos": ["Pedidos y almacén", "Ver el stock y hacer pedidos a los proveedores."],
	"finanzas": ["Finanzas", "Cuentas de resultados, préstamos e historial del restaurante."],
}

var _tabs := {}
var _content: VBoxContainer
var _current := "resumen"


func _ready() -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = Color("1f2430")
	style.set_corner_radius_all(18)
	style.border_color = Color("3b4a63")
	style.set_border_width_all(6)
	style.shadow_size = 24
	style.shadow_color = Color(0, 0, 0, 0.5)
	add_theme_stylebox_override("panel", style)
	var margin := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 28)
	add_child(margin)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 20)
	margin.add_child(column)

	var header := HBoxContainer.new()
	column.add_child(header)
	var title := Label.new()
	title.text = "Ordenador del despacho"
	title.add_theme_font_size_override("font_size", 40)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title)
	var leave := Button.new()
	leave.text = "Levantarse"
	leave.custom_minimum_size = Vector2(260, 80)
	leave.add_theme_font_size_override("font_size", 32)
	leave.pressed.connect(close)
	header.add_child(leave)

	var body := HBoxContainer.new()
	body.add_theme_constant_override("separation", 28)
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(body)
	var menu := VBoxContainer.new()
	menu.add_theme_constant_override("separation", 12)
	body.add_child(menu)
	var group := ButtonGroup.new()
	for id in MODULES:
		var b := Button.new()
		b.text = MODULES[id][0]
		b.toggle_mode = true
		b.button_group = group
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.custom_minimum_size = Vector2(380, 88)
		b.add_theme_font_size_override("font_size", 32)
		b.pressed.connect(_show.bind(id))
		menu.add_child(b)
		_tabs[id] = b
	var scroll := ScrollContainer.new()
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	body.add_child(scroll)
	_content = VBoxContainer.new()
	_content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_content.add_theme_constant_override("separation", 10)
	scroll.add_child(_content)
	hide()


func open() -> void:
	show()
	_show(_current)


func close() -> void:
	if visible:
		hide()
		closed.emit()


func _process(_delta: float) -> void:
	# El resumen se actualiza en directo mientras el tiempo corre.
	if visible and _current == "resumen" and Engine.get_process_frames() % 15 == 0:
		_show("resumen")


func _show(id: String) -> void:
	_current = id
	_tabs[id].button_pressed = true
	for child in _content.get_children():
		child.queue_free()
	_line(MODULES[id][0], 36)
	if id == "resumen":
		_summary()
	else:
		_line(MODULES[id][1], 28, Color("cfd8dc"))
		_line("Próximamente.", 28, Color("ffd54f"))


func _summary() -> void:
	var sim := Game.sim
	var f := sim.finances
	_line("Caja: %s €" % HUD.format_money(f.money), 32)
	_line("Reputación: %.1f/5" % sim.average_stars(), 28)
	if sim.population != null:
		var known := 0
		var regulars := 0
		var opinion := 0.0
		for n in sim.population.neighbors:
			if n.visits > 0:
				known += 1
				opinion += n.opinion
			if n.is_regular():
				regulars += 1
		_line("%s · alquiler %d €/día" % [sim.barrio["nombre"], int(sim.fixed_costs["alquiler"])], 28, Color("b0bec5"))
		var opinion_text := "—" if known == 0 else "%d%%" % roundi(opinion / known * 100.0)
		_line("   Vecinos que ya os conocen: %d de %d · Habituales: %d · Les gusta: %s" % [
				known, sim.population.neighbors.size(), regulars, opinion_text], 28)
	_line("Hoy, de momento:", 28, Color("b0bec5"))
	_line("   Ingresos: %.2f €" % f.total(f.income), 28, Color("81c784"))
	_line("   Gastos: %.2f €" % f.total(f.expenses), 28, Color("e57373"))
	_line("   Clientes atendidos: %d · Grupos perdidos: %d" % [sim.day_stats["clientes_servidos"], sim.day_stats["grupos_perdidos"]], 28)
	_line("Personal: %d camareros, %d cocineros" % [sim.waiters().size(), sim.cooks().size()], 28)
	_line("Platos en carta: %d" % sim.menu.size(), 28)


func _line(text: String, font_size: int = 28, color: Color = Color.WHITE) -> void:
	var label := Label.new()
	label.text = text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	_content.add_child(label)
