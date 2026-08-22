extends GutTest
## Testy F10: pełny save/load (serializacja pociągów w drodze, determinizm
## po wczytaniu) i generator ruchu trybu swobodnego.

const SCENARIO_PATH := "res://data/scenarios/brzeziny-szczyt.json"


func _new_world(seed_value: int = 21) -> SimWorld:
	var world := SimWorld.new()
	assert_true(world.load_scenario_file(SCENARIO_PATH)["ok"])
	world.rng.seed = seed_value
	return world


func _entry(nr: String) -> Timetable.Entry:
	var entry := Timetable.Entry.new()
	entry.nr = nr
	entry.kind = "osobowy"
	entry.from_station = "Sosnów"
	entry.to_station = "Dęby"
	entry.len_m = 120.0
	entry.vmax_kmh = 100
	entry.power_class = "EZT"
	entry.stop = false
	return entry


func _generator_scenario(seed_gap: bool = false) -> Dictionary:
	return {
		"meta": {"id": "gen-test", "station": "brzeziny"},
		"start_time": "08:00",
		"duration_min": 0,
		"timetable": [],
		"generator": {
			"enabled": true,
			"gap_min_s": 120.0 if not seed_gap else 120.0,
			"gap_max_s": 240.0,
			"relations": [
				{"from": "Sosnów", "to": "Dęby", "tracks": ["t1"]},
				{"from": "Dęby", "to": "Sosnów", "tracks": ["t2"]},
			],
			"kinds": [
				{"kind": "osobowy", "weight": 3, "len_m": 120, "vmax_kmh": 100,
					"power_class": "EZT", "stop_chance": 0.5, "nr_base": 90000},
				{"kind": "towarowy", "weight": 1, "len_m": 400, "vmax_kmh": 70,
					"power_class": "lok_el", "stop_chance": 0.0, "nr_base": 645000},
			],
		},
	}


# --- Pełny save/load ---------------------------------------------------------

func test_snapshot_odtwarza_pociag_w_drodze() -> void:
	var world := _new_world()
	var train := world.spawn_train(_entry("50001"))
	for i: int in 600:
		world.tick(0.1)
	assert_gt(train.front_m, 100.0, "pociąg w drodze")
	var snapshot := world.to_dict()
	# JSON round-trip jak przy prawdziwym zapisie na dysk.
	var parsed: Dictionary = JSON.parse_string(JSON.stringify(snapshot))
	var loaded := _new_world()
	loaded.spawn_train(_entry("50001"))  # pociąg zostanie nadpisany snapshotem
	loaded.from_dict(parsed)
	assert_eq(loaded.trains.size(), 1)
	var restored: Train = loaded.trains[0]
	assert_eq(restored.nr, "50001")
	assert_almost_eq(restored.front_m, train.front_m, 0.001,
		"pozycja czoła odtworzona")
	assert_almost_eq(restored.v_ms, train.v_ms, 0.001, "prędkość odtworzona")
	assert_eq(restored.covered_sections().keys(), train.covered_sections().keys(),
		"zajmowane sekcje identyczne")


func test_determinizm_po_wczytaniu() -> void:
	var world := _new_world()
	world.spawn_train(_entry("50002"))
	world.execute(&"route_start", {"id": "A_t1"})
	for i: int in 400:
		world.tick(0.1)
		world.drain_events()
	var snapshot: Dictionary = JSON.parse_string(JSON.stringify(world.to_dict()))
	var loaded := _new_world(99)  # inny seed — snapshot musi go nadpisać
	loaded.from_dict(snapshot)
	# Oba światy tykają dalej — muszą zostać identyczne (determinizm).
	for i: int in 400:
		world.tick(0.1)
		loaded.tick(0.1)
		world.drain_events()
		loaded.drain_events()
	assert_eq(loaded.trains.size(), world.trains.size())
	if not world.trains.is_empty() and not loaded.trains.is_empty():
		assert_almost_eq((loaded.trains[0] as Train).front_m,
			(world.trains[0] as Train).front_m, 0.0001,
			"po wczytaniu symulacja biegnie identycznie")
	assert_eq(loaded.rng.state, world.rng.state, "stan RNG zsynchronizowany")


func test_zapis_na_dysk_przez_game_state() -> void:
	var world := _new_world()
	world.spawn_train(_entry("50003"))
	for i: int in 300:
		world.tick(0.1)
	GameState.new_game("gut-test-save", 7, world.start_of_day_s)
	world.rng = GameState.rng
	assert_true(GameState.save_game(world), "zapis na dysk się udał")
	assert_true(GameState.has_save("gut-test-save"))
	var front_before: float = (world.trains[0] as Train).front_m
	for i: int in 300:
		world.tick(0.1)
	assert_gt((world.trains[0] as Train).front_m, front_before)
	assert_true(GameState.load_game(world), "wczytanie z dysku")
	assert_almost_eq((world.trains[0] as Train).front_m, front_before, 0.001,
		"stan cofnięty do chwili zapisu")
	DirAccess.remove_absolute(GameState.save_path("gut-test-save"))


func test_stary_snapshot_bez_pol_f10_dziala() -> void:
	var world := _new_world()
	var legacy := {"sim_time": 5.0, "tick_count": 50}
	world.from_dict(legacy)
	assert_eq(world.sim_time, 5.0, "zgodność wstecz: brak pól F10 nie wysypuje")


# --- Generator ruchu -----------------------------------------------------------

func test_generator_doklada_pociagi_do_rozkladu() -> void:
	var world := SimWorld.new()
	assert_true(world.apply_scenario(_generator_scenario())["ok"])
	world.rng.seed = 5
	var added := 0
	for i: int in 12000:
		world.tick(0.1)
		for event: Dictionary in world.drain_events():
			if event["type"] == &"timetable_add":
				added += 1
	assert_gt(added, 1, "generator dokłada kolejne pociągi")
	assert_eq(world.timetable.entries.size(), added, "wpisy trafiają do rozkładu")
	var entry: Timetable.Entry = world.timetable.entries[0]
	assert_true(entry.from_station == "Sosnów" or entry.from_station == "Dęby")
	assert_true(world.trains.size() > 0 or entry.spawned,
		"wygenerowany pociąg wszedł do świata przez zapowiadanie sąsiada")


func test_generator_deterministyczny() -> void:
	var world_a := SimWorld.new()
	var world_b := SimWorld.new()
	assert_true(world_a.apply_scenario(_generator_scenario())["ok"])
	assert_true(world_b.apply_scenario(_generator_scenario())["ok"])
	world_a.rng.seed = 33
	world_b.rng.seed = 33
	for i: int in 6000:
		world_a.tick(0.1)
		world_b.tick(0.1)
		world_a.drain_events()
		world_b.drain_events()
	assert_gt(world_a.timetable.entries.size(), 0)
	assert_eq(world_a.timetable.entries.size(), world_b.timetable.entries.size())
	for i: int in world_a.timetable.entries.size():
		assert_eq((world_a.timetable.entries[i] as Timetable.Entry).nr,
			(world_b.timetable.entries[i] as Timetable.Entry).nr,
			"ten sam seed → te same pociągi")


func test_generator_wylaczony_bez_konfiguracji() -> void:
	var world := SimWorld.new()
	assert_true(world.load_scenario_file(SCENARIO_PATH)["ok"])
	assert_false(world.traffic_gen.enabled,
		"scenariusz bez sekcji generator nie generuje ruchu")
