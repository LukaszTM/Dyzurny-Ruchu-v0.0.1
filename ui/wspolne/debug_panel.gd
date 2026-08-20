class_name DebugPanel
extends PanelContainer
## Tryb „debug" Fazy 2 (roadmapa F2): boczny panel stanu rdzenia —
## sekcje (z ręcznym zadawaniem zajętości), zwrotnice, sygnalizatory.
## Panel tylko czyta stan i wysyła akcje — jak każdy widok (docs/02).

## Akcja w formacie "polecenie:argument" (jak akcje pulpitu).
signal action_requested(action: String)

var _graph: TrackGraph = null
var _section_labels: Dictionary = {}
var _section_buttons: Dictionary = {}
var _turnout_labels: Dictionary = {}
var _signal_labels: Dictionary = {}


func build(station: StationData) -> void:
	_graph = station.graph
	for child: Node in get_children():
		child.queue_free()
	_section_labels.clear()
	_section_buttons.clear()
	_turnout_labels.clear()
	_signal_labels.clear()

	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(320.0, 0.0)
	add_child(scroll)
	var vbox := VBoxContainer.new()
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(vbox)

	_add_header(vbox, "DEBUG — STAN RDZENIA")
	_add_header(vbox, "Sekcje")
	for section_id: StringName in _graph.sections:
		var row := HBoxContainer.new()
		vbox.add_child(row)
		var label := Label.new()
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(label)
		_section_labels[section_id] = label
		var button := Button.new()
		button.pressed.connect(_on_section_toggle.bind(section_id))
		row.add_child(button)
		_section_buttons[section_id] = button

	_add_header(vbox, "Zwrotnice")
	for turnout_id: StringName in _graph.turnouts:
		var row := HBoxContainer.new()
		vbox.add_child(row)
		var label := Label.new()
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(label)
		_turnout_labels[turnout_id] = label
		var button := Button.new()
		button.text = "Przestaw"
		button.pressed.connect(
			func() -> void: action_requested.emit("turnout_throw:%s" % turnout_id)
		)
		row.add_child(button)

	_add_header(vbox, "Sygnalizatory")
	for signal_id: StringName in _graph.signals:
		var label := Label.new()
		vbox.add_child(label)
		_signal_labels[signal_id] = label

	refresh()


func refresh() -> void:
	if _graph == null:
		return
	for section_id: StringName in _section_labels:
		var section: Section = _graph.get_section(section_id)
		var state := "ZAJĘTA" if section.occupied else "wolna"
		if section.is_locked():
			state += " • utw. %s" % section.locked_by
		(_section_labels[section_id] as Label).text = "%s — %s" % [section_id, state]
		(_section_buttons[section_id] as Button).text = "Zwolnij" if section.occupied else "Zajmij"
	for turnout_id: StringName in _turnout_labels:
		var turnout: Turnout = _graph.get_turnout(turnout_id)
		var state_name: String = Const.TurnoutState.keys()[turnout.state]
		if turnout.state == Const.TurnoutState.MOVING:
			state_name += " (%.1f s)" % turnout.move_left_s
		(_turnout_labels[turnout_id] as Label).text = "%s — %s" % [turnout_id, state_name]
	for signal_id: StringName in _signal_labels:
		var signal_device: SignalDevice = _graph.get_signal(signal_id)
		(_signal_labels[signal_id] as Label).text = "%s — %s" % [signal_id, signal_device.aspect]


func _add_header(parent: Control, text: String) -> void:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", 15)
	parent.add_child(label)


func _on_section_toggle(section_id: StringName) -> void:
	var section: Section = _graph.get_section(section_id)
	var target := "0" if section.occupied else "1"
	action_requested.emit("debug_section_occupied:%s:%s" % [section_id, target])
