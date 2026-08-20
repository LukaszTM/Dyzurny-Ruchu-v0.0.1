extends GutTest
## Testy szkieletu rdzenia (core/sim_world.gd) — czysta klasa RefCounted,
## uruchamiana headless bez drzewa scen (CLAUDE.md, zasada 3).


func test_tick_advances_time_and_count() -> void:
	var world := SimWorld.new()
	for i: int in range(25):
		world.tick(0.1)
	assert_eq(world.tick_count, 25)
	assert_almost_eq(world.sim_time, 2.5, 0.0001)


func test_new_world_starts_at_zero() -> void:
	var world := SimWorld.new()
	assert_eq(world.tick_count, 0)
	assert_almost_eq(world.sim_time, 0.0, 0.0001)


# Przypadek brzegowy 1: roundtrip snapshotu stanu (save/load).
func test_to_dict_from_dict_roundtrip() -> void:
	var world := SimWorld.new()
	for i: int in range(7):
		world.tick(0.1)
	var restored := SimWorld.new()
	restored.from_dict(world.to_dict())
	assert_eq(restored.tick_count, 7)
	assert_almost_eq(restored.sim_time, 0.7, 0.0001)


# Przypadek brzegowy 2: from_dict z niekompletnym slownikiem uzywa wartosci domyslnych.
func test_from_dict_with_missing_keys_uses_defaults() -> void:
	var world := SimWorld.new()
	world.tick(0.1)
	world.from_dict({})
	assert_eq(world.tick_count, 0)
	assert_almost_eq(world.sim_time, 0.0, 0.0001)
