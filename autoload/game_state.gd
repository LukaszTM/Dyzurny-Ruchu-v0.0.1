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
## Punktacja: start 100, kary odejmowane (scoring v1, docs/05 §7).
var score: int = 100
## Rejestr kar {points, reason} — do podsumowania zmiany.
var penalties: Array[Dictionary] = []


## Rozpoczyna nowy scenariusz. seed_value = 0 → wylosuj seed i zapamiętaj.
func new_game(p_scenario_id: String = "", seed_value: int = 0,
		p_start_of_day_s: int = DEFAULT_START_OF_DAY_S) -> void:
	scenario_id = p_scenario_id
	start_of_day_s = p_start_of_day_s
	score = 100
	penalties.clear()
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


## Kara scoringu (docs/05 §7) — rejestrowana z powodem do podsumowania.
func add_penalty(points: int, reason: String) -> void:
	score = maxi(0, score - points)
	penalties.append({"points": points, "reason": reason})


## Snapshot stanu do zapisu gry (RNG jako tekst — uint64 nie mieści się
## w liczbie JSON bez utraty precyzji).
func to_dict() -> Dictionary:
	return {
		"scenario_id": scenario_id,
		"rng_seed": str(rng_seed),
		"rng_state": str(rng.state),
		"start_of_day_s": start_of_day_s,
		"score": score,
		"penalties": penalties.duplicate(true),
		"sim_time": SimClock.sim_time,
		"tick_count": SimClock.tick_count,
	}


## Odtworzenie stanu z zapisu gry.
func from_dict(data: Dictionary) -> void:
	scenario_id = str(data.get("scenario_id", ""))
	rng_seed = String(str(data.get("rng_seed", "0"))).to_int()
	rng.seed = rng_seed
	rng.state = String(str(data.get("rng_state", str(rng.state)))).to_int()
	start_of_day_s = int(data.get("start_of_day_s", DEFAULT_START_OF_DAY_S))
	score = int(data.get("score", 100))
	penalties.assign(data.get("penalties", []))
	SimClock.sim_time = float(data.get("sim_time", 0.0))
	SimClock.tick_count = int(data.get("tick_count", 0))


# ---------------------------------------------------------------------------
# Ustawienia gracza (F10) — user://settings.json, stosowane przy starcie
# ---------------------------------------------------------------------------

const SETTINGS_PATH := "user://settings.json"

## Ustawienia: głośność (0–1); kolejne klucze dojdą wraz z opcjami.
var settings: Dictionary = {"volume": 1.0}


func _ready() -> void:
	load_settings()
	apply_settings()


func set_setting(key: String, value: Variant) -> void:
	settings[key] = value
	apply_settings()
	save_settings()


func apply_settings() -> void:
	var volume := clampf(float(settings.get("volume", 1.0)), 0.0, 1.0)
	AudioServer.set_bus_volume_db(0, linear_to_db(maxf(volume, 0.001)))
	AudioServer.set_bus_mute(0, volume <= 0.0)


func save_settings() -> void:
	var file := FileAccess.open(SETTINGS_PATH, FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify(settings))
		file.close()


func load_settings() -> void:
	if not FileAccess.file_exists(SETTINGS_PATH):
		return
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(SETTINGS_PATH))
	if parsed is Dictionary:
		settings.merge(parsed as Dictionary, true)


# ---------------------------------------------------------------------------
# Zapis/odczyt na dysk (F10) — user://saves/<scenariusz>.json
# ---------------------------------------------------------------------------

const SAVES_DIR := "user://saves"
const SAVE_VERSION: int = 1


func save_path(p_scenario_id: String = "") -> String:
	var id := p_scenario_id if not p_scenario_id.is_empty() else scenario_id
	return "%s/%s.json" % [SAVES_DIR, id]


func has_save(p_scenario_id: String) -> bool:
	return FileAccess.file_exists(save_path(p_scenario_id))


## Zapis pełnego stanu gry (stan gracza + snapshot rdzenia) na dysk.
func save_game(world: SimWorld) -> bool:
	DirAccess.make_dir_recursive_absolute(SAVES_DIR)
	var file := FileAccess.open(save_path(), FileAccess.WRITE)
	if file == null:
		push_error("GameState: nie można zapisać %s" % save_path())
		return false
	file.store_string(JSON.stringify({
		"version": SAVE_VERSION,
		"game": to_dict(),
		"world": world.to_dict(),
	}, "", false))
	file.close()
	return true


## Wczytanie zapisu do działającego świata (scenariusz musi być ten sam —
## stację i rozkład buduje load_scenario_file, snapshot nakłada stan).
func load_game(world: SimWorld) -> bool:
	if not FileAccess.file_exists(save_path()):
		return false
	var parsed: Variant = JSON.parse_string(
		FileAccess.get_file_as_string(save_path())
	)
	if parsed == null or not (parsed is Dictionary):
		push_error("GameState: uszkodzony zapis %s" % save_path())
		return false
	var data: Dictionary = parsed
	from_dict(data.get("game", {}))
	world.from_dict(data.get("world", {}))
	world.rng = rng
	return true
