extends GutTest
## Testy zwrotnicy: stany i przestawianie wg docs/04-logika-zaleznosci.md §2.


func _make_turnout() -> Turnout:
	var turnout := Turnout.new()
	turnout.id = &"z1"
	turnout.throw_time_s = 5.0
	return turnout


func test_przestawianie_plus_na_minus() -> void:
	var turnout := _make_turnout()
	assert_true(turnout.is_plus(), "zwrotnica startuje w położeniu zasadniczym")
	var result := turnout.start_throw()
	assert_true(result.ok, "przestawienie sprawnej, wolnej zwrotnicy dozwolone")
	assert_eq(turnout.state, Const.TurnoutState.MOVING, "w trakcie: MOVING (brak kontroli)")
	assert_false(turnout.has_control(), "w czasie przestawiania brak kontroli położenia")
	assert_false(turnout.tick(2.0), "po 2 s z 5 s jeszcze się przestawia")
	assert_true(turnout.tick(3.0), "po pełnym czasie przestawianie zakończone")
	assert_true(turnout.is_minus(), "po przestawieniu położenie zwrotne")


func test_przestawianie_z_powrotem_na_plus() -> void:
	var turnout := _make_turnout()
	turnout.start_throw()
	turnout.tick(5.0)
	var result := turnout.start_throw()
	assert_true(result.ok)
	turnout.tick(5.0)
	assert_true(turnout.is_plus(), "drugi ruch wraca do położenia zasadniczego")


func test_tick_konczy_dokladnie_na_granicy_czasu() -> void:
	# Przypadek brzegowy: dt równe dokładnie czasowi przestawiania.
	var turnout := _make_turnout()
	turnout.start_throw()
	assert_true(turnout.tick(5.0), "przestawianie kończy się dokładnie po throw_time_s")
	assert_true(turnout.is_minus())


func test_odmowa_w_trakcie_przestawiania() -> void:
	var turnout := _make_turnout()
	turnout.start_throw()
	var result := turnout.start_throw()
	assert_false(result.ok, "nie wolno przestawiać zwrotnicy będącej w ruchu")
	assert_string_contains(result.reason, "w trakcie")


func test_odmowa_rozpruta() -> void:
	var turnout := _make_turnout()
	turnout.trail()
	assert_eq(turnout.state, Const.TurnoutState.TRAILED)
	var result := turnout.start_throw()
	assert_false(result.ok, "rozpruta zwrotnica wymaga procedury, nie przestawienia")
	assert_string_contains(result.reason, "rozpruta")


func test_odmowa_brak_kontroli() -> void:
	var turnout := _make_turnout()
	turnout.set_no_control()
	var result := turnout.start_throw()
	assert_false(result.ok, "usterka (brak kontroli) blokuje przestawianie")
	assert_string_contains(result.reason, "bez kontroli")


func test_odmowa_zamknieta_indywidualnie() -> void:
	var turnout := _make_turnout()
	turnout.closed_individually = true
	var result := turnout.start_throw()
	assert_false(result.ok, "zamknięcie indywidualne blokuje przestawianie (docs/04 §4)")
	assert_string_contains(result.reason, "zamknięta")


func test_odmowa_utwierdzona_w_przebiegu() -> void:
	var turnout := _make_turnout()
	turnout.locked_by = &"A_t1"
	var result := turnout.start_throw()
	assert_false(result.ok, "utwierdzenie w przebiegu blokuje przestawianie")
	assert_string_contains(result.reason, "A_t1")


func test_snapshot_stanu_dynamicznego() -> void:
	var turnout := _make_turnout()
	turnout.start_throw()
	turnout.tick(2.0)
	var snapshot := turnout.to_dict()
	var restored := _make_turnout()
	restored.from_dict(snapshot)
	assert_eq(restored.state, Const.TurnoutState.MOVING)
	assert_almost_eq(restored.move_left_s, 3.0, 0.0001, "pozostały czas ruchu odtworzony")
	assert_true(restored.tick(3.0), "odtworzona zwrotnica kończy ruch po pozostałym czasie")
	assert_true(restored.is_minus())
