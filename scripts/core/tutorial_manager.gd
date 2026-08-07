class_name TutorialManager
extends Node
## Tryb nauki — prowadzi początkującego dyżurnego krok po kroku przez obsługę
## wszystkich urządzeń: zapowiadanie telefoniczne, nastawianie przebiegów,
## EDR, sygnał zastępczy przy usterce, zgłaszanie usterek, jazdy manewrowe.
## Warunki zaliczenia kroku sprawdzane są na bieżąco na stanie symulacji.

var sim = null
var steps: Array = []
var idx := -1
var done := false


func _init(p_sim) -> void:
	sim = p_sim
	_build()


func start() -> void:
	idx = 0
	_enter()


func current() -> Dictionary:
	if done or idx < 0 or idx >= steps.size():
		return {}
	return steps[idx]


func header() -> String:
	if done:
		return "SAMOUCZEK ZAKOŃCZONY"
	return "SAMOUCZEK — krok %d/%d" % [idx + 1, steps.size()]


func text() -> String:
	var st := current()
	return str(st.get("tekst", ""))


func manual_next_allowed() -> bool:
	return str(current().get("cond", "")) == "next"


func next_step() -> void:
	if manual_next_allowed():
		_advance()


func skip() -> void:
	done = true
	EventBus.tutorial_finished.emit()
	sim.show_message("Samouczek zakończony — tryb wolnej praktyki.")


func step(_now: float) -> void:
	if done:
		return
	var st := current()
	if st.is_empty():
		return
	var c: Variant = st.get("check", null)
	if c is Callable and (c as Callable).call():
		_advance()


func _advance() -> void:
	var st := current()
	var on_exit: Variant = st.get("on_exit", null)
	if on_exit is Callable:
		(on_exit as Callable).call()
	idx += 1
	if idx >= steps.size():
		done = true
		EventBus.tutorial_finished.emit()
		sim.show_message("Samouczek zakończony — możesz dalej ćwiczyć w tym trybie.")
		return
	_enter()


func _enter() -> void:
	var st := current()
	var on_enter: Variant = st.get("on_enter", null)
	if on_enter is Callable:
		(on_enter as Callable).call()
	EventBus.tutorial_step.emit(idx)


# ------------------------------------------------------------------- kroki --

func _pociag(nr: String) -> Train:
	for t: Train in sim.trains.values():
		if t.nr == nr:
			return t
	return null


func _spawn(nr: String, kat: String, nazwa: String, z: String, dokad: String,
		we: String, wy: String, tor: String, man := false) -> void:
	sim.admit_train({
		"nr": nr, "kat": kat, "nazwa": nazwa, "z": z, "do": dokad,
		"we": we, "wy": wy, "tor": tor,
		"arr": sim.sim_time, "dep": sim.sim_time + 240.0, "postoj": 180.0,
		"przelot": false, "koniec": false, "man": man,
		"tt_index": -1, "delay": 0, "podstawienie": man,
	})


func _build() -> void:
	steps = [
		{
			"tekst": "Witaj w trybie nauki. Obejmujesz dyżur na posterunku %s.\n\nZadaniem dyżurnego ruchu jest bezpieczne prowadzenie ruchu pociągów: zapowiadanie ich sąsiednim posterunkom, nastawianie przebiegów, obsługa usterek i dokumentowanie pracy w Elektronicznym Dzienniku Ruchu (EDR)." % sim.layout.station_name,
			"cond": "next",
		},
		{
			"tekst": "PULPIT NASTAWCZY. Szare linie to tory, białe — droga przebiegu utwierdzona, czerwone — zajętość toru. Trójkąty to sygnalizatory (semafory i tarcze manewrowe), liczby przy rozjazdach to ich numery, a znak + lub − pokazuje położenie rozjazdu. Prostokąty na krańcach to przyciski szlaków.\n\nPulpit przesuwasz prawym przyciskiem myszy, przybliżasz rolką. Prawy klik na sygnalizatorze otwiera jego menu poleceń.",
			"cond": "next",
		},
		{
			"tekst": "ZAPOWIADANIE. Zanim pociąg wjedzie na stację, sąsiedni posterunek żąda pozwolenia. Za chwilę zgłosi się posterunek W-wa Centralna z pociągiem MPE 21102.\n\nOtwórz ekran ŁĄCZNOŚĆ (przycisk na górnej belce) i udziel pozwolenia przyciskiem „Droga wolna”.",
			"on_enter": func(): sim.comms.incoming_permission_request({
				"nr": "21102", "kat": "MPE", "nazwa": "", "z": "W-wa Zachodnia", "do": "Terespol",
				"we": "it1D", "wy": "it1R", "tor": "5",
				"arr": sim.sim_time + 120.0, "dep": sim.sim_time + 420.0, "postoj": 180.0,
				"przelot": false, "koniec": false, "man": false,
				"tt_index": -1, "delay": 0, "podstawienie": false}),
			"check": func(): return _pociag("21102") != null,
		},
		{
			"tekst": "Pociąg czeka przed semaforem wjazdowym C (linia dalekobieżna od strony W-wy Centralnej, lewa strona pulpitu).\n\nWróć na PULPIT i upewnij się, że wybrane jest polecenie „PRZEBIEG POCIĄGOWY” (górna belka).",
			"check": func(): return sim.cmd_mode == SimCore.CMD_PP,
		},
		{
			"tekst": "KROK 1 — przycisk POCZĄTKU drogi przebiegu.\nKliknij semafor wjazdowy „C” po lewej stronie pulpitu.",
			"check": func(): return sim.pending_start == "C",
		},
		{
			"tekst": "KROK 2 — przycisk KOŃCA drogi przebiegu.\nKliknij semafor wyjazdowy „N5” na wschodnim końcu toru 5.\n\nUrządzenia same wybiorą drogę przebiegu, przestawią rozjazdy, utwierdzą przebieg (tor zabieli się) i dopiero wtedy semafor poda sygnał zezwalający.",
			"check": func(): return not sim.inter.route_of_signal("C").is_empty(),
		},
		{
			"tekst": "Obserwuj wjazd pociągu. Zajęte odcinki świecą na czerwono, a przebieg zwalnia się sekcyjnie za pociągiem.\n\nPoczekaj, aż pociąg zatrzyma się przy peronie.",
			"check": func(): var t := _pociag("21102"); return t != null and t.state == Train.State.NA_TORZE,
		},
		{
			"tekst": "POTWIERDZENIE PRZYJAZDU. Po przyjeździe pociągu należy potwierdzić go posterunkowi, który go wyprawił.\n\nWejdź w ŁĄCZNOŚĆ i użyj przycisku „Potwierdź przyjazd” dla poc. 21102.",
			"check": func(): var t := _pociag("21102"); return t != null and bool(sim.comms.perm.get(t.id, {}).get("przyjazd_potwierdzony", false)),
		},
		{
			"tekst": "EDR — Elektroniczny Dziennik Ruchu rejestruje wszystkie czynności. Możesz też dopisać własną uwagę.\n\nOtwórz ekran EDR i dodaj własny wpis (np. „Objąłem dyżur”).",
			"check": func():
				for e in sim.edr.entries:
					if str(e["kat"]) == "Dyżurny":
						return true
				return false,
		},
		{
			"tekst": "WYPRAWIENIE POCIĄGU. Najpierw trzeba uzyskać pozwolenie sąsiada.\n\nW ŁĄCZNOŚCI użyj „Żądaj pozwolenia” dla poc. 21102 (kierunek W-wa Rembertów) i poczekaj na odpowiedź „Droga wolna”.",
			"check": func(): var t := _pociag("21102"); return t != null and sim.comms.permission_status(t.id) == "udzielone",
		},
		{
			"tekst": "Teraz nastaw przebieg wyjazdowy: kliknij semafor „N5” (wschodni koniec toru 5), a następnie przycisk szlaku „W-wa Rembertów” (prostokąt po prawej stronie, tor 1).",
			"check": func(): var t := _pociag("21102"); return t != null and t.actual_dep >= 0.0,
		},
		{
			"tekst": "Po odjeździe oznajmij go sąsiadowi: w ŁĄCZNOŚCI użyj „Oznajmij odjazd” dla poc. 21102.",
			"check": func(): var t := _pociag("21102"); return t == null or bool(sim.comms.perm.get(t.id, {}).get("oznajmiony", false)),
		},
		{
			"tekst": "USTERKA SEMAFORA. Semafor wjazdowy „A” uległ uszkodzeniu, a od strony W-wy Centralnej jedzie ROJ 91105.\n\n1) Nastaw przebieg A → N1 (tor 1) — semafor nie poda sygnału.\n2) Kliknij semafor „A” PRAWYM przyciskiem i wybierz z menu „SZ” (sygnał zastępczy).",
			"on_enter": func():
				sim.events.force_event(sim.sim_time, "semafor", "A")
				_spawn("91105", "ROJ", "", "W-wa Zachodnia", "Otwock", "it1P", "it1W", "1"),
			"check": func(): return sim.inter.aspect("A") == Interlocking.ASPECT_SZ,
		},
		{
			"tekst": "ZGŁOSZENIE USTERKI. Usterki nie usuwają się same — trzeba je zgłosić właściwej służbie.\n\nOtwórz ekran ZDARZENIA (albo ŁĄCZNOŚĆ) i zgłoś usterkę semafora A do Automatyka SRK.",
			"check": func(): return sim.events.unreported_count() == 0,
		},
		{
			"tekst": "JAZDY MANEWROWE. Ze stacji technicznej Grochów (prawy dolny róg) trzeba podstawić skład na tor 8.\n\n1) Wybierz polecenie „PRZEBIEG MANEWROWY”.\n2) Kliknij tarczę manewrową „Tm1” przy Grochowie.\n3) Kliknij semafor „K8” (zachodni koniec toru 8).",
			"on_enter": func(): _spawn("Pm401", "MAN", "", "Grochów", "tor 8", "itG", "itG", "8", true),
			"check": func(): var t := _pociag("Pm401"); return t != null and not t.route.is_empty(),
		},
		{
			"tekst": "ROZJAZDY. Rozjazd można też przestawić indywidualnie — polecenie „ZW”, a następnie kliknięcie rozjazdu. Rozjazd zamknięty w przebiegu lub zajęty taborem nie da się przestawić.\n\nWybierz polecenie ZW i przestaw dowolny wolny rozjazd.",
			"check": func(): return sim.cmd_mode == SimCore.CMD_ZW and not sim.inter.sw_moving.is_empty(),
		},
		{
			"tekst": "To wszystkie podstawowe czynności dyżurnego ruchu.\n\nPozostałe polecenia pulpitu: ZD/ZDM — zwolnienie drogi przebiegu, ZWP — zwolnienie awaryjne z kontrolą czasu 180 s, OPS — opis elementu. Menu sygnalizatora zawiera dodatkowo STOP/OSTOP oraz tabliczki WTAB/KTAB.\n\nPowodzenia na dyżurze!",
			"cond": "next",
		},
	]
