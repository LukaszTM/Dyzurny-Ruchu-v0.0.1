extends Control
## Ekran zdarzeń losowych — lista zdarzeń czynnych z możliwością zgłoszenia
## usterki właściwej służbie oraz podglądem postępu jej usuwania.

var sim: SimCore
var clock: Label
var lista: VBoxContainer
var podsum: Label
var archiwum: VBoxContainer
var _acc := 0.0


func _ready() -> void:
	sim = GameState.sim as SimCore
	if sim == null:
		GameState.back_to_menu()
		return
	UICommon.make_background(self)
	var hb := UICommon.make_header(self, "ZDARZENIA I USTERKI", sim)
	clock = hb.get_node("Zegar") as Label

	var vb := VBoxContainer.new()
	vb.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	vb.offset_top = 52.0
	vb.offset_left = 10.0
	vb.offset_right = -10.0
	vb.offset_bottom = -10.0
	add_child(vb)

	if sim.real_mode:
		vb.add_child(UICommon.small(
			"Tryb REALNY ROZKŁAD JAZDY: usterki występują losowo, a ich częstotliwość " +
			"jest stała i nie podlega zmianie. Usterki nie ustępują samoczynnie — należy " +
			"je zgłosić właściwej służbie, dopiero wtedy rozpoczyna się ich usuwanie."))
	else:
		vb.add_child(UICommon.small(
			"Częstotliwość zdarzeń losowych ustawiasz w USTAWIENIACH gry. " +
			"Usterki nie ustępują samoczynnie — należy je zgłosić właściwej służbie, " +
			"dopiero wtedy rozpoczyna się ich usuwanie."))
	vb.add_child(UICommon.section("Zdarzenia czynne"))
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	lista = VBoxContainer.new()
	lista.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(lista)
	vb.add_child(scroll)

	vb.add_child(UICommon.section("Zdarzenia zakończone"))
	var scroll2 := ScrollContainer.new()
	scroll2.custom_minimum_size = Vector2(0, 140)
	archiwum = VBoxContainer.new()
	archiwum.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll2.add_child(archiwum)
	vb.add_child(scroll2)

	podsum = UICommon.small("")
	vb.add_child(podsum)
	_refresh()


func _process(delta: float) -> void:
	if sim == null:
		return
	clock.text = SimUtil.fmt_time(sim.sim_time)
	_acc += delta
	if _acc >= 1.0:
		_acc = 0.0
		_refresh()


func _unhandled_key_input(event: InputEvent) -> void:
	var k := event as InputEventKey
	if k != null and k.pressed and k.keycode == KEY_ESCAPE:
		GameState.back_to_panel()


func _refresh() -> void:
	for c in lista.get_children():
		c.queue_free()
	for ev in sim.events.active:
		lista.add_child(_karta(ev))
	if sim.events.active.is_empty():
		lista.add_child(UICommon.small("Brak zdarzeń czynnych."))
	for c in archiwum.get_children():
		c.queue_free()
	var arch: Array = sim.events.archiwum
	for i in range(maxi(0, arch.size() - 12), arch.size()):
		var e: Dictionary = arch[i]
		var l := UICommon.small("• %s — %s (usunięto o %s)" % [
			SimUtil.fmt_hm(e["czas"]), str(e["tytul"]), SimUtil.fmt_hm(e["usun_at"])])
		archiwum.add_child(l)
	if arch.is_empty():
		archiwum.add_child(UICommon.small("Brak."))
	podsum.text = "Zdarzenia czynne: %d (niezgłoszone: %d)   •   zakończone: %d" % [
		sim.events.active.size(), sim.events.unreported_count(), arch.size()]


func _karta(ev: Dictionary) -> Control:
	var panel := PanelContainer.new()
	var vb := VBoxContainer.new()
	var tyt := Label.new()
	var zgl := bool(ev["zgloszona"])
	tyt.text = ("⚠  " if not zgl else "🛠  ") + str(ev["tytul"])
	tyt.add_theme_font_size_override("font_size", 15)
	tyt.add_theme_color_override("font_color", Color("f87171") if not zgl else Color("fbbf24"))
	vb.add_child(tyt)
	var opis := Label.new()
	opis.text = str(ev["opis"])
	opis.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	opis.add_theme_font_size_override("font_size", 12)
	vb.add_child(opis)
	var czas := Label.new()
	czas.add_theme_font_size_override("font_size", 11)
	if zgl:
		var left := int(maxf(0.0, float(ev["usun_at"]) - sim.sim_time))
		czas.text = "Zgłoszono o %s do: %s. Do usunięcia pozostało ok. %d min %02d s." % [
			SimUtil.fmt_hm(ev["zgloszona_at"]), sim.comms.sluzba_name(str(ev["sluzba"])),
			int(left / 60), left % 60]
		czas.add_theme_color_override("font_color", Color("86efac"))
	else:
		czas.text = "Wystąpiło o %s. NIEZGŁOSZONE — usuwanie nie zostało rozpoczęte." % SimUtil.fmt_hm(ev["czas"])
		czas.add_theme_color_override("font_color", Color("f87171"))
	vb.add_child(czas)
	if not zgl:
		var hb := HBoxContainer.new()
		var l := Label.new()
		l.text = "Zgłoś do:"
		hb.add_child(l)
		for s in Comms.SLUZBY:
			var b := Button.new()
			b.text = str(s["name"])
			b.tooltip_text = str(s["opis"])
			var sid := str(s["id"])
			var eid := int(ev["id"])
			b.pressed.connect(func():
				var err: String = sim.comms.report_fault(eid, sid)
				if err != "":
					sim.show_message("✗ " + err, 2)
				_refresh())
			hb.add_child(b)
		vb.add_child(hb)
	panel.add_child(vb)
	return panel
