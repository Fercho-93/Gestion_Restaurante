extends Node2D
## Escena principal: une el mundo isométrico, la simulación y el HUD.

## Si el dedo se mueve más que esto, es un arrastre de cámara y no un toque.
const TAP_MAX_DISTANCE := 16.0

@onready var floor_grid: Node2D = $World/IsoFloor
@onready var restaurant_view: Node2D = $World/RestaurantView
@onready var camera: Camera2D = $Camera
@onready var hud: CanvasLayer = $HUD

var _press_position := Vector2.ZERO


func _ready() -> void:
	floor_grid.setup(Game.sim.layout)
	restaurant_view.setup(Game.sim)
	camera.position = Iso.cell_to_screen(Game.sim.layout.size / 2) + Vector2(-80, 0)
	hud.show_info("Toca a una persona o una zona para ver detalles")


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch and event.index == 0:
		if event.pressed:
			_press_position = event.position
		elif event.position.distance_to(_press_position) < TAP_MAX_DISTANCE:
			_on_tap(get_global_mouse_position())


func _on_tap(world_pos: Vector2) -> void:
	var person: PersonSprite = restaurant_view.person_at(world_pos)
	if person != null:
		floor_grid.select(Vector2i(-999, -999))
		hud.show_info(_describe(person.entity))
		return
	var cell := Iso.screen_to_cell(world_pos)
	floor_grid.select(cell)
	hud.show_info(Game.sim.layout.zone_name_at(cell))


func _describe(entity) -> String:
	if entity is CustomerGroup:
		var g: CustomerGroup = entity
		var text := "Grupo de %d · %s (%d min) · Ánimo %d%%" % [g.size, g.state_name(), int(g.state_time), roundi(g.mood() * 100)]
		if g.left_angry:
			text += " · " + g.leave_reason
		return text
	if entity is StaffMember:
		var s: StaffMember = entity
		var stats := "Trato %d" % s.trato if s.puesto == StaffMember.ROLE_WAITER else "Habilidad %d" % s.habilidad
		return "%s (%s) · Velocidad %d · %s · %s" % [s.nombre, "sala" if s.puesto == StaffMember.ROLE_WAITER else "cocina",
				s.velocidad, stats, s.describe_task()]
	return ""
