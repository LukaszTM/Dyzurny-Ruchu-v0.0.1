extends GutTest
## Testy reżysera zdarzeń (docs/05 §6): zdarzenia planowe, losowe w oknach,
## naprawy po czasie. Losowość deterministyczna (seedowany RNG).


func _director(events: Array) -> EventDirector:
	return EventDirector.from_scenario({"events": events})


func _rng(seed_value: int = 1234) -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	return rng


func test_zdarzenie_planowe_odpala_o_czasie() -> void:
	var director := _director([
		{"at": "06:20", "type": "turnout_no_control", "target": "z2", "repair_min": 25},
	])
	var rng := _rng()
	assert_eq(director.tick(6.0 * 3600.0 + 19.0 * 60.0, rng).size(), 0, "przed czasem cisza")
	var actions := director.tick(6.0 * 3600.0 + 20.0 * 60.0, rng)
	assert_eq(actions.size(), 1)
	assert_eq(String(actions[0]["kind"]), "fire")
	assert_eq(String(actions[0]["target"]), "z2")
	assert_eq(director.tick(6.0 * 3600.0 + 20.0 * 60.0 + 1.0, rng).size(), 0,
		"zdarzenie odpala dokładnie raz (przypadek brzegowy)")


func test_naprawa_po_czasie() -> void:
	var director := _director([
		{"at": "06:00", "type": "turnout_no_control", "target": "z2", "repair_min": 2},
	])
	var rng := _rng()
	director.tick(6.0 * 3600.0, rng)
	assert_eq(director.tick(6.0 * 3600.0 + 100.0, rng).size(), 0, "naprawa jeszcze trwa")
	var actions := director.tick(6.0 * 3600.0 + 121.0, rng)
	assert_eq(actions.size(), 1)
	assert_eq(String(actions[0]["kind"]), "repair")


func test_zdarzenie_losowe_p1_odpala_w_oknie() -> void:
	var director := _director([
		{"at": "random", "window": ["06:00", "06:10"], "p": 1.0,
		 "type": "block_failure", "target": "blk_e"},
	])
	var rng := _rng()
	var fired := false
	var t := 6.0 * 3600.0
	while t <= 6.0 * 3600.0 + 601.0:
		if not director.tick(t, rng).is_empty():
			fired = true
			break
		t += 1.0
	assert_true(fired, "p=1.0 musi odpalić w oknie")
	assert_between(t, 6.0 * 3600.0, 6.0 * 3600.0 + 601.0)


func test_zdarzenie_losowe_p0_nie_odpala() -> void:
	var director := _director([
		{"at": "random", "window": ["06:00", "06:10"], "p": 0.0,
		 "type": "block_failure", "target": "blk_e"},
	])
	var rng := _rng()
	var t := 6.0 * 3600.0
	while t <= 6.0 * 3600.0 + 700.0:
		assert_eq(director.tick(t, rng).size(), 0)
		t += 60.0
