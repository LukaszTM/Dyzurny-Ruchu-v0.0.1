extends GutTest
## Testy stanu gry (autoload/game_state.gd): determinizm RNG z seedem
## i roundtrip snapshotu save/load. Uzywa autoloadow (GameState, SimClock).


func before_each() -> void:
	GameState.new_game("test", 12345)


func test_new_game_applies_seed() -> void:
	assert_eq(GameState.rng_seed, 12345)
	assert_eq(GameState.scenario_id, "test")
	assert_eq(SimClock.tick_count, 0, "new_game resetuje zegar symulacji")


func test_same_seed_gives_same_sequence() -> void:
	var first: Array[int] = []
	for i: int in range(5):
		first.append(GameState.rng.randi())
	GameState.new_game("test", 12345)
	for i: int in range(5):
		assert_eq(GameState.rng.randi(), first[i], "ten sam seed = ta sama sekwencja")


func test_time_of_day_uses_scenario_start() -> void:
	GameState.new_game("test", 1, 6 * 3600)
	SimClock.advance_real_time(2.0)
	assert_almost_eq(GameState.time_of_day_s(), 6.0 * 3600.0 + 2.0, 0.0001)


# Przypadek brzegowy 1: roundtrip save/load przywraca seed, stan RNG i zegar.
func test_to_dict_from_dict_roundtrip() -> void:
	SimClock.advance_real_time(3.7)
	GameState.rng.randi()
	var ticks_at_snapshot: int = SimClock.tick_count
	var snapshot: Dictionary = GameState.to_dict()
	var expected_next: int = GameState.rng.randi()
	GameState.new_game("inny", 999)
	GameState.from_dict(snapshot)
	assert_eq(GameState.rng_seed, 12345)
	assert_eq(GameState.scenario_id, "test")
	assert_eq(GameState.rng.randi(), expected_next, "stan RNG odtworzony z zapisu")
	assert_eq(SimClock.tick_count, ticks_at_snapshot, "zegar odtworzony z zapisu")


# Przypadek brzegowy 2: seed 0 oznacza losowy seed, ale zapamietany do save.
func test_zero_seed_randomizes_but_records() -> void:
	GameState.new_game("test", 0)
	assert_ne(GameState.rng_seed, 0, "wylosowany seed zapamietany")
	var first: int = GameState.rng.randi()
	GameState.new_game("test", GameState.rng_seed)
	assert_eq(GameState.rng.randi(), first, "seed z save odtwarza sekwencje")
