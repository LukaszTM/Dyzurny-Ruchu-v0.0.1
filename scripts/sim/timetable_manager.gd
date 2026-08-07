class_name TimetableManager
extends RefCounted
## Rozkład jazdy: wczytywanie z pliku lokalizacji, uruchamianie pociągów
## o właściwej porze, statusy dla panelu rozkładu oraz aktualizacja
## rozkładu i opóźnień online (HTTP).

var sim = null
var entries: Array = []      # znormalizowane wiersze rozkładu
var start_time := 4.75 * 3600.0
var online_status := "brak aktualizacji"
var last_online_update := ""


func _init(p_sim) -> void:
	sim = p_sim


func load_file(path: String) -> bool:
	var raw: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not (raw is Dictionary):
		return false
	_apply_timetable_dict(raw)
	return true


func _apply_timetable_dict(data: Dictionary) -> void:
	var st := SimUtil.parse_hhmm(str(data.get("start_time", "04:45")))
	if st >= 0.0:
		start_time = st
	entries.clear()
	for e in data.get("entries", []):
		entries.append(_normalize(e))


func _normalize(e: Dictionary) -> Dictionary:
	return {
		"nr": str(e.get("nr", "?")),
		"kat": str(e.get("kat", "SKM")),
		"nazwa": str(e.get("nazwa", "")),
		"z": str(e.get("z", "?")),
		"do": str(e.get("do", "?")),
		"we": str(e.get("we", "")),
		"wy": str(e.get("wy", "")),
		"tor": str(e.get("tor", "")),
		"arr_sec": SimUtil.parse_hhmm(str(e.get("przyjazd", ""))),
		"dep_sec": SimUtil.parse_hhmm(str(e.get("odjazd", ""))),
		"przelot": bool(e.get("przelot", false)),
		"start": bool(e.get("start", false)),
		"koniec": bool(e.get("koniec", false)),
		"delay_min": int(e.get("opoznienie", 0)),
		"spawned": false,
		"train_id": 0,
		"stock_id": 0,
		"converted": false,
		"status": "",
		"actual_arr": -1.0,
		"actual_dep": -1.0,
	}


## Pomija wiersze, które wg rozkładu zakończyły bieg przed startem symulacji.
func skip_past(now: float) -> void:
	for e in entries:
		var last: float = maxf(e["arr_sec"], e["dep_sec"])
		if last >= 0.0 and last < now - 60.0:
			e["spawned"] = true
			e["status"] = "przed objęciem dyżuru"


func step(now: float) -> void:
	for i in range(entries.size()):
		var e: Dictionary = entries[i]
		if not e["spawned"]:
			var spawn_at := _spawn_time(e)
			if now >= spawn_at:
				_spawn_entry(e, i, now)
		elif e["start"] and not e["converted"] and e["stock_id"] != 0:
			_try_convert_stock(e, i, now)


func _spawn_time(e: Dictionary) -> float:
	if e["start"]:
		return e["dep_sec"] - 1200.0
	var base: float = e["arr_sec"] if e["arr_sec"] >= 0.0 else e["dep_sec"]
	return base + e["delay_min"] * 60.0 - 150.0


func _spawn_entry(e: Dictionary, idx: int, _now: float) -> void:
	e["spawned"] = true
	if e["start"]:
		# pociąg zaczyna bieg na stacji: najpierw skład manewrowy z zaplecza
		var spec := {
			"nr": "M-%s" % e["nr"], "kat": "MAN", "nazwa": "",
			"z": "Grochów", "do": "tor %s (skład poc. %s)" % [e["tor"], e["nr"]],
			"we": e["we"], "wy": e["we"],
			"tor": e["tor"], "arr_sec": -1.0, "dep_sec": -1.0,
			"przelot": false, "koniec": false, "man": true,
			"tt_index": idx, "delay_min": 0, "linked_stock": true,
		}
		var t: Train = sim.spawn_from_spec(spec)
		if t != null:
			e["stock_id"] = t.id
			e["status"] = "skład do podstawienia z Grochowa"
			sim.add_shunt_job("podstawienie",
				"Podstawić skład poc. %s %s z Grochowa na tor %s (odjazd %s)." % [
					e["kat"], e["nr"], e["tor"], SimUtil.fmt_hm(e["dep_sec"])],
				t.id)
		return
	var spec2 := {
		"nr": e["nr"], "kat": e["kat"], "nazwa": e["nazwa"],
		"z": e["z"], "do": e["do"],
		"we": e["we"], "wy": e["wy"], "tor": e["tor"],
		"arr_sec": e["arr_sec"] + e["delay_min"] * 60.0,
		"dep_sec": e["dep_sec"],
		"przelot": e["przelot"], "koniec": e["koniec"], "man": false,
		"tt_index": idx, "delay_min": e["delay_min"],
	}
	var t2: Train = sim.spawn_from_spec(spec2)
	if t2 != null:
		e["train_id"] = t2.id
		e["status"] = "zapowiedziany" + SimUtil.fmt_delay(e["delay_min"])


func _try_convert_stock(e: Dictionary, idx: int, now: float) -> void:
	var t: Train = sim.trains.get(e["stock_id"])
	if t == null:
		e["stock_id"] = 0
		return
	if t.state != Train.State.AT_PLATFORM and t.state != Train.State.READY:
		if now > e["dep_sec"] + 60.0:
			e["status"] = "brak składu — opóźnienie rośnie"
		return
	if now < e["dep_sec"] - 480.0:
		return
	# skład staje się pociągiem rozkładowym
	t.nr = e["nr"]
	t.category = e["kat"]
	t.display_name = e["nazwa"]
	t.from_name = e["z"]
	t.to_name = e["do"]
	t.exit_portal = e["wy"]
	t.sched_dep = e["dep_sec"]
	t.is_shunt_unit = false
	t.flag_koniec = false
	t.flag_start = false
	t.length = Train.length_for(e["kat"])
	t.tt_index = idx
	t.state = Train.State.AT_PLATFORM
	e["converted"] = true
	e["train_id"] = t.id
	e["status"] = "podstawiony na tor %s" % t.track_nr
	sim.dlog.add(now, "Ruch", "Skład poc. %s %s podstawiony na tor %s — planowy odjazd %s." % [
		e["kat"], e["nr"], t.track_nr, SimUtil.fmt_hm(e["dep_sec"])])


## Dodanie wiersza dla pociągu z generatora losowego (wspólny panel rozkładu).
func add_generated_entry(spec: Dictionary, train_id: int) -> int:
	var e := _normalize({
		"nr": spec["nr"], "kat": spec["kat"], "nazwa": spec.get("nazwa", ""),
		"z": spec["z"], "do": spec["do"],
		"we": spec["we"], "wy": spec["wy"], "tor": spec.get("tor", ""),
	})
	e["arr_sec"] = spec.get("arr_sec", -1.0)
	e["dep_sec"] = spec.get("dep_sec", -1.0)
	e["przelot"] = spec.get("przelot", false)
	e["koniec"] = spec.get("koniec", false)
	e["delay_min"] = spec.get("delay_min", 0)
	e["spawned"] = true
	e["train_id"] = train_id
	e["status"] = "zapowiedziany" + SimUtil.fmt_delay(e["delay_min"])
	entries.append(e)
	return entries.size() - 1


func entry_status_update(idx: int, status: String) -> void:
	if idx >= 0 and idx < entries.size():
		entries[idx]["status"] = status


## --- Aktualizacja online ---

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
			if e["nr"] != nr or e["actual_arr"] >= 0.0:
				continue
			e["delay_min"] = dm
			if e["spawned"] and e["train_id"] != 0:
				var t: Train = sim.trains.get(e["train_id"])
				if t != null and t.state == Train.State.WAITING:
					t.delay_min = dm
			elif e["spawned"]:
				continue
			e["status"] = ("zapowiedziany" + SimUtil.fmt_delay(dm)) if e["spawned"] else e["status"]
			count += 1
	last_online_update = Time.get_datetime_string_from_system()
	online_status = "opóźnienia zaktualizowane (%d poz.), %s" % [count, last_online_update]
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
			if e["nr"] == nr:
				found = true
				break
		if not found:
			var ne := _normalize(e_raw)
			var last: float = maxf(ne["arr_sec"], ne["dep_sec"])
			if last >= sim.sim_time:
				entries.append(ne)
				count += 1
	if count > 0:
		entries.sort_custom(func(a, b):
			var ta: float = a["arr_sec"] if a["arr_sec"] >= 0.0 else a["dep_sec"]
			var tb: float = b["arr_sec"] if b["arr_sec"] >= 0.0 else b["dep_sec"]
			return ta < tb)
	last_online_update = Time.get_datetime_string_from_system()
	online_status = "rozkład zaktualizowany (+%d poc.), %s" % [count, last_online_update]
	EventBus.timetable_updated.emit("timetable")
	return count
