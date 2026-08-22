extends GutTest
## Testy F9: komputerowe urządzenia nastawcze (docs/systemy/14) — nastawianie
## przebiegowe, polecenia dwustopniowe (potwierdzenie), rejestr zdarzeń.

var _world: SimWorld
var _events: Array[Dictionary] = []


func before_each() -> void:
	_world = SimWorld.new()
	_events.clear()
	assert_true(_world.load_station_file("res://data/stations/lipiny.json")["ok"],
		"stacja Lipiny (komputerowa) wczytuje się")
	_world.rng.seed = 11


func _tick_n(count: int) -> void:
	for i: int in count:
		_world.tick(0.1)
		_events.append_array(_world.drain_events())


func _has_event(type: StringName) -> bool:
	for event: Dictionary in _events:
		if event["type"] == type:
			return true
	return false


func _register_contains(fragment: String) -> bool:
	for entry: Dictionary in _world.register.entries:
		if String(entry["text"]).contains(fragment):
			return true
	return false


# --- Nastawianie przebiegowe ------------------------------------------------

func test_route_set_uklada_zwrotnice_i_utwierdza() -> void:
	# A_t3 wymaga z1 w MINUS (stan zasadniczy: PLUS) — droga układa się sama.
	var result := _world.execute(&"route_set", {"id": "A_t3"})
	assert_true(result.ok, "polecenie przebiegowe przyjęte: %s" % result.reason)
	var route := _world.interlocking.get_route(&"A_t3")
	assert_ne(route.state, Const.RouteState.LOCKED, "zwrotnica dopiero się przestawia")
	_tick_n(100)
	assert_eq(route.state, Const.RouteState.LOCKED,
		"po dojściu zwrotnic przebieg utwierdzony")
	assert_false(_world.station.graph.get_signal(&"A").shows_stop(),
		"semafor A podaje sygnał zezwalający")


func test_route_set_natychmiast_gdy_zwrotnice_leza() -> void:
	# A_t1: z1/z2 w PLUS — stan zasadniczy, utwierdzenie od ręki.
	assert_true(_world.execute(&"route_set", {"id": "A_t1"}).ok)
	assert_eq(_world.interlocking.get_route(&"A_t1").state, Const.RouteState.LOCKED)


func test_route_set_odmowa_sprzecznego() -> void:
	assert_true(_world.execute(&"route_set", {"id": "A_t1"}).ok)
	var refused := _world.execute(&"route_set", {"id": "A_t3"})
	assert_false(refused.ok)
	assert_string_contains(refused.reason, "sprzeczny")


func test_route_set_zdarzenie_gdy_droga_zajeta_po_ulozeniu() -> void:
	# Sekcja docelowa zajęta: zwrotnice zdążą się ułożyć, utwierdzenie odmówi
	# — rdzeń melduje zdarzeniem route_set_failed (okno dialogowe w GUI).
	_world.execute(&"debug_section_occupied", {"id": "it3", "value": "1"})
	assert_true(_world.execute(&"route_set", {"id": "A_t3"}).ok)
	_tick_n(100)
	assert_true(_has_event(&"route_set_failed"), "niepowodzenie nastawiania zgłoszone")
	assert_eq(_world.interlocking.get_route(&"A_t3").state, Const.RouteState.IDLE)


# --- Polecenia dwustopniowe ---------------------------------------------------

func test_polecenie_specjalne_wymaga_potwierdzenia() -> void:
	var first := _world.execute(&"sub_signal", {"id": "A"})
	assert_false(first.ok, "pierwszy krok tylko odkłada polecenie")
	assert_string_contains(first.reason, "potwierdzenia")
	assert_false(_world.pending_confirm.is_empty())
	_tick_n(1)
	assert_true(_has_event(&"confirm_required"))
	assert_ne(_world.station.graph.get_signal(&"A").aspect, &"Sz",
		"Sz jeszcze nie podany")
	var confirmed := _world.execute(&"command_confirm", {})
	assert_true(confirmed.ok, "potwierdzenie wykonuje polecenie: %s" % confirmed.reason)
	assert_eq(_world.station.graph.get_signal(&"A").aspect, &"Sz",
		"po potwierdzeniu semafor podaje Sz")
	assert_true(_world.pending_confirm.is_empty())


func test_polecenie_specjalne_anulowanie() -> void:
	_world.execute(&"crossing_close", {"id": "przA"})
	_tick_n(300)
	assert_true((_world.crossings[&"przA"] as LevelCrossing).is_closed())
	# Otwarcie przejazdu = polecenie specjalne; anulujemy — rogatki zostają.
	assert_false(_world.execute(&"crossing_open", {"id": "przA"}).ok)
	assert_true(_world.execute(&"command_cancel", {}).ok)
	assert_true(_world.pending_confirm.is_empty())
	_tick_n(50)
	assert_true((_world.crossings[&"przA"] as LevelCrossing).is_closed(),
		"po anulowaniu przejazd wciąż zamknięty")
	assert_false(_world.execute(&"command_confirm", {}).ok,
		"nie ma już czego potwierdzać")


func test_potwierdzenie_wygasa() -> void:
	_world.execute(&"sub_signal", {"id": "A"})
	_tick_n(int(SimWorld.CONFIRM_TIME_S * 10.0) + 5)
	assert_true(_world.pending_confirm.is_empty(), "niepotwierdzone wygasło")
	assert_true(_has_event(&"confirm_expired"))
	assert_false(_world.execute(&"command_confirm", {}).ok)


func test_zwykle_polecenia_bez_potwierdzenia() -> void:
	assert_true(_world.execute(&"route_set", {"id": "A_t1"}).ok,
		"polecenia ruchowe zwykłe wykonują się od razu")
	assert_true(_world.execute(&"crossing_close", {"id": "przA"}).ok)


func test_pulpit_kostkowy_bez_trybu_potwierdzen() -> void:
	var kostkowy := SimWorld.new()
	assert_true(kostkowy.load_station_file("res://data/stations/brzeziny.json")["ok"])
	assert_false(kostkowy.confirm_mode)
	assert_true(kostkowy.execute(&"sub_signal", {"id": "A"}).ok,
		"na pulpicie Sz podaje się przyciskiem plombowanym, bez dialogu")


# --- Rejestr zdarzeń ------------------------------------------------------------

func test_rejestr_loguje_polecenia_i_zdarzenia() -> void:
	_world.execute(&"route_set", {"id": "A_t1"})
	var refused := _world.execute(&"route_set", {"id": "A_t3"})
	assert_false(refused.ok)
	assert_true(_register_contains("route_set A_t1 — wykonano"))
	assert_true(_register_contains("odmowa"))
	# Zdarzenie rdzenia (SYS) trafia do rejestru przy drenażu.
	_world.pending_events.append({"type": &"alarm", "text": "Próba rejestru"})
	_tick_n(1)
	assert_true(_register_contains("Próba rejestru"))
	var line := EventRegister.format_line(_world.register.entries[0])
	assert_string_contains(line, " | DYŻ | ")


func test_rejestr_przycina_najstarsze() -> void:
	for i: int in EventRegister.MAX_ENTRIES + 50:
		_world.register.add(float(i), "SYS", "wpis %d" % i)
	assert_eq(_world.register.entries.size(), EventRegister.MAX_ENTRIES)
	assert_eq(String(_world.register.entries[0]["text"]), "wpis 50",
		"najstarsze wpisy wypadają")
	assert_eq(_world.register.last(5).size(), 5)
