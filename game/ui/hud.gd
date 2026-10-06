class_name HUD
extends CanvasLayer
## HUD: fecha y hora, velocidad, dinero, reputación, estado de la sala e informe diario.

@onready var time_label: Label = %TimeLabel
@onready var money_label: Label = %MoneyLabel
@onready var rating_label: Label = %RatingLabel
@onready var info_label: Label = %InfoLabel
@onready var stats_label: Label = %StatsLabel
@onready var day_report: DayReport = %DayReport
@onready var rotate_hint: Control = %RotateHint
@onready var computer: ComputerScreen = %Computer
@onready var dialogue: DialogueBox = %Dialogue
@onready var toasts: Toasts = %Toasts
@onready var top_bar: Control = $TopBar
@onready var bottom_bar: Control = $BottomBar
@onready var speed_buttons := {
	0: %PauseButton,
	1: %Speed1Button,
	2: %Speed2Button,
	4: %Speed4Button,
}


func _ready() -> void:
	for speed in speed_buttons:
		speed_buttons[speed].pressed.connect(Game.clock.set_speed.bind(speed))
	Game.clock.speed_changed.connect(_on_speed_changed)
	Game.sim.day_closed.connect(_on_day_closed)
	day_report.closed.connect(func(): Game.clock.set_speed(1))
	Game.sim.manager_started_using.connect(_on_manager_started_using)
	Game.sim.manager_started_talking.connect(_on_manager_started_talking)
	Game.sim.announcement.connect(toasts.add)
	computer.closed.connect(_on_panel_closed)
	dialogue.closed.connect(_on_dialogue_closed)
	_on_speed_changed(Game.clock.speed)


func _process(_delta: float) -> void:
	# En el navegador del móvil no se puede forzar la horizontal: avisamos.
	var window := get_viewport().get_visible_rect().size
	rotate_hint.visible = window.x < window.y
	var sim := Game.sim
	# Si la conversación se corta (la persona se va, o mandas al gestor a otro sitio).
	if dialogue.visible and not dialogue.is_self() and sim.manager.state != Manager.State.HABLANDO:
		dialogue.hide()
		dialogue.target = {}
		follow_manager()
	if _follow_manager:
		info_label.text = "Gestor: " + sim.manager.describe()
	time_label.text = Game.clock.get_time_text()
	money_label.text = "%s €" % format_money(sim.finances.money)
	rating_label.text = "Reputación %.1f/5" % sim.average_stars()
	var status := "Abierto" if sim.is_open_for_new_customers() else "Cerrado"
	stats_label.text = "%s · En sala: %d · Atendidos hoy: %d · Perdidos: %d · En cocina: %d platos" % [
		status, sim.customers_inside(), sim.day_stats["clientes_servidos"],
		sim.day_stats["grupos_perdidos"], sim.kitchen_queue.size() + _dishes_cooking()]


## Si es true, el texto de arriba muestra en directo lo que hace el gestor.
var _follow_manager := false


func show_info(text: String) -> void:
	info_label.text = text
	_follow_manager = false


## Muestra en directo lo que está haciendo el gestor.
func follow_manager() -> void:
	_follow_manager = true


## ¿Hay interfaz bajo ese punto de la pantalla? (para no mover al gestor al tocar botones)
func blocks_point(screen_pos: Vector2) -> bool:
	if computer.visible or day_report.is_visible_in_tree() or rotate_hint.visible:
		return true
	if dialogue.visible and dialogue.get_global_rect().has_point(screen_pos):
		return true
	if toasts.covers(screen_pos):
		return true
	return top_bar.get_global_rect().has_point(screen_pos) or bottom_bar.get_global_rect().has_point(screen_pos)


func _on_manager_started_talking(target: Dictionary) -> void:
	dialogue.open(target)
	follow_manager()


func _on_panel_closed() -> void:
	Game.sim.stop_manager()
	follow_manager()


## Al terminar de hablar, el gestor queda libre (salvo que se haya puesto a trabajar).
func _on_dialogue_closed() -> void:
	if Game.sim.manager.state == Manager.State.HABLANDO:
		Game.sim.stop_manager()
	follow_manager()


## Tocar al gestor: ¿qué hago ahora?
func open_self_dialogue() -> void:
	dialogue.open({ "entity": Game.sim.manager, "member": 0 })
	follow_manager()


func _on_manager_started_using(object_id: String) -> void:
	if object_id == "ordenador":
		computer.open()
		follow_manager()


func _dishes_cooking() -> int:
	var n := 0
	for c in Game.sim.cooks():
		n += c.tickets.size()
	return n


func _unhandled_key_input(event: InputEvent) -> void:
	if event.is_pressed() and event.keycode == KEY_SPACE:
		Game.clock.toggle_pause()


func _on_speed_changed(speed: int) -> void:
	for s in speed_buttons:
		speed_buttons[s].button_pressed = s == speed


func _on_day_closed(report: Dictionary) -> void:
	Game.clock.set_speed(0)
	day_report.show_report(report)


## 25000 -> "25.000"
static func format_money(value: float) -> String:
	var prefix := "-" if value < 0.0 else ""
	var digits := str(int(absf(value)))
	var out := ""
	for i in digits.length():
		if i > 0 and (digits.length() - i) % 3 == 0:
			out += "."
		out += digits[i]
	return prefix + out
