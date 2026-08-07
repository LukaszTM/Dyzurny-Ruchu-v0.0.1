extends Node
## Ekran główny — pulpit nastawczy.
## Górna belka: polecenia nastawcze (PP/PM/ZD/ZDM/ZW/ZWP/OPS) oraz przejścia
## do pozostałych ekranów. Na pulpicie zwijane okno skróconego rozkładu
## z czterema najbliższymi pociągami.

var sim: SimCore
var schema: SchemaView
var ui: CanvasLayer
var cmd_buttons := {}
var clock_lbl: Label
var msg_lbl: Label
var sel_lbl: Label
var pause_btn: Button
var speed_btns: Array = []
var mini: PanelContainer
var mini_body: VBoxContainer
var mini_rows: VBoxContainer
var mini_collapsed := false
var mini_toggle: Button
var comms_btn: Button
var events_btn: Button
var sig_popup: PopupPanel
var sig_popup_id := ""
var sig_buttons := {}
var tut_panel: PanelContainer
var tut_head: Label
var tut_text: Label
var tut_next: Button
var help_dialog: AcceptDialog
var settings_dialog: SettingsDialog
var exit_dialog: ConfirmationDialog
var _acc := 0.0


func _ready() -> void:
	sim = GameState.sim as SimCore
	if sim == null:
		GameState.back_to_menu()
		return
	schema = SchemaView.new()
	add_child(schema)
	schema.setup(sim)
	schema.signal_menu_request = _open_signal_menu
	_build_ui()
	EventBus.message.connect(_on_message)
	EventBus.panel_state_changed.connect(_refresh_cmd)
	EventBus.element_selected.connect(func(_k, _i): _refresh_sel())
	EventBus.comms_changed.connect(_refresh_badges)
	EventBus.comms_call_added.connect(func(_c): _refresh_badges())
	EventBus.random_event_started.connect(func(_e): _refresh_badges())
	EventBus.tutorial_step.connect(func(_i): _refresh_tutorial())
	EventBus.tutorial_finished.connect(_refresh_tutorial)
	_refresh_cmd()
	_refresh_badges()
	_refresh_tutorial()
	_refresh_mini()
	if sim.last_message != "":
		_on_message(sim.last_message, sim.last_message_level)


func _process(delta: float) -> void:
	if sim == null:
		return
	clock_lbl.text = SimUtil.fmt_time(sim.sim_time)
	schema.queue_redraw()
	_acc += delta
	if _acc >= 1.0:
		_acc = 0.0
		_refresh_mini()
		_refresh_badges()
		_refresh_sel()


func _unhandled_key_input(event: InputEvent) -> void:
	var k := event as InputEventKey
	if k == null or not k.pressed or k.echo:
		return
	match k.keycode:
		KEY_SPACE:
			sim.toggle_pause()
		KEY_1:
			sim.set_speed(1.0)
		KEY_2:
			sim.set_speed(2.0)
		KEY_3:
			sim.set_speed(5.0)
		KEY_4:
			sim.set_speed(10.0)
		KEY_F1:
			help_dialog.popup_centered()
		KEY_F2:
			GameState.open_scene(GameState.SCENE_TIMETABLE)
		KEY_F3:
			GameState.open_scene(GameState.SCENE_EDR)
		KEY_F4:
			GameState.open_scene(GameState.SCENE_EVENTS)
		KEY_F5:
			GameState.open_scene(GameState.SCENE_COMMS)
		KEY_ESCAPE:
			if sim.pending_start != "":
				sim.pending_start = ""
				EventBus.panel_state_changed.emit()
			else:
				exit_dialog.popup_centered()


# ------------------------------------------------------------------ budowa --

func _build_ui() -> void:
	ui = CanvasLayer.new()
	add_child(ui)

	var top := PanelContainer.new()
	top.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	var top_vb := VBoxContainer.new()
	top_vb.add_theme_constant_override("separation", 2)

	# --- wiersz 1: polecenia nastawcze ---
	var r1 := HBoxContainer.new()
	r1.add_theme_constant_override("separation", 4)
	for cmd in [SimCore.CMD_PP, SimCore.CMD_PM, SimCore.CMD_ZD, SimCore.CMD_ZDM,
			SimCore.CMD_ZW, SimCore.CMD_ZWP, SimCore.CMD_OPS]:
		var b := Button.new()
		b.text = str(SimCore.CMD_LABELS[cmd])
		b.tooltip_text = str(SimCore.CMD_HELP[cmd])
		b.toggle_mode = true
		b.pressed.connect(func(): sim.set_cmd_mode(cmd))
		cmd_buttons[cmd] = b
		r1.add_child(b)
	var sp1 := Control.new()
	sp1.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	r1.add_child(sp1)
	var st_lbl := Label.new()
	st_lbl.text = "%s   •   dyżurny ruchu: %s" % [sim.layout.station_name.to_upper(), Settings.dyzurny_name]
	st_lbl.add_theme_color_override("font_color", UICommon.COL_SZARY)
	r1.add_child(st_lbl)
	clock_lbl = Label.new()
	clock_lbl.add_theme_font_size_override("font_size", 24)
	clock_lbl.add_theme_color_override("font_color", Color("22c55e"))
	r1.add_child(clock_lbl)
	pause_btn = Button.new()
	pause_btn.text = "⏸"
	pause_btn.pressed.connect(func(): sim.toggle_pause())
	r1.add_child(pause_btn)
	for sp in [1.0, 2.0, 5.0, 10.0]:
		var sb := Button.new()
		sb.text = "%dx" % int(sp)
		sb.toggle_mode = true
		sb.set_meta("speed", sp)
		sb.pressed.connect(func(): sim.set_speed(sp))
		speed_btns.append(sb)
		r1.add_child(sb)
	top_vb.add_child(r1)

	# --- wiersz 2: ekrany ---
	var r2 := HBoxContainer.new()
	r2.add_theme_constant_override("separation", 4)
	var nav := [
		["ROZKŁAD JAZDY (F2)", GameState.SCENE_TIMETABLE],
		["EDR (F3)", GameState.SCENE_EDR],
		["ZDARZENIA (F4)", GameState.SCENE_EVENTS],
		["ŁĄCZNOŚĆ (F5)", GameState.SCENE_COMMS],
	]
	for item in nav:
		var nb := Button.new()
		nb.text = str(item[0])
		var path := str(item[1])
		nb.pressed.connect(func(): GameState.open_scene(path))
		if path == GameState.SCENE_COMMS:
			comms_btn = nb
		elif path == GameState.SCENE_EVENTS:
			events_btn = nb
		r2.add_child(nb)
	var sp2 := Control.new()
	sp2.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	r2.add_child(sp2)
	var fit := Button.new()
	fit.text = "Dopasuj widok"
	fit.pressed.connect(func(): schema.fit_to_view())
	r2.add_child(fit)
	var sett := Button.new()
	sett.text = "USTAWIENIA"
	sett.pressed.connect(func(): settings_dialog.popup_centered())
	r2.add_child(sett)
	var hlp := Button.new()
	hlp.text = "POMOC (F1)"
	hlp.pressed.connect(func(): help_dialog.popup_centered())
	r2.add_child(hlp)
	var menu := Button.new()
	menu.text = "ZAKOŃCZ DYŻUR"
	menu.pressed.connect(func(): exit_dialog.popup_centered())
	r2.add_child(menu)
	top_vb.add_child(r2)
	top.add_child(top_vb)
	ui.add_child(top)

	_build_mini()
	_build_bottom()
	_build_signal_popup()
	_build_tutorial()

	settings_dialog = SettingsDialog.new()
	ui.add_child(settings_dialog)
	help_dialog = AcceptDialog.new()
	help_dialog.title = "Pomoc — obsługa pulpitu nastawczego"
	help_dialog.dialog_text = """NASTAWIANIE PRZEBIEGU (dwuprzyciskowe, jak na kolei)
1. Wybierz rodzaj polecenia: PRZEBIEG POCIĄGOWY albo PRZEBIEG MANEWROWY.
2. Naciśnij przycisk POCZĄTKU drogi przebiegu — sygnalizator, spod którego
   ma odbyć się jazda.
3. Naciśnij przycisk KOŃCA drogi przebiegu — sygnalizator na końcu toru
   albo przycisk szlaku (prostokąt na krańcu pulpitu).
Urządzenia wybiorą drogę przebiegu, przestawią rozjazdy (odcinek miga na
niebiesko), utwierdzą przebieg (biel), a potem podadzą sygnał zezwalający.

POZOSTAŁE POLECENIA
ZD / ZDM — zwolnienie drogi przebiegu pociągowego / manewrowego.
ZW  — indywidualne przestawienie rozjazdu (+ / −).
ZWP — zwolnienie awaryjne przebiegu z kontrolą czasu 180 s.
OPS — opis wskazanego elementu.

MENU SYGNALIZATORA — prawy przycisk myszy na sygnalizatorze:
STOP / OSTOP — nakaz i odwołanie sygnału „Stój”.
SZ / SZP — sygnał zastępczy jednorazowy / powtarzalny (przy usterce semafora).
NSZ / NSZP — skasowanie sygnału zastępczego.
WTAB / KTAB — założenie i skasowanie tabliczki ostrzegawczej.

ZAPOWIADANIE — wyprawienie pociągu na szlak wymaga pozwolenia sąsiedniego
posterunku (ekran ŁĄCZNOŚĆ). Po przyjeździe potwierdź przyjazd, po odjeździe
oznajmij odjazd. Usterki usuwane są dopiero po zgłoszeniu właściwej służbie.

WIDOK: prawy przycisk myszy — przesuwanie, rolka — powiększenie.
KLAWISZE: Spacja — pauza, 1/2/3/4 — tempo, F1–F5 — ekrany, Esc — wyjście."""
	ui.add_child(help_dialog)
	exit_dialog = ConfirmationDialog.new()
	exit_dialog.title = "Zakończenie dyżuru"
	exit_dialog.dialog_text = "Zakończyć dyżur i wrócić do menu?\nEDR zostanie zapisany do pliku."
	exit_dialog.confirmed.connect(func(): GameState.back_to_menu())
	ui.add_child(exit_dialog)


func _build_mini() -> void:
	mini = PanelContainer.new()
	mini.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	mini.offset_left = -430.0
	mini.offset_top = 86.0
	mini.offset_right = -12.0
	var vb := VBoxContainer.new()
	var head := HBoxContainer.new()
	var title := Label.new()
	title.text = "NAJBLIŻSZE POCIĄGI"
	title.add_theme_font_size_override("font_size", 12)
	title.add_theme_color_override("font_color", UICommon.COL_AKCENT)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(title)
	var full := Button.new()
	full.text = "pełny rozkład"
	full.add_theme_font_size_override("font_size", 10)
	full.pressed.connect(func(): GameState.open_scene(GameState.SCENE_TIMETABLE))
	head.add_child(full)
	mini_toggle = Button.new()
	mini_toggle.text = "▲"
	mini_toggle.tooltip_text = "Zwiń / rozwiń okno"
	mini_toggle.pressed.connect(_toggle_mini)
	head.add_child(mini_toggle)
	vb.add_child(head)
	mini_body = VBoxContainer.new()
	mini_rows = VBoxContainer.new()
	mini_rows.add_theme_constant_override("separation", 1)
	mini_body.add_child(mini_rows)
	vb.add_child(mini_body)
	mini.add_child(vb)
	ui.add_child(mini)


func _toggle_mini() -> void:
	mini_collapsed = not mini_collapsed
	mini_body.visible = not mini_collapsed
	mini_toggle.text = "▼" if mini_collapsed else "▲"


func _build_bottom() -> void:
	var bottom := PanelContainer.new()
	bottom.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	bottom.offset_top = -56.0
	var vb := VBoxContainer.new()
	sel_lbl = Label.new()
	sel_lbl.add_theme_font_size_override("font_size", 12)
	sel_lbl.add_theme_color_override("font_color", UICommon.COL_SZARY)
	vb.add_child(sel_lbl)
	msg_lbl = Label.new()
	msg_lbl.add_theme_font_size_override("font_size", 13)
	msg_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vb.add_child(msg_lbl)
	bottom.add_child(vb)
	ui.add_child(bottom)


func _build_signal_popup() -> void:
	sig_popup = PopupPanel.new()
	var vb := VBoxContainer.new()
	var t := Label.new()
	t.name = "Tytul"
	t.add_theme_color_override("font_color", UICommon.COL_AKCENT)
	vb.add_child(t)
	var grid := GridContainer.new()
	grid.columns = 4
	for cmd in SimCore.SIGNAL_CMDS:
		var b := Button.new()
		b.text = cmd
		b.custom_minimum_size = Vector2(64, 0)
		b.pressed.connect(func():
			sim.exec_signal_cmd(sig_popup_id, cmd)
			sig_popup.hide())
		sig_buttons[cmd] = b
		grid.add_child(b)
	vb.add_child(grid)
	sig_popup.add_child(vb)
	ui.add_child(sig_popup)


func _open_signal_menu(sig_id: String, screen_pos: Vector2) -> void:
	sig_popup_id = sig_id
	var t := sig_popup.get_child(0).get_node("Tytul") as Label
	var sg: Dictionary = sim.layout.signals[sig_id]
	t.text = "%s — %s (%s)" % [sig_id, str(sg["typ"]), Interlocking.aspect_name(sim.inter.aspect(sig_id))]
	var en := sim.signal_menu_enabled(sig_id)
	for cmd in SimCore.SIGNAL_CMDS:
		(sig_buttons[cmd] as Button).disabled = not bool(en.get(cmd, false))
	sig_popup.popup(Rect2i(Vector2i(screen_pos) + Vector2i(6, 6), Vector2i(300, 90)))


func _build_tutorial() -> void:
	if sim.tutorial == null:
		return
	tut_panel = PanelContainer.new()
	tut_panel.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	tut_panel.offset_left = 12.0
	tut_panel.offset_right = 620.0
	tut_panel.offset_top = -230.0
	tut_panel.offset_bottom = -62.0
	var vb := VBoxContainer.new()
	tut_head = Label.new()
	tut_head.add_theme_color_override("font_color", UICommon.COL_AKCENT)
	tut_head.add_theme_font_size_override("font_size", 12)
	vb.add_child(tut_head)
	tut_text = Label.new()
	tut_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	tut_text.size_flags_vertical = Control.SIZE_EXPAND_FILL
	tut_text.add_theme_font_size_override("font_size", 13)
	vb.add_child(tut_text)
	var hb := HBoxContainer.new()
	tut_next = Button.new()
	tut_next.text = "Dalej ▶"
	tut_next.pressed.connect(func():
		sim.tutorial.next_step()
		_refresh_tutorial())
	hb.add_child(tut_next)
	var skip := Button.new()
	skip.text = "Zakończ samouczek"
	skip.pressed.connect(func():
		sim.tutorial.skip()
		_refresh_tutorial())
	hb.add_child(skip)
	vb.add_child(hb)
	tut_panel.add_child(vb)
	ui.add_child(tut_panel)


# --------------------------------------------------------------- odświeżanie

func _refresh_cmd() -> void:
	for cmd in cmd_buttons:
		(cmd_buttons[cmd] as Button).button_pressed = (cmd == sim.cmd_mode)
	pause_btn.text = "▶" if sim.paused else "⏸"
	for b in speed_btns:
		b.button_pressed = absf(float(b.get_meta("speed")) - sim.time_scale) < 0.01
	_refresh_sel()


func _refresh_sel() -> void:
	if sel_lbl == null:
		return
	var parts: Array = []
	parts.append("Polecenie: %s" % str(SimCore.CMD_LABELS.get(sim.cmd_mode, sim.cmd_mode)))
	if sim.pending_start != "":
		parts.append("początek drogi przebiegu: %s — wskaż koniec" % sim.pending_start)
	var czek := 0
	for lid in sim.queues:
		czek += (sim.queues[lid] as Array).size()
	parts.append("oczekuje przed stacją: %d" % czek)
	parts.append("na stacji: %d" % sim.trains.size())
	var awar: Array = []
	for r in sim.inter.routes.values():
		if float(r["emergency_at"]) > 0.0:
			awar.append("%s: %ds" % [str(r["signal_id"]), int(float(r["emergency_at"]) - sim.sim_time)])
	if not awar.is_empty():
		parts.append("zwolnienie awaryjne — " + ", ".join(awar))
	sel_lbl.text = "   |   ".join(parts)


func _refresh_badges() -> void:
	if comms_btn != null:
		var n := sim.comms.pending_calls().size()
		comms_btn.text = "ŁĄCZNOŚĆ (F5)" if n == 0 else "☎ ŁĄCZNOŚĆ (%d) (F5)" % n
		comms_btn.add_theme_color_override("font_color",
			Color("f59e0b") if n > 0 else UICommon.COL_TEKST)
	if events_btn != null:
		var m := sim.events.unreported_count()
		events_btn.text = "ZDARZENIA (F4)" if m == 0 else "⚠ ZDARZENIA (%d) (F4)" % m
		events_btn.add_theme_color_override("font_color",
			Color("cf1020") if m > 0 else UICommon.COL_TEKST)


func _refresh_mini() -> void:
	if mini_rows == null:
		return
	for c in mini_rows.get_children():
		c.queue_free()
	var lista := sim.tt.upcoming(sim.sim_time, 4)
	if lista.is_empty():
		mini_rows.add_child(UICommon.small("Brak zapowiedzianych pociągów."))
		return
	var hdr := HBoxContainer.new()
	for txt in [["Pociąg", 96], ["Relacja", 170], ["Tor", 34], ["Godz.", 52], ["Stan", 96]]:
		var l := Label.new()
		l.text = str(txt[0])
		l.custom_minimum_size = Vector2(float(txt[1]), 0)
		l.add_theme_font_size_override("font_size", 10)
		l.add_theme_color_override("font_color", UICommon.COL_AKCENT)
		hdr.add_child(l)
	mini_rows.add_child(hdr)
	for e in lista:
		var row := HBoxContainer.new()
		var t_ref: float = e["dep"] if float(e["dep"]) >= 0.0 else e["arr"]
		if float(e["actual_arr"]) < 0.0 and float(e["arr"]) >= 0.0:
			t_ref = float(e["arr"])
		var kol := Color("d7dee8")
		if int(e["delay"]) > 0:
			kol = Color("f0b429")
		var cells := [
			["%s %s" % [str(e["kat"]), str(e["nr"])], 96],
			["%s → %s" % [str(e["z"]), str(e["do"])], 170],
			[str(e["tor"]), 34],
			[SimUtil.fmt_hm(t_ref) + ("+%d" % int(e["delay"]) if int(e["delay"]) > 0 else ""), 52],
			[str(e["status"]), 96],
		]
		for c2 in cells:
			var l2 := Label.new()
			l2.text = str(c2[0])
			l2.custom_minimum_size = Vector2(float(c2[1]), 0)
			l2.clip_text = true
			l2.add_theme_font_size_override("font_size", 11)
			l2.add_theme_color_override("font_color", kol)
			row.add_child(l2)
		mini_rows.add_child(row)


func _refresh_tutorial() -> void:
	if tut_panel == null:
		return
	if sim.tutorial == null or sim.tutorial.done:
		tut_panel.visible = false
		return
	tut_panel.visible = true
	tut_head.text = sim.tutorial.header()
	tut_text.text = sim.tutorial.text()
	tut_next.visible = sim.tutorial.manual_next_allowed()


func _on_message(text: String, level: int) -> void:
	if msg_lbl == null:
		return
	msg_lbl.text = text
	match level:
		2:
			msg_lbl.add_theme_color_override("font_color", Color("f87171"))
		1:
			msg_lbl.add_theme_color_override("font_color", Color("fbbf24"))
		_:
			msg_lbl.add_theme_color_override("font_color", Color("d7dee8"))
