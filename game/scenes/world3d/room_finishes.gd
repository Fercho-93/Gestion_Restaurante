class_name RoomFinishes
extends Node3D
## Acabados del local en 3D: suelos con textura, paredes con ventanas, cuadros y luces.
## Se rehace entero cuando cambian los suelos o las paredes (es barato). La luz de las
## lámparas y el brillo de los cristales cambian con la hora (de día / de noche).

const STREET_COLOR := Color("9aa3a8")
const FRAME_COLOR := Color("f4f1ea")
const WARM := Color("ffd9a0")
const THICKNESS := 0.2
const H := RestaurantLayout.WALL_HEIGHT

var sim: RestaurantSim
var night := 0.0
var _floor_root: Node3D
var _wall_root: Node3D
var _room_root: Node3D
var _inner_root: Node3D
var _wall_mats := {}
var _floor_mats := {}
var _glass_mat: StandardMaterial3D
var _frame_mat: StandardMaterial3D
var _highlight: MeshInstance3D
## Luces de pared: [OmniLight3D, energía de base]
var _lights: Array = []
var _glows: Array = []


func setup(restaurant_sim: RestaurantSim) -> void:
	sim = restaurant_sim
	_floor_root = Node3D.new()
	add_child(_floor_root)
	_wall_root = Node3D.new()
	add_child(_wall_root)
	_glass_mat = StandardMaterial3D.new()
	_glass_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_glass_mat.roughness = 0.1
	_frame_mat = StandardMaterial3D.new()
	_frame_mat.albedo_color = FRAME_COLOR
	_frame_mat.roughness = 0.6
	_highlight = MeshInstance3D.new()
	_highlight.mesh = BoxMesh.new()
	var hm := StandardMaterial3D.new()
	hm.albedo_color = Color(1.0, 0.85, 0.3, 0.55)
	hm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	hm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_highlight.material_override = hm
	_highlight.visible = false
	add_child(_highlight)
	_room_root = Node3D.new()
	add_child(_room_root)
	_inner_root = Node3D.new()
	add_child(_inner_root)
	sim.finishes_changed.connect(rebuild)
	sim.layout_changed.connect(_build_rooms)
	sim.rooms_changed.connect(_build_rooms)
	rebuild()
	set_night(0.0)


func rebuild() -> void:
	for n in [_floor_root, _wall_root]:
		for child in n.get_children():
			child.queue_free()
	_lights.clear()
	_glows.clear()
	_build_floors()
	_build_walls()
	_build_rooms()
	_build_inner_walls()
	set_night(night)


# --- Suelos ------------------------------------------------------------------------------

func _build_floors() -> void:
	var layout := sim.layout
	var r := layout.region
	var groups := {}
	for x in range(r.position.x, r.end.x):
		for y in range(r.position.y, r.end.y):
			var cell := Vector2i(x, y)
			var key := "calle"
			if x >= 0:
				key = layout.floors.get(cell, "zona")
			if not groups.has(key):
				groups[key] = []
			groups[key].append(cell)
	for key in groups:
		var cells: Array = groups[key]
		var mat := StandardMaterial3D.new()
		mat.vertex_color_use_as_albedo = true
		if layout.floor_catalog.has(key):
			mat.albedo_texture = FinishTextures.floor_texture(key)
			mat.roughness = 1.0 - 0.7 * float(layout.floor_catalog[key].get("brillo", 0.4))
		else:
			mat.roughness = 0.85
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.use_colors = true
		var tile := BoxMesh.new()
		tile.size = Vector3(0.98, 0.1, 0.98)
		mm.mesh = tile
		mm.instance_count = cells.size()
		for i in cells.size():
			var c: Vector2i = cells[i]
			var height := -0.1 if c.x < 0 else -0.05
			mm.set_instance_transform(i, Transform3D(Basis(), Vector3(c.x, height, c.y)))
			var tint := 0.8 + 0.05 * float(posmod(c.x * 73 + c.y * 151, 7)) / 6.0
			if (c.x + c.y) % 2 == 0:
				tint -= 0.02
			var color := Color(tint, tint, tint)
			if not layout.floor_catalog.has(key):
				color = (STREET_COLOR if key == "calle" else _zone_color(c)) * tint
				color.a = 1.0
			mm.set_instance_color(i, color)
		var node := MultiMeshInstance3D.new()
		node.multimesh = mm
		node.material_override = mat
		_floor_root.add_child(node)


func _zone_color(cell: Vector2i) -> Color:
	for zone in sim.layout.zones:
		if zone["rect"].has_point(cell):
			return zone["color"]
	return Color("dddddd")


# --- Paredes -----------------------------------------------------------------------------

func _build_walls() -> void:
	var layout := sim.layout
	if layout.walls.is_empty():
		return
	var w := layout.size.x
	var h := layout.size.y
	# Esquina de las dos paredes.
	_box(Vector3(THICKNESS, H, THICKNESS), Vector3(-0.6, H / 2.0, -0.6), _style_mat("crema"))
	for key in layout.walls:
		var key_text: String = key
		_segment(key_text.substr(0, 1), int(key_text.substr(1)), layout.walls[key], key_text)
	# Dintel y marco de la puerta de la fachada.
	var rows := layout.door_rows
	if not rows.is_empty():
		var first: int = rows.min()
		var span: int = rows.max() - first + 1
		_box(Vector3(THICKNESS, 0.3, span), Vector3(-0.6, H - 0.15, first + span / 2.0 - 0.5), _style_mat("crema"))
		for z in [first - 0.5, rows.max() + 0.5]:
			_box(Vector3(THICKNESS + 0.04, H, 0.08), Vector3(-0.6, H / 2.0, z), _frame_mat)
	# Cartel del restaurante sobre la pared del fondo.
	var board := _box(Vector3(2.9, 0.42, 0.08), Vector3(w * 0.55, H + 0.3, -0.62), Color("5e3a1c"))
	board.name = "CartelTabla"
	var sign_label := Label3D.new()
	sign_label.text = "MI RESTAURANTE"
	sign_label.font_size = 96
	sign_label.outline_size = 0
	sign_label.pixel_size = 0.0036
	sign_label.modulate = Color("f3e6d3")
	sign_label.position = Vector3(w * 0.55, H + 0.3, -0.57)
	_wall_root.add_child(sign_label)
	if h <= 0:
		return


func _segment(side: String, index: int, seg: Dictionary, key: String) -> void:
	var layout := sim.layout
	var mat := _style_mat(seg["estilo"])
	var opening: String = seg["abertura"]
	match opening:
		"ventana_pequena":
			_window(side, index, mat, 0.5, 0.95, 1.35)
		"ventana":
			_window(side, index, mat, 0.7, 0.7, 1.35)
		"ventanal":
			_window(side, index, mat, 0.9, 0.1, 1.45)
		_:
			_wbox(side, index, 0.0, H / 2.0, 0.0, 1.0, H, THICKNESS, mat)
	var decor: String = seg["adorno"]
	if decor != "":
		_decor(side, index, decor)


## Pared con un hueco de `width` entre las alturas `bottom` y `top`, con cristal y marco.
func _window(side: String, index: int, mat: Material, width: float, bottom: float, top: float) -> void:
	_wbox(side, index, 0.0, bottom / 2.0, 0.0, 1.0, bottom, THICKNESS, mat)
	_wbox(side, index, 0.0, (top + H) / 2.0, 0.0, 1.0, H - top, THICKNESS, mat)
	var side_w := (1.0 - width) / 2.0
	if side_w > 0.001:
		for sign in [-1.0, 1.0]:
			_wbox(side, index, sign * (width + side_w) / 2.0, (bottom + top) / 2.0, 0.0, side_w, top - bottom, THICKNESS, mat)
	var glass := _wbox(side, index, 0.0, (bottom + top) / 2.0, 0.0, width, top - bottom, 0.03, _glass_mat)
	glass.name = "Cristal"
	glass.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	# Marco blanco por el lado de dentro.
	var inner := THICKNESS / 2.0 + 0.01
	_wbox(side, index, 0.0, bottom, inner, width + 0.06, 0.05, 0.05, _frame_mat)
	_wbox(side, index, 0.0, top, inner, width + 0.06, 0.05, 0.05, _frame_mat)
	for sign in [-1.0, 1.0]:
		_wbox(side, index, sign * (width / 2.0 + 0.015), (bottom + top) / 2.0, inner, 0.05, top - bottom, 0.05, _frame_mat)
	if width > 0.6:
		_wbox(side, index, 0.0, (bottom + top) / 2.0, inner, 0.03, top - bottom, 0.03, _frame_mat)


func _decor(side: String, index: int, id: String) -> void:
	var face := THICKNESS / 2.0 + 0.02  # sobre la cara de dentro de la pared
	match id:
		"cuadro_paisaje", "cuadro_abstracto":
			_wbox(side, index, 0.0, 1.0, face - 0.01, 0.66, 0.5, 0.04, Color("5e3a1c"))
			_art(side, index, id, 0.0, 1.0, face + 0.015, 0.56, 0.42)
		"fotos":
			_art(side, index, id, 0.0, 1.0, face, 0.92, 0.69)
		"espejo":
			_wbox(side, index, 0.0, 0.95, face - 0.01, 0.58, 0.88, 0.04, Color("c9a15a"))
			_art(side, index, id, 0.0, 0.95, face + 0.015, 0.5, 0.8)
		"reloj":
			_art(side, index, id, 0.0, 1.15, face, 0.5, 0.375)
		"aplique":
			_wbox(side, index, 0.0, 1.05, face, 0.12, 0.2, 0.06, Color("37474f"))
			var shade := _wbox(side, index, 0.0, 1.22, face + 0.07, 0.2, 0.22, 0.12, Color(WARM))
			_glow(shade, WARM)
			_wall_light(side, index, 1.15, face + 0.4, WARM, 0.9, 2.8)
		"neon":
			_wbox(side, index, 0.0, 1.05, face - 0.01, 0.9, 0.34, 0.03, Color("2b2f3a"))
			var label := Label3D.new()
			label.text = "ABIERTO"
			label.font_size = 64
			label.pixel_size = 0.0045
			label.modulate = Color("ff6fb5")
			label.shaded = false
			label.outline_size = 0
			label.position = _wpos(side, index, 0.0, 1.05, face + 0.03)
			if side == "O":
				label.rotation.y = PI / 2.0
			_wall_root.add_child(label)
			_wall_light(side, index, 1.05, face + 0.5, Color("ff6fb5"), 0.5, 2.4)


func _art(side: String, index: int, id: String, u: float, v: float, w: float, width: float, height: float) -> void:
	var quad := MeshInstance3D.new()
	var mesh := QuadMesh.new()
	mesh.size = Vector2(width, height)
	quad.mesh = mesh
	var mat := StandardMaterial3D.new()
	mat.albedo_texture = FinishTextures.art_texture(id)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
	mat.roughness = 0.6
	quad.material_override = mat
	quad.position = _wpos(side, index, u, v, w)
	if side == "O":
		quad.rotation.y = PI / 2.0
	_wall_root.add_child(quad)


func _wall_light(side: String, index: int, v: float, w: float, color: Color, energy: float, reach: float) -> void:
	var light := OmniLight3D.new()
	light.light_color = color
	light.omni_range = reach
	light.light_energy = energy
	light.position = _wpos(side, index, 0.0, v, w)
	_wall_root.add_child(light)
	_lights.append([light, energy])


## Posición en el mundo de un punto de un segmento de pared: `u` a lo largo, `v` en
## altura y `w` hacia dentro del local (0 = centro del muro).
func _wpos(side: String, index: int, u: float, v: float, w: float) -> Vector3:
	if side == "N":
		return Vector3(index + u, v, -0.6 + w)
	return Vector3(-0.6 + w, v, index + u)


func _wbox(side: String, index: int, u: float, v: float, w: float, size_u: float, size_v: float, size_w: float, material: Variant) -> MeshInstance3D:
	var size := Vector3(size_u, size_v, size_w) if side == "N" else Vector3(size_w, size_v, size_u)
	return _box(size, _wpos(side, index, u, v, w), material)


func _box(size: Vector3, pos: Vector3, material: Variant) -> MeshInstance3D:
	var m := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	m.mesh = mesh
	if material is Material:
		m.material_override = material
	else:
		var mat := StandardMaterial3D.new()
		mat.albedo_color = material
		mat.roughness = 0.7
		m.material_override = mat
	m.position = pos
	_wall_root.add_child(m)
	return m


func _glow(m: MeshInstance3D, color: Color) -> void:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.emission_enabled = true
	mat.emission = color
	mat.emission_energy_multiplier = 1.3
	m.material_override = mat


func _style_mat(id: String) -> StandardMaterial3D:
	if _wall_mats.has(id):
		return _wall_mats[id]
	var def: Dictionary = sim.layout.wall_catalog.get("estilos", {}).get(id, {})
	var mat := StandardMaterial3D.new()
	mat.roughness = 0.85
	var texture := FinishTextures.wall_texture(id)
	if texture != null:
		mat.albedo_texture = texture
		mat.uv1_triplanar = true
		mat.uv1_world_triplanar = true
	else:
		mat.albedo_color = Color(def.get("color", "f3e6d3"))
	_wall_mats[id] = mat
	return mat


# --- Día y noche, selección de segmentos -------------------------------------------------

## 0 = de día, 1 = de noche: apaga o enciende los cristales y las luces.
func set_night(value: float) -> void:
	night = value
	if _glass_mat == null:
		return
	_glass_mat.albedo_color = Color(0.72, 0.87, 0.97, 0.32).lerp(Color(0.1, 0.14, 0.28, 0.6), night)
	_glass_mat.emission_enabled = night > 0.05
	_glass_mat.emission = Color(0.12, 0.17, 0.35) * night
	for entry in _lights:
		var light: OmniLight3D = entry[0]
		if is_instance_valid(light):
			light.light_energy = float(entry[1]) * lerpf(0.35, 1.0, night)


## Segmento de pared bajo un punto de la pantalla ("" si no hay).
func pick_wall(camera: Camera3D, screen_pos: Vector2) -> String:
	var layout := sim.layout
	var origin := camera.project_ray_origin(screen_pos)
	var dir := camera.project_ray_normal(screen_pos)
	var best_t := INF
	var best := ""
	if absf(dir.z) > 0.0001:
		var t := (-0.5 - origin.z) / dir.z
		var p := origin + dir * t
		if t > 0.0 and p.y >= 0.0 and p.y <= H and p.x > -0.5 and p.x < layout.size.x - 0.5 and layout.walls.has("N%d" % roundi(p.x)):
			best_t = t
			best = "N%d" % roundi(p.x)
	if absf(dir.x) > 0.0001:
		var t := (-0.5 - origin.x) / dir.x
		var p := origin + dir * t
		if t > 0.0 and t < best_t and p.y >= 0.0 and p.y <= H and p.z > -0.5 and p.z < layout.size.y - 0.5 and layout.walls.has("O%d" % roundi(p.z)):
			best = "O%d" % roundi(p.z)
	return best


## Marca un segmento de pared (para enseñar sobre cuál se está actuando).
func highlight_wall(key: String) -> void:
	if key == "":
		_highlight.visible = false
		return
	var side := key.substr(0, 1)
	var index := int(key.substr(1))
	(_highlight.mesh as BoxMesh).size = Vector3(1.0, H, 0.26) if side == "N" else Vector3(0.26, H, 1.0)
	_highlight.position = _wpos(side, index, 0.0, H / 2.0, 0.0)
	_highlight.visible = true


# --- Habitaciones ------------------------------------------------------------------------

## Cada habitación: suelo teñido con su color, cinta en el borde y un rótulo en el suelo
## (en rojo si le falta equipo para funcionar).
func _build_rooms() -> void:
	if _room_root == null:
		return
	for child in _room_root.get_children():
		child.queue_free()
	var layout := sim.layout
	for room in layout.rooms:
		var def: Dictionary = layout.room_types.get(room["tipo"], {})
		var color := Color(def.get("color", "cccccc"))
		var rect: Rect2i = room["rect"]
		var center := Vector3(rect.position.x + rect.size.x / 2.0 - 0.5, 0.0, rect.position.y + rect.size.y / 2.0 - 0.5)
		var tint := MeshInstance3D.new()
		var plane := PlaneMesh.new()
		plane.size = Vector2(rect.size.x, rect.size.y)
		tint.mesh = plane
		tint.material_override = _flat(Color(color, 0.22))
		tint.position = center + Vector3(0, 0.008, 0)
		tint.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_room_root.add_child(tint)
		var tape := _flat(Color(color.darkened(0.15), 0.9))
		var x0 := rect.position.x - 0.5
		var x1 := rect.end.x - 0.5
		var z0 := rect.position.y - 0.5
		var z1 := rect.end.y - 0.5
		for edge in [[Vector3((x0 + x1) / 2.0, 0, z0), Vector3(rect.size.x, 0.012, 0.07)], [Vector3((x0 + x1) / 2.0, 0, z1), Vector3(rect.size.x, 0.012, 0.07)],
				[Vector3(x0, 0, (z0 + z1) / 2.0), Vector3(0.07, 0.012, rect.size.y)], [Vector3(x1, 0, (z0 + z1) / 2.0), Vector3(0.07, 0.012, rect.size.y)]]:
			var strip := MeshInstance3D.new()
			var box := BoxMesh.new()
			box.size = edge[1]
			strip.mesh = box
			strip.material_override = tape
			strip.position = edge[0] + Vector3(0, 0.01, 0)
			strip.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			_room_root.add_child(strip)
		var label := Label3D.new()
		var missing := layout.room_missing(room)
		var text: String = def.get("nombre", "").to_upper()
		var warn := not missing.is_empty()
		if warn:
			text += "\nfalta: " + ", ".join(missing).to_lower()
		elif room["tipo"] == "aseos":
			var dirt: int = sim.wc_dirt.get(room["id"], 0)
			var stalls := layout.stall_cells(room).size()
			text += "\n%d puesto%s" % [stalls, "" if stalls == 1 else "s"]
			if dirt >= RestaurantSim.WC_MAX_DIRT:
				text += " · fuera de servicio"
				warn = true
			elif dirt >= RestaurantSim.WC_CLEAN_AT:
				text += " · sucios"
				warn = true
		label.text = text
		label.font_size = 40
		label.pixel_size = 0.006
		label.modulate = color.darkened(0.55) if not warn else Color("b23b3b")
		label.outline_size = 0
		label.shaded = false
		label.rotation = Vector3(-PI / 2.0, PI / 4.0, 0)
		label.position = Vector3(rect.position.x - 0.35 + minf(1.1, rect.size.x / 2.0), 0.03, rect.end.y - 0.7)
		_room_root.add_child(label)


func _flat(color: Color) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	if color.a < 1.0:
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	return mat


# --- Paredes interiores y puertas ------------------------------------------------------

const INNER_HEIGHT := 1.15
const INNER_THICKNESS := 0.16


## Cada pared es un poste con brazos hacia las paredes y puertas vecinas, así que las
## líneas de casillas se ven como una sola pared fina. Las puertas llevan marco de madera.
func _build_inner_walls() -> void:
	if _inner_root == null:
		return
	for child in _inner_root.get_children():
		child.queue_free()
	var layout := sim.layout
	var mat := _style_mat("crema")
	var wood := StandardMaterial3D.new()
	wood.albedo_color = Color("8a5a35")
	wood.roughness = 0.7
	for cell in layout.inner_walls:
		var kind: String = layout.inner_walls[cell]
		var center := Vector3(cell.x, 0.0, cell.y)
		var links := {}
		for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			links[d] = layout.inner_walls.has(cell + d)
		if kind == "pared":
			_inner_box(Vector3(INNER_THICKNESS, INNER_HEIGHT, INNER_THICKNESS), center + Vector3(0, INNER_HEIGHT / 2.0, 0), mat)
			for d in links:
				if links[d]:
					var arm := Vector3(0.5, INNER_HEIGHT, INNER_THICKNESS) if d.x != 0 else Vector3(INNER_THICKNESS, INNER_HEIGHT, 0.5)
					_inner_box(arm, center + Vector3(d.x * 0.25, INNER_HEIGHT / 2.0, d.y * 0.25), mat)
		else:
			# Puerta: dos postes a los lados del hueco y un dintel, a lo largo de la pared.
			var along_x: bool = links[Vector2i(1, 0)] or links[Vector2i(-1, 0)] or not (links[Vector2i(0, 1)] or links[Vector2i(0, -1)])
			var axis := Vector3(1, 0, 0) if along_x else Vector3(0, 0, 1)
			for sign in [-1.0, 1.0]:
				_inner_box(Vector3(0.12, 1.5, 0.12), center + axis * 0.44 * sign + Vector3(0, 0.75, 0), wood)
				var arm_size := Vector3(0.18, INNER_HEIGHT, INNER_THICKNESS) if along_x else Vector3(INNER_THICKNESS, INNER_HEIGHT, 0.18)
				_inner_box(arm_size, center + axis * 0.41 * sign + Vector3(0, INNER_HEIGHT / 2.0, 0), mat)
			var lintel := Vector3(1.0, 0.1, 0.14) if along_x else Vector3(0.14, 0.1, 1.0)
			_inner_box(lintel, center + Vector3(0, 1.45, 0), wood)


func _inner_box(size: Vector3, pos: Vector3, material: Material) -> void:
	var m := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	m.mesh = mesh
	m.material_override = material
	m.position = pos
	_inner_root.add_child(m)
