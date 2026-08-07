class_name SchemaView
extends Node2D
## Obraz świetlny pulpitu nastawczego — odwzorowanie wyglądu komputerowych
## nastawnic stosowanych na PKP: czarne tło, szare tory, biała droga
## przebiegu utwierdzonego, czerwona zajętość, numery rozjazdów z ich
## położeniem (+ / −), sygnalizatory w postaci trójkątów.

const COL_BG := Color("000000")
const COL_TOR := Color("858585")
const COL_UTW := Color("f2f2f2")
const COL_NAST := Color("00c8d7")
const COL_ZAJETY := Color("cf1020")
const COL_ZAMK := Color("d08000")
const COL_OPIS := Color("b9b9b9")
const COL_SYG := Color("d8a72a")
const COL_SEL := Color("00e5ff")
const COL_PERON := Color("6f6f6f")
const COL_NR := Color("e8e8e8")

const CAT_COL := {
	"EIP": Color("8b5cf6"), "EIE": Color("6d28d9"), "MPE": Color("2563eb"),
	"MOE": Color("0891b2"), "ROJ": Color("16a34a"), "AOE": Color("22c55e"),
	"TDE": Color("a16207"), "TME": Color("92400e"), "PWE": Color("64748b"),
	"LPE": Color("64748b"), "MAN": Color("f59e0b"),
}

var sim: SimCore = null
var layout: StationLayout
var inter: Interlocking
var cam: Camera2D
var _drag := false
var _font: Font
var signal_menu_request := Callable()


func setup(p_sim: SimCore) -> void:
	sim = p_sim
	layout = sim.layout
	inter = sim.inter
	_font = ThemeDB.fallback_font
	cam = Camera2D.new()
	cam.position = layout.bounds.get_center()
	add_child(cam)
	fit_to_view()


func fit_to_view() -> void:
	if cam == null:
		return
	var vp := get_viewport_rect().size
	if vp.x <= 0.0:
		return
	var z: float = minf(vp.x / maxf(layout.bounds.size.x, 1.0),
		(vp.y - 190.0) / maxf(layout.bounds.size.y, 1.0))
	z = clampf(z, 0.25, 2.0)
	cam.zoom = Vector2(z, z)
	cam.position = layout.bounds.get_center() + Vector2(0, 30.0 / z)


func _unhandled_input(event: InputEvent) -> void:
	var mb := event as InputEventMouseButton
	if mb != null:
		if mb.button_index == MOUSE_BUTTON_WHEEL_UP and mb.pressed:
			_zoom(1.12)
		elif mb.button_index == MOUSE_BUTTON_WHEEL_DOWN and mb.pressed:
			_zoom(1.0 / 1.12)
		elif mb.button_index == MOUSE_BUTTON_MIDDLE:
			_drag = mb.pressed
		elif mb.button_index == MOUSE_BUTTON_RIGHT:
			_drag = mb.pressed
			if not mb.pressed:
				var hit := pick(get_global_mouse_position())
				if str(hit["kind"]) == "signal" and signal_menu_request.is_valid():
					signal_menu_request.call(str(hit["id"]), mb.global_position)
					get_viewport().set_input_as_handled()
		elif mb.button_index == MOUSE_BUTTON_LEFT and mb.pressed:
			var hit2 := pick(get_global_mouse_position())
			if str(hit2["kind"]) != "":
				sim.click_element(str(hit2["kind"]), str(hit2["id"]))
				get_viewport().set_input_as_handled()
		return
	var mm := event as InputEventMouseMotion
	if mm != null and _drag:
		cam.position -= mm.relative / cam.zoom.x


func _zoom(f: float) -> void:
	var z := clampf(cam.zoom.x * f, 0.25, 3.0)
	cam.zoom = Vector2(z, z)


# ------------------------------------------------------------- trafienia ---

func pick(world: Vector2) -> Dictionary:
	var best := {"kind": "", "id": ""}
	var best_d := 20.0
	for sid in layout.signals:
		var d := _sig_pos(layout.signals[sid]).distance_to(world)
		if d < best_d:
			best_d = d
			best = {"kind": "signal", "id": sid}
	if best["kind"] != "":
		return best
	for wid in layout.switches:
		var d2 := layout.pos(str(layout.switches[wid]["point"])).distance_to(world)
		if d2 < 16.0:
			return {"kind": "switch", "id": wid}
	for lid in layout.line_end_order:
		if _line_end_rect(lid).has_point(world):
			return {"kind": "line_end", "id": lid}
	for t: Train in sim.trains.values():
		if t.state == Train.State.OCZEKUJE or t.state == Train.State.ZAKONCZONY:
			continue
		if t.head_pos().distance_to(world) < 22.0:
			return {"kind": "train", "id": str(t.id)}
	for nr in layout.tracks:
		var tr: Dictionary = layout.tracks[nr]
		var a := layout.pos(str(tr["a"]))
		var b := layout.pos(str(tr["b"]))
		if absf(world.y - a.y) < 10.0 and world.x > a.x and world.x < b.x:
			return {"kind": "track", "id": nr}
	return best


func _sig_pos(sg: Dictionary) -> Vector2:
	return layout.pos(str(sg["point"])) + Vector2(0, 15 if int(sg["dir"]) > 0 else -15)


func _line_end_rect(lid: String) -> Rect2:
	var p := layout.pos(lid)
	var out := -1.0 if int(layout.line_ends[lid]["dir_in"]) > 0 else 1.0
	return Rect2(p + Vector2(out * 46.0 - 30.0, -13.0), Vector2(60, 26))


# ---------------------------------------------------------------- rysunek --

func _draw() -> void:
	if layout == null:
		return
	var blink := fmod(Time.get_ticks_msec() / 400.0, 2.0) < 1.0
	draw_rect(Rect2(layout.bounds.position - Vector2(400, 400),
		layout.bounds.size + Vector2(800, 800)), COL_BG)
	_draw_platforms()
	_draw_segments(blink)
	_draw_switches(blink)
	_draw_track_numbers()
	_draw_line_ends(blink)
	_draw_tarcze()
	_draw_signals(blink)
	_draw_trains(blink)
	for lb in layout.labels:
		draw_string(_font, Vector2(float(lb["x"]), float(lb["y"])), str(lb["text"]),
			HORIZONTAL_ALIGNMENT_LEFT, -1, int(lb.get("size", 12)), COL_OPIS.darkened(0.35))


func _draw_platforms() -> void:
	for pl in layout.platforms:
		var r := Rect2(float(pl["x"]), float(pl["y"]), float(pl["w"]), float(pl["h"]))
		draw_rect(r, COL_BG)
		draw_rect(r, COL_PERON, false, 1.5)
		draw_string(_font, r.position + Vector2(6, r.size.y - 2), str(pl["name"]),
			HORIZONTAL_ALIGNMENT_LEFT, -1, 10, COL_OPIS)


func _seg_color(sid: String, blink: bool) -> Color:
	if inter.occupied_segs.has(sid):
		return COL_ZAJETY
	if inter.closed_segs.has(sid):
		return COL_ZAMK if blink else COL_ZAMK.darkened(0.5)
	if inter.locked_segs.has(sid):
		var r := inter.seg_route(sid)
		if not r.is_empty() and str(r["state"]) == Interlocking.ST_NASTAWIANIE:
			return COL_NAST if blink else COL_NAST.darkened(0.5)
		return COL_UTW
	if inter.tab.has(sid):
		return COL_ZAMK.darkened(0.3)
	return COL_TOR


func _draw_segments(blink: bool) -> void:
	for sid in layout.segments:
		var sdef: Dictionary = layout.segments[sid]
		var a := layout.pos(str(sdef["from"]))
		var b := layout.pos(str(sdef["to"]))
		var col := _seg_color(sid, blink)
		var w := 4.0 if str(sdef["kind"]) != "szlak" else 3.0
		if str(sdef["kind"]) == "szlak":
			_draw_dashed(a, b, col, w)
		else:
			draw_line(a, b, col, w)
		if inter.closed_segs.has(sid):
			var m := (a + b) / 2.0
			draw_line(m + Vector2(-7, -7), m + Vector2(7, 7), COL_ZAMK, 2.0)
			draw_line(m + Vector2(-7, 7), m + Vector2(7, -7), COL_ZAMK, 2.0)


func _draw_dashed(a: Vector2, b: Vector2, col: Color, w: float) -> void:
	var d := a.distance_to(b)
	var dir := (b - a).normalized()
	var x := 0.0
	while x < d:
		var e: float = minf(x + 11.0, d)
		draw_line(a + dir * x, a + dir * e, col, w)
		x = e + 7.0


func _draw_switches(blink: bool) -> void:
	for wid in layout.switches:
		var w: Dictionary = layout.switches[wid]
		var p := layout.pos(str(w["point"]))
		var pos_txt := str(inter.sw_pos.get(wid, "+"))
		var col := COL_NR
		if inter.sw_failed.has(wid):
			col = COL_ZAMK if blink else COL_ZAMK.darkened(0.5)
		elif inter.sw_moving.has(wid):
			col = COL_NAST if blink else COL_NAST.darkened(0.5)
		elif inter.sw_locked.has(wid):
			col = COL_UTW
		draw_string(_font, p + Vector2(-14, -8), wid, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, col)
		draw_string(_font, p + Vector2(6, -8), pos_txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 11,
			COL_NR if not inter.sw_failed.has(wid) else COL_ZAMK)
		if inter.sw_failed.has(wid) and blink:
			draw_arc(p, 10.0, 0, TAU, 20, COL_ZAMK, 2.0)
		if inter.tab.has(wid):
			draw_rect(Rect2(p + Vector2(-9, -9), Vector2(18, 18)), COL_ZAMK, false, 1.5)
		if str(sim.selected.get("kind", "")) == "switch" and str(sim.selected.get("id", "")) == wid:
			draw_arc(p, 12.0, 0, TAU, 24, COL_SEL, 2.0)


func _draw_track_numbers() -> void:
	for nr in layout.track_order:
		var tr: Dictionary = layout.tracks[nr]
		var a := layout.pos(str(tr["a"]))
		var b := layout.pos(str(tr["b"]))
		var m := (a + b) / 2.0
		draw_string(_font, m + Vector2(-4, -8), nr, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, COL_NR)


func _draw_line_ends(blink: bool) -> void:
	for lid in layout.line_end_order:
		var le: Dictionary = layout.line_ends[lid]
		var r := _line_end_rect(lid)
		var na_zewnatrz := int(le["dir_in"]) > 0
		draw_rect(r, COL_BG)
		draw_rect(r, COL_TOR, false, 1.5)
		var c := r.get_center()
		var ad := -1.0 if na_zewnatrz else 1.0
		draw_line(c + Vector2(-9 * ad, 0), c + Vector2(9 * ad, 0), COL_OPIS, 2.0)
		draw_line(c + Vector2(9 * ad, 0), c + Vector2(3 * ad, -4), COL_OPIS, 2.0)
		draw_line(c + Vector2(9 * ad, 0), c + Vector2(3 * ad, 4), COL_OPIS, 2.0)
		draw_string(_font, c + Vector2(-24, -16), lid, HORIZONTAL_ALIGNMENT_LEFT, -1, 10, COL_OPIS)
		var nm := "%s  %s" % [str(le["name"]), str(le["lk"])]
		var np := r.position + Vector2(-4, r.size.y + 13) if na_zewnatrz else r.position + Vector2(-4, r.size.y + 13)
		draw_string(_font, np, nm, HORIZONTAL_ALIGNMENT_LEFT, -1, 10, COL_OPIS.darkened(0.2))
		var q: Array = sim.queues.get(lid, [])
		if not q.is_empty():
			var t: Train = sim.trains.get(int(q[0]))
			var txt := "%s" % (t.nr if t != null else "?")
			if q.size() > 1:
				txt += "  (+%d)" % (q.size() - 1)
			var box := Rect2(r.position + Vector2(0, -46), Vector2(maxf(58.0, txt.length() * 8.0), 24))
			draw_rect(box, COL_ZAJETY if blink else COL_ZAJETY.darkened(0.35))
			draw_string(_font, box.position + Vector2(6, 17), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color.WHITE)
		if str(sim.selected.get("kind", "")) == "line_end" and str(sim.selected.get("id", "")) == lid:
			draw_rect(r.grow(4.0), COL_SEL, false, 2.0)


func _draw_tarcze() -> void:
	for to in layout.tarcze_ostrz:
		var p := Vector2(float(to["x"]), float(to["y"]))
		draw_line(p + Vector2(0, 12), p + Vector2(0, -2), Color("d060d0"), 1.5)
		draw_line(p + Vector2(0, -2), p + Vector2(-6, -11), Color("d060d0"), 1.5)
		draw_line(p + Vector2(0, -2), p + Vector2(6, -11), Color("d060d0"), 1.5)
		draw_string(_font, p + Vector2(-12, 26), str(to["id"]), HORIZONTAL_ALIGNMENT_LEFT, -1, 9, COL_OPIS.darkened(0.3))


func _draw_signals(blink: bool) -> void:
	for sid in layout.signals:
		var sg: Dictionary = layout.signals[sid]
		var p := _sig_pos(sg)
		var base := layout.pos(str(sg["point"]))
		draw_line(base, p, COL_TOR.darkened(0.2), 1.0)
		var a := inter.aspect(sid)
		var col := Color("cf1020")
		match a:
			Interlocking.ASPECT_JAZDA:
				col = Color("22c55e")
			Interlocking.ASPECT_MANEWR:
				col = Color("f2f2f2")
			Interlocking.ASPECT_SZ:
				col = Color("f2f2f2") if blink else Color("404040")
		var d := 1.0 if int(sg["dir"]) > 0 else -1.0
		var manewrowa: bool = str(sg["typ"]) == "manewrowy"
		var pts := PackedVector2Array([
			p + Vector2(-7 * d, -7), p + Vector2(7 * d, 0), p + Vector2(-7 * d, 7)])
		if manewrowa:
			draw_rect(Rect2(p - Vector2(6, 6), Vector2(12, 12)), col, not manewrowa)
			draw_rect(Rect2(p - Vector2(6, 6), Vector2(12, 12)), col, false, 2.0)
		else:
			draw_colored_polygon(pts, col)
		if inter.is_signal_failed(sid):
			draw_line(p + Vector2(-9, -9), p + Vector2(9, 9), COL_ZAMK, 2.0)
			draw_line(p + Vector2(-9, 9), p + Vector2(9, -9), COL_ZAMK, 2.0)
		if inter.tab.has(sid):
			draw_rect(Rect2(p + Vector2(-11, -11), Vector2(22, 22)), COL_ZAMK, false, 1.5)
		if sim.pending_start == sid:
			draw_arc(p, 13.0, 0, TAU, 26, COL_SEL, 2.5)
		elif str(sim.selected.get("kind", "")) == "signal" and str(sim.selected.get("id", "")) == sid:
			draw_arc(p, 13.0, 0, TAU, 26, COL_SEL.darkened(0.4), 1.5)
		var off := Vector2(-8, 24) if int(sg["dir"]) > 0 else Vector2(-8, -16)
		draw_string(_font, p + off, sid, HORIZONTAL_ALIGNMENT_LEFT, -1, 11,
			COL_SEL if sim.pending_start == sid else COL_SYG)


func _draw_trains(blink: bool) -> void:
	for t: Train in sim.trains.values():
		if t.state == Train.State.OCZEKUJE or t.state == Train.State.ZAKONCZONY:
			continue
		var col: Color = CAT_COL.get(t.rodzaj, Color("9ca3af"))
		var body := t.body_points()
		for i in range(body.size() - 1):
			draw_line(body[i], body[i + 1], col, 9.0)
		var head := t.head_pos()
		var lbl := "%s %s" % [t.rodzaj, t.nr]
		var lp := head + Vector2(-18, -16)
		var box := Rect2(lp + Vector2(-5, -12), Vector2(12 + lbl.length() * 7.0, 17))
		draw_rect(box, Color(0, 0, 0, 0.85))
		var border := col
		if t.state == Train.State.GOTOWY and blink:
			border = Color("22c55e")
		elif t.stop_reason != "":
			border = COL_ZAMK
		draw_rect(box, border, false, 1.5)
		draw_string(_font, lp, lbl, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color("eef2f7"))
		if t.state == Train.State.GOTOWY:
			draw_string(_font, lp + Vector2(0, 26), "GOTÓW", HORIZONTAL_ALIGNMENT_LEFT, -1, 9, Color("22c55e"))
		elif t.stop_reason != "":
			draw_string(_font, lp + Vector2(0, 26), t.stop_reason.to_upper(), HORIZONTAL_ALIGNMENT_LEFT, -1, 9, COL_ZAMK)
