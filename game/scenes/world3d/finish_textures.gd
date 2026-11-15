class_name FinishTextures
extends RefCounted
## Texturas de suelos, paredes y cuadros dibujadas por código (sin ficheros de imagen).
## Cada suelo es una baldosa que se repite por casilla; las paredes usan 1 unidad = 1 casilla.

const SIZE := 128
static var _cache := {}


static func floor_texture(id: String) -> ImageTexture:
	return _cached("f_" + id, func(): return _floor_image(id))


static func wall_texture(id: String) -> ImageTexture:
	return _cached("w_" + id, func(): return _wall_image(id))


static func art_texture(id: String) -> ImageTexture:
	return _cached("a_" + id, func(): return _art_image(id))


static func _cached(key: String, make: Callable) -> ImageTexture:
	if not _cache.has(key):
		var img: Image = make.call()
		_cache[key] = ImageTexture.create_from_image(img) if img != null else null
	return _cache[key]


# --- Suelos ------------------------------------------------------------------------------

static func _floor_image(id: String) -> Image:
	var img := Image.create(SIZE, SIZE, false, Image.FORMAT_RGBA8)
	var grain := _noise(7, 0.03)
	var fine := _noise(11, 0.35)
	match id:
		"madera_natural":
			_planks(img, grain, fine, 4, [Color("a36b3c"), Color("98602f"), Color("ad7745"), Color("8f5a2e")], Color("5e3a1c"), 0.5)
		"tarima":
			_planks(img, grain, fine, 3, [Color("d8b98a"), Color("ccae7e"), Color("dfc294"), Color("d2b284")], Color("b8996a"), 0.25)
		"microcemento":
			for y in SIZE:
				for x in SIZE:
					var n := grain.get_pixel(x, y).r - 0.5
					var f := fine.get_pixel(x, y).r - 0.5
					var v := 0.72 + n * 0.16 + f * 0.05
					img.set_pixel(x, y, Color(v, v + 0.01, v + 0.025))
		"gres":
			var veins := _noise(23, 0.02)
			for y in SIZE:
				for x in SIZE:
					var n := veins.get_pixel(x, y).r
					var vein := 1.0 - smoothstep(0.0, 0.05, absf(n - 0.5))
					var v := 0.92 - vein * 0.13 + (fine.get_pixel(x, y).r - 0.5) * 0.03
					var c := Color(v, v - 0.005, v - 0.02)
					if x % 64 < 2 or y % 64 < 2:  # junta entre baldosas
						c = Color("c9c6bf")
					img.set_pixel(x, y, c)
		"cocina":
			for y in SIZE:
				for x in SIZE:
					var tile := Vector2i(x / 32, y / 32)
					var tone := 0.97 + float(((tile.x * 7 + tile.y * 13) % 5)) * 0.012
					var c := Color("c7dde0") * tone
					c.a = 1.0
					if x % 32 < 2 or y % 32 < 2:
						c = Color("9fb4b8")
					img.set_pixel(x, y, c)
		"oficina":
			for y in SIZE:
				for x in SIZE:
					var f := fine.get_pixel(x, y).r - 0.5
					var base := Color("5d6b82")
					var v := 1.0 + f * 0.35
					var c := Color(base.r * v, base.g * v, base.b * v)
					if x % 64 == 0 or y % 64 == 0:
						c = c.darkened(0.2)
					img.set_pixel(x, y, c)
		_:  # vinílico: baldosas crema en damero suave
			for y in SIZE:
				for x in SIZE:
					var odd := ((x / 64) + (y / 64)) % 2 == 1
					var base := Color("e6dcc8") if odd else Color("ded3bd")
					var f := (fine.get_pixel(x, y).r - 0.5) * 0.05
					var c := Color(base.r + f, base.g + f, base.b + f)
					if x % 64 < 1 or y % 64 < 1:
						c = c.darkened(0.08)
					img.set_pixel(x, y, c)
	return img


## Tablas que corren a lo ancho, con juntas de testa alternadas.
static func _planks(img: Image, grain: Image, fine: Image, count: int, palette: Array, joint: Color, grain_strength: float) -> void:
	var h := SIZE / count
	for y in SIZE:
		var row := y / h
		var base: Color = palette[row % palette.size()]
		var shift := (row * 53) % SIZE
		for x in SIZE:
			var n := grain.get_pixel((x + shift) % SIZE, (y * 3) % SIZE).r - 0.5
			var f := fine.get_pixel(x, y).r - 0.5
			var v := 1.0 + n * grain_strength * 0.6 + f * 0.05
			var c := Color(base.r * v, base.g * v, base.b * v)
			if y % h == 0 or (x + shift) % SIZE == 0:
				c = joint
			img.set_pixel(x, y, c)


# --- Paredes -----------------------------------------------------------------------------

static func _wall_image(id: String) -> Image:
	var img := Image.create(SIZE, SIZE, false, Image.FORMAT_RGBA8)
	var fine := _noise(31, 0.4)
	match id:
		"ladrillo":
			var rows := 8
			var h := SIZE / rows
			for y in SIZE:
				var row := y / h
				var offset := 0 if row % 2 == 0 else 16
				for x in SIZE:
					var bx := (x + offset) % 32
					var brick := Vector2i((x + offset) / 32, row)
					var tone := 0.88 + float((brick.x * 5 + brick.y * 11) % 7) * 0.035
					var base := Color("b5654a")
					var f := (fine.get_pixel(x, y).r - 0.5) * 0.16
					var c := Color(base.r * tone + f, base.g * tone + f, base.b * tone + f)
					if y % h < 2 or bx < 2:
						c = Color("d9cfc2")
					img.set_pixel(x, y, c)
		"azulejo":
			for y in SIZE:
				for x in SIZE:
					var c := Color("f4f6f7")
					var f := (fine.get_pixel(x, y).r - 0.5) * 0.03
					c = Color(c.r + f, c.g + f, c.b + f)
					if x % 16 < 1 or y % 16 < 1:
						c = Color("cfd6d9")
					img.set_pixel(x, y, c)
		"madera":
			for y in SIZE:
				for x in SIZE:
					var slat := x / 16
					var tone := 0.9 + float((slat * 7) % 5) * 0.045
					var base := Color("a8764a")
					var f := (fine.get_pixel(x, (y / 4) % SIZE).r - 0.5) * 0.1
					var c := Color(base.r * tone + f, base.g * tone + f, base.b * tone + f)
					if x % 16 < 2:
						c = Color("5e3a1c")
					img.set_pixel(x, y, c)
		_:
			return null
	return img


# --- Cuadros -----------------------------------------------------------------------------

static func _art_image(id: String) -> Image:
	var w := 96
	var h := 72
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(id)
	match id:
		"cuadro_paisaje":
			for y in h:
				var t := float(y) / h
				var sky := Color("7fb2e5").lerp(Color("f6d3a0"), t * 1.4)
				for x in w:
					img.set_pixel(x, y, sky)
			img.fill_rect(Rect2i(0, 0, 0, 0), Color.WHITE)
			_disc(img, Vector2(66, 28), 9.0, Color("ffe9a8"))
			for x in w:
				var hill1 := 46.0 + sin(x * 0.07) * 7.0
				var hill2 := 54.0 + sin(x * 0.11 + 2.0) * 5.0
				for y in range(int(hill1), h):
					img.set_pixel(x, y, Color("5b8c6a"))
				for y in range(int(hill2), h):
					img.set_pixel(x, y, Color("3f6b4f"))
		"cuadro_abstracto":
			img.fill(Color("f4ecdc"))
			var palette := [Color("d1495b"), Color("edae49"), Color("00798c"), Color("30638e"), Color("1d3557")]
			for i in 9:
				var c: Color = palette[rng.randi() % palette.size()]
				if i % 2 == 0:
					img.fill_rect(Rect2i(rng.randi_range(0, w - 30), rng.randi_range(0, h - 24), rng.randi_range(14, 34), rng.randi_range(10, 28)), c)
				else:
					_disc(img, Vector2(rng.randf_range(10, w - 10), rng.randf_range(10, h - 10)), rng.randf_range(6, 15), c)
		"fotos":
			img.fill(Color(0, 0, 0, 0))
			var tones := [Color("c9b79c"), Color("9db4c0"), Color("d4a5a5")]
			for i in 3:
				var x0 := 2 + i * 31
				img.fill_rect(Rect2i(x0, 12, 28, 40), Color("fbfbf8"))
				img.fill_rect(Rect2i(x0 + 3, 15, 22, 28), tones[i])
				_disc(img, Vector2(x0 + 14, 27), 6.0, tones[i].darkened(0.25))
		"espejo":
			for y in h:
				for x in w:
					var d := float(x + y) / (w + h)
					var c := Color("dff0f7").lerp(Color("b8d6e6"), d)
					if absi((x + y) - 70) < 5 or absi((x + y) - 96) < 2:
						c = c.lightened(0.45)
					img.set_pixel(x, y, c)
		"reloj":
			img.fill(Color(0, 0, 0, 0))
			var c := Vector2(w / 2.0, h / 2.0)
			_disc(img, c, 33.0, Color("2b2f3a"))
			_disc(img, c, 30.0, Color("fbf7ee"))
			for i in 12:
				var a := i * TAU / 12.0
				var p := c + Vector2(sin(a), -cos(a)) * 25.0
				_disc(img, p, 1.8, Color("2b2f3a"))
			for k in [[-0.5, 16.0], [1.9, 23.0]]:
				for s in range(0, int(k[1])):
					var p := c + Vector2(sin(k[0]), -cos(k[0])) * float(s)
					_disc(img, p, 1.3, Color("2b2f3a"))
		_:
			img.fill(Color("cccccc"))
	return img


static func _disc(img: Image, center: Vector2, radius: float, color: Color) -> void:
	for y in range(maxi(0, int(center.y - radius)), mini(img.get_height(), int(center.y + radius) + 1)):
		for x in range(maxi(0, int(center.x - radius)), mini(img.get_width(), int(center.x + radius) + 1)):
			if Vector2(x, y).distance_to(center) <= radius:
				img.set_pixel(x, y, color)


static func _noise(seed_value: int, frequency: float) -> Image:
	var n := FastNoiseLite.new()
	n.seed = seed_value
	n.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	n.frequency = frequency
	return n.get_seamless_image(SIZE, SIZE)
