class_name TutorialManager
extends RefCounted
## Tryb nauki: prowadzi początkującego dyżurnego krok po kroku przez
## obsługę wszystkich urządzeń — przyjęcie i odprawienie pociągu,
## dziennik, sygnał zastępczy przy usterce, jazdy manewrowe.
## Kroki „action” zaliczają się po wykonaniu czynności na pulpicie.

var sim = null
var steps: Array = []
var idx := -1
var overlay: PanelContainer
var step_label: Label
var text_label: Label
var next_btn: Button


func _init(p_sim) -> void:
	sim = p_sim
	_build_steps()
	_build_overlay()
	EventBus.signal_selected.connect(_on_signal_selected)
	EventBus.route_set.connect(_on_route_set)
	EventBus.train_arrived.connect(func(_t): _check("train_arrived", ""))
	EventBus.train_departed.connect(func(_t): _check("train_departed", ""))
	EventBus.panel_changed.connect(func(n): _check("panel", n))
	EventBus.log_added.connect(_on_log_added)
	EventBus.sz_used.connect(func(sig): _check("sz", sig))


func start() -> void:
	idx = -1
	_advance()


func _build_steps() -> void:
	steps = [
		{
			"text": "Witaj w trybie nauki! Zostaniesz dyżurnym ruchu Lokalnego Centrum Sterowania %s.\n\nTwoim zadaniem jest bezpieczne prowadzenie ruchu pociągów: ustawianie przebiegów, obsługa usterek i dokumentowanie pracy w dzienniku ruchu.\n\nKliknij „Dalej”." % sim.layout.station_name,
			"cond": "next",
		},
		{
			"text": "PULPIT NASTAWCZY: linie to tory (szary = wolny, zielony = ustawiony przebieg pociągowy, biały = manewrowy, czerwony = zajęty). Kółka to semafory, kwadraty to tarcze manewrowe, prostokąty ze strzałką to kierunki (portale), z których zgłaszają się pociągi.\n\nPulpit przesuwasz prawym/środkowym przyciskiem myszy, przybliżasz rolką.\n\nKliknij „Dalej”.",
			"cond": "next",
		},
		{
			"text": "Za chwilę od strony W-wy Centralnej (portal WD1, lewy dolny) zgłosi się pociąg IC 5100 „Podlasiak”. Przyjmiesz go na tor 5.\n\nKliknij „Dalej”, aby odebrać zgłoszenie.",
			"cond": "next",
			"on_exit": "spawn_ic",
		},
		{
			"text": "Pociąg czeka przed semaforem wjazdowym. KROK 1: kliknij semafor wjazdowy „Ad” (przy portalu WD1, linia dalekobieżna po lewej).",
			"cond": "signal_selected:Ad",
		},
		{
			"text": "KROK 2: wskaż koniec przebiegu — kliknij semafor „H5” na końcu toru 5 (przy peronie 3, po prawej stronie).\n\nJeżeli droga jest wolna, przebieg podświetli się na zielono, semafor Ad poda sygnał zezwalający i pociąg ruszy.",
			"cond": "route_set:Ad",
		},
		{
			"text": "Doskonale! Obserwuj wjazd pociągu — zajęte odcinki świecą na czerwono, a przebieg zwalnia się sekcyjnie za pociągiem.\n\nPoczekaj, aż pociąg zatrzyma się przy peronie.",
			"cond": "train_arrived",
		},
		{
			"text": "Każde zdarzenie jest odnotowywane w DZIENNIKU RUCHU.\n\nOtwórz zakładkę „Dziennik” w panelu po prawej stronie.",
			"cond": "panel:Dziennik",
		},
		{
			"text": "Dodaj własny wpis do dziennika — wpisz w polu na dole zakładki np. „Objąłem dyżur” i zatwierdź.",
			"cond": "log_manual",
		},
		{
			"text": "Pociąg zgłosił gotowość do odjazdu (mrugający napis GOTÓW).\n\nUstaw przebieg wyjazdowy: kliknij semafor „H5” (koniec toru 5), a następnie portal wyjazdowy „Rembertów / Białystok” (ED1, po prawej). Pociąg odjedzie ze stacji.",
			"cond": "train_departed",
			"on_enter": "force_ready",
		},
		{
			"text": "ZDARZENIE LOSOWE: usterka semafora wjazdowego „Ad”! Właśnie zgłasza się TLK 21102.\n\nUstaw przebieg z „Ad” na tor 6 (semafor „H6”). Semafor nie poda sygnału — wybierz ponownie „Ad” i użyj przycisku „Sygnał zastępczy (Sz)” na dolnym pasku. Pociąg pojedzie z prędkością ograniczoną.",
			"cond": "sz:Ad",
			"on_enter": "fail_and_spawn",
		},
		{
			"text": "JAZDY MANEWROWE: z zaplecza Grochów (prawy dolny róg) trzeba podstawić skład na tor 8.\n\nWłącz „Tryb manewrowy (M)” na dolnym pasku, kliknij tarczę manewrową „M10” przy Grochowie, a następnie semafor „K8” (początek toru 8). Skład przejedzie jako jazda manewrowa (przebieg biały).",
			"cond": "route_shunt:M10",
			"on_enter": "spawn_stock",
		},
		{
			"text": "To wszystkie podstawowe czynności! Zajrzyj jeszcze do zakładek: „Rozkład jazdy” (planowe godziny i opóźnienia), „Zdarzenia” (częstotliwość zdarzeń losowych) oraz „Ruch” (natężenie ruchu, manewry, statystyki).\n\nSamouczek zakończony — możesz dalej ćwiczyć w tym trybie. Powodzenia na dyżurze!",
			"cond": "next",
		},
	]


func _build_overlay() -> void:
	overlay = PanelContainer.new()
	overlay.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	overlay.offset_top = -190.0
	overlay.offset_bottom = -64.0
	overlay.offset_left = 240.0
	overlay.offset_right = -680.0
	var vb := VBoxContainer.new()
	step_label = Label.new()
	step_label.add_theme_font_size_override("font_size", 13)
	step_label.add_theme_color_override("font_color", Color("22d3ee"))
	vb.add_child(step_label)
	text_label = Label.new()
	text_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	text_label.add_theme_font_size_override("font_size", 14)
	text_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vb.add_child(text_label)
	var hb := HBoxContainer.new()
	next_btn = Button.new()
	next_btn.text = "Dalej ▶"
	next_btn.pressed.connect(_on_next)
	hb.add_child(next_btn)
	var skip := Button.new()
	skip.text = "Zakończ samouczek"
	skip.pressed.connect(_finish)
	hb.add_child(skip)
	vb.add_child(hb)
	overlay.add_child(vb)
	sim.ui_layer.add_child(overlay)


func _current() -> Dictionary:
	if idx >= 0 and idx < steps.size():
		return steps[idx]
	return {}


func _advance() -> void:
	var cur := _current()
	if not cur.is_empty() and cur.has("on_exit"):
		_run_action(str(cur["on_exit"]))
	idx += 1
	if idx >= steps.size():
		_finish()
		return
	var st: Dictionary = steps[idx]
	step_label.text = "SAMOUCZEK — krok %d/%d" % [idx + 1, steps.size()]
	text_label.text = str(st["text"])
	next_btn.visible = str(st["cond"]) == "next"
	if st.has("on_enter"):
		_run_action(str(st["on_enter"]))


func _on_next() -> void:
	if str(_current().get("cond", "")) == "next":
		_advance()


func _run_action(action: String) -> void:
	match action:
		"spawn_ic":
			sim.spawn_from_spec({
				"nr": "5100", "kat": "IC", "nazwa": "Podlasiak",
				"z": "W-wa Zachodnia", "do": "Białystok",
				"we": "WD1", "wy": "ED1", "tor": "5",
				"arr_sec": sim.sim_time + 30.0, "dep_sec": -1.0,
				"przelot": false, "koniec": false, "man": false,
				"tt_index": -1, "delay_min": 0,
			})
		"force_ready":
			for t in sim.trains.values():
				if t.state == Train.State.AT_PLATFORM:
					t.state = Train.State.READY
					EventBus.train_ready.emit(t)
					sim.dlog.add(sim.sim_time, "Ruch", "Poc. %s gotowy do odjazdu z toru %s." % [t.title(), t.track_nr])
		"fail_and_spawn":
			sim.events.force_event(sim.sim_time, "semafor", "Ad")
			sim.spawn_from_spec({
				"nr": "21102", "kat": "TLK", "nazwa": "",
				"z": "W-wa Zachodnia", "do": "Terespol",
				"we": "WD1", "wy": "ED1", "tor": "6",
				"arr_sec": sim.sim_time + 30.0, "dep_sec": -1.0,
				"przelot": false, "koniec": false, "man": false,
				"tt_index": -1, "delay_min": 0,
			})
		"spawn_stock":
			sim.spawn_from_spec({
				"nr": "M401", "kat": "MAN", "nazwa": "",
				"z": "Grochów", "do": "tor 8",
				"we": "GR", "wy": "GR", "tor": "8",
				"arr_sec": sim.sim_time, "dep_sec": -1.0,
				"przelot": false, "koniec": false, "man": true,
				"tt_index": -1, "delay_min": 0,
			})


func _on_log_added(e: Dictionary) -> void:
	if str(e["cat"]) == "Dyżurny":
		_check("log_manual", "")


func _on_signal_selected(sig_id: String) -> void:
	_check("signal_selected", sig_id)


func _on_route_set(route: Dictionary) -> void:
	if route["kind"] == "shunt":
		_check("route_shunt", str(route["signal_id"]))
	_check("route_set", str(route["signal_id"]))


func _check(kind: String, arg: String) -> void:
	var st := _current()
	if st.is_empty():
		return
	var cond := str(st["cond"])
	var want := cond
	var want_arg := ""
	if ":" in cond:
		var parts := cond.split(":")
		want = parts[0]
		want_arg = parts[1]
	if want != kind:
		return
	if want_arg != "" and want_arg != arg:
		return
	_advance()


func _finish() -> void:
	if is_instance_valid(overlay):
		overlay.queue_free()
	idx = steps.size()
	EventBus.tutorial_finished.emit()
	sim.show_message("Samouczek zakończony — tryb wolnej praktyki. Miłego dyżuru!")
