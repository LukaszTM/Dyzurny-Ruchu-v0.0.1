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
## Reżyser zdarzeń scenariusza (docs/05 §6).
var director: EventDirector = null
## Generator ruchu trybu swobodnego (null/wyłączony poza F10 free-play).
var traffic_gen: TrafficGen = null
## Samouczek (null poza scenariuszami lekcji — sekcja "tutorial").
var tutorial: Tutorial = null
## Ława dźwigniowa (null poza nastawnią mechaniczną — docs/systemy/12).
var lever_frame: LeverFrame = null
## Przejazdy kolejowo-drogowe (StringName -> LevelCrossing).
var crossings: Dictionary = {}
## Urządzenia dSAT (StringName -> Dsat).
var dsats: Dictionary = {}
## Trwające procedury dSAT: nr pociągu -> {level, at_s, acked, held,
## inspected, result_at_s} (docs/systemy/17 §3).
var _dsat_cases: Dictionary = {}
## Termin reakcji na alarm dSAT (docs/17 §3.5).
const DSAT_REACT_S: float = 180.0
## Czas oględzin po zatrzymaniu (docs/17 §3.3: 5–10 min — przyjęto 5).
const DSAT_INSPECT_S: float = 300.0
## Jedyne źródło losowości rdzenia — Main podpina RNG z GameState
## (determinizm, CLAUDE.md zasada 5).
var rng: RandomNumberGenerator = RandomNumberGenerator.new()
## Rozkazy pisemne (docs/systemy/18 §5): {no, type, nr, signal, left_s,
## active, applied}.
var orders: Array[Dictionary] = []
## Termin na potwierdzenie przyjazdu / oznajmienie odjazdu (scoring v1).
const PROCEDURE_DEADLINE_S: float = 300.0
## Czas dyktowania rozkazu przez radiotelefon (docs/systemy/18 §5).
const ORDER_DICTATE_S: float = 20.0
## Pozwolenia telefoniczne otrzymane od sąsiadów (nr → true) — przy
## awarii blokady warunkują ocenę wyprawienia.
var _phone_clearance: Dictionary = {}
## Poprzedni stan jazdy na Sz per pociąg (detekcja minięcia Sz/rozkazu).
var _train_sz_prev: Dictionary = {}
var _order_counter: int = 0
## Rejestr zdarzeń (docs/systemy/14 §4) — polecenia i zdarzenia z czasem;
## prowadzony na każdej stacji (raport zmiany korzysta z tych danych).
var register: EventRegister = EventRegister.new()
## Tryb komputerowy (panel "komputer"): polecenia specjalne wymagają
## potwierdzenia — filozofia dwóch kroków (docs/systemy/14 §3).
var confirm_mode: bool = false
## Oczekujące polecenie specjalne: {"name": StringName, "args": Dictionary}.
var pending_confirm: Dictionary = {}
var _confirm_left_s: float = 0.0
## Czas na potwierdzenie polecenia specjalnego (docs/14 §3 — przyjęto 30 s).
const CONFIRM_TIME_S: float = 30.0
## Polecenia specjalne — odpowiedniki przycisków plombowanych (docs/14 §3).
## block_press z polem "Poz" też jest specjalne (pozwolenie blokady).
const SPECIAL_COMMANDS: Array[StringName] = [
	&"sub_signal", &"route_emergency_release", &"turnout_lock_toggle",
	&"radio_stop", &"crossing_open",
]
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
		lever_frame = null
		if String(station.panel.get("type", "")) == "mechaniczny":
			lever_frame = LeverFrame.new(station.panel, station.graph, interlocking)
		confirm_mode = String(station.panel.get("type", "")) == "komputer"
		pending_confirm = {}
		_confirm_left_s = 0.0
		crossings.clear()
		for crossing_def: Dictionary in station.crossings:
			var crossing := LevelCrossing.from_def(crossing_def)
			crossings[crossing.id] = crossing
		interlocking.crossings = crossings
		dsats.clear()
		for dsat_def: Dictionary in station.dsat:
			var device := Dsat.from_def(dsat_def)
			dsats[device.id] = device
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
		# AI powstaje przy bloku przyjazdowym (z semaforem wjazdowym);
		# bloki wyjazdowe sbl zwalniają się same zajętością odstępów.
		if block.entry_signal != &"":
			neighbours.append(NeighbourAI.new(block.neighbour_name, block, timetable))
	director = EventDirector.from_scenario(scenario)
	traffic_gen = TrafficGen.from_scenario(scenario)
	tutorial = Tutorial.from_scenario(scenario)
	return {"ok": true, "errors": [] as Array[String]}


## Bieżąca godzina symulacji (sekundy doby).
func time_of_day_s() -> float:
	return float(start_of_day_s) + sim_time


## Wykonanie polecenia gracza (command pattern, docs/02-architektura.md).
## Rdzeń waliduje; odrzucenie z powodem to normalna sytuacja.
## W trybie komputerowym polecenia specjalne przechodzą przez dwa kroki:
## pierwsze wywołanie odkłada polecenie (odmowa z instrukcją), wykonuje je
## dopiero `command_confirm`; `command_cancel` rezygnuje (docs/14 §3).
func execute(name: StringName, args: Dictionary) -> CommandResult:
	if station == null:
		return CommandResult.failure("stacja nie jest wczytana")
	if name == &"command_confirm":
		return _cmd_confirm()
	if name == &"command_cancel":
		if pending_confirm.is_empty():
			return CommandResult.failure("brak polecenia do anulowania")
		register.add(time_of_day_s(), "DYŻ",
			"Anulowano polecenie %s" % pending_confirm["name"])
		pending_confirm = {}
		_confirm_left_s = 0.0
		return CommandResult.success()
	if confirm_mode and _is_special(name, args):
		pending_confirm = {"name": name, "args": args.duplicate(true)}
		_confirm_left_s = CONFIRM_TIME_S
		register.add(time_of_day_s(), "DYŻ",
			"Polecenie specjalne %s czeka na potwierdzenie" % name)
		pending_events.append({"type": &"confirm_required",
			"command": name, "args": args.duplicate(true),
			"text": "Polecenie specjalne %s — wykonać? (potwierdź/anuluj)" % name})
		return CommandResult.failure(
			"polecenie specjalne %s — wymaga potwierdzenia (%.0f s)"
			% [name, CONFIRM_TIME_S]
		)
	var result := _execute_inner(name, args)
	_log_command(name, args, result)
	if tutorial != null:
		tutorial.notify_command(name, args, result.ok)
	return result


## Czy polecenie wymaga drugiego kroku (odpowiednik plomby — docs/14 §3).
func _is_special(name: StringName, args: Dictionary) -> bool:
	if SPECIAL_COMMANDS.has(name):
		return true
	# Pozwolenie blokady (Poz) — specjalne; Po/Ko to obsługa rutynowa.
	return name == &"block_press" and String(args.get("value", "")) == "Poz"


## Potwierdzenie odłożonego polecenia specjalnego (drugi krok).
func _cmd_confirm() -> CommandResult:
	if pending_confirm.is_empty():
		return CommandResult.failure("brak polecenia do potwierdzenia")
	var name: StringName = pending_confirm["name"]
	var args: Dictionary = pending_confirm["args"]
	pending_confirm = {}
	_confirm_left_s = 0.0
	var result := _execute_inner(name, args)
	_log_command(name, args, result)
	if tutorial != null:
		# Samouczek widzi potwierdzone polecenie pod jego właściwą nazwą.
		tutorial.notify_command(name, args, result.ok)
	return result


## Wpis polecenia do rejestru zdarzeń (docs/14 §4). Pomija debugowe
## i otwarcie okna telefonu (to nie są operacje ruchowe).
func _log_command(name: StringName, args: Dictionary, result: CommandResult) -> void:
	if String(name).begins_with("debug_") or name == &"phone_open":
		return
	var parts: Array[String] = []
	for key: String in ["id", "value", "nr", "type", "signal"]:
		if args.has(key) and not String(args[key]).is_empty():
			parts.append(String(args[key]))
	var call := String(name) if parts.is_empty() \
		else "%s %s" % [name, " ".join(parts)]
	if result.ok:
		register.add(time_of_day_s(), "DYŻ", "%s — wykonano" % call)
	else:
		register.add(time_of_day_s(), "DYŻ", "%s — odmowa: %s" % [call, result.reason])


func _execute_inner(name: StringName, args: Dictionary) -> CommandResult:
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
		&"order_dictate":
			return _cmd_order_dictate(args)
		&"lever_move":
			if lever_frame == null:
				return CommandResult.failure("ta nastawnia nie ma ławy dźwigniowej")
			return lever_frame.move_lever(StringName(String(args.get("id", ""))))
		&"station_block_press":
			if lever_frame == null:
				return CommandResult.failure("ta nastawnia nie ma aparatu blokowego")
			return lever_frame.press_block(StringName(String(args.get("id", ""))))
		&"crossing_close", &"crossing_open":
			var crossing: LevelCrossing = crossings.get(StringName(String(args.get("id", ""))))
			if crossing == null:
				return CommandResult.failure("przejazd %s nie istnieje" % args.get("id", ""))
			return crossing.command_close() if name == &"crossing_close" \
				else crossing.command_open()
		&"dsat_ack":
			return _cmd_dsat_ack(String(args.get("nr", "")))
		&"radio_stop", &"radio_release":
			var held_train := _train_by_nr(String(args.get("nr", "")))
			if held_train == null:
				return CommandResult.failure("brak pociągu %s na stacji" % args.get("nr", ""))
			held_train.radio_hold = name == &"radio_stop"
			return CommandResult.success()
	return interlocking.execute(name, args)


## Skwitowanie alarmu dSAT (docs/systemy/17 §3.1). Puste nr = wszystkie.
func _cmd_dsat_ack(nr: String) -> CommandResult:
	var acked := 0
	for case_nr: String in _dsat_cases:
		if not nr.is_empty() and case_nr != nr:
			continue
		var case_data: Dictionary = _dsat_cases[case_nr]
		if not bool(case_data["acked"]):
			case_data["acked"] = true
			acked += 1
	if acked == 0:
		return CommandResult.failure("brak alarmu dSAT do skwitowania")
	return CommandResult.success()


## Wystawienie i dyktowanie rozkazu pisemnego (docs/systemy/18 §5).
func _cmd_order_dictate(args: Dictionary) -> CommandResult:
	var type := String(args.get("type", ""))
	var nr := String(args.get("nr", ""))
	var signal_id := String(args.get("signal", ""))
	if not ["S", "O", "N"].has(type):
		return CommandResult.failure("nieznany druk rozkazu: %s" % type)
	if type == "S":
		if station.graph.get_signal(StringName(signal_id)) == null:
			return CommandResult.failure("rozkaz „S”: semafor %s nie istnieje" % signal_id)
	for order: Dictionary in orders:
		if String(order["nr"]) == nr and not bool(order["active"]):
			return CommandResult.failure("trwa już dyktowanie rozkazu dla pociągu %s" % nr)
	_order_counter += 1
	orders.append({
		"no": _order_counter, "type": type, "nr": nr, "signal": signal_id,
		"left_s": ORDER_DICTATE_S, "active": false, "applied": false,
	})
	return CommandResult.success()


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
	# Lustro zdarzeń w rejestrze (docs/14 §4) — źródło SYS.
	for event: Dictionary in out:
		if event["type"] == &"confirm_required":
			continue  # zalogowane już przy odłożeniu polecenia
		var text := String(event.get("text",
			event.get("reason", "zdarzenie %s" % event["type"])))
		register.add(time_of_day_s(), "SYS", "[%s] %s" % [event["type"], text])
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
	# Blokady samoczynne przed interlockingiem: semafory odstępowe muszą
	# mieć świeży obraz, zanim update_signals policzy semafor wyjazdowy
	# (next_info z pierwszego odstępowego — docs/04 §6).
	for block_id: StringName in block_lines:
		(block_lines[block_id] as BlockLine).update_automatic(station.graph)
	interlocking.tick(dt)
	if not interlocking.events_out.is_empty():
		pending_events.append_array(interlocking.events_out)
		interlocking.events_out = []
	# (6) przejazdy/dSAT (kolejność wg docs/02).
	for crossing_id: StringName in crossings:
		(crossings[crossing_id] as LevelCrossing).tick(dt, station.graph)
	_tick_dsat()
	_tick_events()
	# Wygaśnięcie niepotwierdzonego polecenia specjalnego (docs/14 §3).
	if _confirm_left_s > 0.0:
		_confirm_left_s = maxf(0.0, _confirm_left_s - dt)
		if _confirm_left_s == 0.0 and not pending_confirm.is_empty():
			register.add(time_of_day_s(), "SYS",
				"Polecenie %s niepotwierdzone — wygasło" % pending_confirm["name"])
			pending_events.append({"type": &"confirm_expired",
				"command": pending_confirm["name"],
				"text": "Polecenie %s wygasło bez potwierdzenia" % pending_confirm["name"]})
			pending_confirm = {}
	_tick_orders(dt)
	_tick_traffic_gen()
	_tick_neighbours()
	if tutorial != null and station != null:
		tutorial.observe_events(pending_events)
		pending_events.append_array(tutorial.tick(self))
	_check_procedure_deadlines()
	_check_shift_end()


## Pomiary dSAT i pilnowanie procedury alarmowej (docs/systemy/17 §2–§3).
func _tick_dsat() -> void:
	var now := time_of_day_s()
	for dsat_id: StringName in dsats:
		var device: Dsat = dsats[dsat_id]
		for train: Train in trains:
			var report := device.check_train(train, station.graph)
			if report.is_empty():
				continue
			if String(report["level"]) == "OK":
				pending_events.append({"type": &"dsat_report",
					"text": "dSAT %s: pociąg %s — bez usterek" % [dsat_id, train.nr]})
			else:
				_dsat_cases[train.nr] = {"level": report["level"], "at_s": now,
					"acked": false, "held": false, "inspected": false, "result_at_s": -1.0}
				pending_events.append({"type": &"dsat_alarm",
					"train": train.nr, "code": report["code"],
					"level": report["level"], "axle": report["axle"],
					"text": "dSAT %s: pociąg %s, oś %d, kod %s — %s! Skwituj i zatrzymaj pociąg"
					% [dsat_id, train.nr, report["axle"], report["code"], report["level"]]})
	for nr: String in _dsat_cases:
		var case_data: Dictionary = _dsat_cases[nr]
		var train := _train_by_nr(nr)
		if not bool(case_data["held"]) and train != null and train.v_ms == 0.0 \
				and (train.radio_hold or _is_train_held_by_signal(train)):
			case_data["held"] = true
			case_data["result_at_s"] = now + DSAT_INSPECT_S
			pending_events.append({"type": &"alarm",
				"text": "Pociąg %s zatrzymany — drużyna wykonuje oględziny (%d min)"
				% [nr, int(DSAT_INSPECT_S / 60.0)]})
		if not bool(case_data.get("penalized", false)) \
				and now > float(case_data["at_s"]) + DSAT_REACT_S \
				and not (bool(case_data["acked"]) and bool(case_data["held"])):
			case_data["penalized"] = true
			pending_events.append({"type": &"penalty", "points": 50,
				"reason": "ZDARZENIE NIEBEZPIECZNE: brak reakcji na alarm dSAT (pociąg %s)" % nr})
		if bool(case_data["held"]) and not bool(case_data["inspected"]) \
				and now >= float(case_data["result_at_s"]):
			case_data["inspected"] = true
			# Wynik oględzin z RNG scenariusza (docs/17 §3.4).
			var confirmed := rng.randf() < 0.6
			if train != null:
				train.radio_hold = false
				if confirmed:
					train.order_speed_cap_ms = 40.0 / 3.6
			pending_events.append({"type": &"alarm",
				"text": ("Oględziny %s: usterka potwierdzona — wagon wyłączony, jazda ≤40 km/h"
					if confirmed else "Oględziny %s: alarm fałszywy — pociąg gotów do jazdy") % nr})


## Czy jest nieskwitowany alarm dSAT (lampka/brzęczyk w UI).
func dsat_unacked() -> bool:
	for nr: String in _dsat_cases:
		if not bool((_dsat_cases[nr] as Dictionary)["acked"]):
			return true
	return false


func _is_train_held_by_signal(train: Train) -> bool:
	# Pociąg stoi przed semaforem „stój" (przytrzymany sygnałem).
	for point: Dictionary in train.signal_points:
		if bool(point["passed"]):
			continue
		var signal_device := station.graph.get_signal(point["signal"])
		if signal_device != null and signal_device.shows_stop() \
				and float(point["pos"]) - train.front_m < 60.0:
			return true
	return false


## Zdarzenia scenariusza: skutki w rdzeniu + alarm dla gracza (docs/05 §6).
func _tick_events() -> void:
	if director == null:
		return
	for action: Dictionary in director.tick(time_of_day_s(), rng):
		var target := String(action["target"])
		var is_repair := String(action["kind"]) == "repair"
		match String(action["type"]):
			"turnout_no_control":
				var turnout := station.graph.get_turnout(StringName(target))
				if turnout == null:
					continue
				if is_repair:
					# Ekipa przywraca kontrolę w bieżącym położeniu iglic
					# (rozprucie w międzyczasie wymaga osobnej procedury).
					if turnout.state == Const.TurnoutState.NO_CONTROL:
						turnout.state = Const.TurnoutState.PLUS \
							if turnout.physical_pos() == Const.TurnoutPos.PLUS \
							else Const.TurnoutState.MINUS
						pending_events.append({"type": &"alarm",
							"text": "Zwrotnica %s: kontrola przywrócona" % target})
				else:
					turnout.set_no_control()
					pending_events.append({"type": &"alarm",
						"text": "USTERKA: zwrotnica %s bez kontroli położenia" % target})
			"block_failure":
				var block: BlockLine = block_lines.get(StringName(target))
				if block == null:
					continue
				block.failed = not is_repair
				if is_repair:
					pending_events.append({"type": &"alarm",
						"text": "Blokada %s znów sprawna" % target})
				else:
					pending_events.append({"type": &"alarm",
						"text": "AWARIA blokady %s — przejdź na telefoniczne zapowiadanie" % target})
			"crossing_failure":
				var crossing: LevelCrossing = crossings.get(StringName(target))
				if crossing == null:
					continue
				crossing.set_failure(not is_repair)
				pending_events.append({"type": &"alarm",
					"text": ("Przejazd %s znów sprawny" if is_repair
						else "AWARIA przejazdu %s — rozkaz „O” dla drużyn!") % target})
			"dsat_alarm":
				var device: Dsat = dsats.get(StringName(target))
				if device != null and not is_repair:
					device.armed = (action.get("payload", {}) as Dictionary).duplicate(true)
			_:
				pending_events.append({"type": &"alarm",
					"text": "Zdarzenie scenariusza: %s (%s)" % [action["type"], target]})
	interlocking.update_signals()


## Generator ruchu trybu swobodnego: nowy pociąg trafia do rozkładu
## i do AI właściwego sąsiada — dalej normalny obieg zapowiadania.
func _tick_traffic_gen() -> void:
	if traffic_gen == null or timetable == null:
		return
	var entry := traffic_gen.tick(time_of_day_s(), rng)
	if entry == null:
		return
	timetable.entries.append(entry)
	for ai: NeighbourAI in neighbours:
		ai.add_incoming(entry)
	pending_events.append({"type": &"timetable_add", "nr": entry.nr,
		"text": "Rozkład: pociąg %s (%s) %s → %s, przyjazd ok. %s" % [
			entry.nr, entry.kind, entry.from_station, entry.to_station,
			Comms.format_time(float(entry.arr_s)),
		]})


## Dyktowanie i aktywacja rozkazów pisemnych (docs/systemy/18 §5).
func _tick_orders(dt: float) -> void:
	for order: Dictionary in orders:
		if not bool(order["active"]):
			order["left_s"] = float(order["left_s"]) - dt
			if float(order["left_s"]) <= 0.0:
				order["active"] = true
				pending_events.append({"type": &"alarm",
					"text": "Rozkaz „%s” nr %d dla pociągu %s podyktowany — maszynista powtórzył"
					% [order["type"], order["no"], order["nr"]]})
				train_log.add_remark(String(order["nr"]),
					"rozkaz „%s” nr %d" % [order["type"], order["no"]])
		if bool(order["active"]) and not bool(order["applied"]):
			var train := _train_by_nr(String(order["nr"]))
			if train == null:
				continue
			order["applied"] = true
			match String(order["type"]):
				"S":
					train.pass_orders[StringName(String(order["signal"]))] = true
				"O":
					# Ograniczenie prędkości 20 km/h (docs/04 §8 — obsługa
					# ręczna zwrotnicy / ostrzeżenie).
					train.order_speed_cap_ms = 20.0 / 3.6
				_:
					pass


func _train_by_nr(nr: String) -> Train:
	for train: Train in trains:
		if train.nr == nr:
			return train
	return null


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
				"phone_clearance":
					# Telefoniczne „droga wolna" od sąsiada (awaria blokady).
					_phone_clearance[String(event["nr"])] = true
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
			# Ocena proceduralna: wyprawienie przy awarii blokady wymaga
			# uprzedniego telefonicznego zapowiadania (docs/systemy/18 §6).
			if exit_block.failed and not _phone_clearance.get(train.nr, false):
				pending_events.append({"type": &"penalty", "points": 10,
					"reason": "wyprawienie %s przy awarii blokady bez telefonicznego zapowiadania"
					% train.nr})
		# Ocena jazdy na Sz/rozkaz: w chwili minięcia semafora droga do
		# następnego semafora musi być wolna (docs/00 — zdarzenie
		# niebezpieczne; docs/05 §7).
		var sz_now := train.sz_authority
		if sz_now and not bool(_train_sz_prev.get(train.nr, false)):
			# Wpis do dziennika (uwagi) — docs/systemy/18 §6.
			train_log.add_remark(train.nr, "jazda na Sz/rozkaz")
			for section_id: StringName in train.sections_ahead_to_next_signal():
				var section := station.graph.get_section(section_id)
				if section != null and section.occupied \
						and not train.covered_sections().has(section_id):
					pending_events.append({"type": &"penalty", "points": 50,
						"reason": "ZDARZENIE NIEBEZPIECZNE: pociąg %s skierowany na zajęty tor (%s) na Sz/rozkaz"
						% [train.nr, section_id]})
					break
		_train_sz_prev[train.nr] = sz_now


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
## Krawędź wyznacza blokada: neighbour → entry_signal → sekcja zbliżania;
## przy sbl pociąg wchodzi na początek pierwszego odstępu.
func spawn_train(entry: Timetable.Entry) -> Train:
	var entry_block_id := _block_for_neighbour(entry.from_station, false)
	var entry_block: BlockLine = block_lines.get(entry_block_id)
	if entry_block == null:
		push_warning("SimWorld: brak blokady od sąsiada '%s' — pociąg %s pominięty"
			% [entry.from_station, entry.nr])
		return null
	var entry_edge: StringName = &""
	var boundary: StringName = &""
	if entry_block.automatic and not entry_block.odstepy.is_empty():
		var first := station.graph.get_section(entry_block.odstepy[0])
		if first == null or first.edge_ids.is_empty():
			return null
		entry_edge = first.edge_ids[0]
		boundary = _outer_node_of(entry_edge)
	else:
		var signal_device := station.graph.get_signal(entry_block.entry_signal)
		entry_edge = _approach_edge_of(signal_device)
		if entry_edge == &"":
			return null
		var edge_ref := station.graph.get_edge(entry_edge)
		boundary = edge_ref.from_node \
			if edge_ref.to_node == signal_device.at_node else edge_ref.to_node
	var edge := station.graph.get_edge(entry_edge)
	var train := Train.from_entry(entry)
	train.eastbound = edge.from_node == boundary
	train.place_on_entry(station.graph, _signal_approach, entry_edge, boundary)
	# Mapa sekcja → przejazd (ostrożność przed niesprawnym przejazdem).
	for crossing_id: StringName in crossings:
		var crossing: LevelCrossing = crossings[crossing_id]
		for section_id: StringName in crossing.on_sections:
			train.crossings_by_section[section_id] = crossing
	trains.append(train)
	_train_meta[entry.nr] = {
		"entry": entry,
		"entry_block": _block_for_neighbour(entry.from_station, false),
		"exit_block": _block_for_neighbour(entry.to_station, true),
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


## Czy pociąg przyjechał (dla samouczka i GUI — stan proceduralny).
func train_arrived(nr: String) -> bool:
	return bool((_train_meta.get(nr, {}) as Dictionary).get("arrived", false))


## Czy pociąg odjechał ze stacji.
func train_departed(nr: String) -> bool:
	return bool((_train_meta.get(nr, {}) as Dictionary).get("departed", false))


## Nazwa sąsiada, w którego stronę pociąg wyjechał (dla mostka LCS).
func train_exit_neighbour(nr: String) -> String:
	var meta: Dictionary = _train_meta.get(nr, {})
	if meta.is_empty():
		return ""
	var block: BlockLine = block_lines.get(meta.get("exit_block", &""))
	return block.neighbour_name if block != null else ""


## Blokada od/do sąsiada: przyjazdowa (z entry_signal) albo wyjazdowa
## (z exit_signals) — na dwutorówce to osobne bloki per tor.
func _block_for_neighbour(neighbour_name: String, for_exit: bool) -> StringName:
	for block_id: StringName in block_lines:
		var block: BlockLine = block_lines[block_id]
		if block.neighbour_name != neighbour_name:
			continue
		if for_exit and not block.exit_signals.is_empty():
			return block_id
		if not for_exit and block.entry_signal != &"":
			return block_id
	return &""


## Węzeł graniczny krawędzi (stopień 1 w grafie) — punkt wejścia do świata.
func _outer_node_of(edge_id: StringName) -> StringName:
	var edge := station.graph.get_edge(edge_id)
	for candidate: StringName in [edge.from_node, edge.to_node]:
		var degree := 0
		for other_id: StringName in station.graph.edges:
			var other := station.graph.get_edge(other_id)
			if other.from_node == candidate or other.to_node == candidate:
				degree += 1
		if degree == 1:
			return candidate
	return edge.from_node


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
	if director != null:
		data["director"] = director.to_dict()
	if lever_frame != null:
		data["lever_frame"] = lever_frame.to_dict()
	var crossings_state := {}
	for crossing_id: StringName in crossings:
		crossings_state[String(crossing_id)] = (crossings[crossing_id] as LevelCrossing).to_dict()
	data["crossings"] = crossings_state
	var dsat_state := {}
	for dsat_id: StringName in dsats:
		dsat_state[String(dsat_id)] = (dsats[dsat_id] as Dsat).to_dict()
	data["dsats"] = dsat_state
	data["orders"] = orders.duplicate(true)
	data["register"] = register.to_dict()
	# Pełny save (F10): pociągi w drodze, procedury, łączność, AI sąsiadów,
	# RNG (jako tekst — stan to uint64, JSON gubi precyzję liczb 64-bit).
	var trains_out: Array = []
	for train: Train in trains:
		trains_out.append(train.to_dict())
	data["trains"] = trains_out
	var meta_out := {}
	for nr: String in _train_meta:
		var meta: Dictionary = (_train_meta[nr] as Dictionary).duplicate()
		meta.erase("entry")
		meta["entry_block"] = String(meta["entry_block"])
		meta["exit_block"] = String(meta["exit_block"])
		meta_out[nr] = meta
	data["train_meta"] = meta_out
	data["dsat_cases"] = _dsat_cases.duplicate(true)
	data["train_sz_prev"] = _train_sz_prev.duplicate(true)
	data["phone_clearance"] = _phone_clearance.duplicate(true)
	data["comms"] = comms.to_dict()
	data["train_log"] = train_log.to_dict()
	var neighbours_out := {}
	for ai: NeighbourAI in neighbours:
		neighbours_out[String(ai.block.id)] = ai.to_dict()
	data["neighbours"] = neighbours_out
	if traffic_gen != null:
		data["traffic_gen"] = traffic_gen.to_dict()
	data["rng"] = {"seed": str(rng.seed), "state": str(rng.state)}
	data["pending_confirm"] = {} if pending_confirm.is_empty() else {
		"name": String(pending_confirm["name"]),
		"args": (pending_confirm["args"] as Dictionary).duplicate(true),
	}
	data["confirm_left_s"] = _confirm_left_s
	data["shift_ended"] = _shift_ended
	data["order_counter"] = _order_counter
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
	if director != null and data.has("director"):
		director.from_dict(data["director"])
	if lever_frame != null and data.has("lever_frame"):
		lever_frame.from_dict(data["lever_frame"])
	var crossings_state: Dictionary = data.get("crossings", {})
	for key: String in crossings_state:
		if crossings.has(StringName(key)):
			(crossings[StringName(key)] as LevelCrossing).from_dict(crossings_state[key])
	var dsat_state: Dictionary = data.get("dsats", {})
	for key: String in dsat_state:
		if dsats.has(StringName(key)):
			(dsats[StringName(key)] as Dsat).from_dict(dsat_state[key])
	orders.assign(data.get("orders", []))
	if data.has("register"):
		register.from_dict(data["register"])
	# Pełny load (F10) — kolejność: rozkład już odtworzony wyżej, więc
	# można wiązać metadane pociągów i AI sąsiadów po numerach/blokach.
	if data.has("trains"):
		trains.clear()
		for train_data: Variant in (data["trains"] as Array):
			var train := Train.new()
			train.restore(station.graph, _signal_approach, train_data)
			for crossing_id: StringName in crossings:
				var crossing: LevelCrossing = crossings[crossing_id]
				for section_id: StringName in crossing.on_sections:
					train.crossings_by_section[section_id] = crossing
			trains.append(train)
		_train_cover = {}
		for train: Train in trains:
			if train.phase != Train.Phase.DONE:
				_train_cover.merge(train.covered_sections())
	if data.has("train_meta"):
		_train_meta.clear()
		for nr: String in (data["train_meta"] as Dictionary):
			var meta: Dictionary = (data["train_meta"] as Dictionary)[nr]
			meta = meta.duplicate()
			meta["entry_block"] = StringName(String(meta["entry_block"]))
			meta["exit_block"] = StringName(String(meta["exit_block"]))
			meta["entry"] = timetable.entry_by_nr(nr) if timetable != null else null
			_train_meta[nr] = meta
	_dsat_cases = (data.get("dsat_cases", _dsat_cases) as Dictionary).duplicate(true)
	_train_sz_prev = (data.get("train_sz_prev", _train_sz_prev) as Dictionary).duplicate(true)
	_phone_clearance = (data.get("phone_clearance", _phone_clearance) as Dictionary).duplicate(true)
	if data.has("comms"):
		comms.from_dict(data["comms"])
	if data.has("train_log"):
		train_log.from_dict(data["train_log"])
	if data.has("neighbours"):
		var neighbours_data: Dictionary = data["neighbours"]
		for ai: NeighbourAI in neighbours:
			ai.rebind_timetable(timetable)
			if neighbours_data.has(String(ai.block.id)):
				ai.from_dict(neighbours_data[String(ai.block.id)])
	if traffic_gen != null and data.has("traffic_gen"):
		traffic_gen.from_dict(data["traffic_gen"])
	if data.has("rng"):
		rng.seed = String((data["rng"] as Dictionary)["seed"]).to_int()
		rng.state = String((data["rng"] as Dictionary)["state"]).to_int()
	var confirm_data: Dictionary = data.get("pending_confirm", {})
	pending_confirm = {} if confirm_data.is_empty() else {
		"name": StringName(String(confirm_data["name"])),
		"args": (confirm_data["args"] as Dictionary).duplicate(true),
	}
	_confirm_left_s = float(data.get("confirm_left_s", 0.0))
	_shift_ended = bool(data.get("shift_ended", _shift_ended))
	_order_counter = int(data.get("order_counter", _order_counter))
