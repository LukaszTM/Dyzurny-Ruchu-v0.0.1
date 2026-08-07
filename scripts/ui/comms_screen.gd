extends Control
## Ekran łączności — konsola dyżurnego ruchu.
## Lewa kolumna: rozmowy przychodzące (żądania pozwolenia, oznajmienia,
## monity). Środek: zapowiadanie pociągów (żądanie pozwolenia, oznajmienie
## odjazdu, potwierdzenie przyjazdu). Prawa: dziennik rozmów i służby.

var sim: SimCore
var clock: Label
var calls_box: VBoxContainer
var trains_box: VBoxContainer
var hist: RichTextLabel
var podsum: Label
var _acc := 0.0
var _hist_len := 0


func _ready() -> void:
	sim = GameState.sim as SimCore
	if sim == null:
		GameState.back_to_menu()
		return
	UICommon.make_background(self)
	var hb := UICommon.make_header(self, "ŁĄCZNOŚĆ ZAPOWIADAWCZA I SŁUŻBOWA", sim)
	clock = hb.get_node("Zegar") as Label

	var root := HBoxContainer.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.offset_top = 52.0
	root.offset_left = 10.0
	root.offset_right = -10.0
	root.offset_bottom = -34.0
	root.add_theme_constant_override("separation", 10)
	add_child(root)

	var kol1 := VBoxContainer.new()
	kol1.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	kol1.size_flags_stretch_ratio = 1.1
	kol1.add_child(UICommon.section("Rozmowy przychodzące"))
	var sc1 := ScrollContainer.new()
	sc1.size_flags_vertical = Control.SIZE_EXPAND_FILL
	calls_box = VBoxContainer.new()
	calls_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sc1.add_child(calls_box)
	kol1.add_child(sc1)
	root.add_child(kol1)

	var kol2 := VBoxContainer.new()
	kol2.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	kol2.size_flags_stretch_ratio = 1.4
	kol2.add_child(UICommon.section("Zapowiadanie pociągów"))
	kol2.add_child(UICommon.small(
		"Wyprawienie pociągu na szlak wymaga pozwolenia sąsiedniego posterunku. " +
		"Po odjeździe oznajmij odjazd, po przyjeździe potwierdź przyjazd „w całości”."))
	var sc2 := ScrollContainer.new()
	sc2.size_flags_vertical = Control.SIZE_EXPAND_FILL
	trains_box = VBoxContainer.new()
	trains_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sc2.add_child(trains_box)
	kol2.add_child(sc2)
	root.add_child(kol2)

	var kol3 := VBoxContainer.new()
	kol3.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	kol3.add_child(UICommon.section("Dziennik rozmów"))
	hist = RichTextLabel.new()
	hist.size_flags_vertical = Control.SIZE_EXPAND_FILL
	hist.bbcode_enabled = true
	hist.scroll_following = true
	hist.add_theme_font_size_override("normal_font_size", 12)
	kol3.add_child(hist)
	kol3.add_child(UICommon.section("Służby"))
	var sl := VBoxContainer.new()
	for s in Comms.SLUZBY:
		sl.add_child(UICommon.small("☎  %s — %s" % [str(s["name"]), str(s["opis"])]))
	kol3.add_child(sl)
	root.add_child(kol3)

	podsum = UICommon.small("")
	podsum.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	podsum.offset_top = -28.0
	podsum.offset_left = 10.0
	add_child(podsum)

	EventBus.comms_changed.connect(_refresh)
	EventBus.comms_call_added.connect(func(_c): _refresh())
	_refresh()
	_rebuild_history()


func _process(delta: float) -> void:
	if sim == null:
		return
	clock.text = SimUtil.fmt_time(sim.sim_time)
	_acc += delta
	if _acc >= 1.0:
		_acc = 0.0
		_refresh()
	if sim.comms.history.size() != _hist_len:
		_rebuild_history()


func _unhandled_key_input(event: InputEvent) -> void:
	var k := event as InputEventKey
	if k != null and k.pressed and k.keycode == KEY_ESCAPE:
		GameState.back_to_panel()


func _refresh() -> void:
	if calls_box == null:
		return
	for c in calls_box.get_children():
		c.queue_free()
	var pend := sim.comms.pending_calls()
	for call_ in pend:
		calls_box.add_child(_karta_rozmowy(call_))
	if pend.is_empty():
		calls_box.add_child(UICommon.small("Brak oczekujących rozmów."))

	for c in trains_box.get_children():
		c.queue_free()
	var jest := false
	for t: Train in sim.trains.values():
		var karta: Control = _karta_pociagu(t)
		if karta != null:
			trains_box.add_child(karta)
			jest = true
	if not jest:
		trains_box.add_child(UICommon.small("Brak pociągów wymagających zapowiedzenia."))

	var st: Dictionary = sim.comms.stats
	podsum.text = "Zapowiedzi: %d   •   odmowy pozwolenia: %d   •   monity o potwierdzenie przyjazdu: %d   •   niepotwierdzone przyjazdy: %d" % [
		int(st["zapowiedzi"]), int(st["odmowy"]), int(st["spoznione_potwierdzenia"]),
		sim.comms.needs_arrival_confirmation().size()]


func _karta_rozmowy(call_: Dictionary) -> Control:
	var panel := PanelContainer.new()
	var vb := VBoxContainer.new()
	var l := Label.new()
	l.text = "☎  %s" % str(call_["tresc"])
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.add_theme_color_override("font_color", Color("fbbf24"))
	vb.add_child(l)
	vb.add_child(UICommon.small("godz. %s" % SimUtil.fmt_time(call_["at"])))
	var hb := HBoxContainer.new()
	var cid := int(call_["id"])
	match str(call_["typ"]):
		"zadanie_pozwolenia", "podstawienie":
			var tak := Button.new()
			tak.text = "Droga wolna (pozwolenie)" if str(call_["typ"]) == "zadanie_pozwolenia" else "Zgoda na podstawienie"
			tak.pressed.connect(func():
				sim.comms.answer_call(cid, true)
				_refresh())
			hb.add_child(tak)
			var nie := Button.new()
			nie.text = "Nie mogę przyjąć"
			nie.tooltip_text = "Pociąg zgłosi się ponownie za ok. 3 minuty."
			nie.pressed.connect(func():
				sim.comms.answer_call(cid, false, "brak wolnego toru")
				_refresh())
			hb.add_child(nie)
		"monit_przyjazd":
			var t: Train = sim.trains.get(int(call_["data"].get("train_id", 0)))
			var pot := Button.new()
			pot.text = "Potwierdź przyjazd"
			pot.disabled = t == null
			pot.pressed.connect(func():
				if t != null:
					sim.comms.confirm_arrival(t)
				sim.comms.answer_call(cid, true)
				_refresh())
			hb.add_child(pot)
		_:
			var ok := Button.new()
			ok.text = "Przyjąłem"
			ok.pressed.connect(func():
				sim.comms.answer_call(cid, true)
				_refresh())
			hb.add_child(ok)
	vb.add_child(hb)
	panel.add_child(vb)
	return panel


func _karta_pociagu(t: Train) -> Control:
	if t.manewrowy and t.actual_arr < 0.0:
		return null
	var status := sim.comms.permission_status(t.id)
	var p: Dictionary = sim.comms.perm.get(t.id, {})
	var potw := bool(p.get("przyjazd_potwierdzony", false))
	var oznaj := bool(p.get("oznajmiony", false))
	var trzeba_potwierdzic: bool = t.actual_arr >= 0.0 and not potw and not t.manewrowy
	var trzeba_pozwolenia: bool = not t.manewrowy and t.actual_dep < 0.0 and status != "udzielone"
	var trzeba_oznajmic: bool = t.actual_dep >= 0.0 and not oznaj and not t.manewrowy
	if not (trzeba_potwierdzic or trzeba_pozwolenia or trzeba_oznajmic):
		return null
	var panel := PanelContainer.new()
	var vb := VBoxContainer.new()
	var l := Label.new()
	l.text = "%s  rel. %s" % [t.opis(), t.relacja()]
	l.add_theme_font_size_override("font_size", 14)
	vb.add_child(l)
	var kier_do: Dictionary = sim.layout.line_ends.get(t.wyjazd, {})
	var kier_z: Dictionary = sim.layout.line_ends.get(t.wjazd, {})
	vb.add_child(UICommon.small("od strony: %s   •   w kierunku: %s   •   %s   •   pozwolenie: %s" % [
		str(kier_z.get("name", "?")), str(kier_do.get("name", "?")), t.state_text(),
		status if status != "" else "brak"]))
	var hb := HBoxContainer.new()
	if trzeba_potwierdzic:
		var b := Button.new()
		b.text = "Potwierdź przyjazd (w całości)"
		b.pressed.connect(func():
			var e: String = sim.comms.confirm_arrival(t)
			if e != "":
				sim.show_message("✗ " + e, 2)
			_refresh())
		hb.add_child(b)
	if trzeba_pozwolenia:
		var b2 := Button.new()
		b2.text = "Żądaj pozwolenia" if status != "oczekuje" else "Oczekiwanie na odpowiedź…"
		b2.disabled = status == "oczekuje"
		b2.pressed.connect(func():
			var e: String = sim.comms.ask_permission(t)
			if e != "":
				sim.show_message("✗ " + e, 2)
			_refresh())
		hb.add_child(b2)
	if trzeba_oznajmic:
		var b3 := Button.new()
		b3.text = "Oznajmij odjazd"
		b3.pressed.connect(func():
			var e: String = sim.comms.announce_departure(t)
			if e != "":
				sim.show_message("✗ " + e, 2)
			_refresh())
		hb.add_child(b3)
	vb.add_child(hb)
	panel.add_child(vb)
	return panel


func _rebuild_history() -> void:
	if hist == null:
		return
	hist.clear()
	for h in sim.comms.history:
		var kol := "38bdf8" if str(h["kier"]) == "<-" else "86efac"
		var strzalka := "◀" if str(h["kier"]) == "<-" else "▶"
		hist.append_text("[color=#64748b]%s[/color] [color=#%s]%s %s:[/color] %s\n" % [
			SimUtil.fmt_time(h["t"]), kol, strzalka, str(h["kto"]), str(h["tresc"])])
	_hist_len = sim.comms.history.size()
