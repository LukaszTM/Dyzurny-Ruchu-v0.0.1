extends GutTest
## Test regresyjny danych: KAŻDY scenariusz z data/scenarios wczytuje się
## bez błędów i przechodzi 50 ticków symulacji (walidacja stacji, rozkładu,
## zdarzeń i samouczków — dane, nie kod, CLAUDE.md zasada 4).

const SCENARIOS_DIR := "res://data/scenarios"


func test_wszystkie_scenariusze_wczytuja_sie_i_tykaja() -> void:
	var dir := DirAccess.open(SCENARIOS_DIR)
	assert_not_null(dir, "katalog scenariuszy istnieje")
	var checked := 0
	for file_name: String in dir.get_files():
		if not file_name.ends_with(".json"):
			continue
		var world := SimWorld.new()
		var result := world.load_scenario_file("%s/%s" % [SCENARIOS_DIR, file_name])
		assert_true(result["ok"], "%s: %s" % [file_name, result["errors"]])
		if not result["ok"]:
			continue
		world.rng.seed = 1
		for i: int in 50:
			world.tick(0.1)
			world.drain_events()
		checked += 1
	assert_gte(checked, 15, "w repo jest co najmniej 15 scenariuszy")


func test_scenariusze_maja_nazwy_i_opisy() -> void:
	var dir := DirAccess.open(SCENARIOS_DIR)
	for file_name: String in dir.get_files():
		if not file_name.ends_with(".json"):
			continue
		var parsed: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(
			"%s/%s" % [SCENARIOS_DIR, file_name]))
		var meta: Dictionary = parsed.get("meta", {})
		assert_false(String(meta.get("name", "")).is_empty(),
			"%s: brak meta.name" % file_name)
		assert_false(String(meta.get("description", "")).is_empty(),
			"%s: brak meta.description" % file_name)
