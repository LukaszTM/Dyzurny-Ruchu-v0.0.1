class_name OrdersPanel
extends PanelContainer
## Bloczek rozkazów pisemnych „S"/„O"/„N" (docs/systemy/18 §5): gracz
## wybiera druk i pozycje, „dyktuje przez radiotelefon" (czas w rdzeniu),
## maszynista powtarza — rozkaz odblokowuje jazdę. Numeracja automatyczna.

const ORDER_TYPES: Array[String] = ["S", "O", "N"]
const ORDER_LABELS: Dictionary = {
	"S": "„S” (R-305) — zezwolenie na minięcie semafora „Stój”",
	"O": "„O” (R-307) — ostrzeżenie / ograniczenie prędkości",
	"N": "„N” (R-306) — jazda po torze lewym (ewidencja)",
}

var _world: SimWorld = null
var _type_select: OptionButton = null
var _train_select: OptionButton = null
var _signal_select: OptionButton = null
var _list: Label = null


func build(world: SimWorld) -> void:
	_world = world
	for child: Node in get_children():
		child.queue_free()
	var vbox := VBoxContainer.new()
	vbox.custom_minimum_size = Vector2(430.0, 0.0)
	add_child(vbox)
	var title := Label.new()
	title.text = "ROZKAZY PISEMNE"
	title.add_theme_font_size_override("font_size", 15)
	vbox.add_child(title)

	_type_select = OptionButton.new()
	for type: String in ORDER_TYPES:
		_type_select.add_item(String(ORDER_LABELS[type]))
	vbox.add_child(_type_select)

	var row := HBoxContainer.new()
	vbox.add_child(row)
	_train_select = OptionButton.new()
	_train_select.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if _world.timetable != null:
		for entry: Timetable.Entry in _world.timetable.entries:
			_train_select.add_item(entry.nr)
	row.add_child(_train_select)
	_signal_select = OptionButton.new()
	_signal_select.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for signal_id: StringName in _world.station.graph.signals:
		var signal_device := _world.station.graph.get_signal(signal_id)
		if signal_device.kind == Const.SignalKind.SEMAFOR:
			_signal_select.add_item(String(signal_id))
	row.add_child(_signal_select)

	var dictate := Button.new()
	dictate.text = "Podyktuj przez radiotelefon"
	dictate.pressed.connect(_on_dictate)
	vbox.add_child(dictate)

	_list = Label.new()
	_list.add_theme_font_size_override("font_size", 12)
	vbox.add_child(_list)
	refresh()


func refresh() -> void:
	if _world == null:
		return
	var lines: Array[String] = []
	for order: Dictionary in _world.orders:
		var status := "AKTYWNY"
		if not bool(order["active"]):
			status = "dyktowanie… %d s" % int(ceil(float(order["left_s"])))
		elif String(order["type"]) == "S":
			status += " (sem. %s)" % order["signal"]
		lines.append("Rozkaz „%s” nr %d — poc. %s — %s"
			% [order["type"], order["no"], order["nr"], status])
	_list.text = "\n".join(lines) if not lines.is_empty() else "(brak wystawionych rozkazów)"


func _on_dictate() -> void:
	if _type_select.selected < 0 or _train_select.selected < 0:
		return
	EventBus.send_command(&"order_dictate", {
		"type": ORDER_TYPES[_type_select.selected],
		"nr": _train_select.get_item_text(_train_select.selected),
		"signal": _signal_select.get_item_text(_signal_select.selected)
			if _signal_select.selected >= 0 else "",
	})
