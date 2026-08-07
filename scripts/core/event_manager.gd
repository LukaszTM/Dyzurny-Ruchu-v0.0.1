class_name RandomEventManager
extends RefCounted
## Zdarzenia losowe. Usterki NIE ustępują same — dyżurny musi je zgłosić
## właściwej służbie przez łączność, dopiero wtedy rozpoczyna się ich
## usuwanie (i biegnie czas naprawy).

var sim = null
var rng := RandomNumberGenerator.new()
var freq_min := 12.0
var next_at := -1.0
var active: Array = []
var archiwum: Array = []
var _next_id := 1

const NAPRAWA := {
	"rozjazd": [240.0, 600.0],
	"semafor": [300.0, 720.0],
	"przeszkoda": [180.0, 420.0],
	"zwierzeta": [90.0, 240.0],
	"tabor": [240.0, 600.0],
}


func _init(p_sim) -> void:
	sim = p_sim
	rng.randomize()
	freq_min = Settings.event_freq_min


func by_id(ev_id: int) -> Dictionary:
	for ev in active:
		if int(ev["id"]) == ev_id:
			return ev
	return {}


func schedule_next(now: float) -> void:
	if freq_min <= 0.0:
		next_at = -1.0
		return
	next_at = now + maxf(60.0, -log(1.0 - rng.randf()) * freq_min * 60.0)


func step(now: float) -> void:
	if freq_min > 0.0 and next_at < 0.0:
		schedule_next(now)
	if freq_min > 0.0 and next_at >= 0.0 and now >= next_at:
		_trigger_random(now)
		schedule_next(now)
	var still: Array = []
	for ev in active:
		if float(ev["usun_at"]) > 0.0 and now >= float(ev["usun_at"]):
			_revert(ev)
			ev["ended"] = true
			archiwum.append(ev)
			sim.edr.add(now, "Usterka", "Usterka usunięta: %s." % str(ev["tytul"]))
			sim.comms.fault_cleared(ev)
			EventBus.random_event_ended.emit(ev)
		else:
			still.append(ev)
	active = still


func _trigger_random(now: float) -> void:
	var roll := rng.randf()
	var typ := "rozjazd"
	if roll < 0.28:
		typ = "rozjazd"
	elif roll < 0.52:
		typ = "semafor"
	elif roll < 0.72:
		typ = "przeszkoda"
	elif roll < 0.88:
		typ = "tabor"
	else:
		typ = "zwierzeta"
	force_event(now, typ, "")


## Wywołanie zdarzenia. Zwraca zdarzenie albo {} gdy brak sensownego celu.
func force_event(now: float, typ: String, cel: String) -> Dictionary:
	var inter: Interlocking = sim.inter
	var layout: StationLayout = sim.layout
	var ev := {
		"id": _next_id, "typ": typ, "cel": cel, "tytul": "", "opis": "",
		"czas": now, "zgloszona": false, "zgloszona_at": -1.0, "usun_at": -1.0,
		"ended": false, "sluzba": sim.comms.sluzba_for_event(typ),
	}
	match typ:
		"rozjazd":
			if cel == "":
				var kand: Array = []
				for wid in layout.switches:
					if not inter.sw_failed.has(wid) and not inter.sw_locked.has(wid):
						kand.append(wid)
				if kand.is_empty():
					return {}
				cel = kand[rng.randi_range(0, kand.size() - 1)]
			ev["cel"] = cel
			inter.sw_failed[cel] = true
			ev["tytul"] = "Brak kontroli położenia rozjazdu nr %s" % cel
			ev["opis"] = "Rozjazd nr %s nie wykazuje kontroli położenia. Do czasu usunięcia usterki przebiegi przez ten rozjazd są niemożliwe — prowadź ruch drogą okrężną. Zgłoś usterkę Automatykowi SRK." % cel
		"semafor":
			if cel == "":
				var kand2: Array = []
				for sid in layout.signals:
					if not inter.is_signal_failed(sid) and str(layout.signals[sid]["typ"]) != "manewrowy":
						kand2.append(sid)
				if kand2.is_empty():
					return {}
				cel = kand2[rng.randi_range(0, kand2.size() - 1)]
			ev["cel"] = cel
			inter.sig_state[cel]["failed"] = true
			inter.sig_state[cel]["aspect"] = Interlocking.ASPECT_STOP
			ev["tytul"] = "Usterka semafora %s" % cel
			ev["opis"] = "Semafor %s nie podaje sygnałów zezwalających. Po nastawieniu i utwierdzeniu przebiegu podaj sygnał zastępczy (Sz) z menu semafora. Zgłoś usterkę Automatykowi SRK." % cel
		"przeszkoda", "zwierzeta":
			if cel == "":
				var kand3: Array = []
				for sid2 in layout.segments:
					if not inter.closed_segs.has(sid2) and not inter.occupied_segs.has(sid2) \
							and not inter.locked_segs.has(sid2):
						kand3.append(sid2)
				if kand3.is_empty():
					return {}
				cel = kand3[rng.randi_range(0, kand3.size() - 1)]
			ev["cel"] = cel
			var gdzie := _seg_desc(cel)
			inter.closed_segs[cel] = "osoba postronna" if typ == "przeszkoda" else "zwierzęta w skrajni"
			if typ == "przeszkoda":
				ev["tytul"] = "Osoba postronna w torach (%s)" % gdzie
				ev["opis"] = "Zgłoszono osobę postronną w torach — %s. Odcinek zamknięty do czasu interwencji SOK." % gdzie
			else:
				ev["tytul"] = "Zwierzęta w skrajni toru (%s)" % gdzie
				ev["opis"] = "Zwierzęta w skrajni — %s. Odcinek zamknięty do czasu interwencji SOK." % gdzie
		"tabor":
			var jadace: Array = []
			for t: Train in sim.trains.values():
				if t.state == Train.State.JEDZIE or t.state == Train.State.NA_TORZE:
					jadace.append(t)
			if jadace.is_empty():
				return {}
			var tr: Train = jadace[rng.randi_range(0, jadace.size() - 1)]
			ev["cel"] = str(tr.id)
			tr.stop_reason = "awaria taboru"
			tr.stopped_until = 1e12
			ev["tytul"] = "Awaria taboru — poc. %s" % tr.nr
			ev["opis"] = "Drużyna pociągu %s zgłasza usterkę taboru i nie może kontynuować jazdy. Zgłoś zdarzenie Dyspozytorowi przewoźnika." % tr.opis()
		_:
			return {}
	_next_id += 1
	active.append(ev)
	sim.edr.add(now, "Usterka", "%s — %s" % [str(ev["tytul"]), str(ev["opis"])])
	EventBus.random_event_started.emit(ev)
	return ev


func _seg_desc(seg_id: String) -> String:
	if sim.layout.track_of_seg.has(seg_id):
		return "tor nr %s" % str(sim.layout.track_of_seg[seg_id])
	return "odcinek %s" % seg_id


## Przyjęcie zgłoszenia — uruchamia usuwanie usterki. Zwraca czas naprawy [s].
func report(ev_id: int, now: float) -> float:
	var ev := by_id(ev_id)
	if ev.is_empty() or bool(ev["zgloszona"]):
		return 0.0
	var zakres: Array = NAPRAWA.get(str(ev["typ"]), [240.0, 600.0])
	var czas := rng.randf_range(float(zakres[0]), float(zakres[1]))
	ev["zgloszona"] = true
	ev["zgloszona_at"] = now
	ev["usun_at"] = now + czas
	EventBus.random_event_reported.emit(ev)
	return czas


func _revert(ev: Dictionary) -> void:
	match str(ev["typ"]):
		"rozjazd":
			sim.inter.sw_failed.erase(str(ev["cel"]))
		"semafor":
			if sim.inter.sig_state.has(str(ev["cel"])):
				sim.inter.sig_state[str(ev["cel"])]["failed"] = false
		"przeszkoda", "zwierzeta":
			sim.inter.closed_segs.erase(str(ev["cel"]))
		"tabor":
			var t: Train = sim.trains.get(int(str(ev["cel"])))
			if t != null:
				t.stopped_until = 0.0
				t.stop_reason = ""


func unreported_count() -> int:
	var n := 0
	for ev in active:
		if not bool(ev["zgloszona"]):
			n += 1
	return n
