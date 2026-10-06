class_name Neighbor
extends RefCounted
## Un vecino del barrio: una persona que existe aunque no esté en el restaurante, con su
## perfil, sus rasgos, su presupuesto, sus gustos y el recuerdo de sus visitas.

var id: int
var nombre: String
## Perfil (estudiante, ejecutivo...): diccionario de perfiles.json.
var profile: Dictionary
## Rasgos (impaciente, tacaño...): diccionarios de rasgos.json.
var traits: Array[Dictionary] = []
## Euros por persona que suele gastar.
var budget: float
## Platos favoritos (ids de receta).
var favorites: Array[String] = []
## Qué opina del restaurante, de 0 (no piensa volver) a 1 (le encanta). Empieza neutral.
var opinion := 0.5
var visits := 0
## Satisfacción de la última visita (0-100) o -1 si nunca ha venido.
var last_satisfaction := -1.0
## Día de la última visita (o -100 si nunca).
var last_visit_day := -100
## Lo que recuerda de sus visitas, de la más reciente a la más antigua (frases cortas).
var memories: Array[String] = []


## Multiplicador combinado de perfil y rasgos para un efecto (paciencia, propina...).
func factor(effect: String) -> float:
	var value := float(profile.get(effect, 1.0))
	for t in traits:
		value *= float(t["efectos"].get(effect, 1.0))
	return value


func has_trait(trait_id: String) -> bool:
	for t in traits:
		if t["id"] == trait_id:
			return true
	return false


func trait_names() -> Array[String]:
	var names: Array[String] = []
	for t in traits:
		names.append(t["nombre"])
	return names


## Se considera habitual a quien ha venido varias veces y le gusta el sitio.
func is_regular() -> bool:
	return visits >= 3 and opinion >= 0.6


func remember(day: int, satisfaction: float, note: String) -> void:
	visits += 1
	last_visit_day = day
	last_satisfaction = satisfaction
	# La opinión se mueve hacia lo vivido, más al principio que cuando ya conoce el sitio.
	var weight := 0.6 if visits <= 1 else 0.35
	opinion = clampf(lerpf(opinion, satisfaction / 100.0, weight), 0.0, 1.0)
	memories.push_front(note)
	if memories.size() > 5:
		memories.resize(5)
