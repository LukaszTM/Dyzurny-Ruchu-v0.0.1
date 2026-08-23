class_name KomputerView
extends Control
## Minimalny widok komputerowych urządzeń nastawczych (docs/systemy/14) —
## REFERENCYJNY: ciemny plan synoptyczny w konwencji barw CBI (docs/14 §2),
## panel boczny pokazuje mechaniki rdzenia (nastawianie przebiegowe,
## polecenia dwustopniowe, rejestr zdarzeń). Klik w semafor na planie
## filtruje listę przebiegów od tego semafora (docs/14 §3 — „klik semafora
## początkowego"). Docelowe GUI buduje użytkownik na tym samym API
## (docs/07-interfejs-gui.md); ten widok dokumentuje przepływy.

## Akcja w formacie "polecenie:arg[:arg2]" — jak na pulpicie.
signal action_requested(action: String)

## Liczba linii rejestru widocznych w panelu.
const REGISTER_LINES: int = 14

const COL_VIEW_BG := Color("101318")

var _world: SimWorld = null
var _plan: KomputerPlan = null
var _pending_label: Label = null
var _confirm_button: Button = null
var _cancel_button: Button = null
var _active_list: VBoxContainer = null
var _register_text: RichTextLabel = null
var _routes_hint: Label = null
## Przyciski przebiegów wg semafora początkowego (filtr po kliku w plan).
var _route_buttons: Array[Dictionary] = []
var _filter_signal: StringName = &""


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), COL_VIEW_BG)


func build_view(world: SimWorld) -> void:
	_world = world
	var root := HBoxContainer.new()
	root.add_theme_constant_override("separation", 12)
	add_child(root)

	# Plan stacji: ciemny schemat synoptyczny (KomputerPlan, docs/14 §2).
	_plan = KomputerPlan.new()
	_plan.build(world.station, world.interlocking, world.block_lines, world)
	_plan.action_requested.connect(func(action: String) -> void:
		action_requested.emit(action)
	)
	_plan.signal_clicked.connect(_on_plan_signal_clicked)
	root.add_child(_plan)

	var side := VBoxContainer.new()
	side.custom_minimum_size = Vector2(420, 0)
	side.add_theme_constant_override("separation", 8)
	root.add_child(side)

	# Polecenia dwustopniowe (docs/14 §3): okno „Wykonać? [Tak/Nie]".
	side.add_child(_header("POLECENIE SPECJALNE"))
	_pending_label = Label.new()
	_pending_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_pending_label.text = "—"
	side.add_child(_pending_label)
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
	side.add_child(confirm_row)

	# Nastawianie przebiegowe (docs/14 §5): przebieg z listy, zwrotnice same.
	side.add_child(_header("PRZEBIEGI (nastawianie przebiegowe)"))
	_routes_hint = Label.new()
	_routes_hint.add_theme_font_size_override("font_size", 11)
	_routes_hint.add_theme_color_override("font_color", Color(0.55, 0.6, 0.66))
	_routes_hint.text = "klik w semafor na planie = filtr początku drogi"
	side.add_child(_routes_hint)
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
	side.add_child(routes_grid)

	# Aktywne przebiegi z możliwością zwolnienia (docs/14 §5).
	side.add_child(_header("AKTYWNE PRZEBIEGI"))
	_active_list = VBoxContainer.new()
	side.add_child(_active_list)

	# Rejestr zdarzeń (docs/14 §4).
	side.add_child(_header("REJESTR ZDARZEŃ"))
	_register_text = RichTextLabel.new()
	_register_text.fit_content = false
	_register_text.scroll_following = true
	_register_text.custom_minimum_size = Vector2(0, 220)
	_register_text.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_register_text.add_theme_font_size_override("normal_font_size", 12)
	side.add_child(_register_text)

	custom_minimum_size = Vector2(
		_plan.custom_minimum_size.x + 440, _plan.custom_minimum_size.y
	)
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
	# Aktywne przebiegi: stan + cofnięcie przebiegu przyciskiem semafora.
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
	# Rejestr zdarzeń — ostatnie wpisy.
	var lines: Array[String] = []
	for entry: Dictionary in _world.register.last(REGISTER_LINES):
		lines.append(EventRegister.format_line(entry))
	_register_text.text = "\n".join(lines)


## Klik w semafor na planie: filtr listy przebiegów od tego semafora;
## ponowny klik w ten sam = pokaż wszystkie (docs/14 §3).
func _on_plan_signal_clicked(signal_id: StringName) -> void:
	_filter_signal = &"" if _filter_signal == signal_id else signal_id
	for entry: Dictionary in _route_buttons:
		(entry["button"] as Button).visible = \
			_filter_signal == &"" or entry["entry"] == _filter_signal
	_routes_hint.text = "klik w semafor na planie = filtr początku drogi" \
		if _filter_signal == &"" \
		else "przebiegi od %s (klik ponownie = wszystkie)" % _filter_signal


func _header(text: String) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", 13)
	label.add_theme_color_override("font_color", Color(0.65, 0.72, 0.8))
	return label
