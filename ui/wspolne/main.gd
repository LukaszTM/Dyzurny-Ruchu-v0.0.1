extends Control
## Scena główna F2: pulpit kostkowy stacji Borki + pas górny (tabliczka,
## zegary, sterowanie czasem) + panel debug. UI wysyła polecenia przez
## EventBus; właścicielem rdzenia (SimWorld) jest ta scena i tylko ona
## wykonuje polecenia na rdzeniu (docs/02-architektura.md).

const SCENARIO_PATH := "res://data/scenarios/borki-poranek.json"
## Jak długo pokazujemy komunikat odmowy (s czasu rzeczywistego).
const MESSAGE_TIME_S: float = 4.0

var _world: SimWorld = SimWorld.new()
var _message_left_s: float = 0.0

@onready var _plaque_label: Label = %PlaqueLabel
@onready var _clock_label: Label = %ClockLabel
@onready var _status_label: Label = %StatusLabel
@onready var _message_label: Label = %MessageLabel
@onready var _pause_button: Button = %PauseButton
@onready var _debug_toggle: CheckButton = %DebugToggle
@onready var _pulpit: PulpitView = %Pulpit
@onready var _debug_panel: DebugPanel = %DebugPanel
@onready var _phone_panel: PhonePanel = %PhonePanel
@onready var _dziennik_panel: DziennikPanel = %DziennikPanel
@onready var _orders_panel: OrdersPanel = %OrdersPanel
@onready var _phone_button: Button = %PhoneButton
@onready var _dziennik_button: Button = %DziennikButton
@onready var _orders_button: Button = %OrdersButton
@onready var _speed_buttons: Dictionary = {
	1: %Speed1Button,
	2: %Speed2Button,
	5: %Speed5Button,
}


func _ready() -> void:
	var result := _world.load_scenario_file(SCENARIO_PATH)
	if not result["ok"]:
		push_error("Błąd wczytywania scenariusza: %s" % [result["errors"]])
		_show_message("BŁĄD SCENARIUSZA: %s" % [result["errors"]])
		return
	GameState.new_game("borki-poranek", 0, _world.start_of_day_s)
	_plaque_label.text = _world.station.display_name().to_upper()
	_pulpit.build(_world.station, _world.interlocking, _world.block_lines)
	_debug_panel.build(_world.station, _world.interlocking, _world)
	_phone_panel.build(_world)
	_dziennik_panel.build(_world)
	_orders_panel.build(_world)
	# Determinizm: rdzeń losuje wyłącznie z RNG scenariusza (zasada 5).
	_world.rng = GameState.rng

	SimClock.tick.connect(_on_sim_tick)
	SimClock.multiplier_changed.connect(func(_m: int) -> void: _refresh_controls())
	SimClock.paused_changed.connect(func(_p: bool) -> void: _refresh_controls())
	_pause_button.pressed.connect(SimClock.toggle_paused)
	for m: int in _speed_buttons:
		var button: Button = _speed_buttons[m]
		button.pressed.connect(SimClock.set_multiplier.bind(m))
	_debug_toggle.toggled.connect(func(on: bool) -> void: _debug_panel.visible = on)
	_phone_button.pressed.connect(_toggle_phone)
	_dziennik_button.pressed.connect(
		func() -> void: _dziennik_panel.visible = not _dziennik_panel.visible
	)
	_orders_button.pressed.connect(
		func() -> void: _orders_panel.visible = not _orders_panel.visible
	)

	_pulpit.action_requested.connect(_on_ui_action)
	_debug_panel.action_requested.connect(_on_ui_action)
	EventBus.command.connect(_on_command)

	_refresh_clock()
	_refresh_controls()


func _process(delta: float) -> void:
	if _message_left_s > 0.0:
		_message_left_s -= delta
		if _message_left_s <= 0.0:
			_message_label.text = ""


func _unhandled_key_input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if key == null or not key.pressed or key.echo:
		return
	match key.keycode:
		KEY_SPACE:
			SimClock.toggle_paused()
		KEY_1:
			SimClock.set_multiplier(1)
		KEY_2:
			SimClock.set_multiplier(2)
		KEY_5:
			SimClock.set_multiplier(5)
		KEY_F12:
			_debug_toggle.button_pressed = not _debug_toggle.button_pressed
		KEY_T:
			_toggle_phone()
		KEY_D:
			_dziennik_panel.visible = not _dziennik_panel.visible
		KEY_R:
			_orders_panel.visible = not _orders_panel.visible


## Akcja z przycisku pulpitu/panelu debug ("polecenie:arg[:arg2]") →
## polecenie na szynie zdarzeń.
func _on_ui_action(action: String) -> void:
	var parts := action.split(":")
	var args := {}
	if parts.size() > 1:
		args["id"] = parts[1]
	if parts.size() > 2:
		args["value"] = parts[2]
	EventBus.send_command(StringName(parts[0]), args)


## Wykonanie polecenia na rdzeniu — jedyne miejsce zmieniające jego stan.
func _on_command(name: StringName, args: Dictionary) -> void:
	if _world.station == null:
		return
	var result := _world.execute(name, args)
	EventBus.emit_command_result(name, result.ok, result.reason)
	if not result.ok:
		# Urządzenie „nie reaguje"; w trybie szkolenia pokazujemy przyczynę
		# (docs/systemy/13 §2).
		_show_message(result.reason)
	_refresh_views()


func _on_sim_tick(dt: float) -> void:
	_world.tick(dt)
	_dispatch_world_events()
	_refresh_clock()
	_refresh_controls()
	_refresh_views()


## Rozprowadza zdarzenia rdzenia: scoring do GameState, dzwonek telefonu,
## koniec zmiany (podsumowanie) — i publikuje je na szynie zdarzeń.
func _dispatch_world_events() -> void:
	for event: Dictionary in _world.drain_events():
		var type: StringName = event["type"]
		EventBus.emit_sim_event(type, event)
		match type:
			&"penalty":
				GameState.add_penalty(int(event["points"]), String(event["reason"]))
				_show_message("KARA −%d: %s" % [int(event["points"]), String(event["reason"])])
			&"alarm":
				_show_message(String(event["text"]), 8.0)
			&"shift_end":
				_show_shift_summary()
			_:
				pass


func _toggle_phone() -> void:
	_phone_panel.visible = not _phone_panel.visible
	if _phone_panel.visible:
		EventBus.send_command(&"phone_open", {})


## Podsumowanie zmiany (scoring v1, docs/05 §7) — nakładka na koniec służby.
func _show_shift_summary() -> void:
	SimClock.paused = true
	var dim := ColorRect.new()
	dim.color = Color(0.0, 0.0, 0.0, 0.72)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.add_child(center)
	var vbox := VBoxContainer.new()
	center.add_child(vbox)
	var title := Label.new()
	title.text = "KONIEC SŁUŻBY — wynik: %d/100" % GameState.score
	title.add_theme_font_size_override("font_size", 34)
	vbox.add_child(title)
	if GameState.penalties.is_empty():
		var clean := Label.new()
		clean.text = "Zmiana bez uwag. Wzorowa służba!"
		clean.add_theme_font_size_override("font_size", 18)
		vbox.add_child(clean)
	for penalty: Dictionary in GameState.penalties:
		var row := Label.new()
		row.text = "−%d  %s" % [int(penalty["points"]), String(penalty["reason"])]
		row.add_theme_font_size_override("font_size", 16)
		vbox.add_child(row)


func _refresh_views() -> void:
	_pulpit.refresh()
	if _debug_panel.visible:
		_debug_panel.refresh()
	if _phone_panel.visible:
		_phone_panel.refresh()
	if _dziennik_panel.visible:
		_dziennik_panel.refresh()
	if _orders_panel.visible:
		_orders_panel.refresh()
	var unread := _world.comms.unread
	_phone_button.text = "☎ Telefon (T)" if unread == 0 else "☎ TELEFON (%d)" % unread
	_phone_button.modulate = Color(1, 1, 1) if unread == 0 \
		else (Color(1, 0.55, 0.4) if (Time.get_ticks_msec() / 500) % 2 == 0 else Color(1, 1, 1))


func _refresh_clock() -> void:
	_clock_label.text = _format_time_of_day(GameState.time_of_day_s())


func _refresh_controls() -> void:
	_pause_button.text = "▶ Wznów" if SimClock.paused else "⏸ Pauza"
	for m: int in _speed_buttons:
		var button: Button = _speed_buttons[m]
		button.disabled = (m == SimClock.multiplier)
	var state := "PAUZA" if SimClock.paused else "×%d" % SimClock.multiplier
	_status_label.text = "%s | ticki: %d" % [state, SimClock.tick_count]


func _show_message(text: String, time_s: float = MESSAGE_TIME_S) -> void:
	_message_label.text = text
	_message_left_s = time_s


## Formatuje sekundy doby jako HH:MM:SS (zawija po północy).
func _format_time_of_day(seconds_of_day: float) -> String:
	var total: int = int(seconds_of_day) % 86400
	@warning_ignore("integer_division")
	var h: int = total / 3600
	@warning_ignore("integer_division")
	var m: int = (total % 3600) / 60
	var s: int = total % 60
	return "%02d:%02d:%02d" % [h, m, s]
