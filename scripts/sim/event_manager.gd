class_name RandomEventManager
extends RefCounted
## Zdarzenia losowe: usterki rozjazdów i semaforów, przeszkody na torze,
## awarie taboru. Częstotliwość regulowana suwakiem (średni odstęp w min,
## 0 = wyłączone). Zdarzenia można też wywołać ręcznie (samouczek).

var sim = null
var rng := RandomNumberGenerator.new()
var freq_min := 12.0      # średni odstęp między zdarzeniami [min]; 0 = wył.
var next_at := -1.0
var active: Array = []    # {id, type, title, desc, target, until, ack}
var history_count := 0
var _next_id := 1


func _init(p_sim) -> void:
	sim = p_sim
	rng.randomize()


func schedule_next(now: float) -> void:
	if freq_min <= 0.0:
		next_at = -1.0
		return
	var mean := freq_min * 60.0
	next_at = now + maxf(45.0, -log(1.0 - rng.randf()) * mean)


func step(now: float) -> void:
	if freq_min > 0.0 and next_at < 0.0:
		schedule_next(now)
	if freq_min > 0.0 and next_at >= 0.0 and now >= next_at:
		_trigger_random(now)
		schedule_next(now)
	var still: Array = []
	for ev in active:
		if now >= ev["until"]:
			_revert(ev)
			ev["ended"] = true
			history_count += 1
			sim.dlog.add(now, "Zdarzenie", "Ustąpiło: %s" % ev["title"])
			EventBus.random_event_ended.emit(ev)
		else:
			still.append(ev)
	active = still


func _trigger_random(now: float) -> void:
	var roll := rng.randf()
	if roll < 0.30:
		force_event(now, "rozjazd", "")
	elif roll < 0.55:
		force_event(now, "semafor", "")
	elif roll < 0.75:
		force_event(now, "przeszkoda", "")
	elif roll < 0.90:
		force_event(now, "tabor", "")
	else:
		force_event(now, "zwierzeta", "")


## Wywołanie zdarzenia (losowego lub wymuszonego przez samouczek).
## Zwraca zdarzenie lub {} gdy brak sensownego celu.
func force_event(now: float, type: String, target: String) -> Dictionary:
	var inter: Interlocking = sim.inter
	var layout: StationLayout = sim.layout
	var ev := {
		"id": _next_id, "type": type, "target": target,
		"title": "", "desc": "", "until": now, "ack": false, "ended": false,
	}
	match type:
		"rozjazd":
			if target == "":
				var candidates: Array = []
				for p in layout.switch_points:
					if not inter.failed_points.has(p) and not inter.locked_pts.has(p):
						candidates.append(p)
				if candidates.is_empty():
					return {}
				target = candidates[rng.randi_range(0, candidates.size() - 1)]
			ev["target"] = target
			inter.failed_points[target] = true
			ev["until"] = now + rng.randf_range(90.0, 240.0)
			ev["title"] = "Usterka rozjazdu %s" % target
			ev["desc"] = "Brak kontroli położenia rozjazdu %s. Przebiegi przez ten rozjazd są niemożliwe do czasu usunięcia usterki. Prowadź ruch drogami okrężnymi." % target
		"semafor":
			if target == "":
				var cands: Array = []
				for sid in layout.signals:
					var sig: Dictionary = layout.signals[sid]
					if not sig["failed"] and not sig["shunt_only"]:
						cands.append(sid)
				if cands.is_empty():
					return {}
				target = cands[rng.randi_range(0, cands.size() - 1)]
			ev["target"] = target
			layout.signals[target]["failed"] = true
			ev["until"] = now + rng.randf_range(120.0, 300.0)
			ev["title"] = "Usterka semafora %s" % target
			ev["desc"] = "Semafor %s nie wyświetla sygnałów zezwalających. Po ustawieniu przebiegu użyj sygnału zastępczego (Sz)." % target
		"przeszkoda", "zwierzeta":
			if target == "":
				var segs: Array = []
				for sid2 in layout.segments:
					if not inter.closed_segs.has(sid2) and not inter.occupied_segs.has(sid2) and not inter.locked_segs.has(sid2):
						segs.append(sid2)
				if segs.is_empty():
					return {}
				target = segs[rng.randi_range(0, segs.size() - 1)]
			ev["target"] = target
			var reason := "osoba postronna" if type == "przeszkoda" else "zwierzęta"
			inter.closed_segs[target] = reason
			ev["until"] = now + (rng.randf_range(60.0, 180.0) if type == "przeszkoda" else rng.randf_range(40.0, 90.0))
			if type == "przeszkoda":
				ev["title"] = "Osoba postronna na torach (odc. %s)" % target
				ev["desc"] = "Zgłoszono osobę postronną w torach — odcinek %s zamknięty do czasu interwencji SOK." % target
			else:
				ev["title"] = "Zwierzęta na torach (odc. %s)" % target
				ev["desc"] = "Zwierzęta w skrajni toru — odcinek %s chwilowo zamknięty." % target
		"tabor":
			var moving: Array = []
			for t in sim.trains.values():
				if t.state == Train.State.MOVING:
					moving.append(t)
			if moving.is_empty():
				return {}
			var tr: Train = moving[rng.randi_range(0, moving.size() - 1)]
			ev["target"] = str(tr.id)
			var dur := rng.randf_range(60.0, 200.0)
			tr.stopped_until = now + dur
			tr.stop_reason = "awaria taboru"
			ev["until"] = now + dur
			ev["title"] = "Awaria taboru — poc. %s" % tr.nr
			ev["desc"] = "Pociąg %s zgłasza usterkę taboru i zatrzymał się na szlaku/stacji. Oczekuj na usunięcie usterki." % tr.title()
		_:
			return {}
	_next_id += 1
	active.append(ev)
	sim.dlog.add(now, "Zdarzenie", "%s — %s" % [ev["title"], ev["desc"]])
	EventBus.random_event_started.emit(ev)
	return ev


func _revert(ev: Dictionary) -> void:
	match ev["type"]:
		"rozjazd":
			sim.inter.failed_points.erase(ev["target"])
		"semafor":
			if sim.layout.signals.has(ev["target"]):
				sim.layout.signals[ev["target"]]["failed"] = false
		"przeszkoda", "zwierzeta":
			sim.inter.closed_segs.erase(ev["target"])
		"tabor":
			pass


func ack(ev_id: int) -> void:
	for ev in active:
		if ev["id"] == ev_id and not ev["ack"]:
			ev["ack"] = true
			sim.dlog.add(sim.sim_time, "Zdarzenie", "Przyjęto do wiadomości: %s" % ev["title"])
			EventBus.random_event_acked.emit(ev)
			return
