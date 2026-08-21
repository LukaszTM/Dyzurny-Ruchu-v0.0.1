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
	_pulpit.build(_world.station, _world.interlocking)
	_debug_panel.build(_world.station, _world.interlocking, _world)

	SimClock.tick.connect(_on_sim_tick)
	SimClock.multiplier_changed.connect(func(_m: int) -> void: _refresh_controls())
	SimClock.paused_changed.connect(func(_p: bool) -> void: _refresh_controls())
	_pause_button.pressed.connect(SimClock.toggle_paused)
	for m: int in _speed_buttons:
		var button: Button = _speed_buttons[m]
		button.pressed.connect(SimClock.set_multiplier.bind(m))
	_debug_toggle.toggled.connect(func(on: bool) -> void: _debug_panel.visible = on)

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
	_refresh_clock()
	_refresh_controls()
	_refresh_views()


func _refresh_views() -> void:
	_pulpit.refresh()
	if _debug_panel.visible:
		_debug_panel.refresh()


func _refresh_clock() -> void:
	_clock_label.text = _format_time_of_day(GameState.time_of_day_s())


func _refresh_controls() -> void:
	_pause_button.text = "▶ Wznów" if SimClock.paused else "⏸ Pauza"
	for m: int in _speed_buttons:
		var button: Button = _speed_buttons[m]
		button.disabled = (m == SimClock.multiplier)
	var state := "PAUZA" if SimClock.paused else "×%d" % SimClock.multiplier
	_status_label.text = "%s | ticki: %d" % [state, SimClock.tick_count]


func _show_message(text: String) -> void:
	_message_label.text = text
	_message_left_s = MESSAGE_TIME_S


## Formatuje sekundy doby jako HH:MM:SS (zawija po północy).
func _format_time_of_day(seconds_of_day: float) -> String:
	var total: int = int(seconds_of_day) % 86400
	@warning_ignore("integer_division")
	var h: int = total / 3600
	@warning_ignore("integer_division")
	var m: int = (total % 3600) / 60
	var s: int = total % 60
	return "%02d:%02d:%02d" % [h, m, s]
