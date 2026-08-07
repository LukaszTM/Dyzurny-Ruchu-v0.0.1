class_name Comms
extends RefCounted
## Łączność zapowiadawcza i służbowa.
##
## Odwzorowanie telefonicznego zapowiadania pociągów wg zasad ruchu na PKP:
##   1. żądanie pozwolenia   — „Czy droga wolna dla pociągu nr …?”
##   2. danie pozwolenia     — „Droga wolna dla pociągu nr …”
##   3. oznajmienie odjazdu  — „Pociąg nr … odjechał o godzinie …”
##   4. potwierdzenie przyjazdu — „Pociąg nr … przybył o godzinie … w całości”
##
## Dodatkowo obsługuje zgłoszenia usterek do służb utrzymania — dopiero po
## zgłoszeniu rozpoczyna się usuwanie usterki.

const SLUZBY := [
	{"id": "AUT", "name": "Automatyk SRK", "opis": "usterki urządzeń srk (rozjazdy, semafory)"},
	{"id": "SOK", "name": "Straż Ochrony Kolei", "opis": "osoby postronne, przeszkody, zwierzęta"},
	{"id": "DYSP", "name": "Dyspozytor przewoźnika", "opis": "awarie taboru, drużyny pociągowe"},
	{"id": "DYSL", "name": "Dyspozytor liniowy", "opis": "informacje o zakłóceniach w ruchu"},
]

var sim = null
var rng := RandomNumberGenerator.new()
var posterunki: Array = []      # {id, name, ends: [line_end_id], kind}
var calls: Array = []           # oczekujące rozmowy przychodzące
var history: Array = []         # {t, kier, kto, tresc}
var perm := {}                  # train_id -> {status, kto, at}
var pending_out: Array = []     # nasze żądania oczekujące na odpowiedź
var _next_call := 1
var stats := {"zapowiedzi": 0, "spoznione_potwierdzenia": 0, "odmowy": 0}


func _init(p_sim) -> void:
	sim = p_sim
	rng.randomize()


func setup() -> void:
	posterunki.clear()
	var seen := {}
	for lid in sim.layout.line_end_order:
		var le: Dictionary = sim.layout.line_ends[lid]
		var nm := str(le["name"])
		if not seen.has(nm):
			seen[nm] = {
				"id": "P%d" % (posterunki.size() + 1), "name": nm, "ends": [],
				"kind": "techniczny" if str(le["kind"]) == "manewrowy" else "zapowiadawczy",
			}
			posterunki.append(seen[nm])
		seen[nm]["ends"].append(lid)


func posterunek_for_end(line_end_id: String) -> Dictionary:
	for p in posterunki:
		if line_end_id in p["ends"]:
			return p
	return {}


func _log(kier: String, kto: String, tresc: String) -> void:
	history.append({"t": sim.sim_time, "kier": kier, "kto": kto, "tresc": tresc})
	if history.size() > 400:
		history = history.slice(history.size() - 400, history.size())
	EventBus.comms_changed.emit()


func _add_call(kto: String, typ: String, tresc: String, data: Dictionary) -> Dictionary:
	var c := {
		"id": _next_call, "kto": kto, "typ": typ, "tresc": tresc,
		"data": data, "at": sim.sim_time, "obsluzona": false,
	}
	_next_call += 1
	calls.append(c)
	_log("<-", kto, tresc)
	EventBus.comms_call_added.emit(c)
	return c


func pending_calls() -> Array:
	var res: Array = []
	for c in calls:
		if not c["obsluzona"]:
			res.append(c)
	return res


# --------------------------------------------------------- ruch wjazdowy ---

## Sąsiedni posterunek żąda pozwolenia na wyprawienie pociągu do nas.
func incoming_permission_request(spec: Dictionary) -> void:
	var post := posterunek_for_end(str(spec["we"]))
	var kto := str(post.get("name", spec["we"]))
	if str(post.get("kind", "")) == "techniczny":
		_add_call(kto, "podstawienie",
			"Manewrowy %s: skład %s gotowy do podstawienia na tor %s." % [
				kto, str(spec["nr"]), str(spec.get("tor", "?"))], spec)
		return
	if not Settings.require_zapowiadanie:
		sim.admit_train(spec)
		return
	_add_call(kto, "zadanie_pozwolenia",
		"%s: Czy droga wolna dla pociągu nr %s %s?" % [kto, str(spec["kat"]), str(spec["nr"])], spec)


## Odpowiedź dyżurnego na rozmowę przychodzącą.
func answer_call(call_id: int, zgoda: bool, uwaga := "") -> void:
	for c in calls:
		if int(c["id"]) != call_id or c["obsluzona"]:
			continue
		c["obsluzona"] = true
		var spec: Dictionary = c["data"]
		match str(c["typ"]):
			"zadanie_pozwolenia", "podstawienie":
				if zgoda:
					var tresc := "Droga wolna dla pociągu nr %s." % str(spec.get("nr", ""))
					if str(c["typ"]) == "podstawienie":
						tresc = "Zgoda na podstawienie składu %s." % str(spec.get("nr", ""))
					_log("->", str(c["kto"]), tresc)
					sim.edr.add(sim.sim_time, "Zapowiedź",
						"Dano pozwolenie: %s — %s." % [str(c["kto"]), tresc], str(spec.get("nr", "")))
					stats["zapowiedzi"] += 1
					sim.admit_train(spec)
				else:
					_log("->", str(c["kto"]), "Nie mogę przyjąć pociągu nr %s — %s" % [
						str(spec.get("nr", "")), uwaga if uwaga != "" else "brak wolnego toru"])
					sim.edr.add(sim.sim_time, "Zapowiedź",
						"Odmówiono pozwolenia na przyjęcie poc. %s (%s)." % [
							str(spec.get("nr", "")), uwaga if uwaga != "" else "brak wolnego toru"],
						str(spec.get("nr", "")))
					stats["odmowy"] += 1
					sim.defer_train(spec)
			"oznajmienie_odjazdu":
				_log("->", str(c["kto"]), "Przyjąłem.")
			"monit_przyjazd":
				pass
			_:
				_log("->", str(c["kto"]), "Przyjąłem.")
		EventBus.comms_call_handled.emit(c)
		return


## Sąsiad oznajmia odjazd pociągu w naszym kierunku.
func incoming_departure(spec: Dictionary) -> void:
	var post := posterunek_for_end(str(spec["we"]))
	var kto := str(post.get("name", spec["we"]))
	_add_call(kto, "oznajmienie_odjazdu",
		"%s: Pociąg nr %s odjechał o godzinie %s." % [
			kto, str(spec["nr"]), SimUtil.fmt_hm(sim.sim_time)], spec)


# --------------------------------------------------------- ruch wyjazdowy --

func permission_status(train_id: int) -> String:
	return str(perm.get(train_id, {}).get("status", ""))


## Żądanie pozwolenia na wyprawienie pociągu (nasza rozmowa wychodząca).
func ask_permission(train: Train) -> String:
	if train.wyjazd == "":
		return "Pociąg %s nie ma wyznaczonego kierunku wyjazdu." % train.nr
	var post := posterunek_for_end(train.wyjazd)
	if str(post.get("kind", "")) == "techniczny":
		perm[train.id] = {"status": "udzielone", "kto": str(post.get("name", "")), "at": sim.sim_time}
		_log("->", str(post.get("name", "")), "Zgłaszam odstawienie składu %s." % train.nr)
		EventBus.comms_changed.emit()
		return ""
	var st := permission_status(train.id)
	if st == "oczekuje":
		return "Żądanie pozwolenia dla poc. %s zostało już zgłoszone." % train.nr
	if st == "udzielone":
		return "Pozwolenie dla poc. %s zostało już udzielone." % train.nr
	var kto := str(post.get("name", train.wyjazd))
	_log("->", kto, "Czy droga wolna dla pociągu nr %s %s?" % [train.rodzaj, train.nr])
	perm[train.id] = {"status": "oczekuje", "kto": kto, "at": sim.sim_time}
	pending_out.append({
		"train_id": train.id, "kto": kto,
		"answer_at": sim.sim_time + rng.randf_range(8.0, 25.0),
		"line_end": train.wyjazd,
	})
	sim.edr.add(sim.sim_time, "Zapowiedź",
		"Zażądano pozwolenia u %s dla poc. %s." % [kto, train.opis()], train.nr, train.tor)
	EventBus.comms_changed.emit()
	return ""


## Oznajmienie odjazdu pociągu sąsiadowi.
func announce_departure(train: Train) -> String:
	var post := posterunek_for_end(train.wyjazd)
	var kto := str(post.get("name", train.wyjazd))
	var p: Dictionary = perm.get(train.id, {})
	if str(p.get("status", "")) != "udzielone":
		return "Brak pozwolenia — najpierw zażądaj pozwolenia u %s." % kto
	if bool(p.get("oznajmiony", false)):
		return "Odjazd poc. %s został już oznajmiony." % train.nr
	p["oznajmiony"] = true
	_log("->", kto, "Pociąg nr %s odjechał o godzinie %s." % [train.nr, SimUtil.fmt_hm(train.actual_dep)])
	sim.edr.add(sim.sim_time, "Zapowiedź",
		"Oznajmiono odjazd poc. %s do %s o godz. %s." % [train.opis(), kto, SimUtil.fmt_hm(train.actual_dep)],
		train.nr, train.tor)
	stats["zapowiedzi"] += 1
	EventBus.comms_changed.emit()
	return ""


## Potwierdzenie przyjazdu pociągu posterunkowi, który go wyprawił.
func confirm_arrival(train: Train) -> String:
	var post := posterunek_for_end(train.wjazd)
	var kto := str(post.get("name", train.wjazd))
	if not perm.has(train.id):
		perm[train.id] = {}
	var p: Dictionary = perm[train.id]
	if bool(p.get("przyjazd_potwierdzony", false)):
		return "Przyjazd poc. %s został już potwierdzony." % train.nr
	p["przyjazd_potwierdzony"] = true
	_log("->", kto, "Pociąg nr %s przybył o godzinie %s w całości." % [
		train.nr, SimUtil.fmt_hm(train.actual_arr)])
	sim.edr.add(sim.sim_time, "Zapowiedź",
		"Potwierdzono przyjazd poc. %s do %s o godz. %s (w całości)." % [
			train.opis(), kto, SimUtil.fmt_hm(train.actual_arr)], train.nr, train.tor)
	stats["zapowiedzi"] += 1
	EventBus.comms_changed.emit()
	return ""


func needs_arrival_confirmation() -> Array:
	var res: Array = []
	for t: Train in sim.trains.values():
		if t.manewrowy or t.actual_arr < 0.0:
			continue
		var p: Dictionary = perm.get(t.id, {})
		if not bool(p.get("przyjazd_potwierdzony", false)):
			res.append(t)
	return res


# ------------------------------------------------------- zgłaszanie usterek -

func sluzba_for_event(typ: String) -> String:
	match typ:
		"rozjazd", "semafor":
			return "AUT"
		"przeszkoda", "zwierzeta":
			return "SOK"
		"tabor":
			return "DYSP"
	return "DYSL"


func sluzba_name(sid: String) -> String:
	for s in SLUZBY:
		if str(s["id"]) == sid:
			return str(s["name"])
	return sid


## Zgłoszenie usterki właściwej służbie — uruchamia jej usuwanie.
func report_fault(ev_id: int, sluzba_id: String) -> String:
	var ev: Dictionary = sim.events.by_id(ev_id)
	if ev.is_empty():
		return "Nie ma takiego zdarzenia."
	if bool(ev["zgloszona"]):
		return "Zdarzenie „%s” zostało już zgłoszone." % str(ev["tytul"])
	var wlasciwa := sluzba_for_event(str(ev["typ"]))
	var kto := sluzba_name(sluzba_id)
	if sluzba_id != wlasciwa:
		_log("->", kto, "Zgłaszam: %s" % str(ev["tytul"]))
		_log("<-", kto, "To nie nasza właściwość — proszę zgłosić do: %s." % sluzba_name(wlasciwa))
		return "Niewłaściwa służba — zgłoś do: %s." % sluzba_name(wlasciwa)
	_log("->", kto, "Zgłaszam: %s" % str(ev["tytul"]))
	var czas: float = sim.events.report(ev_id, sim.sim_time)
	_log("<-", kto, "Zgłoszenie przyjęte. Przewidywany czas usunięcia: ok. %d min." % int(czas / 60.0))
	sim.edr.add(sim.sim_time, "Usterka",
		"Zgłoszono do %s: %s. Przewidywany czas usunięcia ok. %d min." % [kto, str(ev["tytul"]), int(czas / 60.0)])
	EventBus.comms_changed.emit()
	return ""


func fault_cleared(ev: Dictionary) -> void:
	var kto := sluzba_name(sluzba_for_event(str(ev["typ"])))
	_log("<-", kto, "Usterka usunięta: %s. Urządzenia sprawne." % str(ev["tytul"]))


# -------------------------------------------------------------------- krok --

func step(now: float) -> void:
	var still: Array = []
	for req in pending_out:
		if now < float(req["answer_at"]):
			still.append(req)
			continue
		var t: Train = sim.trains.get(int(req["train_id"]))
		if t == null:
			continue
		var zajety := _line_busy(str(req["line_end"]), t.id)
		if zajety and rng.randf() < 0.8:
			perm[t.id] = {"status": "odmowa", "kto": req["kto"], "at": now}
			_log("<-", str(req["kto"]), "Nie mogę przyjąć pociągu nr %s — szlak zajęty. Zgłoś ponownie." % t.nr)
			sim.edr.add(now, "Zapowiedź", "Odmowa pozwolenia dla poc. %s (szlak zajęty)." % t.opis(), t.nr)
			stats["odmowy"] += 1
		else:
			perm[t.id] = {"status": "udzielone", "kto": req["kto"], "at": now}
			_log("<-", str(req["kto"]), "Droga wolna dla pociągu nr %s." % t.nr)
			sim.edr.add(now, "Zapowiedź", "Otrzymano pozwolenie od %s dla poc. %s." % [str(req["kto"]), t.opis()], t.nr)
			stats["zapowiedzi"] += 1
		EventBus.comms_changed.emit()
	pending_out = still
	# monity o niepotwierdzone przyjazdy
	for t in needs_arrival_confirmation():
		if not perm.has(t.id):
			perm[t.id] = {}
		if now - t.actual_arr > 420.0 and not bool(perm[t.id].get("monit", false)):
			perm[t.id]["monit"] = true
			stats["spoznione_potwierdzenia"] += 1
			var post := posterunek_for_end(t.wjazd)
			_add_call(str(post.get("name", t.wjazd)), "monit_przyjazd",
				"%s: Proszę o potwierdzenie przyjazdu pociągu nr %s." % [str(post.get("name", "")), t.nr],
				{"train_id": t.id})


func _line_busy(line_end_id: String, skip_train: int) -> bool:
	for t: Train in sim.trains.values():
		if t.id == skip_train:
			continue
		if t.wyjazd == line_end_id and str(permission_status(t.id)) == "udzielone" and t.actual_dep < 0.0:
			return true
	return false
