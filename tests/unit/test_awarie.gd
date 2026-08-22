extends GutTest
## Testy procedur awaryjnych F6: usterka zwrotnicy z naprawą, awaria
## blokady z telefonicznym zapowiadaniem, rozkazy pisemne, ocena jazd
## na Sz (docs/04 §8, docs/systemy/18 §5–§6, docs/05 §6–§7).

var _world: SimWorld
var _events: Array[Dictionary] = []


func _tick_n(count: int) -> void:
	for i: int in count:
		_world.tick(0.1)
		_events.append_array(_world.drain_events())


func _penalty_with(fragment: String) -> bool:
	for event: Dictionary in _events:
		if event["type"] == &"penalty" and String(event["reason"]).contains(fragment):
			return true
	return false


func _alarm_with(fragment: String) -> bool:
	for event: Dictionary in _events:
		if event["type"] == &"alarm" and String(event["text"]).contains(fragment):
			return true
	return false


func _entry_transit() -> Timetable.Entry:
	var entry := Timetable.Entry.new()
	entry.nr = "222"
	entry.kind = "osobowy"
	entry.from_station = "Lipno"
	entry.to_station = "Suchowola"
	entry.len_m = 120.0
	entry.vmax_kmh = 100
	entry.power_class = "EZT"
	entry.stop = false
	return entry


func _setup_scenario(events: Array) -> void:
	_world = SimWorld.new()
	_events.clear()
	var result := _world.apply_scenario({
		"meta": {"id": "test-awarie", "station": "borki"},
		"start_time": "05:40", "duration_min": 60,
		"timetable": [], "events": events,
	})
	assert_true(result["ok"], "%s" % [result["errors"]])
	_world.rng.seed = 42


func test_usterka_zwrotnicy_blokuje_przebiegi_i_naprawa() -> void:
	_setup_scenario([
		{"at": "05:41", "type": "turnout_no_control", "target": "z2", "repair_min": 2},
	])
	_tick_n(650)
	assert_eq(_world.station.graph.get_turnout(&"z2").state, Const.TurnoutState.NO_CONTROL)
	assert_true(_alarm_with("USTERKA"), "alarm o usterce dla gracza")
	var refused := _world.execute(&"route_start", {"id": "C1"})
	assert_false(refused.ok, "przebieg przez zwrotnicę bez kontroli niemożliwy")
	# Po czasie naprawy kontrola wraca w bieżącym położeniu.
	_tick_n(1300)
	assert_true(_world.station.graph.get_turnout(&"z2").is_plus(), "kontrola przywrócona")
	assert_true(_alarm_with("przywrócona"))
	assert_true(_world.execute(&"route_start", {"id": "C1"}).ok)


func test_awaria_blokady_pola_nieczynne_wyjazd_odrzucany() -> void:
	_setup_scenario([
		{"at": "05:41", "type": "block_failure", "target": "blk_e"},
	])
	_tick_n(650)
	assert_true((_world.block_lines[&"blk_e"] as BlockLine).failed)
	assert_true(_alarm_with("telefoniczne zapowiadanie"))
	assert_false(_world.execute(&"block_press", {"id": "blk_e", "value": "Poz"}).ok,
		"pola uszkodzonej blokady nieczynne")
	var refused := _world.execute(&"route_start", {"id": "C1"})
	assert_false(refused.ok, "semafor wyjazdowy zablokowany przy awarii")
	assert_string_contains(refused.reason, "uszkodzona")


func test_wyjazd_na_sz_po_telefonicznym_zapowiadaniu_bez_kary() -> void:
	_setup_scenario([
		{"at": "05:40", "type": "block_failure", "target": "blk_e"},
	])
	_tick_n(20)
	# Pociąg tranzytowy wjeżdża normalnie (wjazd nie zależy od blokady E).
	var train := _world.spawn_train(_entry_transit())
	assert_true(_world.execute(&"route_start", {"id": "A"}).ok)
	while _world.sim_time < 300.0 and not (train.v_ms == 0.0 and train.front_m > 1000.0):
		_tick_n(10)
	# Telefoniczne zapowiadanie: żądanie → sąsiad daje drogę formułą.
	assert_true(_world.execute(&"phone_send", {"type": "zadanie_pozwolenia",
		"nr": "222", "neighbour": "Suchowola"}).ok)
	_tick_n(100)
	# Wyjazd na sygnał zastępczy.
	assert_true(_world.execute(&"sub_signal", {"id": "C1"}).ok)
	while _world.sim_time < 900.0 and not _world.trains.is_empty():
		_tick_n(10)
	assert_true(_world.trains.is_empty(), "pociąg wyjechał na Sz")
	assert_false(_penalty_with("bez telefonicznego zapowiadania"),
		"pełna procedura = brak kary")


func test_wyjazd_na_sz_bez_zapowiedzi_kara() -> void:
	_setup_scenario([
		{"at": "05:40", "type": "block_failure", "target": "blk_e"},
	])
	_tick_n(20)
	var train := _world.spawn_train(_entry_transit())
	assert_true(_world.execute(&"route_start", {"id": "A"}).ok)
	while _world.sim_time < 300.0 and not (train.v_ms == 0.0 and train.front_m > 1000.0):
		_tick_n(10)
	assert_true(_world.execute(&"sub_signal", {"id": "C1"}).ok)
	while _world.sim_time < 900.0 and not _world.trains.is_empty():
		_tick_n(10)
	assert_true(_penalty_with("bez telefonicznego zapowiadania"),
		"wyprawienie bez zapowiedzi przy awarii = kara")


func test_rozkaz_s_pozwala_minac_semafor_stoj() -> void:
	_world = SimWorld.new()
	_events.clear()
	assert_true(_world.load_station_file("res://data/stations/borki.json")["ok"])
	var train := _world.spawn_train(_entry_transit())
	# Pociąg staje przed semaforem A („stój" — brak przebiegu).
	while _world.sim_time < 200.0 and not (train.v_ms == 0.0 and train.front_m > 500.0):
		_tick_n(10)
	assert_almost_eq(train.front_m, 650.0, 3.0)
	# Rozkaz „S": dyktowanie trwa (pociąg stoi), po powtórzeniu — jazda.
	assert_true(_world.execute(&"order_dictate",
		{"type": "S", "nr": "222", "signal": "A"}).ok)
	_tick_n(100)
	assert_eq(train.v_ms, 0.0, "w trakcie dyktowania pociąg stoi")
	_tick_n(150)
	assert_true(bool(_world.orders[0]["active"]), "rozkaz aktywny po podyktowaniu")
	while _world.sim_time < 400.0 and train.front_m < 760.0:
		_tick_n(10)
	assert_gt(train.front_m, 760.0, "pociąg minął semafor „stój” na rozkaz")
	assert_true(train.sz_authority, "za rozkazem obowiązuje reżim jak przy Sz")
	assert_lte(train.v_ms * 3.6, 41.0)
	var remark := _world.train_log.entry_for("222").remarks
	assert_string_contains(remark, "rozkaz")


func test_rozkaz_o_ogranicza_predkosc() -> void:
	_world = SimWorld.new()
	_events.clear()
	assert_true(_world.load_station_file("res://data/stations/borki.json")["ok"])
	assert_true(_world.execute(&"route_start", {"id": "A"}).ok)
	var train := _world.spawn_train(_entry_transit())
	assert_true(_world.execute(&"order_dictate", {"type": "O", "nr": "222", "signal": ""}).ok)
	# Po podyktowaniu pociąg wyhamowuje do ograniczenia...
	_tick_n(250)
	while _world.sim_time < 200.0 and train.v_ms * 3.6 > 20.5:
		_world.tick(0.1)
	# ...i już go nie przekracza.
	var max_v := 0.0
	for i: int in 1000:
		_world.tick(0.1)
		max_v = maxf(max_v, train.v_ms)
	assert_lte(max_v * 3.6, 21.0, "rozkaz „O” ogranicza prędkość do 20 km/h")


func test_sz_na_zajety_tor_zdarzenie_niebezpieczne() -> void:
	_world = SimWorld.new()
	_events.clear()
	assert_true(_world.load_station_file("res://data/stations/borki.json")["ok"])
	# Tor 1 zajęty (np. tabor), a gracz mimo to podaje Sz na wjeździe.
	_world.execute(&"debug_section_occupied", {"id": "it1", "value": "1"})
	assert_true(_world.execute(&"sub_signal", {"id": "A"}).ok)
	var train := _world.spawn_train(_entry_transit())
	while _world.sim_time < 300.0 and train.front_m < 760.0:
		_tick_n(10)
	assert_true(_penalty_with("ZDARZENIE NIEBEZPIECZNE"),
		"skierowanie na zajęty tor na Sz = −50")
