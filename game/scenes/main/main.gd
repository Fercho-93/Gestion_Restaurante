extends Node3D
## Escena principal: une el restaurante 3D, la simulación y el HUD.

## Si el dedo se mueve más que esto, es un arrastre de cámara y no un toque.
const TAP_MAX_DISTANCE := 16.0

@onready var world: Node3D = $World
@onready var camera: IsoCamera = $Camera
@onready var sun: DirectionalLight3D = $Sun
@onready var hud: CanvasLayer = $HUD

var _press_position := Vector2.ZERO


func _ready() -> void:
	sun.rotation_degrees = Vector3(-55, -30, 0)
	world.setup(Game.sim)
	camera.focus(Vector3(Game.sim.layout.size.x / 2.0 - 1.0, 0, Game.sim.layout.size.y / 2.0))
	hud.show_info("Toca a una persona o una zona para ver detalles")


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch and event.index == 0:
		if event.pressed:
			_press_position = event.position
		elif event.position.distance_to(_press_position) < TAP_MAX_DISTANCE:
			_on_tap(event.position)


func _on_tap(screen_pos: Vector2) -> void:
	var bot: Bot = world.person_at(camera, screen_pos)
	if bot != null:
		world.select(Vector2i(-999, -999))
		hud.show_info(_describe(bot))
		return
	var ground := camera.screen_to_ground(screen_pos)
	var cell := Vector2i(roundi(ground.x), roundi(ground.z))
	world.select(cell)
	hud.show_info(Game.sim.layout.zone_name_at(cell))


func _describe(bot: Bot) -> String:
	if bot.role == Bot.Role.GESTOR:
		return "Tú · el gestor del restaurante"
	if bot.entity is CustomerGroup:
		var g: CustomerGroup = bot.entity
		var text := "Grupo de %d · %s (%d min) · Ánimo %d%%" % [g.size, g.state_name(), int(g.state_time), roundi(g.mood() * 100)]
		if g.left_angry:
			text += " · " + g.leave_reason
		return text
	if bot.entity is StaffMember:
		var s: StaffMember = bot.entity
		var stats := "Trato %d" % s.trato if s.puesto == StaffMember.ROLE_WAITER else "Habilidad %d" % s.habilidad
		return "%s (%s) · Velocidad %d · %s · %s" % [s.nombre, "sala" if s.puesto == StaffMember.ROLE_WAITER else "cocina",
				s.velocidad, stats, s.describe_task()]
	return ""
