class_name EventDirector
extends RefCounted
## Reżyser zdarzeń scenariusza (docs/05 §6): zdarzenia zaplanowane („at")
## i losowane w oknach czasowych („random" + p). Każde zdarzenie ma skutek
## w rdzeniu (wykonuje SimWorld) i oczekiwaną procedurę gracza (scoring).
## Losowość wyłącznie z przekazanego RNG (determinizm — CLAUDE.md zasada 5).


## Jedno zdarzenie scenariusza.
class Entry:
	extends RefCounted
	var type: String = ""
	var target: String = ""
	var fire_at_s: float = -1.0     # -1 = jeszcze nie wylosowane / wyłączone
	var window_start_s: float = -1.0
	var window_end_s: float = -1.0
	var probability: float = 1.0
	var is_random: bool = false
	var rolled: bool = false
	var fired: bool = false
	var repair_min: float = 0.0
	var payload: Dictionary = {}

var entries: Array[Entry] = []
## Zaplanowane naprawy: {at_s, kind, target}.
var _repairs: Array[Dictionary] = []


static func from_scenario(scenario: Dictionary) -> EventDirector:
	var director := EventDirector.new()
	for item: Variant in (scenario.get("events", []) as Array):
		var def: Dictionary = item
		var entry := Entry.new()
		entry.type = String(def.get("type", ""))
		entry.target = String(def.get("target", ""))
		entry.repair_min = float(def.get("repair_min", 0.0))
		entry.payload = def.get("payload", {})
		var at := String(def.get("at", ""))
		if at == "random":
			entry.is_random = true
			var window: Array = def.get("window", [])
			if window.size() == 2:
				entry.window_start_s = float(Timetable.parse_time_of_day(String(window[0])))
				entry.window_end_s = float(Timetable.parse_time_of_day(String(window[1])))
			entry.probability = float(def.get("p", 1.0))
		else:
			entry.fire_at_s = float(Timetable.parse_time_of_day(at))
		director.entries.append(entry)
	return director


## Krok reżysera. Zwraca akcje do wykonania przez SimWorld:
## {kind: "fire", type, target, payload} | {kind: "repair", type, target}.
func tick(now_s: float, rng: RandomNumberGenerator) -> Array[Dictionary]:
	var actions: Array[Dictionary] = []
	for entry: Entry in entries:
		if entry.fired:
			continue
		# Zdarzenie losowe: rzut w chwili otwarcia okna (deterministyczny
		# przy stałym seedzie); przy sukcesie losowanie chwili w oknie.
		if entry.is_random and not entry.rolled and now_s >= entry.window_start_s:
			entry.rolled = true
			if rng.randf() < entry.probability:
				entry.fire_at_s = rng.randf_range(
					maxf(now_s, entry.window_start_s), entry.window_end_s
				)
		if entry.fire_at_s >= 0.0 and now_s >= entry.fire_at_s:
			entry.fired = true
			actions.append({
				"kind": "fire", "type": entry.type, "target": entry.target,
				"payload": entry.payload,
			})
			if entry.repair_min > 0.0:
				_repairs.append({
					"at_s": now_s + entry.repair_min * 60.0,
					"kind": "repair", "type": entry.type, "target": entry.target,
				})
	var still: Array[Dictionary] = []
	for repair: Dictionary in _repairs:
		if now_s >= float(repair["at_s"]):
			actions.append({
				"kind": "repair", "type": String(repair["type"]),
				"target": String(repair["target"]), "payload": {},
			})
		else:
			still.append(repair)
	_repairs = still
	return actions


func to_dict() -> Dictionary:
	var states: Array[Dictionary] = []
	for entry: Entry in entries:
		states.append({
			"fired": entry.fired, "rolled": entry.rolled, "fire_at_s": entry.fire_at_s,
		})
	return {"entries": states, "repairs": _repairs.duplicate(true)}


func from_dict(data: Dictionary) -> void:
	var states: Array = data.get("entries", [])
	for i: int in mini(states.size(), entries.size()):
		var state: Dictionary = states[i]
		entries[i].fired = bool(state.get("fired", false))
		entries[i].rolled = bool(state.get("rolled", false))
		entries[i].fire_at_s = float(state.get("fire_at_s", -1.0))
	_repairs.assign(data.get("repairs", []))
