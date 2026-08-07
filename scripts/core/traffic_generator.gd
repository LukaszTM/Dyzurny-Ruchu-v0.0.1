class_name TrafficGenerator
extends RefCounted
## Tryb RUCH LOSOWY: przy rozpoczęciu dyżuru generowany jest FIKCYJNY
## całodobowy rozkład jazdy (widoczny w wykazie pociągów), według którego
## pociągi zgłaszają się na posterunek. Gęstość rozkładu wynika z natężenia
## ustawionego w opcjach gry; zmiana natężenia w trakcie dyżuru przebudowuje
## przyszłe, jeszcze niezapowiedziane pozycje rozkładu.
## Dodatkowo generator zleca okazjonalne prace manewrowe.

const NAZWY := ["Podlasiak", "Sawa", "Hetman", "Kmicic", "Bug", "Narew", "Cukrownik",
	"Żeromski", "Norwid", "Skarga", "Chopin", "Reymont", "Mazowsze", "Syrenka"]

var sim = null
var rng := RandomNumberGenerator.new()
var enabled := false
var next_shunt := -1.0
var _n := 0
var _ni := 0


func _init(p_sim) -> void:
	sim = p_sim
	rng.randomize()


## Zlecenia manewrowe (podstawienia składów z Grochowa) — losowo w tle.
func step(now: float) -> void:
	if not enabled or not Settings.shunting_enabled:
		return
	if next_shunt < 0.0:
		next_shunt = now + rng.randf_range(900.0, 1800.0)
	if now >= next_shunt:
		_shunt_job(now)
		next_shunt = now + rng.randf_range(1200.0, 2400.0)


func _nr(base: int) -> String:
	_n += 1
	return str(base + _n * 2 + rng.randi_range(0, 1))


## Generuje fikcyjny rozkład na całą dobę o zadanym natężeniu [poc./h].
## Zwraca liczbę pozycji.
func generate_day(tt: TimetableManager, intensity: float) -> int:
	var count := _generate_range(tt, 0.0, 86400.0, intensity)
	_sort_entries(tt)
	return count


## Przebudowa przyszłych, niezapowiedzianych pozycji (zmiana natężenia
## w trakcie dyżuru). Zwraca liczbę nowych pozycji.
func rebuild_future(tt: TimetableManager, now: float, intensity: float) -> int:
	var granica := now + 600.0
	var keep: Array = []
	for e in tt.entries:
		var ref: float = e["arr"] if float(e["arr"]) >= 0.0 else e["dep"]
		if bool(e["zapowiedziany"]) or ref <= granica:
			keep.append(e)
	tt.entries = keep
	var count := _generate_range(tt, granica, 86400.0, intensity)
	_sort_entries(tt)
	# indeksy pozycji zmieniły się — napraw powiązania pociągów
	for i in range(tt.entries.size()):
		var e2: Dictionary = tt.entries[i]
		for tid in [int(e2["train_id"]), int(e2["stock_id"])]:
			if tid != 0:
				var t: Train = sim.trains.get(tid)
				if t != null and t.tt_index >= 0:
					t.tt_index = i
	return count


func _sort_entries(tt: TimetableManager) -> void:
	tt.entries.sort_custom(func(a, b):
		var ta: float = a["arr"] if float(a["arr"]) >= 0.0 else a["dep"]
		var tb: float = b["arr"] if float(b["arr"]) >= 0.0 else b["dep"]
		return ta < tb)


func _generate_range(tt: TimetableManager, od: float, do_kiedy: float, intensity: float) -> int:
	var t := od
	var count := 0
	while true:
		var mean := 3600.0 / maxf(intensity, 1.0)
		@warning_ignore("integer_division")
		var godzina := int(t / 3600.0) % 24
		if godzina < 4:
			mean *= 3.0   # noc: rzadszy ruch (głównie towarowy)
		t += maxf(90.0, -log(1.0 - rng.randf()) * mean)
		if t >= do_kiedy:
			break
		tt.entries.append(_fictional_entry(t, godzina < 4))
		count += 1
	return count


func _fictional_entry(t: float, noc: bool) -> Dictionary:
	var e := {
		"nr": "", "kat": "ROJ", "nazwa": "", "z": "?", "do": "?",
		"we": "", "wy": "", "tor": "",
		"arr": t, "dep": -1.0, "postoj": 0.0,
		"przelot": false, "start": false, "koniec": false,
		"delay": 0, "zapowiedziany": false, "train_id": 0, "stock_id": 0,
		"converted": false, "status": "", "actual_arr": -1.0, "actual_dep": -1.0,
		"potwierdzony": false,
	}
	var roll := rng.randf()
	if noc:
		roll = 0.9   # nocą wyłącznie ruch towarowy i próżne składy
	if roll < 0.44:
		# ruch podmiejski (tory 1-4)
		var na_wschod := rng.randf() < 0.5
		e["kat"] = "AOE" if rng.randf() < 0.55 else "ROJ"
		e["nr"] = _nr(21000 if e["kat"] == "AOE" else 91000)
		e["postoj"] = rng.randf_range(60.0, 120.0)
		e["dep"] = t + float(e["postoj"])
		if na_wschod:
			e["we"] = "it1P"
			e["wy"] = "it1W"
			e["z"] = "Pruszków" if e["kat"] == "AOE" else "W-wa Zachodnia"
			e["do"] = "Otwock" if rng.randf() < 0.6 else "Mińsk Mazowiecki"
			e["tor"] = ["1", "3"][rng.randi_range(0, 1)]
		else:
			e["we"] = "it2W"
			e["wy"] = "it2P"
			e["z"] = "Otwock" if rng.randf() < 0.6 else "Mińsk Mazowiecki"
			e["do"] = "Pruszków" if e["kat"] == "AOE" else "W-wa Zachodnia"
			e["tor"] = ["2", "4"][rng.randi_range(0, 1)]
	elif roll < 0.80:
		# ruch dalekobieżny (tory 5-8)
		var na_wschod2 := rng.randf() < 0.5
		var r := rng.randf()
		e["kat"] = "MPE" if r < 0.5 else ("EIE" if r < 0.8 else "EIP")
		e["nr"] = _nr(1000 if e["kat"] == "MPE" else 4000)
		if e["kat"] != "MPE" and rng.randf() < 0.6:
			_ni += 1
			e["nazwa"] = NAZWY[_ni % NAZWY.size()]
		e["postoj"] = rng.randf_range(180.0, 300.0)
		e["dep"] = t + float(e["postoj"])
		if rng.randf() < 0.25:
			e["delay"] = rng.randi_range(2, 12)
		if na_wschod2:
			var przez_otwock := rng.randf() < 0.35
			e["we"] = "it1D"
			e["wy"] = "it1W" if przez_otwock else "it1R"
			e["z"] = "W-wa Zachodnia"
			e["do"] = "Lublin Główny" if przez_otwock else ("Białystok" if rng.randf() < 0.5 else "Terespol")
			e["tor"] = ["5", "7"][rng.randi_range(0, 1)]
			if Settings.shunting_enabled and rng.randf() < 0.08:
				# pociąg rozpoczyna bieg — skład do podstawienia z Grochowa
				e["start"] = true
				e["we"] = "itG"
				e["z"] = "W-wa Wschodnia"
				e["arr"] = -1.0
		else:
			var z_otwocka := rng.randf() < 0.35
			e["we"] = "it2W" if z_otwocka else "it2R"
			e["wy"] = "it2D"
			e["z"] = "Lublin Główny" if z_otwocka else ("Białystok" if rng.randf() < 0.5 else "Terespol")
			e["do"] = "W-wa Zachodnia"
			e["tor"] = ["6", "8"][rng.randi_range(0, 1)]
			if Settings.shunting_enabled and rng.randf() < 0.12:
				# pociąg kończy bieg — skład do odstawienia do Grochowa
				e["koniec"] = true
				e["wy"] = "itG"
				e["do"] = "W-wa Wschodnia"
				e["dep"] = -1.0
				e["postoj"] = 0.0
	else:
		# ruch towarowy / próżne składy — przelot
		e["przelot"] = true
		e["postoj"] = 0.0
		var pwe := noc and rng.randf() < 0.3
		e["kat"] = "PWE" if pwe else ("TME" if rng.randf() < 0.5 else "TDE")
		e["nr"] = _nr(38000 if pwe else 44000)
		if rng.randf() < 0.5:
			e["we"] = "it1D"
			e["wy"] = "itG" if rng.randf() < 0.2 else "it1R"
			e["z"] = "Pruszków"
			e["do"] = "Grochów" if e["wy"] == "itG" else "Małaszewicze"
			e["tor"] = "9" if e["wy"] == "itG" else "7"
		else:
			e["we"] = "it2R"
			e["wy"] = "it2D"
			e["z"] = "Małaszewicze"
			e["do"] = "Pruszków"
			e["tor"] = "8"
	return e


func _shunt_job(now: float) -> void:
	var tor: String = ["5", "6", "7", "8"][rng.randi_range(0, 3)]
	sim.request_train({
		"nr": "Pm%d" % rng.randi_range(100, 999), "kat": "MAN", "nazwa": "",
		"z": "Grochów", "do": "tor %s" % tor,
		"we": "itG", "wy": "itG", "tor": tor,
		"arr": now, "dep": -1.0, "postoj": 0.0,
		"przelot": false, "koniec": false, "man": true,
		"tt_index": -1, "delay": 0, "podstawienie": true,
	})
