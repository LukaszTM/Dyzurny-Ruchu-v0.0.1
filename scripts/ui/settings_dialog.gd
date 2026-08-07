class_name SettingsDialog
extends AcceptDialog
## Ustawienia gry: obraz, symulacja (natężenie ruchu, praca manewrowa,
## zdarzenia losowe, zapowiadanie) oraz aktualizacje online.

var res_opt: OptionButton
var mode_opt: OptionButton
var vsync_chk: CheckBox
var dyzurny_edit: LineEdit
var intensity_slider: HSlider
var intensity_lbl: Label
var shunting_chk: CheckBox
var zapow_chk: CheckBox
var event_slider: HSlider
var event_lbl: Label
var online_chk: CheckBox
var url_delays: LineEdit
var url_tt: LineEdit
var autosave_chk: CheckBox


func _init() -> void:
	title = "Ustawienia"
	ok_button_text = "Zapisz i zastosuj"
	min_size = Vector2i(680, 660)
	var scroll := ScrollContainer.new()
	scroll.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	scroll.offset_left = 14.0
	scroll.offset_top = 14.0
	scroll.offset_right = -14.0
	scroll.offset_bottom = -52.0
	var vb := VBoxContainer.new()
	vb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vb.custom_minimum_size = Vector2(630, 0)
	vb.add_theme_constant_override("separation", 6)

	vb.add_child(UICommon.section("Obraz"))
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_child(_lbl("Rozdzielczość:"))
	res_opt = OptionButton.new()
	for r in Settings.RESOLUTIONS:
		res_opt.add_item("%d × %d" % [r.x, r.y])
	grid.add_child(res_opt)
	grid.add_child(_lbl("Tryb okna:"))
	mode_opt = OptionButton.new()
	for n in Settings.WINDOW_MODE_NAMES:
		mode_opt.add_item(n)
	grid.add_child(mode_opt)
	grid.add_child(_lbl("Synchronizacja pionowa:"))
	vsync_chk = CheckBox.new()
	vsync_chk.text = "VSync"
	grid.add_child(vsync_chk)
	grid.add_child(_lbl("Nazwisko dyżurnego:"))
	dyzurny_edit = LineEdit.new()
	dyzurny_edit.tooltip_text = "Widoczne na pulpicie i w EDR."
	grid.add_child(dyzurny_edit)
	vb.add_child(grid)

	vb.add_child(UICommon.section("Ruch i zdarzenia"))
	intensity_lbl = Label.new()
	vb.add_child(intensity_lbl)
	intensity_slider = HSlider.new()
	intensity_slider.min_value = 4
	intensity_slider.max_value = 40
	intensity_slider.step = 1
	intensity_slider.tooltip_text = "Natężenie ruchu w trybie ruchu losowego (pociągi na godzinę)."
	intensity_slider.value_changed.connect(func(v):
		intensity_lbl.text = "Natężenie ruchu (tryb losowy): %d poc./h" % int(v))
	vb.add_child(intensity_slider)
	event_lbl = Label.new()
	vb.add_child(event_lbl)
	event_slider = HSlider.new()
	event_slider.min_value = 0
	event_slider.max_value = 45
	event_slider.step = 1
	event_slider.tooltip_text = "Średni odstęp między zdarzeniami losowymi. 0 = zdarzenia wyłączone."
	event_slider.value_changed.connect(func(v):
		event_lbl.text = ("Zdarzenia losowe: WYŁĄCZONE" if v <= 0
			else "Zdarzenia losowe: średnio co ~%d min" % int(v)))
	vb.add_child(event_slider)
	shunting_chk = CheckBox.new()
	shunting_chk.text = "Praca manewrowa (podstawianie i odstawianie składów ze stacji technicznej)"
	vb.add_child(shunting_chk)
	zapow_chk = CheckBox.new()
	zapow_chk.text = "Telefoniczne zapowiadanie pociągów (wymagane pozwolenie na wyprawienie)"
	vb.add_child(zapow_chk)
	vb.add_child(UICommon.small(
		"Przy wyłączonym zapowiadaniu pociągi zgłaszają się automatycznie, a wyprawienie " +
		"na szlak nie wymaga pozwolenia sąsiedniego posterunku."))
	vb.add_child(UICommon.small(
		"UWAGA: w trybie REALNY ROZKŁAD JAZDY czas płynie jak w rzeczywistości, natężenie " +
		"ruchu wynika z rozkładu, a częstotliwość zdarzeń losowych jest stała — powyższe " +
		"suwaki natężenia i zdarzeń dotyczą wyłącznie trybu RUCH LOSOWY."))

	vb.add_child(UICommon.section("Aktualizacje online (rozkład jazdy i opóźnienia)"))
	online_chk = CheckBox.new()
	online_chk.text = "Pobieraj rozkład jazdy i opóźnienia z sieci"
	vb.add_child(online_chk)
	vb.add_child(_lbl("Adres opóźnień (JSON):"))
	url_delays = LineEdit.new()
	vb.add_child(url_delays)
	vb.add_child(_lbl("Adres rozkładu jazdy (JSON):"))
	url_tt = LineEdit.new()
	vb.add_child(url_tt)

	vb.add_child(UICommon.section("EDR"))
	autosave_chk = CheckBox.new()
	autosave_chk.text = "Automatyczny zapis EDR do pliku po zakończeniu dyżuru"
	vb.add_child(autosave_chk)

	scroll.add_child(vb)
	add_child(scroll)
	confirmed.connect(_apply)
	about_to_popup.connect(_sync)


func _lbl(t: String) -> Label:
	var l := Label.new()
	l.text = t
	return l


func _sync() -> void:
	var idx := 2
	for i in range(Settings.RESOLUTIONS.size()):
		if Settings.RESOLUTIONS[i] == Settings.resolution:
			idx = i
			break
	res_opt.select(idx)
	mode_opt.select(Settings.window_mode)
	vsync_chk.button_pressed = Settings.vsync
	dyzurny_edit.text = Settings.dyzurny_name
	intensity_slider.value = Settings.traffic_intensity
	intensity_lbl.text = "Natężenie ruchu (tryb losowy): %d poc./h" % int(Settings.traffic_intensity)
	event_slider.value = Settings.event_freq_min
	event_lbl.text = ("Zdarzenia losowe: WYŁĄCZONE" if Settings.event_freq_min <= 0
		else "Zdarzenia losowe: średnio co ~%d min" % int(Settings.event_freq_min))
	shunting_chk.button_pressed = Settings.shunting_enabled
	zapow_chk.button_pressed = Settings.require_zapowiadanie
	online_chk.button_pressed = Settings.online_enabled
	url_delays.text = Settings.url_delays
	url_tt.text = Settings.url_timetable
	autosave_chk.button_pressed = Settings.autosave_edr


func _apply() -> void:
	Settings.resolution = Settings.RESOLUTIONS[res_opt.selected]
	Settings.window_mode = mode_opt.selected
	Settings.vsync = vsync_chk.button_pressed
	Settings.dyzurny_name = dyzurny_edit.text.strip_edges()
	if Settings.dyzurny_name == "":
		Settings.dyzurny_name = "DYŻURNY-1"
	Settings.traffic_intensity = intensity_slider.value
	Settings.event_freq_min = event_slider.value
	Settings.shunting_enabled = shunting_chk.button_pressed
	Settings.require_zapowiadanie = zapow_chk.button_pressed
	Settings.online_enabled = online_chk.button_pressed
	Settings.url_delays = url_delays.text.strip_edges()
	Settings.url_timetable = url_tt.text.strip_edges()
	Settings.autosave_edr = autosave_chk.button_pressed
	Settings.save_cfg()
	Settings.apply()
	var sim := GameState.sim
	if sim != null and is_instance_valid(sim) and not sim.real_mode:
		sim.events.freq_min = Settings.event_freq_min
		sim.events.schedule_next(sim.sim_time)
