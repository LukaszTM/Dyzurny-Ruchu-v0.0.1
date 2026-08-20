extends Node
## Bieżący scenariusz, punktacja, save/load — szkielet Fazy 0.
## Determinizm wg CLAUDE.md (zasada 5): jedyny RandomNumberGenerator w grze,
## seed zapisywany w save. Pełne wczytywanie scenariuszy dojdzie w F1+.

## Emitowany po rozpoczęciu nowego scenariusza.
signal scenario_started(scenario_id: String)

## Godzina startu scenariusza jako sekundy doby (domyślnie 05:40,
## jak w data/scenariusz-przyklad.json).
const DEFAULT_START_OF_DAY_S: int = 5 * 3600 + 40 * 60

## Jedyne źródło losowości w symulacji.
var rng: RandomNumberGenerator = RandomNumberGenerator.new()
## Seed bieżącej rozgrywki (do save/load).
var rng_seed: int = 0
## Identyfikator bieżącego scenariusza ("" = brak).
var scenario_id: String = ""
## Sekundy doby, o której zaczyna się scenariusz.
var start_of_day_s: int = DEFAULT_START_OF_DAY_S
## Punktacja (scoring v1 dojdzie w F5).
var score: int = 0


## Rozpoczyna nowy scenariusz. seed_value = 0 → wylosuj seed i zapamiętaj.
func new_game(p_scenario_id: String = "", seed_value: int = 0,
		p_start_of_day_s: int = DEFAULT_START_OF_DAY_S) -> void:
	scenario_id = p_scenario_id
	start_of_day_s = p_start_of_day_s
	score = 0
	if seed_value == 0:
		rng.randomize()
		rng_seed = int(rng.seed)
	else:
		rng_seed = seed_value
	rng.seed = rng_seed
	SimClock.reset()
	scenario_started.emit(scenario_id)


## Bieżąca godzina w symulacji jako sekundy doby (start + czas symulacji).
func time_of_day_s() -> float:
	return float(start_of_day_s) + SimClock.sim_time


## Snapshot stanu do zapisu gry (rozbudowywany w kolejnych fazach).
func to_dict() -> Dictionary:
	return {
		"scenario_id": scenario_id,
		"rng_seed": rng_seed,
		"rng_state": rng.state,
		"start_of_day_s": start_of_day_s,
		"score": score,
		"sim_time": SimClock.sim_time,
		"tick_count": SimClock.tick_count,
	}


## Odtworzenie stanu z zapisu gry.
func from_dict(data: Dictionary) -> void:
	scenario_id = str(data.get("scenario_id", ""))
	rng_seed = int(data.get("rng_seed", 0))
	rng.seed = rng_seed
	rng.state = int(data.get("rng_state", rng.state))
	start_of_day_s = int(data.get("start_of_day_s", DEFAULT_START_OF_DAY_S))
	score = int(data.get("score", 0))
	SimClock.sim_time = float(data.get("sim_time", 0.0))
	SimClock.tick_count = int(data.get("tick_count", 0))
