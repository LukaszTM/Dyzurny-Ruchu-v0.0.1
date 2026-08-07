class_name SimCore
extends Node
## Rdzeń symulacji — żyje poza drzewem scen interfejsu, dzięki czemu
## przełączanie ekranów (pulpit, rozkład, EDR, zdarzenia, łączność)
## nie przerywa prowadzenia ruchu.

const CMD_PP := "PP"
const CMD_PM := "PM"
const CMD_ZD := "ZD"
const CMD_ZDM := "ZDM"
const CMD_ZW := "ZW"
const CMD_ZWP := "ZWP"
const CMD_OPS := "OPS"

const CMD_LABELS := {
	CMD_PP: "PRZEBIEG POCIĄGOWY",
	CMD_PM: "PRZEBIEG MANEWROWY",
	CMD_ZD: "ZD",
	CMD_ZDM: "ZDM",
	CMD_ZW: "ZW",
	CMD_ZWP: "ZWP",
	CMD_OPS: "OPS",
}

const CMD_HELP := {
	CMD_PP: "Nastawianie przebiegu pociągowego: przycisk początku (semafor), potem przycisk końca (semafor lub szlak).",
	CMD_PM: "Nastawianie przebiegu manewrowego: przycisk początku, potem przycisk końca drogi przebiegu.",
	CMD_ZD: "Zwolnienie drogi przebiegu pociągowego — wskaż sygnalizator początku przebiegu.",
	CMD_ZDM: "Zwolnienie drogi przebiegu manewrowego — wskaż sygnalizator początku przebiegu.",
	CMD_ZW: "Indywidualne przestawienie rozjazdu — wskaż rozjazd (+ / −).",
	CMD_ZWP: "Zwolnienie awaryjne przebiegu z kontrolą czasu 180 s — wskaż sygnalizator.",
	CMD_OPS: "Opis elementu — wskaż dowolny element pulpitu.",
}

const SIGNAL_CMDS := ["STOP", "OSTOP", "SZ", "SZP", "NSZ", "NSZP", "WTAB", "KTAB"]

var layout: StationLayout
var inter: Interlocking
var tt: TimetableManager
var gen: TrafficGenerator
var events: RandomEventManager
var edr: EDR
var comms: Comms
var tutorial = null

## Stała częstotliwość zdarzeń losowych w trybie realnego rozkładu [min] —
## gracz nie ma na nią wpływu.
const REAL_EVENT_FREQ := 25.0

var mode := GameState.MODE_TIMETABLE
var location := {}
var sim_time := 0.0
var time_scale := 1.0
var paused := false
var real_mode := false     # tryb REALNY ROZKŁAD JAZDY: czas rzeczywisty
var sim_date := {}         # {year, month, day} — data w grze

var trains := {}
var next_train_id := 1
var queues := {}              # line_end -> [train_id]
var deferred: Array = []      # {spec, retry_at}
var stats := {
	"obsluzone": 0, "odjazdy": 0, "punktualne": 0,
	"sz": 0, "awaryjne": 0, "niezgloszone": 0,
}

# stan pulpitu
var cmd_mode := CMD_PP
var pending_start := ""       # id sygnalizatora początku przebiegu
var selected := {"kind": "", "id": ""}
var last_message := ""
var last_message_level := 0

var _http_delays: HTTPRequest
var _http_tt: HTTPRequest
var _online_timer := 0.0


func setup(p_mode: String, location_id: String) -> void:
	mode = p_mode
	location = Locations.get_location(location_id)
	if location.is_empty():
		push_error("Brak definicji lokalizacji.")
		return
	layout = StationLayout.new()
	layout.load_file("%s/%s" % [location["dir"], location.get("layout", "layout.json")])
	inter = Interlocking.new(layout)
	inter.message.connect(_on_inter_message)
	edr = EDR.new(layout.station_name)
	tt = TimetableManager.new(self)
	gen = TrafficGenerator.new(self)
	events = RandomEventManager.new(self)
	comms = Comms.new(self)
	comms.setup()
	for lid in layout.line_end_order:
		queues[lid] = []

	match mode:
		GameState.MODE_TIMETABLE:
			# REALNY ROZKŁAD JAZDY: start o rzeczywistej dacie i godzinie,
			# czas płynie jak w rzeczywistości, częstotliwość usterek stała.
			real_mode = true
			tt.load_file("%s/%s" % [location["dir"], location.get("timetable", "timetable.json")])
			var teraz := Time.get_datetime_dict_from_system()
			sim_date = {"year": teraz["year"], "month": teraz["month"], "day": teraz["day"]}
			sim_time = float(int(teraz["hour"]) * 3600 + int(teraz["minute"]) * 60 + int(teraz["second"]))
			tt.start_time = sim_time
			tt.skip_past(sim_time)
			time_scale = 1.0
			events.freq_min = REAL_EVENT_FREQ
		GameState.MODE_RANDOM:
			sim_time = SimUtil.parse_hhmm(str(location.get("start_time_random", "12:00")))
			gen.enabled = true
		GameState.MODE_TUTORIAL:
			sim_time = 8.0 * 3600.0
			events.freq_min = 0.0

	inter.sim_time = sim_time
	_http_delays = HTTPRequest.new()
	add_child(_http_delays)
	_http_delays.request_completed.connect(_on_delays_response)
	_http_tt = HTTPRequest.new()
	add_child(_http_tt)
	_http_tt.request_completed.connect(_on_tt_response)

	edr.add(sim_time, "Służba", "Objęcie dyżuru na posterunku %s. Tryb pracy: %s. Dyżurny ruchu: %s." % [
		layout.station_name, GameState.mode_name(), Settings.dyzurny_name])

	if mode == GameState.MODE_TIMETABLE and Settings.online_enabled:
		request_online_update(false)
	if mode == GameState.MODE_TUTORIAL:
		tutorial = TutorialManager.new(self)
		add_child(tutorial)
		tutorial.start()


func _process(delta: float) -> void:
	if paused or layout == null:
		return
	var dt := delta * time_scale
	sim_time += dt
	if sim_time >= 86400.0:
		sim_time -= 86400.0
		_next_day()
	inter.step(sim_time)
	tt.step(sim_time)
	gen.step(sim_time)
	events.step(sim_time)
	comms.step(sim_time)
	_step_deferred()
	_step_trains(dt)
	_rebuild_occupancy()
	_check_ready()
	if tutorial != null:
		tutorial.step(sim_time)
	if Settings.online_enabled and mode == GameState.MODE_TIMETABLE:
		_online_timer += delta
		if _online_timer > 120.0:
			_online_timer = 0.0
			request_online_update(false)


func _on_inter_message(text: String, level: int) -> void:
	show_message(text, level)


func show_message(text: String, level := 0) -> void:
	last_message = text
	last_message_level = level
	EventBus.message.emit(text, level)


# ---------------------------------------------------------------- pociągi --

func request_train(spec: Dictionary) -> void:
	if not queues.has(str(spec["we"])):
		push_warning("Nieznany szlak wjazdowy: %s" % str(spec["we"]))
		return
	comms.incoming_permission_request(spec)


func defer_train(spec: Dictionary) -> void:
	deferred.append({"spec": spec, "retry_at": sim_time + 180.0})


func _step_deferred() -> void:
	var still: Array = []
	for d in deferred:
		if sim_time >= float(d["retry_at"]):
			comms.incoming_permission_request(d["spec"])
		else:
			still.append(d)
	deferred = still


func admit_train(spec: Dictionary) -> Train:
	var t := Train.new()
	t.id = next_train_id
	next_train_id += 1
	t.nr = str(spec["nr"])
	t.rodzaj = str(spec["kat"])
	t.nazwa = str(spec.get("nazwa", ""))
	t.st_poczatkowa = str(spec["z"])
	t.st_koncowa = str(spec["do"])
	t.wjazd = str(spec["we"])
	t.wyjazd = str(spec["wy"])
	t.tor_zadany = str(spec.get("tor", ""))
	t.sched_arr = float(spec.get("arr", -1.0))
	t.sched_dep = float(spec.get("dep", -1.0))
	t.postoj = float(spec.get("postoj", 0.0))
	t.delay_min = int(spec.get("delay", 0))
	t.flag_przelot = bool(spec.get("przelot", false))
	t.flag_koniec = bool(spec.get("koniec", false))
	t.flag_podstawienie = bool(spec.get("podstawienie", false))
	t.manewrowy = bool(spec.get("man", false))
	t.tt_index = int(spec.get("tt_index", -1))
	t.dlugosc = Train.length_for(t.rodzaj)
	t.spawned_at = sim_time
	trains[t.id] = t
	queues[t.wjazd].append(t.id)
	if t.tt_index >= 0:
		var e: Dictionary = tt.entries[t.tt_index]
		if t.manewrowy:
			e["stock_id"] = t.id
		else:
			e["train_id"] = t.id
	elif not t.manewrowy:
		t.tt_index = tt.add_generated(spec, t.id)
	var le: Dictionary = layout.line_ends[t.wjazd]
	if t.manewrowy:
		edr.add(sim_time, "Manewry", "Skład manewrowy %s oczekuje na podstawienie z %s na tor %s." % [
			t.nr, str(le["name"]), t.tor_zadany], t.nr, t.tor_zadany)
	else:
		comms.incoming_departure(spec)
		edr.add(sim_time, "Ruch", "Zapowiedziano poc. %s rel. %s od strony %s, tor żądany %s%s." % [
			t.opis(), t.relacja(), str(le["name"]), t.tor_zadany, SimUtil.fmt_delay(t.delay_min)],
			t.nr, t.tor_zadany)
	EventBus.train_spawned.emit(t)
	_assign_waiting_routes(t.wjazd)
	return t


func _assign_waiting_routes(line_end_id: String) -> void:
	var sig := layout.signal_at(line_end_id, int(layout.line_ends[line_end_id]["dir_in"]))
	if sig == "":
		# semafor wjazdowy stoi na kolejnym punkcie za szlakiem
		for sid in layout.signals:
			var sg: Dictionary = layout.signals[sid]
			if int(sg["dir"]) != int(layout.line_ends[line_end_id]["dir_in"]):
				continue
			if str(sg["typ"]) not in ["wjazdowy", "manewrowy"]:
				continue
			if _line_end_of_signal(sid) == line_end_id:
				sig = sid
				break
	if sig == "":
		return
	var r := inter.route_of_signal(sig)
	if not r.is_empty() and int(r["train_id"]) == 0:
		_assign_route(r)


## Szlak, z którego pociąg dojeżdża do danego semafora wjazdowego.
func _line_end_of_signal(sig_id: String) -> String:
	var sg: Dictionary = layout.signals[sig_id]
	var adj: Dictionary = layout.adj_w if int(sg["dir"]) > 0 else layout.adj_e
	for edge in adj.get(str(sg["point"]), []):
		if layout.is_line_end(str(edge["to"])):
			return str(edge["to"])
	return ""


func _step_trains(dt: float) -> void:
	var gone: Array = []
	for t: Train in trains.values():
		match t.step(dt, sim_time, inter):
			"przyjazd":
				_on_arrival(t)
			"koniec":
				gone.append(t)
	for t in gone:
		_on_departed_station(t)


func _rebuild_occupancy() -> void:
	inter.occupied_segs.clear()
	for t: Train in trains.values():
		if t.state == Train.State.OCZEKUJE or t.state == Train.State.ZAKONCZONY:
			continue
		for sid in t.covered:
			inter.occupied_segs[sid] = t.id


func _check_ready() -> void:
	for t: Train in trains.values():
		if t.state != Train.State.NA_TORZE:
			continue
		if t.flag_podstawienie and t.tt_index >= 0 and not bool(tt.entries[t.tt_index].get("converted", false)):
			continue
		var gotowy_o: float
		if t.flag_koniec or t.manewrowy:
			gotowy_o = t.actual_arr + 180.0
		elif t.sched_dep >= 0.0:
			gotowy_o = maxf(t.sched_dep + t.delay_min * 60.0, t.actual_arr + t.min_postoj())
		else:
			gotowy_o = t.actual_arr + t.min_postoj()
		if sim_time >= gotowy_o - 20.0:
			t.state = Train.State.GOTOWY
			if t.flag_koniec or t.manewrowy:
				edr.add(sim_time, "Manewry", "Skład %s na torze %s gotowy do odstawienia do Grochowa." % [
					t.nr, t.tor], t.nr, t.tor)
			else:
				edr.add(sim_time, "Ruch", "Poc. %s gotowy do odjazdu z toru %s w kierunku: %s." % [
					t.opis(), t.tor, t.st_koncowa], t.nr, t.tor)
			EventBus.train_ready.emit(t)


func _on_arrival(t: Train) -> void:
	t.actual_arr = sim_time
	t.tor = layout.track_with_end(str(t.route["dest_pt"]))
	inter.finish_route(t.route)
	var op := 0
	if t.sched_arr >= 0.0:
		op = int(maxf(0.0, (sim_time - t.sched_arr) / 60.0))
	if t.manewrowy:
		edr.add(sim_time, "Manewry", "Skład %s podstawiony na tor %s." % [t.nr, t.tor], t.nr, t.tor)
	else:
		edr.add(sim_time, "Ruch", "Wjazd poc. %s na tor %s%s." % [
			t.opis(), t.tor, SimUtil.fmt_delay(op)], t.nr, t.tor)
	if t.tt_index >= 0:
		tt.entries[t.tt_index]["actual_arr"] = sim_time
		tt.set_status(t.tt_index, "na torze %s%s" % [t.tor, SimUtil.fmt_delay(op)])
	EventBus.train_arrived.emit(t)


func _on_departed_station(t: Train) -> void:
	trains.erase(t.id)
	stats["obsluzone"] += 1
	if t.manewrowy or t.wyjazd == "itG":
		edr.add(sim_time, "Manewry", "Skład %s odstawiony do Grochowa." % t.nr, t.nr)
	else:
		edr.add(sim_time, "Ruch", "Poc. %s opuścił posterunek w kierunku: %s." % [
			t.opis(), t.st_koncowa], t.nr)
	if t.tt_index >= 0 and t.actual_dep >= 0.0:
		tt.entries[t.tt_index]["actual_dep"] = t.actual_dep
	EventBus.train_removed.emit(t)


# ------------------------------------------------------------ obsługa pulpitu

func set_cmd_mode(m: String) -> void:
	cmd_mode = m
	pending_start = ""
	show_message("%s — %s" % [str(CMD_LABELS.get(m, m)), str(CMD_HELP.get(m, ""))])
	EventBus.panel_state_changed.emit()


func click_element(kind: String, id: String) -> void:
	selected = {"kind": kind, "id": id}
	EventBus.element_selected.emit(kind, id)
	match cmd_mode:
		CMD_PP, CMD_PM:
			_click_route(kind, id)
		CMD_ZD, CMD_ZDM:
			if kind != "signal":
				show_message("Polecenie %s wykonuje się na sygnalizatorze początku przebiegu." % cmd_mode, 1)
				return
			var err := inter.cmd_release(id, "P" if cmd_mode == CMD_ZD else "M")
			if err != "":
				show_message("✗ " + err, 2)
			else:
				edr.add(sim_time, "Przebieg", "Zwolniono drogę przebiegu spod sygnalizatora %s (%s)." % [id, cmd_mode])
				show_message("✓ Zwolniono drogę przebiegu spod %s." % id)
		CMD_ZW:
			if kind != "switch":
				show_message("Polecenie ZW wykonuje się na rozjeździe.", 1)
				return
			var err2 := inter.cmd_switch(id)
			if err2 != "":
				show_message("✗ " + err2, 2)
			else:
				edr.add(sim_time, "Przebieg", "Indywidualne przestawienie rozjazdu nr %s w położenie %s." % [
					id, str(inter.sw_pos.get(id, "+"))])
				show_message("Rozjazd nr %s — przestawianie w położenie %s." % [id, str(inter.sw_pos.get(id, "+"))])
		CMD_ZWP:
			if kind != "signal":
				show_message("Polecenie ZWP wykonuje się na sygnalizatorze początku przebiegu.", 1)
				return
			var err3 := inter.cmd_emergency_release(id)
			if err3 != "":
				show_message("✗ " + err3, 2)
			else:
				stats["awaryjne"] += 1
				edr.add(sim_time, "Przebieg",
					"Rozpoczęto zwolnienie awaryjne przebiegu spod %s (kontrola czasu %d s)." % [
						id, int(Interlocking.EMERGENCY_DELAY)])
				show_message("Zwolnienie awaryjne przebiegu spod %s — kontrola czasu %d s." % [
					id, int(Interlocking.EMERGENCY_DELAY)], 1)
		CMD_OPS:
			var opis := inter.element_description(kind, id)
			if kind == "train":
				var t: Train = trains.get(int(id))
				if t != null:
					opis = "%s rel. %s\nStan: %s%s" % [t.opis(), t.relacja(), t.state_text(),
						("\nOdjazd planowy %s" % SimUtil.fmt_hm(t.sched_dep)) if t.sched_dep >= 0 else ""]
			show_message(opis if opis != "" else "Brak opisu elementu.")


func _click_route(kind: String, id: String) -> void:
	var kind_code := "P" if cmd_mode == CMD_PP else "M"
	if pending_start == "":
		if kind != "signal":
			show_message("Wskaż przycisk POCZĄTKU drogi przebiegu (sygnalizator).", 1)
			return
		pending_start = id
		show_message("Początek drogi przebiegu: %s. Wskaż przycisk KOŃCA (sygnalizator albo szlak)." % id)
		EventBus.panel_state_changed.emit()
		return
	if kind == "signal" and id == pending_start:
		pending_start = ""
		show_message("Anulowano wybór początku drogi przebiegu.")
		EventBus.panel_state_changed.emit()
		return
	if kind != "signal" and kind != "line_end":
		show_message("Końcem drogi przebiegu może być sygnalizator albo przycisk szlaku.", 1)
		return
	var start := pending_start
	pending_start = ""
	EventBus.panel_state_changed.emit()
	_try_route(start, id, kind, kind_code)


func _try_route(sig_id: String, dest_id: String, dest_kind: String, kind_code: String) -> void:
	# kontrola zapowiadania przy wyprawianiu pociągu na szlak
	if dest_kind == "line_end" and kind_code == "P" and Settings.require_zapowiadanie:
		var le: Dictionary = layout.line_ends[dest_id]
		if str(le["kind"]) != "manewrowy":
			var t := train_for_signal(sig_id)
			if t != null and not t.manewrowy:
				if comms.permission_status(t.id) != "udzielone":
					show_message("✗ Brak pozwolenia na wyprawienie poc. %s w kierunku %s — zażądaj pozwolenia w łączności." % [
						t.nr, str(le["name"])], 2)
					return
	var result := inter.set_route(sig_id, dest_id, dest_kind, kind_code)
	if result.has("error"):
		show_message("✗ " + str(result["error"]), 2)
		return
	var opis := "pociągowy" if kind_code == "P" else "manewrowy"
	edr.add(sim_time, "Przebieg", "Nastawiono przebieg %s: %s → %s (rozjazdy: %s)." % [
		opis, sig_id, dest_id, _sw_text(result["sw"])])
	show_message("Przebieg %s %s → %s: nastawianie rozjazdów…" % [opis, sig_id, dest_id])
	EventBus.route_requested.emit(result)
	_assign_route(result)


func _sw_text(sw: Dictionary) -> String:
	if sw.is_empty():
		return "brak"
	var parts: Array = []
	for wid in sw:
		parts.append("%s%s" % [wid, str(sw[wid])])
	parts.sort()
	return ", ".join(parts)


## Pociąg, który skorzysta z przebiegu spod danego sygnalizatora.
func train_for_signal(sig_id: String) -> Train:
	if not layout.signals.has(sig_id):
		return null
	var pt: String = str(layout.signals[sig_id]["point"])
	var le := _line_end_of_signal(sig_id)
	if le != "" and not queues[le].is_empty():
		var t: Train = trains.get(int(queues[le][0]))
		if t != null and t.state == Train.State.OCZEKUJE:
			return t
	var tor := layout.track_with_end(pt)
	if tor != "":
		for t2: Train in trains.values():
			if t2.tor == tor and (t2.state == Train.State.NA_TORZE or t2.state == Train.State.GOTOWY):
				return t2
	return null


func _assign_route(route: Dictionary) -> void:
	if int(route["train_id"]) != 0:
		return
	var start_pt: String = str(route["start_pt"])
	var le := _line_end_of_signal(str(route["signal_id"]))
	if le != "" and not queues[le].is_empty():
		var tid: int = int(queues[le][0])
		var t: Train = trains.get(tid)
		if t != null and t.state == Train.State.OCZEKUJE:
			queues[le].pop_front()
			t.begin_route(route, layout, 0.0)
			if t.tt_index >= 0:
				tt.set_status(t.tt_index, "wjazd na stację")
			return
	var tor := layout.track_with_end(start_pt)
	if tor == "":
		return
	for t2: Train in trains.values():
		if t2.tor != tor:
			continue
		if t2.state != Train.State.NA_TORZE and t2.state != Train.State.GOTOWY:
			continue
		var przed_czasem: bool = t2.state == Train.State.NA_TORZE and t2.sched_dep >= 0.0 \
			and sim_time < t2.sched_dep - 60.0 and not t2.manewrowy
		t2.begin_route(route, layout, t2.dlugosc)
		t2.actual_dep = sim_time
		var op := 0
		if t2.sched_dep >= 0.0:
			op = int(maxf(0.0, (sim_time - (t2.sched_dep + t2.delay_min * 60.0)) / 60.0))
		if not t2.manewrowy:
			stats["odjazdy"] += 1
			if op <= 5:
				stats["punktualne"] += 1
			edr.add(sim_time, "Ruch", "Odjazd poc. %s z toru %s%s." % [
				t2.opis(), t2.tor, SimUtil.fmt_delay(op)], t2.nr, t2.tor)
			if przed_czasem:
				edr.add(sim_time, "Ruch", "UWAGA: poc. %s wyprawiony przed rozkładową godziną odjazdu." % t2.nr, t2.nr)
			if t2.tt_index >= 0:
				tt.set_status(t2.tt_index, "odjechał%s" % SimUtil.fmt_delay(op))
		else:
			edr.add(sim_time, "Manewry", "Jazda manewrowa składu %s z toru %s." % [t2.nr, t2.tor], t2.nr, t2.tor)
		EventBus.train_departed.emit(t2)
		return


# ------------------------------------------------------- menu sygnalizatora

func signal_menu_enabled(sig_id: String) -> Dictionary:
	var st: Dictionary = inter.sig_state.get(sig_id, {})
	var r := inter.route_of_signal(sig_id)
	var utw: bool = not r.is_empty() and str(r["state"]) == Interlocking.ST_UTWIERDZONY
	return {
		"STOP": not bool(st.get("stop_cmd", false)),
		"OSTOP": bool(st.get("stop_cmd", false)),
		"SZ": utw and inter.aspect(sig_id) == Interlocking.ASPECT_STOP,
		"SZP": utw and inter.aspect(sig_id) == Interlocking.ASPECT_STOP,
		"NSZ": str(st.get("sz", "")) == "SZ",
		"NSZP": str(st.get("sz", "")) == "SZP",
		"WTAB": not inter.tab.has(sig_id),
		"KTAB": inter.tab.has(sig_id),
	}


func exec_signal_cmd(sig_id: String, cmd: String) -> void:
	var err := inter.cmd_signal(sig_id, cmd)
	if err != "":
		show_message("✗ " + err, 2)
		return
	match cmd:
		"SZ", "SZP":
			stats["sz"] += 1
			edr.add(sim_time, "Przebieg", "Podano sygnał zastępczy (%s) na sygnalizatorze %s." % [cmd, sig_id])
			show_message("Sygnał zastępczy (%s) na %s — jazda z prędkością ograniczoną." % [cmd, sig_id], 1)
		"STOP":
			edr.add(sim_time, "Przebieg", "Nakaz sygnału „Stój” na sygnalizatorze %s." % sig_id)
			show_message("Nakaz STOP na %s." % sig_id, 1)
		"OSTOP":
			edr.add(sim_time, "Przebieg", "Odwołano nakaz „Stój” na sygnalizatorze %s." % sig_id)
			show_message("Odwołano nakaz STOP na %s." % sig_id)
		"WTAB":
			edr.add(sim_time, "Służba", "Założono tabliczkę ostrzegawczą na sygnalizatorze %s." % sig_id)
			show_message("Założono tabliczkę na %s." % sig_id, 1)
		"KTAB":
			edr.add(sim_time, "Służba", "Skasowano tabliczkę ostrzegawczą na sygnalizatorze %s." % sig_id)
			show_message("Skasowano tabliczkę na %s." % sig_id)
		_:
			show_message("Wykonano polecenie %s na %s." % [cmd, sig_id])
	EventBus.signal_command.emit(sig_id, cmd)
	EventBus.panel_state_changed.emit()


# ----------------------------------------------------------------- online --

func request_online_update(manual: bool) -> void:
	if not Settings.online_enabled and not manual:
		return
	if Settings.url_delays != "" and _http_delays.get_http_client_status() == HTTPClient.STATUS_DISCONNECTED:
		_http_delays.request(Settings.url_delays)
	if Settings.url_timetable != "" and mode == GameState.MODE_TIMETABLE \
			and _http_tt.get_http_client_status() == HTTPClient.STATUS_DISCONNECTED:
		_http_tt.request(Settings.url_timetable)
	if manual:
		show_message("Wysłano zapytanie o aktualizację rozkładu jazdy i opóźnień…")


func _on_delays_response(result: int, code: int, _h: PackedStringArray, body: PackedByteArray) -> void:
	if result != HTTPRequest.RESULT_SUCCESS or code != 200:
		tt.online_status = "brak połączenia — obowiązuje rozkład lokalny"
		return
	var n := tt.apply_online_delays(body.get_string_from_utf8())
	if n > 0:
		edr.add(sim_time, "Służba", "Aktualizacja online: nowe opóźnienia dla %d pociągów." % n)


func _on_tt_response(result: int, code: int, _h: PackedStringArray, body: PackedByteArray) -> void:
	if result != HTTPRequest.RESULT_SUCCESS or code != 200:
		return
	var n := tt.apply_online_timetable(body.get_string_from_utf8())
	if n > 0:
		edr.add(sim_time, "Służba", "Aktualizacja online: do rozkładu dodano %d pociągów." % n)


# ------------------------------------------------------------- statystyki --

func punctuality() -> float:
	if int(stats["odjazdy"]) <= 0:
		return 100.0
	return 100.0 * float(stats["punktualne"]) / float(stats["odjazdy"])


func toggle_pause() -> void:
	paused = not paused
	EventBus.panel_state_changed.emit()


func set_speed(v: float) -> void:
	if real_mode:
		show_message("W trybie REALNY ROZKŁAD JAZDY czas płynie jak w rzeczywistości — nie można go przyspieszyć.", 1)
		return
	time_scale = v
	EventBus.panel_state_changed.emit()


## Data w grze jako tekst (dd.mm.rrrr).
func date_str() -> String:
	if sim_date.is_empty():
		return ""
	return "%02d.%02d.%04d" % [int(sim_date["day"]), int(sim_date["month"]), int(sim_date["year"])]


## Przejście przez północ: nowa doba, rozkład dobowy zaczyna się od nowa.
func _next_day() -> void:
	if sim_date.is_empty():
		return
	var d := int(sim_date["day"]) + 1
	var m := int(sim_date["month"])
	var y := int(sim_date["year"])
	var dni := 31
	match m:
		4, 6, 9, 11:
			dni = 30
		2:
			dni = 29 if (y % 4 == 0 and (y % 100 != 0 or y % 400 == 0)) else 28
	if d > dni:
		d = 1
		m += 1
		if m > 12:
			m = 1
			y += 1
	sim_date = {"year": y, "month": m, "day": d}
	tt.reset_for_new_day()
	tt.skip_past(sim_time)
	edr.add(sim_time, "Służba", "Nowa doba %s — rozkład jazdy obowiązuje od początku." % date_str())
