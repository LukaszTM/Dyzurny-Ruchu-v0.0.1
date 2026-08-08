extends Node
## „Automatyczny dyżurny” — headless test przepustowości posterunku.
## Gra jak gracz: odbiera rozmowy, nastawia przebiegi wjazdowe dla
## oczekujących pociągów, potwierdza przyjazdy, żąda pozwoleń, nastawia
## przebiegi wyjazdowe i manewrowe. Wykrywa KAŻDY zablokowany pociąg
## (oczekujący/gotowy zbyt długo) i raportuje przyczynę.
## Na początku sprawdza scenariusz ZD: zwolnienie przebiegu z przydzielonym
## pociągiem musi zwrócić pociąg do kolejki.
##
##   godot --headless --path . res://tests/DispatchProbe.tscn --quit-after 90000

const CZAS_TESTU := 5400.0        # 90 min czasu symulacji
const LIMIT_OCZEKUJE := 1500.0
const LIMIT_GOTOWY := 1800.0
const LIMIT_NA_TORZE := 2700.0

var sim: SimCore
var entry_sig := {}          # line_end -> semafor wjazdowy
var t0 := -1.0
var faza0 := 0
var blad := false
var _stany := {}             # train_id -> {state, since}
var _acc := 0.0


func _ready() -> void:
	Settings.require_zapowiadanie = true
	Settings.shunting_enabled = true
	Settings.online_enabled = false
	sim = SimCore.new()
	add_child(sim)
	sim.setup(GameState.MODE_TIMETABLE, "warszawa_wschodnia")
	sim.events.freq_min = 0.0
	sim.events.next_at = -1.0
	sim.time_scale = 20.0
	GameState.sim = sim
	for sid in sim.layout.signals:
		var sg: Dictionary = sim.layout.signals[sid]
		if str(sg["typ"]) in ["wjazdowy", "manewrowy"]:
			var le: String = sim._line_end_of_signal(sid)
			if le != "":
				entry_sig[le] = sid
	print("DYSPOZYTOR: start, semafory wjazdowe: ", entry_sig)


func _fail(msg: String) -> void:
	print("[FAIL] ", msg)
	print("       ostatni komunikat pulpitu: ", sim.last_message)
	_dump()
	blad = true
	_koniec()


func _dump() -> void:
	print("  --- aktywne przebiegi ---")
	for r in sim.inter.routes.values():
		print("  przebieg #%d %s->%s kind=%s stan=%s train=%d passed=%s" % [
			int(r["id"]), str(r["signal_id"]), str(r["dest_id"]), str(r["kind"]),
			str(r["state"]), int(r["train_id"]), str(r["passed"])])
	print("  --- pociągi ---")
	for t: Train in sim.trains.values():
		print("  poc. %s %s tor=%s stan=%s s=%.0f/%.0f route=%s" % [
			t.rodzaj, t.nr, t.tor, t.state_text(), t.s, t.total,
			str(t.route.get("signal_id", "-"))])
	print("  --- zajętości ---")
	print("  occupied: ", sim.inter.occupied_segs)
	print("  locked: ", sim.inter.locked_segs)


func _ok(msg: String) -> void:
	print("[PASS] ", msg)


func _koniec() -> void:
	print("DYSPOZYTOR: obsłużone=%d odjazdy=%d punktualność=%.0f%%" % [
		int(sim.stats["obsluzone"]), int(sim.stats["odjazdy"]), sim.punctuality()])
	print("TEST DYSPOZYTORA: ", "NIEPOWODZENIE" if blad else "OK")
	get_tree().quit(1 if blad else 0)


func _process(_d: float) -> void:
	if sim == null or blad:
		return
	if faza0 < 100:
		_test_zd()
		return
	if t0 < 0.0:
		t0 = sim.sim_time
	_acc += 1.0
	if _acc >= 3.0:
		_acc = 0.0
		_dyspozytor()
	_kontrola_zakleszczen()
	if sim.sim_time - t0 >= CZAS_TESTU:
		if int(sim.stats["obsluzone"]) < 10:
			_fail("obsłużono tylko %d pociągów w 90 min" % int(sim.stats["obsluzone"]))
			return
		if int(sim.stats["odjazdy"]) < 6:
			_fail("tylko %d odjazdów w 90 min" % int(sim.stats["odjazdy"]))
			return
		_ok("Przepustowość: %d obsłużonych, %d odjazdów, bez zakleszczeń" % [
			int(sim.stats["obsluzone"]), int(sim.stats["odjazdy"])])
		_koniec()


## Scenariusz ZD: przebieg z przydzielonym pociągiem zwolniony przed jazdą.
func _test_zd() -> void:
	match faza0:
		0:
			sim.admit_train({
				"nr": "9900", "kat": "EIE", "nazwa": "TestZD", "z": "W-wa Zachodnia",
				"do": "Białystok", "we": "it1D", "wy": "it1R", "tor": "5",
				"arr": sim.sim_time, "dep": sim.sim_time + 240.0, "postoj": 120.0,
				"przelot": false, "koniec": false, "man": false,
				"tt_index": -1, "delay": 0, "podstawienie": false})
			sim.set_cmd_mode(SimCore.CMD_PP)
			sim.click_element("signal", "C")
			sim.click_element("signal", "N5")
			if sim.inter.route_of_signal("C").is_empty():
				_fail("ZD-test: przebieg C->N5 nie został nastawiony")
				return
			sim.set_cmd_mode(SimCore.CMD_ZD)
			sim.click_element("signal", "C")
			if not sim.inter.route_of_signal("C").is_empty():
				_fail("ZD-test: ZD nie zwolniło przebiegu")
				return
			var t: Train = null
			for tr: Train in sim.trains.values():
				if tr.nr == "9900":
					t = tr
			if t == null or t.state != Train.State.OCZEKUJE:
				_fail("ZD-test: po ZD pociąg nie wrócił do stanu OCZEKUJE (osierocony!)")
				return
			if sim.queues["it1D"].is_empty() or int(sim.queues["it1D"][0]) != t.id:
				_fail("ZD-test: po ZD pociąg nie wrócił do kolejki na szlaku")
				return
			_ok("ZD z przydzielonym pociągiem — pociąg wrócił do kolejki")
			sim.set_cmd_mode(SimCore.CMD_PP)
			sim.click_element("signal", "C")
			sim.click_element("signal", "N5")
			var r: Dictionary = sim.inter.route_of_signal("C")
			if r.is_empty() or int(r["train_id"]) != t.id:
				_fail("ZD-test: ponowny przebieg nie przydzielił pociągu")
				return
			faza0 = 1
		1:
			for tr: Train in sim.trains.values():
				if tr.nr == "9900" and tr.state == Train.State.NA_TORZE:
					_ok("ZD-test: pociąg po ponownym przebiegu wjechał na tor %s" % tr.tor)
					faza0 = 100
					return


func _wjazd_na_wschod(t: Train) -> bool:
	return int(sim.layout.line_ends[t.wjazd]["dir_in"]) == 1


func _tory_dla(t: Train) -> Array:
	var pref: Array = []
	if t.tor_zadany != "" and t.tor_zadany != "9":
		pref.append(t.tor_zadany)
	var grupa: Array = ["1", "3", "2", "4"] if t.rodzaj in ["AOE", "ROJ"] else ["5", "7", "6", "8"]
	for nr in grupa:
		if not pref.has(nr):
			pref.append(nr)
	return pref


func _tor_zajety(nr: String) -> bool:
	for t: Train in sim.trains.values():
		if t.tor == nr and t.state != Train.State.ZAKONCZONY:
			return true
	return false


func _dyspozytor() -> void:
	# 1. łączność przychodząca
	for c in sim.comms.pending_calls():
		sim.comms.answer_call(int(c["id"]), true)
	# 2. wjazdy — pierwszy pociąg w każdej kolejce
	for le in sim.queues:
		var q: Array = sim.queues[le]
		if q.is_empty():
			continue
		var t: Train = sim.trains.get(int(q[0]))
		if t == null or t.state != Train.State.OCZEKUJE:
			continue
		var sig: String = str(entry_sig.get(le, ""))
		if sig == "" or not sim.inter.route_of_signal(sig).is_empty():
			continue
		if t.flag_przelot:
			var st := sim.comms.permission_status(t.id)
			if st == "":
				sim.comms.ask_permission(t)
				continue
			if st == "odmowa":
				sim.comms.perm.erase(t.id)
				continue
			if st != "udzielone":
				continue
			sim.set_cmd_mode(SimCore.CMD_PP)
			sim.click_element("signal", sig)
			sim.click_element("line_end", t.wyjazd)
			continue
		var dest_lit := "N" if _wjazd_na_wschod(t) else "K"
		for tor in _tory_dla(t):
			if _tor_zajety(tor):
				continue
			sim.set_cmd_mode(SimCore.CMD_PM if t.manewrowy else SimCore.CMD_PP)
			sim.click_element("signal", sig)
			sim.click_element("signal", dest_lit + tor)
			if not sim.inter.route_of_signal(sig).is_empty():
				break
	# 3. przyjazdy i odjazdy
	for t2: Train in sim.trains.values():
		if t2.actual_arr >= 0.0 and not t2.manewrowy and t2.actual_dep < 0.0:
			sim.comms.confirm_arrival(t2)
		if t2.actual_dep >= 0.0 and not t2.manewrowy:
			sim.comms.announce_departure(t2)
		if t2.state != Train.State.GOTOWY:
			continue
		var pm: bool = t2.manewrowy or t2.flag_koniec or t2.wyjazd == "itG"
		if not pm:
			var st2 := sim.comms.permission_status(t2.id)
			if st2 == "":
				sim.comms.ask_permission(t2)
				continue
			if st2 == "odmowa":
				sim.comms.perm.erase(t2.id)
				continue
			if st2 != "udzielone":
				continue
		if t2.tor == "":
			continue
		var na_zachod: bool = int(sim.layout.line_ends[t2.wyjazd]["dir_in"]) == 1
		var start_sig := ("K" if na_zachod else "N") + t2.tor
		if not sim.inter.route_of_signal(start_sig).is_empty():
			continue
		sim.set_cmd_mode(SimCore.CMD_PM if pm else SimCore.CMD_PP)
		sim.click_element("signal", start_sig)
		sim.click_element("line_end", t2.wyjazd)


func _kontrola_zakleszczen() -> void:
	for t: Train in sim.trains.values():
		var rec: Dictionary = _stany.get(t.id, {})
		if int(rec.get("state", -1)) != t.state:
			_stany[t.id] = {"state": t.state, "since": sim.sim_time}
			continue
		var czekal: float = sim.sim_time - float(rec["since"])
		match t.state:
			Train.State.OCZEKUJE:
				if czekal > LIMIT_OCZEKUJE:
					_fail("poc. %s (%s) czeka przed stacją %d min mimo prób nastawienia przebiegu" % [
						t.nr, t.relacja(), int(czekal / 60.0)])
					return
			Train.State.GOTOWY:
				if czekal > LIMIT_GOTOWY:
					_fail("poc. %s gotowy na torze %s od %d min — nie da się go wyprawić (pozwolenie: %s)" % [
						t.nr, t.tor, int(czekal / 60.0), sim.comms.permission_status(t.id)])
					return
			Train.State.NA_TORZE:
				if czekal > LIMIT_NA_TORZE:
					_fail("poc. %s stoi na torze %s od %d min bez gotowości" % [
						t.nr, t.tor, int(czekal / 60.0)])
					return
			Train.State.JEDZIE:
				if czekal > 1200.0:
					_fail("poc. %s utknął w jeździe (%s)" % [t.nr, t.state_text()])
					return
