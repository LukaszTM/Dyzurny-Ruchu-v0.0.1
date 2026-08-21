extends GutTest
## Testy pociągów i AI maszynisty (docs/05 §1–§2) na stacji Borki:
## hamowanie przed „stój", przejazd po nastawionej drodze ze zwalnianiem
## sekcyjnym, postój handlowy, rozprucie, hamowanie po doraźnym zwolnieniu.

const BORKI_PATH := "res://data/stations/borki.json"

var _world: SimWorld


func before_each() -> void:
	_world = SimWorld.new()
	assert_true(_world.load_station_file(BORKI_PATH)["ok"])


func _entry(stop: bool = false, dep_s: int = 0) -> Timetable.Entry:
	var entry := Timetable.Entry.new()
	entry.nr = "45201"
	entry.kind = "osobowy"
	entry.from_station = "Lipno"
	entry.len_m = 120.0
	entry.vmax_kmh = 100
	entry.power_class = "EZT"
	entry.stop = stop
	entry.dep_s = dep_s
	return entry


func _run_until(condition: Callable, max_ticks: int, why: String) -> void:
	for i: int in max_ticks:
		_world.tick(0.1)
		if condition.call():
			return
	fail_test("nie doczekano: %s" % why)


func test_pociag_hamuje_i_staje_przed_stoj() -> void:
	var train := _world.spawn_train(_entry())
	assert_not_null(train)
	_run_until(func() -> bool: return train.v_ms == 0.0 and train.front_m > 100.0,
		2000, "zatrzymanie przed semaforem A")
	assert_almost_eq(train.front_m, 650.0, 3.0, "~50 m przed semaforem „stój” (700 m)")
	assert_true(_world.station.graph.get_section(&"iza").occupied, "szlak zajęty")
	assert_false(_world.station.graph.get_section(&"izw1").occupied,
		"pociąg nie wjechał za semafor")


func test_przejazd_po_nastawionej_drodze_zwalnia_przebieg() -> void:
	assert_true(_world.execute(&"route_start", {"id": "A"}).ok)
	var train := _world.spawn_train(_entry())
	# Pociąg przejeżdża wjazd i staje przed C1 („stój") na torze 1.
	_run_until(func() -> bool: return train.v_ms == 0.0 and train.front_m > 1000.0,
		3000, "zatrzymanie przed C1")
	assert_almost_eq(train.front_m, 1140.0, 3.0, "50 m przed C1 (1190 m)")
	assert_eq(_world.station.graph.get_signal(&"A").aspect, &"S1",
		"semafor wrócił na „stój” po minięciu czoła")
	assert_eq(_world.interlocking.get_route(&"A_t1").state, Const.RouteState.IDLE,
		"przebieg zwolniony sekcyjnie przez prawdziwy pociąg")
	assert_eq(_world.station.graph.get_turnout(&"z1").locked_by, &"")
	assert_true(_world.station.graph.get_section(&"it1").occupied, "skład stoi na torze 1")
	assert_false(_world.station.graph.get_section(&"iza").occupied, "szlak za pociągiem wolny")
	# Wyjazd: nastawienie C1_out i przejazd do zniknięcia za stacją.
	assert_true(_world.execute(&"route_start", {"id": "C1"}).ok)
	_run_until(func() -> bool: return _world.trains.is_empty(), 3000, "despawn za stacją")
	for section_id: StringName in _world.station.graph.sections:
		var section: Section = _world.station.graph.get_section(section_id)
		assert_false(section.occupied, "sekcja %s wolna po odjeździe" % section_id)
		assert_eq(section.locked_by, &"", "sekcja %s nieutwierdzona" % section_id)
	assert_eq(_world.interlocking.get_route(&"C1_out").state, Const.RouteState.IDLE)


func test_postoj_handlowy_min_30_s() -> void:
	assert_true(_world.execute(&"route_start", {"id": "A"}).ok)
	var train := _world.spawn_train(_entry(true, 0))
	_run_until(func() -> bool: return train.phase == Train.Phase.DWELL,
		3000, "postój na torze 1")
	assert_almost_eq(train.front_m, 965.0, 3.0, "zatrzymanie w połowie toru 1 (W4)")
	var dwell_start := _world.sim_time
	_run_until(func() -> bool: return train.phase == Train.Phase.RUNNING,
		600, "koniec postoju")
	assert_almost_eq(_world.sim_time - dwell_start, 30.0, 1.0, "minimalny postój 30 s")
	# Po postoju rusza, ale staje przed C1 („stój").
	_run_until(func() -> bool: return train.v_ms == 0.0 and train.front_m > 1100.0,
		2000, "zatrzymanie przed C1 po postoju")
	assert_almost_eq(train.front_m, 1140.0, 3.0)


func test_rozprucie_przy_jezdzie_z_boku() -> void:
	# Jazda na Sz (bez przebiegu): dyżurny zostawił z2 w położeniu MINUS —
	# pociąg z toru 1 najeżdża z boku i rozpruwa zwrotnicę (docs/04 §2).
	assert_true(_world.execute(&"sub_signal", {"id": "A"}).ok)
	var train := _world.spawn_train(_entry())
	_run_until(func() -> bool: return train.v_ms == 0.0 and train.front_m > 1000.0,
		4000, "zatrzymanie przed C1 po jeździe na Sz")
	assert_true(_world.execute(&"turnout_throw", {"id": "z2"}).ok)
	for i: int in 51:
		_world.tick(0.1)
	assert_true(_world.station.graph.get_turnout(&"z2").is_minus())
	assert_true(_world.execute(&"sub_signal", {"id": "C1"}).ok)
	_run_until(func() -> bool:
		return _world.station.graph.get_turnout(&"z2").state == Const.TurnoutState.TRAILED,
		4000, "rozprucie z2")
	_run_until(func() -> bool: return _world.trains.is_empty(), 6000,
		"pociąg kontynuuje na szlak po rozpruciu")


func test_ograniczenie_40_przy_jezdzie_na_sz() -> void:
	assert_true(_world.execute(&"sub_signal", {"id": "A"}).ok)
	var train := _world.spawn_train(_entry())
	# Za semaforem A (700 m) pociąg nie przekracza 40 km/h.
	var max_v_after := 0.0
	for i: int in 3000:
		_world.tick(0.1)
		if train.front_m > 760.0 and train.front_m < 1100.0:
			max_v_after = maxf(max_v_after, train.v_ms)
		if train.v_ms == 0.0 and train.front_m > 1000.0:
			break
	assert_between(max_v_after * 3.6, 20.0, 41.0, "limit 40 km/h za Sz")


func test_hamowanie_nagle_po_dorazny_zwolnieniu() -> void:
	assert_true(_world.execute(&"route_start", {"id": "A"}).ok)
	var train := _world.spawn_train(_entry())
	_run_until(func() -> bool: return train.front_m > 150.0, 600, "rozpędzenie")
	assert_gt(train.v_ms, 10.0, "pociąg w biegu")
	# Doraźne zwolnienie przebiegu przed jadącym pociągiem → semafor „stój".
	_world.execute(&"route_emergency_release", {})
	assert_true(_world.execute(&"route_start", {"id": "A"}).ok)
	assert_eq(_world.station.graph.get_signal(&"A").aspect, &"S1")
	_run_until(func() -> bool: return train.v_ms == 0.0, 1200, "zatrzymanie awaryjne")
	assert_lte(train.front_m, 699.0, "zatrzymanie przed semaforem A")


func test_spawn_wg_rozkladu_scenariusza() -> void:
	var world := SimWorld.new()
	assert_true(world.load_scenario_file("res://data/scenarios/borki-poranek.json")["ok"],
		"scenariusz borki-poranek wczytuje się")
	assert_eq(world.timetable.entries.size(), 4, "4 pociągi w rozkładzie")
	# 05:40 → 06:00:00 — jeszcze pusto (45201 wjeżdża 90 s przed 06:02).
	for i: int in 12000:
		world.tick(0.1)
	assert_eq(world.trains.size(), 0, "przed 06:00:30 brak pociągów")
	for i: int in 400:
		world.tick(0.1)
	assert_eq(world.trains.size(), 1, "45201 pojawił się na szlaku od Lipna")
	assert_eq(world.trains[0].nr, "45201")
