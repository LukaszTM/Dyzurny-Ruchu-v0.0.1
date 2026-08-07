class_name Train
extends RefCounted
## Pociąg (lub skład manewrowy) poruszający się po ustawionych przebiegach.

enum State { WAITING, MOVING, AT_PLATFORM, READY, DONE }

const SPEED_MAIN := 80.0
const SPEED_SHUNT := 46.0
const SPEED_SZ := 38.0

var id := 0
var nr := ""
var category := "SKM"
var display_name := ""
var from_name := ""
var to_name := ""
var entry_portal := ""
var exit_portal := ""
var pref_track := ""
var sched_arr := -1.0
var sched_dep := -1.0
var delay_min := 0
var flag_start := false     # skład podstawiany pod pociąg zaczynający bieg
var flag_koniec := false    # kończy bieg -> odstawienie do zaplecza
var flag_przelot := false   # przejeżdża bez zatrzymania
var is_shunt_unit := false
var tt_index := -1          # powiązany wiersz rozkładu
var spawned_at := 0.0

var state: int = State.WAITING
var track_nr := ""
var length := 70.0
var actual_arr := -1.0
var actual_dep := -1.0
var stopped_until := 0.0
var stop_reason := ""

var route: Dictionary = {}
var path_pts: Array = []         # Vector2
var seg_of_interval: Array = []  # seg_id (lub "") dla odcinka pts[i]..pts[i+1]
var cum: Array = []              # skumulowana długość w każdym punkcie
var s := 0.0
var total := 0.0
var despawn_end := false
var covered: Array = []
var _released := {}
var _start_s := 0.0


static func length_for(cat: String) -> float:
	match cat:
		"TME":
			return 120.0
		"MAN":
			return 45.0
		"SKM":
			return 60.0
		_:
			return 85.0


func rel_text() -> String:
	return "%s — %s" % [from_name, to_name]


func title() -> String:
	var t := "%s %s" % [category, nr]
	if display_name != "":
		t += " „%s”" % display_name
	return t


func min_dwell() -> float:
	return 35.0 if category == "SKM" else 55.0


## Przypisanie przebiegu. prefix_len > 0 = odjazd/manewr z toru stacyjnego:
## za punktem początkowym dokleja się fragment toru, na którym stoi skład,
## aby zajętość tyłu składu była poprawnie liczona.
func begin_route(p_route: Dictionary, layout: StationLayout, prefix_len := 0.0) -> void:
	route = p_route
	route["train_id"] = id
	path_pts.clear()
	seg_of_interval.clear()
	cum.clear()
	_released.clear()
	covered.clear()
	var pts: Array = route["pts"]
	var segs: Array = route["segs"]
	var start_pos: Vector2 = layout.pos(pts[0])
	if prefix_len > 0.0 and track_nr != "" and layout.tracks.has(track_nr):
		var tr: Dictionary = layout.tracks[track_nr]
		var pa: Vector2 = layout.pos(tr["a"])
		var pb: Vector2 = layout.pos(tr["b"])
		var along := (pb - pa).normalized()
		var back_from: Vector2
		if pts[0] == tr["a"]:
			back_from = start_pos + along * prefix_len
		else:
			back_from = start_pos - along * prefix_len
		path_pts.append(back_from)
		seg_of_interval.append(tr["seg"])
	path_pts.append(start_pos)
	for i in range(segs.size()):
		path_pts.append(layout.pos(pts[i + 1]))
		seg_of_interval.append(segs[i])
	despawn_end = layout.portals.has(route["dest_pt"])
	if despawn_end:
		var dirv: Vector2 = (path_pts[path_pts.size() - 1] - path_pts[path_pts.size() - 2]).normalized()
		path_pts.append(path_pts[path_pts.size() - 1] + dirv * (length + 60.0))
		seg_of_interval.append("")
	cum.append(0.0)
	for i in range(path_pts.size() - 1):
		cum.append(cum[i] + path_pts[i].distance_to(path_pts[i + 1]))
	total = cum[cum.size() - 1]
	s = prefix_len
	_start_s = prefix_len
	state = State.MOVING
	_update_covered()


func current_speed() -> float:
	if route.get("sz", false):
		return SPEED_SZ
	if route.get("kind", "") == "shunt":
		return SPEED_SHUNT
	return SPEED_MAIN


## Krok symulacji. Zwraca: "" | "arrived" | "done"
func step(dt: float, sim_time: float, inter: Interlocking) -> String:
	if state != State.MOVING:
		return ""
	if not route.get("open", false):
		return ""
	if sim_time < stopped_until:
		return ""
	stop_reason = ""
	s = minf(s + current_speed() * dt, total)
	if not route.get("dropped", false) and s > _start_s + 15.0:
		inter.drop_signal(route)
	var tail := s - length
	for i in range(seg_of_interval.size()):
		if _released.has(i):
			continue
		if cum[i + 1] < tail:
			_released[i] = true
			var sid: String = seg_of_interval[i]
			if sid != "":
				inter.release_seg(sid, route)
	_update_covered()
	if s >= total:
		if despawn_end:
			state = State.DONE
			covered.clear()
			return "done"
		state = State.AT_PLATFORM
		return "arrived"
	return ""


func _update_covered() -> void:
	covered.clear()
	var tail := s - length
	for i in range(seg_of_interval.size()):
		if cum[i + 1] <= tail or cum[i] >= s:
			continue
		var sid: String = seg_of_interval[i]
		if sid != "" and not covered.has(sid):
			covered.append(sid)


func pos_at(d: float) -> Vector2:
	if path_pts.is_empty():
		return Vector2.ZERO
	d = clampf(d, 0.0, total)
	for i in range(path_pts.size() - 1):
		if d <= cum[i + 1] or i == path_pts.size() - 2:
			var seg_l: float = cum[i + 1] - cum[i]
			var t: float = 0.0 if seg_l <= 0.0 else (d - cum[i]) / seg_l
			return path_pts[i].lerp(path_pts[i + 1], t)
	return path_pts[path_pts.size() - 1]


func head_pos() -> Vector2:
	return pos_at(s)


func body_points() -> PackedVector2Array:
	var res := PackedVector2Array()
	if path_pts.is_empty():
		return res
	var tail := maxf(s - length, 0.0)
	res.append(pos_at(tail))
	for i in range(path_pts.size()):
		if cum[i] > tail and cum[i] < s:
			res.append(path_pts[i])
	res.append(pos_at(s))
	return res


func state_text() -> String:
	match state:
		State.WAITING:
			return "oczekuje przed stacją"
		State.MOVING:
			if stop_reason != "":
				return stop_reason
			if route.get("kind", "") == "shunt":
				return "jazda manewrowa"
			return "w ruchu"
		State.AT_PLATFORM:
			return "na torze %s" % track_nr
		State.READY:
			if flag_koniec or is_shunt_unit:
				return "do odstawienia (tor %s)" % track_nr
			return "gotowy do odjazdu (tor %s)" % track_nr
		_:
			return "obsłużony"
