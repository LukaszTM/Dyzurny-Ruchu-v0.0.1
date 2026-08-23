extends Control
## Scena główna: wybór scenariusza, potem widok urządzeń wg typu panelu
## stacji — pulpit kostkowy (przekaźnikowe) albo nastawnia mechaniczna
## (dźwignie, docs/systemy/12). UI wysyła polecenia przez EventBus;
## właścicielem rdzenia (SimWorld) jest ta scena (docs/02-architektura.md).

const SCENARIOS_DIR := "res://data/scenarios"
## Jak długo pokazujemy komunikat odmowy (s czasu rzeczywistego).
const MESSAGE_TIME_S: float = 4.0

var _world: SimWorld = SimWorld.new()
var _message_left_s: float = 0.0
var _started: bool = false
## Bieżący widok urządzeń (PulpitView / MechView / KomputerView).
var _view: Control = null
## Odtwarzacze dźwięków gry (nazwa -> AudioStreamPlayer).
var _sounds: Dictionary = {}
## Nakładka samouczka (tworzona przy scenariuszu z sekcją "tutorial").
var _tutorial_panel: PanelContainer = null
var _tutorial_label: Label = null

@onready var _plaque_label: Label = %PlaqueLabel
@onready var _clock_label: Label = %ClockLabel
@onready var _status_label: Label = %StatusLabel
@onready var _message_label: Label = %MessageLabel
@onready var _pause_button: Button = %PauseButton
@onready var _debug_toggle: CheckButton = %DebugToggle
@onready var _view_center: CenterContainer = %ViewCenter
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
	SimClock.paused = true
	_setup_audio()
	_show_scenario_picker(_list_scenarios())


## Dźwięki gry (assets/audio, syntezowane — tools/gen_sounds.py).
func _setup_audio() -> void:
	for sound_name: String in ["phone_ring", "buzzer", "click", "ding"]:
		var path := "res://assets/audio/%s.wav" % sound_name
		if not ResourceLoader.exists(path):
			continue
		var player := AudioStreamPlayer.new()
		player.stream = load(path)
		add_child(player)
		_sounds[sound_name] = player


func _play(sound_name: String) -> void:
	var player: AudioStreamPlayer = _sounds.get(sound_name)
	if player != null:
		player.play()


## Lista scenariuszy z data/scenarios (dane, nie kod — CLAUDE.md zasada 4).
func _list_scenarios() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var dir := DirAccess.open(SCENARIOS_DIR)
	if dir == null:
		return result
	for file_name: String in dir.get_files():
		if not file_name.ends_with(".json"):
			continue
		var path := "%s/%s" % [SCENARIOS_DIR, file_name]
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
		if parsed is Dictionary:
			var meta: Dictionary = (parsed as Dictionary).get("meta", {})
			result.append({
				"path": path,
				"name": String(meta.get("name", file_name)),
				"description": String(meta.get("description", "")),
				"is_tutorial": (parsed as Dictionary).has("tutorial"),
			})
	# Lekcje samouczka przed służbami, w kolejności plików.
	result.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		if a["is_tutorial"] != b["is_tutorial"]:
			return bool(a["is_tutorial"])
		return String(a["path"]) < String(b["path"])
	)
	return result


## Menu główne (F10 „szlif"): lista służb z opisami, wznowienie zapisu,
## ustawienia głośności. Dane z data/scenarios (dane, nie kod).
func _show_scenario_picker(scenarios: Array[Dictionary]) -> void:
	var dim := ColorRect.new()
	dim.name = "ScenarioPicker"
	dim.color = Color(0.04, 0.045, 0.06)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.add_child(center)
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 10)
	center.add_child(vbox)
	var title := Label.new()
	title.text = "SYMULATOR DYŻURNEGO RUCHU"
	title.add_theme_font_size_override("font_size", 34)
	vbox.add_child(title)
	var subtitle := Label.new()
	subtitle.text = "wybierz służbę"
	subtitle.add_theme_font_size_override("font_size", 15)
	subtitle.add_theme_color_override("font_color", Color(0.55, 0.6, 0.68))
	vbox.add_child(subtitle)
	vbox.add_child(HSeparator.new())
	var last_group := ""
	for scenario: Dictionary in scenarios:
		var group := "SAMOUCZEK" if bool(scenario.get("is_tutorial", false)) else "SŁUŻBY"
		if group != last_group:
			last_group = group
			var header := Label.new()
			header.text = group
			header.add_theme_font_size_override("font_size", 13)
			header.add_theme_color_override("font_color", Color(0.5, 0.62, 0.78))
			vbox.add_child(header)
		var path := String(scenario["path"])
		var scenario_id := path.get_file().get_basename()
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 12)
		var texts := VBoxContainer.new()
		texts.custom_minimum_size = Vector2(560, 0)
		texts.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var name_label := Label.new()
		name_label.text = String(scenario["name"])
		name_label.add_theme_font_size_override("font_size", 21)
		texts.add_child(name_label)
		var desc := Label.new()
		desc.text = String(scenario["description"])
		desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		desc.add_theme_font_size_override("font_size", 12)
		desc.add_theme_color_override("font_color", Color(0.55, 0.6, 0.68))
		texts.add_child(desc)
		row.add_child(texts)
		var start := Button.new()
		start.text = "Rozpocznij"
		start.custom_minimum_size = Vector2(130, 0)
		start.pressed.connect(func() -> void:
			_play("click")
			dim.queue_free()
			_start_scenario(path)
		)
		row.add_child(start)
		var resume := Button.new()
		resume.text = "Wznów zapis"
		resume.custom_minimum_size = Vector2(130, 0)
		resume.disabled = not GameState.has_save(scenario_id)
		resume.pressed.connect(func() -> void:
			_play("click")
			dim.queue_free()
			_start_scenario(path, true)
		)
		row.add_child(resume)
		vbox.add_child(row)
	vbox.add_child(HSeparator.new())
	# Ustawienia: głośność (magistrala Master); w grze F5 zapis / F9 odczyt.
	var settings := HBoxContainer.new()
	settings.add_theme_constant_override("separation", 12)
	var volume_label := Label.new()
	volume_label.text = "Głośność"
	volume_label.add_theme_font_size_override("font_size", 13)
	settings.add_child(volume_label)
	var volume := HSlider.new()
	volume.min_value = 0.0
	volume.max_value = 1.0
	volume.step = 0.05
	volume.value = db_to_linear(AudioServer.get_bus_volume_db(0))
	volume.custom_minimum_size = Vector2(220, 0)
	volume.value_changed.connect(func(v: float) -> void:
		AudioServer.set_bus_volume_db(0, linear_to_db(maxf(v, 0.001)))
		AudioServer.set_bus_mute(0, v <= 0.0)
	)
	settings.add_child(volume)
	var hint := Label.new()
	hint.text = "w grze: Spacja pauza · 1/2/5 tempo · F5 zapis · F9 wczytanie · T telefon · D dziennik · R rozkazy"
	hint.add_theme_font_size_override("font_size", 12)
	hint.add_theme_color_override("font_color", Color(0.45, 0.5, 0.58))
	settings.add_child(hint)
	vbox.add_child(settings)


func _start_scenario(path: String, resume: bool = false) -> void:
	var result := _world.load_scenario_file(path)
	if not result["ok"]:
		push_error("Błąd wczytywania scenariusza: %s" % [result["errors"]])
		_show_message("BŁĄD SCENARIUSZA: %s" % [result["errors"]])
		return
	var scenario_id := path.get_file().get_basename()
	GameState.new_game(scenario_id, 0, _world.start_of_day_s)
	_world.rng = GameState.rng
	if resume and GameState.load_game(_world):
		_show_message("Wznowiono zapisaną służbę")
	_plaque_label.text = _world.station.display_name().to_upper()

	# Widok urządzeń wg typu panelu stacji (jedna logika, różne „skóry").
	if _world.lever_frame != null:
		var mech := MechView.new()
		mech.build_view(_world)
		mech.action_requested.connect(
			func(command_name: StringName, args: Dictionary) -> void:
				EventBus.send_command(command_name, args)
		)
		_view = mech
	elif _world.confirm_mode:
		var komputer := KomputerView.new()
		komputer.build_view(_world)
		komputer.action_requested.connect(_on_ui_action)
		_view = komputer
	else:
		var pulpit := PulpitView.new()
		pulpit.build(_world.station, _world.interlocking, _world.block_lines, _world)
		pulpit.action_requested.connect(_on_ui_action)
		_view = pulpit
	_view_center.add_child(_view)

	_debug_panel.build(_world.station, _world.interlocking, _world)
	_phone_panel.build(_world)
	_dziennik_panel.build(_world)
	_orders_panel.build(_world)

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

	_debug_panel.action_requested.connect(_on_ui_action)
	EventBus.command.connect(_on_command)

	_started = true
	SimClock.paused = false
	_refresh_clock()
	_refresh_controls()


func _process(delta: float) -> void:
	if _message_left_s > 0.0:
		_message_left_s -= delta
		if _message_left_s <= 0.0:
			_message_label.text = ""


func _unhandled_key_input(event: InputEvent) -> void:
	if not _started:
		return
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
		KEY_F5:
			if GameState.save_game(_world):
				_show_message("Zapisano grę (wczytanie: F9)")
		KEY_F9:
			if GameState.load_game(_world):
				_show_message("Wczytano zapis")
				_refresh_views()
			else:
				_show_message("Brak zapisu dla tego scenariusza")


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
	if not String(name).begins_with("debug_"):
		_play("click")
	var result := _world.execute(name, args)
	EventBus.emit_command_result(name, result.ok, result.reason)
	if not result.ok:
		# Urządzenie „nie reaguje"; w trybie szkolenia pokazujemy przyczynę
		# (docs/systemy/13 §2, assets-spec/22 §2).
		_show_message(result.reason)
	_refresh_views()


func _on_sim_tick(dt: float) -> void:
	_world.tick(dt)
	_dispatch_world_events()
	_refresh_clock()
	_refresh_controls()
	_refresh_views()


## Rozprowadza zdarzenia rdzenia: scoring do GameState, dzwonek telefonu,
## alarmy, koniec zmiany (podsumowanie) — i publikuje je na szynie zdarzeń.
func _dispatch_world_events() -> void:
	for event: Dictionary in _world.drain_events():
		var type: StringName = event["type"]
		EventBus.emit_sim_event(type, event)
		match type:
			&"penalty":
				GameState.add_penalty(int(event["points"]), String(event["reason"]))
				_show_message("KARA −%d: %s" % [int(event["points"]), String(event["reason"])])
				_play("buzzer")
			&"alarm":
				_show_message(String(event["text"]), 8.0)
				_play("buzzer")
			&"phone_ring":
				_play("phone_ring")
			&"tutorial_step":
				_show_tutorial_step(event)
			&"tutorial_done":
				if _tutorial_label != null:
					_tutorial_label.text = "✔ %s\n%s" % [
						String(event.get("title", "Samouczek")), String(event["text"])]
					_play("ding")
					get_tree().create_timer(12.0).timeout.connect(func() -> void:
						if _tutorial_panel != null:
							_tutorial_panel.visible = false
					)
			&"shift_end":
				_play("ding")
				_show_shift_summary()
			_:
				pass


## Nakładka samouczka: krok z licznikiem, u góry ekranu pod paskiem.
func _show_tutorial_step(event: Dictionary) -> void:
	if _tutorial_panel == null:
		_tutorial_panel = PanelContainer.new()
		var style := StyleBoxFlat.new()
		style.bg_color = Color(0.09, 0.11, 0.15, 0.96)
		style.border_color = Color(0.35, 0.55, 0.8)
		style.set_border_width_all(2)
		style.set_content_margin_all(12)
		_tutorial_panel.add_theme_stylebox_override("panel", style)
		_tutorial_panel.position = Vector2(24, 56)
		_tutorial_panel.custom_minimum_size = Vector2(560, 0)
		_tutorial_label = Label.new()
		_tutorial_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_tutorial_label.custom_minimum_size = Vector2(536, 0)
		_tutorial_panel.add_child(_tutorial_label)
		add_child(_tutorial_panel)
	_tutorial_panel.visible = true
	_tutorial_label.text = "%s — KROK %d/%d\n%s" % [
		String(event.get("title", "Samouczek")), int(event["index"]),
		int(event["total"]), String(event["text"]),
	]


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
	if _view != null:
		_view.refresh()
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
