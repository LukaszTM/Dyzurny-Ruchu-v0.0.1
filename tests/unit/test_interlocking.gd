extends GutTest
## Testy silnika zależności — komplet wymagany przez docs/04 §9 na stacji
## Borki + stacja syntetyczna (3 sekcje, ochrona boczna, propagacja obrazów).

const BORKI_PATH := "res://data/stations/borki.json"

var _world: SimWorld


func before_each() -> void:
	_world = SimWorld.new()
	var result := _world.load_station_file(BORKI_PATH)
	assert_true(result["ok"], "Borki muszą się wczytać")


func _il() -> Interlocking:
	return _world.interlocking


func _graph() -> TrackGraph:
	return _world.station.graph


func _occupy(section_id: StringName, occupied: bool = true) -> void:
	_graph().set_section_occupied(section_id, occupied)
	_il().tick(0.0)


## Przestawia zwrotnicę i domyka przestawianie (5 s po 0,1 s jak SimClock).
func _throw_and_finish(turnout_id: StringName) -> void:
	var result := _il().execute(&"turnout_throw", {"id": turnout_id})
	assert_true(result.ok, "przestawienie %s: %s" % [turnout_id, result.reason])
	for i: int in 51:
		_world.tick(0.1)


# --- Utwierdzanie (§3, §9.1) -------------------------------------------------

func test_utwierdzenie_wjazdu_na_tor_1() -> void:
	var result := _il().execute(&"route_start", {"id": "A"})
	assert_true(result.ok, result.reason)
	var route := _il().get_route(&"A_t1")
	assert_eq(route.state, Const.RouteState.LOCKED)
	assert_eq(_graph().get_section(&"izw1").locked_by, &"A_t1", "sekcja drogi utwierdzona")
	assert_eq(_graph().get_section(&"izw2").locked_by, &"A_t1", "droga ochronna utwierdzona")
	assert_eq(_graph().get_turnout(&"z1").locked_by, &"A_t1", "zwrotnica drogi zamknięta")
	assert_eq(_graph().get_turnout(&"z2").locked_by, &"A_t1", "zwrotnica drogi ochronnej zamknięta")
	assert_eq(_graph().get_signal(&"A").aspect, &"S5",
		"wjazd na wprost, następny (C1) „stój” → S5")
	assert_eq(_graph().get_signal(&"ToA").aspect, &"Os2", "tarcza: semafor w grupie VMAX")


func test_utwierdzenie_wjazdu_na_tor_2_grupa_40() -> void:
	_throw_and_finish(&"z1")
	_throw_and_finish(&"z2")
	var result := _il().execute(&"route_start", {"id": "A"})
	assert_true(result.ok, result.reason)
	assert_eq(_il().get_route(&"A_t2").state, Const.RouteState.LOCKED)
	assert_eq(_graph().get_signal(&"A").aspect, &"S10",
		"jazda w bok 40 km/h, następny „stój” → S10")


func test_odmowa_zajeta_sekcja() -> void:
	_occupy(&"it1")
	var result := _il().execute(&"route_start", {"id": "A"})
	assert_false(result.ok, "nie wolno utwierdzić przebiegu na zajętą sekcję")
	assert_string_contains(result.reason, "it1")
	assert_eq(_graph().get_signal(&"A").aspect, &"S1")


func test_odmowa_przebieg_sprzeczny() -> void:
	assert_true(_il().execute(&"route_start", {"id": "A"}).ok)
	var result := _il().execute(&"route_start", {"id": "B"})
	assert_false(result.ok, "przebieg sprzeczny z nastawionym musi być odrzucony")
	assert_string_contains(result.reason, "sprzeczny")


func test_odmowa_zajeta_droga_ochronna() -> void:
	_occupy(&"izw2")
	var result := _il().execute(&"route_start", {"id": "A"})
	assert_false(result.ok, "droga ochronna musi być wolna (docs/04 §3.5)")
	assert_string_contains(result.reason, "ochronnej")


func test_odmowa_zle_polozenie_zwrotnic() -> void:
	_throw_and_finish(&"z1")
	# z1 MINUS, z2 PLUS: nie pasuje ani do A_t1, ani do A_t2 (wymaga z2 MINUS
	# w drodze ochronnej)... A_t2 wymaga w drodze jazdy tylko z1 MINUS — pasuje,
	# ale droga ochronna z2 w złym położeniu → odmowa.
	var result := _il().execute(&"route_start", {"id": "A"})
	assert_false(result.ok)
	assert_string_contains(result.reason, "z2")


# --- Zwrotnice w przebiegu (§9.2) i zwalnianie sekcyjne (§9.3) ---------------

func test_zwrotnica_utwierdzona_nie_do_przestawienia() -> void:
	assert_true(_il().execute(&"route_start", {"id": "A"}).ok)
	var result := _il().execute(&"turnout_throw", {"id": "z1"})
	assert_false(result.ok, "zwrotnicy w przebiegu LOCKED nie wolno przestawiać")
	assert_string_contains(result.reason, "A_t1")


func test_przejazd_zwalnia_sekcyjnie_i_zwrotnice() -> void:
	assert_true(_il().execute(&"route_start", {"id": "A"}).ok)
	# Czoło pociągu za semaforem: pierwsza sekcja zajęta → semafor „stój".
	_occupy(&"izw1")
	assert_eq(_il().get_route(&"A_t1").state, Const.RouteState.TRAIN_ON)
	assert_eq(_graph().get_signal(&"A").aspect, &"S1", "powrót na „stój” po minięciu czoła")
	# Pociąg przechodzi na tor 1, zwalnia sekcję zwrotnicową.
	_occupy(&"it1")
	_occupy(&"izw1", false)
	assert_eq(_graph().get_section(&"izw1").locked_by, &"", "izw1 zwolniona sekcyjnie")
	var result := _il().execute(&"turnout_throw", {"id": "z1"})
	assert_true(result.ok, "po zwolnieniu sekcyjnym zwrotnica znów przestawialna: %s" % result.reason)
	# Pociąg dojechał na tor docelowy (it1 zajęty) → droga ochronna zwolniona,
	# przebieg wraca do IDLE (docs/04 §2).
	assert_eq(_il().get_route(&"A_t1").state, Const.RouteState.IDLE)
	assert_eq(_graph().get_turnout(&"z2").locked_by, &"", "zwrotnica drogi ochronnej wolna")
	assert_eq(_graph().get_section(&"it1").locked_by, &"", "utwierdzenie zdjęte (zajętość chroni)")
	assert_true(_graph().get_section(&"it1").occupied, "pociąg nadal na torze")


# --- Kasowanie i doraźne zwolnienie (§9.5) -----------------------------------

func test_kasowanie_przy_wolnym_zblizaniu_natychmiastowe() -> void:
	assert_true(_il().execute(&"route_start", {"id": "A"}).ok)
	var result := _il().execute(&"signal_cancel", {"id": "A"})
	assert_true(result.ok, result.reason)
	assert_eq(_il().get_route(&"A_t1").state, Const.RouteState.IDLE)
	assert_eq(_graph().get_turnout(&"z1").locked_by, &"")
	assert_eq(_graph().get_signal(&"A").aspect, &"S1")


func test_kasowanie_z_zajetym_zblizaniem_wymusza_dzw_timer_i_licznik() -> void:
	_occupy(&"iza")
	assert_true(_il().execute(&"route_start", {"id": "A"}).ok,
		"zajęte zbliżanie nie przeszkadza w utwierdzeniu (pociąg jedzie na semafor)")
	var cancel := _il().execute(&"signal_cancel", {"id": "A"})
	assert_false(cancel.ok, "przy zajętym zbliżaniu zwykłe kasowanie zabronione")
	assert_string_contains(cancel.reason, "dZw")
	# Doraźne zwolnienie: uzbrojenie dZw + wskazanie semafora.
	_il().execute(&"route_emergency_release", {})
	var release := _il().execute(&"route_start", {"id": "A"})
	assert_true(release.ok, release.reason)
	var route := _il().get_route(&"A_t1")
	assert_eq(route.state, Const.RouteState.CANCELLED)
	assert_eq(int(_il().counters.get("dZw", 0)), 1, "licznik dZw rośnie")
	assert_eq(_graph().get_signal(&"A").aspect, &"S1", "semafor na „stój” od razu")
	assert_eq(_graph().get_section(&"it1").locked_by, &"A_t1",
		"w czasie ewolucji elementy pozostają utwierdzone")
	for i: int in 899:
		_il().tick(0.1)
	assert_eq(route.state, Const.RouteState.CANCELLED, "czas ewolucji 90 s jeszcze trwa")
	for i: int in 12:
		_il().tick(0.1)
	assert_eq(route.state, Const.RouteState.IDLE, "po czasie ewolucji zwolnione")
	assert_eq(_graph().get_section(&"it1").locked_by, &"")


# --- Sygnał zastępczy (§5) ---------------------------------------------------

func test_sz_z_licznikiem_i_timerem() -> void:
	var result := _il().execute(&"sub_signal", {"id": "C1"})
	assert_true(result.ok, result.reason)
	assert_eq(_graph().get_signal(&"C1").aspect, &"Sz")
	assert_eq(int(_il().counters.get("dSz:C1", 0)), 1, "licznik dSz rośnie")
	var again := _il().execute(&"sub_signal", {"id": "C1"})
	assert_false(again.ok, "Sz już podany → odmowa")
	for i: int in 901:
		_il().tick(0.1)
	assert_eq(_graph().get_signal(&"C1").aspect, &"S1", "Sz gaśnie po czasie")


func test_sz_odmowy() -> void:
	assert_false(_il().execute(&"sub_signal", {"id": "C2"}).ok,
		"C2 nie ma sygnału zastępczego (can_sz=false)")
	assert_true(_il().execute(&"route_start", {"id": "A"}).ok)
	assert_false(_il().execute(&"sub_signal", {"id": "A"}).ok,
		"Sz tylko na semaforze wskazującym „stój”")


# --- Rozprucie (§9.6) i zamknięcia indywidualne (§4) -------------------------

func test_rozprucie_wyklucza_zwrotnice_z_przebiegow() -> void:
	_graph().get_turnout(&"z1").trail()
	var result := _il().execute(&"route_start", {"id": "A"})
	assert_false(result.ok, "rozpruta zwrotnica = brak kontroli = brak przebiegu")


func test_rozprucie_pod_przebiegiem_gasi_semafor() -> void:
	assert_true(_il().execute(&"route_start", {"id": "A"}).ok)
	assert_eq(_graph().get_signal(&"A").aspect, &"S5")
	_graph().get_turnout(&"z1").trail()
	_il().tick(0.1)
	assert_eq(_graph().get_signal(&"A").aspect, &"S1",
		"utrata kontroli zwrotnicy w przebiegu gasi sygnał zezwalający")


func test_zamkniecie_indywidualne() -> void:
	_il().execute(&"turnout_lock_toggle", {})
	var toggle := _il().execute(&"turnout_throw", {"id": "z1"})
	assert_true(toggle.ok, toggle.reason)
	assert_true(_graph().get_turnout(&"z1").closed_individually)
	var throw := _il().execute(&"turnout_throw", {"id": "z1"})
	assert_false(throw.ok, "zamkniętej zwrotnicy nie wolno przestawiać")
	assert_string_contains(throw.reason, "zamknięta")
	# Zamknięta w wymaganym położeniu nie przeszkadza przebiegowi (docs/04 §4).
	assert_true(_il().execute(&"route_start", {"id": "A"}).ok)


# --- Stacja syntetyczna: 3 sekcje, ochrona boczna, propagacja obrazów --------

func _synthetic_station() -> Dictionary:
	return {
		"meta": {"id": "syn", "name": "Syntetyczna"},
		"nodes": [
			{"id": "n1"}, {"id": "n2"}, {"id": "n3"}, {"id": "n4"},
			{"id": "n5"}, {"id": "n6"}, {"id": "n7"}, {"id": "n8"},
		],
		"edges": [
			{"id": "e_app", "from": "n1", "to": "n2", "len_m": 500, "vmax_kmh": 100},
			{"id": "e_a", "from": "n2", "to": "n3", "len_m": 300, "vmax_kmh": 100},
			{"id": "e_b", "from": "n3", "to": "n4", "len_m": 300, "vmax_kmh": 100},
			{"id": "e_c", "from": "n4", "to": "n5", "len_m": 300, "vmax_kmh": 100},
			{"id": "e_out", "from": "n5", "to": "n6", "len_m": 500, "vmax_kmh": 100},
			{"id": "e_f1", "from": "n3", "to": "n7", "len_m": 100, "vmax_kmh": 40},
			{"id": "e_f2", "from": "n7", "to": "n8", "len_m": 100, "vmax_kmh": 40},
		],
		"turnouts": [
			{"id": "zf", "node": "n3", "edge_root": "e_f1", "edge_plus": "e_a",
			 "edge_minus": "e_b", "throw_time_s": 4, "v_minus_kmh": 40},
		],
		"sections": [
			{"id": "s_app", "type": "approach", "edges": ["e_app"]},
			{"id": "s_a", "type": "track", "edges": ["e_a"]},
			{"id": "s_b", "type": "track", "edges": ["e_b"]},
			{"id": "s_c", "type": "track", "edges": ["e_c"]},
			{"id": "s_out", "type": "approach", "edges": ["e_out"]},
			{"id": "s_f", "type": "track", "edges": ["e_f1", "e_f2"]},
		],
		"signals": [
			{"id": "SA", "kind": "semafor", "at_node": "n2", "dir": "N", "heads": 5,
			 "can_ms2": true, "can_sz": true},
			{"id": "SB", "kind": "semafor", "at_node": "n5", "dir": "N", "heads": 3,
			 "can_ms2": true, "can_sz": true},
			{"id": "SF", "kind": "semafor", "at_node": "n7", "dir": "P", "heads": 3,
			 "can_ms2": true, "can_sz": false},
		],
		"routes": [
			{"id": "R_in", "class": "train", "entry_signal": "SA", "target": "c",
			 "exit_signal": "SB", "sections": ["s_a", "s_b", "s_c"],
			 "turnouts": {}, "flank": {"zf": "MINUS", "signals_at_stop": ["SF"]},
			 "overlap": null, "v_route_kmh": 100, "conflicts": []},
			{"id": "R_out", "class": "train", "entry_signal": "SB", "target": "out",
			 "sections": ["s_out"], "turnouts": {}, "flank": {},
			 "overlap": null, "v_route_kmh": 100, "conflicts": []},
		],
	}


func _load_synthetic() -> Interlocking:
	var parsed := StationLoader.parse(_synthetic_station())
	assert_true(parsed["ok"], "stacja syntetyczna: %s" % [parsed["errors"]])
	var station: StationData = parsed["station"]
	return Interlocking.new(station.graph, station.routes, AspectTable.load_default())


func test_odmowa_bez_ochrony_bocznej() -> void:
	var il := _load_synthetic()
	var result := il.execute(&"route_start", {"id": "SA"})
	assert_false(result.ok, "zwrotnica ochronna w złym położeniu → odmowa (docs/04 §3.3)")
	assert_string_contains(result.reason, "zf")


func test_ochrona_boczna_zamyka_zwrotnice() -> void:
	var il := _load_synthetic()
	il.execute(&"turnout_throw", {"id": "zf"})
	for i: int in 41:
		il.graph.tick(0.1)
	var result := il.execute(&"route_start", {"id": "SA"})
	assert_true(result.ok, result.reason)
	assert_eq(il.graph.get_turnout(&"zf").locked_by, &"R_in",
		"zwrotnica ochronna zamknięta w przebiegu")


func test_propagacja_obrazow_wjazd_za_wyjazdem() -> void:
	var il := _load_synthetic()
	il.execute(&"turnout_throw", {"id": "zf"})
	for i: int in 41:
		il.graph.tick(0.1)
	assert_true(il.execute(&"route_start", {"id": "SB"}).ok)
	assert_eq(il.graph.get_signal(&"SB").aspect, &"S5", "wyjazd bez następnika → S5")
	assert_true(il.execute(&"route_start", {"id": "SA"}).ok)
	assert_eq(il.graph.get_signal(&"SA").aspect, &"S2",
		"następny semafor zezwala z maksymalną → S2")


func test_zwalnianie_sekcyjne_3_sekcje_krok_po_kroku() -> void:
	var il := _load_synthetic()
	il.execute(&"turnout_throw", {"id": "zf"})
	for i: int in 41:
		il.graph.tick(0.1)
	assert_true(il.execute(&"route_start", {"id": "SA"}).ok)
	var route := il.get_route(&"R_in")
	# Pociąg zajmuje s_a i s_b jednocześnie (długi skład).
	il.graph.set_section_occupied(&"s_a", true)
	il.tick(0.1)
	assert_eq(route.state, Const.RouteState.TRAIN_ON)
	il.graph.set_section_occupied(&"s_b", true)
	il.tick(0.1)
	# Zwolnienie s_b PRZED s_a nie zwalnia s_b (kolejność! docs/04 §2).
	il.graph.set_section_occupied(&"s_b", false)
	il.tick(0.1)
	assert_false(route.released[1], "s_b czeka na zwolnienie s_a")
	assert_eq(il.graph.get_section(&"s_b").locked_by, &"R_in")
	# Zwolnienie s_a odblokowuje kolejno s_a i s_b.
	il.graph.set_section_occupied(&"s_a", false)
	il.tick(0.1)
	assert_true(route.released[0], "s_a zwolniona")
	assert_true(route.released[1], "s_b zwolniona po s_a")
	assert_eq(il.graph.get_section(&"s_a").locked_by, &"")
	assert_false(route.released[2], "s_c wciąż utwierdzona")
	# Pociąg przejeżdża s_c i opuszcza stację.
	il.graph.set_section_occupied(&"s_c", true)
	il.tick(0.1)
	il.graph.set_section_occupied(&"s_c", false)
	il.tick(0.1)
	assert_eq(route.state, Const.RouteState.IDLE, "po ostatniej sekcji przebieg zwolniony")
	assert_eq(il.graph.get_turnout(&"zf").locked_by, &"", "ochrona boczna zwolniona")
