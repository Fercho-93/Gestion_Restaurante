class_name DialogueBox
extends PanelContainer
## Cuadro de conversación entre el gestor y otra persona del local, en la parte de abajo
## para que se siga viendo el restaurante.

signal closed

var target := {}
var _name_label: Label
var _text_label: Label
var _options: GridContainer


func _ready() -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = Color("1f2430", 0.95)
	style.set_corner_radius_all(18)
	style.border_color = Color("ffd54f")
	style.set_border_width_all(4)
	add_theme_stylebox_override("panel", style)
	var margin := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 24)
	add_child(margin)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 14)
	margin.add_child(column)
	_name_label = Label.new()
	_name_label.add_theme_font_size_override("font_size", 30)
	_name_label.add_theme_color_override("font_color", Color("ffd54f"))
	column.add_child(_name_label)
	_text_label = Label.new()
	_text_label.add_theme_font_size_override("font_size", 34)
	_text_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(_text_label)
	_options = GridContainer.new()
	_options.columns = 3
	_options.add_theme_constant_override("h_separation", 14)
	_options.add_theme_constant_override("v_separation", 10)
	column.add_child(_options)
	hide()


func open(new_target: Dictionary) -> void:
	target = new_target
	_name_label.text = Conversation.speaker_name(target)
	_text_label.text = "«%s»" % Conversation.opening(target, Game.sim)
	_rebuild_options()
	show()


## Las opciones cambian según la situación (y según lo ya hablado).
func _rebuild_options() -> void:
	for child in _options.get_children():
		_options.remove_child(child)
		child.queue_free()
	for option in Conversation.options(target, Game.sim):
		var b := Button.new()
		b.text = option["texto"]
		b.custom_minimum_size = Vector2(380, 72)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.add_theme_font_size_override("font_size", 26)
		b.pressed.connect(_choose.bind(option["id"]))
		_options.add_child(b)


func close() -> void:
	if visible:
		hide()
		target = {}
		closed.emit()


func _choose(option_id: String) -> void:
	var answer := Conversation.choose(target, option_id, Game.sim)
	_text_label.text = "«%s»" % answer
	if option_id == "adios":
		# Se despide y el cuadro se cierra solo al momento.
		for b in _options.get_children():
			b.disabled = true
		get_tree().create_timer(1.2).timeout.connect(close)
		return
	_rebuild_options()
