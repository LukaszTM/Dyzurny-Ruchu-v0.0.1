class_name Section
extends RefCounted
## Odcinek izolowany — kontrola zajętości (docs/04-logika-zaleznosci.md §2,
## format danych: docs/03-model-danych.md §1).
## Stany: FREE / OCCUPIED + flaga utwierdzenia `locked_by` (id przebiegu, F3).

var id: StringName = &""
var type: Const.SectionType = Const.SectionType.TRACK
## Krawędzie grafu wchodzące w skład odcinka (pusta lista dozwolona dla
## odcinków zwrotnicowych opisanych przez `turnout_id` + `len_m`).
var edge_ids: Array[StringName] = []
## Zwrotnica leżąca w odcinku — tylko dla type == TURNOUT.
var turnout_id: StringName = &""
var len_m: float = 0.0

## Zajętość fizyczna (oś taboru na odcinku).
var occupied: bool = false
## Id przebiegu, który utwierdził odcinek (&"" = nieutwierdzony). Pełna
## obsługa w F3 (interlocking); w F1 pole jest respektowane przy zwrotnicach.
var locked_by: StringName = &""


func is_free() -> bool:
	return not occupied


func is_locked() -> bool:
	return locked_by != &""


## Snapshot stanu dynamicznego (konfiguracja pochodzi z pliku stacji).
func to_dict() -> Dictionary:
	return {
		"occupied": occupied,
		"locked_by": String(locked_by),
	}


func from_dict(data: Dictionary) -> void:
	occupied = bool(data.get("occupied", false))
	locked_by = StringName(String(data.get("locked_by", "")))
