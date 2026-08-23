extends GutTest
## Testy samouczka (F10): kroki, warunki zaliczenia, zdarzenia dla UI.

var _events: Array[Dictionary] = []


func _tick(world: SimWorld, count: int = 1) -> void:
	for i: int in count:
		world.tick(0.1)
		_events.append_array(world.drain_events())


func _last_step_index() -> int:
	var index := -1
	for event: Dictionary in _events:
		if event["type"] == &"tutorial_step":
			index = int(event["index"])
	return index


func _has_done() -> bool:
	for event: Dictionary in _events:
		if event["type"] == &"tutorial_done":
			return true
	return false


func test_lekcja_komputerowa_od_startu_do_konca() -> void:
	var world := SimWorld.new()
	assert_true(world.load_scenario_file(
		"res://data/scenarios/samouczek-5-komputer.json")["ok"])
	world.rng.seed = 3
	_events.clear()
	_tick(world)
	assert_eq(_last_step_index(), 1, "start lekcji publikuje krok 1")
	# Krok 1: przebieg poleceniem przebiegowym.
	assert_true(world.execute(&"route_set", {"id": "A_t1"}).ok)
	_tick(world)
	assert_eq(_last_step_index(), 2, "utwierdzenie A_t1 zalicza krok 1")
	# Krok 2: Sz na B — polecenie czeka na potwierdzenie.
	world.execute(&"sub_signal", {"id": "B"})
	_tick(world)
	assert_eq(_last_step_index(), 3, "oczekujące potwierdzenie zalicza krok 2")
	# Krok 3: potwierdzenie — B pokazuje Sz.
	assert_true(world.execute(&"command_confirm", {}).ok)
	_tick(world)
	assert_eq(_last_step_index(), 4, "Sz na B zalicza krok 3")
	# Krok 4: cofnięcie przebiegu A.
	assert_true(world.execute(&"signal_cancel", {"id": "A"}).ok)
	_tick(world)
	assert_eq(_last_step_index(), 5, "signal_cancel A zalicza krok 4")
	# Krok 5: odczekanie w kroku (in_step_s = 6 s).
	_tick(world, 70)
	assert_true(_has_done(), "po odczekaniu lekcja ukończona")
	assert_true(world.tutorial.done)


func test_warunek_command_wymaga_wlasciwego_id() -> void:
	var world := SimWorld.new()
	assert_true(world.load_scenario_file(
		"res://data/scenarios/samouczek-1-pulpit.json")["ok"])
	world.rng.seed = 3
	_events.clear()
	_tick(world)
	assert_eq(_last_step_index(), 1)
	# Zła zwrotnica — krok nie przechodzi.
	world.execute(&"turnout_throw", {"id": "z2"})
	_tick(world)
	assert_eq(_last_step_index(), 1, "z2 nie zalicza kroku o z1")
	# Właściwa zwrotnica.
	assert_true(world.execute(&"turnout_throw", {"id": "z1"}).ok)
	_tick(world)
	assert_eq(_last_step_index(), 2, "z1 zalicza krok 1")
	# Krok 2: powrót na plus — po dojściu do MINUS przestaw ponownie.
	_tick(world, 80)
	assert_true(world.execute(&"turnout_throw", {"id": "z1"}).ok)
	_tick(world, 80)
	assert_eq(_last_step_index(), 3, "kontrola w plusie zalicza krok 2")


func test_scenariusz_bez_sekcji_tutorial_bez_samouczka() -> void:
	var world := SimWorld.new()
	assert_true(world.load_scenario_file("res://data/scenarios/borki-poranek.json")["ok"])
	assert_null(world.tutorial)
	_events.clear()
	_tick(world)
	assert_eq(_last_step_index(), -1, "zwykła służba nie publikuje kroków")
