extends Node
## Headless test dymny pełnej pętli rozgrywki:
## zapowiadanie → przebieg wjazdowy → przyjazd → potwierdzenie przyjazdu →
## pozwolenie → przebieg wyjazdowy → oznajmienie odjazdu → manewry →
## usterka semafora i sygnał zastępczy → zgłoszenie usterki → ZW → ZD → EDR.
##
## Uruchomienie:
##   godot --headless --path . res://tests/SmokeTest.tscn --quit-after 40000

var sim: SimCore
var faza := 0
var klatki := 0
var blad := false
var poc_id := 0
var man_id := 0
var szt_id := 0
var ev_id := 0


func _ready() -> void:
	Settings.require_zapowiadanie = true
	Settings.shunting_enabled = true
	Settings.event_freq_min = 0.0
	Settings.online_enabled = false
	sim = SimCore.new()
	add_child(sim)
	sim.setup(GameState.MODE_TIMETABLE, "warszawa_wschodnia")
	sim.time_scale = 20.0
	GameState.sim = sim


func _ok(msg: String) -> void:
	print("[PASS] ", msg)


func _fail(msg: String) -> void:
	print("[FAIL] ", msg)
	blad = true
	_koniec()


func _koniec() -> void:
	print("TEST DYMNY: ", "NIEPOWODZENIE" if blad else "OK")
	get_tree().quit(1 if blad else 0)


func _dalej() -> void:
	faza += 1
	klatki = 0


func _poc(nr: String) -> Train:
	for t: Train in sim.trains.values():
		if t.nr == nr:
			return t
	return null


func _process(_d: float) -> void:
	if sim == null:
		return
	klatki += 1
	if klatki > 4000:
		_fail("przekroczono limit czasu w fazie %d" % faza)
		return
	match faza:
		0:
			# 1. zapowiadanie: żądanie pozwolenia od sąsiada
			sim.request_train({
				"nr": "9901", "kat": "EIE", "nazwa": "Test", "z": "W-wa Zachodnia",
				"do": "Białystok", "we": "it1D", "wy": "it1R", "tor": "5",
				"arr": sim.sim_time, "dep": sim.sim_time + 200.0, "postoj": 120.0,
				"przelot": false, "koniec": false, "man": false,
				"tt_index": -1, "delay": 0, "podstawienie": false})
			var pend := sim.comms.pending_calls()
			if pend.is_empty():
				_fail("sąsiad nie zażądał pozwolenia na wyprawienie pociągu")
				return
			if _poc("9901") != null:
				_fail("pociąg pojawił się przed udzieleniem pozwolenia")
				return
			_ok("Żądanie pozwolenia od sąsiedniego posterunku")
			sim.comms.answer_call(int(pend[0]["id"]), true)
			var t := _poc("9901")
			if t == null:
				_fail("po udzieleniu pozwolenia pociąg się nie zgłosił")
				return
			poc_id = t.id
			_ok("Danie pozwolenia — pociąg oczekuje przed semaforem wjazdowym C")
			_dalej()
		1:
			# 2. przebieg wjazdowy C -> N5 (dwuprzyciskowo)
			sim.set_cmd_mode(SimCore.CMD_PP)
			sim.click_element("signal", "C")
			if sim.pending_start != "C":
				_fail("przycisk początku drogi przebiegu nie zadziałał")
				return
			sim.click_element("signal", "N5")
			var r := sim.inter.route_of_signal("C")
			if r.is_empty():
				_fail("przebieg C → N5 nie został nastawiony")
				return
			if str(r["state"]) != Interlocking.ST_NASTAWIANIE:
				_fail("przebieg powinien najpierw przejść w stan nastawiania rozjazdów")
				return
			if sim.inter.aspect("C") != Interlocking.ASPECT_STOP:
				_fail("semafor podał sygnał przed utwierdzeniem przebiegu")
				return
			if int(r["train_id"]) != poc_id:
				_fail("przebieg nie został przydzielony oczekującemu pociągowi")
				return
			_ok("Nastawianie dwuprzyciskowe C → N5 (rozjazdy: %s)" % sim._sw_text(r["sw"]))
			_dalej()
		2:
			var r2 := sim.inter.route_of_signal("C")
			if r2.is_empty():
				_dalej()
				return
			if str(r2["state"]) == Interlocking.ST_UTWIERDZONY:
				if sim.inter.aspect("C") != Interlocking.ASPECT_JAZDA:
					_fail("po utwierdzeniu przebiegu semafor C nie podał sygnału zezwalającego")
					return
				for wid in r2["sw"]:
					if str(sim.inter.sw_pos[wid]) != str(r2["sw"][wid]):
						_fail("rozjazd nr %s nie osiągnął wymaganego położenia" % wid)
						return
				_ok("Utwierdzenie przebiegu, rozjazdy w położeniu, sygnał zezwalający")
				_dalej()
		3:
			var t3 := sim.trains.get(poc_id) as Train
			if t3 != null and t3.state == Train.State.NA_TORZE:
				if t3.tor != "5":
					_fail("pociąg wjechał na tor %s zamiast 5" % t3.tor)
					return
				_ok("Wjazd na tor 5 zakończony")
				if sim.comms.confirm_arrival(t3) != "":
					_fail("potwierdzenie przyjazdu nie powiodło się")
					return
				_ok("Potwierdzenie przyjazdu „w całości”")
				_dalej()
		4:
			# 3. wyprawienie bez pozwolenia musi zostać odrzucone
			var t4 := sim.trains.get(poc_id) as Train
			t4.state = Train.State.GOTOWY
			sim.click_element("signal", "N5")
			sim.click_element("line_end", "it1R")
			if not sim.inter.route_of_signal("N5").is_empty():
				_fail("wyprawiono pociąg bez pozwolenia sąsiedniego posterunku")
				return
			_ok("Odmowa nastawienia przebiegu wyjazdowego bez pozwolenia")
			if sim.comms.ask_permission(t4) != "":
				_fail("żądanie pozwolenia nie powiodło się")
				return
			_dalej()
		5:
			if sim.comms.permission_status(poc_id) == "udzielone":
				_ok("Otrzymano pozwolenie na wyprawienie pociągu")
				_dalej()
			elif sim.comms.permission_status(poc_id) == "odmowa":
				sim.comms.perm.erase(poc_id)
				sim.comms.ask_permission(sim.trains.get(poc_id))
		6:
			sim.click_element("signal", "N5")
			sim.click_element("line_end", "it1R")
			var t6 := sim.trains.get(poc_id) as Train
			if t6 == null or t6.actual_dep < 0.0:
				_fail("przebieg wyjazdowy N5 → it1R nie ruszył pociągu")
				return
			_ok("Przebieg wyjazdowy N5 → szlak W-wa Rembertów")
			if sim.comms.announce_departure(t6) != "":
				_fail("oznajmienie odjazdu nie powiodło się")
				return
			_ok("Oznajmienie odjazdu sąsiedniemu posterunkowi")
			_dalej()
		7:
			if sim.trains.get(poc_id) == null:
				_ok("Pociąg opuścił posterunek (zwolnienie przebiegu na szlaku)")
				_dalej()
		8:
			# 4. jazda manewrowa z Grochowa na tor 8
			sim.admit_train({
				"nr": "Pm900", "kat": "MAN", "nazwa": "", "z": "Grochów", "do": "tor 8",
				"we": "itG", "wy": "itG", "tor": "8",
				"arr": sim.sim_time, "dep": -1.0, "postoj": 0.0,
				"przelot": false, "koniec": false, "man": true,
				"tt_index": -1, "delay": 0, "podstawienie": true})
			var m := _poc("Pm900")
			if m == null:
				_fail("skład manewrowy się nie zgłosił")
				return
			man_id = m.id
			sim.set_cmd_mode(SimCore.CMD_PM)
			sim.click_element("signal", "Tm1")
			sim.click_element("signal", "K8")
			var rm := sim.inter.route_of_signal("Tm1")
			if rm.is_empty():
				_fail("przebieg manewrowy Tm1 → K8 nie został nastawiony")
				return
			if str(rm["kind"]) != "M":
				_fail("przebieg z tarczy manewrowej nie jest manewrowy")
				return
			_ok("Przebieg manewrowy Tm1 → K8 (Grochów → tor 8)")
			_dalej()
		9:
			var m2 := sim.trains.get(man_id) as Train
			if m2 != null and m2.state == Train.State.NA_TORZE:
				if m2.tor != "8":
					_fail("skład podstawiony na tor %s zamiast 8" % m2.tor)
					return
				if sim.inter.aspect("Tm1") != Interlocking.ASPECT_STOP:
					_fail("tarcza manewrowa nie wróciła do sygnału „Stój”")
					return
				_ok("Skład podstawiony na tor 8")
				_dalej()
		10:
			# 5. usterka semafora + sygnał zastępczy
			var ev := sim.events.force_event(sim.sim_time, "semafor", "A")
			if ev.is_empty():
				_fail("nie udało się wywołać usterki semafora")
				return
			ev_id = int(ev["id"])
			sim.admit_train({
				"nr": "9902", "kat": "ROJ", "nazwa": "", "z": "W-wa Zachodnia", "do": "Otwock",
				"we": "it1P", "wy": "it1W", "tor": "1",
				"arr": sim.sim_time, "dep": sim.sim_time + 200.0, "postoj": 120.0,
				"przelot": false, "koniec": false, "man": false,
				"tt_index": -1, "delay": 0, "podstawienie": false})
			szt_id = _poc("9902").id
			sim.set_cmd_mode(SimCore.CMD_PP)
			sim.click_element("signal", "A")
			sim.click_element("signal", "N1")
			var ra := sim.inter.route_of_signal("A")
			if ra.is_empty():
				_fail("przebieg przy uszkodzonym semaforze nie został nastawiony")
				return
			_ok("Przebieg A → N1 nastawiony mimo usterki semafora")
			_dalej()
		11:
			var ra2 := sim.inter.route_of_signal("A")
			if ra2.is_empty() or str(ra2["state"]) != Interlocking.ST_UTWIERDZONY:
				return
			if sim.inter.aspect("A") != Interlocking.ASPECT_STOP:
				_fail("uszkodzony semafor podał sygnał zezwalający")
				return
			var en := sim.signal_menu_enabled("A")
			if not bool(en["SZ"]):
				_fail("polecenie SZ niedostępne mimo utwierdzonego przebiegu")
				return
			sim.exec_signal_cmd("A", "SZ")
			if sim.inter.aspect("A") != Interlocking.ASPECT_SZ:
				_fail("sygnał zastępczy nie został podany")
				return
			_ok("Sygnał zastępczy (Sz) podany na uszkodzonym semaforze A")
			_dalej()
		12:
			var t12 := sim.trains.get(szt_id) as Train
			if t12 != null and t12.state == Train.State.NA_TORZE:
				_ok("Pociąg wjechał na sygnał zastępczy na tor %s" % t12.tor)
				_dalej()
		13:
			# 6. zgłoszenie usterki do niewłaściwej i właściwej służby
			if sim.comms.report_fault(ev_id, "SOK") == "":
				_fail("zgłoszenie do niewłaściwej służby zostało przyjęte")
				return
			if sim.events.unreported_count() != 1:
				_fail("usterka została oznaczona jako zgłoszona mimo błędnej służby")
				return
			if sim.comms.report_fault(ev_id, "AUT") != "":
				_fail("zgłoszenie do Automatyka SRK nie powiodło się")
				return
			var ev2 := sim.events.by_id(ev_id)
			if not bool(ev2["zgloszona"]) or float(ev2["usun_at"]) <= sim.sim_time:
				_fail("po zgłoszeniu nie rozpoczęło się usuwanie usterki")
				return
			_ok("Zgłoszenie usterki — rozpoczęto usuwanie (ETA %d min)" % int(
				(float(ev2["usun_at"]) - sim.sim_time) / 60.0))
			# deterministycznie: skróć czas naprawy, aby test nie zależał od FPS
			ev2["usun_at"] = sim.sim_time + 30.0
			_dalej()
		14:
			if sim.events.by_id(ev_id).is_empty():
				if sim.inter.is_signal_failed("A"):
					_fail("po usunięciu usterki semafor nadal uszkodzony")
					return
				_ok("Usterka usunięta — urządzenia sprawne")
				_dalej()
		15:
			# 7. indywidualne przestawienie rozjazdu (ZW)
			sim.set_cmd_mode(SimCore.CMD_ZW)
			var przed := str(sim.inter.sw_pos["1"])
			sim.click_element("switch", "1")
			if str(sim.inter.sw_pos["1"]) == przed:
				_fail("polecenie ZW nie przestawiło rozjazdu nr 1")
				return
			_ok("ZW — rozjazd nr 1 przestawiony z %s na %s" % [przed, str(sim.inter.sw_pos["1"])])
			_dalej()
		16:
			# 8. przebieg bez pociągu i jego zwolnienie (ZD)
			sim.set_cmd_mode(SimCore.CMD_PP)
			sim.click_element("signal", "P")
			sim.click_element("signal", "K6")
			if sim.inter.route_of_signal("P").is_empty():
				_fail("przebieg P → K6 nie został nastawiony")
				return
			sim.set_cmd_mode(SimCore.CMD_ZDM)
			sim.click_element("signal", "P")
			if sim.inter.route_of_signal("P").is_empty():
				_fail("ZDM zwolnił przebieg pociągowy")
				return
			sim.set_cmd_mode(SimCore.CMD_ZD)
			sim.click_element("signal", "P")
			if not sim.inter.route_of_signal("P").is_empty():
				_fail("ZD nie zwolnił drogi przebiegu")
				return
			_ok("ZD — zwolnienie drogi przebiegu (ZDM odrzucone dla przebiegu pociągowego)")
			_dalej()
		17:
			# 9. wrogość przebiegów
			sim.set_cmd_mode(SimCore.CMD_PP)
			sim.click_element("signal", "P")
			sim.click_element("signal", "K6")
			sim.click_element("signal", "R")
			sim.click_element("signal", "K6")
			if not sim.inter.route_of_signal("R").is_empty():
				_fail("nastawiono przebieg wrogi na zajęty tor")
				return
			_ok("Kontrola wrogości przebiegów — drugi przebieg na tor 6 odrzucony")
			sim.set_cmd_mode(SimCore.CMD_ZD)
			sim.click_element("signal", "P")
			_dalej()
		18:
			# 10. EDR i rozkład jazdy
			if sim.edr.entries.size() < 20:
				_fail("EDR ma podejrzanie mało zapisów (%d)" % sim.edr.entries.size())
				return
			if sim.tt.entries.size() < 35:
				_fail("rozkład jazdy nie został wczytany (%d poz.)" % sim.tt.entries.size())
				return
			if sim.tt.upcoming(sim.sim_time, 4).size() != 4:
				_fail("skrócony rozkład nie zwrócił czterech najbliższych pociągów")
				return
			var kat := {}
			for e in sim.edr.entries:
				kat[str(e["kat"])] = true
			for wymagana in ["Zapowiedź", "Przebieg", "Ruch", "Manewry", "Usterka"]:
				if not kat.has(wymagana):
					_fail("w EDR brakuje zapisów rodzaju „%s”" % wymagana)
					return
			var p: String = sim.edr.save_to_file()
			if p == "":
				_fail("zapis EDR do pliku nie powiódł się")
				return
			_ok("EDR: %d zapisów wszystkich rodzajów, rozkład: %d pozycji, plik zapisany" % [
				sim.edr.entries.size(), sim.tt.entries.size()])
			_koniec()
