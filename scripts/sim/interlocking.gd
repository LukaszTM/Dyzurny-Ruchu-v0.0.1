class_name Interlocking
extends RefCounted
## Urządzenia srk: nastawianie i zwalnianie przebiegów (pociągowych
## i manewrowych), kontrola wrogości przebiegów, zajętości, zamknięć
## torowych i usterek rozjazdów/semaforów, sygnał zastępczy Sz.

const ASPECT_STOP := 0
const ASPECT_GO := 1
const ASPECT_SHUNT := 2
const ASPECT_SZ := 3

var layout: StationLayout
var locked_segs := {}    # seg_id -> route_id
var locked_pts := {}     # pt_id -> route_id
var closed_segs := {}    # seg_id -> opis (zamknięcie toru)
var failed_points := {}  # pt_id -> true (usterka rozjazdu)
var occupied_segs := {}  # seg_id -> train_id (odświeżane co klatkę)
var routes := {}         # route_id -> Dictionary
var _next_route_id := 1


func _init(p_layout: StationLayout) -> void:
	layout = p_layout


func find_path(start_pt: String, dest_pt: String, dir: int) -> Dictionary:
	var adj: Dictionary = layout.adj_e if dir > 0 else layout.adj_w
	var prev := {}
	var visited := {start_pt: true}
	var queue: Array = [start_pt]
	while not queue.is_empty():
		var p: String = queue.pop_front()
		if p == dest_pt:
			break
		for edge in adj.get(p, []):
			var seg: String = edge["seg"]
			var np: String = edge["to"]
			if visited.has(np):
				continue
			if locked_segs.has(seg) or closed_segs.has(seg) or occupied_segs.has(seg):
				continue
			if locked_pts.has(np):
				continue
			if failed_points.has(np) and np != dest_pt:
				continue
			visited[np] = true
			prev[np] = {"pt": p, "seg": seg}
			queue.append(np)
	if not prev.has(dest_pt):
		return {}
	var pts: Array = [dest_pt]
	var segs: Array = []
	var cur := dest_pt
	while cur != start_pt:
		var e: Dictionary = prev[cur]
		segs.push_front(e["seg"])
		cur = e["pt"]
		pts.push_front(cur)
	return {"pts": pts, "segs": segs}


func route_of_signal(sig_id: String) -> Dictionary:
	for r in routes.values():
		if r["signal_id"] == sig_id:
			return r
	return {}


func set_route(sig_id: String, dest_pt: String, kind: String) -> Dictionary:
	if not layout.signals.has(sig_id):
		return {"error": "Nieznany sygnalizator."}
	var sig: Dictionary = layout.signals[sig_id]
	if sig["shunt_only"]:
		kind = "shunt"
	if not route_of_signal(sig_id).is_empty():
		return {"error": "Sygnalizator %s ma już ustawiony przebieg." % sig_id}
	if dest_pt == sig["point"]:
		return {"error": "Cel przebiegu wskazuje jego początek."}
	if locked_pts.has(sig["point"]):
		return {"error": "Początek przebiegu jest objęty innym przebiegiem."}
	var path := find_path(sig["point"], dest_pt, sig["dir"])
	if path.is_empty():
		return {"error": "Brak wolnej drogi przebiegu (zajętość, wrogość przebiegów, zamknięcie lub usterka rozjazdu)."}
	var rid := _next_route_id
	_next_route_id += 1
	var route := {
		"id": rid,
		"signal_id": sig_id,
		"start_pt": sig["point"],
		"dest_pt": dest_pt,
		"dir": sig["dir"],
		"kind": kind,
		"pts": path["pts"],
		"segs": path["segs"],
		"train_id": 0,
		"dropped": false,
		"needs_sz": false,
		"sz": false,
		"open": false,
	}
	for s in path["segs"]:
		locked_segs[s] = rid
	for p in path["pts"]:
		locked_pts[p] = rid
	if sig["failed"]:
		route["needs_sz"] = true
	else:
		sig["aspect"] = ASPECT_SHUNT if kind == "shunt" else ASPECT_GO
		route["open"] = true
	routes[rid] = route
	return route


## Sygnał zastępczy: otwiera przebieg mimo usterki semafora.
func give_sz(sig_id: String) -> Dictionary:
	var route := route_of_signal(sig_id)
	if route.is_empty():
		return {"error": "Brak ustawionego przebiegu spod sygnalizatora %s." % sig_id}
	if route["open"]:
		return {"error": "Przebieg spod %s jest już otwarty — Sz zbędny." % sig_id}
	layout.signals[sig_id]["aspect"] = ASPECT_SZ
	route["open"] = true
	route["sz"] = true
	return route


func drop_signal(route: Dictionary) -> void:
	if route.get("dropped", false):
		return
	route["dropped"] = true
	var sig: Dictionary = layout.signals[route["signal_id"]]
	sig["aspect"] = ASPECT_STOP


## Zwolnienie odcinka za pociągiem (sekcyjne zwalnianie przebiegu).
func release_seg(seg_id: String, route: Dictionary) -> void:
	if locked_segs.get(seg_id, -1) == route["id"]:
		locked_segs.erase(seg_id)
		var sdef: Dictionary = layout.segments[seg_id]
		var rear: String = sdef["from"] if route["dir"] > 0 else sdef["to"]
		if locked_pts.get(rear, -1) == route["id"]:
			locked_pts.erase(rear)


## Pełne rozwiązanie przebiegu (po dojeździe pociągu do końca drogi).
func finish_route(route: Dictionary) -> void:
	var rid: int = route["id"]
	for s in route["segs"]:
		if locked_segs.get(s, -1) == rid:
			locked_segs.erase(s)
	for p in route["pts"]:
		if locked_pts.get(p, -1) == rid:
			locked_pts.erase(p)
	if not route.get("dropped", false):
		layout.signals[route["signal_id"]]["aspect"] = ASPECT_STOP
		route["dropped"] = true
	routes.erase(rid)


## Doraźne zwolnienie przebiegu przez dyżurnego. Zwraca "" lub opis błędu.
func cancel_route(route: Dictionary) -> String:
	for s in route["segs"]:
		if occupied_segs.has(s):
			return "Nie można zwolnić — pociąg znajduje się w drodze przebiegu."
	if route["train_id"] != 0 and route.get("dropped", false):
		return "Nie można zwolnić — pociąg minął sygnalizator."
	finish_route(route)
	return ""


func seg_route_kind(seg_id: String) -> String:
	var rid: int = locked_segs.get(seg_id, -1)
	if rid < 0:
		return ""
	var r: Dictionary = routes.get(rid, {})
	return str(r.get("kind", ""))
