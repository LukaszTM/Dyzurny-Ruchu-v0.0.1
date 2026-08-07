class_name Train
extends RefCounted
## Pociąg lub skład manewrowy poruszający się po nastawionych przebiegach.

enum State { OCZEKUJE, JEDZIE, NA_TORZE, GOTOWY, ZAKONCZONY }

const V_POCIAGOWA := 78.0
const V_MANEWROWA := 44.0
const V_SZ := 36.0

# rodzaje pociągów wg wykazu PKP
const RODZAJE := {
	"EIP": "Express InterCity Premium",
	"EIE": "Express InterCity",
	"MPE": "międzywojewódzki pospieszny",
	"MOE": "międzywojewódzki osobowy",
	"ROJ": "regionalny osobowy",
	"AOE": "aglomeracyjny osobowy",
	"TDE": "towarowy dalekobieżny",
	"TME": "towarowy międzynarodowy",
	"PWE": "próżny skład wagonowy",
	"LPE": "lokomotywa luzem",
	"MAN": "manewrowy",
}

var id := 0
var nr := ""
var rodzaj := "ROJ"
var nazwa := ""
var st_poczatkowa := ""
var st_koncowa := ""
var wjazd := ""              # id szlaku wjazdowego
var wyjazd := ""             # id szlaku wyjazdowego
var tor_zadany := ""
var sched_arr := -1.0
var sched_dep := -1.0
var postoj := 0.0
var delay_min := 0
var flag_przelot := false
var flag_koniec := false
var flag_podstawienie := false
var manewrowy := false
var tt_index := -1
var spawned_at := 0.0

var state: int = State.OCZEKUJE
var tor := ""
var dlugosc := 70.0
var actual_arr := -1.0
var actual_dep := -1.0
var stopped_until := 0.0
var stop_reason := ""

var route: Dictionary = {}
var path_pts: Array = []
var seg_of_interval: Array = []
var cum: Array = []
var s := 0.0
var total := 0.0
var start_s := 0.0
var despawn_end := false
var covered: Array = []
var _released := {}


static func length_for(rodz: String) -> float:
	match rodz:
		"TME", "TDE":
			return 130.0
		"MAN", "LPE":
			return 40.0
		"AOE", "ROJ":
			return 60.0
		"PWE":
			return 90.0
		_:
			return 90.0


func relacja() -> String:
	return "%s — %s" % [st_poczatkowa, st_koncowa]


func opis() -> String:
	var t := "%s %s" % [rodzaj, nr]
	if nazwa != "":
		t += " „%s”" % nazwa
	return t


func min_postoj() -> float:
	if postoj > 0.0:
		return postoj
	return 40.0 if rodzaj in ["AOE", "ROJ"] else 60.0


## Przypisanie przebiegu. prefix_len > 0 — jazda z toru stacyjnego: za punktem
## początkowym dokleja się fragment toru, na którym stoi skład, aby zajętość
## końca składu była liczona poprawnie.
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
	if prefix_len > 0.0 and tor != "" and layout.tracks.has(tor):
		var tr: Dictionary = layout.tracks[tor]
		var pa: Vector2 = layout.pos(tr["a"])
		var pb: Vector2 = layout.pos(tr["b"])
		var along := (pb - pa).normalized()
		var back: Vector2 = start_pos + along * prefix_len if pts[0] == tr["a"] else start_pos - along * prefix_len
		path_pts.append(back)
		seg_of_interval.append(str(tr["seg"]))
	path_pts.append(start_pos)
	for i in range(segs.size()):
		path_pts.append(layout.pos(pts[i + 1]))
		seg_of_interval.append(str(segs[i]))
	despawn_end = layout.is_line_end(str(route["dest_pt"]))
	if despawn_end:
		var n := path_pts.size()
		var dirv: Vector2 = (path_pts[n - 1] - path_pts[n - 2]).normalized()
		path_pts.append(path_pts[n - 1] + dirv * (dlugosc + 70.0))
		seg_of_interval.append("")
	cum.append(0.0)
	for i in range(path_pts.size() - 1):
		cum.append(cum[i] + path_pts[i].distance_to(path_pts[i + 1]))
	total = cum[cum.size() - 1]
	s = prefix_len
	start_s = prefix_len
	state = State.JEDZIE
	_update_covered()


func predkosc() -> float:
	if route.get("sz", false):
		return V_SZ
	if str(route.get("kind", "P")) == "M":
		return V_MANEWROWA
	return V_POCIAGOWA


## Krok symulacji. Zwraca "", "przyjazd" albo "koniec".
func step(dt: float, sim_time: float, inter: Interlocking) -> String:
	if state != State.JEDZIE:
		return ""
	if not inter.route_open(route) and not route.get("passed", false):
		return ""
	if sim_time < stopped_until:
		return ""
	stop_reason = ""
	s = minf(s + predkosc() * dt, total)
	if not route.get("passed", false) and s > start_s + 14.0:
		inter.drop_signal(route)
	var tail := s - dlugosc
	for i in range(seg_of_interval.size()):
		if _released.has(i):
			continue
		if float(cum[i + 1]) < tail:
			_released[i] = true
			var sid: String = seg_of_interval[i]
			if sid != "":
				inter.release_seg(sid, route)
	_update_covered()
	if s >= total:
		if despawn_end:
			state = State.ZAKONCZONY
			covered.clear()
			return "koniec"
		state = State.NA_TORZE
		return "przyjazd"
	return ""


func _update_covered() -> void:
	covered.clear()
	var tail := s - dlugosc
	for i in range(seg_of_interval.size()):
		if float(cum[i + 1]) <= tail or float(cum[i]) >= s:
			continue
		var sid: String = seg_of_interval[i]
		if sid != "" and not covered.has(sid):
			covered.append(sid)


func pos_at(d: float) -> Vector2:
	if path_pts.is_empty():
		return Vector2.ZERO
	d = clampf(d, 0.0, total)
	for i in range(path_pts.size() - 1):
		if d <= float(cum[i + 1]) or i == path_pts.size() - 2:
			var seg_l: float = float(cum[i + 1]) - float(cum[i])
			var t: float = 0.0 if seg_l <= 0.0 else (d - float(cum[i])) / seg_l
			return path_pts[i].lerp(path_pts[i + 1], t)
	return path_pts[path_pts.size() - 1]


func head_pos() -> Vector2:
	return pos_at(s)


func body_points() -> PackedVector2Array:
	var res := PackedVector2Array()
	if path_pts.is_empty():
		return res
	var tail := maxf(s - dlugosc, 0.0)
	res.append(pos_at(tail))
	for i in range(path_pts.size()):
		if float(cum[i]) > tail and float(cum[i]) < s:
			res.append(path_pts[i])
	res.append(pos_at(s))
	return res


func state_text() -> String:
	match state:
		State.OCZEKUJE:
			return "oczekuje przed semaforem wjazdowym"
		State.JEDZIE:
			if stop_reason != "":
				return stop_reason
			return "jazda manewrowa" if str(route.get("kind", "P")) == "M" else "w ruchu"
		State.NA_TORZE:
			return "na torze %s" % tor
		State.GOTOWY:
			if flag_koniec or manewrowy:
				return "do odstawienia (tor %s)" % tor
			return "gotowy do odjazdu (tor %s)" % tor
		_:
			return "obsłużony"
