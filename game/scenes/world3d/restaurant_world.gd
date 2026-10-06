extends Node3D
## Restaurante en 3D: suelo, paredes y muebles, y un Bot por cada cliente y empleado de
## la simulación, colocado donde la simulación dice. Además, el gestor (el jugador).
## Una celda de la rejilla (x, y) mide 1 x 1 y está en el punto 3D (x, 0, y).

## Estado del grupo -> texto del bocadillo (su color indica el ánimo).
const BUBBLES := {
	CustomerGroup.State.EN_COLA: "...",
	CustomerGroup.State.ESPERANDO_PEDIR: "?",
	CustomerGroup.State.ESPERANDO_COMIDA: "...",
	CustomerGroup.State.ESPERANDO_CUENTA: "€",
}
const STREET_COLOR := Color("9aa3a8")
const WALL_COLOR := Color("f3e6d3")
const WOOD := Color("a0673a")
## Hacia dónde se mira para "mirar a la cámara".
const TOWARDS_CAMERA := Vector3(1, 0, 1)

var sim: RestaurantSim
## clave -> Bot
var _bots := {}
var _gestor: Bot
var _wave_left := 0.0
var _last_group_id := 0
var _selection: MeshInstance3D
## Platos sucios de cada mesa (se ven mientras está sin recoger): mesa -> Node3D
var _dirty_marks := {}
## Manchas del suelo: celda -> MeshInstance3D
var _stain_marks := {}


func setup(restaurant_sim: RestaurantSim) -> void:
	sim = restaurant_sim
	_build_floor()
	_build_walls()
	_build_furniture()
	_gestor = Bot.new()
	_gestor.setup(Bot.Role.GESTOR, 0)
	_gestor.entity = sim.manager
	add_child(_gestor)
	_gestor.face_direction(TOWARDS_CAMERA)


static func to_world(p: Vector2, y: float = 0.0) -> Vector3:
	return Vector3(p.x, y, p.y)


## Objeto del local (id) más cercano a un punto de la pantalla, o "".
func object_at(camera: Camera3D, screen_pos: Vector2) -> String:
	var radius := 0.7 * get_viewport().get_visible_rect().size.y / camera.size
	var best := ""
	var best_d := radius
	for id in sim.layout.objects:
		var cell: Vector2i = sim.layout.objects[id]["celda"]
		var d := camera.unproject_position(Vector3(cell.x, 0.6, cell.y)).distance_to(screen_pos)
		if d < best_d:
			best = id
			best_d = d
	return best


## Personaje más cercano a un punto de la pantalla (o null).
func person_at(camera: Camera3D, screen_pos: Vector2) -> Bot:
	var radius := 0.5 * get_viewport().get_visible_rect().size.y / camera.size
	var best: Bot = null
	var best_d := radius
	for bot in _bots.values() + [_gestor]:
		var p := camera.unproject_position(bot.global_position + Vector3(0, 0.4, 0) * bot.scale.y)
		var d := p.distance_to(screen_pos)
		if d < best_d:
			best = bot
			best_d = d
	return best


func _process(delta: float) -> void:
	if sim == null:
		return
	var seen := {}
	for g in sim.groups:
		for i in g.members.size():
			var key := "g%d_%d" % [g.id, i]
			seen[key] = true
			var bot := _bot(key, Bot.Role.CLIENTE, g.id * 7 + i)
			bot.member_index = i
			_sync_customer(bot, g, i)
	for s in sim.staff:
		var key := "s%d" % s.id
		seen[key] = true
		var role := Bot.Role.COCINERO if s.puesto == StaffMember.ROLE_COOK else Bot.Role.CAMARERO
		_sync_staff(_bot(key, role, s.id * 3 + 1), s)
	for key in _bots.keys():
		if not seen.has(key):
			_bots[key].queue_free()
			_bots.erase(key)
	_update_gestor(delta)
	_face_conversation()
	_sync_dirt()
	# Marca en el suelo el destino del gestor mientras camina.
	var path := sim.manager.mover.path
	_selection.visible = not path.is_empty()
	if not path.is_empty():
		_selection.position = Vector3(path.back().x, 0.01, path.back().y)


func _sync_customer(bot: Bot, g: CustomerGroup, member_index: int) -> void:
	var m := g.members[member_index]
	var moving := m.is_moving() and not m.blocked
	var seated := m.arrived() and g.table != null and sim.layout.is_sittable(m.last_cell)
	bot.entity = g
	bot.position = to_world(m.pos if seated else m.pos + m.jitter)
	bot.pose = Bot.Pose.SENTADO if seated else (Bot.Pose.ANDANDO if moving else Bot.Pose.DE_PIE)
	bot.eating = seated and g.state == CustomerGroup.State.COMIENDO
	if seated:
		bot.face_direction(to_world(Vector2(g.table.cell)) - bot.position)
	elif moving:
		bot.face_direction(to_world(m.facing))
	var mood := g.mood()
	if g.left_angry or mood < 0.35:
		bot.eyes = Bot.Eyes.ENFADADO
	elif mood < 0.65:
		bot.eyes = Bot.Eyes.NORMAL
	else:
		bot.eyes = Bot.Eyes.FELIZ
	if member_index != 0:
		return
	if g.state == CustomerGroup.State.SALIENDO and g.left_angry:
		bot.set_bubble("!", Color("d9433b"))
	elif BUBBLES.has(g.state):
		var color := Color("d9433b").lerp(Color("e0b43b"), mood * 2.0) if mood < 0.5 \
				else Color("e0b43b").lerp(Color("4caf50"), (mood - 0.5) * 2.0)
		bot.set_bubble(BUBBLES[g.state], color)
	else:
		bot.set_bubble("")


func _sync_staff(bot: Bot, s: StaffMember) -> void:
	bot.entity = s
	bot.position = to_world(s.mover.pos)
	bot.carrying = s.is_carrying_food()
	bot.eyes = Bot.Eyes.FELIZ if s.moral >= 40.0 else Bot.Eyes.NORMAL
	if s.puesto == StaffMember.ROLE_COOK:
		bot.pose = Bot.Pose.TRABAJANDO if not s.tickets.is_empty() else Bot.Pose.DE_PIE
		bot.face_direction(Vector3(1, 0, 0))
		return
	_pose_for_task(bot, s.mover, s.task)


## Postura y orientación de quien hace tareas de sala (camareros y el gestor).
func _pose_for_task(bot: Bot, mover: Mover, task: Dictionary) -> void:
	var phase: String = task.get("fase", "")
	if mover.is_moving() and not mover.blocked:
		bot.pose = Bot.Pose.ANDANDO
		bot.face_direction(to_world(mover.facing))
		return
	var working := phase == "atender" or phase == "recoger"
	bot.pose = Bot.Pose.TRABAJANDO if working else Bot.Pose.DE_PIE
	var look_at = null
	if phase == "atender":
		var g = task.get("grupo")
		if g != null and g.table != null and task["tipo"] != "acomodar":
			look_at = g.table.cell
		elif task.has("mesa"):
			look_at = task["mesa"].cell
		elif task.has("celda"):
			look_at = task["celda"] + Vector2i(0, 1)
		elif g != null and not g.members.is_empty():
			look_at = g.members[0].last_cell
	if phase == "recoger":
		bot.face_direction(Vector3(1, 0, 0))
	elif look_at != null:
		bot.face_direction(to_world(Vector2(look_at)) - bot.position)
	elif not working:
		bot.face_direction(TOWARDS_CAMERA)


## Platos sucios en las mesas sin recoger y manchas en el suelo.
func _sync_dirt() -> void:
	for t in sim.layout.tables:
		if not _dirty_marks.has(t):
			_dirty_marks[t] = _make_dirty_plates(t)
		_dirty_marks[t].visible = t.dirty
	for cell in sim.stains:
		if not _stain_marks.has(cell):
			var stain := MeshInstance3D.new()
			var disc := CylinderMesh.new()
			disc.top_radius = 0.5
			disc.bottom_radius = 0.5
			disc.height = 0.01
			stain.mesh = disc
			var mat := StandardMaterial3D.new()
			mat.albedo_color = Color(0.45, 0.33, 0.2, 0.75)
			mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			mat.roughness = 0.3
			stain.material_override = mat
			var h := hash(cell)
			stain.scale = Vector3(0.45 + (h % 7) * 0.03, 1, 0.3 + (h % 5) * 0.03)
			stain.rotation.y = float(h % 31) * 0.2
			stain.position = Vector3(cell.x + ((h % 9) - 4) * 0.03, 0.006, cell.y + ((h % 11) - 5) * 0.03)
			add_child(stain)
			_stain_marks[cell] = stain
	for cell in _stain_marks.keys():
		if not sim.stains.has(cell):
			_stain_marks[cell].queue_free()
			_stain_marks.erase(cell)


func _make_dirty_plates(t: RestaurantLayout.Table) -> Node3D:
	var node := Node3D.new()
	node.position = Vector3(t.cell.x, 0.47, t.cell.y)
	add_child(node)
	var plate := Bot.material(Color("e8e4dc"))
	var leftover := Bot.material(Color("8d6e4c"))
	var spots := [Vector3(-0.15, 0, -0.12), Vector3(0.14, 0, 0.1), Vector3(0.12, 0.02, -0.14)]
	for i in spots.size():
		var p := MeshInstance3D.new()
		p.mesh = Bot.resources()["cylinder"]
		p.material_override = plate
		p.scale = Vector3(0.2, 0.015 + i * 0.012, 0.2)
		p.position = spots[i]
		node.add_child(p)
		var crumb := MeshInstance3D.new()
		crumb.mesh = Bot.resources()["sphere"]
		crumb.material_override = leftover
		crumb.scale = Vector3(0.06, 0.02, 0.05)
		crumb.position = spots[i] + Vector3(0.03, 0.02 + i * 0.012, 0)
		node.add_child(crumb)
	return node


## Durante una conversación, el gestor y la otra persona se miran.
func _face_conversation() -> void:
	var m := sim.manager
	if m.state != Manager.State.HABLANDO:
		return
	var e = m.talking_to["entity"]
	var key := "s%d" % e.id if e is StaffMember else "g%d_%d" % [e.id, m.talking_to["member"]]
	if not _bots.has(key):
		return
	var other: Bot = _bots[key]
	_gestor.face_direction(other.position - _gestor.position)
	other.face_direction(_gestor.position - other.position)


## El gestor saluda cada vez que llega un grupo nuevo.
func _update_gestor(delta: float) -> void:
	var newest := 0
	for g in sim.groups:
		newest = maxi(newest, g.id)
	if newest > _last_group_id:
		_wave_left = 2.0
	_last_group_id = maxi(_last_group_id, newest)
	_wave_left -= delta * maxf(1.0, Game.clock.speed)
	var m := sim.manager
	_gestor.position = to_world(m.mover.pos)
	_gestor.eyes = Bot.Eyes.FELIZ
	if m.mover.is_moving() and not m.mover.blocked:
		_gestor.pose = Bot.Pose.ANDANDO
		_gestor.face_direction(to_world(m.mover.facing))
	elif m.state == Manager.State.USANDO:
		_gestor.pose = Bot.Pose.SENTADO
		var cell: Vector2i = sim.layout.objects[m.using]["celda"]
		_gestor.face_direction(to_world(Vector2(cell)) - _gestor.position)
	elif m.state == Manager.State.TRABAJANDO:
		_pose_for_task(_gestor, m.mover, m.task)
	else:
		_gestor.pose = Bot.Pose.DE_PIE
	_gestor.carrying = m.task.get("tipo", "") == "servir" and m.task.get("fase", "") == "ir_mesa"
	_gestor.waving = _wave_left > 0.0 and m.state == Manager.State.LIBRE


func _bot(key: String, role: Bot.Role, seed_value: int) -> Bot:
	if not _bots.has(key):
		var bot := Bot.new()
		bot.setup(role, seed_value)
		add_child(bot)
		_bots[key] = bot
	return _bots[key]


# --- Escenario -------------------------------------------------------------

func _build_floor() -> void:
	var r := sim.layout.region
	var tile := BoxMesh.new()
	tile.size = Vector3(0.98, 0.1, 0.98)
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.mesh = tile
	mm.instance_count = r.size.x * r.size.y
	var i := 0
	for x in range(r.position.x, r.end.x):
		for y in range(r.position.y, r.end.y):
			var cell := Vector2i(x, y)
			var height := -0.1 if x < 0 else -0.05
			mm.set_instance_transform(i, Transform3D(Basis(), Vector3(x, height, y)))
			var color := _cell_color(cell)
			if (x + y) % 2 == 0:
				color = color.darkened(0.06)
			mm.set_instance_color(i, color)
			i += 1
	var floor_mat := StandardMaterial3D.new()
	floor_mat.vertex_color_use_as_albedo = true
	floor_mat.roughness = 0.85
	var floor_node := MultiMeshInstance3D.new()
	floor_node.multimesh = mm
	floor_node.material_override = floor_mat
	add_child(floor_node)

	_selection = MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(0.98, 0.98)
	_selection.mesh = plane
	var sel_mat := StandardMaterial3D.new()
	sel_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	sel_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	sel_mat.albedo_color = Color(1, 1, 1, 0.45)
	_selection.material_override = sel_mat
	_selection.visible = false
	add_child(_selection)


func _build_walls() -> void:
	var w := float(sim.layout.size.x)
	# Pared del fondo con ventanas y el cartel del restaurante.
	_box(Vector3(w, 1.5, 0.2), Vector3(w / 2.0 - 0.5, 0.75, -0.6), WALL_COLOR)
	for x in [1.0, 4.0, 9.5]:
		_box(Vector3(1.4, 0.6, 0.05), Vector3(x, 0.9, -0.48), Color("bcd8ec"))
	var sign_label := Label3D.new()
	sign_label.text = "MI RESTAURANTE"
	sign_label.font_size = 96
	sign_label.outline_size = 0
	sign_label.pixel_size = 0.004
	sign_label.modulate = Color("a0673a")
	sign_label.position = Vector3(6.6, 1.25, -0.48)
	add_child(sign_label)


func _build_furniture() -> void:
	var layout := sim.layout
	for table in layout.tables:
		var c := Vector3(table.cell.x, 0, table.cell.y)
		_box(Vector3(0.7, 0.06, 0.7), c + Vector3(0, 0.42, 0), WOOD)
		_box(Vector3(0.56, 0.01, 0.56), c + Vector3(0, 0.455, 0), Color("f4efe6"))
		_box(Vector3(0.1, 0.4, 0.1), c + Vector3(0, 0.2, 0), WOOD.darkened(0.3))
		for seat in table.seats:
			var s := Vector3(seat.x, 0, seat.y)
			var away := (s - c).normalized()
			_box(Vector3(0.36, 0.16, 0.36), s + Vector3(0, 0.08, 0), WOOD.darkened(0.25))
			var back_size := Vector3(0.05, 0.36, 0.36) if absf(away.x) > 0.5 else Vector3(0.36, 0.36, 0.05)
			_box(back_size, s + away * 0.17 + Vector3(0, 0.34, 0), WOOD.darkened(0.25))
	for cell in layout.counter_cells:
		var p := Vector3(cell.x, 0, cell.y)
		_box(Vector3(0.98, 0.8, 0.98), p + Vector3(0, 0.4, 0), Color("c7ccd1"))
		_box(Vector3(1.0, 0.05, 1.0), p + Vector3(0, 0.82, 0), Color("e6e9ec"))
	for cell in layout.cook_stations:
		var p := Vector3(cell.x + 1, 0, cell.y)
		_box(Vector3(0.9, 0.75, 0.9), p + Vector3(0, 0.375, 0), Color("3d4248"))
		for dz in [-0.2, 0.2]:
			var burner := _box(Vector3(0.24, 0.02, 0.24), p + Vector3(0, 0.76, dz), Color("e2553b"))
			var mat := burner.material_override as StandardMaterial3D
			mat.emission_enabled = true
			mat.emission = Color("e2553b")
	_build_office()
	for zone in layout.zones:
		if not zone["bloqueada"]:
			continue
		var rect: Rect2i = zone["rect"]
		for x in range(rect.position.x, rect.end.x):
			for y in range(rect.position.y, rect.end.y):
				if (x + y) % 2 == 0:
					_box(Vector3(0.7, 0.5, 0.7), Vector3(x, 0.25, y), Color("c49a6c"))
				else:
					_box(Vector3(0.45, 0.3, 0.45), Vector3(x, 0.15, y), Color("b5885a"))


## Despacho: mesa con ordenador, silla del gestor, estantería y planta.
func _build_office() -> void:
	var layout := sim.layout
	if not layout.objects.has("ordenador"):
		return
	var pc: Dictionary = layout.objects["ordenador"]
	var desk := Vector3(pc["celda"].x, 0, pc["celda"].y)
	var seat := Vector3(pc["uso"].x, 0, pc["uso"].y)
	var toward := (desk - seat).normalized()
	var side := Vector3(-toward.z, 0, toward.x)
	_box(Vector3(0.8, 0.06, 0.8) if absf(toward.x) > 0.5 else Vector3(0.8, 0.06, 0.8), desk + Vector3(0, 0.46, 0), WOOD.lightened(0.15))
	for corner in [Vector3(-0.33, 0, -0.33), Vector3(0.33, 0, -0.33), Vector3(-0.33, 0, 0.33), Vector3(0.33, 0, 0.33)]:
		_box(Vector3(0.06, 0.44, 0.06), desk + corner + Vector3(0, 0.22, 0), WOOD.darkened(0.3))
	# Pantalla mirando a la silla, con brillo.
	var monitor_pos := desk + toward * 0.12 + Vector3(0, 0.68, 0)
	var monitor_size := Vector3(0.05, 0.3, 0.46) if absf(toward.x) > 0.5 else Vector3(0.46, 0.3, 0.05)
	_box(monitor_size, monitor_pos, Color("2a2d34"))
	var screen := _box(monitor_size * Vector3(0.6, 0.85, 0.9) if absf(toward.x) > 0.5 else monitor_size * Vector3(0.9, 0.85, 0.6), monitor_pos - toward * 0.02, Color("7fc8f0"))
	var screen_mat := screen.material_override as StandardMaterial3D
	screen_mat.emission_enabled = true
	screen_mat.emission = Color("7fc8f0")
	screen_mat.emission_energy_multiplier = 0.8
	_box(Vector3(0.08, 0.16, 0.08), desk + toward * 0.12 + Vector3(0, 0.55, 0), Color("2a2d34"))
	_box(Vector3(0.3, 0.02, 0.12) if absf(toward.x) > 0.5 else Vector3(0.12, 0.02, 0.3), desk - toward * 0.15 + Vector3(0, 0.5, 0), Color("dfe3e8"))
	# Silla de oficina.
	_box(Vector3(0.38, 0.06, 0.38), seat + Vector3(0, 0.16, 0), Color("3b4a63"))
	_box(Vector3(0.06, 0.4, 0.38) if absf(toward.x) > 0.5 else Vector3(0.38, 0.4, 0.06), seat - toward * 0.19 + Vector3(0, 0.36, 0), Color("3b4a63"))
	# Estantería y planta en las esquinas libres del despacho.
	for zone in layout.zones:
		if zone["nombre"] != "Despacho":
			continue
		var r: Rect2i = zone["rect"]
		_box(Vector3(0.9, 1.1, 0.3), Vector3(r.end.x - 1, 0.55, r.position.y - 0.3), Color("8a5a35"))
		for i in 3:
			_box(Vector3(0.12, 0.22, 0.2), Vector3(r.end.x - 1.3 + i * 0.2, 0.75, r.position.y - 0.3), Color(["c0504d", "4f81bd", "9bbb59"][i]))
		var pot := Vector3(r.end.x - 1, 0, r.end.y - 1)
		_box(Vector3(0.3, 0.3, 0.3), pot + Vector3(0, 0.15, 0), Color("b5651d"))
		_box(Vector3(0.4, 0.4, 0.4), pot + Vector3(0, 0.5, 0), Color("4f9a4a"))


func _box(size: Vector3, pos: Vector3, color: Color) -> MeshInstance3D:
	var m := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	m.mesh = mesh
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = 0.7
	m.material_override = mat
	m.position = pos
	add_child(m)
	return m


func _cell_color(cell: Vector2i) -> Color:
	if cell.x < 0:
		return STREET_COLOR
	for zone in sim.layout.zones:
		if zone["rect"].has_point(cell):
			return zone["color"]
	return Color("dddddd")
