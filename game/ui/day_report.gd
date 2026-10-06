class_name DayReport
extends PanelContainer
## Informe de cierre del día: caja, clientes, satisfacción y platos vendidos.

signal closed

const CATEGORY_NAMES := {
	"ventas": "Ventas",
	"materia_prima": "Materia prima",
	"personal": "Personal",
	"alquiler": "Alquiler",
	"suministros": "Suministros",
	"invitaciones": "Invitaciones de la casa",
}

var _body: VBoxContainer


func _ready() -> void:
	custom_minimum_size = Vector2(760, 0)
	var style := StyleBoxFlat.new()
	style.bg_color = Color("26262e")
	style.set_corner_radius_all(16)
	style.shadow_size = 24
	style.shadow_color = Color(0, 0, 0, 0.5)
	add_theme_stylebox_override("panel", style)
	var margin := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 32)
	add_child(margin)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 16)
	margin.add_child(column)
	_body = VBoxContainer.new()
	_body.add_theme_constant_override("separation", 6)
	column.add_child(_body)
	var button := Button.new()
	button.text = "Continuar"
	button.custom_minimum_size = Vector2(0, 80)
	button.add_theme_font_size_override("font_size", 32)
	button.pressed.connect(func(): hide(); closed.emit())
	column.add_child(button)
	hide()


func show_report(r: Dictionary) -> void:
	for child in _body.get_children():
		child.queue_free()
	_line("Cierre del día %d" % r["dia"], 40)
	_line("Clientes atendidos: %d (en %d grupos)" % [r["clientes_servidos"], r["grupos_servidos"]])
	var lost: int = r["grupos_perdidos"]
	if lost > 0:
		var reasons: Array[String] = []
		for reason in r["motivos_perdida"]:
			reasons.append("%s: %d" % [reason, r["motivos_perdida"][reason]])
		_line("Grupos perdidos: %d  (%s)" % [lost, ", ".join(reasons)], 24, Color("e57373"))
	_line("Satisfacción media: %d/100 · Reputación: %.1f/5" % [roundi(r["satisfaccion_media"]), r["reputacion"]])
	if r["platos_tirados"] > 0:
		_line("Platos tirados: %d" % r["platos_tirados"], 24, Color("e57373"))
	for k in r["ingresos"]:
		_line("+ %s: %s €" % [_category(k), _money(r["ingresos"][k])], 26, Color("81c784"))
	for k in r["gastos"]:
		_line("− %s: %s €" % [_category(k), _money(r["gastos"][k])], 26, Color("e57373"))
	var profit: float = r["beneficio"]
	_line("Beneficio del día: %s €" % _money(profit), 32, Color("81c784") if profit >= 0.0 else Color("e57373"))
	_line("Propinas para el personal: %s €" % _money(r["propinas_personal"]), 22, Color("b0bec5"))
	var dishes: Dictionary = r["platos"]
	if not dishes.is_empty():
		var keys := dishes.keys()
		keys.sort_custom(func(a, b): return dishes[a] > dishes[b])
		var best: Array[String] = []
		for k in keys.slice(0, 3):
			best.append("%s (%d)" % [GameData.recipes[k]["nombre"], dishes[k]])
		_line("Más vendidos: " + ", ".join(best), 22, Color("b0bec5"))
	show()


func _line(text: String, size: int = 26, color: Color = Color.WHITE) -> void:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", color)
	_body.add_child(label)


static func _category(key: String) -> String:
	return CATEGORY_NAMES.get(key, key.capitalize())


static func _money(value: float) -> String:
	return "%.2f" % value
