extends GutTest
## Testy F8: blokada samoczynna (docs/systemy/15 §2), przejazdy kat. A
## i ssp (systemy/16), dSAT (systemy/17) na dwutorowej stacji Brzeziny.

var _world: SimWorld
var _events: Array[Dictionary] = []


func before_each() -> void:
	_world = SimWorld.new()
	_events.clear()
	assert_true(_world.load_station_file("res://data/stations/brzeziny.json")["ok"],
		"stacja Brzeziny wczytuje się")
	_world.rng.seed = 7


func _tick_n(count: int) -> void:
	for i: int in count:
		_world.tick(0.1)
		_events.append_array(_world.drain_events())


func _has_event(type: StringName, fragment: String = "") -> bool:
	for event: Dictionary in _events:
		if event["type"] != type:
			continue
		if fragment.is_empty():
			return true
		for key: String in ["text", "reason"]:
			if event.has(key) and String(event[key]).contains(fragment):
				return true
	return false


func _entry_e(nr: String = "31501") -> Timetable.Entry:
	var entry := Timetable.Entry.new()
	entry.nr = nr
	entry.kind = "osobowy"
	entry.from_station = "Sosnów"
	entry.to_station = "Dęby"
	entry.len_m = 120.0
	entry.vmax_kmh = 100
	entry.power_class = "EZT"
	entry.stop = false
	return entry


# --- Blokada samoczynna -----------------------------------------------------

func test_aspekty_semaforow_odstepowych_3staw() -> void:
	_tick_n(1)
	var graph := _world.station.graph
	assert_eq(graph.get_signal(&"O1").aspect, &"S2", "2 wolne odstępy → S2")
	assert_eq(graph.get_signal(&"O2").aspect, &"S5", "1 wolny odstęp (dalej stacja) → S5")
	# Pociąg na drugim odstępie: O2 „stój", O1 ostrzega.
	_world.execute(&"debug_section_occupied", {"id": "iodw2", "value": "1"})
	_tick_n(1)
	assert_eq(graph.get_signal(&"O2").aspect, &"S1", "odstęp za semaforem zajęty → S1")
	assert_eq(graph.get_signal(&"O1").aspect, &"S5", "1 wolny przed zajętym → S5")
	_world.execute(&"debug_section_occupied", {"id": "iodw1", "value": "1"})
	_tick_n(1)
	assert_eq(graph.get_signal(&"O1").aspect, &"S1")


func test_sbl_wyprawianie_za_pociagiem() -> void:
	_tick_n(1)
	# Pierwszy odstęp wyjazdowy zajęty (poprzedni pociąg) → odmowa.
	_world.execute(&"debug_section_occupied", {"id": "iode1", "value": "1"})
	_tick_n(1)
	var refused := _world.execute(&"route_start", {"id": "C1"})
	assert_false(refused.ok, "sbl: wyjazd tylko na wolny pierwszy odstęp")
	assert_string_contains(refused.reason, "odstęp")
	# Pociąg zwolnił pierwszy odstęp (jedzie dalej) → wyprawianie za nim.
	_world.execute(&"debug_section_occupied", {"id": "iode1", "value": "0"})
	_world.execute(&"debug_section_occupied", {"id": "iode2", "value": "1"})
	_tick_n(1)
	assert_true(_world.execute(&"route_start", {"id": "C1"}).ok,
		"wyprawianie za pociągiem, gdy zwolnił pierwszy odstęp")
	assert_eq(_world.station.graph.get_signal(&"C1").aspect, &"S5",
		"następny (P1) na „stój” → S5")
	# Szlak całkiem wolny → semafor wyjazdowy wg odstępowego (S2).
	_world.execute(&"debug_section_occupied", {"id": "iode2", "value": "0"})
	_tick_n(1)
	assert_eq(_world.station.graph.get_signal(&"C1").aspect, &"S2",
		"wolny szlak sbl → jazda z maksymalną")


func test_sbl_pola_reczne_nieczynne() -> void:
	var refused := _world.execute(&"block_press", {"id": "blk_ee", "value": "Po"})
	assert_false(refused.ok)
	assert_string_contains(refused.reason, "samoczynna")


# --- Przejazdy ----------------------------------------------------------------

func test_przejazd_kat_a_warunkiem_przebiegu() -> void:
	var refused := _world.execute(&"route_start", {"id": "B"})
	assert_false(refused.ok, "wjazd na tor 2 wymaga zamkniętego przejazdu (docs/04 §3.7)")
	assert_string_contains(refused.reason, "przejazd")
	assert_true(_world.execute(&"crossing_close", {"id": "przA"}).ok)
	_tick_n(260)
	assert_true((_world.crossings[&"przA"] as LevelCrossing).is_closed())
	assert_true(_world.execute(&"route_start", {"id": "B"}).ok,
		"po zamknięciu rogatek przebieg się utwierdza")


func test_ssp_automat_od_najazdu() -> void:
	var przB: LevelCrossing = _world.crossings[&"przB"]
	assert_eq(przB.state, LevelCrossing.State.OPEN)
	assert_false(_world.execute(&"crossing_close", {"id": "przB"}).ok,
		"ssp nie ma obsługi ręcznej")
	_world.execute(&"debug_section_occupied", {"id": "iodw1", "value": "1"})
	_tick_n(130)
	assert_eq(przB.state, LevelCrossing.State.CLOSED, "najazd zamyka ssp")
	_world.execute(&"debug_section_occupied", {"id": "iodw1", "value": "0"})
	_tick_n(90)
	assert_eq(przB.state, LevelCrossing.State.OPEN, "po przejeździe ssp otwiera się")


func test_awaria_ssp_zwalnia_pociag_do_20() -> void:
	(_world.crossings[&"przB"] as LevelCrossing).set_failure(true)
	var train := _world.spawn_train(_entry_e())
	var max_v_at_crossing := 0.0
	for i: int in 2000:
		_world.tick(0.1)
		if train.front_m > 300.0 and train.front_m < 2000.0:
			max_v_at_crossing = maxf(max_v_at_crossing, train.v_ms)
		if train.front_m >= 2000.0 or _world.trains.is_empty():
			break
	assert_between(max_v_at_crossing * 3.6, 5.0, 21.0,
		"przy awarii ssp jazda ≤20 km/h przez rejon przejazdu")


# --- dSAT ---------------------------------------------------------------------

func test_dsat_raport_ok_i_alarm_z_procedura() -> void:
	# Bez uzbrojenia: raport „bez usterek".
	var train := _world.spawn_train(_entry_e("30001"))
	_tick_n(400)
	assert_true(_has_event(&"dsat_report", "bez usterek"))
	assert_true(train.front_m > 0.0)
	# Uzbrojony alarm dla kolejnego pociągu (jak zdarzenie scenariusza).
	(_world.dsats[&"dsat1"] as Dsat).armed = {"code": "GM", "level": "ALARM", "axle": 14}
	var second := _world.spawn_train(_entry_e("30002"))
	_tick_n(600)
	assert_true(_has_event(&"dsat_alarm", "GM"), "alarm dSAT opublikowany")
	assert_true(_world.dsat_unacked(), "lampka alarmu do skwitowania")
	assert_true(_world.execute(&"dsat_ack", {}).ok)
	assert_false(_world.dsat_unacked())
	# Pociąg przytrzymany semaforem A („stój") → oględziny → wynik.
	while _world.sim_time < 400.0 and not (second.v_ms == 0.0 and second.front_m > 1500.0):
		_tick_n(10)
	_tick_n(50)
	assert_true(_has_event(&"alarm", "oględziny") or _has_event(&"alarm", "Oględziny")
		or _has_event(&"alarm", "zatrzymany"), "drużyna rozpoczęła oględziny")
	_tick_n(3100)
	assert_true(_has_event(&"alarm", "Oględziny"), "wynik oględzin ogłoszony")
	assert_false(_has_event(&"penalty", "dSAT"), "pełna procedura = brak kary")


func test_dsat_brak_kwitu_kara() -> void:
	(_world.dsats[&"dsat1"] as Dsat).armed = {"code": "GH", "level": "ALARM", "axle": 3}
	_world.spawn_train(_entry_e("30003"))
	_tick_n(2400)
	assert_true(_has_event(&"penalty", "dSAT"),
		"brak skwitowania i reakcji w terminie = zdarzenie niebezpieczne")


func test_radio_stop_zatrzymuje_pociag() -> void:
	var train := _world.spawn_train(_entry_e("30004"))
	_tick_n(300)
	assert_gt(train.v_ms, 10.0, "pociąg w biegu")
	assert_true(_world.execute(&"radio_stop", {"nr": "30004"}).ok)
	_tick_n(400)
	assert_eq(train.v_ms, 0.0, "radiostop zatrzymuje pociąg")
	assert_true(_world.execute(&"radio_release", {"nr": "30004"}).ok)
	_tick_n(200)
	assert_gt(train.v_ms, 3.0, "po zwolnieniu jedzie dalej")
