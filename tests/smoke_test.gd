extends Node
## Headless test dymny pełnej pętli rozgrywki. Uruchomienie:
##   godot --headless --path . res://tests/SmokeTest.tscn --quit-after 3000
## Wypisuje [PASS]/[FAIL] dla kolejnych kroków i kończy proces.

var sim = null
var phase := 0
var wait_frames := 0
var failed := false
var ic_id := 0
var man_id := 0
var tlk_id := 0


func _ready() -> void:
	GameState.mode = GameState.MODE_TIMETABLE
	GameState.location_id = "warszawa_wschodnia"
	var scene: PackedScene = load("res://scenes/Simulator.tscn")
	sim = scene.instantiate()
	add_child(sim)


func _fail(msg: String) -> void:
	print("[FAIL] ", msg)
	failed = true
	_quit()


func _pass(msg: String) -> void:
	print("[PASS] ", msg)


func _quit() -> void:
	print("SMOKE TEST: ", "FAILED" if failed else "OK")
	get_tree().quit(1 if failed else 0)


func _find_train(nr: String):
	for t in sim.trains.values():
		if t.nr == nr:
			return t
	return null


func _process(_delta: float) -> void:
	if sim == null:
		return
	wait_frames += 1
	if wait_frames > 2500:
		_fail("Przekroczono limit czasu w fazie %d" % phase)
		return
	match phase:
		0:
			# rozpędzenie symulacji + własny pociąg testowy
			sim.time_scale = 20.0
			sim.spawn_from_spec({
				"nr": "9901", "kat": "IC", "nazwa": "Test",
				"z": "W-wa Zachodnia", "do": "Białystok",
				"we": "WD1", "wy": "ED1", "tor": "5",
				"arr_sec": sim.sim_time, "dep_sec": -1.0,
				"przelot": false, "koniec": false, "man": false,
				"tt_index": -1, "delay_min": 0,
			})
			var t = _find_train("9901")
			if t == null:
				_fail("Pociąg testowy nie powstał")
				return
			ic_id = t.id
			_pass("Spawn pociągu i kolejka portalu")
			_next()
		1:
			# przebieg wjazdowy Ad -> H5 (tor 5)
			sim.on_schema_click("signal", "Ad")
			sim.on_schema_click("signal", "H5")
			var t = sim.trains.get(ic_id)
			if t == null or t.state != Train.State.MOVING or t.route.is_empty():
				_fail("Przebieg wjazdowy Ad->H5 nie przydzielił pociągu")
				return
			_pass("Przebieg wjazdowy ustawiony, pociąg rusza")
			_next()
		2:
			var t = sim.trains.get(ic_id)
			if t != null and t.state == Train.State.AT_PLATFORM:
				if t.track_nr != "5":
					_fail("Pociąg wjechał na tor %s zamiast 5" % t.track_nr)
					return
				_pass("Wjazd na tor 5 zakończony (%.0f s symulacji)" % (sim.sim_time - t.spawned_at))
				t.state = Train.State.READY
				_next()
		3:
			# odjazd H5 -> portal ED1
			sim.on_schema_click("signal", "H5")
			sim.on_schema_click("portal", "ED1")
			var t = sim.trains.get(ic_id)
			if t == null or t.state != Train.State.MOVING:
				_fail("Przebieg wyjazdowy H5->ED1 nie ruszył pociągu")
				return
			_pass("Przebieg wyjazdowy ustawiony")
			_next()
		4:
			if sim.trains.get(ic_id) == null:
				_pass("Pociąg opuścił posterunek (despawn na portalu)")
				_next()
		5:
			# manewr: skład z Grochowa na tor 8
			sim.spawn_from_spec({
				"nr": "M900", "kat": "MAN", "nazwa": "",
				"z": "Grochów", "do": "tor 8",
				"we": "GR", "wy": "GR", "tor": "8",
				"arr_sec": sim.sim_time, "dep_sec": -1.0,
				"przelot": false, "koniec": false, "man": true,
				"tt_index": -1, "delay_min": 0,
			})
			var t = _find_train("M900")
			man_id = t.id if t != null else 0
			sim.shunt_mode = true
			sim.on_schema_click("signal", "M10")
			sim.on_schema_click("signal", "K8")
			sim.shunt_mode = false
			var t2 = sim.trains.get(man_id)
			if t2 == null or t2.state != Train.State.MOVING or t2.route.get("kind", "") != "shunt":
				_fail("Przebieg manewrowy M10->K8 nie zadziałał")
				return
			_pass("Przebieg manewrowy ustawiony (skład z Grochowa)")
			_next()
		6:
			var t = sim.trains.get(man_id)
			if t != null and t.state == Train.State.AT_PLATFORM:
				if t.track_nr != "8":
					_fail("Manewr dotarł na tor %s zamiast 8" % t.track_nr)
					return
				_pass("Skład podstawiony na tor 8")
				_next()
		7:
			# usterka semafora + sygnał zastępczy
			var ev: Dictionary = sim.events.force_event(sim.sim_time, "semafor", "Bd")
			if ev.is_empty():
				_fail("Nie udało się wymusić usterki semafora")
				return
			sim.spawn_from_spec({
				"nr": "9902", "kat": "TLK", "nazwa": "",
				"z": "W-wa Zachodnia", "do": "Terespol",
				"we": "WD2", "wy": "ED2", "tor": "6",
				"arr_sec": sim.sim_time, "dep_sec": -1.0,
				"przelot": false, "koniec": false, "man": false,
				"tt_index": -1, "delay_min": 0,
			})
			tlk_id = _find_train("9902").id
			sim.on_schema_click("signal", "Bd")
			sim.on_schema_click("signal", "H6")
			var t = sim.trains.get(tlk_id)
			if t == null or t.route.is_empty():
				_fail("Przebieg przy uszkodzonym semaforze nie został ustawiony")
				return
			if t.route.get("open", false):
				_fail("Semafor uszkodzony, a przebieg otwarty bez Sz")
				return
			sim.selected_signal = "Bd"
			sim.give_sz_selected()
			if not t.route.get("open", false):
				_fail("Sygnał zastępczy nie otworzył przebiegu")
				return
			_pass("Usterka semafora obsłużona sygnałem Sz")
			_next()
		8:
			var t = sim.trains.get(tlk_id)
			if t != null and t.state == Train.State.AT_PLATFORM:
				_pass("Pociąg wjechał na Sz na tor %s" % t.track_nr)
				_next()
		9:
			# przebieg bez pociągu + doraźne zwolnienie
			sim.on_schema_click("signal", "Cp")
			sim.on_schema_click("signal", "K1")
			var r: Dictionary = sim.inter.route_of_signal("Cp")
			if r.is_empty():
				_fail("Przebieg Cp->K1 nie został ustawiony")
				return
			sim.selected_signal = "Cp"
			sim.release_selected_route()
			if not sim.inter.route_of_signal("Cp").is_empty():
				_fail("Doraźne zwolnienie przebiegu nie zadziałało")
				return
			_pass("Doraźne zwolnienie przebiegu")
			_next()
		10:
			# dziennik i rozkład
			if sim.dlog.entries.size() < 10:
				_fail("Dziennik ruchu ma podejrzanie mało wpisów")
				return
			if sim.tt.entries.size() < 30:
				_fail("Rozkład jazdy nie został wczytany")
				return
			var path: String = sim.dlog.save_to_file()
			if path == "":
				_fail("Zapis dziennika nie powiódł się")
				return
			_pass("Dziennik (%d wpisów) zapisany, rozkład wczytany (%d poz.)" % [
				sim.dlog.entries.size(), sim.tt.entries.size()])
			_quit()


func _next() -> void:
	phase += 1
	wait_frames = 0
