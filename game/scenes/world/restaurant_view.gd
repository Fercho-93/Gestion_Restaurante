extends Node2D
## Parte visual del restaurante: crea los muebles y mantiene un PersonSprite por cada
## cliente y empleado de la simulación, colocándolo donde la simulación dice.
## Necesita y_sort_enabled para que lo de delante tape a lo de detrás.

## Estado del grupo -> texto del bocadillo (su color indica el ánimo).
const BUBBLES := {
	CustomerGroup.State.EN_COLA: "...",
	CustomerGroup.State.ESPERANDO_PEDIR: "?",
	CustomerGroup.State.ESPERANDO_COMIDA: "...",
	CustomerGroup.State.ESPERANDO_CUENTA: "€",
}

var sim: RestaurantSim
## clave -> PersonSprite
var _people := {}


func setup(restaurant_sim: RestaurantSim) -> void:
	sim = restaurant_sim
	_build_furniture()


func _build_furniture() -> void:
	var layout := sim.layout
	for table in layout.tables:
		for seat in table.seats:
			_add_furniture("silla", seat)
		_add_furniture("mesa", table.cell)
	for c in layout.counter_cells:
		_add_furniture("barra", c)
	for c in layout.cook_stations:
		_add_furniture("fogon", c + Vector2i(1, 0))


func _add_furniture(kind: String, cell: Vector2i) -> void:
	var f := FurnitureSprite.new(kind)
	f.position = Iso.cell_to_screen(cell)
	add_child(f)


func _process(_delta: float) -> void:
	if sim == null:
		return
	var seen := {}
	for g in sim.groups:
		for i in g.members.size():
			var key := "g%d_%d" % [g.id, i]
			seen[key] = true
			var p := _person(key, "cliente", g.id * 7 + i)
			var m := g.members[i]
			p.entity = g
			p.moving = m.is_moving()
			p.seated = not p.moving and g.table != null and g.state != CustomerGroup.State.YENDO_A_MESA
			p.position = Iso.grid_to_screen(m.pos + (Vector2.ZERO if p.seated else m.jitter))
			_update_bubble(p, g, i)
	for s in sim.staff:
		var key := "s%d" % s.id
		seen[key] = true
		var p := _person(key, s.puesto, s.id * 3)
		p.entity = s
		p.moving = s.mover.is_moving()
		p.working = s.is_busy() and not p.moving
		p.carrying = s.is_carrying_food()
		p.position = Iso.grid_to_screen(s.mover.pos)
	for key in _people.keys():
		if not seen.has(key):
			_people[key].queue_free()
			_people.erase(key)


func _person(key: String, role: String, seed_value: int) -> PersonSprite:
	if not _people.has(key):
		var p := PersonSprite.new()
		p.setup(role, seed_value)
		add_child(p)
		_people[key] = p
	return _people[key]


func _update_bubble(p: PersonSprite, g: CustomerGroup, member_index: int) -> void:
	p.bubble = ""
	if member_index != 0:
		return
	if g.state == CustomerGroup.State.SALIENDO and g.left_angry:
		p.bubble = "!"
		p.bubble_color = Color("d9433b")
	elif BUBBLES.has(g.state):
		p.bubble = BUBBLES[g.state]
		var mood := g.mood()
		p.bubble_color = Color("d9433b").lerp(Color("e0b43b"), mood * 2.0) if mood < 0.5 \
				else Color("e0b43b").lerp(Color("4caf50"), (mood - 0.5) * 2.0)


## Persona más cercana a un punto de pantalla (o null).
func person_at(world_pos: Vector2, radius: float = 40.0) -> PersonSprite:
	var best: PersonSprite = null
	var best_d := radius
	for p in _people.values():
		var d: float = (p.position + Vector2(0, -36)).distance_to(world_pos)
		if d < best_d:
			best = p
			best_d = d
	return best
