extends Control
## Scena główna Fazy 0: zegar symulacji + sterowanie mnożnikiem czasu i pauzą.
## UI tylko wyświetla stan i wysyła polecenia do autoloadów (CLAUDE.md, zasada 3).

## Rdzeń symulacji (w F0 tylko liczy ticki — dowód separacji rdzeń/UI).
var _world: SimWorld = SimWorld.new()

@onready var _clock_label: Label = %ClockLabel
@onready var _status_label: Label = %StatusLabel
@onready var _pause_button: Button = %PauseButton
@onready var _speed_buttons: Dictionary = {
	1: %Speed1Button,
	2: %Speed2Button,
	5: %Speed5Button,
}


func _ready() -> void:
	GameState.new_game("", 0)
	SimClock.tick.connect(_on_sim_tick)
	SimClock.multiplier_changed.connect(_on_multiplier_changed)
	SimClock.paused_changed.connect(_on_paused_changed)
	_pause_button.pressed.connect(SimClock.toggle_paused)
	for m: int in _speed_buttons:
		var button: Button = _speed_buttons[m]
		button.pressed.connect(SimClock.set_multiplier.bind(m))
	_refresh_clock()
	_refresh_controls()


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


func _on_sim_tick(dt: float) -> void:
	_world.tick(dt)
	_refresh_clock()
	# Licznik ticków w pasku stanu ma żyć razem z zegarem.
	_refresh_controls()


func _on_multiplier_changed(_multiplier: int) -> void:
	_refresh_controls()


func _on_paused_changed(_paused: bool) -> void:
	_refresh_controls()


func _refresh_clock() -> void:
	_clock_label.text = _format_time_of_day(GameState.time_of_day_s())


func _refresh_controls() -> void:
	_pause_button.text = "▶ Wznów (Spacja)" if SimClock.paused else "⏸ Pauza (Spacja)"
	for m: int in _speed_buttons:
		var button: Button = _speed_buttons[m]
		button.disabled = (m == SimClock.multiplier)
	var state := "PAUZA" if SimClock.paused else "×%d" % SimClock.multiplier
	_status_label.text = "Czas symulacji: %s   |   Ticki: %d" % [state, SimClock.tick_count]


## Formatuje sekundy doby jako HH:MM:SS (zawija po północy).
func _format_time_of_day(seconds_of_day: float) -> String:
	var total: int = int(seconds_of_day) % 86400
	@warning_ignore("integer_division")
	var h: int = total / 3600
	@warning_ignore("integer_division")
	var m: int = (total % 3600) / 60
	var s: int = total % 60
	return "%02d:%02d:%02d" % [h, m, s]
