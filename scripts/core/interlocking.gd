class_name Interlocking
extends RefCounted
## Urządzenia srk (komputerowa nastawnica) — odwzorowanie obsługi
## stosowanej na PKP.
##
## Nastawianie przebiegu jest DWUPRZYCISKOWE: dyżurny wybiera rodzaj
## polecenia (przebieg pociągowy / manewrowy), naciska przycisk POCZĄTKU
## drogi przebiegu (sygnalizator), a następnie przycisk KOŃCA (sygnalizator
## na końcu toru albo przycisk szlaku). Urządzenia same wybierają drogę
## przebiegu, przestawiają rozjazdy, utwierdzają przebieg i dopiero wtedy
## podają sygnał zezwalający.
##
## Polecenia pulpitu:
##   PP  — przebieg pociągowy      PM  — przebieg manewrowy
##   ZD  — zwolnienie drogi przebiegu pociągowego
##   ZDM — zwolnienie drogi przebiegu manewrowego
##   ZW  — indywidualne przestawienie rozjazdu (+ / −)
##   ZWP — zwolnienie awaryjne przebiegu (z kontrolą czasu 180 s)
##   OPS — opis (podgląd stanu) elementu
## Polecenia sygnalizatora (menu):
##   STOP / OSTOP — nakaz i odwołanie sygnału „Stój"
##   SZ / SZP     — sygnał zastępczy jednorazowy / powtarzalny
##   NSZ / NSZP   — skasowanie sygnału zastępczego
##   WTAB / KTAB  — założenie i skasowanie tabliczki ostrzegawczej

signal message(text: String, level: int)

enum { ASPECT_STOP, ASPECT_JAZDA, ASPECT_MANEWR, ASPECT_SZ }

const ST_NASTAWIANIE := "NASTAWIANIE"
const ST_UTWIERDZONY := "UTWIERDZONY"

const SW_MOVE_TIME := 3.0          # czas przestawiania rozjazdu [s]
const EMERGENCY_DELAY := 180.0     # kontrola czasu przy zwolnieniu awaryjnym [s]

var layout: StationLayout
var sim_time := 0.0

var sw_pos := {}          # nr rozjazdu -> "+" / "-"
var sw_moving := {}       # nr rozjazdu -> czas zakończenia przestawiania
var sw_failed := {}       # nr rozjazdu -> true (brak kontroli położenia)
var sw_locked := {}       # nr rozjazdu -> id przebiegu
var sig_state := {}       # id -> {aspect, failed, sz, stop_cmd}
var tab := {}             # id elementu -> opis tabliczki
var closed_segs := {}     # seg -> powód zamknięcia toru
var locked_segs := {}     # seg -> id przebiegu
var locked_pts := {}      # punkt -> id przebiegu
var occupied_segs := {}   # seg -> id pociągu
var routes := {}          # id -> Dictionary
var _next_id := 1


func _init(p_layout: StationLayout) -> void:
	layout = p_layout
	for wid in layout.switches:
		sw_pos[wid] = "+"
	for sid in layout.signals:
		sig_state[sid] = {"aspect": ASPECT_STOP, "failed": false, "sz": "", "stop_cmd": false}


func _msg(text: String, level := 0) -> void:
	message.emit(text, level)


# ----------------------------------------------------------------- odczyt --

func aspect(sig_id: String) -> int:
	return int(sig_state.get(sig_id, {}).get("aspect", ASPECT_STOP))


func is_signal_failed(sig_id: String) -> bool:
	return bool(sig_state.get(sig_id, {}).get("failed", false))


func route_of_signal(sig_id: String) -> Dictionary:
	for r in routes.values():
		if r["signal_id"] == sig_id:
			return r
	return {}


func route_by_id(rid: int) -> Dictionary:
	return routes.get(rid, {})


func seg_route(seg_id: String) -> Dictionary:
	var rid: int = int(locked_segs.get(seg_id, -1))
	return routes.get(rid, {})


func element_description(kind: String, id: String) -> String:
	match kind:
		"signal":
			var sg: Dictionary = layout.signals.get(id, {})
			var st: Dictionary = sig_state.get(id, {})
			var opis := "Sygnalizator %s (%s) — %s\n" % [id, sg.get("typ", "?"), sg.get("opis", "")]
			opis += "Wskazanie: %s" % aspect_name(int(st.get("aspect", 0)))
			if st.get("failed", false):
				opis += "  ⚠ USTERKA (brak kontroli sygnału)"
			if str(st.get("sz", "")) != "":
				opis += "  [%s]" % str(st.get("sz", ""))
			if st.get("stop_cmd", false):
				opis += "  [nakaz STOP]"
			if tab.has(id):
				opis += "\nTabliczka: %s" % tab[id]
			var r := route_of_signal(id)
			if not r.is_empty():
				opis += "\nPrzebieg %s %s → %s (%s)" % [
					"pociągowy" if r["kind"] == "P" else "manewrowy",
					id, r["dest_id"], r["state"]]
			return opis
		"switch":
			var w: Dictionary = layout.switches.get(id, {})
			var opis2 := "Rozjazd nr %s — położenie %s" % [id, str(sw_pos.get(id, "?"))]
			if sw_moving.has(id):
				opis2 += " (przestawianie…)"
			if sw_failed.has(id):
				opis2 += "  ⚠ BRAK KONTROLI POŁOŻENIA"
			if sw_locked.has(id):
				opis2 += "  [zamknięty w przebiegu nr %d]" % int(sw_locked[id])
			if tab.has(id):
				opis2 += "\nTabliczka: %s" % tab[id]
			opis2 += "\nIglice: %s, plus: %s, minus: %s" % [w.get("root", ""), w.get("plus", ""), w.get("minus", "")]
			return opis2
		"line_end":
			var le: Dictionary = layout.line_ends.get(id, {})
			return "Szlak %s — %s, tor %s (%s)" % [id, le.get("name", ""), le.get("tor", ""), le.get("lk", "")]
		"track":
			var tr: Dictionary = layout.tracks.get(id, {})
			var opis3 := "Tor stacyjny nr %s" % id
			if str(tr.get("peron", "")) != "":
				opis3 += " przy %s" % str(tr.get("peron"))
			if closed_segs.has(str(tr.get("seg", ""))):
				opis3 += "\n⚠ ZAMKNIĘCIE TORU: %s" % closed_segs[str(tr.get("seg"))]
			return opis3
	return ""


static func aspect_name(a: int) -> String:
	match a:
		ASPECT_JAZDA:
			return "sygnał zezwalający (S2)"
		ASPECT_MANEWR:
			return "sygnał manewrowy (Ms2)"
		ASPECT_SZ:
			return "sygnał zastępczy (Sz)"
		_:
			return "Stój (S1)"


# ------------------------------------------------------- wyznaczanie drogi --

## Znajduje drogę przebiegu od punktu startowego do docelowego.
## Zwraca {pts, segs, sw} albo {error}.
func find_path(start_pt: String, dest_pt: String, dir: int, ignore_blocks := false) -> Dictionary:
	var adj: Dictionary = layout.adj_e if dir > 0 else layout.adj_w
	var start_key := "%s|" % start_pt
	var prev := {}
	var visited := {start_key: true}
	var queue: Array = [{"pt": start_pt, "in": ""}]
	var found_key := ""
	while not queue.is_empty():
		var cur: Dictionary = queue.pop_front()
		var pt: String = cur["pt"]
		var in_seg: String = cur["in"]
		if pt == dest_pt and in_seg != "":
			found_key = "%s|%s" % [pt, in_seg]
			break
		for edge in adj.get(pt, []):
			var seg: String = edge["seg"]
			var np: String = edge["to"]
			if layout.transition_error(pt, in_seg, seg) != "":
				continue
			if not ignore_blocks:
				if locked_segs.has(seg) or occupied_segs.has(seg) or closed_segs.has(seg):
					continue
				if tab.has(seg):
					continue
				var wid: String = str(layout.switch_at_point.get(pt, ""))
				if wid != "" and (sw_failed.has(wid) or sw_locked.has(wid) or tab.has(wid)):
					continue
				var wid2: String = str(layout.switch_at_point.get(np, ""))
				if wid2 != "" and (sw_failed.has(wid2) or sw_locked.has(wid2) or tab.has(wid2)):
					continue
				if locked_pts.has(np):
					continue
			var key := "%s|%s" % [np, seg]
			if visited.has(key):
				continue
			visited[key] = true
			prev[key] = {"pt": pt, "in": in_seg, "seg": seg}
			queue.append({"pt": np, "in": seg})
	if found_key == "":
		return {"error": "brak drogi przebiegu"}
	var pts: Array = [dest_pt]
	var segs: Array = []
	var key2 := found_key
	while prev.has(key2):
		var e: Dictionary = prev[key2]
		segs.push_front(e["seg"])
		pts.push_front(e["pt"])
		key2 = "%s|%s" % [e["pt"], e["in"]]
	# położenia rozjazdów na drodze przebiegu
	var sw_need := {}
	for i in range(pts.size()):
		var wid3: String = str(layout.switch_at_point.get(pts[i], ""))
		if wid3 == "":
			continue
		var in_s: String = segs[i - 1] if i > 0 else ""
		var out_s: String = segs[i] if i < segs.size() else ""
		if in_s == "" or out_s == "":
			continue
		sw_need[wid3] = layout.required_position(wid3, in_s, out_s)
	return {"pts": pts, "segs": segs, "sw": sw_need}


# ------------------------------------------------------ nastawianie drogi --

## Nastawienie przebiegu. kind: "P" (pociągowy) albo "M" (manewrowy).
## dest_kind: "signal" albo "line_end".
func set_route(sig_id: String, dest_id: String, dest_kind: String, kind: String) -> Dictionary:
	if not layout.signals.has(sig_id):
		return {"error": "Nieznany sygnalizator %s." % sig_id}
	var sg: Dictionary = layout.signals[sig_id]
	var st: Dictionary = sig_state[sig_id]
	if sg["typ"] == "manewrowy":
		kind = "M"
	if kind == "P" and sg["typ"] == "manewrowy":
		return {"error": "Na tarczy manewrowej %s nie nastawia się przebiegów pociągowych." % sig_id}
	if tab.has(sig_id):
		return {"error": "Sygnalizator %s ma założoną tabliczkę: %s." % [sig_id, tab[sig_id]]}
	if st["stop_cmd"]:
		return {"error": "Na sygnalizatorze %s obowiązuje nakaz STOP — odwołaj go poleceniem OSTOP." % sig_id}
	if not route_of_signal(sig_id).is_empty():
		return {"error": "Spod sygnalizatora %s jest już nastawiony przebieg." % sig_id}
	var start_pt: String = sg["point"]
	var dest_pt := dest_id
	if dest_kind == "signal":
		if not layout.signals.has(dest_id):
			return {"error": "Nieznany sygnalizator końcowy."}
		var dsg: Dictionary = layout.signals[dest_id]
		if int(dsg["dir"]) != int(sg["dir"]):
			return {"error": "Sygnalizator %s jest zwrócony w przeciwną stronę — nie może kończyć tego przebiegu." % dest_id}
		dest_pt = dsg["point"]
	elif dest_kind == "line_end":
		if not layout.line_ends.has(dest_id):
			return {"error": "Nieznany przycisk szlaku."}
		var le: Dictionary = layout.line_ends[dest_id]
		if int(le["dir_in"]) == int(sg["dir"]):
			return {"error": "Szlak %s leży po stronie wjazdu — nie może kończyć tego przebiegu." % dest_id}
		if kind == "P" and str(le["kind"]) == "manewrowy":
			return {"error": "Na %s wyprawia się wyłącznie jazdy manewrowe." % str(le["name"])}
	else:
		return {"error": "Nieprawidłowy koniec drogi przebiegu."}
	if dest_pt == start_pt:
		return {"error": "Koniec przebiegu pokrywa się z jego początkiem."}
	if locked_pts.has(start_pt):
		return {"error": "Początek drogi przebiegu jest zajęty innym przebiegiem."}

	var path := find_path(start_pt, dest_pt, int(sg["dir"]))
	if path.has("error"):
		var alt := find_path(start_pt, dest_pt, int(sg["dir"]), true)
		if alt.has("error"):
			return {"error": "Brak drogi przebiegu %s → %s (układ torowy nie pozwala na taką jazdę)." % [sig_id, dest_id]}
		return {"error": "Droga przebiegu %s → %s niewolna: zajętość toru, przebieg wrogi, zamknięcie toru lub usterka rozjazdu." % [sig_id, dest_id]}

	var rid := _next_id
	_next_id += 1
	var route := {
		"id": rid,
		"signal_id": sig_id,
		"dest_id": dest_id,
		"dest_kind": dest_kind,
		"start_pt": start_pt,
		"dest_pt": dest_pt,
		"dir": int(sg["dir"]),
		"kind": kind,
		"pts": path["pts"],
		"segs": path["segs"],
		"sw": path["sw"],
		"state": ST_NASTAWIANIE,
		"ready_at": sim_time + SW_MOVE_TIME,
		"train_id": 0,
		"passed": false,
		"sz": false,
		"emergency_at": -1.0,
	}
	for s in route["segs"]:
		locked_segs[s] = rid
	for p in route["pts"]:
		locked_pts[p] = rid
	for wid in route["sw"]:
		sw_locked[wid] = rid
		if str(sw_pos.get(wid, "+")) != str(route["sw"][wid]):
			sw_moving[wid] = sim_time + SW_MOVE_TIME
			route["ready_at"] = maxf(route["ready_at"], sim_time + SW_MOVE_TIME)
	routes[rid] = route
	return route


func step(p_time: float) -> void:
	sim_time = p_time
	for wid in sw_moving.keys():
		if sim_time >= float(sw_moving[wid]):
			sw_moving.erase(wid)
			var rid: int = int(sw_locked.get(wid, -1))
			var r: Dictionary = routes.get(rid, {})
			if not r.is_empty():
				sw_pos[wid] = str(r["sw"].get(wid, sw_pos.get(wid, "+")))
			EventBus.switch_moved.emit(wid, str(sw_pos.get(wid, "+")))
	for r in routes.values():
		if r["state"] == ST_NASTAWIANIE and sim_time >= float(r["ready_at"]):
			_lock_route(r)
		if float(r["emergency_at"]) > 0.0 and sim_time >= float(r["emergency_at"]):
			_msg("Zwolnienie awaryjne przebiegu spod %s — upłynęła kontrola czasu." % r["signal_id"], 1)
			finish_route(r)


func _lock_route(route: Dictionary) -> void:
	route["state"] = ST_UTWIERDZONY
	var sig_id: String = route["signal_id"]
	var st: Dictionary = sig_state[sig_id]
	if st["failed"]:
		_msg("Przebieg spod %s utwierdzony, ale semafor jest uszkodzony — wymagany sygnał zastępczy (Sz)." % sig_id, 1)
	elif str(st["sz"]) == "SZP":
		st["aspect"] = ASPECT_SZ
		route["sz"] = true
	else:
		st["aspect"] = ASPECT_MANEWR if route["kind"] == "M" else ASPECT_JAZDA
	EventBus.route_locked.emit(route)


## Czy przebieg jest otwarty dla jazdy (sygnalizator podaje sygnał zezwalający).
func route_open(route: Dictionary) -> bool:
	if route.is_empty() or route["state"] != ST_UTWIERDZONY:
		return false
	return aspect(route["signal_id"]) != ASPECT_STOP


func drop_signal(route: Dictionary) -> void:
	if route.get("passed", false):
		return
	route["passed"] = true
	var st: Dictionary = sig_state[route["signal_id"]]
	st["aspect"] = ASPECT_STOP
	if str(st["sz"]) == "SZ":
		st["sz"] = ""


## Sekcyjne zwalnianie odcinka za pociągiem.
func release_seg(seg_id: String, route: Dictionary) -> void:
	if int(locked_segs.get(seg_id, -1)) != int(route["id"]):
		return
	locked_segs.erase(seg_id)
	var sdef: Dictionary = layout.segments[seg_id]
	var rear: String = sdef["from"] if route["dir"] > 0 else sdef["to"]
	if int(locked_pts.get(rear, -1)) == int(route["id"]):
		locked_pts.erase(rear)
	var wid: String = str(layout.switch_at_point.get(rear, ""))
	if wid != "" and int(sw_locked.get(wid, -1)) == int(route["id"]):
		sw_locked.erase(wid)


func finish_route(route: Dictionary) -> void:
	var rid: int = int(route["id"])
	for s in route["segs"]:
		if int(locked_segs.get(s, -1)) == rid:
			locked_segs.erase(s)
	for p in route["pts"]:
		if int(locked_pts.get(p, -1)) == rid:
			locked_pts.erase(p)
	for wid in route["sw"]:
		if int(sw_locked.get(wid, -1)) == rid:
			sw_locked.erase(wid)
	if not route.get("passed", false):
		var st: Dictionary = sig_state[route["signal_id"]]
		st["aspect"] = ASPECT_STOP
		if str(st["sz"]) == "SZ":
			st["sz"] = ""
	routes.erase(rid)
	EventBus.route_released.emit(route, "normalne")


# ------------------------------------------------------------- polecenia ---

## ZD / ZDM — zwolnienie drogi przebiegu. Zwraca "" albo opis błędu.
func cmd_release(sig_id: String, kind: String) -> String:
	var r := route_of_signal(sig_id)
	if r.is_empty():
		return "Spod sygnalizatora %s nie ma nastawionego przebiegu." % sig_id
	if r["kind"] != kind:
		var want := "pociągowy" if r["kind"] == "P" else "manewrowy"
		return "Przebieg spod %s jest %s — użyj polecenia %s." % [sig_id, want, "ZD" if r["kind"] == "P" else "ZDM"]
	for s in r["segs"]:
		if occupied_segs.has(s):
			return "Nie można zwolnić — w drodze przebiegu znajduje się tabor. Użyj zwolnienia awaryjnego (ZWP)."
	if r.get("passed", false):
		return "Pociąg minął sygnalizator %s — wymagane zwolnienie awaryjne (ZWP)." % sig_id
	finish_route(r)
	return ""


## ZWP — zwolnienie awaryjne przebiegu z kontrolą czasu.
func cmd_emergency_release(sig_id: String) -> String:
	var r := route_of_signal(sig_id)
	if r.is_empty():
		return "Spod sygnalizatora %s nie ma nastawionego przebiegu." % sig_id
	if float(r["emergency_at"]) > 0.0:
		var left := int(float(r["emergency_at"]) - sim_time)
		return "Zwolnienie awaryjne już trwa — pozostało %d s." % maxi(left, 0)
	drop_signal(r)
	r["emergency_at"] = sim_time + EMERGENCY_DELAY
	return ""


## ZW — indywidualne przestawienie rozjazdu.
func cmd_switch(wid: String) -> String:
	if not layout.switches.has(wid):
		return "Nieznany rozjazd."
	if tab.has(wid):
		return "Rozjazd nr %s ma założoną tabliczkę: %s." % [wid, tab[wid]]
	if sw_failed.has(wid):
		return "Rozjazd nr %s — brak kontroli położenia (usterka)." % wid
	if sw_locked.has(wid):
		return "Rozjazd nr %s jest zamknięty w przebiegu." % wid
	if sw_moving.has(wid):
		return "Rozjazd nr %s jest w trakcie przestawiania." % wid
	var w: Dictionary = layout.switches[wid]
	for s in [w["root"], w["plus"], w["minus"]]:
		if occupied_segs.has(s):
			return "Rozjazd nr %s zajęty taborem." % wid
	var target := "-" if str(sw_pos.get(wid, "+")) == "+" else "+"
	sw_moving[wid] = sim_time + SW_MOVE_TIME
	sw_pos[wid] = target
	EventBus.switch_moved.emit(wid, target)
	return ""


## Polecenia menu sygnalizatora. Zwraca "" albo opis błędu.
func cmd_signal(sig_id: String, cmd: String) -> String:
	if not layout.signals.has(sig_id):
		return "Nieznany sygnalizator."
	var st: Dictionary = sig_state[sig_id]
	var r := route_of_signal(sig_id)
	match cmd:
		"STOP":
			st["stop_cmd"] = true
			if not r.is_empty():
				drop_signal(r)
			else:
				st["aspect"] = ASPECT_STOP
			return ""
		"OSTOP":
			if not st["stop_cmd"]:
				return "Na sygnalizatorze %s nie obowiązuje nakaz STOP." % sig_id
			st["stop_cmd"] = false
			return ""
		"SZ", "SZP":
			if r.is_empty():
				return "Sygnał zastępczy wymaga wcześniej nastawionego przebiegu spod %s." % sig_id
			if r["state"] != ST_UTWIERDZONY:
				return "Przebieg spod %s nie jest jeszcze utwierdzony." % sig_id
			if aspect(sig_id) != ASPECT_STOP:
				return "Sygnalizator %s podaje już sygnał zezwalający — Sz zbędny." % sig_id
			st["sz"] = cmd
			st["aspect"] = ASPECT_SZ
			r["sz"] = true
			return ""
		"NSZ", "NSZP":
			if str(st["sz"]) == "":
				return "Na sygnalizatorze %s nie podano sygnału zastępczego." % sig_id
			st["sz"] = ""
			if aspect(sig_id) == ASPECT_SZ:
				st["aspect"] = ASPECT_STOP
			return ""
		"WTAB":
			tab[sig_id] = "urządzenie wyłączone z użytku"
			return ""
		"KTAB":
			if not tab.has(sig_id):
				return "Na sygnalizatorze %s nie ma tabliczki." % sig_id
			tab.erase(sig_id)
			return ""
	return "Nieznane polecenie %s." % cmd


func set_tab(element_id: String, text: String) -> void:
	tab[element_id] = text


func clear_tab(element_id: String) -> void:
	tab.erase(element_id)
