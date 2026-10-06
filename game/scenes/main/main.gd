extends Node3D
## Escena principal: une el restaurante 3D, la simulación y el HUD.

@onready var world: Node3D = $World
@onready var camera: IsoCamera = $Camera
@onready var sun: DirectionalLight3D = $Sun
@onready var hud: HUD = $HUD

var _press_position := Vector2.ZERO
## Si en el gesto ha habido dos dedos (pellizco), al soltar no es un toque.
var _multi_touch := false


func _ready() -> void:
	sun.rotation_degrees = Vector3(-55, -30, 0)
	world.setup(Game.sim)
	camera.focus(Vector3(Game.sim.layout.size.x / 2.0 - 1.0, 0, Game.sim.layout.size.y / 2.0))
	hud.show_info("Toca el suelo para mover al gestor · el ordenador del despacho para gestionar")


func _unhandled_input(event: InputEvent) -> void:
	if not event is InputEventScreenTouch:
		return
	if event.index > 0:
		_multi_touch = true
	elif event.pressed:
		_press_position = event.position
		_multi_touch = false
	elif not _multi_touch and event.position.distance_to(_press_position) < camera.tap_slop():
		_on_tap(event.position)


## Un toque en el mundo: el ordenador se usa, las personas se consultan y el suelo es
## adonde va el gestor.
func _on_tap(screen_pos: Vector2) -> void:
	if hud.blocks_point(screen_pos):
		return
	var sim := Game.sim
	var object_id: String = world.object_at(camera, screen_pos)
	var bot: Bot = world.person_at(camera, screen_pos)
	if bot != null and object_id == "":
		hud.show_info(_describe(bot))
		return
	if object_id != "":
		sim.manager.go_use(sim.layout, object_id)
		hud.show_info("Gestor: %s" % sim.manager.describe())
		return
	var ground := camera.screen_to_ground(screen_pos)
	var cell := Vector2i(roundi(ground.x), roundi(ground.z))
	if not sim.layout.region.has_point(cell):
		return
	sim.manager.walk_to(sim.layout, cell)
	hud.show_info("Gestor: va a %s" % sim.layout.zone_name_at(sim.layout.nearest_walkable(cell)))


func _describe(bot: Bot) -> String:
	if bot.role == Bot.Role.GESTOR:
		return "Tú · el gestor del restaurante · " + Game.sim.manager.describe()
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
