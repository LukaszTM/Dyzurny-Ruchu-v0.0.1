extends Node
## Ekran główny — pulpit nastawczy w układzie jak w SimRail:
## na środku u góry pasek poleceń (PRZEBIEG POCIĄGOWY … OPS), pod nim
## „Dyżurny ruchu: …” i nazwa posterunku; zegar w lewym dolnym rogu;
## menu sygnalizatora jako pozioma listwa STOP…KTAB pod paskiem poleceń;
## dyskretne przyciski ekranów w prawym górnym rogu; zwijane okno
## skróconego rozkładu z czterema najbliższymi pociągami.

var sim: SimCore
var schema: SchemaView
var ui: CanvasLayer
var cmd_buttons := {}
var clock_lbl: Label
var date_lbl: Label
var msg_lbl: Label
var stan_lbl: Label
var pause_btn: Button
var speed_btns: Array = []
var mini: PanelContainer
var mini_body: VBoxContainer
var mini_rows: VBoxContainer
var mini_collapsed := false
var mini_toggle: Button
var comms_btn: Button
var events_btn: Button
var nav_btns: Array = []
var sig_bar: PanelContainer
var sig_bar_title: Label
var sig_bar_id := ""
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
	EventBus.element_selected.connect(func(_k, _i): _refresh_stan())
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
	date_lbl.text = sim.date_str()
	schema.queue_redraw()
	_acc += delta
	if _acc >= 1.0:
		_acc = 0.0
		_refresh_mini()
		_refresh_badges()
		_refresh_stan()


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
			if sig_bar.visible:
				sig_bar.visible = false
			elif sim.pending_start != "":
				sim.pending_start = ""
				EventBus.panel_state_changed.emit()
			else:
				exit_dialog.popup_centered()


# ------------------------------------------------------------------ budowa --

func _build_ui() -> void:
	ui = CanvasLayer.new()
	add_child(ui)

	# --- pasek poleceń wyśrodkowany u góry (jak w SimRail) ---
	var top := VBoxContainer.new()
	top.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	top.offset_top = 8.0
	top.add_theme_constant_override("separation", 2)
	top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 5)
	for cmd in [SimCore.CMD_PP, SimCore.CMD_PM, SimCore.CMD_ZD, SimCore.CMD_ZDM,
			SimCore.CMD_ZW, SimCore.CMD_ZWP, SimCore.CMD_OPS]:
		var b := Button.new()
		b.text = str(SimCore.CMD_LABELS[cmd])
		b.tooltip_text = str(SimCore.CMD_HELP[cmd])
		b.focus_mode = Control.FOCUS_NONE
		b.pressed.connect(func(): sim.set_cmd_mode(cmd))
		cmd_buttons[cmd] = b
		row.add_child(b)
	top.add_child(row)
	var dyz := Label.new()
	dyz.text = "Dyżurny ruchu: %s" % Settings.dyzurny_name
	dyz.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	dyz.add_theme_font_size_override("font_size", 11)
	dyz.add_theme_color_override("font_color", Color("8a8a8a"))
	top.add_child(dyz)
	var st_name := Label.new()
	st_name.text = sim.layout.station_name.to_upper()
	st_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	st_name.add_theme_font_size_override("font_size", 22)
	st_name.add_theme_color_override("font_color", Color("8a8a8a"))
	top.add_child(st_name)
	ui.add_child(top)

	# --- listwa menu sygnalizatora (STOP…KTAB) pod paskiem poleceń ---
	sig_bar = PanelContainer.new()
	sig_bar.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	sig_bar.offset_top = 96.0
	sig_bar.visible = false
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color("101010")
	sb.border_color = Color("3a3a3a")
	sb.set_border_width_all(1)
	sb.content_margin_left = 8
	sb.content_margin_right = 8
	sb.content_margin_top = 4
	sb.content_margin_bottom = 6
	sig_bar.add_theme_stylebox_override("panel", sb)
	var sig_vb := VBoxContainer.new()
	sig_bar_title = Label.new()
	sig_bar_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sig_bar_title.add_theme_font_size_override("font_size", 12)
	sig_bar_title.add_theme_color_override("font_color", Color("e8e8e8"))
	sig_vb.add_child(sig_bar_title)
	var sig_hb := HBoxContainer.new()
	sig_hb.add_theme_constant_override("separation", 5)
	for cmd in SimCore.SIGNAL_CMDS:
		var b2 := Button.new()
		b2.text = cmd
		b2.custom_minimum_size = Vector2(58, 0)
		b2.focus_mode = Control.FOCUS_NONE
		b2.pressed.connect(func():
			sim.exec_signal_cmd(sig_bar_id, cmd)
			_refresh_signal_bar())
		sig_buttons[cmd] = b2
		sig_hb.add_child(b2)
	var zamknij := Button.new()
	zamknij.text = "✕"
	zamknij.focus_mode = Control.FOCUS_NONE
	zamknij.pressed.connect(func(): sig_bar.visible = false)
	UICommon.style_nav_button(zamknij)
	sig_hb.add_child(zamknij)
	sig_vb.add_child(sig_hb)
	sig_bar.add_child(sig_vb)
	ui.add_child(sig_bar)

	# --- nawigacja: prawy dolny róg (nie zasłania paska poleceń) ---
	var nav := HBoxContainer.new()
	nav.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	nav.offset_left = -664.0
	nav.offset_top = -34.0
	nav.offset_right = -8.0
	nav.offset_bottom = -8.0
	nav.alignment = BoxContainer.ALIGNMENT_END
	nav.add_theme_constant_override("separation", 4)
	var defs := [
		["ROZKŁAD F2", GameState.SCENE_TIMETABLE],
		["EDR F3", GameState.SCENE_EDR],
		["ZDARZENIA F4", GameState.SCENE_EVENTS],
		["ŁĄCZNOŚĆ F5", GameState.SCENE_COMMS],
	]
	for item in defs:
		var nb := Button.new()
		nb.text = str(item[0])
		nb.focus_mode = Control.FOCUS_NONE
		var path := str(item[1])
		nb.pressed.connect(func(): GameState.open_scene(path))
		UICommon.style_nav_button(nb)
		if path == GameState.SCENE_COMMS:
			comms_btn = nb
		elif path == GameState.SCENE_EVENTS:
			events_btn = nb
		nav_btns.append(nb)
		nav.add_child(nb)
	var sett := Button.new()
	sett.text = "USTAW."
	sett.focus_mode = Control.FOCUS_NONE
	sett.pressed.connect(func(): settings_dialog.popup_centered())
	UICommon.style_nav_button(sett)
	nav.add_child(sett)
	var hlp := Button.new()
	hlp.text = "POMOC F1"
	hlp.focus_mode = Control.FOCUS_NONE
	hlp.pressed.connect(func(): help_dialog.popup_centered())
	UICommon.style_nav_button(hlp)
	nav.add_child(hlp)
	var menu := Button.new()
	menu.text = "KONIEC"
	menu.focus_mode = Control.FOCUS_NONE
	menu.pressed.connect(func(): exit_dialog.popup_centered())
	UICommon.style_nav_button(menu)
	nav.add_child(menu)
	ui.add_child(nav)

	# --- lewy górny róg: pauza i tempo ---
	var czas := HBoxContainer.new()
	czas.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	czas.offset_left = 8.0
	czas.offset_top = 6.0
	czas.add_theme_constant_override("separation", 4)
	pause_btn = Button.new()
	pause_btn.text = "⏸"
	pause_btn.focus_mode = Control.FOCUS_NONE
	pause_btn.pressed.connect(func(): sim.toggle_pause())
	UICommon.style_nav_button(pause_btn)
	czas.add_child(pause_btn)
	if not sim.real_mode:
		for sp in [1.0, 2.0, 5.0, 10.0]:
			var b3 := Button.new()
			b3.text = "%dx" % int(sp)
			b3.focus_mode = Control.FOCUS_NONE
			b3.set_meta("speed", sp)
			b3.pressed.connect(func(): sim.set_speed(sp))
			UICommon.style_nav_button(b3)
			speed_btns.append(b3)
			czas.add_child(b3)
	else:
		var rt := Label.new()
		rt.text = "CZAS RZECZYWISTY"
		rt.add_theme_font_size_override("font_size", 11)
		rt.add_theme_color_override("font_color", Color("6a6a6a"))
		czas.add_child(rt)
	var fit := Button.new()
	fit.text = "WIDOK"
	fit.tooltip_text = "Dopasuj widok pulpitu"
	fit.focus_mode = Control.FOCUS_NONE
	fit.pressed.connect(func(): schema.fit_to_view())
	UICommon.style_nav_button(fit)
	czas.add_child(fit)
	ui.add_child(czas)

	_build_mini()

	# --- zegar (z datą) w lewym dolnym rogu (jak w SimRail) ---
	var zegar_vb := VBoxContainer.new()
	zegar_vb.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	zegar_vb.offset_left = 14.0
	zegar_vb.offset_top = -66.0
	zegar_vb.add_theme_constant_override("separation", 0)
	zegar_vb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	date_lbl = Label.new()
	date_lbl.add_theme_font_size_override("font_size", 12)
	date_lbl.add_theme_color_override("font_color", Color("6a6a6a"))
	zegar_vb.add_child(date_lbl)
	clock_lbl = Label.new()
	clock_lbl.add_theme_font_size_override("font_size", 28)
	clock_lbl.add_theme_color_override("font_color", Color("9a9a9a"))
	zegar_vb.add_child(clock_lbl)
	ui.add_child(zegar_vb)

	# --- dolny środek: stan pulpitu + komunikat ---
	var bot := VBoxContainer.new()
	bot.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	bot.offset_top = -84.0
	bot.offset_bottom = -34.0
	bot.offset_left = 240.0
	bot.offset_right = -240.0
	bot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stan_lbl = Label.new()
	stan_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	stan_lbl.add_theme_font_size_override("font_size", 11)
	stan_lbl.add_theme_color_override("font_color", Color("6a7a8a"))
	bot.add_child(stan_lbl)
	msg_lbl = Label.new()
	msg_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	msg_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	msg_lbl.add_theme_font_size_override("font_size", 13)
	bot.add_child(msg_lbl)
	ui.add_child(bot)

	_build_tutorial()

	settings_dialog = SettingsDialog.new()
	ui.add_child(settings_dialog)
	help_dialog = AcceptDialog.new()
	help_dialog.title = "Pomoc — obsługa pulpitu nastawczego"
	help_dialog.dialog_text = """NASTAWIANIE PRZEBIEGU (dwuprzyciskowe)
1. Wybierz na górnym pasku: PRZEBIEG POCIĄGOWY albo PRZEBIEG MANEWROWY.
2. Kliknij przycisk POCZĄTKU drogi przebiegu (sygnalizator) — dostanie
   seledynową obwódkę.
3. Kliknij przycisk KOŃCA (sygnalizator na końcu toru albo kasetkę szlaku).
Urządzenia wybiorą drogę, przestawią rozjazdy (odcinki migają), utwierdzą
przebieg (biel) i podadzą sygnał — grot semafora zmieni kolor na zielony
(jazda pociągowa) albo biały (manewrowa).

POZOSTAŁE POLECENIA PASKA
ZD / ZDM — zwolnienie drogi przebiegu pociągowego / manewrowego.
ZW  — indywidualne przestawienie rozjazdu (+ / −).
ZWP — zwolnienie awaryjne przebiegu z kontrolą czasu 180 s.
OPS — opis wskazanego elementu.

MENU SYGNALIZATORA — prawy przycisk myszy na sygnalizatorze otwiera listwę:
STOP / OSTOP — nakaz i odwołanie sygnału „Stój”.
SZ / SZP — sygnał zastępczy jednorazowy / powtarzalny (czerwone przyciski).
NSZ / NSZP — skasowanie sygnału zastępczego.
WTAB / KTAB — założenie i skasowanie tabliczki ostrzegawczej.

ZAPOWIADANIE (ekran ŁĄCZNOŚĆ, F5) — wyprawienie pociągu wymaga pozwolenia
sąsiedniego posterunku; po odjeździe oznajmij odjazd, po przyjeździe
potwierdź przyjazd. Usterki zgłaszaj właściwej służbie (ekran ZDARZENIA).

WIDOK: prawy przycisk myszy — przesuwanie, rolka — zoom.
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
	mini.offset_left = -450.0
	mini.offset_top = 8.0
	mini.offset_right = -8.0
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color("0c0c0c")
	sb.border_color = Color("3a3a3a")
	sb.set_border_width_all(1)
	sb.content_margin_left = 8
	sb.content_margin_right = 8
	sb.content_margin_top = 4
	sb.content_margin_bottom = 6
	mini.add_theme_stylebox_override("panel", sb)
	var vb := VBoxContainer.new()
	var head := HBoxContainer.new()
	var title := Label.new()
	title.text = "NAJBLIŻSZE POCIĄGI"
	title.add_theme_font_size_override("font_size", 11)
	title.add_theme_color_override("font_color", Color("8a8a8a"))
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(title)
	var full := Button.new()
	full.text = "wykaz"
	full.focus_mode = Control.FOCUS_NONE
	full.pressed.connect(func(): GameState.open_scene(GameState.SCENE_TIMETABLE))
	UICommon.style_nav_button(full)
	head.add_child(full)
	mini_toggle = Button.new()
	mini_toggle.text = "▲"
	mini_toggle.focus_mode = Control.FOCUS_NONE
	mini_toggle.tooltip_text = "Zwiń / rozwiń okno"
	mini_toggle.pressed.connect(_toggle_mini)
	UICommon.style_nav_button(mini_toggle)
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


func _open_signal_menu(sig_id: String, _screen_pos: Vector2) -> void:
	sig_bar_id = sig_id
	sig_bar.visible = true
	_refresh_signal_bar()


func _refresh_signal_bar() -> void:
	if sig_bar_id == "" or not sim.layout.signals.has(sig_bar_id):
		sig_bar.visible = false
		return
	var sg: Dictionary = sim.layout.signals[sig_bar_id]
	sig_bar_title.text = "%s  —  %s,  %s" % [
		sig_bar_id, str(sg["typ"]), Interlocking.aspect_name(sim.inter.aspect(sig_bar_id))]
	var en := sim.signal_menu_enabled(sig_bar_id)
	for cmd in SimCore.SIGNAL_CMDS:
		var czerw: bool = cmd in ["SZ", "SZP", "NSZ", "NSZP"]
		UICommon.style_signal_button(sig_buttons[cmd] as Button, bool(en.get(cmd, false)), czerw)


func _build_tutorial() -> void:
	if sim.tutorial == null:
		return
	tut_panel = PanelContainer.new()
	tut_panel.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	tut_panel.offset_left = 12.0
	tut_panel.offset_right = 620.0
	tut_panel.offset_top = -252.0
	tut_panel.offset_bottom = -58.0
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
		UICommon.style_cmd_button(cmd_buttons[cmd] as Button, cmd == sim.cmd_mode)
	pause_btn.text = "▶" if sim.paused else "⏸"
	for b in speed_btns:
		var akt: bool = absf(float(b.get_meta("speed")) - sim.time_scale) < 0.01
		b.add_theme_color_override("font_color", Color("e8e8e8") if akt else Color("9a9a9a"))
	_refresh_stan()


func _refresh_stan() -> void:
	if stan_lbl == null:
		return
	var parts: Array = []
	parts.append(str(SimCore.CMD_LABELS.get(sim.cmd_mode, sim.cmd_mode)))
	if sim.pending_start != "":
		parts.append("początek: %s — wskaż koniec drogi przebiegu" % sim.pending_start)
	var czek := 0
	for lid in sim.queues:
		czek += (sim.queues[lid] as Array).size()
	if czek > 0:
		parts.append("oczekuje: %d" % czek)
	parts.append("na stacji: %d" % sim.trains.size())
	var awar: Array = []
	for r in sim.inter.routes.values():
		if float(r["emergency_at"]) > 0.0:
			awar.append("%s %ds" % [str(r["signal_id"]), int(float(r["emergency_at"]) - sim.sim_time)])
	if not awar.is_empty():
		parts.append("ZWP: " + ", ".join(awar))
	if sim.paused:
		parts.append("PAUZA")
	stan_lbl.text = "   •   ".join(parts)


func _refresh_badges() -> void:
	if comms_btn != null:
		var n := sim.comms.pending_calls().size()
		comms_btn.text = "ŁĄCZNOŚĆ F5" if n == 0 else "☎ ŁĄCZNOŚĆ (%d)" % n
		UICommon.style_nav_button(comms_btn, n > 0)
	if events_btn != null:
		var m := sim.events.unreported_count()
		events_btn.text = "ZDARZENIA F4" if m == 0 else "⚠ ZDARZENIA (%d)" % m
		UICommon.style_nav_button(events_btn, m > 0)


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
	for txt in [["Pociąg", 92], ["Relacja", 168], ["Tor", 30], ["Godz.", 56], ["Stan", 90]]:
		var l := Label.new()
		l.text = str(txt[0])
		l.custom_minimum_size = Vector2(float(txt[1]), 0)
		l.add_theme_font_size_override("font_size", 10)
		l.add_theme_color_override("font_color", Color("6a6a6a"))
		hdr.add_child(l)
	mini_rows.add_child(hdr)
	for e in lista:
		var row := HBoxContainer.new()
		var t_ref: float = e["dep"] if float(e["dep"]) >= 0.0 else e["arr"]
		if float(e["actual_arr"]) < 0.0 and float(e["arr"]) >= 0.0:
			t_ref = float(e["arr"])
		var kol := Color("c8c8c8")
		if int(e["delay"]) > 0:
			kol = Color("f0b429")
		var cells := [
			["%s %s" % [str(e["kat"]), str(e["nr"])], 92],
			["%s → %s" % [str(e["z"]), str(e["do"])], 168],
			[str(e["tor"]), 30],
			[SimUtil.fmt_hm(t_ref) + ("+%d" % int(e["delay"]) if int(e["delay"]) > 0 else ""), 56],
			[str(e["status"]), 90],
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
			msg_lbl.add_theme_color_override("font_color", Color("c8c8c8"))
