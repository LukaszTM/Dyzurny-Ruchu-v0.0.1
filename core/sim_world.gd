class_name SimWorld
extends RefCounted
## Rdzeń symulacji — spina wszystkie podsystemy i wykonuje tick()
## wg kolejności z docs/02-architektura.md ("Pętla symulacji").
## F1: graf torowy stacji (zwrotnice z czasem przestawiania, zajętości);
## kolejne podsystemy (interlocking, pociągi, blokady...) dojdą w F3–F5.
## Czysta klasa bez zależności od węzłów sceny (testowalna headless w GUT).

## Czas symulacji w sekundach od startu scenariusza.
var sim_time: float = 0.0
## Liczba wykonanych ticków.
var tick_count: int = 0
## Wczytana stacja (null przed load_station_file).
var station: StationData = null
## Silnik zależności (tworzony przy wczytaniu stacji).
var interlocking: Interlocking = null
## Rozkład jazdy scenariusza (null = brak scenariusza, np. w testach stacji).
var timetable: Timetable = null
## Pociągi obecne w świecie.
var trains: Array[Train] = []
## Godzina startu scenariusza (sekundy doby).
var start_of_day_s: int = 5 * 3600 + 40 * 60
## Mapa semafor → sekcja zbliżania (z tablicy przebiegów, dla AI maszynisty).
var _signal_approach: Dictionary = {}
## Sekcje zajmowane przez pociągi w poprzednim ticku (diff zajętości).
var _train_cover: Dictionary = {}


## Wczytuje stację z pliku JSON (walidacja: core/station_loader.gd)
## i buduje silnik zależności. Zwraca wynik loadera {ok, errors, station}.
func load_station_file(path: String) -> Dictionary:
	var result := StationLoader.load_from_file(path)
	if result["ok"]:
		station = result["station"]
		interlocking = Interlocking.new(
			station.graph, station.routes, AspectTable.load_default()
		)
		_signal_approach.clear()
		for route_id: StringName in interlocking.routes:
			var route: Route = interlocking.routes[route_id]
			if route.approach_section != &"":
				_signal_approach[route.entry_signal] = route.approach_section
	return result


## Wczytuje scenariusz (docs/03 §6): stację, rozkład jazdy, godzinę startu.
## Zwraca {ok, errors} (błędy stacji lub scenariusza).
func load_scenario_file(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {"ok": false, "errors": ["nie można otworzyć scenariusza: %s" % path]}
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if parsed == null or not (parsed is Dictionary):
		return {"ok": false, "errors": ["scenariusz %s nie jest poprawnym JSON" % path]}
	var scenario: Dictionary = parsed
	var station_id := String((scenario.get("meta", {}) as Dictionary).get("station", ""))
	var station_result := load_station_file("res://data/stations/%s.json" % station_id)
	if not station_result["ok"]:
		return station_result
	timetable = Timetable.from_scenario(scenario)
	start_of_day_s = Timetable.parse_time_of_day(String(scenario.get("start_time", "05:40")))
	return {"ok": true, "errors": [] as Array[String]}


## Bieżąca godzina symulacji (sekundy doby).
func time_of_day_s() -> float:
	return float(start_of_day_s) + sim_time


## Wykonanie polecenia gracza (command pattern, docs/02-architektura.md).
## Rdzeń waliduje; odrzucenie z powodem to normalna sytuacja.
func execute(name: StringName, args: Dictionary) -> CommandResult:
	if station == null:
		return CommandResult.failure("stacja nie jest wczytana")
	if name == &"debug_section_occupied":
		# Ręczne zadawanie zajętości (tryb debug F2; od F4 robią to pociągi).
		var result := station.graph.set_section_occupied(
			StringName(String(args.get("id", ""))), String(args.get("value", "0")) == "1"
		)
		if result.ok:
			interlocking.tick(0.0)
		return result
	return interlocking.execute(name, args)


## Jeden krok symulacji o dt sekund czasu symulacji (wołany przez SimClock).
## Kolejność podsystemów w ticku: pociągi → zwrotnice → interlocking →
## sygnalizatory → blokady → przejazdy/dSAT → EventDirector → NeighbourAI →
## emisja zdarzeń zbiorczo (docs/02). W F1 działa krok „zwrotnice".
func tick(dt: float) -> void:
	sim_time += dt
	tick_count += 1
	if station == null:
		return
	# Kolejność podsystemów wg docs/02: pociągi → zwrotnice → interlocking
	# (ze zwalnianiem sekcyjnym i sygnalizatorami).
	_spawn_due_trains()
	for train: Train in trains:
		train.tick(dt, time_of_day_s())
	_update_train_occupancy()
	_despawn_done_trains()
	station.graph.tick(dt)
	interlocking.tick(dt)


func _spawn_due_trains() -> void:
	if timetable == null:
		return
	for entry: Timetable.Entry in timetable.due_entries(time_of_day_s()):
		entry.spawned = true
		spawn_train(entry)


## Wstawia pociąg na krawędź wjazdową od strony sąsiada (docs/05 §3).
## Krawędź wyznacza blokada: neighbour → entry_signal → sekcja zbliżania.
func spawn_train(entry: Timetable.Entry) -> Train:
	var entry_signal := _entry_signal_for_neighbour(entry.from_station)
	if entry_signal == &"":
		push_warning("SimWorld: brak blokady od sąsiada '%s' — pociąg %s pominięty"
			% [entry.from_station, entry.nr])
		return null
	var signal_device := station.graph.get_signal(entry_signal)
	var entry_edge := _approach_edge_of(signal_device)
	if entry_edge == &"":
		return null
	var edge := station.graph.get_edge(entry_edge)
	# Pociąg wjeżdża od granicznego węzła szlaku w stronę semafora.
	var boundary := edge.from_node \
		if edge.to_node == signal_device.at_node else edge.to_node
	var train := Train.from_entry(entry)
	train.place_on_entry(station.graph, _signal_approach, entry_edge, boundary)
	trains.append(train)
	return train


func _entry_signal_for_neighbour(neighbour: String) -> StringName:
	for block: Dictionary in station.blocks:
		if String(block.get("neighbour", "")) == neighbour:
			return StringName(String(block.get("entry_signal", "")))
	return &""


func _approach_edge_of(signal_device: SignalDevice) -> StringName:
	if signal_device == null:
		return &""
	for edge_id: StringName in station.graph.edges:
		var edge := station.graph.get_edge(edge_id)
		var arrives := edge.to_node == signal_device.at_node \
			if signal_device.dir == &"N" else edge.from_node == signal_device.at_node
		if arrives:
			var section := station.graph.section_for_edge(edge_id)
			if section != null and section.type == Const.SectionType.APPROACH:
				return edge_id
	return &""


## Zajętości od pociągów: diff względem poprzedniego ticku, żeby ręczne
## (debugowe) zajętości innych sekcji zostały nietknięte.
func _update_train_occupancy() -> void:
	var now := {}
	for train: Train in trains:
		if train.phase == Train.Phase.DONE:
			continue
		for section_id: StringName in train.covered_sections():
			now[section_id] = true
	for section_id: StringName in now:
		if not _train_cover.has(section_id):
			station.graph.set_section_occupied(section_id, true)
	for section_id: StringName in _train_cover:
		if not now.has(section_id):
			station.graph.set_section_occupied(section_id, false)
	_train_cover = now


func _despawn_done_trains() -> void:
	for i: int in range(trains.size() - 1, -1, -1):
		if trains[i].phase == Train.Phase.DONE:
			trains.remove_at(i)


## Snapshot stanu rdzenia do zapisu gry.
func to_dict() -> Dictionary:
	var data := {
		"sim_time": sim_time,
		"tick_count": tick_count,
	}
	data["start_of_day_s"] = start_of_day_s
	if station != null:
		data["graph"] = station.graph.to_dict()
		data["interlocking"] = interlocking.to_dict()
	if timetable != null:
		# Pełna serializacja pociągów w drodze dojdzie z pełnym save/load
		# (roadmapa F10); na razie zapisujemy, które wpisy już wjechały.
		data["timetable"] = timetable.to_dict()
	return data


## Odtworzenie stanu rdzenia z zapisu gry (stacja musi być już wczytana).
func from_dict(data: Dictionary) -> void:
	sim_time = float(data.get("sim_time", 0.0))
	tick_count = int(data.get("tick_count", 0))
	start_of_day_s = int(data.get("start_of_day_s", start_of_day_s))
	if station != null and data.has("graph"):
		station.graph.from_dict(data["graph"])
	if station != null and data.has("interlocking"):
		interlocking.from_dict(data["interlocking"])
	if timetable != null and data.has("timetable"):
		timetable.from_dict(data["timetable"])
