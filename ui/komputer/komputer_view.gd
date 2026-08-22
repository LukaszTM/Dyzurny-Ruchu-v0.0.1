class_name KomputerView
extends Control
## Minimalny widok komputerowych urządzeń nastawczych (docs/systemy/14) —
## REFERENCYJNY: plan synoptyczny współdzieli renderer pulpitu, a panel
## boczny pokazuje mechaniki rdzenia (nastawianie przebiegowe, polecenia
## dwustopniowe, rejestr zdarzeń). Docelowe GUI buduje użytkownik na tym
## samym API (docs/07-interfejs-gui.md); ten widok dokumentuje przepływy.

## Akcja w formacie "polecenie:arg[:arg2]" — jak na pulpicie.
signal action_requested(action: String)

## Liczba linii rejestru widocznych w panelu.
const REGISTER_LINES: int = 14

var _world: SimWorld = null
var _plan: PulpitView = null
var _pending_label: Label = null
var _confirm_button: Button = null
var _cancel_button: Button = null
var _active_list: VBoxContainer = null
var _register_text: RichTextLabel = null


func build_view(world: SimWorld) -> void:
	_world = world
	var root := HBoxContainer.new()
	root.add_theme_constant_override("separation", 12)
	add_child(root)

	# Plan stacji (schemat synoptyczny) — renderer kafelkowy jako referencja.
	_plan = PulpitView.new()
	_plan.build(world.station, world.interlocking, world.block_lines, world)
	_plan.action_requested.connect(func(action: String) -> void:
		action_requested.emit(action)
	)
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


func _header(text: String) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", 13)
	label.add_theme_color_override("font_color", Color(0.65, 0.72, 0.8))
	return label
