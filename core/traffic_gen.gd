class_name TrafficGen
extends RefCounted
## Generator ruchu trybu swobodnego (docs/06-roadmap F10): dokłada pociągi
## do rozkładu w locie. Deterministyczny — losuje wyłącznie z RNG świata
## (CLAUDE.md zasada 5). Konfiguracja w sekcji "generator" scenariusza
## (dane, nie kod — zasada 4).

var enabled: bool = false
## Odstęp między kolejnymi wygenerowanymi pociągami (sekundy).
var gap_min_s: float = 300.0
var gap_max_s: float = 720.0
## Relacje: {from, to, tracks: Array} — od/do sąsiadów stacji.
var relations: Array[Dictionary] = []
## Mieszanka pociągów: {kind, weight, len_m, vmax_kmh, mass_t,
## power_class, stop_chance, nr_base}.
var kinds: Array[Dictionary] = []
## Czas najbliższego wygenerowania (sekundy doby; -1 = jeszcze nie losowany).
var next_at_s: float = -1.0
var _counter: int = 0


static func from_scenario(scenario: Dictionary) -> TrafficGen:
	var generator := TrafficGen.new()
	var config: Dictionary = scenario.get("generator", {})
	if config.is_empty():
		return generator
	generator.enabled = bool(config.get("enabled", true))
	generator.gap_min_s = float(config.get("gap_min_s", 300.0))
	generator.gap_max_s = float(config.get("gap_max_s", 720.0))
	for relation: Variant in (config.get("relations", []) as Array):
		generator.relations.append(relation as Dictionary)
	for kind: Variant in (config.get("kinds", []) as Array):
		generator.kinds.append(kind as Dictionary)
	if generator.relations.is_empty() or generator.kinds.is_empty():
		generator.enabled = false
	return generator


## Krok generatora: zwraca nowy wpis rozkładu albo null. Przyjazd planowany
## z wyprzedzeniem większym niż zabieganie sąsiada o drogę (NeighbourAI
## REQUEST_LEAD_S), żeby zapowiadanie przebiegło normalnym trybem.
func tick(now_s: float, rng: RandomNumberGenerator) -> Timetable.Entry:
	if not enabled:
		return null
	if next_at_s < 0.0:
		next_at_s = now_s + rng.randf_range(gap_min_s * 0.3, gap_max_s * 0.5)
		return null
	if now_s < next_at_s:
		return null
	next_at_s = now_s + rng.randf_range(gap_min_s, gap_max_s)
	var relation: Dictionary = relations[rng.randi_range(0, relations.size() - 1)]
	var kind := _pick_kind(rng)
	_counter += 1
	var entry := Timetable.Entry.new()
	entry.nr = str(int(kind.get("nr_base", 90000)) + _counter)
	entry.kind = String(kind.get("kind", "osobowy"))
	entry.from_station = String(relation.get("from", ""))
	entry.to_station = String(relation.get("to", ""))
	entry.arr_s = int(now_s + 300.0)
	entry.stop = rng.randf() < float(kind.get("stop_chance", 0.5))
	entry.dep_s = entry.arr_s + (60 if entry.stop else 0)
	var tracks: Array = relation.get("tracks", [])
	entry.track = String(tracks[rng.randi_range(0, tracks.size() - 1)]) \
		if not tracks.is_empty() else ""
	entry.len_m = float(kind.get("len_m", 120.0))
	entry.vmax_kmh = int(kind.get("vmax_kmh", 100))
	entry.mass_t = float(kind.get("mass_t", 200.0))
	entry.power_class = String(kind.get("power_class", "EZT"))
	return entry


## Losowanie rodzaju pociągu wg wag.
func _pick_kind(rng: RandomNumberGenerator) -> Dictionary:
	var total := 0.0
	for kind: Dictionary in kinds:
		total += float(kind.get("weight", 1.0))
	var roll := rng.randf() * total
	for kind: Dictionary in kinds:
		roll -= float(kind.get("weight", 1.0))
		if roll <= 0.0:
			return kind
	return kinds[kinds.size() - 1]


func to_dict() -> Dictionary:
	return {"next_at_s": next_at_s, "counter": _counter}


func from_dict(data: Dictionary) -> void:
	next_at_s = float(data.get("next_at_s", -1.0))
	_counter = int(data.get("counter", 0))
