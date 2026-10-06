class_name Population
extends RefCounted
## Los vecinos del barrio donde está el restaurante. Se generan al empezar la partida y
## persisten: son siempre los mismos, con sus gustos y su memoria. Cada grupo que llega
## al restaurante está formado por vecinos de verdad.

const FIRST_NAMES := ["Carmen", "Javier", "Lucía", "Manuel", "Elena", "Pablo", "Rosa", "Andrés",
	"Marta", "Diego", "Isabel", "Sergio", "Nuria", "Raúl", "Pilar", "Óscar", "Laura", "Hugo",
	"Alba", "Iván", "Teresa", "Rubén", "Sara", "Álvaro", "Inés", "Mario", "Clara", "Jorge",
	"Paula", "Adrián", "Noelia", "Víctor", "Irene", "Daniel", "Lola", "Gonzalo", "Marina",
	"Tomás", "Beatriz", "Fernando", "Silvia", "Alberto", "Julia", "Ramón", "Celia", "Luis",
	"Ana", "Carlos", "Eva", "Miguel", "Rocío", "Marcos", "Sofía", "Héctor", "Lidia", "Pedro"]
const LAST_NAMES := ["García", "López", "Martín", "Sánchez", "Pérez", "Gómez", "Ruiz", "Díaz",
	"Moreno", "Muñoz", "Álvarez", "Romero", "Navarro", "Torres", "Domínguez", "Vázquez",
	"Ramos", "Gil", "Serrano", "Blanco", "Molina", "Ortega", "Delgado", "Castro", "Rubio"]
## Mínimo de días entre dos visitas de un mismo vecino.
const MIN_DAYS_BETWEEN_VISITS := 2

var barrio: Dictionary
var neighbors: Array[Neighbor] = []
## perfil_id -> diccionario del perfil.
var profiles: Dictionary
var traits: Dictionary


## barrio: de barrios.json. profiles/traits: id -> diccionario.
func _init(barrio_data: Dictionary, profile_data: Dictionary, trait_data: Dictionary, rng: RandomNumberGenerator) -> void:
	barrio = barrio_data
	profiles = profile_data
	traits = trait_data
	for i in int(barrio["vecinos"]):
		neighbors.append(_make_neighbor(i, rng))


func _make_neighbor(index: int, rng: RandomNumberGenerator) -> Neighbor:
	var n := Neighbor.new()
	n.id = index
	n.nombre = "%s %s" % [FIRST_NAMES[rng.randi() % FIRST_NAMES.size()], LAST_NAMES[rng.randi() % LAST_NAMES.size()]]
	n.profile = profiles[_weighted_pick(barrio["poblacion"], rng)]
	for trait_id in n.profile["rasgos"]:
		if rng.randf() < float(n.profile["rasgos"][trait_id]) and n.traits.size() < 2:
			n.traits.append(traits[trait_id])
	var b: Array = n.profile["presupuesto"]
	n.budget = rng.randf_range(float(b[0]), float(b[1]))
	var likes: Array = n.profile["gustos"].duplicate()
	while n.favorites.size() < 2 and not likes.is_empty():
		n.favorites.append(likes.pop_at(rng.randi() % likes.size()))
	return n


## Forma un grupo de vecinos que quiere venir hoy: [cabeza, acompañantes...]. Quien no
## soporta el sitio o vino hace muy poco no viene; quien está contento, viene más.
func pick_group(size: int, day: int, rng: RandomNumberGenerator) -> Array[Neighbor]:
	var group: Array[Neighbor] = []
	for attempt in 40:
		var n: Neighbor = neighbors[rng.randi() % neighbors.size()]
		if group.has(n) or day - n.last_visit_day < MIN_DAYS_BETWEEN_VISITS:
			continue
		# Cuanto mejor opinión tiene del sitio, más probable es que quiera venir.
		if rng.randf() > lerpf(0.05, 1.0, n.opinion):
			continue
		# Los acompañantes suelen ser del mismo perfil que quien les invita.
		if not group.is_empty() and n.profile["id"] != group[0].profile["id"] and rng.randf() < 0.7:
			continue
		group.append(n)
		if group.size() >= size:
			break
	return group


## Opinión media del barrio sobre el restaurante (para el boca a boca).
func average_opinion() -> float:
	var total := 0.0
	for n in neighbors:
		total += n.opinion
	return total / maxf(1.0, float(neighbors.size()))


static func _weighted_pick(weights: Dictionary, rng: RandomNumberGenerator) -> String:
	var total := 0.0
	for k in weights:
		total += float(weights[k])
	var roll := rng.randf() * total
	for k in weights:
		roll -= float(weights[k])
		if roll <= 0.0:
			return k
	return weights.keys()[-1]
