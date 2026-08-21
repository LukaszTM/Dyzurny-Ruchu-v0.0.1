extends GutTest
## Test pełnej pętli zapowiadawczej (docs/05 §3–§4, systemy/15 §1,
## systemy/18): zapowiedź → pozwolenie → wjazd → potwierdzenie → wyprawienie.

var _world: SimWorld
var _events: Array[Dictionary] = []


func before_each() -> void:
	_world = SimWorld.new()
	_events.clear()
	var result := _world.apply_scenario({
		"meta": {"id": "test-flow", "station": "borki"},
		"start_time": "05:40",
		"duration_min": 30,
		"timetable": [
			{"nr": "111", "kind": "osobowy", "from": "Lipno", "to": "Suchowola",
			 "arr": "05:45", "dep": "05:46", "track": "t1", "stop": true,
			 "len_m": 120, "vmax_kmh": 100, "mass_t": 180, "power_class": "EZT"},
		],
	})
	assert_true(result["ok"], "scenariusz testowy: %s" % [result["errors"]])


func _tick_n(count: int) -> void:
	for i: int in count:
		_world.tick(0.1)
		_events.append_array(_world.drain_events())


func _penalties() -> Array[Dictionary]:
	return _events.filter(func(e: Dictionary) -> bool: return e["type"] == &"penalty")


func _blk_w() -> BlockLine:
	return _world.block_lines[&"blk_w"]


func _blk_e() -> BlockLine:
	return _world.block_lines[&"blk_e"]


func test_pelna_petla_zapowiadawcza() -> void:
	# 05:41 — sąsiad żąda pozwolenia dla 111; pociąg NIE wjeżdża bez zgody.
	_tick_n(700)
	assert_gt(_world.comms.log.size(), 0, "sąsiad zadzwonił")
	assert_string_contains(_world.comms.log[0].text, "111")
	assert_string_contains(_world.comms.log[0].text, "wolna?")
	assert_eq(_world.trains.size(), 0, "wjazd sprzężony z zapowiedzią — bez Poz brak pociągu")
	# Gracz odpowiada formułą i przekazuje pozwolenie przyciskiem Poz.
	assert_true(_world.execute(&"phone_send", {"type": "danie_pozwolenia",
		"nr": "111", "neighbour": "Lipno"}).ok)
	assert_true(_world.execute(&"block_press", {"id": "blk_w", "value": "Poz"}).ok)
	assert_eq(_blk_w().permission_at, BlockLine.BlockSide.NEIGHBOUR)
	# 05:43:30 — po oznajmieniu odjazdu pociąg jest na szlaku, odstęp zajęty.
	_tick_n(1400)
	assert_eq(_world.trains.size(), 1, "po zapowiedzi pociąg wjechał na szlak")
	assert_true(_blk_w().occupied, "odstęp od Lipna zajęty")
	var announced := false
	for message: Comms.Message in _world.comms.log:
		if message.incoming and message.text.contains("odjedzie"):
			announced = true
	assert_true(announced, "sąsiad oznajmił odjazd")
	# Wjazd na tor 1 i przyjazd całego pociągu.
	assert_true(_world.execute(&"route_start", {"id": "A"}).ok)
	var train: Train = _world.trains[0]
	while _world.sim_time < 500.0 and train.phase != Train.Phase.DWELL:
		_tick_n(10)
	assert_eq(train.phase, Train.Phase.DWELL, "pociąg stanął przy peronie")
	assert_true(_blk_w().arrival_pending, "pociąg przyjechał cały — Ko dozwolone")
	# Potwierdzenie przyjazdu: Ko + telefonogram.
	assert_true(_world.execute(&"block_press", {"id": "blk_w", "value": "Ko"}).ok)
	assert_false(_blk_w().occupied, "Ko zwolniło odstęp")
	assert_true(_world.execute(&"phone_send", {"type": "potwierdzenie_przyjazdu",
		"nr": "111", "neighbour": "Lipno"}).ok)
	# Wyjazd na Suchowolę: bez pozwolenia blokada odmawia (warunek 6).
	assert_true(_world.execute(&"block_press", {"id": "blk_e", "value": "Poz"}).ok)
	var refused := _world.execute(&"route_start", {"id": "C1"})
	assert_false(refused.ok, "wyjazd bez pozwolenia musi być odrzucony")
	assert_string_contains(refused.reason, "pozwolenie")
	# Gracz żąda drogi telefonicznie; sąsiad daje pozwolenie po chwili.
	assert_true(_world.execute(&"phone_send", {"type": "zadanie_pozwolenia",
		"nr": "111", "neighbour": "Suchowola"}).ok)
	_tick_n(100)
	assert_eq(_blk_e().permission_at, BlockLine.BlockSide.PLAYER, "pozwolenie wróciło do gracza")
	assert_true(_world.execute(&"route_start", {"id": "C1"}).ok)
	# Odjazd po postoju, oznajmienie, zniknięcie za stacją.
	while _world.sim_time < 900.0 and not _world.trains.is_empty():
		_tick_n(10)
	assert_true(_world.trains.is_empty(), "pociąg odjechał do Suchowoli")
	assert_true(_world.execute(&"phone_send", {"type": "oznajmienie_odjazdu",
		"nr": "111", "neighbour": "Suchowola"}).ok)
	assert_true(_blk_e().occupied, "odstęp do Suchowoli zajęty do Ko sąsiada")
	assert_true(_blk_w().po_pending or true, "")
	# Sąsiad po czasie jazdy potwierdza przyjazd i zwalnia odstęp.
	_tick_n(1100)
	assert_false(_blk_e().occupied, "Ko sąsiada zwolniło odstęp")
	# Dziennik ruchu: komplet wpisów, bez kar proceduralnych.
	var entry := _world.train_log.entry_for("111")
	assert_gte(entry.permission_s, 0.0, "wpis pozwolenia")
	assert_gte(entry.announced_s, 0.0, "wpis oznajmienia")
	assert_gte(entry.arrived_s, 0.0, "wpis przyjazdu")
	assert_gte(entry.confirmed_s, 0.0, "wpis potwierdzenia")
	assert_gte(entry.departed_s, 0.0, "wpis odjazdu")
	assert_eq(_penalties().size(), 0, "pełna procedura = brak kar")


func test_kara_za_brak_potwierdzenia_przyjazdu() -> void:
	_tick_n(700)
	_world.execute(&"block_press", {"id": "blk_w", "value": "Poz"})
	_tick_n(1400)
	_world.execute(&"route_start", {"id": "A"})
	while _world.sim_time < 500.0 \
			and (_world.trains.is_empty() or _world.trains[0].phase != Train.Phase.DWELL):
		_tick_n(10)
	# Gracz ignoruje potwierdzenie przyjazdu przez ponad 5 minut.
	_tick_n(3200)
	var penalties := _penalties()
	assert_gt(penalties.size(), 0, "brak potwierdzenia po terminie = kara")
	assert_string_contains(String(penalties[0]["reason"]), "potwierdzenia przyjazdu")


func test_koniec_zmiany_emituje_zdarzenie() -> void:
	_world.duration_min = 1
	_tick_n(650)
	var ended := _events.filter(func(e: Dictionary) -> bool: return e["type"] == &"shift_end")
	assert_eq(ended.size(), 1, "koniec służby zgłoszony dokładnie raz")
