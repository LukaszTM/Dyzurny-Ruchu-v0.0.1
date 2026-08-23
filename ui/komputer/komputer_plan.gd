class_name KomputerPlan
extends Control
## Ciemny plan synoptyczny komputerowych urządzeń nastawczych — konwencja
## barw wg docs/systemy/14 §2: tor wolny szary, zajęty czerwony, droga
## przebiegu zielona, zwrotnica w ruchu/bez kontroli miga, semafor
## czerwony/zielony, Sz biały migający. Geometrię bierze z tych samych
## kafelków `panel` co pulpit (dane, nie kod — CLAUDE.md zasada 4).

## Klik w semafor na planie (wybór początku drogi — docs/14 §3).
signal signal_clicked(signal_id: StringName)
## Akcja przycisku modułu ("polecenie:arg[:arg2]" jak na pulpicie).
signal action_requested(action: String)

const TILE: float = 48.0
const FRAME: float = 14.0

# Paleta CBI (docs/14 §2 [DO WERYFIKACJI] — robocza).
const COL_BG := Color("060708")
const COL_GRID := Color("111317")
const COL_FREE := Color("5b626c")
const COL_ROUTE := Color("35d45e")
const COL_OCCUPIED := Color("f04438")
const COL_LEG_OFF := Color("363b42")
const COL_TEXT := Color("a9b0ba")
const COL_TEXT_DIM := Color("6b7280")
const COL_BOX := Color("1b1f26")
const COL_BOX_EDGE := Color("2c323b")
const COL_WHITE := Color("f2f4f7")
const COL_LAMP_DARK := Color("2a2e35")
const COL_BUTTON := Color("262c35")

const TRACK_W: float = 9.0
## Wcięcie segmentu na granicy odcinków (kanciasta „kreska" planu SCS).
const SECTION_NOTCH: float = 2.5
## Kafelki rysujące tor poziomy (do wykrywania granic odcinków).
const H_TRACK_TILES: Array[String] = [
	"track_h", "signal_e", "signal_w", "insulation_gap",
	"turnout_ne", "turnout_nw",
]

var _tiles: Array[Dictionary] = []
var _grid: Vector2i = Vector2i.ZERO
var _graph: TrackGraph = null
var _interlocking: Interlocking = null
var _blocks: Dictionary = {}
var _world: SimWorld = null
var _blink_on: bool = true
## Strefy kliknięć: {"center": Vector2, "r": float, "action"/"signal": ...}.
var _hotspots: Array[Dictionary] = []
## Sekcja toru poziomego per pole siatki (granice odcinków na planie).
var _section_at: Dictionary = {}


func build(station: StationData, interlocking: Interlocking,
		blocks: Dictionary, world: SimWorld) -> void:
	_graph = station.graph
	_interlocking = interlocking
	_blocks = blocks
	_world = world
	_tiles.clear()
	_section_at.clear()
	for tile_variant: Variant in (station.panel.get("tiles", []) as Array):
		var tile: Dictionary = tile_variant
		_tiles.append(tile)
		if H_TRACK_TILES.has(String(tile.get("tile", ""))):
			var xy: Array = tile.get("xy", [0, 0])
			_section_at[Vector2i(int(xy[0]), int(xy[1]))] = \
				String(tile.get("section", ""))
	var grid: Array = station.panel.get("grid", [8, 4])
	_grid = Vector2i(int(grid[0]), int(grid[1]))
	custom_minimum_size = Vector2(
		_grid.x * TILE + 2.0 * FRAME, _grid.y * TILE + 2.0 * FRAME
	)
	queue_redraw()


func refresh() -> void:
	queue_redraw()


func _process(_delta: float) -> void:
	var phase_on := fmod(Time.get_ticks_msec() / 1000.0, 1.0) < 0.5
	if phase_on != _blink_on:
		_blink_on = phase_on
		queue_redraw()


func _gui_input(event: InputEvent) -> void:
	var click := event as InputEventMouseButton
	if click == null or not click.pressed or click.button_index != MOUSE_BUTTON_LEFT:
		return
	for spot: Dictionary in _hotspots:
		if click.position.distance_to(spot["center"]) <= float(spot["r"]):
			accept_event()
			if spot.has("signal"):
				signal_clicked.emit(StringName(String(spot["signal"])))
			else:
				action_requested.emit(String(spot["action"]))
			return


func _draw() -> void:
	# Czarne zobrazowanie bez siatki (Ie-104): widać tylko elementy planu.
	_hotspots.clear()
	draw_rect(Rect2(Vector2.ZERO, size), COL_BG)
	for tile: Dictionary in _tiles:
		_draw_tile(tile)


func _origin(tile: Dictionary) -> Vector2:
	var xy: Array = tile.get("xy", [0, 0])
	return Vector2(FRAME + int(xy[0]) * TILE, FRAME + int(xy[1]) * TILE)


func _draw_tile(tile: Dictionary) -> void:
	var o := _origin(tile)
	var c := o + Vector2(TILE / 2.0, TILE / 2.0)
	var color := _section_color(StringName(String(tile.get("section", ""))))
	match String(tile.get("tile", "")):
		"track_h":
			_draw_h_segment(tile, o, color)
			_draw_tile_text(o + Vector2(0, 10), TILE, String(tile.get("label", "")))
		"track_diag_ne":
			draw_line(o + Vector2(0, TILE), o + Vector2(TILE, 0), color, TRACK_W)
		"track_diag_nw":
			draw_line(o, o + Vector2(TILE, TILE), color, TRACK_W)
		"track_curve_se":
			_draw_curve(o + Vector2(0, TILE), c, o + Vector2(TILE, 24), color)
		"track_curve_sw":
			_draw_curve(o + Vector2(TILE, TILE), c, o + Vector2(0, 24), color)
		"insulation_gap":
			draw_rect(Rect2(o.x, o.y + 24.0 - TRACK_W / 2.0, 20.0, TRACK_W), color)
			draw_rect(Rect2(o.x + 28.0, o.y + 24.0 - TRACK_W / 2.0,
				TILE - 28.0, TRACK_W), color)
			draw_line(o + Vector2(24, 16), o + Vector2(24, 32), COL_TEXT_DIM, 2.0)
		"turnout_ne":
			_draw_turnout(tile, o, true)
		"turnout_nw":
			_draw_turnout(tile, o, false)
		"signal_e":
			_draw_signal(tile, o, true)
		"signal_w":
			_draw_signal(tile, o, false)
		"label":
			_draw_tile_text(o + Vector2(0, 28), TILE, String(tile.get("text", "")))
		"block_field":
			_draw_block_field(tile, o)
		"crossing_ctrl":
			_draw_crossing(tile, o)
		"ssp_ctrl":
			_draw_ssp(tile, o)
		"dsat_ctrl":
			_draw_dsat(tile, o)
		"counter_button":
			_draw_counter_button(tile, o)
		"button":
			_draw_small_button(tile, o)


## Kanciasty segment toru poziomego (styl planu SCS): prostokąt z wcięciem
## na granicy odcinków — sąsiad o innej sekcji = przerwa w pasie.
func _draw_h_segment(tile: Dictionary, o: Vector2, color: Color) -> void:
	var xy: Array = tile.get("xy", [0, 0])
	var cell := Vector2i(int(xy[0]), int(xy[1]))
	var my_section := String(tile.get("section", ""))
	var inset_l := 0.0
	var inset_r := 0.0
	var left: Variant = _section_at.get(cell + Vector2i(-1, 0))
	var right: Variant = _section_at.get(cell + Vector2i(1, 0))
	if left != null and String(left) != my_section:
		inset_l = SECTION_NOTCH
	if right != null and String(right) != my_section:
		inset_r = SECTION_NOTCH
	draw_rect(Rect2(o.x + inset_l, o.y + 24.0 - TRACK_W / 2.0,
		TILE - inset_l - inset_r, TRACK_W), color)


## Kolor toru wg stanu sekcji (docs/14 §2); poświata dla zajętości.
func _section_color(section_id: StringName) -> Color:
	if section_id == &"" or _graph == null:
		return COL_FREE
	var section := _graph.get_section(section_id)
	if section == null:
		return COL_FREE
	if section.occupied:
		return COL_OCCUPIED
	if section.is_locked():
		return COL_ROUTE
	return COL_FREE


func _draw_curve(from_point: Vector2, control: Vector2, to_point: Vector2,
		color: Color) -> void:
	var points := PackedVector2Array()
	for i: int in 17:
		var t := float(i) / 16.0
		var a := from_point.lerp(control, t)
		var b := control.lerp(to_point, t)
		points.append(a.lerp(b, t))
	draw_polyline(points, color, TRACK_W)


## Zwrotnica wg konwencji Ie-104: położenie pokazuje CIĄGŁOŚĆ drogi —
## noga niepołożona jest szara i ODSUNIĘTA od krzyżownicy (przerwa);
## w ruchu / bez kontroli symbol miga.
func _draw_turnout(tile: Dictionary, o: Vector2, branch_ne: bool) -> void:
	var section_color := _section_color(StringName(String(tile.get("section", ""))))
	var turnout := _graph.get_turnout(StringName(String(tile.get("turnout", ""))))
	var corner := o + (Vector2(TILE, 0) if branch_ne else Vector2.ZERO)
	var center := o + Vector2(24.0, 24.0)
	var half := TRACK_W / 2.0
	var is_minus := turnout != null and turnout.is_minus()
	var no_control := turnout != null and not turnout.has_control()
	var blink_color := COL_OCCUPIED if _blink_on else COL_LAMP_DARK
	# Kierunek jazdy w bok: dla NE odgałęzienie odchodzi w prawo-górę,
	# więc przy MINUS przerwę dostaje prawa połowa toru prostego (i odwrotnie).
	var branch_side_right := branch_ne
	var straight_l := Rect2(o.x, o.y + 24.0 - half, 24.0, TRACK_W)
	var straight_r := Rect2(o.x + 24.0, o.y + 24.0 - half, 24.0, TRACK_W)
	var gap := 7.0
	if is_minus:
		if branch_side_right:
			straight_r.position.x += gap
			straight_r.size.x -= gap
		else:
			straight_l.size.x -= gap
	var straight_color := blink_color if no_control else section_color
	var off_color := blink_color if no_control else COL_LEG_OFF
	draw_rect(straight_l, straight_color if not (is_minus and not branch_side_right) \
		else off_color)
	draw_rect(straight_r, straight_color if not (is_minus and branch_side_right) \
		else off_color)
	# Odgałęzienie: położone = od krzyżownicy, niepołożone = z przerwą.
	var branch_start := center
	var branch_color := straight_color if is_minus else off_color
	if no_control:
		branch_color = blink_color
	if not is_minus:
		branch_start = center.lerp(corner, 0.25)
	draw_line(branch_start, corner, branch_color, TRACK_W)
	# Numer zwrotnicy drobnym tekstem obok krzyżownicy (bez ramki).
	var label_pos := o + (Vector2(2.0, 44.0) if branch_ne else Vector2(32.0, 44.0))
	_draw_text(label_pos, 14.0, String(tile.get("label", "")), COL_TEXT_DIM)
	# Klik w zwrotnicę = przestawienie (mapowanie akcji z JSON).
	_register_press(tile, center, 14.0)


func _draw_signal(tile: Dictionary, o: Vector2, travel_east: bool) -> void:
	_draw_h_segment(tile, o, _section_color(StringName(String(tile.get("section", "")))))
	var signal_id := StringName(String(tile.get("signal", "")))
	var signal_device := _graph.get_signal(signal_id)
	var head := o + Vector2(28.0, 38.0) if travel_east else o + Vector2(20.0, 10.0)
	var color := COL_LAMP_DARK
	if signal_device != null:
		if signal_device.aspect == &"Sz":
			color = COL_WHITE if _blink_on else COL_LAMP_DARK
		elif signal_device.shows_stop():
			color = COL_OCCUPIED
		else:
			color = COL_ROUTE
	# Goły symbol Ie-104: maszt prostopadły od toru + okrągła głowica;
	# zgaszony = sam szary pierścień, litera drobnym tekstem obok.
	var mast_x := head.x - 11.0 if travel_east else head.x + 11.0
	draw_line(Vector2(mast_x, o.y + 24.0), Vector2(mast_x, head.y), COL_FREE, 2.0)
	draw_line(Vector2(mast_x, head.y), Vector2(head.x - 6.0 if travel_east \
		else head.x + 6.0, head.y), COL_FREE, 2.0)
	if color == COL_LAMP_DARK:
		draw_arc(head, 5.5, 0.0, TAU, 20, COL_FREE, 2.0)
	else:
		draw_circle(head, 5.5, color)
		draw_arc(head, 6.0, 0.0, TAU, 20, COL_FREE, 1.5)
	var letter_y := 50.0 if travel_east else 8.0
	var letter_x := -12.0 if travel_east else 12.0
	_draw_text(o + Vector2(letter_x, letter_y), TILE, String(signal_id), COL_TEXT_DIM)
	_hotspots.append({"center": head, "r": 12.0, "signal": String(signal_id)})


func _draw_box(o: Vector2, cells_w: float, cells_h: float, title: String) -> Rect2:
	var rect := Rect2(o + Vector2(3, 3), Vector2(cells_w * TILE - 6, cells_h * TILE - 6))
	draw_rect(rect, COL_BOX)
	draw_rect(rect, COL_BOX_EDGE, false, 1.5)
	_draw_text(o + Vector2(8, 17), cells_w * TILE - 16, title, COL_TEXT)
	return rect


func _draw_lamp(center: Vector2, color: Color, label: String = "") -> void:
	draw_circle(center, 5.5, color)
	draw_arc(center, 6.0, 0.0, TAU, 18, COL_BOX_EDGE, 1.5)
	if not label.is_empty():
		_draw_text(center + Vector2(-22.0, 16.0), 44.0, label, COL_TEXT_DIM)


func _draw_plan_button(tile: Dictionary, center: Vector2, action: String,
		label: String) -> void:
	draw_circle(center, 8.0, COL_BUTTON)
	draw_arc(center, 8.0, 0.0, TAU, 20, COL_TEXT_DIM, 1.5)
	if not label.is_empty():
		_draw_text(center + Vector2(-22.0, 19.0), 44.0, label, COL_TEXT_DIM)
	if not action.is_empty():
		_hotspots.append({"center": center, "r": 11.0, "action": action})
	else:
		_register_press(tile, center, 11.0)


func _register_press(tile: Dictionary, center: Vector2, radius: float) -> void:
	var actions: Dictionary = {}
	if tile.has("button"):
		actions = (tile["button"] as Dictionary).get("actions", {})
	elif tile.has("actions"):
		actions = tile["actions"]
	var press := String(actions.get("press", ""))
	if not press.is_empty():
		_hotspots.append({"center": center, "r": radius, "action": press})


func _draw_block_field(tile: Dictionary, o: Vector2) -> void:
	_draw_box(o, 3, 2, String(tile.get("label", "")))
	var block: BlockLine = _blocks.get(StringName(String(tile.get("block", ""))))
	var occupied := COL_LAMP_DARK
	var po := COL_LAMP_DARK
	var permission := COL_LAMP_DARK
	if block != null:
		if block.occupied:
			occupied = COL_OCCUPIED
		if block.po_locked:
			po = COL_WHITE
		if block.permission_at == BlockLine.BlockSide.PLAYER:
			permission = COL_ROUTE
	var block_id := String(tile.get("block", ""))
	var lamp_x: Array[float] = [30.0, 72.0, 114.0]
	var colors: Array[Color] = [occupied, po, permission]
	var labels: Array[String] = ["odstęp", "Po", "pozw."]
	for i: int in 3:
		_draw_lamp(o + Vector2(lamp_x[i], 34.0), colors[i], labels[i])
	for field: String in ["Po", "Ko", "Poz"]:
		var idx := ["Po", "Ko", "Poz"].find(field)
		_draw_plan_button(tile, o + Vector2(lamp_x[idx], 72.0),
			"block_press:%s:%s" % [block_id, field], field)


func _draw_crossing(tile: Dictionary, o: Vector2) -> void:
	_draw_box(o, 3, 2, String(tile.get("label", "")))
	var crossing: LevelCrossing = null
	if _world != null:
		crossing = _world.crossings.get(StringName(String(tile.get("crossing", ""))))
	var lamp := COL_LAMP_DARK
	var state_name := "?"
	if crossing != null:
		state_name = LevelCrossing.STATE_NAMES[crossing.state]
		match crossing.state:
			LevelCrossing.State.CLOSED:
				lamp = COL_WHITE
			LevelCrossing.State.CLOSING, LevelCrossing.State.OPENING:
				lamp = COL_WHITE if _blink_on else COL_LAMP_DARK
			LevelCrossing.State.FAILURE:
				lamp = COL_OCCUPIED if _blink_on else COL_LAMP_DARK
	_draw_lamp(o + Vector2(72.0, 34.0), lamp)
	_draw_text(o + Vector2(8.0, 53.0), 128.0, state_name, COL_TEXT_DIM)
	var crossing_id := String(tile.get("crossing", ""))
	_draw_plan_button(tile, o + Vector2(48.0, 72.0),
		"crossing_close:%s" % crossing_id, "Zamk")
	_draw_plan_button(tile, o + Vector2(96.0, 72.0),
		"crossing_open:%s" % crossing_id, "Otw")


func _draw_ssp(tile: Dictionary, o: Vector2) -> void:
	_draw_box(o, 3, 2, String(tile.get("label", "")))
	var crossing: LevelCrossing = null
	if _world != null:
		crossing = _world.crossings.get(StringName(String(tile.get("crossing", ""))))
	var ok := COL_LAMP_DARK
	var active := COL_LAMP_DARK
	var fail := COL_LAMP_DARK
	if crossing != null:
		if crossing.state == LevelCrossing.State.FAILURE:
			fail = COL_OCCUPIED if _blink_on else COL_LAMP_DARK
		else:
			ok = COL_ROUTE
			if crossing.state != LevelCrossing.State.OPEN:
				active = COL_WHITE
	var lamp_x: Array[float] = [30.0, 72.0, 114.0]
	var colors: Array[Color] = [ok, active, fail]
	var labels: Array[String] = ["sprawna", "załącz.", "awaria"]
	for i: int in 3:
		_draw_lamp(o + Vector2(lamp_x[i], 44.0), colors[i], labels[i])


func _draw_dsat(tile: Dictionary, o: Vector2) -> void:
	_draw_box(o, 3, 2, String(tile.get("label", "")))
	var alarm := _world != null and _world.dsat_unacked()
	var lamp := (COL_OCCUPIED if _blink_on else COL_LAMP_DARK) if alarm else COL_LAMP_DARK
	_draw_lamp(o + Vector2(72.0, 36.0), lamp)
	_draw_plan_button(tile, o + Vector2(72.0, 72.0), "dsat_ack", "KWIT")


func _draw_counter_button(tile: Dictionary, o: Vector2) -> void:
	_draw_box(o, 1, 2, "")
	_draw_text(o + Vector2(0.0, 16.0), TILE, String(tile.get("label", "")), COL_TEXT)
	_draw_plan_button(tile, o + Vector2(24.0, 38.0), "", "")
	if bool(tile.get("counter", false)):
		draw_rect(Rect2(o + Vector2(10.0, 60.0), Vector2(28.0, 15.0)), Color("0c0e11"))
		_draw_text_center(o + Vector2(10.0, 72.0), 28.0,
			"%03d" % _counter_value(tile), COL_WHITE)


func _draw_small_button(tile: Dictionary, o: Vector2) -> void:
	_draw_text(o + Vector2(0.0, 12.0), TILE, String(tile.get("label", "")), COL_TEXT_DIM)
	_draw_plan_button(tile, o + Vector2(24.0, 32.0), "", "")


func _counter_value(tile: Dictionary) -> int:
	if _interlocking == null:
		return 0
	var actions: Dictionary = {}
	if tile.has("button"):
		actions = (tile["button"] as Dictionary).get("actions", {})
	var press := String(actions.get("press", ""))
	if press.begins_with("sub_signal:"):
		return int(_interlocking.counters.get("dSz:%s" % press.get_slice(":", 1), 0))
	if press.begins_with("route_emergency_release"):
		return int(_interlocking.counters.get("dZw", 0))
	return 0


func _draw_tile_text(pos: Vector2, width: float, text: String) -> void:
	_draw_text(pos, width, text, COL_TEXT)


func _draw_text(pos: Vector2, width: float, text: String, color: Color) -> void:
	if text.is_empty():
		return
	draw_string(ThemeDB.fallback_font, pos, text, HORIZONTAL_ALIGNMENT_CENTER,
		width, 10, color)


func _draw_text_center(pos: Vector2, width: float, text: String, color: Color) -> void:
	draw_string(ThemeDB.fallback_font, pos, text, HORIZONTAL_ALIGNMENT_CENTER,
		width, 10, color)
