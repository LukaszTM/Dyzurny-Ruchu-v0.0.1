class_name Interlocking
extends RefCounted
## Silnik zależności wg docs/04-logika-zaleznosci.md: warunki utwierdzenia
## (§3), zamknięcia indywidualne (§4), sygnał zastępczy z licznikiem (§5),
## wybór obrazów sygnałowych (§6), zwalnianie sekcyjne i kasowanie (§2).
## Nastawianie indywidualne (docs/systemy/13 §2): gracz układa zwrotnice
## przyciskami, przycisk sygnałowy utwierdza przebieg dobrany do bieżącego
## położenia zwrotnic.

## Czas ewolucji doraźnego zwolnienia.
## TODO(weryfikacja): wartość zależna od typu urządzeń, przyjęto 90 s (docs/04 §2).
const EVOLUTION_TIME_S: float = 90.0
## Czas świecenia sygnału zastępczego.
## TODO(weryfikacja): Sz gaśnie po czasie (np. 90 s) lub po zajęciu pierwszej
## sekcji — zachowanie zależne od typu urządzeń (docs/04 §5); w F3 sam timer,
## gaszenie zajęciem sekcji dojdzie z pociągami (F4).
const SZ_TIME_S: float = 90.0
## Okno czasowe „uzbrojenia" przycisków współpracujących (dZw / zamknięcie
## zwrotnicy): po naciśnięciu przycisku specjalnego gracz wskazuje cel.
## TODO(weryfikacja): na pulpicie typu E przyciski współpracujące naciska się
## równocześnie; w grze przyjęto obsługę sekwencyjną z oknem 10 s.
const ARM_TIME_S: float = 10.0

var graph: TrackGraph
var aspect_table: AspectTable
var routes: Dictionary = {}   # StringName -> Route
## Blokady liniowe per szlak (StringName -> BlockLine) — wstrzykuje SimWorld;
## warunek 6 checklisty utwierdzenia (docs/04 §3) dla przebiegów wyjazdowych.
var block_lines: Dictionary = {}
## Przejazdy (StringName -> LevelCrossing) — wstrzykuje SimWorld;
## warunek 7 checklisty (docs/04 §3.7).
var crossings: Dictionary = {}
## Liczniki przycisków specjalnych: "dSz:A", "dZw" (docs/systemy/13 §4).
var counters: Dictionary = {}
## Aktywne sygnały zastępcze: id semafora -> pozostały czas.
var _sz_left: Dictionary = {}
## Uzbrojenie dZw: po naciśnięciu gracz wskazuje semafor przebiegu.
var _armed_emergency_left_s: float = 0.0
## Uzbrojenie zamknięcia indywidualnego: gracz wskazuje zwrotnicę.
var _armed_lock_left_s: float = 0.0


func _init(p_graph: TrackGraph, route_defs: Array[Dictionary], p_table: AspectTable) -> void:
	graph = p_graph
	aspect_table = p_table
	for def: Dictionary in route_defs:
		var route := Route.from_def(def)
		route.approach_section = _compute_approach_section(route)
		route.v_group = _compute_v_group(route)
		routes[route.id] = route
	update_signals()


func get_route(route_id: StringName) -> Route:
	return routes.get(route_id) as Route


## Wykonanie polecenia gracza (command pattern, docs/02-architektura.md).
func execute(name: StringName, args: Dictionary) -> CommandResult:
	var id := StringName(String(args.get("id", "")))
	match name:
		&"turnout_throw":
			return _cmd_turnout_throw(id)
		&"route_start":
			return _cmd_route_start(id)
		&"signal_cancel":
			return _cmd_signal_cancel(id)
		&"sub_signal":
			return _cmd_sub_signal(id)
		&"route_emergency_release":
			_armed_emergency_left_s = ARM_TIME_S
			_armed_lock_left_s = 0.0
			return CommandResult.failure(
				"dZw uzbrojone — wskaż przebieg przyciskiem sygnałowym (%.0f s)" % ARM_TIME_S
			)
		&"turnout_lock_toggle":
			_armed_lock_left_s = ARM_TIME_S
			_armed_emergency_left_s = 0.0
			return CommandResult.failure(
				"zamknięcie uzbrojone — wskaż zwrotnicę jej przyciskiem (%.0f s)" % ARM_TIME_S
			)
	return CommandResult.failure("nieznane polecenie: %s" % name)


# ---------------------------------------------------------------------------
# Polecenia
# ---------------------------------------------------------------------------

func _cmd_turnout_throw(turnout_id: StringName) -> CommandResult:
	if _armed_lock_left_s > 0.0:
		_armed_lock_left_s = 0.0
		return _toggle_individual_lock(turnout_id)
	var result := graph.throw_turnout(turnout_id)
	if result.ok:
		update_signals()
	return result


## Zamknięcie indywidualne zwrotnicy w bieżącym położeniu (docs/04 §4).
func _toggle_individual_lock(turnout_id: StringName) -> CommandResult:
	var turnout := graph.get_turnout(turnout_id)
	if turnout == null:
		return CommandResult.failure("zwrotnica %s nie istnieje" % turnout_id)
	if not turnout.closed_individually and not turnout.has_control():
		return CommandResult.failure(
			"zwrotnica %s bez kontroli położenia — nie można zamknąć" % turnout_id
		)
	turnout.closed_individually = not turnout.closed_individually
	return CommandResult.success()


## Przycisk sygnałowy: utwierdzenie przebiegu od wskazanego semafora
## (nastawianie indywidualne — przebieg wybierany po położeniu zwrotnic).
func _cmd_route_start(signal_id: StringName) -> CommandResult:
	if _armed_emergency_left_s > 0.0:
		_armed_emergency_left_s = 0.0
		return _emergency_release(signal_id)
	var signal_device := graph.get_signal(signal_id)
	if signal_device == null:
		return CommandResult.failure("sygnalizator %s nie istnieje" % signal_id)
	var candidate: Route = null
	var any_route := false
	for route_id: StringName in routes:
		var route: Route = routes[route_id]
		if route.entry_signal != signal_id:
			continue
		any_route = true
		if route.is_active():
			return CommandResult.failure("przebieg %s od semafora %s już nastawiony" % [route.id, signal_id])
		if _turnouts_match(route.turnouts_req):
			candidate = route
			break
	if not any_route:
		return CommandResult.failure("brak przebiegów od semafora %s w tablicy zależności" % signal_id)
	if candidate == null:
		return CommandResult.failure(
			"zwrotnice nie są ułożone dla żadnego przebiegu od semafora %s" % signal_id
		)
	var check := _check_lock_conditions(candidate)
	if not check.ok:
		return check
	_lock_route(candidate)
	update_signals()
	return CommandResult.success()


## Warunki utwierdzenia — checklista docs/04 §3 (konflikty sprawdzane
## pierwsze, żeby odmowa niosła pierwotną przyczynę, nie skutek zamknięć).
func _check_lock_conditions(route: Route) -> CommandResult:
	# 4. Brak przebiegu sprzecznego w stanie ≥ SETTING.
	for conflict_id: StringName in route.conflicts:
		var conflict := get_route(conflict_id)
		if conflict != null and conflict.is_active():
			return CommandResult.failure("przebieg sprzeczny %s jest nastawiony" % conflict_id)
	# 1. Sekcje drogi jazdy wolne i nieutwierdzone. Odstępy blokady
	#    samoczynnej ocenia warunek 6 (wyprawianie za pociągiem wymaga
	#    tylko wolnego pierwszego odstępu — docs/systemy/15 §2).
	var auto_odstepy: Array[StringName] = []
	if route.block_id != &"" and block_lines.has(route.block_id):
		var route_block: BlockLine = block_lines[route.block_id]
		if route_block.automatic:
			auto_odstepy = route_block.odstepy
	for section_id: StringName in route.sections:
		if auto_odstepy.has(section_id):
			continue
		var section := graph.get_section(section_id)
		if section == null:
			return CommandResult.failure("przebieg %s: sekcja %s nie istnieje" % [route.id, section_id])
		if section.occupied:
			return CommandResult.failure("sekcja %s zajęta" % section_id)
		if section.is_locked():
			return CommandResult.failure("sekcja %s utwierdzona w przebiegu %s" % [section_id, section.locked_by])
	# 2. Zwrotnice drogi jazdy: wymagane położenie z kontrolą, nieutwierdzone.
	#    Zamknięcie indywidualne w wymaganym położeniu nie przeszkadza (§4).
	var turnout_check := _check_turnout_group(route.turnouts_req, "drogi jazdy")
	if not turnout_check.ok:
		return turnout_check
	# 3. Ochrona boczna: zwrotnice ochronne w położeniu ochronnym,
	#    sygnalizatory osłaniające na „stój".
	var flank_check := _check_turnout_group(route.flank_turnouts, "ochrony bocznej")
	if not flank_check.ok:
		return flank_check
	for signal_id: StringName in route.flank_signals:
		var flank_signal := graph.get_signal(signal_id)
		if flank_signal == null or not flank_signal.shows_stop():
			return CommandResult.failure(
				"sygnalizator osłaniający %s nie wskazuje „stój”" % signal_id
			)
	# 5. Droga ochronna wolna i możliwa do zamknięcia.
	for section_id: StringName in route.overlap_sections:
		var section := graph.get_section(section_id)
		if section == null or section.occupied:
			return CommandResult.failure("sekcja drogi ochronnej %s zajęta" % section_id)
		if section.is_locked():
			return CommandResult.failure(
				"sekcja drogi ochronnej %s utwierdzona w przebiegu %s" % [section_id, section.locked_by]
			)
	var overlap_check := _check_turnout_group(route.overlap_turnouts, "drogi ochronnej")
	if not overlap_check.ok:
		return overlap_check
	# 6. Blokada liniowa pozwala wyprawić: pozwolenie u gracza, odstęp wolny
	#    (docs/systemy/15 §1).
	if route.block_id != &"" and block_lines.has(route.block_id):
		var dispatch := (block_lines[route.block_id] as BlockLine).can_dispatch()
		if not dispatch.ok:
			return dispatch
	# 7. Przejazdy kat. A w drodze przebiegu zamknięte, ssp sprawne
	#    (docs/04 §3.7, docs/systemy/16 §2–§3).
	for crossing_id: StringName in crossings:
		var crossing: LevelCrossing = crossings[crossing_id]
		var in_route := false
		for section_id: StringName in crossing.on_sections:
			if route.sections.has(section_id):
				in_route = true
				break
		if not in_route:
			continue
		if not crossing.is_automatic() and not crossing.is_closed():
			return CommandResult.failure(
				"przejazd %s w drodze przebiegu nie jest zamknięty" % crossing_id
			)
		if crossing.state == LevelCrossing.State.FAILURE:
			return CommandResult.failure(
				"przejazd %s w awarii — jazda na Sz/rozkaz z ostrzeżeniem" % crossing_id
			)
	return CommandResult.success()


func _check_turnout_group(required: Dictionary, group_name: String) -> CommandResult:
	for turnout_id: StringName in required:
		var turnout := graph.get_turnout(turnout_id)
		if turnout == null:
			return CommandResult.failure("zwrotnica %s nie istnieje" % turnout_id)
		if not turnout.has_control():
			return CommandResult.failure(
				"zwrotnica %s (%s) bez kontroli położenia" % [turnout_id, group_name]
			)
		var required_pos: Const.TurnoutPos = required[turnout_id]
		var in_plus := turnout.is_plus()
		if (required_pos == Const.TurnoutPos.PLUS) != in_plus:
			return CommandResult.failure(
				"zwrotnica %s (%s) w złym położeniu" % [turnout_id, group_name]
			)
		if turnout.locked_by != &"":
			return CommandResult.failure(
				"zwrotnica %s utwierdzona w przebiegu %s" % [turnout_id, turnout.locked_by]
			)
	return CommandResult.success()


## Utwierdzenie: zamknięcie zwrotnic i sekcji drogi, ochrony i drogi ochronnej.
func _lock_route(route: Route) -> void:
	route.reset_runtime()
	route.state = Const.RouteState.LOCKED
	for section_id: StringName in route.sections:
		graph.get_section(section_id).locked_by = route.id
	for section_id: StringName in route.overlap_sections:
		graph.get_section(section_id).locked_by = route.id
	for turnout_id: StringName in route.turnouts_req:
		graph.get_turnout(turnout_id).locked_by = route.id
	for turnout_id: StringName in route.flank_turnouts:
		graph.get_turnout(turnout_id).locked_by = route.id
	for turnout_id: StringName in route.overlap_turnouts:
		graph.get_turnout(turnout_id).locked_by = route.id


## Kasowanie przebiegu przyciskiem sygnałowym (pociągnięcie) — docs/04 §2:
## przy wolnej sekcji zbliżania natychmiastowe; przy zajętej wymaga dZw.
func _cmd_signal_cancel(signal_id: StringName) -> CommandResult:
	var route := _active_route_from(signal_id)
	if route == null:
		return CommandResult.failure("brak nastawionego przebiegu od semafora %s" % signal_id)
	if route.state != Const.RouteState.LOCKED:
		return CommandResult.failure("pociąg w drodze przebiegu %s — kasowanie niemożliwe" % route.id)
	var approach := graph.get_section(route.approach_section)
	if approach != null and approach.occupied:
		return CommandResult.failure(
			"sekcja zbliżania %s zajęta — wymagane doraźne zwolnienie (dZw)" % approach.id
		)
	_release_route(route)
	update_signals()
	return CommandResult.success()


## Doraźne zwolnienie (dZw + przycisk sygnałowy): semafor na „stój",
## czas ewolucji, licznik, potem zwolnienie (docs/04 §2, systemy/13 §4).
func _emergency_release(signal_id: StringName) -> CommandResult:
	var route := _active_route_from(signal_id)
	if route == null:
		return CommandResult.failure("brak nastawionego przebiegu od semafora %s" % signal_id)
	if route.state != Const.RouteState.LOCKED:
		return CommandResult.failure("pociąg w drodze przebiegu %s" % route.id)
	route.state = Const.RouteState.CANCELLED
	route.cancel_left_s = EVOLUTION_TIME_S
	counters["dZw"] = int(counters.get("dZw", 0)) + 1
	update_signals()
	return CommandResult.success()


## Sygnał zastępczy z licznikiem (docs/04 §5): warunek — semafor na „stój".
func _cmd_sub_signal(signal_id: StringName) -> CommandResult:
	var signal_device := graph.get_signal(signal_id)
	if signal_device == null:
		return CommandResult.failure("sygnalizator %s nie istnieje" % signal_id)
	if not signal_device.can_sz:
		return CommandResult.failure("semafor %s nie ma sygnału zastępczego" % signal_id)
	if signal_device.aspect == &"Sz":
		return CommandResult.failure("Sz na semaforze %s już podany" % signal_id)
	if not signal_device.shows_stop():
		return CommandResult.failure("semafor %s nie wskazuje „stój”" % signal_id)
	counters["dSz:%s" % signal_id] = int(counters.get("dSz:%s" % signal_id, 0)) + 1
	_sz_left[signal_id] = SZ_TIME_S
	update_signals()
	return CommandResult.success()


func _active_route_from(signal_id: StringName) -> Route:
	for route_id: StringName in routes:
		var route: Route = routes[route_id]
		if route.entry_signal == signal_id and route.is_active():
			return route
	return null


func _turnouts_match(required: Dictionary) -> bool:
	for turnout_id: StringName in required:
		var turnout := graph.get_turnout(turnout_id)
		if turnout == null or not turnout.has_control():
			return false
		var required_pos: Const.TurnoutPos = required[turnout_id]
		if (required_pos == Const.TurnoutPos.PLUS) != turnout.is_plus():
			return false
	return true


# ---------------------------------------------------------------------------
# Tick: zwalnianie sekcyjne, timery, obrazy sygnałowe
# ---------------------------------------------------------------------------

func tick(dt: float) -> void:
	_armed_emergency_left_s = maxf(0.0, _armed_emergency_left_s - dt)
	_armed_lock_left_s = maxf(0.0, _armed_lock_left_s - dt)
	# Timery sygnałów zastępczych.
	for signal_id: StringName in _sz_left.keys():
		_sz_left[signal_id] = float(_sz_left[signal_id]) - dt
		if float(_sz_left[signal_id]) <= 0.0:
			_sz_left.erase(signal_id)
	for route_id: StringName in routes:
		_tick_route(routes[route_id], dt)
	update_signals()


func _tick_route(route: Route, dt: float) -> void:
	match route.state:
		Const.RouteState.LOCKED:
			# Czoło pociągu na pierwszej sekcji → TRAIN_ON, semafor na „stój"
			# (docs/04 §2/§6.4; obraz przelicza update_signals).
			var first := graph.get_section(route.sections[0])
			if first != null and first.occupied:
				route.state = Const.RouteState.TRAIN_ON
				route.passed[0] = true
		Const.RouteState.TRAIN_ON, Const.RouteState.RELEASING:
			_sectional_release(route, dt)
		Const.RouteState.CANCELLED:
			route.cancel_left_s -= dt
			if route.cancel_left_s <= 0.0:
				_release_route(route)


## Zwalnianie sekcyjne (docs/04 §2): sekcja zwalnia się, gdy była zajęta
## i zwolniona przez pociąg, a sekcja poprzednia już zwolniona.
func _sectional_release(route: Route, dt: float) -> void:
	for i: int in route.sections.size():
		var section := graph.get_section(route.sections[i])
		if section == null:
			continue
		if section.occupied:
			route.passed[i] = true
		if route.passed[i] and not route.released[i] and not section.occupied \
				and (i == 0 or route.released[i - 1]):
			route.released[i] = true
			route.state = Const.RouteState.RELEASING
			_unlock_section_and_turnouts(route, route.sections[i])
	var last_section := graph.get_section(route.sections[route.sections.size() - 1])
	var last_occupied := last_section != null and last_section.occupied
	if not route.main_path_done(last_occupied):
		return
	# Droga jazdy wykorzystana: zdejmij utwierdzenie z pozostałych sekcji
	# (zajętość toru docelowego nadal chroni) i zwolnij drogę ochronną:
	# natychmiast przy zajętym torze docelowym albo po timerze release_s
	# (docs/04 §2).
	for section_id: StringName in route.sections:
		var section := graph.get_section(section_id)
		if section != null and section.locked_by == route.id:
			section.locked_by = &""
	for turnout_id: StringName in route.turnouts_req:
		_unlock_turnout(route, turnout_id)
	if not route.has_overlap:
		_release_route(route)
		return
	if last_occupied:
		_release_route(route)
		return
	if not route.overlap_timer_running:
		route.overlap_timer_running = true
		route.overlap_left_s = route.overlap_release_s
	route.overlap_left_s -= dt
	if route.overlap_left_s <= 0.0:
		_release_route(route)


func _unlock_section_and_turnouts(route: Route, section_id: StringName) -> void:
	var section := graph.get_section(section_id)
	if section != null and section.locked_by == route.id:
		section.locked_by = &""
	if section != null and section.turnout_id != &"":
		_unlock_turnout(route, section.turnout_id)


func _unlock_turnout(route: Route, turnout_id: StringName) -> void:
	var turnout := graph.get_turnout(turnout_id)
	if turnout != null and turnout.locked_by == route.id:
		turnout.locked_by = &""


## Pełne zwolnienie przebiegu — wszystkie elementy wracają do stanu wolnego.
func _release_route(route: Route) -> void:
	for section_id: StringName in route.sections:
		var section := graph.get_section(section_id)
		if section != null and section.locked_by == route.id:
			section.locked_by = &""
	for section_id: StringName in route.overlap_sections:
		var section := graph.get_section(section_id)
		if section != null and section.locked_by == route.id:
			section.locked_by = &""
	for turnout_id: StringName in route.turnouts_req:
		_unlock_turnout(route, turnout_id)
	for turnout_id: StringName in route.flank_turnouts:
		_unlock_turnout(route, turnout_id)
	for turnout_id: StringName in route.overlap_turnouts:
		_unlock_turnout(route, turnout_id)
	route.reset_runtime()


## Przeliczenie obrazów wszystkich sygnalizatorów (docs/04 §6).
func update_signals() -> void:
	# Dwa przejścia: najpierw wszystkie semafory (obraz wyjazdowego jest
	# potrzebny wjazdowemu jako next_info), potem tarcze i powtarzacze.
	for pass_index: int in 2:
		for signal_id: StringName in graph.signals:
			var signal_device := graph.get_signal(signal_id)
			if signal_device.sbl:
				# Semafory odstępowe sbl ustawia BlockLine (zajętość).
				continue
			if signal_device.kind == Const.SignalKind.SEMAFOR \
					or signal_device.kind == Const.SignalKind.SEMAFOR_KSZTALTOWY:
				signal_device.set_aspect(_semaphore_aspect(signal_device))
	for signal_id: StringName in graph.signals:
		var signal_device := graph.get_signal(signal_id)
		match signal_device.kind:
			Const.SignalKind.TARCZA_OSTRZEGAWCZA:
				signal_device.set_aspect(_linked_aspect(signal_device, true))
			Const.SignalKind.POWTARZACZ:
				signal_device.set_aspect(_linked_aspect(signal_device, false))
			_:
				pass


func _semaphore_aspect(signal_device: SignalDevice) -> StringName:
	# Sz ma pierwszeństwo (podany ręcznie na semaforze wskazującym „stój").
	if _sz_left.has(signal_device.id):
		return &"Sz"
	var route := _locked_route_from(signal_device.id)
	# Semafor kształtowy: Sr2 na wprost, Sr3 w bok (docs/systemy/11 §7);
	# brak obrazów pośrednich — informacja o następniku nie występuje.
	if signal_device.kind == Const.SignalKind.SEMAFOR_KSZTALTOWY:
		if route == null:
			return &"Sr1"
		return &"Sr2" if route.v_group == "MAX" else &"Sr3"
	if route == null:
		return &"S1"
	var next_info := "STOP"
	if route.exit_signal != &"":
		var next_signal := graph.get_signal(route.exit_signal)
		if next_signal != null and not next_signal.failed:
			next_info = aspect_table.info_class(next_signal.aspect)
	elif route.block_id != &"" and block_lines.has(route.block_id):
		# Semafor wyjazdowy na szlak z blokadą samoczynną: wg stanu
		# pierwszego odstępu / wskazania semafora odstępowego (docs/04 §6).
		var block: BlockLine = block_lines[route.block_id]
		if block.automatic:
			if block.occupied:
				next_info = "STOP"
			else:
				var line_signal := graph.get_signal(block.first_line_signal())
				if line_signal != null:
					next_info = aspect_table.info_class(line_signal.aspect)
	return aspect_table.pick(route.v_group, next_info, signal_device)


## Przebieg pociągowy LOCKED od semafora, z ważną kontrolą zwrotnic —
## utrata kontroli (rozprucie, usterka) natychmiast gasi sygnał zezwalający.
func _locked_route_from(signal_id: StringName) -> Route:
	for route_id: StringName in routes:
		var route: Route = routes[route_id]
		if route.entry_signal != signal_id or route.state != Const.RouteState.LOCKED:
			continue
		if not route.is_train:
			continue
		if not _turnouts_match(route.turnouts_req) \
				or not _turnouts_match(route.flank_turnouts) \
				or not _turnouts_match(route.overlap_turnouts):
			return null
		return route
	return null


func _linked_aspect(signal_device: SignalDevice, is_warning: bool) -> StringName:
	var semaphore := graph.get_signal(signal_device.for_signal)
	var semaphore_aspect: StringName = &"S1"
	if semaphore != null and not semaphore.failed:
		semaphore_aspect = semaphore.aspect
	if is_warning:
		return aspect_table.warning_aspect(semaphore_aspect)
	return aspect_table.repeater_aspect(semaphore_aspect)


# ---------------------------------------------------------------------------
# Wyliczenia pomocnicze przy budowie
# ---------------------------------------------------------------------------

## Sekcja zbliżania przebiegu: sekcja przed semaforem początkowym.
## Przy zwrotnicy w węźle semafora — krawędź pary połączeń nieużyta
## przez drogę jazdy; inaczej krawędź dochodząca wg kierunku sygnalizatora.
func _compute_approach_section(route: Route) -> StringName:
	var signal_device := graph.get_signal(route.entry_signal)
	if signal_device == null or signal_device.at_node == &"":
		return &""
	var node := signal_device.at_node
	for turnout_id: StringName in route.turnouts_req:
		var turnout := graph.get_turnout(turnout_id)
		if turnout == null or turnout.node_id != node:
			continue
		var required_pos: Const.TurnoutPos = route.turnouts_req[turnout_id]
		var pair_edge := turnout.edge_plus \
			if required_pos == Const.TurnoutPos.PLUS else turnout.edge_minus
		var root_section := graph.section_for_edge(turnout.edge_root)
		if root_section != null and route.sections.has(root_section.id):
			var pair_section := graph.section_for_edge(pair_edge)
			return pair_section.id if pair_section != null else &""
		return root_section.id if root_section != null else &""
	for edge_id: StringName in graph.edges:
		var edge := graph.get_edge(edge_id)
		var arrives := edge.to_node == node \
			if signal_device.dir == &"N" else edge.from_node == node
		if not arrives:
			continue
		var section := graph.section_for_edge(edge_id)
		if section != null and not route.sections.has(section.id):
			return section.id
	return &""


## Grupa prędkości drogi przebiegu (docs/04 §6) — z geometrii rozjazdów:
## najmniejsze v_minus_kmh zwrotnic drogi jazdy w położeniu zwrotnym;
## wszystkie na wprost → MAX.
## TODO(weryfikacja): docs/04 §6 wskazuje pole v_route_kmh, ale semafory
## Borek nie mają pasów świetlnych i jazda na wprost przy 100 km/h musi
## dawać grupę MAX — przyjęto wyliczanie z geometrii (v_minus zwrotnic),
## pole v_route_kmh traktowane informacyjnie.
func _compute_v_group(route: Route) -> String:
	var v_min: int = 9999
	for turnout_id: StringName in route.turnouts_req:
		if route.turnouts_req[turnout_id] == Const.TurnoutPos.MINUS:
			var turnout := graph.get_turnout(turnout_id)
			if turnout != null:
				v_min = mini(v_min, turnout.v_minus_kmh)
	if v_min == 9999:
		return "MAX"
	if v_min >= 100:
		return "100"
	if v_min >= 60:
		return "60"
	return "40"


# ---------------------------------------------------------------------------
# Snapshot
# ---------------------------------------------------------------------------

func to_dict() -> Dictionary:
	var route_states := {}
	for route_id: StringName in routes:
		route_states[String(route_id)] = (routes[route_id] as Route).to_dict()
	var sz := {}
	for signal_id: StringName in _sz_left:
		sz[String(signal_id)] = _sz_left[signal_id]
	return {
		"routes": route_states,
		"counters": counters.duplicate(),
		"sz_left": sz,
	}


func from_dict(data: Dictionary) -> void:
	var route_states: Dictionary = data.get("routes", {})
	for key: String in route_states:
		var route := get_route(StringName(key))
		if route != null:
			route.from_dict(route_states[key])
	counters = (data.get("counters", {}) as Dictionary).duplicate()
	_sz_left.clear()
	var sz: Dictionary = data.get("sz_left", {})
	for key: String in sz:
		_sz_left[StringName(key)] = float(sz[key])
	update_signals()
