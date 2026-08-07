class_name StationLayout
extends RefCounted
## Układ torowy posterunku wczytany z layout.json.
##
## Konwencje:
##  * każdy odcinek prowadzi z zachodu na wschód (from.x < to.x),
##  * jazda w kierunku wschodnim ma dir = 1, w zachodnim dir = -1,
##  * rozjazd ma trzy odgałęzienia: root (od strony iglic) oraz plus
##    (położenie zasadnicze) i minus (położenie zwrotne); jazda przez
##    rozjazd możliwa jest tylko root<->plus albo root<->minus.

var station_name := ""
var short_name := ""
var points := {}            # id -> Vector2
var segments := {}          # id -> {from, to, kind}
var seg_len := {}           # id -> float
var adj_e := {}             # punkt -> [{seg, to}]  jazda na wschód
var adj_w := {}             # punkt -> [{seg, to}]  jazda na zachód
var seg_at_point := {}      # punkt -> [seg_id]
var switches := {}          # nr -> {id, point, root, plus, minus}
var switch_at_point := {}   # punkt -> nr
var signals := {}           # id -> {id, point, dir, typ, opis}
var sig_at_point := {}      # "punkt|dir" -> sig_id
var tarcze_ostrz: Array = []
var line_ends := {}         # id -> {id, name, dir_in, lk, kind, tor}
var line_end_order: Array = []
var tracks := {}            # nr -> {nr, seg, a, b, peron, dl}
var track_order: Array = []
var track_of_seg := {}      # seg_id -> nr
var platforms: Array = []
var labels: Array = []
var decor: Array = []
var bounds := Rect2(0, 0, 2000, 900)


func load_file(path: String) -> bool:
	var raw: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not (raw is Dictionary):
		push_error("Nie można wczytać układu torowego: %s" % path)
		return false
	var data: Dictionary = raw
	station_name = str(data.get("name", "Posterunek"))
	short_name = str(data.get("short", ""))
	var min_p := Vector2(1e9, 1e9)
	var max_p := Vector2(-1e9, -1e9)
	for p in data.get("points", []):
		var v := Vector2(float(p["x"]), float(p["y"]))
		points[str(p["id"])] = v
		min_p = min_p.min(v)
		max_p = max_p.max(v)
	bounds = Rect2(min_p - Vector2(160, 80), (max_p - min_p) + Vector2(320, 160))
	for sdef in data.get("segments", []):
		var sid := str(sdef["id"])
		var a := str(sdef["from"])
		var b := str(sdef["to"])
		segments[sid] = {"from": a, "to": b, "kind": str(sdef.get("kind", "stacyjny"))}
		seg_len[sid] = points[a].distance_to(points[b])
		if not adj_e.has(a):
			adj_e[a] = []
		adj_e[a].append({"seg": sid, "to": b})
		if not adj_w.has(b):
			adj_w[b] = []
		adj_w[b].append({"seg": sid, "to": a})
		for endpoint in [a, b]:
			if not seg_at_point.has(endpoint):
				seg_at_point[endpoint] = []
			seg_at_point[endpoint].append(sid)
	for w in data.get("switches", []):
		var wid := str(w["id"])
		switches[wid] = {
			"id": wid, "point": str(w["point"]),
			"root": str(w["root"]), "plus": str(w["plus"]), "minus": str(w["minus"]),
		}
		switch_at_point[str(w["point"])] = wid
	for sg in data.get("signals", []):
		var sid2 := str(sg["id"])
		signals[sid2] = {
			"id": sid2, "point": str(sg["point"]), "dir": int(sg["dir"]),
			"typ": str(sg.get("typ", "wyjazdowy")), "opis": str(sg.get("opis", "")),
		}
		sig_at_point["%s|%d" % [str(sg["point"]), int(sg["dir"])]] = sid2
	tarcze_ostrz = data.get("tarcze_ostrzegawcze", [])
	for le in data.get("line_ends", []):
		var lid := str(le["id"])
		line_ends[lid] = {
			"id": lid, "name": str(le.get("name", lid)),
			"dir_in": int(le.get("dir_in", 1)), "lk": str(le.get("lk", "")),
			"kind": str(le.get("kind", "pociagowy")), "tor": str(le.get("tor", "")),
		}
		line_end_order.append(lid)
	for tr in data.get("tracks", []):
		var nr := str(tr["nr"])
		tracks[nr] = {
			"nr": nr, "seg": str(tr["seg"]), "a": str(tr["a"]), "b": str(tr["b"]),
			"peron": str(tr.get("peron", "")), "dl": float(tr.get("dl", 400)),
		}
		track_order.append(nr)
		track_of_seg[str(tr["seg"])] = nr
	platforms = data.get("platforms", [])
	labels = data.get("labels", [])
	decor = data.get("decor", [])
	return true


func pos(pt_id: String) -> Vector2:
	return points.get(pt_id, Vector2.ZERO)


func signal_at(pt_id: String, dir: int) -> String:
	return str(sig_at_point.get("%s|%d" % [pt_id, dir], ""))


func track_with_end(pt_id: String) -> String:
	for nr in tracks:
		var tr: Dictionary = tracks[nr]
		if tr["a"] == pt_id or tr["b"] == pt_id:
			return nr
	return ""


func is_line_end(pt_id: String) -> bool:
	return line_ends.has(pt_id)


## Czy jazda z odcinka in_seg na odcinek out_seg przez punkt pt jest możliwa
## (zgodnie z budową rozjazdu). Zwraca "" gdy tak, inaczej opis przeszkody.
func transition_error(pt: String, in_seg: String, out_seg: String) -> String:
	if in_seg == "":
		return ""
	var wid: String = str(switch_at_point.get(pt, ""))
	if wid == "":
		return ""
	var w: Dictionary = switches[wid]
	var pair := [in_seg, out_seg]
	if w["root"] in pair and (w["plus"] in pair or w["minus"] in pair):
		return ""
	return "rozjazd nr %s nie łączy tych torów" % wid


## Położenie rozjazdu wymagane dla jazdy in_seg -> out_seg ("+" albo "-").
func required_position(wid: String, in_seg: String, out_seg: String) -> String:
	var w: Dictionary = switches[wid]
	if w["plus"] == in_seg or w["plus"] == out_seg:
		return "+"
	return "-"


func track_length(nr: String) -> float:
	if tracks.has(nr):
		return float(tracks[nr]["dl"])
	return 400.0
