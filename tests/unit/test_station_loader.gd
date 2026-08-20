extends GutTest
## Testy loadera i walidacji pliku stacji (docs/03-model-danych.md §7):
## wczytanie Borek + odrzucanie niespójnych danych z czytelnym komunikatem.

const BORKI_PATH := "res://data/stations/borki.json"


## Minimalna poprawna stacja do mutowania w testach błędów.
func _minimal_station() -> Dictionary:
	return {
		"meta": {"id": "test", "name": "Testowo"},
		"nodes": [{"id": "n1"}, {"id": "n2"}, {"id": "n3"}],
		"edges": [
			{"id": "e1", "from": "n1", "to": "n2", "len_m": 100, "vmax_kmh": 60},
			{"id": "e2", "from": "n2", "to": "n3", "len_m": 200, "vmax_kmh": 60},
			{"id": "e3", "from": "n2", "to": "n3", "len_m": 210, "vmax_kmh": 40},
		],
		"turnouts": [
			{"id": "z1", "node": "n2", "edge_root": "e1", "edge_plus": "e2",
			 "edge_minus": "e3", "throw_time_s": 5, "v_minus_kmh": 40},
		],
		"sections": [
			{"id": "s1", "type": "approach", "edges": ["e1"]},
			{"id": "sz1", "type": "turnout", "edges": [], "turnout": "z1", "len_m": 30},
			{"id": "s2", "type": "track", "edges": ["e2"]},
			{"id": "s3", "type": "track", "edges": ["e3"]},
		],
		"signals": [
			{"id": "A", "kind": "semafor", "at_node": "n1", "dir": "N", "heads": 5,
			 "can_ms2": true, "can_sz": true},
			{"id": "B", "kind": "semafor", "at_node": "n3", "dir": "P", "heads": 5,
			 "can_ms2": true, "can_sz": true},
		],
		"routes": [
			{"id": "A_s2", "class": "train", "entry_signal": "A", "target": "s2",
			 "sections": ["sz1", "s2"], "turnouts": {"z1": "PLUS"}, "flank": {},
			 "overlap": null, "v_route_kmh": 60, "conflicts": ["B_s2"]},
			{"id": "B_s2", "class": "train", "entry_signal": "B", "target": "s2",
			 "sections": ["sz1", "s2"], "turnouts": {"z1": "PLUS"}, "flank": {},
			 "overlap": null, "v_route_kmh": 60, "conflicts": ["A_s2"]},
		],
	}


func _errors_of(data: Dictionary) -> Array[String]:
	var result := StationLoader.parse(data)
	assert_false(result["ok"], "niespójne dane muszą zostać odrzucone")
	assert_null(result["station"], "przy błędach nie budujemy stacji")
	return result["errors"]


func _assert_any_contains(errors: Array[String], fragment: String) -> void:
	for message: String in errors:
		if message.contains(fragment):
			pass_test("znaleziono komunikat z '%s'" % fragment)
			return
	fail_test("brak komunikatu zawierającego '%s' w: %s" % [fragment, errors])


func test_wczytuje_borki_z_pliku() -> void:
	var result := StationLoader.load_from_file(BORKI_PATH)
	assert_true(result["ok"], "Borki muszą przechodzić walidację: %s" % [result["errors"]])
	var station: StationData = result["station"]
	assert_eq(station.id(), &"borki")
	assert_eq(station.display_name(), "Borki")
	assert_eq(station.graph.node_ids.size(), 4, "4 węzły")
	assert_eq(station.graph.edges.size(), 4, "4 krawędzie")
	assert_eq(station.graph.turnouts.size(), 2, "2 zwrotnice")
	assert_eq(station.graph.sections.size(), 6, "6 odcinków izolowanych")
	assert_eq(station.graph.signals.size(), 8, "8 sygnalizatorów")
	assert_eq(station.routes.size(), 8, "8 przebiegów w tabeli")
	assert_eq(station.blocks.size(), 2, "2 blokady liniowe")


func test_minimalna_stacja_poprawna() -> void:
	var result := StationLoader.parse(_minimal_station())
	assert_true(result["ok"], "stacja bazowa testów musi być poprawna: %s" % [result["errors"]])


func test_blad_nieistniejacy_plik() -> void:
	var result := StationLoader.load_from_file("res://data/stations/nie_ma.json")
	assert_false(result["ok"])
	_assert_any_contains(result["errors"], "nie_ma.json")


func test_blad_brak_wymaganej_sekcji_pliku() -> void:
	var data := _minimal_station()
	data.erase("sections")
	_assert_any_contains(_errors_of(data), "sections")


func test_blad_krawedz_do_nieistniejacego_wezla() -> void:
	var data := _minimal_station()
	(data["edges"][0] as Dictionary)["to"] = "n99"
	var errors := _errors_of(data)
	_assert_any_contains(errors, "e1")
	_assert_any_contains(errors, "n99")


func test_blad_duplikat_id_wezla() -> void:
	var data := _minimal_station()
	(data["nodes"] as Array).append({"id": "n1"})
	_assert_any_contains(_errors_of(data), "zduplikowane")


func test_blad_sekcja_z_nieznana_krawedzia() -> void:
	var data := _minimal_station()
	((data["sections"][0] as Dictionary)["edges"] as Array).append("e99")
	var errors := _errors_of(data)
	_assert_any_contains(errors, "s1")
	_assert_any_contains(errors, "e99")


func test_blad_krawedz_w_dwoch_sekcjach() -> void:
	# Przypadek brzegowy kompletności sekcji: ta sama krawędź w dwóch odcinkach.
	var data := _minimal_station()
	((data["sections"][3] as Dictionary)["edges"] as Array).append("e2")
	_assert_any_contains(_errors_of(data), "należy już do sekcji")


func test_blad_zwrotnica_z_krawedzia_bez_styku() -> void:
	var data := _minimal_station()
	(data["edges"] as Array).append(
		{"id": "e_obca", "from": "n1", "to": "n3", "len_m": 50, "vmax_kmh": 40}
	)
	(data["sections"] as Array).append(
		{"id": "s_obca", "type": "track", "edges": ["e_obca"]}
	)
	(data["turnouts"][0] as Dictionary)["edge_minus"] = "e_obca"
	_assert_any_contains(_errors_of(data), "nie styka się")


func test_blad_przebieg_z_nieznanym_semaforem() -> void:
	var data := _minimal_station()
	(data["routes"][0] as Dictionary)["entry_signal"] = "X"
	var errors := _errors_of(data)
	_assert_any_contains(errors, "A_s2")
	_assert_any_contains(errors, "X")


func test_blad_przebieg_ze_zlym_polozeniem_zwrotnicy() -> void:
	var data := _minimal_station()
	(data["routes"][0] as Dictionary)["turnouts"] = {"z1": "LEWO"}
	_assert_any_contains(_errors_of(data), "LEWO")


func test_blad_konflikty_niesymetryczne() -> void:
	var data := _minimal_station()
	(data["routes"][1] as Dictionary)["conflicts"] = []
	_assert_any_contains(_errors_of(data), "niesymetryczne")


func test_blad_konflikt_z_samym_soba() -> void:
	# Przypadek brzegowy tabeli konfliktów.
	var data := _minimal_station()
	(data["routes"][0] as Dictionary)["conflicts"] = ["A_s2", "B_s2"]
	_assert_any_contains(_errors_of(data), "samym sobą")


func test_blad_panel_wskazuje_nieistniejaca_zwrotnice() -> void:
	var data := _minimal_station()
	data["panel"] = {"type": "kostkowy", "grid": [4, 2], "tiles": [
		{"xy": [0, 0], "tile": "turnout_ne", "turnout": "z9"},
	]}
	_assert_any_contains(_errors_of(data), "z9")
