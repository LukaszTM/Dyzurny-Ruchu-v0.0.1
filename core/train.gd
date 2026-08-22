class_name Train
extends RefCounted
## Pociąg: punkt materialny z długością + AI maszynisty
## (docs/05-symulacja-ruchu.md §1–§2). Jedzie po ścieżce budowanej
## przyrostowo z grafu (krawędzie + wirtualne odcinki zwrotnicowe),
## zajmuje sekcje czołem, zwalnia końcem składu.

## Stan pociągu w świecie.
enum Phase { RUNNING, DWELL, DONE }

## Zatrzymanie przed semaforem „stój": ~50 m przed (docs/05 §2).
const STOP_BEFORE_SIGNAL_M: float = 50.0
## Margines zatrzymania, gdy pociąg już minął punkt 50 m przed semaforem.
const STOP_AT_SIGNAL_M: float = 2.0
## Jak daleko w przód budujemy ścieżkę i „widzimy" sygnały. Krzywa
## hamowania liczona bez limitu widoczności — realnie zapewnia to tarcza
## ostrzegawcza na drodze hamowania (docs/05 §2).
const LOOKAHEAD_M: float = 900.0
## Minimalny postój handlowy (docs/05 §2.3).
const MIN_DWELL_S: float = 30.0
## Ograniczenie prędkości przy jeździe na Sz (docs/05 §2; systemy/11 §3).
const SZ_LIMIT_MS: float = 40.0 / 3.6
## Hamowanie nagłe (docs/05 §1).
const BRAKE_EMERGENCY: float = 1.0

var nr: String = ""
var kind: String = "osobowy"
var length_m: float = 100.0
var vmax_ms: float = 27.8
var accel_base: float = 0.4
var brake_service: float = 0.5
var wants_stop: bool = true
var dep_time_s: float = 0.0

var phase: Phase = Phase.RUNNING
## Pozycja czoła w metrach wzdłuż ścieżki.
var front_m: float = 0.0
var v_ms: float = 0.0
## Jazda na Sz: limit 40 km/h do minięcia następnego semafora.
var sz_authority: bool = false
## Rozkazy pisemne „S" (docs/systemy/18 §5): semafory, które wolno minąć
## na „stój" (id → true); zużywane przy minięciu.
var pass_orders: Dictionary = {}
## Ograniczenie prędkości z rozkazu „O" (INF = brak).
## TODO(weryfikacja): zakres obowiązywania rozkazu O — przyjęto do końca
## jazdy przez stację (docs/systemy/18 §5, uproszczenie F6).
var order_speed_cap_ms: float = INF
## Koniec postoju handlowego (sekundy doby); 0 = jeszcze nie wyliczony.
var dwell_until_s: float = 0.0
var dwell_done: bool = false

## Segmenty ścieżki: {start, len, vmax_ms, section: StringName,
## turnout: StringName, from_edge, chosen_branch, entered: bool}.
var path: Array[Dictionary] = []
## Semafory na ścieżce: {pos, signal: StringName, passed: bool}.
var signal_points: Array[Dictionary] = []
## Punkt zatrzymania handlowego (środek pierwszej sekcji torowej), -1 = brak.
var dwell_point_m: float = -1.0

var _graph: TrackGraph = null
## Mapa semafor → sekcja zbliżania (z tablicy przebiegów).
var _signal_approach: Dictionary = {}
## Węzeł, w którym ścieżka się skończy przy następnym wydłużeniu.
var _next_node: StringName = &""
## Krawędź, którą dojechaliśmy do _next_node.
var _prev_edge: StringName = &""
## Świat się skończył — za ostatnią krawędzią pociąg znika.
var _path_ended: bool = false


static func from_entry(entry: Timetable.Entry) -> Train:
	var train := Train.new()
	train.nr = entry.nr
	train.kind = entry.kind
	train.length_m = entry.len_m
	train.vmax_ms = float(entry.vmax_kmh) / 3.6
	train.wants_stop = entry.stop
	train.dep_time_s = float(entry.dep_s)
	# Przyspieszenia wg docs/05 §1: EZT 0,7; osobowy 0,4; towarowy 0,15.
	if entry.power_class == "EZT":
		train.accel_base = 0.7
	elif entry.kind == "towarowy":
		train.accel_base = 0.15
	else:
		train.accel_base = 0.4
	train.brake_service = 0.3 if entry.kind == "towarowy" else 0.5
	return train


## Ustawia pociąg na krawędzi wjazdowej (czoło na początku krawędzi).
func place_on_entry(graph: TrackGraph, signal_approach: Dictionary,
		entry_edge: StringName, entry_node: StringName) -> void:
	_graph = graph
	_signal_approach = signal_approach
	var edge := graph.get_edge(entry_edge)
	_append_edge_segment(edge, entry_node)
	front_m = 0.0


func path_length() -> float:
	if path.is_empty():
		return 0.0
	var last: Dictionary = path[path.size() - 1]
	return float(last["start"]) + float(last["len"])


func rear_m() -> float:
	return front_m - length_m


# ---------------------------------------------------------------------------
# Tick
# ---------------------------------------------------------------------------

func tick(dt: float, time_of_day_s: float) -> void:
	if phase == Phase.DONE:
		return
	_extend_path_if_needed()
	if phase == Phase.DWELL:
		if time_of_day_s >= dwell_until_s:
			phase = Phase.RUNNING
			dwell_done = true
		else:
			return
	_drive(dt, time_of_day_s)
	_check_segment_entries()
	if _path_ended and rear_m() >= path_length():
		phase = Phase.DONE


## Regulator prędkości: cel = min(vmax pociągu, vmax toru, krzywa hamowania
## do najbliższego punktu zatrzymania) — docs/05 §2.
func _drive(dt: float, time_of_day_s: float) -> void:
	var limit := minf(vmax_ms, _current_speed_limit())
	limit = minf(limit, order_speed_cap_ms)
	if sz_authority:
		limit = minf(limit, SZ_LIMIT_MS)
	var stop_at := _nearest_stop_point()
	var target := minf(limit, _sz_approach_limit())
	var brake_rate := brake_service
	if stop_at >= 0.0:
		var distance := stop_at - front_m
		if distance <= 0.05:
			front_m = maxf(front_m, stop_at)
			v_ms = 0.0
			_maybe_start_dwell(stop_at, time_of_day_s)
			return
		# Hamowanie nagłe, gdy służbowe już nie wystarczy (np. skasowanie
		# przebiegu przed pociągiem — docs/05 §2.4).
		var needed := (v_ms * v_ms) / (2.0 * distance)
		if needed > brake_service * 1.05:
			brake_rate = BRAKE_EMERGENCY
		target = minf(target, sqrt(2.0 * brake_service * distance))
	if v_ms < target:
		var a := accel_base * (1.0 - v_ms / maxf(vmax_ms, 0.1))
		v_ms = minf(v_ms + a * dt, target)
	elif v_ms > target:
		v_ms = maxf(v_ms - brake_rate * dt, target)
	front_m += v_ms * dt
	if stop_at >= 0.0 and front_m >= stop_at:
		front_m = stop_at
		v_ms = 0.0
		_maybe_start_dwell(stop_at, time_of_day_s)


## Najbliższy obowiązujący punkt zatrzymania przed czołem (-1 = brak):
## semafor wskazujący „stój" albo miejsce postoju handlowego.
func _nearest_stop_point() -> float:
	var nearest := -1.0
	if wants_stop and not dwell_done and dwell_point_m >= 0.0 and front_m <= dwell_point_m:
		nearest = dwell_point_m
	for point: Dictionary in signal_points:
		if bool(point["passed"]):
			continue
		var pos := float(point["pos"])
		if pos < front_m - 0.5:
			_pass_signal(point)
			continue
		var signal_device := _graph.get_signal(point["signal"])
		if signal_device == null:
			continue
		if signal_device.aspect == &"Sz" or not signal_device.shows_stop() \
				or pass_orders.has(signal_device.id):
			# Sygnał zezwalający / Sz / rozkaz „S": minięcie odnotowujemy,
			# gdy czoło przekroczy słupek.
			if front_m >= pos - 0.5:
				_pass_signal(point)
			continue
		var stop_at := pos - STOP_BEFORE_SIGNAL_M
		if front_m > stop_at:
			stop_at = pos - STOP_AT_SIGNAL_M
		if nearest < 0.0 or stop_at < nearest:
			nearest = stop_at
	return nearest


## Krzywa zwalniania przed semaforem z Sz albo mijanym na rozkaz „S":
## pociąg ma go minąć już z prędkością ≤40 km/h (docs/05 §2).
func _sz_approach_limit() -> float:
	var allowed := INF
	for point: Dictionary in signal_points:
		if bool(point["passed"]):
			continue
		var pos := float(point["pos"])
		if pos < front_m:
			continue
		var signal_device := _graph.get_signal(point["signal"])
		if signal_device == null:
			continue
		var restricted := signal_device.aspect == &"Sz" \
			or (signal_device.shows_stop() and pass_orders.has(signal_device.id))
		if not restricted:
			continue
		var distance := pos - front_m
		allowed = minf(allowed,
			sqrt(SZ_LIMIT_MS * SZ_LIMIT_MS + 2.0 * brake_service * distance))
	return allowed


func _pass_signal(point: Dictionary) -> void:
	point["passed"] = true
	var signal_device := _graph.get_signal(point["signal"])
	if signal_device == null:
		sz_authority = false
		return
	var by_order := pass_orders.has(signal_device.id) and signal_device.shows_stop()
	if by_order:
		# Rozkaz „S" zużywa się przy minięciu semafora (docs/systemy/18 §5).
		# TODO(weryfikacja): prędkość za rozkazem „S" — przyjęto reżim jak
		# przy Sz (≤40 km/h do następnego semafora).
		pass_orders.erase(signal_device.id)
	# Jazda na Sz/rozkaz: limit 40 km/h do minięcia następnego semafora
	# (docs/05 §2, TODO(weryfikacja) — reżim wg Ir-1 §61).
	sz_authority = signal_device.aspect == &"Sz" or by_order


## Sekcje na ścieżce od czoła do najbliższego semafora (do proceduralnej
## oceny jazdy na Sz — sprawdzenie, czy droga za semaforem nie jest zajęta).
func sections_ahead_to_next_signal() -> Array[StringName]:
	var until := path_length()
	for point: Dictionary in signal_points:
		if not bool(point["passed"]) and float(point["pos"]) > front_m + 0.5:
			until = float(point["pos"])
			break
	var result: Array[StringName] = []
	for segment: Dictionary in path:
		var start := float(segment["start"])
		if start + float(segment["len"]) <= front_m or start >= until:
			continue
		var section_id: StringName = segment["section"]
		if section_id != &"" and not result.has(section_id):
			result.append(section_id)
	return result


## Limit prędkości bieżącego segmentu (vmax toru / zwrotnicy).
func _current_speed_limit() -> float:
	for segment: Dictionary in path:
		var start := float(segment["start"])
		if front_m >= start and front_m < start + float(segment["len"]):
			return float(segment["vmax_ms"])
	return vmax_ms


func _maybe_start_dwell(stop_at: float, time_of_day_s: float) -> void:
	if not wants_stop or dwell_done or dwell_point_m < 0.0:
		return
	if absf(stop_at - dwell_point_m) > 0.5:
		return
	phase = Phase.DWELL
	dwell_until_s = maxf(dep_time_s, time_of_day_s + MIN_DWELL_S)


# ---------------------------------------------------------------------------
# Ścieżka
# ---------------------------------------------------------------------------

func _extend_path_if_needed() -> void:
	while not _path_ended and path_length() - front_m < LOOKAHEAD_M:
		if _stop_signal_blocks_extension():
			return
		if not _extend_once():
			return


## Nie budujemy ścieżki za semafor wskazujący „stój" — droga za nim jest
## nieznana, dopóki dyżurny jej nie nastawi (zwrotnice mogą się zmieniać).
func _stop_signal_blocks_extension() -> bool:
	for point: Dictionary in signal_points:
		if bool(point["passed"]):
			continue
		if float(point["pos"]) >= path_length() - 0.5:
			var signal_device := _graph.get_signal(point["signal"])
			if signal_device != null and signal_device.shows_stop() \
					and signal_device.aspect != &"Sz":
				return true
	return false


func _extend_once() -> bool:
	if _next_node == &"":
		_path_ended = true
		return false
	var node := _next_node
	var turnout := _turnout_at(node)
	var next_edge_id: StringName = &""
	if turnout != null:
		var branch_pos := _branch_of(turnout, _prev_edge)
		var chosen: StringName
		if _prev_edge == turnout.edge_root:
			# Jazda „na ostrze": kierunek wg fizycznego położenia iglic.
			chosen = turnout.edge_plus \
				if turnout.physical_pos() == Const.TurnoutPos.PLUS else turnout.edge_minus
		else:
			# Jazda z boku: zawsze na krawędź korzeniową (ew. rozprucie
			# sprawdzane przy fizycznym wjeździe czoła).
			chosen = turnout.edge_root
		var section := _graph.section_for_turnout(turnout.id)
		var seg_vmax := float(turnout.v_minus_kmh) / 3.6 \
			if _uses_minus_branch(turnout, _prev_edge, chosen) else vmax_ms
		path.append({
			"start": path_length(),
			"len": section.len_m if section != null and section.len_m > 0.0 else 30.0,
			"vmax_ms": seg_vmax,
			"section": section.id if section != null else &"",
			"turnout": turnout.id,
			"from_edge": _prev_edge,
			"from_branch": branch_pos,
			"chosen": chosen,
			"entered": false,
		})
		next_edge_id = chosen
	else:
		for edge_id: StringName in _graph.edges:
			var edge := _graph.get_edge(edge_id)
			if edge_id != _prev_edge and (edge.from_node == node or edge.to_node == node):
				next_edge_id = edge_id
				break
		if next_edge_id == &"":
			_path_ended = true
			return false
	_append_edge_segment(_graph.get_edge(next_edge_id), node)
	return true


func _append_edge_segment(edge: TrackGraph.Edge, enter_node: StringName) -> void:
	var travelling_n := edge.from_node == enter_node
	var far_node := edge.to_node if travelling_n else edge.from_node
	var section := _graph.section_for_edge(edge.id)
	path.append({
		"start": path_length(),
		"len": edge.len_m,
		"vmax_ms": float(edge.vmax_kmh) / 3.6,
		"section": section.id if section != null else &"",
		"turnout": &"",
		"entered": false,
	})
	_register_signal_at(far_node, &"N" if travelling_n else &"P",
		section.id if section != null else &"", path_length())
	_prev_edge = edge.id
	_next_node = far_node
	# Punkt zatrzymania handlowego: środek pierwszej sekcji torowej (W4
	# w uproszczeniu F4 — perony/wskaźniki dojdą później).
	if dwell_point_m < 0.0 and section != null and section.type == Const.SectionType.TRACK:
		var last: Dictionary = path[path.size() - 1]
		dwell_point_m = float(last["start"]) + float(last["len"]) / 2.0


## Semafor ważny dla naszej jazdy w węźle: kierunek zgodny, sekcja
## zbliżania (z tablicy przebiegów) równa sekcji, z której nadjeżdżamy.
func _register_signal_at(node: StringName, dir: StringName,
		from_section: StringName, at_pos: float) -> void:
	for signal_id: StringName in _graph.signals:
		var signal_device := _graph.get_signal(signal_id)
		if signal_device.at_node != node or signal_device.dir != dir:
			continue
		if signal_device.kind != Const.SignalKind.SEMAFOR \
				and signal_device.kind != Const.SignalKind.SEMAFOR_KSZTALTOWY:
			continue
		var approach: StringName = _signal_approach.get(signal_id, &"")
		if approach != &"" and approach != from_section:
			continue
		signal_points.append({"pos": at_pos, "signal": signal_id, "passed": false})


## Wjazd czoła na kolejne segmenty: kontrola rozprucia i zmian położenia.
func _check_segment_entries() -> void:
	for segment: Dictionary in path:
		if bool(segment["entered"]) or front_m < float(segment["start"]):
			continue
		segment["entered"] = true
		if segment["turnout"] == &"":
			continue
		var turnout := _graph.get_turnout(segment["turnout"])
		if turnout == null:
			continue
		if segment["from_edge"] == turnout.edge_root:
			# Jazda na ostrze: jeśli iglice przełożono po zbudowaniu ścieżki
			# (możliwe tylko bez utwierdzenia), jedziemy tam, gdzie iglice.
			var actual := turnout.edge_plus \
				if turnout.physical_pos() == Const.TurnoutPos.PLUS else turnout.edge_minus
			if actual != segment["chosen"]:
				_rebuild_after(segment, actual)
		else:
			# Jazda z boku przy złym położeniu = rozprucie (docs/04 §2).
			var branch: Const.TurnoutPos = segment["from_branch"]
			if turnout.physical_pos() != branch:
				turnout.trail_forced(branch)


func _turnout_at(node: StringName) -> Turnout:
	for turnout_id: StringName in _graph.turnouts:
		var turnout := _graph.get_turnout(turnout_id)
		if turnout.node_id == node:
			return turnout
	return null


func _branch_of(turnout: Turnout, edge_id: StringName) -> Const.TurnoutPos:
	return Const.TurnoutPos.PLUS if edge_id == turnout.edge_plus else Const.TurnoutPos.MINUS


func _uses_minus_branch(turnout: Turnout, from_edge: StringName,
		chosen: StringName) -> bool:
	return from_edge == turnout.edge_minus or chosen == turnout.edge_minus


## Iglice pod czołem w innym położeniu, niż zbudowana ścieżka: utnij
## wszystko za zwrotnicą i buduj od nowa od właściwej krawędzi.
func _rebuild_after(turnout_segment: Dictionary, actual_edge: StringName) -> void:
	var keep_end := float(turnout_segment["start"]) + float(turnout_segment["len"])
	var index := path.find(turnout_segment)
	path.resize(index + 1)
	turnout_segment["chosen"] = actual_edge
	signal_points.assign(signal_points.filter(
		func(point: Dictionary) -> bool: return float(point["pos"]) <= keep_end + 0.5
	))
	if dwell_point_m > keep_end:
		dwell_point_m = -1.0
	_path_ended = false
	var turnout := _graph.get_turnout(turnout_segment["turnout"])
	_append_edge_segment(_graph.get_edge(actual_edge), turnout.node_id)


## Sekcje przykryte przez skład [koniec, czoło] — do zajętości.
func covered_sections() -> Dictionary:
	var covered := {}
	var rear := rear_m()
	for segment: Dictionary in path:
		var start := float(segment["start"])
		var end := start + float(segment["len"])
		if end <= rear or start >= front_m:
			continue
		var section_id: StringName = segment["section"]
		if section_id != &"":
			covered[section_id] = true
	return covered
