class_name TimetablePanel
extends VBoxContainer
## Podgląd rozkładu jazdy z opóźnieniami i statusami + aktualizacja online.

var sim = null
var tree: Tree
var status_label: Label


func setup(p_sim) -> void:
	sim = p_sim
	tree = Tree.new()
	tree.size_flags_vertical = Control.SIZE_EXPAND_FILL
	tree.columns = 6
	tree.column_titles_visible = true
	tree.hide_root = true
	tree.select_mode = Tree.SELECT_ROW
	var titles := ["Pociąg", "Relacja", "Tor", "Przyj.", "Odj.", "Status"]
	var widths := [86, 150, 34, 52, 52, 150]
	for i in range(titles.size()):
		tree.set_column_title(i, titles[i])
		tree.set_column_custom_minimum_width(i, widths[i])
		tree.set_column_expand(i, i == 5)
	add_child(tree)
	var hb := HBoxContainer.new()
	var btn := Button.new()
	btn.text = "Aktualizuj online"
	btn.tooltip_text = "Pobierz rozkład i opóźnienia z sieci (adresy w Ustawieniach)."
	btn.pressed.connect(func(): sim.request_online_update(true))
	hb.add_child(btn)
	status_label = Label.new()
	status_label.text = ""
	status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	status_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	status_label.add_theme_font_size_override("font_size", 11)
	hb.add_child(status_label)
	add_child(hb)
	refresh()


func refresh() -> void:
	if sim == null or sim.tt == null:
		return
	status_label.text = "Online: %s" % sim.tt.online_status
	tree.clear()
	var root := tree.create_item()
	for e in sim.tt.entries:
		var it := tree.create_item(root)
		var nr_txt: String = "%s %s" % [e["kat"], e["nr"]]
		it.set_text(0, nr_txt)
		var rel: String = "%s → %s" % [e["z"], e["do"]]
		if e["nazwa"] != "":
			rel = "„%s”  %s" % [e["nazwa"], rel]
		it.set_text(1, rel)
		it.set_text(2, str(e["tor"]))
		var arr_txt := SimUtil.fmt_hm(e["arr_sec"])
		var dep_txt := SimUtil.fmt_hm(e["dep_sec"])
		if e["przelot"]:
			dep_txt = "przelot"
		if e["delay_min"] > 0:
			if e["arr_sec"] >= 0:
				arr_txt += " +%d" % e["delay_min"]
		it.set_text(3, arr_txt)
		it.set_text(4, dep_txt)
		it.set_text(5, str(e["status"]))
		var col := Color("9aa7b8")
		if e["actual_dep"] >= 0.0 or str(e["status"]).begins_with("przed"):
			col = Color("5b6675")
		elif e["actual_arr"] >= 0.0:
			col = Color("d7dee8")
		elif e["delay_min"] > 0:
			col = Color("f0b429")
		for c in range(6):
			it.set_custom_color(c, col)
