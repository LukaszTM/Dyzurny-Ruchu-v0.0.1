class_name TimetableManager
extends RefCounted
## Rozkład jazdy: wczytanie z pliku lokalizacji, zapowiadanie pociągów o
## właściwej porze, statusy dla wykazu pociągów oraz aktualizacja rozkładu
## i opóźnień online.

var sim = null
var entries: Array = []
var start_time := 4.75 * 3600.0
var online_status := "brak aktualizacji"


func _init(p_sim) -> void:
	sim = p_sim


func load_file(path: String) -> bool:
	var raw: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not (raw is Dictionary):
		return false
	var data: Dictionary = raw
	var st := SimUtil.parse_hhmm(str(data.get("start_time", "04:45")))
	if st >= 0.0:
		start_time = st
	entries.clear()
	for e in data.get("entries", []):
		entries.append(normalize(e))
	return true


func normalize(e: Dictionary) -> Dictionary:
	return {
		"nr": str(e.get("nr", "?")),
		"kat": str(e.get("kat", "ROJ")),
		"nazwa": str(e.get("nazwa", "")),
		"z": str(e.get("z", "?")),
		"do": str(e.get("do", "?")),
		"we": str(e.get("we", "")),
		"wy": str(e.get("wy", "")),
		"tor": str(e.get("tor", "")),
		"arr": SimUtil.parse_hhmm(str(e.get("przyjazd", ""))),
		"dep": SimUtil.parse_hhmm(str(e.get("odjazd", ""))),
		"postoj": float(e.get("postoj", 0)) * 60.0,
		"przelot": bool(e.get("przelot", false)),
		"start": bool(e.get("start", false)),
		"koniec": bool(e.get("koniec", false)),
		"delay": int(e.get("opoznienie", 0)),
		"zapowiedziany": false,
		"train_id": 0,
		"stock_id": 0,
		"converted": false,
		"status": "",
		"actual_arr": -1.0,
		"actual_dep": -1.0,
		"potwierdzony": false,
	}


func skip_past(now: float) -> void:
	for e in entries:
		var last: float = maxf(e["arr"], e["dep"])
		if last >= 0.0 and last < now - 60.0:
			e["zapowiedziany"] = true
			e["status"] = "przed objęciem dyżuru"


func step(now: float) -> void:
	for i in range(entries.size()):
		var e: Dictionary = entries[i]
		if not e["zapowiedziany"]:
			if now >= _zapowiedz_time(e):
				_announce(e, i)
		elif e["start"] and not e["converted"] and int(e["stock_id"]) != 0:
			_try_convert(e, i, now)


func _zapowiedz_time(e: Dictionary) -> float:
	if e["start"]:
		return float(e["dep"]) - 1500.0
	var base: float = e["arr"] if float(e["arr"]) >= 0.0 else e["dep"]
	return base + float(e["delay"]) * 60.0 - 240.0


func _announce(e: Dictionary, idx: int) -> void:
	e["zapowiedziany"] = true
	if e["start"]:
		var spec := {
			"nr": "Pm%s" % str(e["nr"]), "kat": "MAN", "nazwa": "",
			"z": "Grochów", "do": "tor %s (skład poc. %s)" % [str(e["tor"]), str(e["nr"])],
			"we": "itG", "wy": "itG", "tor": str(e["tor"]),
			"arr": -1.0, "dep": -1.0, "postoj": 0.0,
			"przelot": false, "koniec": false, "man": true,
			"tt_index": idx, "delay": 0, "podstawienie": true,
		}
		e["status"] = "skład do podstawienia z Grochowa"
		sim.request_train(spec)
		return
	var spec2 := {
		"nr": str(e["nr"]), "kat": str(e["kat"]), "nazwa": str(e["nazwa"]),
		"z": str(e["z"]), "do": str(e["do"]),
		"we": str(e["we"]), "wy": str(e["wy"]), "tor": str(e["tor"]),
		"arr": float(e["arr"]) + float(e["delay"]) * 60.0,
		"dep": float(e["dep"]), "postoj": float(e["postoj"]),
		"przelot": bool(e["przelot"]), "koniec": bool(e["koniec"]), "man": false,
		"tt_index": idx, "delay": int(e["delay"]), "podstawienie": false,
	}
	e["status"] = "zapowiedziany" + SimUtil.fmt_delay(int(e["delay"]))
	sim.request_train(spec2)


func _try_convert(e: Dictionary, idx: int, now: float) -> void:
	var t: Train = sim.trains.get(int(e["stock_id"]))
	if t == null:
		e["stock_id"] = 0
		return
	if t.state != Train.State.NA_TORZE and t.state != Train.State.GOTOWY:
		if now > float(e["dep"]) + 60.0:
			e["status"] = "brak składu — opóźnienie rośnie"
		return
	if now < float(e["dep"]) - 600.0:
		return
	t.nr = str(e["nr"])
	t.rodzaj = str(e["kat"])
	t.nazwa = str(e["nazwa"])
	t.st_poczatkowa = str(e["z"])
	t.st_koncowa = str(e["do"])
	t.wyjazd = str(e["wy"])
	t.sched_dep = float(e["dep"])
	t.manewrowy = false
	t.flag_koniec = false
	t.flag_podstawienie = false
	t.dlugosc = Train.length_for(str(e["kat"]))
	t.tt_index = idx
	t.state = Train.State.NA_TORZE
	e["converted"] = true
	e["train_id"] = t.id
	e["status"] = "podstawiony na tor %s" % t.tor
	sim.edr.add(now, "Manewry", "Skład poc. %s podstawiony na tor %s; planowy odjazd %s." % [
		t.opis(), t.tor, SimUtil.fmt_hm(float(e["dep"]))], t.nr, t.tor)


func add_generated(spec: Dictionary, train_id: int) -> int:
	var e := normalize({
		"nr": spec["nr"], "kat": spec["kat"], "nazwa": spec.get("nazwa", ""),
		"z": spec["z"], "do": spec["do"], "we": spec["we"], "wy": spec["wy"],
		"tor": spec.get("tor", ""),
	})
	e["arr"] = float(spec.get("arr", -1.0))
	e["dep"] = float(spec.get("dep", -1.0))
	e["przelot"] = bool(spec.get("przelot", false))
	e["koniec"] = bool(spec.get("koniec", false))
	e["delay"] = int(spec.get("delay", 0))
	e["zapowiedziany"] = true
	e["train_id"] = train_id
	e["status"] = "zapowiedziany" + SimUtil.fmt_delay(int(e["delay"]))
	entries.append(e)
	return entries.size() - 1


func set_status(idx: int, status: String) -> void:
	if idx >= 0 and idx < entries.size():
		entries[idx]["status"] = status


## Nowa doba (rozkład dobowy) — wyzeruj stan wszystkich pozycji.
func reset_for_new_day() -> void:
	for e in entries:
		e["zapowiedziany"] = false
		e["train_id"] = 0
		e["stock_id"] = 0
		e["converted"] = false
		e["status"] = ""
		e["actual_arr"] = -1.0
		e["actual_dep"] = -1.0
		e["potwierdzony"] = false


## Najbliższe pozycje rozkładu do skróconego podglądu na pulpicie.
func upcoming(now: float, count: int) -> Array:
	var kand: Array = []
	for e in entries:
		if float(e["actual_dep"]) >= 0.0 or str(e["status"]) == "przed objęciem dyżuru":
			continue
		var t_ref: float = e["dep"] if float(e["dep"]) >= 0.0 else e["arr"]
		if float(e["actual_arr"]) < 0.0 and float(e["arr"]) >= 0.0:
			t_ref = float(e["arr"]) + float(e["delay"]) * 60.0
		if t_ref < 0.0:
			continue
		if t_ref < now - 900.0:
			continue
		kand.append({"e": e, "t": t_ref})
	kand.sort_custom(func(a, b): return float(a["t"]) < float(b["t"]))
	var res: Array = []
	for i in range(mini(count, kand.size())):
		res.append(kand[i]["e"])
	return res


# ------------------------------------------------------- aktualizacje online

func apply_online_delays(body: String) -> int:
	var raw: Variant = JSON.parse_string(body)
	if not (raw is Dictionary):
		return -1
	var count := 0
	for d in raw.get("delays", []):
		if not (d is Dictionary):
			continue
		var nr := str(d.get("nr", ""))
		var dm := int(d.get("delay_min", 0))
		for e in entries:
			if str(e["nr"]) != nr or float(e["actual_arr"]) >= 0.0:
				continue
			e["delay"] = dm
			if not bool(e["zapowiedziany"]):
				e["status"] = "opóźnienie %+d min" % dm
			count += 1
	online_status = "opóźnienia zaktualizowane (%d poz.) — %s" % [count, Time.get_time_string_from_system()]
	EventBus.timetable_updated.emit("delays")
	return count


func apply_online_timetable(body: String) -> int:
	var raw: Variant = JSON.parse_string(body)
	if not (raw is Dictionary) or not raw.has("entries"):
		return -1
	var count := 0
	for e_raw in raw.get("entries", []):
		if not (e_raw is Dictionary):
			continue
		var nr := str(e_raw.get("nr", ""))
		var found := false
		for e in entries:
			if str(e["nr"]) == nr:
				found = true
				break
		if found:
			continue
		var ne := normalize(e_raw)
		if maxf(ne["arr"], ne["dep"]) >= sim.sim_time:
			entries.append(ne)
			count += 1
	if count > 0:
		entries.sort_custom(func(a, b):
			var ta: float = a["arr"] if float(a["arr"]) >= 0.0 else a["dep"]
			var tb: float = b["arr"] if float(b["arr"]) >= 0.0 else b["dep"]
			return ta < tb)
	online_status = "rozkład zaktualizowany (+%d poc.) — %s" % [count, Time.get_time_string_from_system()]
	EventBus.timetable_updated.emit("timetable")
	return count
