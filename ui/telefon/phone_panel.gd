class_name PhonePanel
extends PanelContainer
## Okno łączności zapowiadawczej (docs/05 §5, docs/systemy/18 §2):
## rozmowa = złożenie formuły z klocków (typ, nr pociągu, sąsiad),
## nie wolne pisanie. Transkrypt telefonogramów z rejestru rdzenia.

var _world: SimWorld = null
var _transcript: RichTextLabel = null
var _type_select: OptionButton = null
var _train_select: OptionButton = null
var _neighbour_select: OptionButton = null
var _last_log_size: int = -1


func build(world: SimWorld) -> void:
	_world = world
	for child: Node in get_children():
		child.queue_free()
	var vbox := VBoxContainer.new()
	vbox.custom_minimum_size = Vector2(380.0, 0.0)
	add_child(vbox)

	var title := Label.new()
	title.text = "ŁĄCZNOŚĆ ZAPOWIADAWCZA"
	title.add_theme_font_size_override("font_size", 15)
	vbox.add_child(title)

	_transcript = RichTextLabel.new()
	_transcript.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_transcript.scroll_following = true
	_transcript.add_theme_font_size_override("normal_font_size", 13)
	vbox.add_child(_transcript)

	_type_select = OptionButton.new()
	for type: StringName in Comms.TYPES:
		_type_select.add_item(String(Comms.TYPE_LABELS[type]))
	vbox.add_child(_type_select)

	var row := HBoxContainer.new()
	vbox.add_child(row)
	_train_select = OptionButton.new()
	_train_select.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if _world.timetable != null:
		for entry: Timetable.Entry in _world.timetable.entries:
			_train_select.add_item(entry.nr)
	row.add_child(_train_select)
	_neighbour_select = OptionButton.new()
	_neighbour_select.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for ai: NeighbourAI in _world.neighbours:
		_neighbour_select.add_item(ai.neighbour_name)
	row.add_child(_neighbour_select)

	var send := Button.new()
	send.text = "Nadaj telefonogram"
	send.pressed.connect(_on_send)
	vbox.add_child(send)
	refresh()


func refresh() -> void:
	if _world == null or _world.comms.log.size() == _last_log_size:
		return
	_last_log_size = _world.comms.log.size()
	_transcript.clear()
	for message: Comms.Message in _world.comms.log:
		var who := message.from_name.to_upper()
		var color := "e8b06a" if message.incoming else "9fd6a4"
		_transcript.append_text("[color=#8a8a8a]%s[/color] [color=#%s]%s:[/color] %s\n"
			% [Comms.format_time(message.time_s), color, who, message.text])


func _on_send() -> void:
	if _type_select.selected < 0 or _train_select.selected < 0 \
			or _neighbour_select.selected < 0:
		return
	EventBus.send_command(&"phone_send", {
		"type": String(Comms.TYPES[_type_select.selected]),
		"nr": _train_select.get_item_text(_train_select.selected),
		"neighbour": _neighbour_select.get_item_text(_neighbour_select.selected),
	})
