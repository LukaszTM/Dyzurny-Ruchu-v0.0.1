extends GutTest
## Testy grafu torowego na wczytanej stacji Borki: ręczna zajętość sekcji,
## przestawianie zwrotnic z warunkami z docs/04 §2, kwerendy indeksów.

const BORKI_PATH := "res://data/stations/borki.json"

var _graph: TrackGraph


func before_each() -> void:
	var result := StationLoader.load_from_file(BORKI_PATH)
	assert_true(result["ok"], "stacja Borki musi się wczytywać: %s" % [result["errors"]])
	_graph = (result["station"] as StationData).graph


func test_reczna_zajetosc_sekcji() -> void:
	var section := _graph.get_section(&"it1")
	assert_false(section.occupied, "sekcja startuje wolna")
	var result := _graph.set_section_occupied(&"it1", true)
	assert_true(result.ok)
	assert_true(section.occupied, "sekcja zajęta po ustawieniu ręcznym")
	_graph.set_section_occupied(&"it1", false)
	assert_true(section.is_free(), "sekcja zwolniona po odwołaniu")


func test_zajetosc_nieznanej_sekcji_odmowa() -> void:
	var result := _graph.set_section_occupied(&"nie_ma", true)
	assert_false(result.ok, "nieznana sekcja = czytelna odmowa")
	assert_string_contains(result.reason, "nie_ma")


func test_przestawienie_zwrotnicy_przez_graf() -> void:
	var turnout := _graph.get_turnout(&"z1")
	assert_true(turnout.is_plus())
	var result := _graph.throw_turnout(&"z1")
	assert_true(result.ok, "wolna, sprawna zwrotnica daje się przestawić")
	var finished: Array[StringName] = []
	# 5 s czasu symulacji po 0,1 s — jak prawdziwe ticki SimClock.
	for i: int in 50:
		finished.append_array(_graph.tick(0.1))
	assert_eq(finished, [&"z1"] as Array[StringName], "dokładnie jedna zwrotnica kończy ruch")
	assert_true(turnout.is_minus(), "po 5 s zwrotnica w położeniu zwrotnym")


func test_odmowa_gdy_sekcja_zwrotnicowa_zajeta() -> void:
	_graph.set_section_occupied(&"izw1", true)
	var result := _graph.throw_turnout(&"z1")
	assert_false(result.ok, "nie wolno przestawiać zwrotnicy pod taborem (docs/04 §2)")
	assert_string_contains(result.reason, "izw1")
	assert_true(_graph.get_turnout(&"z1").is_plus(), "zwrotnica pozostaje w położeniu")


func test_odmowa_gdy_sekcja_utwierdzona() -> void:
	_graph.get_section(&"izw1").locked_by = &"A_t1"
	var result := _graph.throw_turnout(&"z1")
	assert_false(result.ok, "utwierdzona sekcja zwrotnicowa blokuje przestawianie")
	assert_string_contains(result.reason, "A_t1")


func test_odmowa_nieznana_zwrotnica() -> void:
	var result := _graph.throw_turnout(&"z9")
	assert_false(result.ok)
	assert_string_contains(result.reason, "z9")


func test_kwerendy_indeksow() -> void:
	assert_eq(_graph.section_for_turnout(&"z1").id, &"izw1")
	assert_eq(_graph.section_for_turnout(&"z2").id, &"izw2")
	assert_eq(_graph.section_for_edge(&"e_t1").id, &"it1")
	assert_eq(_graph.section_for_edge(&"e_szlak_w").id, &"iza")
	assert_null(_graph.section_for_edge(&"nie_ma"), "nieznana krawędź → null")


func test_sygnalizatory_startuja_w_stanie_zasadniczym() -> void:
	assert_eq(_graph.get_signal(&"A").aspect, &"S1", "semafor spoczynkowo „stój”")
	assert_true(_graph.get_signal(&"A").shows_stop())
	assert_eq(_graph.get_signal(&"ToA").aspect, &"Os1", "tarcza ostrzegawcza spoczynkowo Os1")


func test_snapshot_grafu() -> void:
	_graph.set_section_occupied(&"it2", true)
	_graph.throw_turnout(&"z2")
	var snapshot := _graph.to_dict()
	# Świeżo wczytany graf tej samej stacji odtwarza stan dynamiczny.
	var result := StationLoader.load_from_file(BORKI_PATH)
	var other: TrackGraph = (result["station"] as StationData).graph
	other.from_dict(snapshot)
	assert_true(other.get_section(&"it2").occupied)
	assert_eq(other.get_turnout(&"z2").state, Const.TurnoutState.MOVING)
