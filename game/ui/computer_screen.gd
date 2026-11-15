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
var _staff_message := ""


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
	elif id == "personal":
		_staff_module()
	else:
		_line(MODULES[id][1], 28, Color("cfd8dc"))
		_line("Próximamente.", 28, Color("ffd54f"))


## Personal: elegir qué hace cada uno según sus características, contratar y despedir.
func _staff_module() -> void:
	var sim := Game.sim
	_line("Elige a qué se dedica cada uno según lo que se le da bien. La aptitud (0-100) sale de sus características.", 24, Color("cfd8dc"))
	if _staff_message != "":
		_line(_staff_message, 26, Color("ffd54f"))
	var total := sim.layout.cook_stations.size() + sim.layout.waiter_homes.size()
	_line("Tu equipo · %d de %d puestos" % [sim.staff.size(), total], 30, Color("b0bec5"))
	for s in sim.staff:
		_content.add_child(_staff_row(s))
	_line("Buscan trabajo hoy", 30, Color("b0bec5"))
	if sim.candidates.is_empty():
		_line("Hoy no hay nadie. Mañana habrá candidatos nuevos.", 24, Color("90a4ae"))
	for i in sim.candidates.size():
		_content.add_child(_candidate_row(i))


func _panel_row() -> HBoxContainer:
	var panel := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color("2a3140")
	style.set_corner_radius_all(12)
	style.content_margin_left = 16
	style.content_margin_right = 16
	style.content_margin_top = 10
	style.content_margin_bottom = 10
	panel.add_theme_stylebox_override("panel", style)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 16)
	panel.add_child(row)
	_content.add_child(panel)
	_content.remove_child(panel)
	row.set_meta("panel", panel)
	return row


func _staff_row(s: StaffMember) -> Control:
	var sim := Game.sim
	var row := _panel_row()
	var info := VBoxContainer.new()
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(info)
	info.add_child(_label("%s · %s" % [s.nombre, s.rol_name()], 30, Color.WHITE))
	info.add_child(_label("Velocidad %d · Trato %d · Habilidad %d · Ánimo %d (%s) · Sueldo %d €/día" % [
			s.velocidad, s.trato, s.habilidad, roundi(s.moral), s.moral_word(), int(s.salario_dia)], 22, Color("b0bec5")))
	var picker := OptionButton.new()
	picker.custom_minimum_size = Vector2(420, 64)
	picker.add_theme_font_size_override("font_size", 24)
	var selected := 0
	var i := 0
	for rol in StaffMember.ROLES:
		picker.add_item("%s · aptitud %d" % [StaffMember.ROLES[rol][0], roundi(s.aptitude(rol))], i)
		picker.set_item_metadata(i, rol)
		if rol == s.rol:
			selected = i
		i += 1
	picker.select(selected)
	picker.item_selected.connect(func(index: int):
		var problem := sim.set_role(s, picker.get_item_metadata(index))
		_staff_message = problem if problem != "" else "%s ahora está en %s." % [s.nombre, s.rol_name().to_lower()]
		_show("personal"))
	row.add_child(picker)
	var fire := Button.new()
	fire.text = "Despedir"
	fire.custom_minimum_size = Vector2(190, 64)
	fire.add_theme_font_size_override("font_size", 24)
	fire.pressed.connect(func():
		if fire.text == "Despedir":
			fire.text = "¿Seguro?"
			return
		var problem := sim.fire(s)
		_staff_message = problem if problem != "" else "Has despedido a %s." % s.nombre
		_show("personal"))
	row.add_child(fire)
	return row.get_meta("panel")


func _candidate_row(index: int) -> Control:
	var sim := Game.sim
	var c: Dictionary = sim.candidates[index]
	var row := _panel_row()
	var info := VBoxContainer.new()
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(info)
	info.add_child(_label(c["nombre"], 28, Color.WHITE))
	var best := "sala"
	var probe := StaffMember.new({ "nombre": c["nombre"], "puesto": StaffMember.ROLE_WAITER, "velocidad": c["velocidad"], "trato": c["trato"],
			"habilidad": c["habilidad"], "salario_dia": c["salario_dia"] }, 0, Vector2i.ZERO)
	for rol in StaffMember.ROLES:
		if probe.aptitude(rol) > probe.aptitude(best):
			best = rol
	info.add_child(_label("Velocidad %d · Trato %d · Habilidad %d · Sueldo %d €/día · Le iría bien en: %s" % [
			c["velocidad"], c["trato"], c["habilidad"], int(c["salario_dia"]), StaffMember.ROLES[best][0].to_lower()], 22, Color("b0bec5")))
	var hire := Button.new()
	hire.text = "Contratar"
	hire.custom_minimum_size = Vector2(190, 64)
	hire.add_theme_font_size_override("font_size", 24)
	hire.disabled = sim.hire_problem(index) != ""
	hire.tooltip_text = sim.hire_problem(index)
	hire.pressed.connect(func():
		var problem := sim.hire(index)
		_staff_message = problem if problem != "" else "%s se incorpora al equipo." % c["nombre"]
		_show("personal"))
	row.add_child(hire)
	return row.get_meta("panel")


func _label(text: String, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	return label


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
		var housing := "%s en propiedad · tasas %d €/día" % [sim.property_local["nombre"], int(sim.fixed_costs["tasas"])] \
				if not sim.property_local.is_empty() else "alquiler %d €/día" % int(sim.fixed_costs["alquiler"])
		_line("%s · %s" % [sim.barrio["nombre"], housing], 28, Color("b0bec5"))
		var opinion_text := "—" if known == 0 else "%d%%" % roundi(opinion / known * 100.0)
		_line("   Vecinos que ya os conocen: %d de %d · Habituales: %d · Les gusta: %s" % [
				known, sim.population.neighbors.size(), regulars, opinion_text], 28)
	_line("Hoy, de momento:", 28, Color("b0bec5"))
	_line("   Ingresos: %.2f €" % f.total(f.income), 28, Color("81c784"))
	_line("   Gastos: %.2f €" % f.total(f.expenses), 28, Color("e57373"))
	_line("   Clientes atendidos: %d · Grupos perdidos: %d" % [sim.day_stats["clientes_servidos"], sim.day_stats["grupos_perdidos"]], 28)
	var by_role := []
	for rol in StaffMember.ROLES:
		var n := sim.staff.filter(func(s: StaffMember): return s.rol == rol).size()
		if n > 0:
			by_role.append("%d %s" % [n, StaffMember.ROLES[rol][0].to_lower()])
	_line("Personal: %s" % ", ".join(by_role), 28)
	_line("Platos en carta: %d" % sim.menu.size(), 28)


func _line(text: String, font_size: int = 28, color: Color = Color.WHITE) -> void:
	var label := Label.new()
	label.text = text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	_content.add_child(label)
