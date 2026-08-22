class_name Dsat
extends RefCounted
## Urządzenie detekcji stanów awaryjnych taboru (docs/systemy/17):
## punkt na krawędzi szlaku; przy przejeździe pociągu publikuje raport.
## Alarmy uzbraja EventDirector (zdarzenie dsat_alarm z payload) —
## losowość wyłącznie przez RNG scenariusza.

var id: StringName = &""
var on_edge: StringName = &""
var types: Array[String] = []
## Uzbrojony alarm dla następnego pociągu: {"code", "level", "axle"}.
var armed: Dictionary = {}
## Pociągi już zmierzone (nr -> true).
var _measured: Dictionary = {}


static func from_def(def: Dictionary) -> Dsat:
	var device := Dsat.new()
	device.id = StringName(String(def.get("id", "")))
	device.on_edge = StringName(String(def.get("on_edge", "")))
	for type_name: Variant in (def.get("types", []) as Array):
		device.types.append(String(type_name))
	return device


## Sprawdza przejazd pociągu przez czujnik. Zwraca raport ({} = brak):
## {train, code, level, axle} — "OK" gdy bez usterek (docs/17 §2).
func check_train(train: Train, graph: TrackGraph) -> Dictionary:
	if _measured.has(train.nr):
		return {}
	var section := graph.section_for_edge(on_edge)
	if section == null or not train.covered_sections().has(section.id):
		return {}
	_measured[train.nr] = true
	if armed.is_empty():
		return {"train": train.nr, "code": "OK", "level": "OK", "axle": 0}
	var report := {
		"train": train.nr,
		"code": String(armed.get("code", "GM")),
		"level": String(armed.get("level", "ALARM")),
		"axle": int(armed.get("axle", 1)),
	}
	armed = {}
	return report


func to_dict() -> Dictionary:
	return {"armed": armed.duplicate(true), "measured": _measured.keys()}


func from_dict(data: Dictionary) -> void:
	armed = (data.get("armed", {}) as Dictionary).duplicate(true)
	_measured.clear()
	for nr: Variant in (data.get("measured", []) as Array):
		_measured[String(nr)] = true
