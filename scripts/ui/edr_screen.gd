extends Control
## Ekran EDR — Elektroniczny Dziennik Ruchu.

var sim: SimCore
var tree: Tree
var clock: Label
var wpis: LineEdit
var wpis_nr: LineEdit
var wpis_tor: LineEdit
var filtr: OptionButton
var filtr_nr: LineEdit
var info: Label


func _ready() -> void:
	sim = GameState.sim as SimCore
	if sim == null:
		GameState.back_to_menu()
		return
	UICommon.make_background(self)
	var hb := UICommon.make_header(self, "EDR — ELEKTRONICZNY DZIENNIK RUCHU", sim)
	clock = hb.get_node("Zegar") as Label

	var vb := VBoxContainer.new()
	vb.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	vb.offset_top = 52.0
	vb.offset_left = 10.0
	vb.offset_right = -10.0
	vb.offset_bottom = -10.0
	add_child(vb)

	var f := HBoxContainer.new()
	f.add_theme_constant_override("separation", 10)
	var l1 := Label.new()
	l1.text = "Rodzaj zapisu:"
	f.add_child(l1)
	filtr = OptionButton.new()
	filtr.add_item("wszystkie")
	for k in EDR.KAT:
		filtr.add_item(k)
	filtr.item_selected.connect(func(_i): _refresh())
	f.add_child(filtr)
	var l2 := Label.new()
	l2.text = "Nr pociągu:"
	f.add_child(l2)
	filtr_nr = LineEdit.new()
	filtr_nr.custom_minimum_size = Vector2(110, 0)
	filtr_nr.text_changed.connect(func(_t): _refresh())
	f.add_child(filtr_nr)
	var sp := Control.new()
	sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	f.add_child(sp)
	var save := Button.new()
	save.text = "Zapisz EDR do pliku"
	save.pressed.connect(func():
		var p: String = sim.edr.save_to_file()
		info.text = ("Zapisano: %s" % p) if p != "" else "Błąd zapisu pliku!")
	f.add_child(save)
	vb.add_child(f)

	tree = Tree.new()
	tree.size_flags_vertical = Control.SIZE_EXPAND_FILL
	tree.columns = 6
	tree.column_titles_visible = true
	tree.hide_root = true
	var kol := [["Lp.", 50], ["Godzina", 78], ["Rodzaj", 90], ["Nr poc.", 70], ["Tor", 40], ["Treść zapisu", 600]]
	for i in range(kol.size()):
		tree.set_column_title(i, str(kol[i][0]))
		tree.set_column_custom_minimum_width(i, int(kol[i][1]))
		tree.set_column_expand(i, i == 5)
	vb.add_child(tree)

	vb.add_child(UICommon.section("Wpis własny dyżurnego ruchu"))
	var w := HBoxContainer.new()
	w.add_theme_constant_override("separation", 6)
	wpis = LineEdit.new()
	wpis.placeholder_text = "Treść zapisu…"
	wpis.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	wpis.text_submitted.connect(func(_t): _dodaj())
	w.add_child(wpis)
	var l3 := Label.new()
	l3.text = "nr poc.:"
	w.add_child(l3)
	wpis_nr = LineEdit.new()
	wpis_nr.custom_minimum_size = Vector2(90, 0)
	w.add_child(wpis_nr)
	var l4 := Label.new()
	l4.text = "tor:"
	w.add_child(l4)
	wpis_tor = LineEdit.new()
	wpis_tor.custom_minimum_size = Vector2(50, 0)
	w.add_child(wpis_tor)
	var add := Button.new()
	add.text = "Dodaj wpis"
	add.pressed.connect(_dodaj)
	w.add_child(add)
	vb.add_child(w)

	info = UICommon.small("")
	vb.add_child(info)

	EventBus.edr_added.connect(func(_e): _refresh())
	_refresh()


func _process(_delta: float) -> void:
	if sim != null:
		clock.text = SimUtil.fmt_time(sim.sim_time)


func _unhandled_key_input(event: InputEvent) -> void:
	var k := event as InputEventKey
	if k != null and k.pressed and k.keycode == KEY_ESCAPE and not wpis.has_focus():
		GameState.back_to_panel()


func _dodaj() -> void:
	var txt := wpis.text.strip_edges()
	if txt == "":
		return
	sim.edr.add(sim.sim_time, "Dyżurny", txt, wpis_nr.text.strip_edges(), wpis_tor.text.strip_edges())
	wpis.text = ""
	wpis_nr.text = ""
	wpis_tor.text = ""


func _refresh() -> void:
	if tree == null:
		return
	var kat := "" if filtr.selected <= 0 else str(EDR.KAT[filtr.selected - 1])
	var lista := sim.edr.filtered(kat, filtr_nr.text.strip_edges())
	tree.clear()
	var root := tree.create_item()
	var last: TreeItem = null
	for e in lista:
		var it := tree.create_item(root)
		it.set_text(0, str(e["lp"]))
		it.set_text(1, SimUtil.fmt_time(e["t"]))
		it.set_text(2, str(e["kat"]))
		it.set_text(3, str(e["nr"]))
		it.set_text(4, str(e["tor"]))
		it.set_text(5, str(e["tresc"]))
		var kol := Color("c8d2de")
		match str(e["kat"]):
			"Usterka":
				kol = Color("f87171")
			"Zapowiedź":
				kol = Color("38bdf8")
			"Przebieg":
				kol = Color("86efac")
			"Manewry":
				kol = Color("fbbf24")
			"Dyżurny":
				kol = Color("e879f9")
			"Służba":
				kol = Color("94a3b8")
		for c in range(6):
			it.set_custom_color(c, kol)
		last = it
	if last != null:
		tree.scroll_to_item(last)
	info.text = "Zapisów: %d (z %d)   •   plik: %s" % [
		lista.size(), sim.edr.entries.size(), sim.edr.file_path()]
