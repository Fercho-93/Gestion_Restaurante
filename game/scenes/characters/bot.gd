class_name Bot
extends Node3D
## Personaje 3D del juego, con el estilo del gestor (docs/arte/personaje_referencia.png):
## cuerpo blanco redondeado, visor oscuro con ojos luminosos y manos y pies ovalados.
## Se construye con formas básicas y se anima por código. Mira hacia -Z.

enum Role { GESTOR, CAMARERO, COCINERO, CLIENTE }
enum Pose { DE_PIE, ANDANDO, SENTADO, TRABAJANDO }
enum Eyes { FELIZ, NORMAL, ENFADADO, CERRADOS }

const WHITE := Color(0.96, 0.95, 0.93)
const ACCENTS := [Color("e05a5a"), Color("4f8fdb"), Color("58b368"), Color("e0a23b"), Color("9b6fd1"), Color("e07fb1"), Color("3fb3b0")]
## Altura de la silla: cuánto se eleva el personaje al sentarse.
const SEAT_HEIGHT := 0.16
const FOOT_Z := -0.03

## Mallas, materiales y texturas compartidos por todos los personajes.
static var _res: Dictionary = {}

var role := Role.CLIENTE
var pose := Pose.DE_PIE
var eyes := Eyes.FELIZ
var carrying := false
var eating := false
var waving := false
## Entidad de la simulación que representa (CustomerGroup, StaffMember o Manager).
var entity = null
## En un grupo de clientes, qué miembro es.
var member_index := 0

var _rig: Node3D
var _torso: Node3D
var _hand_l: Node3D
var _hand_r: Node3D
var _foot_l: MeshInstance3D
var _foot_r: MeshInstance3D
var _eyes_mat: StandardMaterial3D
var _hand_plate: Node3D
var _table_plate: Node3D
var _thought: Node3D
var _thought_bg: Sprite3D
var _thought_icon: Sprite3D
var _thought_text: Label3D
var _thought_shown := ""
var _walk_t := 0.0
var _idle_t := 0.0
var _blink_left := 0.0
var _next_blink := 3.0
var _target_yaw := 0.0
var _shown_eyes := -1


func setup(bot_role: Role, seed_value: int) -> void:
	role = bot_role
	var r := resources()
	var accent: Color = ACCENTS[seed_value % ACCENTS.size()]
	var body_color := WHITE.lerp(accent, 0.3) if role == Role.CLIENTE else WHITE
	_idle_t = float(seed_value % 17)
	_next_blink = 1.0 + float(seed_value % 5)

	_rig = Node3D.new()
	add_child(_rig)
	_torso = Node3D.new()
	_rig.add_child(_torso)
	_part(_torso, r["capsule"], material(body_color), Vector3(0, 0.38, 0), Vector3(1, 1, 0.86))
	_part(_torso, r["sphere"], r["visor"], Vector3(0, 0.56, -0.152), Vector3(0.3, 0.18, 0.09))
	var eyes_mesh := _part(_torso, r["eyes_quad"], null, Vector3(0, 0.562, -0.2), Vector3.ONE)
	eyes_mesh.rotation.y = PI
	_eyes_mat = (r["eyes_material"] as StandardMaterial3D).duplicate()
	eyes_mesh.material_override = _eyes_mat

	_hand_l = _hand(-1.0, body_color)
	_hand_r = _hand(1.0, body_color)
	_foot_l = _part(_rig, r["sphere"], material(body_color), Vector3(-0.09, 0.035, FOOT_Z), Vector3(0.12, 0.07, 0.17))
	_foot_r = _part(_rig, r["sphere"], material(body_color), Vector3(0.09, 0.035, FOOT_Z), Vector3(0.12, 0.07, 0.17))

	_hand_plate = Node3D.new()
	_hand_plate.position = Vector3(0.17, 0.44, -0.24)
	_add_plate(_hand_plate, accent)
	_torso.add_child(_hand_plate)
	_table_plate = Node3D.new()
	_table_plate.position = Vector3(0, 0.46 - SEAT_HEIGHT, -0.4)
	_add_plate(_table_plate, accent)
	add_child(_table_plate)

	if role == Role.CAMARERO or role == Role.COCINERO:
		scale = Vector3.ONE * 1.15
	match role:
		Role.COCINERO:
			_part(_torso, r["cylinder"], material(Color.WHITE), Vector3(0, 0.76, 0), Vector3(0.24, 0.13, 0.24))
			_part(_torso, r["sphere"], material(Color.WHITE), Vector3(0, 0.86, 0), Vector3(0.32, 0.17, 0.32))
			_part(_torso, r["torus"], material(Color("e05a5a")), Vector3(0, 0.47, 0), Vector3(0.95, 0.5, 0.82))
		Role.CAMARERO:
			_part(_torso, r["sphere"], material(Color("23242b")), Vector3(-0.035, 0.465, -0.18), Vector3(0.07, 0.05, 0.03))
			_part(_torso, r["sphere"], material(Color("23242b")), Vector3(0.035, 0.465, -0.18), Vector3(0.07, 0.05, 0.03))
			_part(_torso, r["box"], material(Color("2b2d36")), Vector3(0, 0.24, -0.176), Vector3(0.3, 0.2, 0.02))
		Role.GESTOR:
			scale = Vector3.ONE * 1.35
		Role.CLIENTE:
			scale = Vector3.ONE * (1.05 + float(seed_value % 4) * 0.04)
			_add_accessory(seed_value / ACCENTS.size() % 4, accent)

	_thought = Node3D.new()
	_thought.position = Vector3(0, 1.05, 0)
	_thought.visible = false
	add_child(_thought)
	_thought_bg = Sprite3D.new()
	_thought_bg.texture = r["thought_bubble"]
	_thought_bg.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_thought_bg.no_depth_test = true
	_thought_bg.render_priority = 1
	_thought_bg.pixel_size = 0.0042
	_thought.add_child(_thought_bg)
	_thought_icon = Sprite3D.new()
	_thought_icon.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_thought_icon.no_depth_test = true
	_thought_icon.render_priority = 2
	_thought_icon.pixel_size = 0.0042
	_thought_icon.offset = Vector2(0, 8)
	_thought.add_child(_thought_icon)
	_thought_text = Label3D.new()
	_thought_text.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_thought_text.no_depth_test = true
	_thought_text.render_priority = 2
	_thought_text.font_size = 64
	_thought_text.outline_size = 0
	_thought_text.pixel_size = 0.0042
	_thought_text.offset = Vector2(0, 8)
	_thought.add_child(_thought_text)
	_update_eyes(0.0)


## Bocadillo de pensamiento. `icon`: "" (ninguno), un icono dibujado ("reloj",
## "cubiertos", "corazon", "tarta", "lapiz") o un texto corto ("?", "!", "€", "¡Oiga!").
## `tint`: el color del bocadillo según el ánimo.
func set_thought(icon: String, tint: Color = Color.WHITE) -> void:
	_thought.visible = icon != ""
	_thought_bg.modulate = Color.WHITE.lerp(tint, 0.45)
	if icon == _thought_shown:
		return
	_thought_shown = icon
	var icons: Dictionary = resources()["thought_icons"]
	_thought_icon.visible = icons.has(icon)
	_thought_text.visible = not icons.has(icon) and icon != ""
	if icons.has(icon):
		_thought_icon.texture = icons[icon]
	else:
		_thought_text.text = icon
		_thought_text.modulate = Color("c62828") if icon.begins_with("!") or icon.begins_with("¡") else Color("263238")
		_thought_text.font_size = 40 if icon.length() > 2 else 64
		_thought_bg.scale = Vector3(1.6, 1.0, 1.0) if icon.length() > 2 else Vector3.ONE
	if icons.has(icon):
		_thought_bg.scale = Vector3.ONE


## Los niños son más pequeños.
func make_child() -> void:
	scale = Vector3.ONE * 0.72


## Gira poco a poco para mirar en la dirección indicada (en el plano del suelo).
func face_direction(dir: Vector3) -> void:
	if Vector2(dir.x, dir.z).length() > 0.01:
		_target_yaw = atan2(-dir.x, -dir.z)


func _process(delta: float) -> void:
	var game := get_node_or_null("/root/Game")
	var game_speed := float(game.clock.speed) if game != null else 1.0
	_idle_t += delta
	_walk_t += delta * game_speed
	_animate()
	_update_eyes(delta)
	rotation.y = lerp_angle(rotation.y, _target_yaw, minf(1.0, delta * 10.0))


func _animate() -> void:
	var t := _walk_t
	var lift := 0.0
	var roll := 0.0
	var hand_l := 0.0
	var hand_r := 0.0
	var foot_swing := 0.0
	var breathing := 1.0 + sin(_idle_t * 2.2) * 0.012
	_rig.position.y = SEAT_HEIGHT if pose == Pose.SENTADO else 0.0
	match pose:
		Pose.ANDANDO:
			var s := sin(t * 9.0)
			lift = absf(s) * 0.035
			roll = s * 0.09
			hand_l = s * 0.6
			hand_r = -s * 0.6
			foot_swing = s * 0.07
			breathing = 1.0
		Pose.TRABAJANDO:
			lift = absf(sin(t * 6.0)) * 0.01
			hand_l = 0.9 + sin(t * 10.0) * 0.35
			hand_r = 0.9 - sin(t * 10.0) * 0.35
		Pose.SENTADO:
			hand_l = 0.5
			hand_r = 0.5
			if eating:
				hand_r = 0.9 + sin(t * 5.0) * 0.4
	if carrying:
		hand_r = 1.3
	_torso.position.y = lift
	_torso.rotation.z = roll
	_torso.scale.y = breathing
	_hand_l.rotation = Vector3(hand_l, 0, 0)
	_hand_r.rotation = Vector3(hand_r, 0, 0)
	if waving:
		_hand_r.rotation = Vector3(0, 0, 2.4 + sin(_idle_t * 9.0) * 0.35)
	var seated := pose == Pose.SENTADO
	_foot_l.position.z = (-0.12 if seated else FOOT_Z) + foot_swing
	_foot_r.position.z = (-0.12 if seated else FOOT_Z) - foot_swing
	_hand_plate.visible = carrying
	_table_plate.visible = seated and eating


func _update_eyes(delta: float) -> void:
	_next_blink -= delta
	if _next_blink <= 0.0:
		_blink_left = 0.12
		_next_blink = randf_range(2.5, 5.0)
	_blink_left -= delta
	var shown := eyes
	if _blink_left > 0.0 and eyes != Eyes.ENFADADO:
		shown = Eyes.CERRADOS
	if shown != _shown_eyes:
		_shown_eyes = shown
		_eyes_mat.albedo_texture = resources()["eye_textures"][shown]


func _hand(side: float, color: Color) -> Node3D:
	var pivot := Node3D.new()
	pivot.position = Vector3(0.2 * side, 0.47, 0)
	_torso.add_child(pivot)
	_part(pivot, resources()["sphere"], material(color), Vector3(0.045 * side, -0.11, 0), Vector3(0.11, 0.15, 0.1))
	return pivot


func _add_plate(parent: Node3D, food: Color) -> void:
	var r := resources()
	_part(parent, r["cylinder"], material(Color.WHITE), Vector3.ZERO, Vector3(0.2, 0.015, 0.2))
	_part(parent, r["sphere"], material(food.lerp(Color("d9a35b"), 0.5)), Vector3(0, 0.02, 0), Vector3(0.11, 0.05, 0.11))


## Complementos de los clientes para que no todos sean iguales.
func _add_accessory(kind: int, color: Color) -> void:
	var r := resources()
	match kind:
		1: # Gorra
			_part(_torso, r["sphere"], material(color), Vector3(0, 0.69, 0), Vector3(0.36, 0.16, 0.33))
			_part(_torso, r["box"], material(color.darkened(0.2)), Vector3(0, 0.69, -0.18), Vector3(0.2, 0.015, 0.12))
		2: # Lazo
			_part(_torso, r["sphere"], material(color), Vector3(0.09, 0.73, -0.02), Vector3(0.09, 0.07, 0.05))
			_part(_torso, r["sphere"], material(color), Vector3(0.16, 0.71, -0.02), Vector3(0.09, 0.07, 0.05))
		3: # Bufanda
			_part(_torso, r["torus"], material(color), Vector3(0, 0.47, 0), Vector3(0.95, 0.55, 0.82))


func _part(parent: Node3D, mesh: Mesh, mat: Material, pos: Vector3, size: Vector3) -> MeshInstance3D:
	var m := MeshInstance3D.new()
	m.mesh = mesh
	m.material_override = mat
	m.position = pos
	m.scale = size
	parent.add_child(m)
	return m


## Material liso con aspecto de vinilo mate, reutilizado por color.
static func material(color: Color) -> StandardMaterial3D:
	var r := resources()
	var key := color.to_html()
	if not r["materials"].has(key):
		var mat := StandardMaterial3D.new()
		mat.albedo_color = color
		mat.roughness = 0.5
		mat.rim_enabled = true
		mat.rim = 0.25
		r["materials"][key] = mat
	return r["materials"][key]


static func resources() -> Dictionary:
	if not _res.is_empty():
		return _res
	var capsule := CapsuleMesh.new()
	capsule.radius = 0.2
	capsule.height = 0.62
	var sphere := SphereMesh.new()
	sphere.radial_segments = 24
	sphere.rings = 12
	var cylinder := CylinderMesh.new()
	cylinder.top_radius = 0.5
	cylinder.bottom_radius = 0.5
	cylinder.height = 1.0
	var torus := TorusMesh.new()
	torus.inner_radius = 0.17
	torus.outer_radius = 0.23
	var quad := QuadMesh.new()
	quad.size = Vector2(0.25, 0.1)
	var visor := StandardMaterial3D.new()
	visor.albedo_color = Color(0.09, 0.09, 0.11)
	visor.roughness = 0.2
	visor.metallic = 0.3
	var eyes_material := StandardMaterial3D.new()
	eyes_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	eyes_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	eyes_material.albedo_color = Color(1.0, 0.86, 0.55)
	var textures := {}
	for kind in Eyes.values():
		textures[kind] = _eye_texture(kind)
	var thought_icons := {}
	for icon in ["reloj", "cubiertos", "corazon", "tarta", "lapiz"]:
		thought_icons[icon] = _icon_texture(icon)
	_res = {
		"capsule": capsule, "sphere": sphere, "cylinder": cylinder, "torus": torus,
		"box": BoxMesh.new(), "eyes_quad": quad, "visor": visor,
		"eyes_material": eyes_material, "eye_textures": textures, "materials": {},
		"thought_bubble": _bubble_texture(), "thought_icons": thought_icons,
	}
	return _res


## Bocadillo de pensamiento: nube blanca con borde y dos burbujitas debajo.
static func _bubble_texture() -> ImageTexture:
	var img := Image.create(128, 128, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var blobs := [[Vector2(64, 54), 46.0], [Vector2(40, 104), 9.0], [Vector2(28, 120), 5.0]]
	for x in 128:
		for y in 128:
			var p := Vector2(x, y)
			for b in blobs:
				var d: float = p.distance_to(b[0]) - b[1]
				if d <= 0.0:
					var border := d > -4.0
					img.set_pixel(x, y, Color(0.55, 0.58, 0.62) if border else Color.WHITE)
					break
	return ImageTexture.create_from_image(img)


## Iconos de los bocadillos, dibujados con formas simples (la fuente web no trae emojis).
static func _icon_texture(kind: String) -> ImageTexture:
	var img := Image.create(96, 96, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	for x in 96:
		for y in 96:
			var c := _icon_pixel(kind, Vector2(x - 48, y - 48))
			if c.a > 0.0:
				img.set_pixel(x, y, c)
	return ImageTexture.create_from_image(img)


static func _icon_pixel(kind: String, p: Vector2) -> Color:
	var dark := Color("37474f")
	match kind:
		"reloj":
			var r := p.length()
			if r <= 30.0 and r >= 24.0:
				return dark
			if _near_segment(p, Vector2.ZERO, Vector2(0, -18), 3.5) or _near_segment(p, Vector2.ZERO, Vector2(13, 0), 3.5):
				return dark
			if r < 24.0:
				return Color("fff8e1")
		"cubiertos":
			# Tenedor (izquierda) y cuchillo (derecha).
			if _near_segment(p, Vector2(-12, -6), Vector2(-12, 30), 3.5):
				return dark
			for tine in [-19.0, -12.0, -5.0]:
				if _near_segment(p, Vector2(tine, -30), Vector2(tine, -8), 2.5):
					return dark
			if _near_segment(p, Vector2(-19, -8), Vector2(-5, -8), 3.0):
				return dark
			if _near_segment(p, Vector2(13, -30), Vector2(13, 30), 3.5) or (p.x > 13 and p.x < 20 and p.y > -30 and p.y < 2):
				return dark
		"corazon":
			var q := Vector2(p.x, -p.y - 4.0) / 26.0
			var f := pow(q.x * q.x + q.y * q.y - 1.0, 3.0) - q.x * q.x * pow(q.y, 3.0)
			if f <= 0.0:
				return Color("e53935")
		"tarta":
			if p.y > 0 and p.y < 26 and absf(p.x) < 28:
				return Color("f48fb1") if p.y > 8 else Color("fff3e0")
			if _near_segment(p, Vector2(0, -2), Vector2(0, -20), 3.0):
				return Color("fdd835")
			if p.distance_to(Vector2(0, -26)) < 5.0:
				return Color("ff7043")
		"lapiz":
			if _near_segment(p, Vector2(-22, 22), Vector2(16, -16), 7.0):
				return Color("fbc02d") if p.distance_to(Vector2(-22, 22)) > 10.0 else Color("5d4037")
			if _near_segment(p, Vector2(16, -16), Vector2(24, -24), 7.0):
				return Color("e57373")
	return Color(0, 0, 0, 0)


static func _near_segment(p: Vector2, a: Vector2, b: Vector2, width: float) -> bool:
	var ab := b - a
	var t := clampf((p - a).dot(ab) / ab.length_squared(), 0.0, 1.0)
	return p.distance_to(a + ab * t) <= width


## Dibuja los dos ojos de una expresión en una textura (blanco sobre transparente).
static func _eye_texture(kind: Eyes) -> ImageTexture:
	var w := 96
	var h := 40
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	for x in w:
		for y in h:
			var a := maxf(_eye_alpha(kind, x - 24.0, y - 20.0, -1.0), _eye_alpha(kind, x - 72.0, y - 20.0, 1.0))
			if a > 0.0:
				img.set_pixel(x, y, Color(1, 1, 1, a))
	return ImageTexture.create_from_image(img)


static func _eye_alpha(kind: Eyes, dx: float, dy: float, side: float) -> float:
	match kind:
		Eyes.FELIZ: # Arco ^, como en el dibujo original.
			if dy - 7.0 > -3.0:
				return 0.0
			return clampf(1.0 - absf(Vector2(dx, dy - 7.0).length() - 12.0) / 4.0, 0.0, 1.0)
		Eyes.NORMAL:
			var v := pow(dx / 8.0, 2) + pow(dy / 11.0, 2)
			return clampf((1.0 - v) * 4.0, 0.0, 1.0)
		Eyes.ENFADADO: # Ceja inclinada hacia dentro y ojo pequeño.
			var brow := clampf(1.0 - absf(dy + 4.0 + side * dx * 0.4) / 2.5, 0.0, 1.0) if absf(dx) < 11.0 else 0.0
			var eye := clampf((1.0 - (pow(dx / 4.0, 2) + pow((dy - 6.0) / 5.0, 2))) * 4.0, 0.0, 1.0)
			return maxf(brow, eye)
		Eyes.CERRADOS:
			return clampf(1.0 - absf(dy - 2.0) / 2.0, 0.0, 1.0) if absf(dx) < 10.0 else 0.0
	return 0.0
