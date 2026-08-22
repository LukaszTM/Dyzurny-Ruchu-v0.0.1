extends GutTest
## Testy ławy dźwigniowej i skrzyni zależności (docs/systemy/12 §3):
## wymuszona kolejność zwrotnice → rygiel → nakaz → dźwignia sygnałowa,
## blokada elektromechaniczna, semafory kształtowe Sr1/Sr2/Sr3.

var _world: SimWorld


func before_each() -> void:
	_world = SimWorld.new()
	assert_true(_world.load_station_file("res://data/stations/jodlow.json")["ok"],
		"stacja Jodłów wczytuje się")
	assert_not_null(_world.lever_frame, "panel mechaniczny tworzy ławę dźwigni")


func _frame() -> LeverFrame:
	return _world.lever_frame


func _graph() -> TrackGraph:
	return _world.station.graph


func _finish_throw() -> void:
	for i: int in 62:
		_world.tick(0.1)


func test_sygnalowa_wymaga_rygla_i_nakazu() -> void:
	var no_lock := _world.execute(&"lever_move", {"id": "sA"})
	assert_false(no_lock.ok, "sygnałowa przed ryglem — skrzynia nie puszcza")
	assert_string_contains(no_lock.reason, "rygiel")
	assert_true(_world.execute(&"lever_move", {"id": "r3"}).ok, "rygiel przekłada się")
	var no_order := _world.execute(&"lever_move", {"id": "sA"})
	assert_false(no_order.ok, "bez nakazu dźwignia sygnałowa zablokowana")
	assert_string_contains(no_order.reason, "nakaz")
	assert_true(_world.execute(&"station_block_press", {"id": "nakaz_wjazd"}).ok)
	assert_true(_world.execute(&"lever_move", {"id": "sA"}).ok,
		"pełna sekwencja: zwrotnice→rygiel→nakaz→sygnałowa")
	assert_eq(_world.interlocking.get_route(&"A_t1").state, Const.RouteState.LOCKED)
	assert_eq(_graph().get_signal(&"A").aspect, &"Sr2",
		"semafor kształtowy: jazda na wprost = Sr2")


func test_wjazd_na_tor_boczny_daje_sr3() -> void:
	assert_true(_world.execute(&"lever_move", {"id": "dz1"}).ok)
	_finish_throw()
	assert_true(_world.execute(&"lever_move", {"id": "dz2"}).ok)
	_finish_throw()
	assert_true(_world.execute(&"lever_move", {"id": "r3"}).ok)
	assert_true(_world.execute(&"station_block_press", {"id": "nakaz_wjazd"}).ok)
	assert_true(_world.execute(&"lever_move", {"id": "sA"}).ok)
	assert_eq(_graph().get_signal(&"A").aspect, &"Sr3",
		"jazda w bok (40 km/h) = Sr3 (dwa ramiona)")


func test_zwrotnicowa_pod_ryglem_zablokowana() -> void:
	assert_true(_world.execute(&"lever_move", {"id": "r3"}).ok)
	var refused := _world.execute(&"lever_move", {"id": "dz1"})
	assert_false(refused.ok, "zaryglowanej zwrotnicy nie wolno przestawiać")
	assert_string_contains(refused.reason, "zaryglowana")


func test_rygiel_wymaga_kontroli_zwrotnic() -> void:
	assert_true(_world.execute(&"lever_move", {"id": "dz1"}).ok)
	# Zwrotnica w trakcie przestawiania (pędnia pracuje) — rygiel czeka.
	var refused := _world.execute(&"lever_move", {"id": "r3"})
	assert_false(refused.ok)
	assert_string_contains(refused.reason, "kontroli")
	_finish_throw()
	assert_true(_world.execute(&"lever_move", {"id": "r3"}).ok,
		"po dojściu zwrotnicy rygiel przekłada się")


func test_rygla_nie_cofniesz_przy_przelozonej_sygnalowej() -> void:
	assert_true(_world.execute(&"lever_move", {"id": "r3"}).ok)
	assert_true(_world.execute(&"station_block_press", {"id": "nakaz_wjazd"}).ok)
	assert_true(_world.execute(&"lever_move", {"id": "sA"}).ok)
	var refused := _world.execute(&"lever_move", {"id": "r3"})
	assert_false(refused.ok, "kolejność cofania też wymuszona (docs/systemy/12 §3.7)")
	assert_string_contains(refused.reason, "sygnałową")


func test_cofniecie_sygnalowej_kasuje_i_zwalnia() -> void:
	assert_true(_world.execute(&"lever_move", {"id": "r3"}).ok)
	assert_true(_world.execute(&"station_block_press", {"id": "nakaz_wjazd"}).ok)
	assert_true(_world.execute(&"lever_move", {"id": "sA"}).ok)
	# Cofnięcie przy wolnym zbliżaniu = kasowanie przebiegu.
	assert_true(_world.execute(&"lever_move", {"id": "sA"}).ok)
	assert_eq(_world.interlocking.get_route(&"A_t1").state, Const.RouteState.IDLE)
	assert_eq(_graph().get_signal(&"A").aspect, &"Sr1", "ramię wraca na „stój”")
	# Teraz rygiel daje się cofnąć, a klawisz zwolnienia oddaje nakaz.
	assert_true(_world.execute(&"lever_move", {"id": "r3"}).ok)
	assert_true(_world.execute(&"station_block_press", {"id": "zwol_przeb"}).ok)
	var frame_block: LeverFrame.StationBlock = _frame().station_blocks[&"nakaz_wjazd"]
	assert_false(frame_block.given, "zwolnienie przebiegu cofa nakaz")


func test_zwolnienie_nakazu_zablokowane_w_czasie_jazdy() -> void:
	assert_true(_world.execute(&"lever_move", {"id": "r3"}).ok)
	assert_true(_world.execute(&"station_block_press", {"id": "nakaz_wjazd"}).ok)
	assert_true(_world.execute(&"lever_move", {"id": "sA"}).ok)
	var refused := _world.execute(&"station_block_press", {"id": "zwol_przeb"})
	assert_false(refused.ok, "nakaz nie do zwolnienia, dopóki przebieg aktywny")


func test_nakaz_dwa_razy_odrzucony() -> void:
	assert_true(_world.execute(&"station_block_press", {"id": "nakaz_wjazd"}).ok)
	assert_false(_world.execute(&"station_block_press", {"id": "nakaz_wjazd"}).ok,
		"nakaz już dany (przypadek brzegowy)")


func test_blokada_elektromechaniczna_warunkuje_wyjazd() -> void:
	# Funkcjonalnie jak półsamoczynna (docs/systemy/15 §3): bez pozwolenia
	# dźwignia sygnałowa wyjazdowa nie utwierdzi przebiegu.
	assert_true(_world.execute(&"block_press", {"id": "blk_e", "value": "Poz"}).ok)
	assert_true(_world.execute(&"lever_move", {"id": "r3"}).ok)
	assert_true(_world.execute(&"station_block_press", {"id": "nakaz_wyjazd"}).ok)
	var refused := _world.execute(&"lever_move", {"id": "sC1"})
	assert_false(refused.ok, "pozwolenie u sąsiada → odmowa")
	assert_string_contains(refused.reason, "pozwolenie")


func test_pelny_przejazd_przez_stacje_mechaniczna() -> void:
	# Wjazd od Cisowa na tor 1 i wyjazd na Grabno — prawdziwy pociąg.
	var entry := Timetable.Entry.new()
	entry.nr = "52101"
	entry.kind = "osobowy"
	entry.from_station = "Cisów"
	entry.to_station = "Grabno"
	entry.len_m = 110.0
	entry.vmax_kmh = 80
	entry.power_class = "EZT"
	entry.stop = false
	assert_true(_world.execute(&"lever_move", {"id": "r3"}).ok)
	assert_true(_world.execute(&"station_block_press", {"id": "nakaz_wjazd"}).ok)
	assert_true(_world.execute(&"station_block_press", {"id": "nakaz_wyjazd"}).ok)
	assert_true(_world.execute(&"lever_move", {"id": "sA"}).ok)
	# Wyjazd sprzeczny z wjazdem (mijanka!) — dopiero po przejeździe.
	assert_false(_world.execute(&"lever_move", {"id": "sC1"}).ok,
		"wyjazd sprzeczny z nastawionym wjazdem")
	var train := _world.spawn_train(entry)
	assert_true(train.eastbound)
	# Pociąg wjeżdża i staje przed C1 („stój"); wjazd zwalnia się sekcyjnie.
	for i: int in 2500:
		_world.tick(0.1)
		if train.v_ms == 0.0 and train.front_m > 900.0:
			break
	assert_eq(_world.interlocking.get_route(&"A_t1").state, Const.RouteState.IDLE,
		"wjazd zwolniony przez pociąg")
	# Cofnięcie dźwigni wjazdowej i nastawienie wyjazdu.
	assert_true(_world.execute(&"lever_move", {"id": "sA"}).ok)
	assert_true(_world.execute(&"lever_move", {"id": "sC1"}).ok, "wyjazd nastawiony")
	assert_eq(_graph().get_signal(&"C1").aspect, &"Sr2")
	for i: int in 3000:
		_world.tick(0.1)
		if _world.trains.is_empty():
			break
	assert_true(_world.trains.is_empty(), "pociąg przejechał przez stację mechaniczną")
	assert_eq(_graph().get_signal(&"A").aspect, &"Sr1", "ramiona wróciły na „stój”")
	assert_eq(_graph().get_signal(&"C1").aspect, &"Sr1")
