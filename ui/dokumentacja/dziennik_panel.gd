class_name DziennikPanel
extends PanelContainer
## Dziennik ruchu (układ wg R-142, docs/systemy/18 §3) — w F5 tryb auto:
## wpisy generuje rdzeń, gracz ma wgląd.

var _world: SimWorld = null
var _table: Label = null


func build(world: SimWorld) -> void:
	_world = world
	for child: Node in get_children():
		child.queue_free()
	var vbox := VBoxContainer.new()
	vbox.custom_minimum_size = Vector2(560.0, 0.0)
	add_child(vbox)
	var title := Label.new()
	title.text = "DZIENNIK RUCHU (R-142) — wpisy automatyczne"
	title.add_theme_font_size_override("font_size", 15)
	vbox.add_child(title)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(scroll)
	_table = Label.new()
	_table.add_theme_font_size_override("font_size", 12)
	scroll.add_child(_table)
	refresh()


func refresh() -> void:
	if _world == null:
		return
	var lines: Array[String] = []
	lines.append("nr      relacja              tor  pozw.  ozn.   odjazd przyj. potw.  uwagi")
	lines.append("------------------------------------------------------------------------")
	for entry: TrainLog.Entry in _world.train_log.entries:
		lines.append("%-7s %-20s %-4s %-6s %-6s %-6s %-6s %-6s %s" % [
			entry.nr, entry.relation, entry.track,
			_hhmm(entry.permission_s), _hhmm(entry.announced_s),
			_hhmm(entry.departed_s), _hhmm(entry.arrived_s),
			_hhmm(entry.confirmed_s), entry.remarks,
		])
	_table.text = "\n".join(lines)


func _hhmm(time_s: float) -> String:
	return "—" if time_s < 0.0 else Comms.format_time(time_s)
