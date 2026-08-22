class_name Timetable
extends RefCounted
## Rozkład jazdy scenariusza (docs/03-model-danych.md §6, docs/05 §3).
## Pilnuje kolejności pojawiania się pociągów w świecie.

## Ile sekund przed planowym przyjazdem pociąg pojawia się na szlaku.
## Uproszczenie F4: stała; docelowo (F5) wejście sprzężone z zapowiedzią
## sąsiada i blokadą (docs/05 §3).
const SPAWN_LEAD_S: float = 90.0


## Jeden pociąg rozkładu.
class Entry:
	extends RefCounted
	var nr: String = ""
	var kind: String = "osobowy"
	var from_station: String = ""
	var to_station: String = ""
	var arr_s: int = 0
	var dep_s: int = 0
	var track: String = ""
	var stop: bool = true
	var len_m: float = 100.0
	var vmax_kmh: int = 100
	var mass_t: float = 100.0
	var power_class: String = "EZT"
	var spawned: bool = false

var entries: Array[Entry] = []


static func from_scenario(scenario: Dictionary) -> Timetable:
	var timetable := Timetable.new()
	for item: Variant in (scenario.get("timetable", []) as Array):
		var def: Dictionary = item
		var entry := Entry.new()
		entry.nr = String(def.get("nr", "?"))
		entry.kind = String(def.get("kind", "osobowy"))
		entry.from_station = String(def.get("from", ""))
		entry.to_station = String(def.get("to", ""))
		entry.arr_s = parse_time_of_day(String(def.get("arr", "00:00")))
		entry.dep_s = parse_time_of_day(String(def.get("dep", def.get("arr", "00:00"))))
		entry.track = String(def.get("track", ""))
		entry.stop = bool(def.get("stop", true))
		entry.len_m = float(def.get("len_m", 100.0))
		entry.vmax_kmh = int(def.get("vmax_kmh", 100))
		entry.mass_t = float(def.get("mass_t", 100.0))
		entry.power_class = String(def.get("power_class", "EZT"))
		timetable.entries.append(entry)
	return timetable


## "HH:MM" lub "HH:MM:SS" → sekundy doby.
static func parse_time_of_day(text: String) -> int:
	var parts := text.split(":")
	var h := int(parts[0]) if parts.size() > 0 else 0
	var m := int(parts[1]) if parts.size() > 1 else 0
	var s := int(parts[2]) if parts.size() > 2 else 0
	return h * 3600 + m * 60 + s


## Wpisy, którym pora pojawić się w świecie (i jeszcze się nie pojawiły).
func due_entries(time_of_day_s: float) -> Array[Entry]:
	var due: Array[Entry] = []
	for entry: Entry in entries:
		if not entry.spawned and time_of_day_s >= float(entry.arr_s) - SPAWN_LEAD_S:
			due.append(entry)
	return due


## Wpis po numerze pociągu (null = brak).
func entry_by_nr(nr: String) -> Entry:
	for entry: Entry in entries:
		if entry.nr == nr:
			return entry
	return null


## Pełna serializacja wpisów — rozkład bywa uzupełniany w locie przez
## generator ruchu (tryb swobodny), więc sam plik scenariusza nie wystarcza.
func to_dict() -> Dictionary:
	var list: Array = []
	for entry: Entry in entries:
		list.append({
			"nr": entry.nr, "kind": entry.kind,
			"from": entry.from_station, "to": entry.to_station,
			"arr_s": entry.arr_s, "dep_s": entry.dep_s,
			"track": entry.track, "stop": entry.stop,
			"len_m": entry.len_m, "vmax_kmh": entry.vmax_kmh,
			"mass_t": entry.mass_t, "power_class": entry.power_class,
			"spawned": entry.spawned,
		})
	return {"entries": list}


func from_dict(data: Dictionary) -> void:
	if not data.has("entries"):
		# Zgodność ze snapshotem sprzed F10 (tylko flagi spawned).
		var spawned: Array = data.get("spawned", [])
		for entry: Entry in entries:
			entry.spawned = spawned.has(entry.nr)
		return
	entries.clear()
	for item: Variant in (data["entries"] as Array):
		var def: Dictionary = item
		var entry := Entry.new()
		entry.nr = String(def["nr"])
		entry.kind = String(def["kind"])
		entry.from_station = String(def["from"])
		entry.to_station = String(def["to"])
		entry.arr_s = int(def["arr_s"])
		entry.dep_s = int(def["dep_s"])
		entry.track = String(def["track"])
		entry.stop = bool(def["stop"])
		entry.len_m = float(def["len_m"])
		entry.vmax_kmh = int(def["vmax_kmh"])
		entry.mass_t = float(def["mass_t"])
		entry.power_class = String(def["power_class"])
		entry.spawned = bool(def["spawned"])
		entries.append(entry)
