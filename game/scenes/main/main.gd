extends Node3D
## Escena principal: une el restaurante 3D, la simulación y el HUD.

@onready var world: Node3D = $World
@onready var camera: IsoCamera = $Camera
@onready var sun: DirectionalLight3D = $Sun
@onready var hud: HUD = $HUD

var _taps := TapDetector.new()
var build := BuildMode.new()
var _day := -1.0


func _ready() -> void:
	sun.rotation_degrees = Vector3(-55, 30, 0)
	world.setup(Game.sim)
	camera.fit_layout(Game.sim.layout.size)
	hud.show_info("Toca: suelo = ir · persona = hablar · a ti = trabajar")
	hud.toasts.pressed.connect(func(cell: Vector2i): camera.focus(Vector3(cell.x, 0, cell.y)))
	add_child(build)
	build.setup(Game.sim, camera, world.finishes)
	hud.setup_build(build)
	hud.build_button.pressed.connect(_enter_build)
	hud.build_panel.done.connect(build.exit)


## Luz del día: sol, cielo, cristales y lámparas cambian con la hora.
func _process(_delta: float) -> void:
	var t := Game.clock.get_hour() + Game.clock.get_minute() / 60.0
	var day := smoothstep(6.5, 9.0, t) * (1.0 - smoothstep(18.5, 21.0, t))
	if absf(day - _day) < 0.004:
		return
	_day = day
	var night := 1.0 - day
	sun.light_energy = lerpf(0.12, 0.75, day)
	sun.light_color = Color(0.55, 0.6, 0.95).lerp(Color(1, 0.96, 0.9), day)
	var env := $Environment.environment as Environment
	env.background_color = Color("141a33").lerp(Color(0.66, 0.75, 0.88), day)
	env.ambient_light_color = Color(0.36, 0.42, 0.7).lerp(Color(0.86, 0.89, 0.96), day)
	env.ambient_light_energy = lerpf(0.42, 0.35, day)
	world.finishes.set_night(night)
	for light in get_tree().get_nodes_in_group("luz_ambiente"):
		light.light_energy = float(light.get_meta("base", 1.0)) * lerpf(0.35, 1.0, night)


func _enter_build() -> void:
	hud.dialogue.close()
	if hud.computer.visible:
		hud.computer.close()
	build.enter()


# En _input (y no _unhandled_input) para ver también los arrastres que usa la cámara.
func _input(event: InputEvent) -> void:
	var tap = _taps.feed(event, camera.tap_slop())
	if tap != null:
		_on_tap(tap)


## Un toque en el mundo: el ordenador se usa, las personas se consultan y el suelo es
## adonde va el gestor.
func _on_tap(screen_pos: Vector2) -> void:
	if hud.blocks_point(screen_pos):
		return
	if build.active:
		build.tap(screen_pos)
		return
	var sim := Game.sim
	var object_id: String = world.object_at(camera, screen_pos)
	var bot: Bot = world.person_at(camera, screen_pos)
	if bot != null and object_id == "":
		if bot.role == Bot.Role.GESTOR:
			hud.open_self_dialogue()
		else:
			sim.order_manager_talk(bot.entity, bot.member_index)
			sim.manager.talk_name = _short_name(bot)
			hud.follow_manager()
		return
	if object_id != "":
		sim.order_manager_use(object_id)
		hud.follow_manager()
		return
	var ground := camera.screen_to_ground(screen_pos)
	var cell := Vector2i(roundi(ground.x), roundi(ground.z))
	if not sim.layout.region.has_point(cell):
		return
	# Una mesa sin recoger o una mancha: el gestor va a limpiarla.
	var table := sim.layout.table_at(cell)
	if table != null and table.dirty and table.cleaner == null:
		sim.order_manager_clean_table(table)
		hud.follow_manager()
		return
	if sim.stains.has(cell) and sim.stains[cell] == null:
		sim.order_manager_mop(cell)
		hud.follow_manager()
		return
	sim.order_manager_walk(cell)
	sim.manager.walk_zone = sim.layout.zone_name_at(sim.manager.destination)
	hud.follow_manager()


func _short_name(bot: Bot) -> String:
	if bot.entity is StaffMember:
		return bot.entity.nombre
	return Conversation.customer_name(bot.entity, bot.member_index)


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
		return "%s (%s) · Velocidad %d · %s · Ánimo %d · %s" % [s.nombre, s.rol_name().to_lower(),
				s.velocidad, stats, roundi(s.moral), s.describe_task()]
	return ""
