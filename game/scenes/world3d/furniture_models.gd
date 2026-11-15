class_name FurnitureModels
extends RefCounted
## Modelos 3D de los muebles del catálogo, hechos con piezas sencillas (como los
## personajes). Se usan en el local, en el "fantasma" del modo construcción y en las
## miniaturas del catálogo. El modelo se construye con el mueble en su celda (0, 0) y
## sin girar; el nodo raíz se gira según `rot`.

const WOOD := Color("a0673a")
const DARK_WOOD := Color("7a4a2a")
const CLOTH := Color("f4efe6")
const VELVET := Color("8e3b46")
const POT := Color("c46a3c")
const LEAF := Color("5aa05a")
const WARM_LIGHT := Color("ffd9a0")


## Nodo con el modelo del mueble `def` girado `rot` cuartos de vuelta. Con `ghost`, es
## semitransparente y sin luces (para colocarlo).
static func build(def: Dictionary, rot: int = 0, ghost: bool = false) -> Node3D:
	var root := Node3D.new()
	root.rotation.y = -rot * PI / 2.0
	match def.get("estilo", ""):
		"madera", "elegante":
			_table(root, def, ghost)
		"planta":
			_cyl(root, 0.16, 0.12, 0.3, Vector3(0, 0.15, 0), POT, ghost)
			_sphere(root, 0.24, Vector3(0, 0.45, 0), LEAF, ghost)
			_sphere(root, 0.15, Vector3(0.1, 0.62, 0.05), LEAF.lightened(0.1), ghost)
		"ficus":
			_cyl(root, 0.22, 0.17, 0.4, Vector3(0, 0.2, 0), POT, ghost)
			_cyl(root, 0.04, 0.05, 0.7, Vector3(0, 0.75, 0), DARK_WOOD, ghost)
			_sphere(root, 0.34, Vector3(0, 1.15, 0), LEAF.darkened(0.1), ghost)
			_sphere(root, 0.26, Vector3(0.18, 1.0, 0.12), LEAF, ghost)
			_sphere(root, 0.24, Vector3(-0.16, 1.32, -0.08), LEAF.lightened(0.1), ghost)
		"estanteria":
			var c := Vector3(0.5, 0, 0)
			_box(root, Vector3(1.9, 1.5, 0.42), c + Vector3(0, 0.75, 0), WOOD, ghost)
			for shelf in 3:
				var y := 0.35 + shelf * 0.45
				_box(root, Vector3(1.8, 0.04, 0.44), c + Vector3(0, y - 0.18, 0), DARK_WOOD, ghost)
				for i in 7:
					var colors := [Color("d1495b"), Color("edae49"), Color("00798c"), Color("30638e"), Color("66a182")]
					var h := 0.22 + float((i * 7 + shelf * 3) % 5) * 0.025
					_box(root, Vector3(0.11, h, 0.3), c + Vector3(-0.75 + i * 0.22, y - 0.16 + h / 2.0, 0.04), colors[(i + shelf) % colors.size()], ghost)
		"acuario":
			var c := Vector3(0.5, 0, 0)
			_box(root, Vector3(1.8, 0.5, 0.5), c + Vector3(0, 0.25, 0), DARK_WOOD, ghost)
			var glass := _box(root, Vector3(1.7, 0.6, 0.44), c + Vector3(0, 0.8, 0), Color(0.45, 0.75, 0.95, 0.45), true)
			if not ghost:
				var mat := glass.material_override as StandardMaterial3D
				mat.emission_enabled = true
				mat.emission = Color("3d8fd1")
				mat.emission_energy_multiplier = 0.4
			_box(root, Vector3(1.7, 0.06, 0.44), c + Vector3(0, 0.53, 0), Color("e8d8a8"), ghost)
			for i in 4:
				var fish := Vector3(-0.55 + i * 0.36, 0.72 + (i % 2) * 0.14, -0.05 + (i % 3) * 0.06)
				_box(root, Vector3(0.12, 0.07, 0.04), c + fish, [Color("ff8c42"), Color("ffd23f"), Color("ee4266")][i % 3], ghost)
			_box(root, Vector3(1.76, 0.05, 0.48), c + Vector3(0, 1.12, 0), Color("263238"), ghost)
		"lampara":
			_cyl(root, 0.17, 0.17, 0.04, Vector3(0, 0.02, 0), Color("37474f"), ghost)
			_cyl(root, 0.025, 0.025, 1.3, Vector3(0, 0.67, 0), Color("37474f"), ghost)
			_glow(_cyl(root, 0.14, 0.24, 0.26, Vector3(0, 1.38, 0), WARM_LIGHT, ghost), ghost)
			if not ghost:
				_light(root, Vector3(0, 1.3, 0), 2.6, 0.9)
		"farolillo":
			_box(root, Vector3(0.45, 0.04, 0.45), Vector3(0, 0.5, 0), WOOD, ghost)
			_cyl(root, 0.05, 0.05, 0.5, Vector3(0, 0.25, 0), DARK_WOOD, ghost)
			_box(root, Vector3(0.16, 0.22, 0.16), Vector3(0, 0.63, 0), Color("2b2f3a"), ghost)
			_glow(_box(root, Vector3(0.12, 0.16, 0.12), Vector3(0, 0.63, 0), WARM_LIGHT, ghost), ghost)
			if not ghost:
				_light(root, Vector3(0, 0.7, 0), 1.8, 0.6)
		"inodoro":
			var porcelain := Color("f4f6f7")
			_box(root, Vector3(0.4, 0.5, 0.2), Vector3(0, 0.25, -0.3), porcelain, ghost)
			_cyl(root, 0.2, 0.15, 0.3, Vector3(0, 0.2, -0.05), porcelain, ghost)
			_cyl(root, 0.22, 0.22, 0.04, Vector3(0, 0.37, -0.05), Color("dfe5e8"), ghost)
			_box(root, Vector3(0.1, 0.05, 0.05), Vector3(0, 0.53, -0.4), Color("b0bec5"), ghost)
		"lavabo":
			_box(root, Vector3(0.7, 0.55, 0.4), Vector3(0, 0.275, -0.25), Color("e9ecef"), ghost)
			_box(root, Vector3(0.6, 0.06, 0.34), Vector3(0, 0.58, -0.25), Color("fbfbfb"), ghost)
			_box(root, Vector3(0.05, 0.14, 0.05), Vector3(0, 0.68, -0.38), Color("b0bec5"), ghost)
			_box(root, Vector3(0.5, 0.45, 0.04), Vector3(0, 1.05, -0.46), Color(0.78, 0.9, 0.96, 0.9), true if ghost else false)
		"perchero":
			_cyl(root, 0.18, 0.2, 0.06, Vector3(0, 0.03, 0), DARK_WOOD, ghost)
			_cyl(root, 0.03, 0.03, 1.6, Vector3(0, 0.83, 0), DARK_WOOD, ghost)
			for i in 3:
				var coat: Color = [Color("37474f"), Color("8e3b46"), Color("5a7d9a")][i]
				var a := i * TAU / 3.0
				_box(root, Vector3(0.05, 0.05, 0.28), Vector3(sin(a) * 0.14, 1.5, cos(a) * 0.14), DARK_WOOD, ghost)
				_box(root, Vector3(0.16, 0.5, 0.1), Vector3(sin(a) * 0.26, 1.2, cos(a) * 0.26), coat, ghost)
		"barra_bar":
			_box(root, Vector3(0.98, 0.9, 0.98), Vector3(0, 0.45, 0), DARK_WOOD, ghost)
			_box(root, Vector3(1.0, 0.07, 1.0), Vector3(0, 0.93, 0), Color("c9a15a"), ghost)
			_box(root, Vector3(0.98, 0.04, 0.3), Vector3(0, 0.99, 0.25), Color("e9d9b0"), ghost)
		"taburete":
			_cyl(root, 0.2, 0.2, 0.07, Vector3(0, 0.62, 0), VELVET, ghost)
			for i in 4:
				var a := i * TAU / 4.0 + PI / 4.0
				_box(root, Vector3(0.04, 0.6, 0.04), Vector3(sin(a) * 0.14, 0.3, cos(a) * 0.14), Color("37474f"), ghost)
		"ordenador":
			# Mesa con ordenador mirando a la silla, que está en la casilla de uso (a la izquierda).
			_box(root, Vector3(0.8, 0.06, 0.8), Vector3(0, 0.46, 0), WOOD.lightened(0.15), ghost)
			for corner in [Vector3(-0.33, 0, -0.33), Vector3(0.33, 0, -0.33), Vector3(-0.33, 0, 0.33), Vector3(0.33, 0, 0.33)]:
				_box(root, Vector3(0.06, 0.44, 0.06), corner + Vector3(0, 0.22, 0), DARK_WOOD, ghost)
			_box(root, Vector3(0.05, 0.3, 0.46), Vector3(0.12, 0.68, 0), Color("2a2d34"), ghost)
			var screen := _box(root, Vector3(0.03, 0.25, 0.4), Vector3(0.095, 0.68, 0), Color("7fc8f0"), ghost)
			if not ghost:
				var mat := screen.material_override as StandardMaterial3D
				mat.emission_enabled = true
				mat.emission = Color("7fc8f0")
				mat.emission_energy_multiplier = 0.8
			_box(root, Vector3(0.08, 0.16, 0.08), Vector3(0.12, 0.55, 0), Color("2a2d34"), ghost)
			_box(root, Vector3(0.12, 0.02, 0.3), Vector3(-0.15, 0.5, 0), Color("dfe3e8"), ghost)
			_box(root, Vector3(0.38, 0.06, 0.38), Vector3(-1, 0.16, 0), Color("3b4a63"), ghost)
			_box(root, Vector3(0.06, 0.4, 0.38), Vector3(-1.19, 0.36, 0), Color("3b4a63"), ghost)
		"colgante":
			_cyl(root, 0.012, 0.012, 1.0, Vector3(0, 2.05, 0), Color("37474f"), ghost)
			_cyl(root, 0.1, 0.24, 0.2, Vector3(0, 1.5, 0), Color("2b2f3a"), ghost)
			_glow(_sphere(root, 0.1, Vector3(0, 1.42, 0), WARM_LIGHT, ghost), ghost)
			if not ghost:
				_light(root, Vector3(0, 1.3, 0), 3.4, 1.0)
		"sofa":
			var c := Vector3(0.5, 0, 0)
			var fabric := Color("3d6b7a")
			_box(root, Vector3(1.8, 0.3, 0.8), c + Vector3(0, 0.15, 0), fabric.darkened(0.2), ghost)
			for i in 2:
				_box(root, Vector3(0.84, 0.14, 0.6), c + Vector3(-0.44 + i * 0.88, 0.37, 0.07), fabric, ghost)
			_box(root, Vector3(1.8, 0.5, 0.2), c + Vector3(0, 0.55, -0.3), fabric.darkened(0.1), ghost)
			for sign in [-1.0, 1.0]:
				_box(root, Vector3(0.14, 0.42, 0.8), c + Vector3(sign * 0.83, 0.3, 0), fabric.darkened(0.15), ghost)
		"macetero":
			var c := Vector3(0.5, 0, 0)
			_box(root, Vector3(1.8, 0.32, 0.45), c + Vector3(0, 0.16, 0), WOOD.darkened(0.15), ghost)
			for i in 4:
				_sphere(root, 0.26 - (i % 2) * 0.03, c + Vector3(-0.66 + i * 0.44, 0.52 + (i % 2) * 0.05, 0), LEAF.darkened(0.05 * (i % 3)), ghost)
		_:
			_box(root, Vector3(0.8, 0.8, 0.8), Vector3(0, 0.4, 0), Color("b0bec5"), ghost)
	return root


## Mesa con sus sillas alrededor (respaldo hacia fuera).
static func _table(root: Node3D, def: Dictionary, ghost: bool) -> void:
	var elegant: bool = def.get("estilo", "") == "elegante"
	_box(root, Vector3(0.1, 0.4, 0.1), Vector3(0, 0.2, 0), DARK_WOOD, ghost)
	_box(root, Vector3(0.72, 0.06, 0.72), Vector3(0, 0.42, 0), WOOD, ghost)
	if elegant:
		# Mantel blanco que cae por los lados.
		_box(root, Vector3(0.8, 0.02, 0.8), Vector3(0, 0.46, 0), Color.WHITE, ghost)
		_box(root, Vector3(0.82, 0.22, 0.82), Vector3(0, 0.36, 0), Color("f7f7f2"), ghost)
		_glow(_cyl(root, 0.03, 0.03, 0.12, Vector3(0, 0.53, 0), WARM_LIGHT, ghost), ghost)
	else:
		_box(root, Vector3(0.56, 0.01, 0.56), Vector3(0, 0.455, 0), CLOTH, ghost)
	var chair := VELVET if elegant else WOOD.darkened(0.25)
	for offset in RestaurantLayout.SEAT_OFFSETS[int(def.get("plazas", 2))]:
		var s := Vector3(offset.x, 0, offset.y)
		var away := s.normalized()
		_box(root, Vector3(0.38, 0.16, 0.38), s + Vector3(0, 0.08, 0), chair, ghost)
		var back := Vector3(0.05, 0.4, 0.38) if absf(away.x) > 0.5 else Vector3(0.38, 0.4, 0.05)
		_box(root, back, s + away * 0.17 + Vector3(0, 0.36, 0), chair, ghost)


static func _material(color: Color, ghost: bool) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = 0.7
	if ghost or color.a < 1.0:
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		if ghost:
			mat.albedo_color = Color(color, minf(color.a, 0.6))
	return mat


static func _box(root: Node3D, size: Vector3, pos: Vector3, color: Color, ghost: bool) -> MeshInstance3D:
	var mesh := BoxMesh.new()
	mesh.size = size
	return _add(root, mesh, pos, color, ghost)


static func _cyl(root: Node3D, top: float, bottom: float, height: float, pos: Vector3, color: Color, ghost: bool) -> MeshInstance3D:
	var mesh := CylinderMesh.new()
	mesh.top_radius = top
	mesh.bottom_radius = bottom
	mesh.height = height
	mesh.radial_segments = 16
	return _add(root, mesh, pos, color, ghost)


static func _sphere(root: Node3D, radius: float, pos: Vector3, color: Color, ghost: bool) -> MeshInstance3D:
	var mesh := SphereMesh.new()
	mesh.radius = radius
	mesh.height = radius * 2.0
	mesh.radial_segments = 16
	mesh.rings = 8
	return _add(root, mesh, pos, color, ghost)


static func _add(root: Node3D, mesh: Mesh, pos: Vector3, color: Color, ghost: bool) -> MeshInstance3D:
	var m := MeshInstance3D.new()
	m.mesh = mesh
	m.material_override = _material(color, ghost)
	m.position = pos
	root.add_child(m)
	return m


## Hace que una pieza brille (pantallas de lámpara, velas...).
static func _glow(m: MeshInstance3D, ghost: bool) -> void:
	if ghost:
		return
	var mat := m.material_override as StandardMaterial3D
	mat.emission_enabled = true
	mat.emission = WARM_LIGHT
	mat.emission_energy_multiplier = 1.2


static func _light(root: Node3D, pos: Vector3, reach: float, energy: float) -> void:
	var light := OmniLight3D.new()
	light.light_color = WARM_LIGHT
	light.omni_range = reach
	light.light_energy = energy
	light.position = pos
	light.set_meta("base", energy)
	light.add_to_group("luz_ambiente")
	root.add_child(light)
