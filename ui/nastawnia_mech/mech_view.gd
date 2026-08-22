class_name MechView
extends Control
## Widok nastawni mechanicznej (assets-spec/22): u góry okno z panoramą
## torów (gracz sprawdza wolność toru WZROKIEM — kontroli zajętości brak,
## docs/systemy/12 §1), w środku aparat blokowy (pola blokowe z klawiszami
## i induktorem), na dole ława dźwigniowa. UI tylko czyta stan rdzenia
## i wysyła polecenia (docs/02-architektura.md).

signal action_requested(action_name: StringName, args: Dictionary)

const VIEW_W: float = 1520.0
const VIEW_H: float = 940.0
const PANORAMA_H: float = 420.0
const BLOCKS_H: float = 190.0

## Paleta wg assets-spec/22 §5 (robocza).
const COL_SKY := Color("b8ccd8")
const COL_GROUND := Color("8f9b74")
const COL_BALLAST := Color("9a9284")
const COL_RAIL := Color("3a3a3a")
const COL_WALL := Color("CFC9B8")
const COL_WAINSCOT := Color("7A6A4F")
const COL_FLOOR := Color("8A6B45")
const COL_OAK := Color("6E4F2A")
const COL_SHEET := Color("8C8C8C")
const COL_BRASS := Color("B08D3E")
const COL_LEVER_METAL := Color("3E434A")
# TODO(weryfikacja): kolory dźwigni robocze (systemy/12 §1): zwrotnicowe
# niebieskie, ryglowe zielone, sygnałowe czerwone.
const COL_LEVER: Dictionary = {
	LeverFrame.LeverType.ZWROTNICOWA: Color("2D4F8A"),
	LeverFrame.LeverType.RYGLOWA: Color("2F6B3A"),
	LeverFrame.LeverType.SYGNALOWA: Color("A83226"),
}
const COL_TEXT := Color("2B2B2B")
## Czas kręcenia induktorem przy obsłudze pola blokowego (assets-spec/22 §3).
const CRANK_TIME_S: float = 2.0

var _world: SimWorld = null
## Trwająca obsługa induktora: {action, args, left_s, label}.
var _crank: Dictionary = {}
## Ekranowe prostokąty klawiszy pól blokowych: [{rect, action, args, label}].
var _block_keys: Array[Dictionary] = []
## Ekranowe uchwyty dźwigni: [{rect, lever_id}].
var _lever_grips: Array[Dictionary] = []


func build_view(world: SimWorld) -> void:
	_world = world
	custom_minimum_size = Vector2(VIEW_W, VIEW_H)
	size = custom_minimum_size
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	queue_redraw()


func refresh() -> void:
	queue_redraw()


func _process(delta: float) -> void:
	if _crank.is_empty():
		return
	_crank["left_s"] = float(_crank["left_s"]) - delta
	if float(_crank["left_s"]) <= 0.0:
		action_requested.emit(StringName(String(_crank["action"])), _crank["args"])
		_crank = {}
	queue_redraw()


func _gui_input(event: InputEvent) -> void:
	var click := event as InputEventMouseButton
	if click == null or not click.pressed or click.button_index != MOUSE_BUTTON_LEFT:
		return
	if not _crank.is_empty():
		return
	for key: Dictionary in _block_keys:
		if (key["rect"] as Rect2).has_point(click.position):
			accept_event()
			# Klawisz + induktor: 2 s „kręcenia korbką", potem polecenie.
			_crank = {"action": key["action"], "args": key["args"],
				"left_s": CRANK_TIME_S, "label": key["label"]}
			return
	for grip: Dictionary in _lever_grips:
		if (grip["rect"] as Rect2).has_point(click.position):
			accept_event()
			action_requested.emit(&"lever_move", {"id": String(grip["lever_id"])})
			return


func _draw() -> void:
	_block_keys.clear()
	_lever_grips.clear()
	_draw_panorama(Rect2(0.0, 0.0, VIEW_W, PANORAMA_H))
	_draw_block_apparatus(Rect2(0.0, PANORAMA_H, VIEW_W, BLOCKS_H))
	_draw_lever_bench(Rect2(0.0, PANORAMA_H + BLOCKS_H, VIEW_W, VIEW_H - PANORAMA_H - BLOCKS_H))


# ---------------------------------------------------------------------------
# Panorama torów (widok z okna) — assets-spec/22 §4
# ---------------------------------------------------------------------------

func _station_length_m() -> float:
	var total := 0.0
	for edge_id: StringName in _world.station.graph.edges:
		var edge := _world.station.graph.get_edge(edge_id)
		if edge.id != &"e_t2":
			total += edge.len_m
	for section_id: StringName in _world.station.graph.sections:
		var section := _world.station.graph.get_section(section_id)
		if section.type == Const.SectionType.TURNOUT:
			total += section.len_m
	return maxf(total, 1.0)


func _draw_panorama(area: Rect2) -> void:
	draw_rect(area, COL_SKY)
	var ground_y := area.position.y + area.size.y * 0.62
	draw_rect(Rect2(area.position.x, ground_y, area.size.x, area.end.y - ground_y), COL_GROUND)
	var margin := 40.0
	var scale_px := (area.size.x - 2.0 * margin) / _station_length_m()
	var y_main := ground_y + 58.0
	var y_back := ground_y + 22.0
	# Peron między rozjazdami (sylwetka).
	var x_a := margin + 640.0 * scale_px
	var x_b := margin + 1040.0 * scale_px
	draw_rect(Rect2(x_a, y_back + 8.0, x_b - x_a, 10.0), Color("b9b1a0"))
	# Tor 2 (w głębi) między rozjazdami, tor główny na całej długości.
	_draw_track_line(area.position.x + 8.0, area.end.x - 8.0, y_main)
	_draw_track_line(x_a, x_b, y_back)
	draw_line(Vector2(x_a - 30.0 * scale_px, y_main - 2.0), Vector2(x_a, y_back),
		COL_RAIL, 3.0)
	draw_line(Vector2(x_b + 30.0 * scale_px, y_main - 2.0), Vector2(x_b, y_back),
		COL_RAIL, 3.0)
	# Semafory kształtowe przy węzłach (ramiona wg obrazu Sr1/Sr2/Sr3).
	var graph := _world.station.graph
	for signal_id: StringName in graph.signals:
		var signal_device := graph.get_signal(signal_id)
		if signal_device.kind != Const.SignalKind.SEMAFOR_KSZTALTOWY:
			continue
		var node_x := 600.0 if signal_device.at_node == &"nA" else 1080.0
		var east := signal_device.dir == &"N"
		var offset := -14.0 if east else 14.0
		if signal_device.id in [&"C1", &"C2"]:
			offset = -14.0
		if signal_device.id in [&"D1", &"D2"]:
			offset = 14.0
		var x := margin + node_x * scale_px + offset \
			+ (10.0 if String(signal_device.id).ends_with("2") else 0.0)
		_draw_shape_semaphore(Vector2(x, y_main), signal_device, east)
	# Pociągi — gracz widzi skład, nie lampki (docs/systemy/12 §1).
	for train: Train in _world.trains:
		var west_m := train.front_m if train.eastbound \
			else _station_length_m() - train.front_m
		var length_px := train.length_m * scale_px
		var head_x := margin + west_m * scale_px
		var rect_x := head_x - length_px if train.eastbound else head_x
		var on_back := train.covered_sections().has(&"it2")
		var y := (y_back if on_back else y_main) - 20.0
		var color := Color("7a7f85") if train.kind == "towarowy" else Color("2f6b45")
		draw_rect(Rect2(rect_x, y, length_px, 16.0), color)
		draw_rect(Rect2(rect_x, y, length_px, 16.0), COL_TEXT, false, 1.5)
		_text(Vector2(rect_x, y - 6.0), length_px, train.nr, 11)


func _draw_track_line(from_x: float, to_x: float, y: float) -> void:
	draw_rect(Rect2(from_x, y + 2.0, to_x - from_x, 5.0), COL_BALLAST)
	draw_line(Vector2(from_x, y), Vector2(to_x, y), COL_RAIL, 3.0)


## Semafor kształtowy: maszt kratowy + ramiona (Sr1 poziomo / Sr2 jedno
## ukośnie / Sr3 dwa ukośnie) — assets-spec/22 §4, systemy/11 §7.
func _draw_shape_semaphore(base: Vector2, signal_device: SignalDevice, east: bool) -> void:
	var mast_top := base.y - 74.0
	draw_line(base, Vector2(base.x, mast_top), COL_LEVER_METAL, 3.0)
	draw_line(Vector2(base.x - 5.0, base.y), Vector2(base.x + 5.0, base.y),
		COL_LEVER_METAL, 2.0)
	var dir_sign := 1.0 if east else -1.0
	var arm_len := 26.0
	var aspect := signal_device.aspect
	var up := aspect == &"Sr2" or aspect == &"Sr3"
	_draw_arm(Vector2(base.x, mast_top), dir_sign, arm_len, up)
	if aspect == &"Sr3":
		_draw_arm(Vector2(base.x, mast_top + 20.0), dir_sign, arm_len * 0.8, true)
	_text(Vector2(base.x - 14.0, base.y + 14.0), 28.0, String(signal_device.id), 10)


func _draw_arm(pivot: Vector2, dir_sign: float, arm_len: float, raised: bool) -> void:
	var angle := -0.7 if raised else 0.0
	var tip := pivot + Vector2(cos(angle) * arm_len * dir_sign, sin(angle) * arm_len)
	draw_line(pivot, tip, Color("c23a2e"), 7.0)
	var mid := pivot.lerp(tip, 0.55)
	draw_line(pivot.lerp(tip, 0.4), mid, Color("f2ede0"), 7.0)


# ---------------------------------------------------------------------------
# Aparat blokowy — assets-spec/22 §3
# ---------------------------------------------------------------------------

func _draw_block_apparatus(area: Rect2) -> void:
	draw_rect(area, COL_WALL)
	var box := Rect2(area.position.x + 40.0, area.position.y + 8.0,
		area.size.x - 80.0, area.size.y - 16.0)
	draw_rect(box, COL_OAK)
	draw_rect(Rect2(box.position.x, box.position.y, box.size.x, 14.0), COL_SHEET)
	draw_rect(box, Color("4a3a22"), false, 2.0)
	_text(Vector2(box.position.x + 8.0, box.position.y + 11.0), 300.0,
		"APARAT BLOKOWY", 10)
	# Pola: blokada liniowa (Po/Ko/Poz per sąsiad) + bloki stacyjne.
	var fields: Array[Dictionary] = []
	for block_id: StringName in _world.block_lines:
		var block: BlockLine = _world.block_lines[block_id]
		fields.append({"label": "Po %s" % block.neighbour_name,
			"red": block.po_locked,
			"action": "block_press", "args": {"id": String(block_id), "value": "Po"}})
		fields.append({"label": "Ko %s" % block.neighbour_name,
			"red": block.occupied,
			"action": "block_press", "args": {"id": String(block_id), "value": "Ko"}})
		fields.append({"label": "Poz %s" % block.neighbour_name,
			"red": block.permission_at != BlockLine.BlockSide.PLAYER,
			"action": "block_press", "args": {"id": String(block_id), "value": "Poz"}})
	if _world.lever_frame != null:
		for block_id: StringName in _world.lever_frame.block_order:
			var station_block: LeverFrame.StationBlock = \
				_world.lever_frame.station_blocks[block_id]
			fields.append({"label": station_block.label,
				"red": station_block.given,
				"action": "station_block_press", "args": {"id": String(block_id)}})
	var count := fields.size()
	var spacing := box.size.x / float(count + 1)
	for i: int in count:
		var field: Dictionary = fields[i]
		var cx := box.position.x + spacing * float(i + 1)
		_text(Vector2(cx - spacing / 2.0, box.position.y + 34.0), spacing,
			String(field["label"]), 9, Color("e8e2d2"))
		# Okienko 26×36 w mosiężnej ramce; czerwone = zablokowane
		# TODO(weryfikacja): konwencja barw okienek per pole (systemy/15 §3).
		var window := Rect2(cx - 13.0, box.position.y + 42.0, 26.0, 36.0)
		draw_rect(window.grow(3.0), COL_BRASS)
		draw_rect(window, Color("b8352b") if bool(field["red"]) else Color("f2ede0"))
		# Klawisz pod polem.
		var key := Rect2(cx - 17.0, window.end.y + 10.0, 34.0, 18.0)
		draw_rect(key, Color("1f1f1f"))
		draw_rect(key.grow(-2.0), Color("3c3c3c"))
		_block_keys.append({"rect": key.grow(6.0), "action": field["action"],
			"args": field["args"], "label": field["label"]})
	# Korbka induktora + pasek postępu kręcenia.
	var crank_center := Vector2(box.end.x - 26.0, box.position.y + 60.0)
	draw_circle(crank_center, 12.0, COL_SHEET)
	draw_line(crank_center, crank_center + Vector2(10.0, -14.0), Color("2b2b2b"), 4.0)
	if not _crank.is_empty():
		var progress := 1.0 - float(_crank["left_s"]) / CRANK_TIME_S
		var bar := Rect2(box.position.x + 8.0, box.end.y - 16.0, box.size.x - 16.0, 8.0)
		draw_rect(bar, Color("2b2b2b"))
		draw_rect(Rect2(bar.position, Vector2(bar.size.x * progress, bar.size.y)),
			Color("d9b23c"))
		_text(Vector2(bar.position.x, bar.position.y - 4.0), bar.size.x,
			"induktor: %s" % _crank["label"], 9, Color("e8e2d2"))


# ---------------------------------------------------------------------------
# Ława dźwigniowa — assets-spec/22 §2
# ---------------------------------------------------------------------------

func _draw_lever_bench(area: Rect2) -> void:
	draw_rect(area, COL_WAINSCOT)
	draw_rect(Rect2(area.position.x, area.end.y - 60.0, area.size.x, 60.0), COL_FLOOR)
	if _world.lever_frame == null:
		return
	var axis_y := area.end.y - 70.0
	draw_line(Vector2(area.position.x + 30.0, axis_y),
		Vector2(area.end.x - 30.0, axis_y), COL_LEVER_METAL, 8.0)
	var count := _world.lever_frame.lever_order.size()
	var spacing := (area.size.x - 120.0) / float(maxi(count - 1, 1))
	for i: int in count:
		var lever: LeverFrame.Lever = _world.lever_frame.levers[
			_world.lever_frame.lever_order[i]]
		var base := Vector2(area.position.x + 60.0 + spacing * float(i), axis_y)
		_draw_lever(base, lever)


func _draw_lever(base: Vector2, lever: LeverFrame.Lever) -> void:
	var reversed := lever.reversed
	var blink := false
	if lever.type == LeverFrame.LeverType.ZWROTNICOWA:
		var turnout := _world.station.graph.get_turnout(lever.turnout)
		if turnout != null:
			reversed = turnout.physical_pos() == Const.TurnoutPos.MINUS
			blink = not turnout.has_control() \
				and fmod(Time.get_ticks_msec() / 1000.0, 1.0) < 0.5
	# Dźwignia pionowa (zasadnicze) albo przełożona ~40° (spec §2).
	var angle := deg_to_rad(40.0) if reversed else 0.0
	var top := base + Vector2(sin(angle) * 140.0, -cos(angle) * 140.0)
	draw_line(base, base.lerp(top, 0.35), COL_LEVER_METAL, 9.0)
	var color: Color = COL_LEVER[lever.type]
	if blink:
		color = Color("E0362C")
	draw_line(base.lerp(top, 0.3), top, color, 8.0)
	# Rękojeść z zapadką (ciężarkiem).
	draw_circle(top, 7.0, COL_LEVER_METAL)
	draw_circle(base.lerp(top, 0.62), 6.0, COL_LEVER_METAL)
	# Tabliczka emaliowana z numerem przy osi.
	var plate := Rect2(base.x - 13.0, base.y + 12.0, 26.0, 16.0)
	draw_rect(plate, Color("f2ede0"))
	draw_rect(plate, COL_TEXT, false, 1.0)
	_text(Vector2(plate.position.x, plate.position.y + 12.0), plate.size.x, lever.label, 10)
	_lever_grips.append({
		"rect": Rect2(top.x - 26.0, top.y - 26.0, 52.0, 96.0), "lever_id": lever.id,
	})


func _text(pos: Vector2, width: float, text: String, font_size: int,
		color: Color = COL_TEXT) -> void:
	draw_string(ThemeDB.fallback_font, Vector2(pos.x, pos.y), text,
		HORIZONTAL_ALIGNMENT_CENTER, width, font_size, color)
