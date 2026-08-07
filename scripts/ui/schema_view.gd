class_name SchemaView
extends Node2D
## Pulpit nastawczy — schematyczny obraz stacji w stylu rzeczywistych
## systemów zdalnego sterowania (odcinki: szary=wolny, zielony=przebieg
## pociągowy, biały=przebieg manewrowy, czerwony=zajęty, pomarańczowy=
## zamknięty). Obsługa klikania semaforów/portali oraz pan i zoom kamery.

const COL_BG := Color("10161d")
const COL_FREE := Color("48566a")
const COL_ROUTE := Color("37d67a")
const COL_SHUNT := Color("e8e8e8")
const COL_OCCUPIED := Color("e5484d")
const COL_CLOSED := Color("f59e0b")
const COL_PLATFORM := Color("2a3442")
const COL_TEXT := Color("9aa7b8")
const COL_SELECT := Color("22d3ee")

const CAT_COLORS := {
	"SKM": Color("35b558"),
	"KM": Color("7cb342"),
	"IC": Color("1d4ed8"),
	"EIP": Color("6d28d9"),
	"TLK": Color("0891b2"),
	"TME": Color("8d6e63"),
	"MAN": Color("f59e0b"),
}

var sim = null
var layout: StationLayout
var inter: Interlocking
var cam: Camera2D
var _dragging := false
var _font: Font


func setup(p_sim) -> void:
	sim = p_sim
	layout = sim.layout
	inter = sim.inter
	_font = ThemeDB.fallback_font
	cam = Camera2D.new()
	cam.position = Vector2(700, 340)
	cam.zoom = Vector2(0.85, 0.85)
	add_child(cam)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb: InputEventMouseButton = event
		if mb.button_index == MOUSE_BUTTON_WHEEL_UP and mb.pressed:
			_zoom_by(1.12)
		elif mb.button_index == MOUSE_BUTTON_WHEEL_DOWN and mb.pressed:
			_zoom_by(1.0 / 1.12)
		elif mb.button_index in [MOUSE_BUTTON_RIGHT, MOUSE_BUTTON_MIDDLE]:
			_dragging = mb.pressed
		elif mb.button_index == MOUSE_BUTTON_LEFT and mb.pressed:
			_handle_click(get_global_mouse_position())
	elif event is InputEventMouseMotion and _dragging:
		var mm: InputEventMouseMotion = event
		cam.position -= mm.relative / cam.zoom.x


func _zoom_by(f: float) -> void:
	var z := clampf(cam.zoom.x * f, 0.35, 3.0)
	cam.zoom = Vector2(z, z)


func _handle_click(world: Vector2) -> void:
	# 1) semafory
	var best_sig := ""
	var best_d := 18.0
	for sid in layout.signals:
		var p := _signal_pos(layout.signals[sid])
		var d := p.distance_to(world)
		if d < best_d:
			best_d = d
			best_sig = sid
	if best_sig != "":
		sim.on_schema_click("signal", best_sig)
		return
	# 2) portale
	for pid in layout.portals:
		if _portal_rect(pid).has_point(world):
			sim.on_schema_click("portal", pid)
			return
	# 3) pociągi
	for t in sim.trains.values():
		if t.state == Train.State.WAITING or t.state == Train.State.DONE:
			continue
		if t.head_pos().distance_to(world) < 26.0:
			sim.on_schema_click("train", str(t.id))
			return
	sim.on_schema_click("none", "")


func _signal_pos(sig: Dictionary) -> Vector2:
	var base: Vector2 = layout.pos(sig["point"])
	var off := Vector2(0, 14) if sig["dir"] > 0 else Vector2(0, -14)
	return base + off


func _portal_rect(pid: String) -> Rect2:
	var p: Vector2 = layout.pos(pid)
	var outward := -1.0 if p.x < 750.0 else 1.0
	var c := p + Vector2(outward * 34.0, 0)
	return Rect2(c - Vector2(26, 15), Vector2(52, 30))


func _draw() -> void:
	if layout == null:
		return
	var blink := fmod(Time.get_ticks_msec() / 450.0, 2.0) < 1.0
	# tło
	draw_rect(Rect2(-400, -300, 2400, 1400), COL_BG)
	# perony
	for pl in layout.platforms:
		var r := Rect2(float(pl["x"]), float(pl["y"]), float(pl["w"]), float(pl["h"]))
		draw_rect(r, COL_PLATFORM)
		draw_string(_font, r.position + Vector2(8, r.size.y - 7), str(pl["name"]),
			HORIZONTAL_ALIGNMENT_LEFT, -1, 12, COL_TEXT)
	# odcinki torowe
	for sid in layout.segments:
		var sdef: Dictionary = layout.segments[sid]
		var a: Vector2 = layout.pos(sdef["from"])
		var b: Vector2 = layout.pos(sdef["to"])
		var col := COL_FREE
		if inter.closed_segs.has(sid):
			col = COL_CLOSED if blink else COL_CLOSED.darkened(0.45)
		if inter.locked_segs.has(sid):
			col = COL_SHUNT if inter.seg_route_kind(sid) == "shunt" else COL_ROUTE
		if inter.occupied_segs.has(sid):
			col = COL_OCCUPIED
		draw_line(a, b, col, 4.0)
		if inter.closed_segs.has(sid):
			var mid := (a + b) / 2.0
			draw_line(mid + Vector2(-6, -6), mid + Vector2(6, 6), COL_CLOSED, 2.0)
			draw_line(mid + Vector2(-6, 6), mid + Vector2(6, -6), COL_CLOSED, 2.0)
	# uszkodzone rozjazdy
	for pt in inter.failed_points:
		var p: Vector2 = layout.pos(pt)
		if blink:
			draw_arc(p, 9.0, 0, TAU, 20, COL_CLOSED, 2.5)
		draw_string(_font, p + Vector2(-10, -12), str(pt), HORIZONTAL_ALIGNMENT_LEFT, -1, 10, COL_CLOSED)
	# numery torów
	for nr in layout.tracks:
		var tr: Dictionary = layout.tracks[nr]
		var pa: Vector2 = layout.pos(tr["a"])
		draw_string(_font, pa + Vector2(-24, 4), str(nr), HORIZONTAL_ALIGNMENT_LEFT, -1, 13, COL_TEXT)
	# portale
	for pid in layout.portals:
		_draw_portal(pid, blink)
	# semafory
	for sid in layout.signals:
		_draw_signal(layout.signals[sid], sid, blink)
	# pociągi
	for t in sim.trains.values():
		_draw_train(t, blink)
	# etykiety
	for lb in layout.labels:
		draw_string(_font, Vector2(float(lb["x"]), float(lb["y"])), str(lb["text"]),
			HORIZONTAL_ALIGNMENT_LEFT, -1, 12, COL_TEXT.darkened(0.15))
	draw_string(_font, Vector2(60, 40), layout.station_name.to_upper(),
		HORIZONTAL_ALIGNMENT_LEFT, -1, 20, Color("d7dee8"))
	draw_string(_font, Vector2(60, 60), "LCS — pulpit nastawczy", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, COL_TEXT)


func _draw_signal(sig: Dictionary, sid: String, blink: bool) -> void:
	var p := _signal_pos(sig)
	var base: Vector2 = layout.pos(sig["point"])
	draw_line(base, p, Color("6b7686"), 1.5)
	var col := Color("d94550")
	match sig["aspect"]:
		Interlocking.ASPECT_GO:
			col = Color("2ee56b")
		Interlocking.ASPECT_SHUNT:
			col = Color("f2f2f2")
		Interlocking.ASPECT_SZ:
			col = Color("f2f2f2") if blink else Color("6b6b6b")
	if sig["shunt_only"]:
		draw_rect(Rect2(p - Vector2(5, 5), Vector2(10, 10)), Color("222b36"))
		draw_rect(Rect2(p - Vector2(5, 5), Vector2(10, 10)), col, false, 2.0)
	else:
		draw_circle(p, 6.0, Color("222b36"))
		draw_circle(p, 4.5, col)
	if sig["failed"]:
		draw_line(p + Vector2(-7, -7), p + Vector2(7, 7), COL_CLOSED, 2.0)
		draw_line(p + Vector2(-7, 7), p + Vector2(7, -7), COL_CLOSED, 2.0)
	if sim.selected_signal == sid:
		draw_arc(p, 10.0, 0, TAU, 24, COL_SELECT, 2.5)
	var lbl_off := Vector2(-8, 22) if sig["dir"] > 0 else Vector2(-8, -16)
	draw_string(_font, p + lbl_off, sid, HORIZONTAL_ALIGNMENT_LEFT, -1, 11,
		COL_SELECT if sim.selected_signal == sid else COL_TEXT)


func _draw_portal(pid: String, blink: bool) -> void:
	var portal: Dictionary = layout.portals[pid]
	var r := _portal_rect(pid)
	draw_rect(r, Color("1a222c"))
	draw_rect(r, Color("55606f"), false, 1.5)
	var arrow_dir := 1.0 if layout.pos(pid).x < 750.0 else -1.0
	var cx := r.get_center()
	draw_line(cx + Vector2(-7 * arrow_dir, 0), cx + Vector2(7 * arrow_dir, 0), COL_TEXT, 2.0)
	draw_line(cx + Vector2(7 * arrow_dir, 0), cx + Vector2(2 * arrow_dir, -4), COL_TEXT, 2.0)
	draw_line(cx + Vector2(7 * arrow_dir, 0), cx + Vector2(2 * arrow_dir, 4), COL_TEXT, 2.0)
	var name_pos := r.position + Vector2(-4, -8) if layout.pos(pid).x < 750.0 else r.position + Vector2(-40, -8)
	draw_string(_font, name_pos, str(portal["name"]), HORIZONTAL_ALIGNMENT_LEFT, -1, 10, COL_TEXT)
	# kolejka oczekujących
	var waiting: Array = sim.portal_queues.get(pid, [])
	if not waiting.is_empty():
		var first: Train = sim.trains.get(waiting[0])
		var txt := "%d ⏳" % waiting.size()
		if first != null:
			txt = "%s %s  (czeka: %d)" % [first.category, first.nr, waiting.size()]
		var col := COL_OCCUPIED if blink else COL_OCCUPIED.darkened(0.3)
		draw_string(_font, r.position + Vector2(-4, r.size.y + 16), txt,
			HORIZONTAL_ALIGNMENT_LEFT, -1, 11, col)


func _draw_train(t: Train, blink: bool) -> void:
	if t.state == Train.State.WAITING or t.state == Train.State.DONE:
		return
	var col: Color = CAT_COLORS.get(t.category, Color("cccccc"))
	var body := t.body_points()
	if body.size() >= 2:
		for i in range(body.size() - 1):
			draw_line(body[i], body[i + 1], col, 9.0)
	var head := t.head_pos()
	var lbl := "%s %s" % [t.category, t.nr]
	var lbl_pos := head + Vector2(-20, -14)
	var box := Rect2(lbl_pos + Vector2(-4, -12), Vector2(14 + lbl.length() * 7.0, 17))
	draw_rect(box, Color(0.06, 0.09, 0.12, 0.85))
	var border := col
	if t.state == Train.State.READY and blink:
		border = Color("2ee56b")
	draw_rect(box, border, false, 1.5)
	draw_string(_font, lbl_pos, lbl, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color("e8edf3"))
	if t.state == Train.State.READY:
		draw_string(_font, lbl_pos + Vector2(0, 26), "GOTÓW", HORIZONTAL_ALIGNMENT_LEFT, -1, 9, Color("2ee56b"))
	elif t.stop_reason != "" and t.state == Train.State.MOVING:
		draw_string(_font, lbl_pos + Vector2(0, 26), "AWARIA", HORIZONTAL_ALIGNMENT_LEFT, -1, 9, COL_CLOSED)
