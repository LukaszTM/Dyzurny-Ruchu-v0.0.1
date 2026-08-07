extends Control
## „Wykaz pociągów” — odwzorowanie ekranu rozkładu z SimRail:
## jasny motyw, kolorowe nagłówki kolumn, osobne kolumny „Nr poc” dla obu
## kierunków, fioletowe podświetlenie wybranego wiersza, zakładki
## Wykaz pociągów / Opis pociągu / Trasa pociągu, filtry potwierdzeń
## i rodzajów pociągów, duży zegar.

const KOLUMNY := [
	["K", 30], ["NK", 30],
	["Przyj. pl.", 68], ["+/-", 38], ["Przyj. rz.", 68],
	["Rodz.", 50], ["Nr poc", 64], ["Z kierunku post.", 128],
	["Nr poc", 64], ["W kierunku post.", 128],
	["L", 26], ["Nr t.", 44], ["Postój", 52], ["Typ p.", 48], ["P T", 46],
	["Odj. pl.", 68], ["+/-", 38], ["Odj. rz.", 68],
	["Stacja początkowa", 128], ["Stacja końcowa", 128],
]

const HDR_KOLORY := {
	0: UICommon.WYK_HDR_SZARY, 1: UICommon.WYK_HDR_SZARY,
	2: UICommon.WYK_HDR_OLIWKA, 3: UICommon.WYK_HDR_OLIWKA, 4: UICommon.WYK_HDR_OLIWKA,
	5: UICommon.WYK_HDR_CZERW,
	6: Color("6a8aa0"), 7: UICommon.WYK_HDR_CYJAN,
	8: Color("a08a7a"), 9: UICommon.WYK_HDR_ZIEL,
	10: UICommon.WYK_HDR_SZARY, 11: UICommon.WYK_HDR_ZOLTY,
	12: Color("9a9a8a"), 13: Color("8aa0b8"), 14: UICommon.WYK_HDR_NIEB,
	15: UICommon.WYK_HDR_OLIWKA, 16: UICommon.WYK_HDR_OLIWKA, 17: UICommon.WYK_HDR_OLIWKA,
	18: UICommon.WYK_HDR_FIOLET, 19: UICommon.WYK_HDR_FIOLET,
}

const RODZ_KOLORY := {
	"EIP": Color("c41818"), "EIE": Color("c41818"),
	"MPE": Color("8a1a1a"), "MOE": Color("8a1a1a"),
	"ROJ": Color("8a1a1a"), "AOE": Color("8a1a1a"),
	"TDE": Color("b02020"), "TME": Color("7a1010"),
	"PWE": Color("6a5a4a"), "LPE": Color("6a5a4a"), "MAN": Color("6a6a6a"),
}

const PERON_RZYM := {"Peron 1": "I", "Peron 2": "II", "Peron 3": "III", "Peron 4": "IV"}

var sim: SimCore
var tree: Tree
var hdr_tree: Tree
var clock: Label
var filtr_nr: LineEdit
var potw_grp := ButtonGroup.new()
var poc_grp := ButtonGroup.new()
var dod_info: Label
var status_lbl: Label
var zakladka := 0
var tab_btns: Array = []
var wykaz_box: VBoxContainer
var opis_box: VBoxContainer
var trasa_box: VBoxContainer
var wybrany_nr := ""
var _acc := 0.0


func _ready() -> void:
	sim = GameState.sim as SimCore
	if sim == null:
		GameState.back_to_menu()
		return
	UICommon.make_background(self, UICommon.WYK_TLO)
	_build()
	_refresh()


func _process(delta: float) -> void:
	if sim == null:
		return
	clock.text = SimUtil.fmt_time(sim.sim_time)
	_acc += delta
	if _acc >= 2.0:
		_acc = 0.0
		if zakladka == 0:
			_refresh()
		else:
			_refresh_detale()


func _unhandled_key_input(event: InputEvent) -> void:
	var k := event as InputEventKey
	if k != null and k.pressed and k.keycode == KEY_ESCAPE and not filtr_nr.has_focus():
		GameState.back_to_panel()


# ------------------------------------------------------------------ budowa --

func _ciemny(t: String, size := 13) -> Label:
	var l := Label.new()
	l.text = t
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", Color("2a2a2a"))
	return l


func _radio(text: String, grp: ButtonGroup, wybrane: bool) -> CheckBox:
	var c := CheckBox.new()
	c.text = text
	c.button_group = grp
	c.button_pressed = wybrane
	c.add_theme_font_size_override("font_size", 12)
	c.add_theme_color_override("font_color", Color("2a2a2a"))
	c.add_theme_color_override("font_pressed_color", Color("2a2a2a"))
	c.add_theme_color_override("font_hover_color", Color("000000"))
	c.pressed.connect(_refresh)
	return c


func _build() -> void:
	var root := VBoxContainer.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.offset_left = 8.0
	root.offset_right = -8.0
	root.offset_top = 4.0
	root.offset_bottom = -6.0
	root.add_theme_constant_override("separation", 4)
	add_child(root)

	# --- górny wiersz: zakładki + język + zegar ---
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 2)
	for i in range(3):
		var nazwy := ["Wykaz pociągów", "Opis pociągu", "Trasa pociągu"]
		var tb := Button.new()
		tb.text = nazwy[i]
		tb.focus_mode = Control.FOCUS_NONE
		tb.pressed.connect(func(): _set_tab(i))
		tab_btns.append(tb)
		top.add_child(tb)
	var powrot := Button.new()
	powrot.text = "◀ PULPIT (Esc)"
	powrot.focus_mode = Control.FOCUS_NONE
	powrot.pressed.connect(func(): GameState.back_to_panel())
	top.add_child(powrot)
	var sp := Control.new()
	sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(sp)
	var jez := OptionButton.new()
	jez.add_item("Polski")
	jez.disabled = true
	top.add_child(jez)
	clock = Label.new()
	clock.add_theme_font_size_override("font_size", 30)
	clock.add_theme_color_override("font_color", Color("ffffff"))
	var csb := StyleBoxFlat.new()
	csb.bg_color = Color("2878d8")
	csb.content_margin_left = 12
	csb.content_margin_right = 12
	var cpan := PanelContainer.new()
	cpan.add_theme_stylebox_override("panel", csb)
	cpan.add_child(clock)
	top.add_child(cpan)
	root.add_child(top)

	# --- stacja ---
	var st_row := HBoxContainer.new()
	st_row.add_theme_constant_override("separation", 14)
	var st_opt := OptionButton.new()
	st_opt.add_item(sim.layout.station_name)
	st_opt.disabled = true
	st_row.add_child(st_opt)
	st_row.add_child(_ciemny("Pełna data:"))
	var pd := CheckBox.new()
	pd.disabled = true
	st_row.add_child(pd)
	root.add_child(st_row)

	# --- filtry ---
	var f := HBoxContainer.new()
	f.add_theme_constant_override("separation", 16)
	var f1 := VBoxContainer.new()
	f1.add_child(_ciemny("Nr pociągu:", 12))
	filtr_nr = LineEdit.new()
	filtr_nr.custom_minimum_size = Vector2(130, 0)
	filtr_nr.text_changed.connect(func(_t): _refresh())
	f1.add_child(filtr_nr)
	f.add_child(f1)
	var f2 := VBoxContainer.new()
	f2.add_child(_ciemny("Potwierdzenie:", 12))
	var f2h := HBoxContainer.new()
	for para in [["wszystkie", true], ["potwierdzone", false], ["niepotwierdzone", false]]:
		f2h.add_child(_radio(str(para[0]), potw_grp, bool(para[1])))
	f2.add_child(f2h)
	f.add_child(f2)
	var f3 := VBoxContainer.new()
	f3.add_child(_ciemny("Pociągi:", 12))
	var f3h := HBoxContainer.new()
	for para2 in [["wszystkie", true], ["kończące", false], ["uruchamiane", false],
			["uruch. + koń.", false], ["kursujące", false]]:
		f3h.add_child(_radio(str(para2[0]), poc_grp, bool(para2[1])))
	f3.add_child(f3h)
	f.add_child(f3)
	var fsp := Control.new()
	fsp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	f.add_child(fsp)
	var f4 := VBoxContainer.new()
	f4.add_child(_ciemny("Uwagi eksploatacyjne", 12))
	var uw := LineEdit.new()
	uw.custom_minimum_size = Vector2(150, 0)
	uw.editable = false
	f4.add_child(uw)
	f.add_child(f4)
	var f5 := VBoxContainer.new()
	f5.add_child(_ciemny("Dodatkowe informacje", 12))
	dod_info = _ciemny("Z  —\nDo  —", 12)
	f5.add_child(dod_info)
	f.add_child(f5)
	root.add_child(f)

	# --- zakładka: wykaz ---
	wykaz_box = VBoxContainer.new()
	wykaz_box.size_flags_vertical = Control.SIZE_EXPAND_FILL
	wykaz_box.add_theme_constant_override("separation", 0)
	hdr_tree = _make_tree()
	hdr_tree.custom_minimum_size = Vector2(0, 34)
	var hroot := hdr_tree.create_item()
	var hit := hdr_tree.create_item(hroot)
	for i in range(KOLUMNY.size()):
		hit.set_text(i, str(KOLUMNY[i][0]))
		hit.set_custom_bg_color(i, HDR_KOLORY.get(i, UICommon.WYK_HDR_SZARY))
		hit.set_custom_color(i, Color("ffffff"))
		hit.set_selectable(i, false)
	wykaz_box.add_child(hdr_tree)
	tree = _make_tree()
	tree.size_flags_vertical = Control.SIZE_EXPAND_FILL
	tree.item_selected.connect(_on_selected)
	wykaz_box.add_child(tree)
	root.add_child(wykaz_box)

	# --- zakładki: opis / trasa ---
	opis_box = VBoxContainer.new()
	opis_box.size_flags_vertical = Control.SIZE_EXPAND_FILL
	opis_box.visible = false
	root.add_child(opis_box)
	trasa_box = VBoxContainer.new()
	trasa_box.size_flags_vertical = Control.SIZE_EXPAND_FILL
	trasa_box.visible = false
	root.add_child(trasa_box)

	# --- dolny pasek ---
	var bot := HBoxContainer.new()
	var wg := Button.new()
	wg.text = "Wprowadzanie godzin"
	wg.disabled = true
	bot.add_child(wg)
	var upd := Button.new()
	upd.text = "Aktualizuj online"
	upd.pressed.connect(func():
		sim.request_online_update(true)
		_refresh())
	bot.add_child(upd)
	status_lbl = _ciemny("", 11)
	status_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bot.add_child(status_lbl)
	var v_dol := Button.new()
	v_dol.text = "V"
	v_dol.pressed.connect(func(): _przewin(1))
	bot.add_child(v_dol)
	var v_gora := Button.new()
	v_gora.text = "Λ"
	v_gora.pressed.connect(func(): _przewin(-1))
	bot.add_child(v_gora)
	root.add_child(bot)
	_set_tab(0)


func _make_tree() -> Tree:
	var t := Tree.new()
	t.columns = KOLUMNY.size()
	t.hide_root = true
	t.column_titles_visible = false
	t.select_mode = Tree.SELECT_ROW
	t.scroll_horizontal_enabled = false
	t.focus_mode = Control.FOCUS_NONE
	for i in range(KOLUMNY.size()):
		t.set_column_custom_minimum_width(i, int(KOLUMNY[i][1]))
		t.set_column_expand(i, i in [7, 9, 18, 19])
	var bg := StyleBoxFlat.new()
	bg.bg_color = UICommon.WYK_TLO
	t.add_theme_stylebox_override("panel", bg)
	var sel := StyleBoxFlat.new()
	sel.bg_color = UICommon.WYK_ZAZN
	t.add_theme_stylebox_override("selected", sel)
	t.add_theme_stylebox_override("selected_focus", sel)
	t.add_theme_color_override("font_selected_color", Color("ffffff"))
	t.add_theme_color_override("font_color", Color("2a2a2a"))
	t.add_theme_constant_override("draw_guides", 1)
	t.add_theme_color_override("guide_color", Color("c8c4a8"))
	return t


func _set_tab(i: int) -> void:
	zakladka = i
	wykaz_box.visible = i == 0
	opis_box.visible = i == 1
	trasa_box.visible = i == 2
	for j in range(tab_btns.size()):
		var b := tab_btns[j] as Button
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color("ffffff") if j == i else Color("d8d5c0")
		sb.border_color = Color("a8a488")
		sb.set_border_width_all(1)
		sb.content_margin_left = 10
		sb.content_margin_right = 10
		sb.content_margin_top = 4
		sb.content_margin_bottom = 4
		b.add_theme_stylebox_override("normal", sb)
		b.add_theme_color_override("font_color", Color("1a1a1a"))
	if i == 0:
		_refresh()
	else:
		_refresh_detale()


func _przewin(kier: int) -> void:
	var sel := tree.get_selected()
	var cel: TreeItem = null
	if sel == null:
		cel = tree.get_root().get_first_child() if tree.get_root() != null else null
	else:
		cel = sel.get_next() if kier > 0 else sel.get_prev()
	if cel != null:
		cel.select(0)
		tree.scroll_to_item(cel)


# --------------------------------------------------------------- dane ------

func _potwierdzony(e: Dictionary) -> bool:
	var tid := int(e["train_id"])
	if tid == 0:
		return false
	var p: Dictionary = sim.comms.perm.get(tid, {})
	return bool(p.get("przyjazd_potwierdzony", false)) or bool(p.get("oznajmiony", false))


func _pasuje(e: Dictionary) -> bool:
	var nrf := filtr_nr.text.strip_edges()
	if nrf != "" and not str(e["nr"]).contains(nrf):
		return false
	var potw := potw_grp.get_pressed_button()
	if potw != null:
		match potw.text:
			"potwierdzone":
				if not _potwierdzony(e):
					return false
			"niepotwierdzone":
				if _potwierdzony(e):
					return false
	var poc := poc_grp.get_pressed_button()
	if poc != null:
		match poc.text:
			"kończące":
				return bool(e["koniec"])
			"uruchamiane":
				return bool(e["start"])
			"uruch. + koń.":
				return bool(e["start"]) or bool(e["koniec"])
			"kursujące":
				return float(e["actual_arr"]) >= 0.0 and float(e["actual_dep"]) < 0.0
	return true


func _na_wschod(e: Dictionary) -> bool:
	var wy: Dictionary = sim.layout.line_ends.get(str(e["wy"]), {})
	if not wy.is_empty():
		return int(wy.get("dir_in", -1)) == -1
	var we: Dictionary = sim.layout.line_ends.get(str(e["we"]), {})
	return int(we.get("dir_in", 1)) == 1


func _kierunek(line_end_id: String) -> String:
	var le: Dictionary = sim.layout.line_ends.get(line_end_id, {})
	return str(le.get("name", line_end_id))


func _peron_tor(e: Dictionary) -> String:
	var tr: Dictionary = sim.layout.tracks.get(str(e["tor"]), {})
	var rzym := str(PERON_RZYM.get(str(tr.get("peron", "")), ""))
	if rzym == "":
		return ""
	return "%s %s" % [rzym, str(e["tor"])]


func _refresh() -> void:
	if tree == null:
		return
	status_lbl.text = "   pozycji: %d   •   online: %s" % [sim.tt.entries.size(), sim.tt.online_status]
	tree.clear()
	var root := tree.create_item()
	var do_zaznaczenia: TreeItem = null
	for e in sim.tt.entries:
		if not _pasuje(e):
			continue
		var it := tree.create_item(root)
		var wschod := _na_wschod(e)
		var op := int(e["delay"])
		var arr_rz := float(e["actual_arr"])
		var dep_rz := float(e["actual_dep"])
		var arr_op := op
		if arr_rz >= 0.0 and float(e["arr"]) >= 0.0:
			arr_op = int(round((arr_rz - float(e["arr"])) / 60.0))
		var dep_op := 0
		if dep_rz >= 0.0 and float(e["dep"]) >= 0.0:
			dep_op = int(round((dep_rz - float(e["dep"])) / 60.0))
		elif float(e["dep"]) >= 0.0:
			dep_op = op
		var postoj_min := float(e["postoj"]) / 60.0
		var wart := [
			"☑" if _potwierdzony(e) else "",
			"",
			SimUtil.fmt_hm(e["arr"]),
			SimUtil.fmt_signed(arr_op) if float(e["arr"]) >= 0.0 else "",
			SimUtil.fmt_hm(arr_rz),
			str(e["kat"]),
			str(e["nr"]) if wschod else "",
			_kierunek(str(e["we"])),
			"" if wschod else str(e["nr"]),
			_kierunek(str(e["wy"])),
			"",
			str(e["tor"]),
			"%.1f" % postoj_min,
			"ph" if postoj_min > 0.0 and not bool(e["przelot"]) else "",
			_peron_tor(e),
			SimUtil.fmt_hm(e["dep"]) if not bool(e["przelot"]) else "przel.",
			SimUtil.fmt_signed(dep_op) if float(e["dep"]) >= 0.0 else "",
			SimUtil.fmt_hm(dep_rz),
			str(e["z"]),
			str(e["do"]),
		]
		var wiersz_bg := UICommon.WYK_WIERSZ
		if dep_rz >= 0.0 or str(e["status"]) == "przed objęciem dyżuru":
			wiersz_bg = Color("e8e6d4")
		for i in range(KOLUMNY.size()):
			it.set_text(i, str(wart[i]))
			it.set_custom_color(i, Color("2a2a2a"))
			var bg := wiersz_bg
			match i:
				5:
					bg = RODZ_KOLORY.get(str(e["kat"]), Color("8a1a1a"))
					it.set_custom_color(i, Color("ffffff"))
				6, 7:
					bg = UICommon.WYK_KOM_NIEB
				8, 9:
					bg = UICommon.WYK_KOM_ROZ
				12:
					bg = UICommon.WYK_KOM_POM if postoj_min > 0.0 else wiersz_bg
				13:
					bg = UICommon.WYK_KOM_PH if str(wart[13]) != "" else wiersz_bg
					it.set_custom_color(i, Color("2060a0"))
				14:
					bg = UICommon.WYK_KOM_NIEB if str(wart[14]) != "" else wiersz_bg
			if (i == 3 and arr_op >= 15) or (i == 16 and dep_op >= 15):
				it.set_custom_color(i, Color("c01010"))
			it.set_custom_bg_color(i, bg)
		it.set_metadata(0, str(e["nr"]))
		if str(e["nr"]) == wybrany_nr:
			do_zaznaczenia = it
	if do_zaznaczenia != null:
		do_zaznaczenia.select(0)
		_update_dod_info()


func _on_selected() -> void:
	var it := tree.get_selected()
	if it != null:
		wybrany_nr = str(it.get_metadata(0))
	_update_dod_info()


func _wybrany_wiersz() -> Dictionary:
	for e in sim.tt.entries:
		if str(e["nr"]) == wybrany_nr:
			return e
	return {}


func _update_dod_info() -> void:
	var e := _wybrany_wiersz()
	if e.is_empty():
		dod_info.text = "Z  —\nDo  —"
		return
	dod_info.text = "Z  %s\nDo  %s" % [str(e["z"]), str(e["do"])]


# ----------------------------------------------------- opis / trasa pociągu

func _refresh_detale() -> void:
	var box := opis_box if zakladka == 1 else trasa_box
	for c in box.get_children():
		c.queue_free()
	var e := _wybrany_wiersz()
	if e.is_empty():
		box.add_child(_ciemny("Wybierz pociąg w zakładce „Wykaz pociągów”.", 14))
		return
	if zakladka == 1:
		_build_opis(box, e)
	else:
		_build_trasa(box, e)


func _wiersz_opisu(box: VBoxContainer, klucz: String, wartosc: String) -> void:
	var hb := HBoxContainer.new()
	var k := _ciemny(klucz, 13)
	k.custom_minimum_size = Vector2(240, 0)
	k.add_theme_color_override("font_color", Color("6a6a5a"))
	hb.add_child(k)
	hb.add_child(_ciemny(wartosc, 13))
	box.add_child(hb)


func _build_opis(box: VBoxContainer, e: Dictionary) -> void:
	var naglowek := _ciemny("%s %s %s" % [str(e["kat"]), str(e["nr"]),
		("„%s”" % str(e["nazwa"])) if str(e["nazwa"]) != "" else ""], 20)
	box.add_child(naglowek)
	box.add_child(HSeparator.new())
	_wiersz_opisu(box, "Rodzaj pociągu:", "%s — %s" % [str(e["kat"]),
		str(Train.RODZAJE.get(str(e["kat"]), ""))])
	_wiersz_opisu(box, "Relacja:", "%s — %s" % [str(e["z"]), str(e["do"])])
	_wiersz_opisu(box, "Z kierunku posterunku:", _kierunek(str(e["we"])))
	_wiersz_opisu(box, "W kierunku posterunku:", _kierunek(str(e["wy"])))
	_wiersz_opisu(box, "Tor / peron:", "%s   %s" % [str(e["tor"]), _peron_tor(e)])
	_wiersz_opisu(box, "Przyjazd plan. / rzecz.:", "%s / %s" % [
		SimUtil.fmt_hm(e["arr"]), SimUtil.fmt_hm(e["actual_arr"])])
	_wiersz_opisu(box, "Odjazd plan. / rzecz.:", "%s / %s" % [
		SimUtil.fmt_hm(e["dep"]), SimUtil.fmt_hm(e["actual_dep"])])
	_wiersz_opisu(box, "Opóźnienie:", "%+d min" % int(e["delay"]))
	_wiersz_opisu(box, "Postój:", "%.1f min" % (float(e["postoj"]) / 60.0))
	var cechy: Array = []
	if bool(e["przelot"]):
		cechy.append("przelot bez zatrzymania")
	if bool(e["start"]):
		cechy.append("rozpoczyna bieg (podstawienie z zaplecza)")
	if bool(e["koniec"]):
		cechy.append("kończy bieg (odstawienie na zaplecze)")
	_wiersz_opisu(box, "Cechy:", ", ".join(cechy) if not cechy.is_empty() else "—")
	_wiersz_opisu(box, "Stan:", str(e["status"]) if str(e["status"]) != "" else "—")
	var tid := int(e["train_id"])
	var t: Train = sim.trains.get(tid) if tid != 0 else null
	if t != null:
		_wiersz_opisu(box, "Położenie:", t.state_text())
		_wiersz_opisu(box, "Pozwolenie na wyjazd:",
			sim.comms.permission_status(t.id) if sim.comms.permission_status(t.id) != "" else "brak")
	_wiersz_opisu(box, "Potwierdzenie (K):", "tak" if _potwierdzony(e) else "nie")


func _build_trasa(box: VBoxContainer, e: Dictionary) -> void:
	box.add_child(_ciemny("Trasa pociągu %s %s w obrębie posterunku %s" % [
		str(e["kat"]), str(e["nr"]), sim.layout.station_name], 16))
	box.add_child(HSeparator.new())
	var kroki: Array = []
	if bool(e["start"]):
		kroki.append(["—", "Grochów (podstawienie składu)", ""])
	else:
		kroki.append([SimUtil.fmt_hm(float(e["arr"]) - 180.0), _kierunek(str(e["we"])), "szlak wjazdowy"])
		kroki.append([SimUtil.fmt_hm(e["arr"]), "%s — tor %s" % [sim.layout.station_name, str(e["tor"])],
			"przyjazd" if not bool(e["przelot"]) else "przejazd"])
	if not bool(e["przelot"]) and float(e["dep"]) >= 0.0:
		kroki.append([SimUtil.fmt_hm(e["dep"]), "%s — tor %s" % [sim.layout.station_name, str(e["tor"])], "odjazd"])
	if bool(e["koniec"]):
		kroki.append(["—", "Grochów (odstawienie składu)", ""])
	else:
		kroki.append(["", _kierunek(str(e["wy"])), "szlak wyjazdowy"])
	for k in kroki:
		var hb := HBoxContainer.new()
		var g := _ciemny(str(k[0]), 14)
		g.custom_minimum_size = Vector2(80, 0)
		hb.add_child(g)
		var m := _ciemny("● " + str(k[1]), 14)
		m.custom_minimum_size = Vector2(420, 0)
		hb.add_child(m)
		var u := _ciemny(str(k[2]), 12)
		u.add_theme_color_override("font_color", Color("6a6a5a"))
		hb.add_child(u)
		box.add_child(hb)
