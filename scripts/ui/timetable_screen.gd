extends Control
## Ekran „Wykaz pociągów" — pełny rozkład jazdy posterunku z opóźnieniami,
## godzinami rzeczywistymi i statusami; aktualizacja online.

var sim: SimCore
var tree: Tree
var clock: Label
var status: Label
var filtr_nr: LineEdit
var filtr_rodzaj: OptionButton
var _acc := 0.0

const FILTRY := ["wszystkie", "kursujące", "kończące bieg", "rozpoczynające bieg", "przeloty"]


func _ready() -> void:
	sim = GameState.sim as SimCore
	if sim == null:
		GameState.back_to_menu()
		return
	UICommon.make_background(self)
	var hb := UICommon.make_header(self, "WYKAZ POCIĄGÓW — ROZKŁAD JAZDY", sim)
	clock = hb.get_node("Zegar") as Label

	var vb := VBoxContainer.new()
	vb.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	vb.offset_top = 52.0
	vb.offset_left = 10.0
	vb.offset_right = -10.0
	vb.offset_bottom = -10.0
	add_child(vb)

	var filtry := HBoxContainer.new()
	filtry.add_theme_constant_override("separation", 10)
	var l1 := Label.new()
	l1.text = "Nr pociągu:"
	filtry.add_child(l1)
	filtr_nr = LineEdit.new()
	filtr_nr.custom_minimum_size = Vector2(120, 0)
	filtr_nr.text_changed.connect(func(_t): _refresh())
	filtry.add_child(filtr_nr)
	var l2 := Label.new()
	l2.text = "Pociągi:"
	filtry.add_child(l2)
	filtr_rodzaj = OptionButton.new()
	for f in FILTRY:
		filtr_rodzaj.add_item(f)
	filtr_rodzaj.item_selected.connect(func(_i): _refresh())
	filtry.add_child(filtr_rodzaj)
	var sp := Control.new()
	sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	filtry.add_child(sp)
	var btn := Button.new()
	btn.text = "Aktualizuj online"
	btn.tooltip_text = "Pobierz rozkład jazdy i opóźnienia z sieci (adresy w Ustawieniach)."
	btn.pressed.connect(func():
		sim.request_online_update(true)
		_refresh())
	filtry.add_child(btn)
	vb.add_child(filtry)

	status = UICommon.small("")
	vb.add_child(status)

	tree = Tree.new()
	tree.size_flags_vertical = Control.SIZE_EXPAND_FILL
	tree.columns = 15
	tree.column_titles_visible = true
	tree.hide_root = true
	tree.select_mode = Tree.SELECT_ROW
	var kol := [
		["Przyj. pl.", 74], ["+/−", 44], ["Przyj. rz.", 74], ["Rodz.", 52],
		["Nr poc.", 70], ["Z kierunku post.", 150], ["W kierunku post.", 150],
		["Tor", 40], ["Postój", 56], ["Odj. pl.", 70], ["+/−", 44], ["Odj. rz.", 70],
		["Stacja początkowa", 140], ["Stacja końcowa", 140], ["Stan", 170],
	]
	for i in range(kol.size()):
		tree.set_column_title(i, str(kol[i][0]))
		tree.set_column_custom_minimum_width(i, int(kol[i][1]))
		tree.set_column_expand(i, i == 14)
	vb.add_child(tree)
	_refresh()


func _process(delta: float) -> void:
	if sim == null:
		return
	clock.text = SimUtil.fmt_time(sim.sim_time)
	_acc += delta
	if _acc >= 2.0:
		_acc = 0.0
		_refresh()


func _unhandled_key_input(event: InputEvent) -> void:
	var k := event as InputEventKey
	if k != null and k.pressed and k.keycode == KEY_ESCAPE:
		GameState.back_to_panel()


func _pasuje(e: Dictionary) -> bool:
	var nrf := filtr_nr.text.strip_edges()
	if nrf != "" and not str(e["nr"]).contains(nrf):
		return false
	match filtr_rodzaj.selected:
		1:
			return float(e["actual_arr"]) >= 0.0 and float(e["actual_dep"]) < 0.0
		2:
			return bool(e["koniec"])
		3:
			return bool(e["start"])
		4:
			return bool(e["przelot"])
	return true


func _refresh() -> void:
	status.text = "Posterunek %s   •   pozycji w rozkładzie: %d   •   aktualizacja online: %s" % [
		sim.layout.station_name, sim.tt.entries.size(), sim.tt.online_status]
	tree.clear()
	var root := tree.create_item()
	for e in sim.tt.entries:
		if not _pasuje(e):
			continue
		var it := tree.create_item(root)
		var op := int(e["delay"])
		var arr_rz := float(e["actual_arr"])
		var dep_rz := float(e["actual_dep"])
		var arr_op := op
		if arr_rz >= 0.0 and float(e["arr"]) >= 0.0:
			arr_op = int(round((arr_rz - float(e["arr"])) / 60.0))
		var dep_op := op
		if dep_rz >= 0.0 and float(e["dep"]) >= 0.0:
			dep_op = int(round((dep_rz - float(e["dep"])) / 60.0))
		var kier_z := _kierunek(str(e["we"]))
		var kier_do := _kierunek(str(e["wy"]))
		var postoj_txt := "%.1f" % (float(e["postoj"]) / 60.0) if float(e["postoj"]) > 0.0 else "0.0"
		var wart := [
			SimUtil.fmt_hm(e["arr"]),
			SimUtil.fmt_signed(arr_op) if float(e["arr"]) >= 0.0 else "",
			SimUtil.fmt_hm(arr_rz),
			str(e["kat"]),
			str(e["nr"]),
			kier_z,
			kier_do,
			str(e["tor"]),
			postoj_txt,
			SimUtil.fmt_hm(e["dep"]) if not bool(e["przelot"]) else "przelot",
			SimUtil.fmt_signed(dep_op) if float(e["dep"]) >= 0.0 else "",
			SimUtil.fmt_hm(dep_rz),
			str(e["z"]),
			str(e["do"]),
			str(e["status"]),
		]
		for i in range(wart.size()):
			it.set_text(i, str(wart[i]))
		var kol := Color("c8d2de")
		if str(e["status"]) == "przed objęciem dyżuru" or dep_rz >= 0.0:
			kol = Color("64748b")
		elif arr_rz >= 0.0:
			kol = Color("ffffff")
		elif op > 0:
			kol = Color("f0b429")
		if op >= 15:
			kol = Color("f87171")
		for c in range(15):
			it.set_custom_color(c, kol)


func _kierunek(line_end_id: String) -> String:
	var le: Dictionary = sim.layout.line_ends.get(line_end_id, {})
	if le.is_empty():
		return line_end_id
	return "%s (tor %s)" % [str(le["name"]), str(le["tor"])] if str(le["tor"]) != "" else str(le["name"])
