class_name KomputerView
extends Control
## Stanowisko komputerowych urządzeń nastawczych (docs/systemy/14 §1):
## pasek menu poleceń, plan synoptyczny (KomputerPlan, konwencja barw
## docs/14 §2), panel przebiegów/rejestru, linia dialogowa i pole alarmów
## z kwitowaniem. Polecenia „ze wskazaniem": klik pozycji menu uzbraja
## polecenie, klik semafora na planie je adresuje (docs/14 §3).
## Widok REFERENCYJNY — docelowe GUI buduje użytkownik na tym samym API.

## Akcja w formacie "polecenie:arg[:arg2]" — jak na pulpicie.
signal action_requested(action: String)

const REGISTER_LINES: int = 6
const COL_VIEW_BG := Color("08090b")
const COL_BAR_BG := Color("1a1f27")
const COL_BOX_BG := Color("161a21")
const COL_BOX_EDGE := Color("2c323b")
const COL_ACCENT := Color("8ab4d8")
const COL_ALARM := Color("f04438")

var _world: SimWorld = null
var _plan: KomputerPlan = null
var _pending_label: Label = null
var _confirm_button: Button = null
var _cancel_button: Button = null
var _active_list: VBoxContainer = null
var _register_text: RichTextLabel = null
var _routes_hint: Label = null
var _clock_label: Label = null
var _dialog_label: Label = null
var _alarm_label: Label = null
var _alarm_panel: PanelContainer = null
var _kwit_button: Button = null
var _menu_buttons: Dictionary = {}
## Przyciski przebiegów wg semafora początkowego (filtr po kliku w plan).
var _route_buttons: Array[Dictionary] = []
var _filter_signal: StringName = &""
## Uzbrojone polecenie menu czekające na wskazanie semafora na planie.
var _armed: String = ""

const ARMED_LABELS := {
	"sz": "SYGNAŁ ZASTĘPCZY — wskaż semafor na planie",
	"cancel": "COFNIĘCIE PRZEBIEGU — wskaż semafor początkowy",
	"dzw": "DORAŹNE ZWOLNIENIE — wskaż semafor przebiegu",
}


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), COL_VIEW_BG)


func build_view(world: SimWorld) -> void:
	_world = world
	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 6)
	add_child(root)

	# --- Pasek menu poleceń (docs/14 §1). --------------------------------
	var bar := _panel(COL_BAR_BG)
	var bar_box := HBoxContainer.new()
	bar_box.add_theme_constant_override("separation", 10)
	bar.add_child(bar_box)
	var title := Label.new()
	title.text = "  %s — komputerowe urządzenia nastawcze" \
		% world.station.display_name().to_upper()
	title.add_theme_color_override("font_color", COL_ACCENT)
	bar_box.add_child(title)
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bar_box.add_child(spacer)
	_add_menu_button(bar_box, "sz", "Sz…")
	_add_menu_button(bar_box, "cancel", "Cofnij przebieg…")
	_add_menu_button(bar_box, "dzw", "dZw…")
	_clock_label = Label.new()
	_clock_label.add_theme_color_override("font_color", Color(0.9, 0.92, 0.95))
	_clock_label.text = "  00:00:00  "
	bar_box.add_child(_clock_label)
	root.add_child(bar)

	# --- Plan + panel boczny. --------------------------------------------
	var middle := HBoxContainer.new()
	middle.add_theme_constant_override("separation", 8)
	middle.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(middle)

	_plan = KomputerPlan.new()
	_plan.build(world.station, world.interlocking, world.block_lines, world)
	_plan.action_requested.connect(func(action: String) -> void:
		action_requested.emit(action)
	)
	_plan.signal_clicked.connect(_on_plan_signal_clicked)
	middle.add_child(_plan)

	var side := VBoxContainer.new()
	side.custom_minimum_size = Vector2(430, 0)
	side.add_theme_constant_override("separation", 8)
	middle.add_child(side)

	# Polecenie dwustopniowe (docs/14 §3): okno „Wykonać? [Tak/Nie]".
	var confirm_content := VBoxContainer.new()
	_pending_label = Label.new()
	_pending_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_pending_label.text = "—"
	confirm_content.add_child(_pending_label)
	var confirm_row := HBoxContainer.new()
	_confirm_button = Button.new()
	_confirm_button.text = "WYKONAĆ (Tak)"
	_confirm_button.pressed.connect(
		func() -> void: action_requested.emit("command_confirm")
	)
	_cancel_button = Button.new()
	_cancel_button.text = "Anuluj (Nie)"
	_cancel_button.pressed.connect(
		func() -> void: action_requested.emit("command_cancel")
	)
	confirm_row.add_child(_confirm_button)
	confirm_row.add_child(_cancel_button)
	confirm_content.add_child(confirm_row)
	side.add_child(_boxed("POLECENIE SPECJALNE", confirm_content))

	# Nastawianie przebiegowe (docs/14 §5).
	var routes_content := VBoxContainer.new()
	_routes_hint = Label.new()
	_routes_hint.add_theme_font_size_override("font_size", 11)
	_routes_hint.add_theme_color_override("font_color", Color(0.55, 0.6, 0.66))
	_routes_hint.text = "klik w semafor na planie = filtr początku drogi"
	routes_content.add_child(_routes_hint)
	var routes_grid := GridContainer.new()
	routes_grid.columns = 2
	for route_id: StringName in world.interlocking.routes:
		var route: Route = world.interlocking.routes[route_id]
		var button := Button.new()
		button.text = "%s → %s" % [route.entry_signal, route.target]
		button.tooltip_text = String(route.id)
		var id_string := String(route.id)
		button.pressed.connect(
			func() -> void: action_requested.emit("route_set:%s" % id_string)
		)
		routes_grid.add_child(button)
		_route_buttons.append({"button": button, "entry": route.entry_signal})
	routes_content.add_child(routes_grid)
	side.add_child(_boxed("PRZEBIEGI", routes_content))

	_active_list = VBoxContainer.new()
	side.add_child(_boxed("AKTYWNE PRZEBIEGI", _active_list))

	var side_spacer := Control.new()
	side_spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	side.add_child(side_spacer)

	# --- Linia dialogowa + pole alarmów (docs/14 §1). ---------------------
	var bottom := HBoxContainer.new()
	bottom.add_theme_constant_override("separation", 8)
	root.add_child(bottom)
	var dialog_panel := _panel(COL_BAR_BG)
	dialog_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_dialog_label = Label.new()
	_dialog_label.text = " gotowe"
	dialog_panel.add_child(_dialog_label)
	bottom.add_child(dialog_panel)
	_alarm_panel = _panel(COL_BOX_BG)
	_alarm_panel.custom_minimum_size = Vector2(430, 0)
	var alarm_box := HBoxContainer.new()
	_alarm_label = Label.new()
	_alarm_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_alarm_label.text = " ALARMY: brak"
	alarm_box.add_child(_alarm_label)
	_kwit_button = Button.new()
	_kwit_button.text = "KWIT"
	_kwit_button.pressed.connect(
		func() -> void: action_requested.emit("dsat_ack")
	)
	alarm_box.add_child(_kwit_button)
	_alarm_panel.add_child(alarm_box)
	bottom.add_child(_alarm_panel)

	# --- Pole komunikatów pełną szerokością (rejestr zdarzeń, docs/14 §4).
	_register_text = RichTextLabel.new()
	_register_text.fit_content = false
	_register_text.scroll_following = true
	_register_text.custom_minimum_size = Vector2(0, 108)
	_register_text.add_theme_font_size_override("normal_font_size", 12)
	root.add_child(_boxed("KOMUNIKATY", _register_text))

	set_anchors_preset(Control.PRESET_FULL_RECT)
	custom_minimum_size = Vector2(_plan.custom_minimum_size.x + 450,
		_plan.custom_minimum_size.y + 90)
	refresh()


func refresh() -> void:
	if _world == null:
		return
	_plan.refresh()
	# Polecenie oczekujące na potwierdzenie.
	if _world.pending_confirm.is_empty():
		_pending_label.text = "— brak —"
		_confirm_button.disabled = true
		_cancel_button.disabled = true
	else:
		_pending_label.text = "Wykonać: %s %s ?" % [
			_world.pending_confirm["name"],
			JSON.stringify(_world.pending_confirm["args"]),
		]
		_confirm_button.disabled = false
		_cancel_button.disabled = false
	# Aktywne przebiegi: stan + cofnięcie.
	for child: Node in _active_list.get_children():
		child.queue_free()
	for route_id: StringName in _world.interlocking.routes:
		var route: Route = _world.interlocking.routes[route_id]
		if route.state == Const.RouteState.IDLE:
			continue
		var row := HBoxContainer.new()
		var label := Label.new()
		label.text = "%s (%s)" % [route.id, Const.route_state_name(route.state)]
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(label)
		if route.state == Const.RouteState.LOCKED:
			var cancel := Button.new()
			cancel.text = "Cofnij"
			var signal_string := String(route.entry_signal)
			cancel.pressed.connect(
				func() -> void: action_requested.emit("signal_cancel:%s" % signal_string)
			)
			row.add_child(cancel)
		_active_list.add_child(row)
	if _world.interlocking.pending_route_id != &"":
		var pending := Label.new()
		pending.text = "%s (układanie drogi…)" % _world.interlocking.pending_route_id
		_active_list.add_child(pending)
	# Pole komunikatów (rejestr zdarzeń) + zegar stanowiska.
	var lines: Array[String] = []
	for entry: Dictionary in _world.register.last(REGISTER_LINES):
		lines.append(EventRegister.format_line(entry))
	_register_text.text = "\n".join(lines)
	var total: int = int(_world.time_of_day_s()) % 86400
	@warning_ignore("integer_division")
	var clock_h: int = total / 3600
	@warning_ignore("integer_division")
	var clock_m: int = (total % 3600) / 60
	_clock_label.text = "  %02d:%02d:%02d  " % [clock_h, clock_m, total % 60]
	_refresh_dialog_line()
	_refresh_alarms()


## Linia dialogowa: uzbrojone polecenie > potwierdzenie > ostatni wpis.
func _refresh_dialog_line() -> void:
	if not _armed.is_empty():
		_dialog_label.text = " " + String(ARMED_LABELS[_armed])
		_dialog_label.add_theme_color_override("font_color", COL_ACCENT)
		return
	if not _world.pending_confirm.is_empty():
		_dialog_label.text = " polecenie %s czeka na potwierdzenie [Tak/Nie]" \
			% _world.pending_confirm["name"]
		_dialog_label.add_theme_color_override("font_color", Color(1, 0.72, 0.35))
		return
	_dialog_label.add_theme_color_override("font_color", Color(0.6, 0.65, 0.7))
	var last := _world.register.last(1)
	_dialog_label.text = " gotowe" if last.is_empty() \
		else " " + EventRegister.format_line(last[0])


## Pole alarmów (docs/14 §1): dSAT do skwitowania, awarie przejazdów
## i blokad — czerwone, migające do obsłużenia.
func _refresh_alarms() -> void:
	var alarms: Array[String] = []
	if _world.dsat_unacked():
		alarms.append("dSAT do skwitowania")
	for crossing_id: StringName in _world.crossings:
		if (_world.crossings[crossing_id] as LevelCrossing).state \
				== LevelCrossing.State.FAILURE:
			alarms.append("awaria przejazdu %s" % crossing_id)
	for block_id: StringName in _world.block_lines:
		if (_world.block_lines[block_id] as BlockLine).failed:
			alarms.append("awaria blokady %s" % block_id)
	if alarms.is_empty():
		_alarm_label.text = " ALARMY: brak"
		_alarm_label.add_theme_color_override("font_color", Color(0.45, 0.5, 0.55))
		_kwit_button.disabled = true
		return
	var blink_on := fmod(Time.get_ticks_msec() / 1000.0, 1.0) < 0.5
	_alarm_label.text = " ALARM: " + "; ".join(alarms)
	_alarm_label.add_theme_color_override("font_color",
		COL_ALARM if blink_on else Color(0.5, 0.2, 0.18))
	_kwit_button.disabled = not _world.dsat_unacked()


## Klik semafora na planie: adresuje uzbrojone polecenie menu albo
## filtruje listę przebiegów (docs/14 §3).
func _on_plan_signal_clicked(signal_id: StringName) -> void:
	if not _armed.is_empty():
		match _armed:
			"sz":
				action_requested.emit("sub_signal:%s" % signal_id)
			"cancel":
				action_requested.emit("signal_cancel:%s" % signal_id)
			"dzw":
				# dZw: uzbrojenie w rdzeniu + wskazanie semafora przebiegu.
				action_requested.emit("route_emergency_release")
				action_requested.emit("route_start:%s" % signal_id)
		_set_armed("")
		return
	_filter_signal = &"" if _filter_signal == signal_id else signal_id
	for entry: Dictionary in _route_buttons:
		(entry["button"] as Button).visible = \
			_filter_signal == &"" or entry["entry"] == _filter_signal
	_routes_hint.text = "klik w semafor na planie = filtr początku drogi" \
		if _filter_signal == &"" \
		else "przebiegi od %s (klik ponownie = wszystkie)" % _filter_signal


func _add_menu_button(parent: Control, command: String, text: String) -> void:
	var button := Button.new()
	button.text = text
	button.toggle_mode = true
	button.pressed.connect(func() -> void:
		_set_armed("" if _armed == command else command)
	)
	parent.add_child(button)
	_menu_buttons[command] = button


## Uzbrojenie polecenia menu (drugi klik pozycji = rezygnacja).
func _set_armed(command: String) -> void:
	_armed = command
	for key: String in _menu_buttons:
		(_menu_buttons[key] as Button).set_pressed_no_signal(key == command)
	_refresh_dialog_line()


func _panel(bg: Color) -> PanelContainer:
	var panel := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = bg
	style.border_color = COL_BOX_EDGE
	style.set_border_width_all(1)
	style.set_content_margin_all(6)
	panel.add_theme_stylebox_override("panel", style)
	return panel


## Kaseta panelu bocznego z tytułem (rama jak w oknach stanowiska).
func _boxed(title: String, content: Control) -> PanelContainer:
	var panel := _panel(COL_BOX_BG)
	var vbox := VBoxContainer.new()
	var header := Label.new()
	header.text = title
	header.add_theme_font_size_override("font_size", 12)
	header.add_theme_color_override("font_color", COL_ACCENT)
	vbox.add_child(header)
	content.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(content)
	panel.add_child(vbox)
	return panel
