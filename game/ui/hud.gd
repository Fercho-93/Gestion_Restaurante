extends CanvasLayer
## HUD superior: fecha y hora, controles de velocidad y dinero.

@onready var time_label: Label = %TimeLabel
@onready var money_label: Label = %MoneyLabel
@onready var info_label: Label = %InfoLabel
@onready var speed_buttons := {
	0: %PauseButton,
	1: %Speed1Button,
	2: %Speed2Button,
	4: %Speed4Button,
}

var money := 25000.0


func _ready() -> void:
	for speed in speed_buttons:
		speed_buttons[speed].pressed.connect(GameClock.clock.set_speed.bind(speed))
	GameClock.clock.speed_changed.connect(_on_speed_changed)
	GameClock.clock.minute_passed.connect(func(_m): _refresh_time())
	_on_speed_changed(GameClock.clock.speed)
	_refresh_time()
	money_label.text = "%s €" % _format_money(money)


func show_info(text: String) -> void:
	info_label.text = text


func _unhandled_key_input(event: InputEvent) -> void:
	if event.is_pressed() and event.keycode == KEY_SPACE:
		GameClock.clock.toggle_pause()


func _on_speed_changed(speed: int) -> void:
	for s in speed_buttons:
		speed_buttons[s].button_pressed = s == speed


func _refresh_time() -> void:
	time_label.text = GameClock.clock.get_time_text()


static func _format_money(value: float) -> String:
	var digits := str(int(value))
	var out := ""
	for i in digits.length():
		if i > 0 and (digits.length() - i) % 3 == 0:
			out += "."
		out += digits[i]
	return out
