class_name StationLayout
extends RefCounted
## Układ torowy posterunku wczytywany z JSON.
## Wszystkie odcinki (segments) są opisane od punktu zachodniego ("from")
## do wschodniego ("to"); jazda w kierunku wschodnim (dir=1) odbywa się
## po krawędziach from->to, w kierunku zachodnim (dir=-1) po to->from.

var station_name := ""
var points := {}          # id -> Vector2
var segments := {}        # id -> {from, to}
var seg_len := {}         # id -> float
var adj_e := {}           # punkt -> [{seg, to}]  (jazda na wschód)
var adj_w := {}           # punkt -> [{seg, to}]  (jazda na zachód)
var signals := {}         # id -> {id, point, dir, shunt_only, aspect, failed}
var portals := {}         # punkt-id -> {id, name, dir_in, kind}
var portal_order: Array = []
var tracks := {}          # nr -> {nr, seg, a, b, platform}
var track_order: Array = []
var switch_points: Array = []
var platforms: Array = []
var labels: Array = []


func load_file(path: String) -> bool:
	var raw: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not (raw is Dictionary):
		push_error("Nie można wczytać układu: %s" % path)
		return false
	var data: Dictionary = raw
	station_name = str(data.get("name", "Posterunek"))
	for p in data.get("points", []):
		points[str(p["id"])] = Vector2(float(p["x"]), float(p["y"]))
	for sdef in data.get("segments", []):
		var sid := str(sdef["id"])
		var a := str(sdef["from"])
		var b := str(sdef["to"])
		segments[sid] = {"from": a, "to": b}
		seg_len[sid] = points[a].distance_to(points[b])
		if not adj_e.has(a):
			adj_e[a] = []
		adj_e[a].append({"seg": sid, "to": b})
		if not adj_w.has(b):
			adj_w[b] = []
		adj_w[b].append({"seg": sid, "to": a})
	for sg in data.get("signals", []):
		var sig := {
			"id": str(sg["id"]),
			"point": str(sg["point"]),
			"dir": int(sg["dir"]),
			"shunt_only": bool(sg.get("shunt_only", false)),
			"aspect": 0,
			"failed": false,
		}
		signals[sig["id"]] = sig
	for po in data.get("portals", []):
		var pid := str(po["id"])
		portals[pid] = {
			"id": pid,
			"name": str(po.get("name", pid)),
			"dir_in": int(po.get("dir_in", 1)),
			"kind": str(po.get("kind", "pas")),
		}
		portal_order.append(pid)
	for tr in data.get("tracks", []):
		var nr := str(tr["nr"])
		tracks[nr] = {
			"nr": nr,
			"seg": str(tr["seg"]),
			"a": str(tr["a"]),
			"b": str(tr["b"]),
			"platform": str(tr.get("platform", "")),
		}
		track_order.append(nr)
	for sw in data.get("switch_points", []):
		switch_points.append(str(sw))
	platforms = data.get("platforms", [])
	labels = data.get("labels", [])
	return true


func pos(pt_id: String) -> Vector2:
	return points.get(pt_id, Vector2.ZERO)


func signal_at_point(pt_id: String, dir: int) -> String:
	for sid in signals:
		var sig: Dictionary = signals[sid]
		if sig["point"] == pt_id and sig["dir"] == dir:
			return sid
	return ""


func track_with_end(pt_id: String) -> String:
	for nr in tracks:
		var tr: Dictionary = tracks[nr]
		if tr["a"] == pt_id or tr["b"] == pt_id:
			return nr
	return ""


func track_segment_ids() -> Array:
	var res: Array = []
	for nr in tracks:
		res.append(tracks[nr]["seg"])
	return res
