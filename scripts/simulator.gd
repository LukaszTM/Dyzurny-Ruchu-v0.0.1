extends Node
## Główna scena symulacji: buduje pulpit i interfejs, prowadzi zegar
## symulacji, spawnowanie pociągów, przydział przebiegów, statystyki
## oraz komunikację online (rozkład/opóźnienia).

const APPROACH_LEAD := 150.0

var layout: StationLayout
var inter: Interlocking
var tt: TimetableManager
var gen: TrafficGenerator
var events: RandomEventManager
var dlog: DispatcherLog
var tutorial = null

var sim_time := 0.0
var time_scale := 1.0
var paused := false
var trains := {}          # id -> Train
var next_train_id := 1
var portal_queues := {}   # portal_id -> Array[int]
var shunt_jobs: Array = []
var _next_job_id := 1
var selected_signal := ""
var shunt_mode := false
var stats := {"handled": 0, "dep_count": 0, "punctual": 0, "irregular": 0}

var schema: SchemaView
var ui_layer: CanvasLayer
var clock_label: Label
var pause_btn: Button
var speed_btns: Array = []
var msg_label: Label
var _msg_until := 0.0
var sel_label: Label
var sel_release_btn: Button
var sel_sz_btn: Button
var shunt_check: CheckButton
var tabs: TabContainer
var tt_panel: TimetablePanel
var log_panel: LogPanel
var events_panel: EventsPanel
var traffic_panel: TrafficPanel
var settings_dialog: SettingsDialog
var help_dialog: AcceptDialog
var exit_dialog: ConfirmationDialog
var http_delays: HTTPRequest
var http_tt: HTTPRequest
var _refresh_accum := 0.0
var _online_timer := 0.0


func _ready() -> void:
	var loc := Locations.get_location(GameState.location_id)
	if loc.is_empty():
		push_error("Brak lokalizacji!")
		GameState.back_to_menu()
		return
	layout = StationLayout.new()
	layout.load_file("%s/%s" % [loc["dir"], loc.get("layout", "layout.json")])
	inter = Interlocking.new(layout)
	dlog = DispatcherLog.new(str(loc.get("name", "Posterunek")))
	tt = TimetableManager.new(self)
	gen = TrafficGenerator.new(self)
	events = RandomEventManager.new(self)
	for pid in layout.portals:
		portal_queues[pid] = []

	match GameState.mode:
		GameState.MODE_TIMETABLE:
			tt.load_file("%s/%s" % [loc["dir"], loc.get("timetable", "timetable.json")])
			sim_time = tt.start_time
			tt.skip_past(sim_time)
		GameState.MODE_RANDOM:
			sim_time = SimUtil.parse_hhmm(str(loc.get("start_time_random", "12:00")))
			gen.enabled = true
		GameState.MODE_TUTORIAL:
			sim_time = 8.0 * 3600.0
			events.freq_min = 0.0

	schema = SchemaView.new()
	add_child(schema)
	schema.setup(self)
	_build_ui()

	http_delays = HTTPRequest.new()
	add_child(http_delays)
	http_delays.request_completed.connect(_on_delays_response)
	http_tt = HTTPRequest.new()
	add_child(http_tt)
	http_tt.request_completed.connect(_on_tt_response)

	dlog.add(sim_time, "Ruch", "Objęcie dyżuru na posterunku %s. Tryb: %s." % [
		layout.station_name, GameState.mode_name()])

	if GameState.mode == GameState.MODE_TIMETABLE and Settings.online_enabled:
		request_online_update(false)

	if GameState.mode == GameState.MODE_TUTORIAL:
		tutorial = TutorialManager.new(self)
		tutorial.start()

	show_message("Kliknij semafor, potem cel przebiegu (semafor lub portal wyjazdowy). PPM/środkowy — przesuwanie, rolka — zoom, [M] — tryb manewrowy, [Spacja] — pauza.")


func _process(delta: float) -> void:
	var dt := 0.0 if paused else delta * time_scale
	if dt > 0.0:
		sim_time += dt
		tt.step(sim_time)
		gen.step(sim_time)
		events.step(sim_time)
		_step_trains(dt)
		_rebuild_occupancy()
		_check_ready()
	clock_label.text = SimUtil.fmt_time(sim_time)
	if msg_label.text != "" and Time.get_ticks_msec() / 1000.0 > _msg_until:
		msg_label.text = ""
	_refresh_accum += delta
	if _refresh_accum >= 1.0:
		_refresh_accum = 0.0
		tt_panel.refresh()
		events_panel.refresh()
		traffic_panel.refresh()
	if Settings.online_enabled and GameState.mode == GameState.MODE_TIMETABLE:
		_online_timer += delta
		if _online_timer > 90.0:
			_online_timer = 0.0
			request_online_update(false)
	schema.queue_redraw()


func _unhandled_key_input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if key == null or not key.pressed or key.echo:
		return
	match key.keycode:
		KEY_SPACE:
			_toggle_pause()
		KEY_M:
			shunt_check.button_pressed = not shunt_check.button_pressed
		KEY_1:
			_set_speed(1.0)
		KEY_2:
			_set_speed(2.0)
		KEY_3:
			_set_speed(5.0)
		KEY_4:
			_set_speed(10.0)
		KEY_F1:
			help_dialog.popup_centered()
		KEY_ESCAPE:
			if selected_signal != "":
				_select_signal("")
			else:
				exit_dialog.popup_centered()


## --- Symulacja pociągów ---

func _step_trains(dt: float) -> void:
	var to_remove: Array = []
	for t in trains.values():
		var result: String = t.step(dt, sim_time, inter)
		match result:
			"arrived":
				_on_train_arrived(t)
			"done":
				to_remove.append(t)
	for t in to_remove:
		_on_train_gone(t)


func _rebuild_occupancy() -> void:
	inter.occupied_segs.clear()
	for t in trains.values():
		if t.state == Train.State.WAITING or t.state == Train.State.DONE:
			continue
		for sid in t.covered:
			inter.occupied_segs[sid] = t.id


func _check_ready() -> void:
	for t in trains.values():
		if t.state != Train.State.AT_PLATFORM:
			continue
		if t.tt_index >= 0 and t.flag_start:
			continue  # skład czeka na przemianowanie w pociąg rozkładowy
		var dep_eff: float
		if t.flag_koniec or t.is_shunt_unit:
			dep_eff = t.actual_arr + 150.0
		elif t.sched_dep >= 0.0:
			dep_eff = maxf(t.sched_dep + t.delay_min * 60.0, t.actual_arr + t.min_dwell())
		else:
			dep_eff = t.actual_arr + t.min_dwell()
		if sim_time >= dep_eff - 15.0:
			t.state = Train.State.READY
			if t.flag_koniec or t.is_shunt_unit:
				dlog.add(sim_time, "Ruch", "Skład poc. %s do odstawienia z toru %s do Grochowa (jazda manewrowa)." % [t.nr, t.track_nr])
				add_shunt_job("odstawienie", "Odstawić skład %s z toru %s do Grochowa." % [t.nr, t.track_nr], t.id)
			else:
				dlog.add(sim_time, "Ruch", "Poc. %s gotowy do odjazdu z toru %s (kierunek: %s)." % [t.title(), t.track_nr, t.to_name])
			EventBus.train_ready.emit(t)


func spawn_from_spec(spec: Dictionary) -> Train:
	var t := Train.new()
	t.id = next_train_id
	next_train_id += 1
	t.nr = str(spec["nr"])
	t.category = str(spec["kat"])
	t.display_name = str(spec.get("nazwa", ""))
	t.from_name = str(spec["z"])
	t.to_name = str(spec["do"])
	t.entry_portal = str(spec["we"])
	t.exit_portal = str(spec["wy"])
	t.pref_track = str(spec.get("tor", ""))
	t.sched_arr = float(spec.get("arr_sec", -1.0))
	t.sched_dep = float(spec.get("dep_sec", -1.0))
	t.delay_min = int(spec.get("delay_min", 0))
	t.flag_przelot = bool(spec.get("przelot", false))
	t.flag_koniec = bool(spec.get("koniec", false))
	t.flag_start = bool(spec.get("linked_stock", false))
	t.is_shunt_unit = bool(spec.get("man", false))
	t.tt_index = int(spec.get("tt_index", -1))
	t.length = Train.length_for(t.category)
	t.spawned_at = sim_time
	if not portal_queues.has(t.entry_portal):
		push_warning("Nieznany portal wjazdowy: %s" % t.entry_portal)
		return null
	trains[t.id] = t
	portal_queues[t.entry_portal].append(t.id)
	if t.tt_index < 0 and not t.is_shunt_unit:
		t.tt_index = tt.add_generated_entry(spec, t.id)
	var portal_name: String = layout.portals[t.entry_portal]["name"]
	if t.is_shunt_unit:
		dlog.add(sim_time, "Ruch", "Skład manewrowy %s oczekuje: %s (%s)." % [t.nr, portal_name, t.to_name])
	else:
		dlog.add(sim_time, "Ruch", "Zgłasza się poc. %s rel. %s od strony: %s, tor żąd. %s%s." % [
			t.title(), t.rel_text(), portal_name, t.pref_track, SimUtil.fmt_delay(t.delay_min)])
	EventBus.train_spawned.emit(t)
	# jeśli spod semafora wjazdowego czeka już nieobsadzony przebieg — przydziel
	var sig_id := layout.signal_at_point(t.entry_portal, int(layout.portals[t.entry_portal]["dir_in"]))
	if sig_id != "":
		var r := inter.route_of_signal(sig_id)
		if not r.is_empty() and r["train_id"] == 0:
			_assign_route(r)
	return t


func _on_train_arrived(t: Train) -> void:
	t.actual_arr = sim_time
	t.track_nr = layout.track_with_end(t.route["dest_pt"])
	inter.finish_route(t.route)
	var arr_delay := 0
	if t.sched_arr >= 0.0:
		arr_delay = int(maxf(0.0, (sim_time - t.sched_arr) / 60.0))
	if t.is_shunt_unit:
		dlog.add(sim_time, "Ruch", "Skład manewrowy %s podstawiony na tor %s." % [t.nr, t.track_nr])
		_mark_job_done_for_train(t.id, "podstawienie")
	else:
		dlog.add(sim_time, "Ruch", "Wjazd poc. %s na tor %s%s." % [t.title(), t.track_nr, SimUtil.fmt_delay(arr_delay)])
	if t.tt_index >= 0:
		tt.entries[t.tt_index]["actual_arr"] = sim_time
		tt.entry_status_update(t.tt_index, "na torze %s%s" % [t.track_nr, SimUtil.fmt_delay(arr_delay)])
	EventBus.train_arrived.emit(t)


func _on_train_gone(t: Train) -> void:
	trains.erase(t.id)
	stats["handled"] += 1
	if t.is_shunt_unit and t.exit_portal == "GR":
		_mark_job_done_for_train(t.id, "odstawienie")
		dlog.add(sim_time, "Ruch", "Skład %s odstawiony do Grochowa." % t.nr)
	else:
		dlog.add(sim_time, "Ruch", "Poc. %s opuścił posterunek (kierunek: %s)." % [t.title(), t.to_name])
	if t.tt_index >= 0 and t.actual_dep >= 0.0:
		tt.entries[t.tt_index]["actual_dep"] = t.actual_dep
	EventBus.train_removed.emit(t)


## --- Obsługa pulpitu ---

func on_schema_click(kind: String, id: String) -> void:
	match kind:
		"signal":
			if selected_signal == "":
				_select_signal(id)
			elif selected_signal == id:
				_select_signal("")
			else:
				var dest_pt: String = layout.signals[id]["point"]
				_try_route_to(dest_pt)
		"portal":
			if selected_signal != "":
				_try_route_to(id)
			else:
				var q: Array = portal_queues.get(id, [])
				var pname: String = layout.portals[id]["name"]
				if q.is_empty():
					show_message("%s — brak oczekujących pociągów." % pname)
				else:
					var first: Train = trains.get(q[0])
					show_message("%s — oczekuje: %s rel. %s (w kolejce: %d). Ustaw przebieg spod semafora wjazdowego." % [
						pname, first.title(), first.rel_text(), q.size()])
		"train":
			var t: Train = trains.get(int(id))
			if t != null:
				var extra := ""
				if t.sched_dep >= 0.0:
					extra = " Odjazd plan. %s." % SimUtil.fmt_hm(t.sched_dep)
				show_message("%s rel. %s — %s.%s" % [t.title(), t.rel_text(), t.state_text(), extra])
		_:
			_select_signal("")


func _select_signal(sig_id: String) -> void:
	selected_signal = sig_id
	if sig_id == "":
		sel_label.text = ""
		sel_release_btn.visible = false
		sel_sz_btn.visible = false
		return
	var sig: Dictionary = layout.signals[sig_id]
	var r := inter.route_of_signal(sig_id)
	var state_txt := "brak przebiegu"
	if not r.is_empty():
		state_txt = "przebieg %s do %s%s" % [
			"manewrowy" if r["kind"] == "shunt" else "pociągowy",
			r["dest_pt"],
			"" if r["open"] else " — OCZEKUJE NA Sz"]
	sel_label.text = "Semafor %s (%s): %s" % [
		sig_id, "uszkodzony!" if sig["failed"] else "sprawny", state_txt]
	sel_release_btn.visible = not r.is_empty()
	sel_sz_btn.visible = not r.is_empty() and not r["open"]
	EventBus.signal_selected.emit(sig_id)
	if r.is_empty():
		show_message("Wybrano semafor %s. Kliknij cel przebiegu: semafor na końcu toru lub portal wyjazdowy. %s" % [
			sig_id, "[TRYB MANEWROWY]" if shunt_mode else ""])


func _try_route_to(dest_pt: String) -> void:
	var sig_id := selected_signal
	var kind := "shunt" if shunt_mode else "train"
	var result := inter.set_route(sig_id, dest_pt, kind)
	if result.has("error"):
		show_message("✗ " + str(result["error"]))
		return
	var kind_txt := "manewrowy" if result["kind"] == "shunt" else "pociągowy"
	dlog.add(sim_time, "Przebieg", "Ustawiono przebieg %s: %s → %s." % [kind_txt, sig_id, dest_pt])
	if result["needs_sz"]:
		show_message("Przebieg ustawiony, ale semafor %s jest USZKODZONY — użyj przycisku „Sygnał zastępczy (Sz)”." % sig_id)
	else:
		show_message("✓ Przebieg %s: %s → %s." % [kind_txt, sig_id, dest_pt])
	_assign_route(result)
	EventBus.route_set.emit(result)
	if result["needs_sz"]:
		_select_signal(sig_id)  # zostaw wybór — potrzebny przycisk Sz
	else:
		_select_signal("")


func _assign_route(route: Dictionary) -> void:
	if route["train_id"] != 0:
		return
	var start_pt: String = route["start_pt"]
	# 1) wjazd/przelot z portalu
	if portal_queues.has(start_pt) and not portal_queues[start_pt].is_empty():
		var tid: int = portal_queues[start_pt][0]
		var t: Train = trains.get(tid)
		if t != null and t.state == Train.State.WAITING:
			portal_queues[start_pt].pop_front()
			t.begin_route(route, layout, 0.0)
			if t.tt_index >= 0:
				tt.entry_status_update(t.tt_index, "wjazd na stację")
		return
	# 2) odjazd / manewr z toru stacyjnego
	var track_nr := layout.track_with_end(start_pt)
	if track_nr != "":
		for t2 in trains.values():
			if t2.track_nr == track_nr and (t2.state == Train.State.AT_PLATFORM or t2.state == Train.State.READY):
				var early: bool = t2.state == Train.State.AT_PLATFORM and t2.sched_dep >= 0.0 \
					and sim_time < t2.sched_dep - 60.0
				t2.begin_route(route, layout, t2.length)
				t2.actual_dep = sim_time
				var dep_delay := 0
				if t2.sched_dep >= 0.0:
					dep_delay = int(maxf(0.0, (sim_time - (t2.sched_dep + t2.delay_min * 60.0)) / 60.0))
				stats["dep_count"] += 1
				if dep_delay <= 5:
					stats["punctual"] += 1
				if route["kind"] == "shunt":
					dlog.add(sim_time, "Ruch", "Jazda manewrowa składu %s z toru %s." % [t2.nr, t2.track_nr])
				else:
					dlog.add(sim_time, "Ruch", "Odjazd poc. %s z toru %s%s." % [t2.title(), t2.track_nr, SimUtil.fmt_delay(dep_delay)])
					if early:
						dlog.add(sim_time, "Ruch", "UWAGA: odjazd poc. %s przed czasem rozkładowym!" % t2.nr)
				if t2.tt_index >= 0:
					tt.entry_status_update(t2.tt_index, "odjechał%s" % SimUtil.fmt_delay(dep_delay))
				EventBus.train_departed.emit(t2)
				return


func release_selected_route() -> void:
	if selected_signal == "":
		return
	var r := inter.route_of_signal(selected_signal)
	if r.is_empty():
		show_message("Semafor %s nie ma ustawionego przebiegu." % selected_signal)
		return
	var err := inter.cancel_route(r)
	if err != "":
		show_message("✗ " + err)
		return
	# jeśli przebieg miał przydzielony, ale jeszcze stojący pociąg — cofnij go do kolejki
	if r["train_id"] != 0:
		var t: Train = trains.get(r["train_id"])
		if t != null and t.state == Train.State.MOVING and t.s <= t._start_s + 0.5:
			t.state = Train.State.WAITING if t.track_nr == "" else Train.State.READY
			t.route = {}
			if t.track_nr == "":
				portal_queues[t.entry_portal].push_front(t.id)
	stats["irregular"] += 1
	dlog.add(sim_time, "Przebieg", "Doraźne zwolnienie przebiegu spod semafora %s." % selected_signal)
	show_message("Przebieg spod %s zwolniony doraźnie (odnotowano w dzienniku)." % selected_signal)
	EventBus.route_released.emit(r["id"], true)
	_select_signal("")


func give_sz_selected() -> void:
	if selected_signal == "":
		return
	var result := inter.give_sz(selected_signal)
	if result.has("error"):
		show_message("✗ " + str(result["error"]))
		return
	stats["irregular"] += 1
	dlog.add(sim_time, "Przebieg", "Podano sygnał zastępczy (Sz) na sygnalizatorze %s." % selected_signal)
	show_message("Sygnał zastępczy na %s — jazda z prędkością ograniczoną." % selected_signal)
	EventBus.sz_used.emit(selected_signal)
	_select_signal("")


func add_shunt_job(type: String, desc: String, train_id: int) -> void:
	var job := {"id": _next_job_id, "type": type, "desc": desc, "train_id": train_id, "done": false}
	_next_job_id += 1
	shunt_jobs.append(job)
	EventBus.shunt_job_added.emit(job)


func _mark_job_done_for_train(train_id: int, type: String) -> void:
	for job in shunt_jobs:
		if job["train_id"] == train_id and job["type"] == type and not job["done"]:
			job["done"] = true
			EventBus.shunt_job_done.emit(job)
			return


## --- Aktualizacja online ---

func request_online_update(manual: bool) -> void:
	if not Settings.online_enabled and not manual:
		return
	if Settings.url_delays != "" and http_delays.get_http_client_status() == HTTPClient.STATUS_DISCONNECTED:
		http_delays.request(Settings.url_delays)
	if Settings.url_timetable != "" and GameState.mode == GameState.MODE_TIMETABLE \
			and http_tt.get_http_client_status() == HTTPClient.STATUS_DISCONNECTED:
		http_tt.request(Settings.url_timetable)
	if manual:
		show_message("Wysłano zapytanie o aktualizację rozkładu i opóźnień…")


func _on_delays_response(result: int, code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	if result != HTTPRequest.RESULT_SUCCESS or code != 200:
		tt.online_status = "brak połączenia — dane lokalne"
		return
	var n := tt.apply_online_delays(body.get_string_from_utf8())
	if n > 0:
		dlog.add(sim_time, "Ruch", "Aktualizacja online: nowe opóźnienia dla %d pociągów." % n)


func _on_tt_response(result: int, code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	if result != HTTPRequest.RESULT_SUCCESS or code != 200:
		return
	var n := tt.apply_online_timetable(body.get_string_from_utf8())
	if n > 0:
		dlog.add(sim_time, "Ruch", "Aktualizacja online: dodano %d pociągów do rozkazu jazdy." % n)


## --- Interfejs ---

func show_message(txt: String) -> void:
	msg_label.text = txt
	_msg_until = Time.get_ticks_msec() / 1000.0 + 10.0


func _toggle_pause() -> void:
	paused = not paused
	pause_btn.text = "▶" if paused else "⏸"


func _set_speed(v: float) -> void:
	time_scale = v
	for b in speed_btns:
		b.button_pressed = absf(b.get_meta("speed") - v) < 0.01


func _build_ui() -> void:
	ui_layer = CanvasLayer.new()
	add_child(ui_layer)

	# górny pasek
	var top := PanelContainer.new()
	top.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	var top_hb := HBoxContainer.new()
	top_hb.add_theme_constant_override("separation", 10)
	var back := Button.new()
	back.text = "◀ Menu"
	back.pressed.connect(func(): exit_dialog.popup_centered())
	top_hb.add_child(back)
	var title := Label.new()
	title.text = "LCS %s — %s" % [layout.station_name, GameState.mode_name()]
	title.add_theme_font_size_override("font_size", 16)
	top_hb.add_child(title)
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top_hb.add_child(spacer)
	clock_label = Label.new()
	clock_label.add_theme_font_size_override("font_size", 22)
	clock_label.add_theme_color_override("font_color", Color("2ee56b"))
	top_hb.add_child(clock_label)
	pause_btn = Button.new()
	pause_btn.text = "⏸"
	pause_btn.pressed.connect(_toggle_pause)
	top_hb.add_child(pause_btn)
	for sp in [1.0, 2.0, 5.0, 10.0]:
		var b := Button.new()
		b.text = "%dx" % int(sp)
		b.toggle_mode = true
		b.button_pressed = absf(sp - 1.0) < 0.01
		b.set_meta("speed", sp)
		b.pressed.connect(func(): _set_speed(sp))
		speed_btns.append(b)
		top_hb.add_child(b)
	var settings_btn := Button.new()
	settings_btn.text = "Ustawienia"
	settings_btn.pressed.connect(func(): settings_dialog.popup_centered())
	top_hb.add_child(settings_btn)
	var help_btn := Button.new()
	help_btn.text = "Pomoc (F1)"
	help_btn.pressed.connect(func(): help_dialog.popup_centered())
	top_hb.add_child(help_btn)
	top.add_child(top_hb)
	ui_layer.add_child(top)

	# panel boczny z zakładkami
	var dock := PanelContainer.new()
	dock.set_anchors_and_offsets_preset(Control.PRESET_RIGHT_WIDE)
	dock.offset_left = -430.0
	dock.offset_top = 44.0
	dock.offset_bottom = -64.0
	tabs = TabContainer.new()
	tt_panel = TimetablePanel.new()
	tt_panel.name = "Rozkład jazdy"
	tabs.add_child(tt_panel)
	log_panel = LogPanel.new()
	log_panel.name = "Dziennik"
	tabs.add_child(log_panel)
	events_panel = EventsPanel.new()
	events_panel.name = "Zdarzenia"
	tabs.add_child(events_panel)
	traffic_panel = TrafficPanel.new()
	traffic_panel.name = "Ruch"
	tabs.add_child(traffic_panel)
	tabs.tab_changed.connect(func(idx: int):
		EventBus.panel_changed.emit(tabs.get_tab_title(idx)))
	dock.add_child(tabs)
	ui_layer.add_child(dock)
	tt_panel.setup(self)
	log_panel.setup(self)
	events_panel.setup(self)
	traffic_panel.setup(self)

	# dolny pasek
	var bottom := PanelContainer.new()
	bottom.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	bottom.offset_top = -60.0
	var bot_vb := VBoxContainer.new()
	var bot_hb := HBoxContainer.new()
	bot_hb.add_theme_constant_override("separation", 10)
	shunt_check = CheckButton.new()
	shunt_check.text = "Tryb manewrowy (M)"
	shunt_check.toggled.connect(func(on: bool):
		shunt_mode = on
		show_message("Tryb manewrowy: %s — przebiegi będą ustawiane jako manewrowe (sygnał biały)." % ("WŁ." if on else "wył.")))
	bot_hb.add_child(shunt_check)
	sel_label = Label.new()
	sel_label.add_theme_font_size_override("font_size", 13)
	bot_hb.add_child(sel_label)
	sel_release_btn = Button.new()
	sel_release_btn.text = "Zwolnij przebieg"
	sel_release_btn.visible = false
	sel_release_btn.pressed.connect(release_selected_route)
	bot_hb.add_child(sel_release_btn)
	sel_sz_btn = Button.new()
	sel_sz_btn.text = "Sygnał zastępczy (Sz)"
	sel_sz_btn.visible = false
	sel_sz_btn.pressed.connect(give_sz_selected)
	bot_hb.add_child(sel_sz_btn)
	bot_vb.add_child(bot_hb)
	msg_label = Label.new()
	msg_label.add_theme_font_size_override("font_size", 13)
	msg_label.add_theme_color_override("font_color", Color("f0e6a8"))
	msg_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	bot_vb.add_child(msg_label)
	bottom.add_child(bot_vb)
	ui_layer.add_child(bottom)

	settings_dialog = SettingsDialog.new()
	ui_layer.add_child(settings_dialog)

	help_dialog = AcceptDialog.new()
	help_dialog.title = "Pomoc — obsługa pulpitu"
	help_dialog.dialog_text = """USTAWIANIE PRZEBIEGU
1. Kliknij semafor początkowy (np. wjazdowy „Ad” przy portalu).
2. Kliknij cel: semafor na końcu toru (wjazd) lub portal wyjazdowy (odjazd/przelot).
3. Droga przebiegu podświetli się na zielono (pociągowa) lub biało (manewrowa),
   a semafor poda sygnał zezwalający. Pociąg ruszy sam.

PRZEBIEGI MANEWROWE — włącz „Tryb manewrowy (M)”. Tarcze manewrowe (kwadratowe,
np. M10 przy Grochowie) obsługują wyłącznie jazdy manewrowe.

USTERKI — przy usterce semafora ustaw przebieg i podaj sygnał zastępczy (Sz).
Uszkodzony rozjazd (mrugająca obwódka) wyklucza przebiegi przez ten rozjazd —
prowadź ruch drogą okrężną. Zamknięty odcinek (pomarańczowy, przekreślony)
czeka na interwencję.

KLAWISZE: Spacja — pauza, 1/2/3/4 — tempo 1x/2x/5x/10x, M — tryb manewrowy,
F1 — pomoc, Esc — odznaczenie/wyjście. PPM lub środkowy przycisk — przesuwanie
pulpitu, rolka — zoom. Kliknięcie pociągu/portalu pokazuje informacje."""
	ui_layer.add_child(help_dialog)

	exit_dialog = ConfirmationDialog.new()
	exit_dialog.title = "Zakończenie dyżuru"
	exit_dialog.dialog_text = "Wrócić do menu głównego?\nDziennik ruchu zostanie zapisany."
	exit_dialog.confirmed.connect(func():
		if Settings.autosave_log:
			dlog.save_to_file()
		GameState.back_to_menu())
	ui_layer.add_child(exit_dialog)
