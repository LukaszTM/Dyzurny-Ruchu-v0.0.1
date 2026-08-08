class_name SchemaView
extends Node2D
## Obraz pulpitu nastawczego LCS — odwzorowanie wyglądu z SimRail:
## czarne tło; szare tory; biała droga przebiegu utwierdzonego; czerwona
## zajętość ze strzałkami kierunku; sygnalizatory jako podwójne groty
## z nazwami na żółto; numery rozjazdów z położeniem +/−; seledynowe
## obwódki wybranych przycisków i nazwy odcinków zbliżania; czerwone
## kasetki z numerami pociągów; różowe znaki km i linia przejazdu;
## kasetka skrótu posterunku na dole.

const COL_BG := Color("000000")
const COL_TOR := Color("8a8a8a")
const COL_UTW_P := Color("18c832")   # przebieg pociągowy utwierdzony — ZIELONY (jak w LCS)
const COL_UTW_M := Color("f2f2f2")   # przebieg manewrowy — biały
const COL_NAST := Color("00c8d7")
const COL_ZAJETY := Color("d01020")
const COL_ZAMK := Color("d08000")
const COL_OPIS := Color("9a9a9a")
const COL_ZOLTY := Color("c8a018")
const COL_SEL := Color("00e5ff")
const COL_NR := Color("e8e8e8")
const COL_CYJAN := Color("00b0c0")
const COL_ROZOWY := Color("d060d0")
const COL_KASETA := Color("9e0e0e")

const CHEV_GO := Color("18c832")
const CHEV_MAN := Color("f0f0f0")
const CHEV_STOP := Color("8a8a8a")

const RZYM := ["I", "II", "III"]

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
	var mono := SystemFont.new()
	mono.font_names = PackedStringArray(["DejaVu Sans Mono", "Liberation Mono", "Consolas", "Courier New"])
	_font = mono
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
		(vp.y - 150.0) / maxf(layout.bounds.size.y, 1.0))
	z = clampf(z, 0.25, 2.0)
	cam.zoom = Vector2(z, z)
	cam.position = layout.bounds.get_center() + Vector2(0, 40.0 / z)


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
	return layout.pos(str(sg["point"])) + Vector2(0, 16 if int(sg["dir"]) > 0 else -16)


func _line_end_rect(lid: String) -> Rect2:
	var p := layout.pos(lid)
	var out := -1.0 if int(layout.line_ends[lid]["dir_in"]) > 0 else 1.0
	return Rect2(p + Vector2(out * 48.0 - 34.0, -16.0), Vector2(68, 32))


# ---------------------------------------------------------------- rysunek --

func _draw() -> void:
	if layout == null:
		return
	var blink := fmod(Time.get_ticks_msec() / 400.0, 2.0) < 1.0
	draw_rect(Rect2(layout.bounds.position - Vector2(500, 500),
		layout.bounds.size + Vector2(1000, 1000)), COL_BG)
	_draw_decor_under()
	_draw_platforms()
	_draw_segments(blink)
	_draw_switches(blink)
	_draw_track_numbers()
	_draw_line_ends(blink)
	_draw_tarcze()
	_draw_signals(blink)
	_draw_decor_over()
	for lb in layout.labels:
		draw_string(_font, Vector2(float(lb["x"]), float(lb["y"])), str(lb["text"]),
			HORIZONTAL_ALIGNMENT_LEFT, -1, int(lb.get("size", 12)), COL_OPIS.darkened(0.45))
	# kasetki pociągów rysowane NA KOŃCU — nic nie może zasłaniać numeru
	_draw_trains(blink)


## Różowa linia przejazdu — rysowana pod torami.
func _draw_decor_under() -> void:
	for d in layout.decor:
		if str(d["type"]) == "crossing":
			var x := float(d["x"])
			var y1 := float(d["y1"])
			var y2 := float(d["y2"])
			draw_line(Vector2(x, y1), Vector2(x, y2), COL_ROZOWY, 1.6)
			draw_line(Vector2(x, y1), Vector2(x - 5, y1 - 9), COL_ROZOWY, 1.6)
			draw_line(Vector2(x, y1), Vector2(x + 5, y1 - 9), COL_ROZOWY, 1.6)
			draw_line(Vector2(x, y2), Vector2(x - 5, y2 + 9), COL_ROZOWY, 1.6)
			draw_line(Vector2(x, y2), Vector2(x + 5, y2 + 9), COL_ROZOWY, 1.6)
			draw_string(_font, Vector2(x - 34, y1 - 26), str(d.get("label", "")),
				HORIZONTAL_ALIGNMENT_LEFT, -1, 11, COL_NR)
			draw_string(_font, Vector2(x - 18, y1 - 13), str(d.get("km", "")),
				HORIZONTAL_ALIGNMENT_LEFT, -1, 11, COL_NR)


## Kasetka skrótu posterunku i znaki km — nad torami.
func _draw_decor_over() -> void:
	for d in layout.decor:
		match str(d["type"]):
			"lb":
				var p := Vector2(float(d["x"]), float(d["y"]))
				var r := Rect2(p, Vector2(46, 28))
				draw_rect(r, COL_BG)
				draw_rect(r, COL_NR, false, 1.5)
				draw_rect(Rect2(p + Vector2(5, 5), Vector2(24, 12)), COL_NR, false, 1.0)
				draw_circle(p + Vector2(11, 21), 3.0, COL_NR)
				draw_string(_font, p + Vector2(2, 44), "\"%s\"" % str(d.get("label", "")),
					HORIZONTAL_ALIGNMENT_LEFT, -1, 12, COL_NR)
			"stub":
				var x1 := float(d["x1"])
				var x2 := float(d["x2"])
				var y := float(d["y"])
				var xk := x1 if str(d.get("koz", "l")) == "l" else x2
				var seg_d := (x2 - x1)
				var xx := x1
				while xx < x1 + seg_d:
					var xe: float = minf(xx + 10.0, x1 + seg_d)
					draw_line(Vector2(xx, y), Vector2(xe, y), COL_TOR.darkened(0.2), 3.0)
					xx = xe + 6.0
				draw_line(Vector2(xk, y - 7), Vector2(xk, y + 7), COL_NR, 2.5)
				draw_string(_font, Vector2((x1 + x2) / 2.0 - 12, y + 17), str(d.get("label", "")),
					HORIZONTAL_ALIGNMENT_LEFT, -1, 10, COL_CYJAN)
			"box":
				var rb := Rect2(float(d["x"]), float(d["y"]), float(d["w"]), float(d["h"]))
				draw_rect(rb, Color("b0b0b0"))
				draw_rect(rb, Color("d8d8d8"), false, 1.0)
			"km":
				var q := Vector2(float(d["x"]), float(d["y"]))
				draw_line(q + Vector2(0, 10), q + Vector2(0, -2), COL_ROZOWY, 1.6)
				draw_line(q + Vector2(0, -2), q + Vector2(-5, -10), COL_ROZOWY, 1.6)
				draw_line(q + Vector2(0, -2), q + Vector2(5, -10), COL_ROZOWY, 1.6)
				draw_string(_font, q + Vector2(-16, -16), str(d.get("km", "")),
					HORIZONTAL_ALIGNMENT_LEFT, -1, 10, COL_NR)


func _draw_platforms() -> void:
	for pl in layout.platforms:
		var r := Rect2(float(pl["x"]), float(pl["y"]), float(pl["w"]), float(pl["h"]))
		draw_rect(r, COL_BG)
		draw_rect(r, Color("c8c8c8"), false, 1.5)
		draw_rect(r.grow(-3.0), Color("6f6f6f"), false, 1.0)
		draw_string(_font, r.position + Vector2(r.size.x / 2.0 - 24.0, r.size.y - 3), str(pl["name"]),
			HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color("d8d8d8"))


func _seg_color(sid: String, blink: bool) -> Color:
	if inter.occupied_segs.has(sid):
		return COL_ZAJETY
	if inter.closed_segs.has(sid):
		return COL_ZAMK if blink else COL_ZAMK.darkened(0.5)
	if inter.locked_segs.has(sid):
		var r := inter.seg_route(sid)
		if not r.is_empty() and str(r["state"]) == Interlocking.ST_NASTAWIANIE:
			return COL_NAST if blink else COL_NAST.darkened(0.5)
		return COL_UTW_M if str(r.get("kind", "P")) == "M" else COL_UTW_P
	if inter.tab.has(sid):
		return COL_ZAMK.darkened(0.3)
	return COL_TOR


func _draw_segments(blink: bool) -> void:
	for sid in layout.segments:
		var sdef: Dictionary = layout.segments[sid]
		var a := layout.pos(str(sdef["from"]))
		var b := layout.pos(str(sdef["to"]))
		var col := _seg_color(sid, blink)
		if str(sdef["kind"]) == "szlak":
			_draw_szlak(sid, a, b, col)
		else:
			draw_line(a, b, col, 4.0)
			if str(sdef["kind"]) == "tor":
				for fr in [0.333, 0.667]:
					var g := a.lerp(b, fr)
					draw_line(g + Vector2(0, -3), g + Vector2(0, 3), COL_BG, 3.0)
		if inter.closed_segs.has(sid):
			var m := (a + b) / 2.0
			draw_line(m + Vector2(-7, -7), m + Vector2(7, 7), COL_ZAMK, 2.0)
			draw_line(m + Vector2(-7, 7), m + Vector2(7, -7), COL_ZAMK, 2.0)


## Szlak z odcinkami zbliżania: groty jak w SimRail + seledynowe nazwy ISp….
func _draw_szlak(sid: String, a: Vector2, b: Vector2, col: Color) -> void:
	draw_line(a, b, col.darkened(0.2), 3.0)
	var line_end_id := str(layout.segments[sid]["from"])
	if not layout.is_line_end(line_end_id):
		line_end_id = str(layout.segments[sid]["to"])
	var le: Dictionary = layout.line_ends.get(line_end_id, {})
	var dir_in := int(le.get("dir_in", 1))
	var sig := _entry_signal_for(line_end_id)
	var d := 1.0 if dir_in > 0 else -1.0
	for i in range(3):
		var t := (i + 1.0) / 4.0
		var m := a.lerp(b, t if dir_in > 0 else 1.0 - t)
		_chevron(m, d, col.darkened(0.1), 5.0, 1.6)
		if sig != "" and i < 2:
			draw_string(_font, m + Vector2(-14, 19), "%sSp%s" % [RZYM[1 - i], sig],
				HORIZONTAL_ALIGNMENT_LEFT, -1, 8, COL_CYJAN)


func _entry_signal_for(line_end_id: String) -> String:
	if not layout.line_ends.has(line_end_id):
		return ""
	var dir_in := int(layout.line_ends[line_end_id]["dir_in"])
	var adj: Dictionary = layout.adj_e if dir_in > 0 else layout.adj_w
	for edge in adj.get(line_end_id, []):
		var s := layout.signal_at(str(edge["to"]), dir_in)
		if s != "":
			return s
	return ""


func _chevron(p: Vector2, d: float, col: Color, r: float, w: float) -> void:
	draw_line(p + Vector2(-r * d, -r), p + Vector2(r * 0.6 * d, 0), col, w)
	draw_line(p + Vector2(r * 0.6 * d, 0), p + Vector2(-r * d, r), col, w)


func _draw_switches(blink: bool) -> void:
	for wid in layout.switches:
		var w: Dictionary = layout.switches[wid]
		var p := layout.pos(str(w["point"]))
		var pos_txt := str(inter.sw_pos.get(wid, "+"))
		var col := COL_CYJAN
		if inter.sw_failed.has(wid):
			col = COL_ZAMK if blink else COL_ZAMK.darkened(0.5)
		elif inter.sw_moving.has(wid):
			col = COL_NAST if blink else COL_NAST.darkened(0.5)
		elif inter.sw_locked.has(wid):
			col = COL_UTW_P
		draw_string(_font, p + Vector2(-15, -7), wid, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, col)
		draw_string(_font, p + Vector2(5, -10), pos_txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 10,
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
		draw_string(_font, m + Vector2(-4, -7), nr, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, COL_NR)


func _draw_line_ends(blink: bool) -> void:
	for lid in layout.line_end_order:
		var le: Dictionary = layout.line_ends[lid]
		var p := layout.pos(lid)
		var na_zachodzie := int(le["dir_in"]) > 0
		var out := -1.0 if na_zachodzie else 1.0
		var r := _line_end_rect(lid)
		draw_rect(r, Color("2a2a2a"))
		draw_rect(r, COL_TOR, false, 1.5)
		draw_string(_font, r.position + Vector2(6, 20), lid, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, COL_NR)
		if str(le["tor"]) != "":
			draw_string(_font, r.position + Vector2(r.size.x - 16.0, 20), str(le["tor"]),
				HORIZONTAL_ALIGNMENT_LEFT, -1, 11, COL_ZOLTY)
		# nazwa kierunku NAD kasetką szlaku (nie koliduje z kasetką pociągu)
		var nazwa := "%s %s" % [str(le["name"]), str(le["lk"])]
		draw_string(_font, r.position + Vector2(-4, -8), nazwa,
			HORIZONTAL_ALIGNMENT_LEFT, -1, 10, COL_OPIS)
		# czerwona kasetka z numerem oczekującego pociągu (jak w SimRail)
		var q: Array = sim.queues.get(lid, [])
		if not q.is_empty():
			var t: Train = sim.trains.get(int(q[0]))
			var nr_txt := t.nr if t != null else "?"
			if q.size() > 1:
				nr_txt += " +%d" % (q.size() - 1)
			var box := Rect2(p + Vector2(out * 48.0 - 44.0, 46.0), Vector2(96, 30))
			draw_rect(box, COL_KASETA if blink else COL_KASETA.darkened(0.25))
			draw_rect(box, Color("d8d8d8"), false, 1.0)
			draw_string(_font, box.position + Vector2(8, 21), nr_txt,
				HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color("ffffff"))
		if str(sim.selected.get("kind", "")) == "line_end" and str(sim.selected.get("id", "")) == lid:
			draw_rect(r.grow(4.0), COL_SEL, false, 2.0)


func _draw_tarcze() -> void:
	for to in layout.tarcze_ostrz:
		var p := Vector2(float(to["x"]), float(to["y"]))
		var d := 1.0 if p.x < layout.bounds.get_center().x else -1.0
		_chevron(p + Vector2(-4 * d, 0), d, COL_TOR, 6.0, 1.6)
		_chevron(p + Vector2(5 * d, 0), d, COL_TOR, 6.0, 1.6)
		draw_string(_font, p + Vector2(-14, 22), str(to["id"]), HORIZONTAL_ALIGNMENT_LEFT, -1, 10, COL_ZOLTY)


func _draw_signals(blink: bool) -> void:
	for sid in layout.signals:
		var sg: Dictionary = layout.signals[sid]
		var p := _sig_pos(sg)
		var base := layout.pos(str(sg["point"]))
		draw_line(base, p, Color("505050"), 1.0)
		var a := inter.aspect(sid)
		var col := CHEV_STOP
		match a:
			Interlocking.ASPECT_JAZDA:
				col = CHEV_GO
			Interlocking.ASPECT_MANEWR:
				col = CHEV_MAN
			Interlocking.ASPECT_SZ:
				col = CHEV_MAN if blink else Color("484848")
		var d := 1.0 if int(sg["dir"]) > 0 else -1.0
		if str(sg["typ"]) == "manewrowy":
			draw_rect(Rect2(p - Vector2(9, 8), Vector2(18, 16)), Color("1c1c1c"))
			draw_rect(Rect2(p - Vector2(9, 8), Vector2(18, 16)), col, false, 1.5)
			_chevron(p + Vector2(-1 * d, 0), d, col, 5.0, 2.0)
		else:
			draw_line(p + Vector2(-13 * d, -7), p + Vector2(-13 * d, 7), col, 2.0)
			_chevron(p + Vector2(-5 * d, 0), d, col, 7.0, 2.4)
			_chevron(p + Vector2(5 * d, 0), d, col, 7.0, 2.4)
		if inter.is_signal_failed(sid):
			draw_line(p + Vector2(-10, -9), p + Vector2(10, 9), COL_ZAMK, 2.0)
			draw_line(p + Vector2(-10, 9), p + Vector2(10, -9), COL_ZAMK, 2.0)
		if inter.tab.has(sid):
			draw_rect(Rect2(p + Vector2(-12, -11), Vector2(24, 22)), COL_ZAMK, false, 1.5)
		if sim.pending_start == sid:
			draw_arc(p, 14.0, 0, TAU, 28, COL_SEL, 2.5)
		elif str(sim.selected.get("kind", "")) == "signal" and str(sim.selected.get("id", "")) == sid:
			draw_arc(p, 14.0, 0, TAU, 28, COL_SEL.darkened(0.45), 1.5)
		var off := Vector2(-7, 30) if int(sg["dir"]) > 0 else Vector2(-7, -22)
		draw_string(_font, p + off, sid, HORIZONTAL_ALIGNMENT_LEFT, -1, 12,
			COL_SEL if sim.pending_start == sid else COL_ZOLTY)


func _draw_trains(blink: bool) -> void:
	for t: Train in sim.trains.values():
		if t.state == Train.State.OCZEKUJE or t.state == Train.State.ZAKONCZONY:
			continue
		var body := t.body_points()
		if body.size() >= 2:
			var dirv := body[body.size() - 1] - body[0]
			var d := 1.0 if dirv.x >= 0.0 else -1.0
			for i in range(body.size() - 1):
				var m := (body[i] + body[i + 1]) / 2.0
				_chevron(m, d, Color("ff8080"), 5.0, 2.0)
		var head := t.head_pos()
		var box := Rect2(head + Vector2(-34, -46), Vector2(84, 26))
		draw_rect(box, COL_KASETA)
		var border := Color("d8d8d8")
		if t.state == Train.State.GOTOWY and blink:
			border = CHEV_GO
		elif t.stop_reason != "":
			border = COL_ZAMK
		draw_rect(box, border, false, 1.2)
		draw_string(_font, box.position + Vector2(6, 18), t.nr,
			HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color("ffffff"))
		if t.state == Train.State.GOTOWY:
			draw_string(_font, box.position + Vector2(2, 40), "GOTÓW", HORIZONTAL_ALIGNMENT_LEFT, -1, 9, CHEV_GO)
		elif t.stop_reason != "":
			draw_string(_font, box.position + Vector2(2, 40), t.stop_reason.to_upper(),
				HORIZONTAL_ALIGNMENT_LEFT, -1, 9, COL_ZAMK)
