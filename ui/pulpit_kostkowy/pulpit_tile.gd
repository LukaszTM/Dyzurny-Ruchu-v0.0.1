class_name PulpitTile
extends Control
## Jedna kostka pulpitu przekaźnikowego — rysowanie wg
## assets-spec/20-pulpit-kostkowy-wyglad.md, zachowanie wg docs/systemy/13.
## Kafelek tylko czyta stan rdzenia (TrackGraph) i emituje akcje przycisków;
## tło kostek i fugi rysuje PulpitView.

signal button_activated(action: String)

const TILE: float = 48.0

## Paleta z assets-spec/20 §2 (robocza, do strojenia).
const COL_TRACK := Color("1C1C1C")
const COL_LAMP_OFF := Color("8E8A80")
const COL_LAMP_RING := Color("55524A")
const COL_OCCUPIED := Color("E0362C")
const COL_LOCKED := Color("F4EFE2")
const COL_GREEN := Color("3FA34D")
const COL_TEXT := Color("2B2B2B")
const COL_BUTTON_GRAY := Color("4A4A4A")
const COL_BUTTON_SHADOW := Color("2E2E2E")
# TODO(weryfikacja): kolory główek przycisków robocze wg assets-spec/20 §4
# (zwrotnicowe szare, sygnałowe zielone, specjalne czerwone) — do weryfikacji
# ze zdjęciami pulpitów typu E.
const COL_BUTTON_GREEN := Color("3A6B45")
const COL_BUTTON_RED := Color("B03A30")
const COL_SEAL_COLLAR := Color("D9B23C")
const COL_COUNTER_BG := Color("111111")
const COL_COUNTER_DIGITS := Color("EDEDED")
const COL_PLATE := Color("EDE9DC")

const TRACK_WIDTH: float = 6.0
const BUTTON_RADIUS: float = 9.0

## Skórka fotorealistyczna (assets/pulpit/*.png): kafelek rysuje teksturę
## kostki, a na wierzchu wyłącznie elementy dynamiczne (lampki, przyciski,
## opisy). Brak pliku tekstury = dotychczasowe rysowanie wektorowe.
const TEX_DIR := "res://assets/pulpit"
static var _tex_cache: Dictionary = {}


static func skin_texture(name: String) -> Texture2D:
	if _tex_cache.has(name):
		return _tex_cache[name]
	var path := "%s/%s.png" % [TEX_DIR, name]
	var tex: Texture2D = load(path) if ResourceLoader.exists(path) else null
	_tex_cache[name] = tex
	return tex


## Tekstura rozciągnięta na cały kafelek; false = brak skórki (fallback).
func _draw_tile_tex(name: String) -> bool:
	var tex := skin_texture(name)
	if tex == null:
		return false
	draw_texture_rect(tex, Rect2(Vector2.ZERO, size), false)
	return true


## Lampka stanu jako PNG (plakietka z kloszem) albo wektorowo (fallback).
func _draw_state_lamp(center: Vector2, color: Color, radius: float = 7.0) -> void:
	var tex := skin_texture(_lamp_tex_name(color))
	if tex == null:
		draw_circle(center, radius + 1.5, COL_LAMP_RING)
		draw_circle(center, radius, color)
		return
	if color == COL_OCCUPIED:
		draw_circle(center, radius * 2.0, Color(COL_OCCUPIED, 0.18))
	var side := radius * 3.4
	draw_texture_rect(tex, Rect2(center - Vector2(side, side) / 2.0,
		Vector2(side, side)), false)


func _lamp_tex_name(color: Color) -> String:
	if color == COL_OCCUPIED:
		return "lamp_red"
	if color == COL_GREEN:
		return "lamp_green"
	if color == COL_LOCKED:
		return "lamp_white"
	return "lamp_off"

var tile_def: Dictionary = {}
var graph: TrackGraph = null
var interlocking: Interlocking = null
## Blokady liniowe (StringName -> BlockLine) — dla pól block_field.
var blocks: Dictionary = {}
## Świat symulacji — dla kafelków przejazdów i dSAT (tylko odczyt stanu).
var world: SimWorld = null
## Faza migania 1 Hz (50% duty) — ustawia PulpitView.
var blink_on: bool = true

var _tile_type: String = ""
var _section_id: StringName = &""
var _turnout_id: StringName = &""
var _signal_id: StringName = &""
var _press_action: String = ""
var _pull_action: String = ""


func setup(def: Dictionary, p_graph: TrackGraph, p_interlocking: Interlocking = null,
		p_blocks: Dictionary = {}, p_world: SimWorld = null) -> void:
	tile_def = def
	graph = p_graph
	interlocking = p_interlocking
	blocks = p_blocks
	world = p_world
	_tile_type = String(def.get("tile", ""))
	_section_id = StringName(String(def.get("section", "")))
	_turnout_id = StringName(String(def.get("turnout", "")))
	_signal_id = StringName(String(def.get("signal", "")))
	# Mapowanie przycisk→akcja per stacja w JSON (docs/systemy/13 §6).
	# Naciśnięcie = LPM, pociągnięcie = PPM (docs/systemy/13 §6: klik prawym).
	# TODO(weryfikacja): mapowanie naciśnij/pociągnij per typ przycisku.
	var actions: Dictionary = {}
	if def.has("button"):
		actions = (def["button"] as Dictionary).get("actions", {})
	elif def.has("actions"):
		actions = def["actions"]
	_press_action = String(actions.get("press", ""))
	_pull_action = String(actions.get("pull", ""))
	var cells := _cells()
	custom_minimum_size = Vector2(TILE * cells.x, TILE * cells.y)
	size = custom_minimum_size
	if not _press_action.is_empty() or _tile_type == "block_field":
		mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND


## Rozmiar kafelka w kostkach (pola blokad i przyciski licznikowe są większe).
func _cells() -> Vector2i:
	match _tile_type:
		"block_field", "crossing_ctrl", "ssp_ctrl", "dsat_ctrl":
			return Vector2i(3, 2)
		"counter_button":
			return Vector2i(1, 2)
	return Vector2i(1, 1)


## Kafelki wieloprzyciskowe: mapa akcja → środek przycisku.
func _multi_buttons() -> Dictionary:
	match _tile_type:
		"block_field":
			var block_id := String(tile_def.get("block", ""))
			return {
				"block_press:%s:Po" % block_id: Vector2(30.0, 70.0),
				"block_press:%s:Ko" % block_id: Vector2(72.0, 70.0),
				"block_press:%s:Poz" % block_id: Vector2(114.0, 70.0),
			}
		"crossing_ctrl":
			var crossing_id := String(tile_def.get("crossing", ""))
			return {
				"crossing_close:%s" % crossing_id: Vector2(48.0, 70.0),
				"crossing_open:%s" % crossing_id: Vector2(96.0, 70.0),
			}
		"dsat_ctrl":
			return {"dsat_ack": Vector2(72.0, 70.0)}
	return {}


func _gui_input(event: InputEvent) -> void:
	var click := event as InputEventMouseButton
	if click == null or not click.pressed:
		return
	var multi := _multi_buttons()
	if not multi.is_empty():
		if click.button_index != MOUSE_BUTTON_LEFT:
			return
		for multi_action: String in multi:
			if click.position.distance_to(multi[multi_action]) <= 12.0:
				accept_event()
				button_activated.emit(multi_action)
				return
		return
	var action := ""
	if click.button_index == MOUSE_BUTTON_LEFT:
		action = _press_action
	elif click.button_index == MOUSE_BUTTON_RIGHT:
		action = _pull_action
	if action.is_empty():
		return
	if _button_center() != Vector2.INF \
			and click.position.distance_to(_button_center()) > BUTTON_RADIUS + 4.0:
		return
	accept_event()
	button_activated.emit(action)


## Środek przycisku na kafelku (Vector2.INF = kafelek bez przycisku).
func _button_center() -> Vector2:
	match _tile_type:
		"turnout_ne":
			return Vector2(36.0, 38.0)
		"turnout_nw":
			return Vector2(12.0, 38.0)
		"signal_e":
			return Vector2(36.0, 10.0)
		"signal_w":
			return Vector2(12.0, 38.0)
		"counter_button", "button":
			return Vector2(24.0, 34.0)
	return Vector2.INF


func _draw() -> void:
	match _tile_type:
		"track_h":
			if not _draw_tile_tex("track_h"):
				_draw_track_h()
			_draw_section_lamp(Vector2(24.0, 24.0))
			_draw_tile_label(Vector2(24.0, 12.0))
		"track_diag_ne":
			if not _draw_tile_tex("diag_ne"):
				draw_line(Vector2(0.0, TILE), Vector2(TILE, 0.0), COL_TRACK, TRACK_WIDTH)
			_draw_section_lamp_round(Vector2(24.0, 24.0))
		"track_diag_nw":
			if not _draw_tile_tex("diag_nw"):
				draw_line(Vector2(0.0, 0.0), Vector2(TILE, TILE), COL_TRACK, TRACK_WIDTH)
			_draw_section_lamp_round(Vector2(24.0, 24.0))
		"track_curve_se":
			if not _draw_tile_tex("curve_se"):
				_draw_curve(Vector2(0.0, TILE), Vector2(24.0, 24.0), Vector2(TILE, 24.0))
			_draw_section_lamp_round(Vector2(21.0, 33.0))
		"track_curve_sw":
			if not _draw_tile_tex("curve_sw"):
				_draw_curve(Vector2(TILE, TILE), Vector2(24.0, 24.0), Vector2(0.0, 24.0))
			_draw_section_lamp_round(Vector2(27.0, 33.0))
		"insulation_gap":
			if not _draw_tile_tex("insulation"):
				_draw_insulation_gap()
		"turnout_ne":
			_draw_turnout(true)
		"turnout_nw":
			_draw_turnout(false)
		"signal_e":
			_draw_signal_tile(true)
		"signal_w":
			_draw_signal_tile(false)
		"label":
			_draw_text(Vector2(0.0, 24.0), TILE, String(tile_def.get("text", "")), 11)
		"block_field":
			_draw_block_field()
		"crossing_ctrl":
			_draw_crossing_ctrl()
		"ssp_ctrl":
			_draw_ssp_ctrl()
		"dsat_ctrl":
			_draw_dsat_ctrl()
		"counter_button":
			_draw_counter_button()
		"button":
			_draw_button(Vector2(24.0, 34.0), _button_color())
			_draw_text(Vector2(0.0, 12.0), TILE, String(tile_def.get("label", "")), 9)


func _draw_track_h() -> void:
	draw_line(Vector2(0.0, 24.0), Vector2(TILE, 24.0), COL_TRACK, TRACK_WIDTH)


## Łuk 90°/45° jako krzywa Beziera (spec §3: track_curve_*).
func _draw_curve(from_point: Vector2, control: Vector2, to_point: Vector2) -> void:
	var points := PackedVector2Array()
	for i: int in 13:
		var t := float(i) / 12.0
		var a := from_point.lerp(control, t)
		var b := control.lerp(to_point, t)
		points.append(a.lerp(b, t))
	draw_polyline(points, COL_TRACK, TRACK_WIDTH)


func _draw_insulation_gap() -> void:
	# Przerwa izolacyjna: przerwana linia toru + małe poprzeczki (spec §3).
	draw_line(Vector2(0.0, 24.0), Vector2(20.0, 24.0), COL_TRACK, TRACK_WIDTH)
	draw_line(Vector2(28.0, 24.0), Vector2(TILE, 24.0), COL_TRACK, TRACK_WIDTH)
	draw_line(Vector2(20.0, 18.0), Vector2(20.0, 30.0), COL_TRACK, 2.0)
	draw_line(Vector2(28.0, 18.0), Vector2(28.0, 30.0), COL_TRACK, 2.0)


func _draw_turnout(branch_ne: bool) -> void:
	# Skórka: kostka rozjazdowa (tor poziomy + odgałęzienie 45° od środka
	# do narożnika); fallback: tor poziomy + odgałęzienie wektorowe.
	if not _draw_tile_tex("turnout_ne" if branch_ne else "turnout_nw"):
		if not _draw_tile_tex("track_h"):
			_draw_track_h()
		# Odgałęzienie 45° do narożnika: turnout_ne → NE, turnout_nw → NW.
		var corner := Vector2(TILE, 0.0) if branch_ne else Vector2(0.0, 0.0)
		draw_line(Vector2(24.0, 24.0), corner, COL_TRACK, TRACK_WIDTH)
	# Okienko lampki sekcji zwrotnicowej — odsunięte od rozgałęzienia.
	var lamp_x := 10.0 if branch_ne else 38.0
	_draw_section_lamp(Vector2(lamp_x, 24.0), 14.0)
	_draw_position_lamps(branch_ne)
	# Tabliczka z numerem zwrotnicy 14×10 px (spec §3).
	var plate_pos := Vector2(6.0, 31.0) if branch_ne else Vector2(28.0, 31.0)
	draw_rect(Rect2(plate_pos, Vector2(14.0, 10.0)), COL_PLATE)
	draw_rect(Rect2(plate_pos, Vector2(14.0, 10.0)), COL_TEXT, false, 1.0)
	_draw_text(Vector2(plate_pos.x, plate_pos.y + 8.0), 14.0, String(tile_def.get("label", "")), 9)
	_draw_button(_button_center(), _button_color())


## Lampki kontroli położenia zwrotnicy przy rozgałęzieniu (spec §3):
## świeci strona, w którą droga zwarta; przestawianie = obie migają.
# TODO(weryfikacja): w wielu urządzeniach położenie pokazuje pojedyncza
# lampka/podświetlenie kierunku — parametr stylu (assets-spec/20 §3).
# TODO(weryfikacja): brak kontroli = miganie + brzęczyk (systemy/13 §5);
# przyjęto miganie czerwone obu lampek, brzęczyk dojdzie z dźwiękami (F10).
func _draw_position_lamps(branch_ne: bool) -> void:
	var turnout := graph.get_turnout(_turnout_id) if graph != null else null
	if turnout == null:
		return
	var plus_lamp := Vector2(38.0, 31.0) if branch_ne else Vector2(10.0, 31.0)
	var minus_lamp := Vector2(40.0, 13.0) if branch_ne else Vector2(8.0, 13.0)
	var plus_color := COL_LAMP_OFF
	var minus_color := COL_LAMP_OFF
	match turnout.state:
		Const.TurnoutState.PLUS:
			plus_color = COL_LOCKED
		Const.TurnoutState.MINUS:
			minus_color = COL_LOCKED
		Const.TurnoutState.MOVING:
			if blink_on:
				plus_color = COL_LOCKED
				minus_color = COL_LOCKED
		Const.TurnoutState.NO_CONTROL, Const.TurnoutState.TRAILED:
			if blink_on:
				plus_color = COL_OCCUPIED
				minus_color = COL_OCCUPIED
	draw_circle(plus_lamp, 4.5, COL_LAMP_RING)
	draw_circle(plus_lamp, 3.5, plus_color)
	draw_circle(minus_lamp, 4.5, COL_LAMP_RING)
	draw_circle(minus_lamp, 3.5, minus_color)


func _draw_signal_tile(travel_east: bool) -> void:
	if not _draw_tile_tex("track_h"):
		_draw_track_h()
	# Symbol semafora po prawej stronie toru w kierunku jazdy: jazda na wschód
	# → pod torem, na zachód → nad torem. Kółko 12 px + kreska-podstawa
	# prostopadła do toru, „chorągiewka" w kierunku jazdy (spec §3).
	var below := travel_east
	var base_x := 20.0 if travel_east else 28.0
	var head_x := 30.0 if travel_east else 18.0
	var base_top := 31.0 if below else 7.0
	var head_y := 37.0 if below else 11.0
	draw_line(Vector2(base_x, base_top), Vector2(base_x, base_top + 10.0), COL_TRACK, 2.0)
	draw_line(Vector2(base_x, head_y), Vector2(head_x, head_y), COL_TRACK, 2.0)
	draw_circle(Vector2(head_x, head_y), 7.0, COL_TRACK)
	draw_circle(Vector2(head_x, head_y), 5.5, _repeater_color())
	# Litera semafora obok symbolu.
	var letter_y := 44.0 if below else 16.0
	_draw_text(Vector2(0.0, letter_y), 14.0, String(_signal_id), 10)
	_draw_button(_button_center(), _button_color())


## Kolor powtarzacza semafora na planie (systemy/13 §1):
## zielony = sygnał zezwalający, czerwony = „stój", biały migający = Sz.
# TODO(weryfikacja): kolory powtarzaczy w typie E do weryfikacji (systemy/13 §1).
func _repeater_color() -> Color:
	var signal_device := graph.get_signal(_signal_id) if graph != null else null
	if signal_device == null:
		return COL_LAMP_OFF
	if signal_device.aspect == &"Sz":
		return COL_LOCKED if blink_on else COL_LAMP_OFF
	if signal_device.shows_stop():
		return COL_OCCUPIED
	return COL_GREEN


func _draw_section_lamp(center: Vector2, width: float = 20.0) -> void:
	if _section_id == &"":
		return
	_draw_lamp_capsule(center, width, _section_lamp_color())


func _draw_section_lamp_round(center: Vector2) -> void:
	if _section_id == &"":
		return
	var color := _section_lamp_color()
	if color == COL_OCCUPIED:
		draw_circle(center, 11.0, Color(COL_OCCUPIED, 0.2))
	draw_circle(center, 6.0, COL_LAMP_RING)
	draw_circle(center, 5.0, color)


## Kolory lampek odcinków (systemy/13 §1): czerwona = zajęty, biała =
## utwierdzony w przebiegu, ciemna = wolny; zajętość nadpisuje białą.
func _section_lamp_color() -> Color:
	var section := graph.get_section(_section_id) if graph != null else null
	if section == null:
		return COL_LAMP_OFF
	if section.occupied:
		return COL_OCCUPIED
	if section.is_locked():
		return COL_LOCKED
	return COL_LAMP_OFF


## Okienko lampki: kapsuła 20×8 px wpuszczona w linię toru (spec §3).
func _draw_lamp_capsule(center: Vector2, width: float, color: Color) -> void:
	if color == COL_OCCUPIED:
		# Poświata zajętości 20% (spec §2).
		draw_circle(center, 13.0, Color(COL_OCCUPIED, 0.2))
	_capsule(center, width, 8.0, COL_LAMP_RING, 1.0)
	_capsule(center, width, 8.0, color, 0.0)


func _capsule(center: Vector2, width: float, height: float, color: Color, grow: float) -> void:
	var r := height / 2.0 + grow
	var half := width / 2.0 - height / 2.0
	draw_circle(center + Vector2(-half, 0.0), r, color)
	draw_circle(center + Vector2(half, 0.0), r, color)
	draw_rect(Rect2(center + Vector2(-half, -r), Vector2(half * 2.0, r * 2.0)), color)


## Przycisk: korpus walcowy z góry, okrąg z cieniem (spec §4).
func _draw_button(center: Vector2, head_color: Color, sealed: bool = false) -> void:
	if center == Vector2.INF:
		return
	if sealed:
		# Kołnierz plomby + drucik (spec §4).
		draw_circle(center, BUTTON_RADIUS + 3.5, COL_SEAL_COLLAR)
		draw_line(center + Vector2(-12.0, 4.0), center + Vector2(12.0, -4.0),
			Color("9a9a9a"), 1.0)
		draw_circle(center + Vector2(12.0, -4.0), 2.0, Color("9a9a9a"))
	draw_circle(center + Vector2(1.5, 1.5), BUTTON_RADIUS, COL_BUTTON_SHADOW)
	draw_circle(center, BUTTON_RADIUS, head_color)
	draw_circle(center, BUTTON_RADIUS - 3.0, head_color.lightened(0.12))


func _button_color() -> Color:
	if _press_action.begins_with("turnout"):
		return COL_BUTTON_GRAY
	if _press_action.begins_with("route_start"):
		return COL_BUTTON_GREEN
	if _press_action.begins_with("sub_signal") \
			or _press_action.begins_with("route_emergency_release"):
		return COL_BUTTON_RED
	return COL_BUTTON_GRAY


## Pole blokady liniowej (3×2 kostki, assets-spec/20 §5): ramka, etykieta,
## lampki stanu (odstęp zajęty, pozwolenie u nas) i przyciski Po/Ko/Poz.
func _draw_block_field() -> void:
	if not _draw_tile_tex("kostka_wide"):
		draw_rect(Rect2(4.0, 4.0, 136.0, 88.0), COL_TEXT, false, 2.0)
	_draw_text(Vector2(4.0, 18.0), 136.0, String(tile_def.get("label", "")), 10)
	var block: BlockLine = blocks.get(StringName(String(tile_def.get("block", ""))))
	var occupied_color := COL_LAMP_OFF
	var permission_color := COL_LAMP_OFF
	var po_color := COL_LAMP_OFF
	if block != null:
		if block.occupied:
			occupied_color = COL_OCCUPIED
		if block.permission_at == BlockLine.BlockSide.PLAYER:
			permission_color = COL_GREEN
		if block.po_locked:
			po_color = COL_LOCKED
	var lamp_x: Array[float] = [30.0, 72.0, 114.0]
	var lamp_colors: Array[Color] = [occupied_color, po_color, permission_color]
	var lamp_labels: Array[String] = ["odstęp", "Po", "pozw."]
	for i: int in 3:
		_draw_state_lamp(Vector2(lamp_x[i], 36.0), lamp_colors[i], 6.0)
		_draw_text(Vector2(lamp_x[i] - 20.0, 52.0), 40.0, lamp_labels[i], 8)
	var centers := _block_button_centers()
	for field: String in centers:
		_draw_button(centers[field], COL_BUTTON_GRAY)
		_draw_text(Vector2(centers[field].x - 20.0, 89.0), 40.0, field, 8)


func _block_button_centers() -> Dictionary:
	return {
		"Po": Vector2(30.0, 70.0),
		"Ko": Vector2(72.0, 70.0),
		"Poz": Vector2(114.0, 70.0),
	}


## Pole przejazdu kat. A (docs/systemy/16 §2): lampki położenia drągów
## + przyciski zamknij/otwórz.
## TODO(weryfikacja): konwencja lampek położenia drągów — przyjęto:
## biała = zamknięty (bezpieczny dla kolei), ciemna = otwarty,
## miganie = ruch drągów / awaria (czerwone).
func _draw_crossing_ctrl() -> void:
	if not _draw_tile_tex("kostka_wide"):
		draw_rect(Rect2(4.0, 4.0, 136.0, 88.0), COL_TEXT, false, 2.0)
	_draw_text(Vector2(4.0, 18.0), 136.0, String(tile_def.get("label", "")), 9)
	var crossing: LevelCrossing = null
	if world != null:
		crossing = world.crossings.get(StringName(String(tile_def.get("crossing", ""))))
	var lamp := COL_LAMP_OFF
	if crossing != null:
		match crossing.state:
			LevelCrossing.State.CLOSED:
				lamp = COL_LOCKED
			LevelCrossing.State.CLOSING, LevelCrossing.State.OPENING:
				lamp = COL_LOCKED if blink_on else COL_LAMP_OFF
			LevelCrossing.State.FAILURE:
				lamp = COL_OCCUPIED if blink_on else COL_LAMP_OFF
			_:
				lamp = COL_LAMP_OFF
	_draw_state_lamp(Vector2(72.0, 38.0), lamp, 7.0)
	var state_name := "?" if crossing == null \
		else LevelCrossing.STATE_NAMES[crossing.state]
	_draw_text(Vector2(4.0, 54.0), 136.0, state_name, 8)
	_draw_button(Vector2(48.0, 70.0), COL_BUTTON_GRAY)
	_draw_text(Vector2(28.0, 89.0), 40.0, "Zamk", 8)
	_draw_button(Vector2(96.0, 70.0), COL_BUTTON_GRAY)
	_draw_text(Vector2(76.0, 89.0), 40.0, "Otw", 8)


## Kontrola ssp na pulpicie (docs/systemy/16 §3): sprawna / załączona /
## awaria.
func _draw_ssp_ctrl() -> void:
	if not _draw_tile_tex("kostka_wide"):
		draw_rect(Rect2(4.0, 4.0, 136.0, 88.0), COL_TEXT, false, 2.0)
	_draw_text(Vector2(4.0, 18.0), 136.0, String(tile_def.get("label", "")), 9)
	var crossing: LevelCrossing = null
	if world != null:
		crossing = world.crossings.get(StringName(String(tile_def.get("crossing", ""))))
	var ok_lamp := COL_LAMP_OFF
	var active_lamp := COL_LAMP_OFF
	var fail_lamp := COL_LAMP_OFF
	if crossing != null:
		if crossing.state == LevelCrossing.State.FAILURE:
			fail_lamp = COL_OCCUPIED if blink_on else COL_LAMP_OFF
		else:
			ok_lamp = COL_GREEN
			if crossing.state != LevelCrossing.State.OPEN:
				active_lamp = COL_LOCKED
	var lamp_x: Array[float] = [30.0, 72.0, 114.0]
	var lamp_colors: Array[Color] = [ok_lamp, active_lamp, fail_lamp]
	var labels: Array[String] = ["sprawna", "załącz.", "awaria"]
	for i: int in 3:
		_draw_state_lamp(Vector2(lamp_x[i], 44.0), lamp_colors[i], 6.0)
		_draw_text(Vector2(lamp_x[i] - 22.0, 62.0), 44.0, labels[i], 8)


## Terminal dSAT (docs/systemy/17 §2): lampka alarmu + kwitowanie.
func _draw_dsat_ctrl() -> void:
	if not _draw_tile_tex("kostka_wide"):
		draw_rect(Rect2(4.0, 4.0, 136.0, 88.0), COL_TEXT, false, 2.0)
	_draw_text(Vector2(4.0, 18.0), 136.0, String(tile_def.get("label", "")), 9)
	var alarm := world != null and world.dsat_unacked()
	var beacon := skin_texture("beacon")
	if alarm and blink_on and beacon != null:
		# Kogut alarmowy dSAT (skórka) — miga do skwitowania.
		draw_texture_rect(beacon, Rect2(72.0 - 14.0, 26.0, 28.0, 28.0), false)
	else:
		var lamp := (COL_OCCUPIED if blink_on else COL_LAMP_OFF) if alarm else COL_LAMP_OFF
		_draw_state_lamp(Vector2(72.0, 40.0), lamp, 7.0)
	_draw_button(Vector2(72.0, 70.0), COL_BUTTON_RED)
	_draw_text(Vector2(52.0, 89.0), 40.0, "KWIT", 8)


## Przycisk specjalny z licznikiem i plombą (1×2 kostki, spec §2/§4,
## systemy/13 §4). W F2 nieaktywny — działanie dojdzie w F3.
func _draw_counter_button() -> void:
	_draw_text(Vector2(0.0, 12.0), TILE, String(tile_def.get("label", "")), 9)
	var sealed := bool(tile_def.get("sealed", false))
	_draw_button(Vector2(24.0, 34.0), _button_color(), sealed)
	if bool(tile_def.get("counter", false)):
		var counter_tex := skin_texture("counter")
		if counter_tex != null:
			# Licznik bębenkowy ze skórki; okienko przykrywamy bieżącym stanem.
			draw_texture_rect(counter_tex, Rect2(6.0, 50.0, 36.0, 36.0), false)
			draw_rect(Rect2(12.0, 63.0, 24.0, 11.0), COL_COUNTER_BG)
			_draw_text_color(Vector2(12.0, 72.0), 24.0, "%03d" % _counter_value(), 9,
				COL_COUNTER_DIGITS)
		else:
			draw_rect(Rect2(10.0, 58.0, 28.0, 14.0), COL_COUNTER_BG)
			_draw_text_color(Vector2(10.0, 69.0), 28.0, "%03d" % _counter_value(), 10,
				COL_COUNTER_DIGITS)


## Stan licznika bębenkowego przycisku (docs/systemy/13 §4) z rdzenia.
func _counter_value() -> int:
	if interlocking == null:
		return 0
	if _press_action.begins_with("sub_signal:"):
		return int(interlocking.counters.get("dSz:%s" % _press_action.get_slice(":", 1), 0))
	if _press_action.begins_with("route_emergency_release"):
		return int(interlocking.counters.get("dZw", 0))
	return 0


func _draw_tile_label(center_top: Vector2) -> void:
	var text := String(tile_def.get("label", ""))
	if not text.is_empty():
		_draw_text(Vector2(0.0, center_top.y), TILE, text, 10)


func _draw_text(pos: Vector2, width: float, text: String, font_size: int) -> void:
	_draw_text_color(pos, width, text, font_size, COL_TEXT)


func _draw_text_color(
	pos: Vector2, width: float, text: String, font_size: int, color: Color
) -> void:
	if text.is_empty():
		return
	var font := ThemeDB.fallback_font
	draw_string(font, pos, text, HORIZONTAL_ALIGNMENT_CENTER, width, font_size, color)
