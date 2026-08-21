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
## Długość zmiany w minutach (0 = bez limitu).
var duration_min: int = 0
## Blokady liniowe per szlak (StringName -> BlockLine).
var block_lines: Dictionary = {}
## AI sąsiednich posterunków (po jednym na blokadę).
var neighbours: Array[NeighbourAI] = []
## Rejestr telefonogramów.
var comms: Comms = Comms.new()
## Dziennik ruchu (R-142, tryb auto).
var train_log: TrainLog = TrainLog.new()
## Zdarzenia dla warstwy UI/scoringu — odbiera je scena Main (drain_events).
var pending_events: Array[Dictionary] = []
## Termin na potwierdzenie przyjazdu / oznajmienie odjazdu (scoring v1).
const PROCEDURE_DEADLINE_S: float = 300.0
## Mapa semafor → sekcja zbliżania (z tablicy przebiegów, dla AI maszynisty).
var _signal_approach: Dictionary = {}
## Sekcje zajmowane przez pociągi w poprzednim ticku (diff zajętości).
var _train_cover: Dictionary = {}
## Stan proceduralny pociągów (nr -> Dictionary) — przyjazdy, odjazdy, kary.
var _train_meta: Dictionary = {}
var _shift_ended: bool = false


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
		block_lines.clear()
		for block_def: Dictionary in station.blocks:
			var entry_signal := station.graph.get_signal(
				StringName(String(block_def.get("entry_signal", "")))
			)
			var approach_edge := _approach_edge_of(entry_signal)
			var approach := station.graph.section_for_edge(approach_edge)
			var block := BlockLine.from_def(
				block_def, approach.id if approach != null else &""
			)
			block_lines[block.id] = block
		interlocking.block_lines = block_lines
	return result


## Wczytuje scenariusz (docs/03 §6): stację, rozkład jazdy, godzinę startu.
## Zwraca {ok, errors} (błędy stacji lub scenariusza).
func load_scenario_file(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {"ok": false, "errors": ["nie można otworzyć scenariusza: %s" % path]}
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if parsed == null or not (parsed is Dictionary):
		return {"ok": false, "errors": ["scenariusz %s nie jest poprawnym JSON" % path]}
	return apply_scenario(parsed)


## Stosuje słownik scenariusza (osobno od pliku — używane też w testach).
func apply_scenario(scenario: Dictionary) -> Dictionary:
	var station_id := String((scenario.get("meta", {}) as Dictionary).get("station", ""))
	var station_result := load_station_file("res://data/stations/%s.json" % station_id)
	if not station_result["ok"]:
		return station_result
	timetable = Timetable.from_scenario(scenario)
	start_of_day_s = Timetable.parse_time_of_day(String(scenario.get("start_time", "05:40")))
	duration_min = int(scenario.get("duration_min", 0))
	neighbours.clear()
	for block_id: StringName in block_lines:
		var block: BlockLine = block_lines[block_id]
		neighbours.append(NeighbourAI.new(block.neighbour_name, block, timetable))
	return {"ok": true, "errors": [] as Array[String]}


## Bieżąca godzina symulacji (sekundy doby).
func time_of_day_s() -> float:
	return float(start_of_day_s) + sim_time


## Wykonanie polecenia gracza (command pattern, docs/02-architektura.md).
## Rdzeń waliduje; odrzucenie z powodem to normalna sytuacja.
func execute(name: StringName, args: Dictionary) -> CommandResult:
	if station == null:
		return CommandResult.failure("stacja nie jest wczytana")
	match name:
		&"debug_section_occupied":
			# Ręczne zadawanie zajętości (tryb debug F2; od F4 robią to pociągi).
			var result := station.graph.set_section_occupied(
				StringName(String(args.get("id", ""))), String(args.get("value", "0")) == "1"
			)
			if result.ok:
				interlocking.tick(0.0)
			return result
		&"block_press":
			return _cmd_block_press(args)
		&"phone_send":
			return _cmd_phone_send(args)
		&"phone_open":
			comms.mark_read()
			return CommandResult.success()
	return interlocking.execute(name, args)


## Obsługa pola blokady przez gracza (Po/Ko/Poz — docs/systemy/15 §1).
func _cmd_block_press(args: Dictionary) -> CommandResult:
	var block_id := StringName(String(args.get("id", "")))
	var field := String(args.get("value", ""))
	if not block_lines.has(block_id):
		return CommandResult.failure("blokada %s nie istnieje" % block_id)
	var block: BlockLine = block_lines[block_id]
	var confirmed_nr := block.train_nr
	var result := block.press(field)
	if not result.ok:
		return result
	var now := time_of_day_s()
	match field:
		"Ko":
			# Potwierdzenie fizyczne przyjazdu — druga część to telefonogram.
			if _train_meta.has(confirmed_nr):
				(_train_meta[confirmed_nr] as Dictionary)["ko_done"] = true
		"Poz":
			# Danie pozwolenia sąsiadowi — wpis pozwolenia dla pociągu,
			# o który sąsiad zabiega (tryb auto dziennika).
			var ai := _neighbour_for_block(block_id)
			if ai != null:
				for entry: Timetable.Entry in ai.incoming:
					if not entry.spawned:
						train_log.note_permission(entry.nr, now)
						break
	return result


## Telefonogram gracza do sąsiada (docs/systemy/18 §2).
func _cmd_phone_send(args: Dictionary) -> CommandResult:
	var type := StringName(String(args.get("type", "")))
	var nr := String(args.get("nr", ""))
	var neighbour_name := String(args.get("neighbour", ""))
	if not Comms.TYPES.has(type):
		return CommandResult.failure("nieznany typ telefonogramu: %s" % type)
	var ai := _neighbour_by_name(neighbour_name)
	if ai == null:
		return CommandResult.failure("brak łączności z posterunkiem %s" % neighbour_name)
	var now := time_of_day_s()
	comms.add(station.display_name(), Comms.format_message(type, nr, now), now, false)
	ai.on_player_phone(type, nr, now)
	match type:
		&"oznajmienie_odjazdu":
			if _train_meta.has(nr):
				(_train_meta[nr] as Dictionary)["departure_announced"] = true
			train_log.note_announced(nr, now)
		&"potwierdzenie_przyjazdu":
			if _train_meta.has(nr):
				(_train_meta[nr] as Dictionary)["phone_confirmed"] = true
			train_log.note_confirmed(nr, now)
	return CommandResult.success()


func _neighbour_by_name(neighbour_name: String) -> NeighbourAI:
	for ai: NeighbourAI in neighbours:
		if ai.neighbour_name == neighbour_name:
			return ai
	return null


func _neighbour_for_block(block_id: StringName) -> NeighbourAI:
	for ai: NeighbourAI in neighbours:
		if ai.block != null and ai.block.id == block_id:
			return ai
	return null


## Zdarzenia z tego ticku dla warstwy UI/scoringu (Main je rozprowadza).
func drain_events() -> Array[Dictionary]:
	var out := pending_events
	pending_events = []
	return out


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
	# (ze zwalnianiem sekcyjnym i sygnalizatorami) → NeighbourAI.
	for train: Train in trains:
		train.tick(dt, time_of_day_s())
	_update_train_occupancy()
	_track_train_procedures()
	_despawn_done_trains()
	station.graph.tick(dt)
	interlocking.tick(dt)
	_tick_neighbours()
	_check_procedure_deadlines()
	_check_shift_end()


## Obsługa zdarzeń AI sąsiadów: telefonogramy, wjazdy pociągów na odstęp
## (wejście do świata sprzężone z zapowiedzią — docs/05 §3).
func _tick_neighbours() -> void:
	var now := time_of_day_s()
	for ai: NeighbourAI in neighbours:
		for event: Dictionary in ai.tick(now):
			match String(event["kind"]):
				"phone":
					var type: StringName = event["type"]
					var nr := String(event["nr"])
					comms.add(ai.neighbour_name,
						Comms.format_message(type, nr, now), now, true)
					pending_events.append({"type": &"phone_ring"})
					if type == &"oznajmienie_odjazdu":
						train_log.note_announced(nr, now)
					elif type == &"danie_pozwolenia":
						train_log.note_permission(nr, now)
					elif type == &"potwierdzenie_przyjazdu":
						train_log.note_confirmed(nr, now)
				"ack":
					comms.add(ai.neighbour_name, "Przyjąłem. Koniec.", now, true)
					pending_events.append({"type": &"phone_ring"})
				"spawn":
					_spawn_announced(ai, String(event["nr"]))
				_:
					pass


func _spawn_announced(ai: NeighbourAI, nr: String) -> void:
	if timetable == null:
		return
	for entry: Timetable.Entry in timetable.entries:
		if entry.nr == nr and not entry.spawned:
			entry.spawned = true
			var train := spawn_train(entry)
			if train != null:
				ai.block.train_entered_from_neighbour(nr)
			return


## Detekcja proceduralna: pociąg przyjechał cały (koniec zjechał ze szlaku
## wjazdowego) / wyjechał na szlak — zasila blokadę, dziennik i scoring.
func _track_train_procedures() -> void:
	var now := time_of_day_s()
	for train: Train in trains:
		var meta: Dictionary = _train_meta.get(train.nr, {})
		if meta.is_empty():
			continue
		var covered := train.covered_sections()
		var entry_block: BlockLine = block_lines.get(meta["entry_block"])
		if entry_block != null and entry_block.approach_section != &"":
			if covered.has(entry_block.approach_section):
				meta["was_on_entry"] = true
			elif bool(meta["was_on_entry"]) and not bool(meta["arrived"]):
				meta["arrived"] = true
				meta["arrived_s"] = now
				entry_block.train_arrived_at_player()
				train_log.note_arrived(train.nr, now)
				var entry: Timetable.Entry = meta["entry"]
				var late_min := int(maxf(0.0, now - float(entry.arr_s)) / 60.0)
				if late_min > 0:
					pending_events.append({"type": &"penalty", "points": late_min,
						"reason": "opóźnienie pociągu %s: %d min" % [train.nr, late_min]})
		var exit_block: BlockLine = block_lines.get(meta["exit_block"])
		if exit_block != null and exit_block.approach_section != &"" \
				and not bool(meta["departed"]) \
				and covered.has(exit_block.approach_section):
			meta["departed"] = true
			meta["departed_s"] = now
			exit_block.train_dispatched_by_player(train.nr)
			train_log.note_departed(train.nr, now)


## Kary proceduralne (scoring v1, docs/05 §7): brak potwierdzenia przyjazdu
## (Ko + telefonogram) / brak oznajmienia odjazdu w terminie.
func _check_procedure_deadlines() -> void:
	var now := time_of_day_s()
	for nr: String in _train_meta:
		var meta: Dictionary = _train_meta[nr]
		if bool(meta["arrived"]) and not bool(meta.get("arrival_penalized", false)) \
				and now > float(meta["arrived_s"]) + PROCEDURE_DEADLINE_S \
				and not (bool(meta.get("ko_done", false)) and bool(meta.get("phone_confirmed", false))):
			meta["arrival_penalized"] = true
			pending_events.append({"type": &"penalty", "points": 10,
				"reason": "brak potwierdzenia przyjazdu pociągu %s (Ko + telefonogram)" % nr})
		if bool(meta["departed"]) and not bool(meta.get("departure_penalized", false)) \
				and now > float(meta["departed_s"]) + PROCEDURE_DEADLINE_S \
				and not bool(meta.get("departure_announced", false)):
			meta["departure_penalized"] = true
			pending_events.append({"type": &"penalty", "points": 10,
				"reason": "brak oznajmienia odjazdu pociągu %s" % nr})


func _check_shift_end() -> void:
	if _shift_ended or duration_min <= 0:
		return
	if sim_time >= float(duration_min) * 60.0:
		_shift_ended = true
		pending_events.append({"type": &"shift_end"})


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
	_train_meta[entry.nr] = {
		"entry": entry,
		"entry_block": _block_for_neighbour(entry.from_station),
		"exit_block": _block_for_neighbour(entry.to_station),
		"was_on_entry": false,
		"arrived": false,
		"arrived_s": 0.0,
		"departed": false,
		"departed_s": 0.0,
		"ko_done": false,
		"phone_confirmed": false,
		"departure_announced": false,
	}
	train_log.entry_for(entry.nr, "%s → %s" % [entry.from_station, entry.to_station],
		entry.track)
	return train


func _block_for_neighbour(neighbour_name: String) -> StringName:
	for block_id: StringName in block_lines:
		if (block_lines[block_id] as BlockLine).neighbour_name == neighbour_name:
			return block_id
	return &""


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
		if trains[i].phase != Train.Phase.DONE:
			continue
		var nr := trains[i].nr
		var meta: Dictionary = _train_meta.get(nr, {})
		# Sąsiad po stronie wyjazdu przejmuje pociąg: po czasie jazdy
		# potwierdzi przyjazd i zwolni odstęp (jego Ko).
		if not meta.is_empty():
			var exit_ai := _neighbour_for_block(meta["exit_block"])
			if exit_ai != null:
				exit_ai.on_player_train_left(nr, time_of_day_s())
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
		var blocks_state := {}
		for block_id: StringName in block_lines:
			blocks_state[String(block_id)] = (block_lines[block_id] as BlockLine).to_dict()
		data["blocks"] = blocks_state
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
	var blocks_state: Dictionary = data.get("blocks", {})
	for key: String in blocks_state:
		if block_lines.has(StringName(key)):
			(block_lines[StringName(key)] as BlockLine).from_dict(blocks_state[key])
