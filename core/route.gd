class_name Route
extends RefCounted
## Przebieg — stany i dane wg docs/04-logika-zaleznosci.md §2; przejściami
## steruje Interlocking (warunki §3, zwalnianie sekcyjne, kasowanie).

var id: StringName = &""
## Klasa przebiegu: pociągowy / manewrowy (docs/03 §3).
var is_train: bool = true
var entry_signal: StringName = &""
var exit_signal: StringName = &""
var target: String = ""
var sections: Array[StringName] = []
var turnouts_req: Dictionary = {}       # StringName -> Const.TurnoutPos
var flank_turnouts: Dictionary = {}     # StringName -> Const.TurnoutPos
var flank_signals: Array[StringName] = []
var overlap_sections: Array[StringName] = []
var overlap_turnouts: Dictionary = {}   # StringName -> Const.TurnoutPos
var overlap_release_s: float = 0.0
var has_overlap: bool = false
var conflicts: Array[StringName] = []
var block_id: StringName = &""
var v_route_kmh: int = 0

## Sekcja zbliżania przed semaforem początkowym (wyliczana przez Interlocking).
var approach_section: StringName = &""
## Grupa prędkości drogi do wyboru obrazu (MAX/100/60/40, docs/04 §6).
var v_group: String = "MAX"

# --- Stan dynamiczny ---
var state: Const.RouteState = Const.RouteState.IDLE
## Czy sekcja i była zajęta przez pociąg (zwalnianie sekcyjne §2).
var passed: Array[bool] = []
## Czy sekcja i została już zwolniona z utwierdzenia.
var released: Array[bool] = []
## Pozostały czas ewolucji doraźnego zwolnienia (stan CANCELLED).
var cancel_left_s: float = 0.0
## Pozostały czas zwalniania drogi ochronnej (po przejeździe).
var overlap_left_s: float = 0.0
## Czy trwa odliczanie zwolnienia drogi ochronnej.
var overlap_timer_running: bool = false


static func from_def(def: Dictionary) -> Route:
	var route := Route.new()
	route.id = StringName(String(def["id"]))
	route.is_train = String(def.get("class", "train")) == "train"
	route.entry_signal = StringName(String(def.get("entry_signal", "")))
	var exit_value: Variant = def.get("exit_signal")
	route.exit_signal = StringName(String(exit_value)) if exit_value != null else &""
	route.target = String(def.get("target", ""))
	for section_id: Variant in (def.get("sections", []) as Array):
		route.sections.append(StringName(String(section_id)))
	route.turnouts_req = _positions(def.get("turnouts", {}))
	var flank: Variant = def.get("flank")
	if flank is Dictionary:
		for key: Variant in (flank as Dictionary):
			if String(key) == "signals_at_stop":
				for signal_id: Variant in ((flank as Dictionary)[key] as Array):
					route.flank_signals.append(StringName(String(signal_id)))
			else:
				route.flank_turnouts[StringName(String(key))] = \
					Const.TURNOUT_POS_FROM_STRING[String((flank as Dictionary)[key])]
	var overlap: Variant = def.get("overlap")
	if overlap is Dictionary:
		route.has_overlap = true
		for section_id: Variant in ((overlap as Dictionary).get("sections", []) as Array):
			route.overlap_sections.append(StringName(String(section_id)))
		route.overlap_turnouts = _positions((overlap as Dictionary).get("turnouts", {}))
		route.overlap_release_s = float((overlap as Dictionary).get("release_s", 90.0))
	for conflict_id: Variant in (def.get("conflicts", []) as Array):
		route.conflicts.append(StringName(String(conflict_id)))
	route.block_id = StringName(String(def.get("block", "")))
	route.v_route_kmh = int(def.get("v_route_kmh", 0))
	route.reset_runtime()
	return route


static func _positions(raw: Dictionary) -> Dictionary:
	var result := {}
	for key: Variant in raw:
		result[StringName(String(key))] = Const.TURNOUT_POS_FROM_STRING[String(raw[key])]
	return result


func reset_runtime() -> void:
	state = Const.RouteState.IDLE
	passed.clear()
	released.clear()
	for i: int in sections.size():
		passed.append(false)
		released.append(false)
	cancel_left_s = 0.0
	overlap_left_s = 0.0
	overlap_timer_running = false


## Czy przebieg trzyma elementy w zależnościach (stan ≥ SETTING, docs/04 §3.4).
func is_active() -> bool:
	return state != Const.RouteState.IDLE


## Czy wszystkie sekcje drogi jazdy zwolnione albo pociąg dojechał na
## ostatnią (tor docelowy) — warunek przejścia do zwalniania drogi ochronnej.
func main_path_done(last_section_occupied: bool) -> bool:
	for i: int in sections.size() - 1:
		if not released[i]:
			return false
	var last: int = sections.size() - 1
	return released[last] or (passed[last] and last_section_occupied)


func to_dict() -> Dictionary:
	return {
		"state": state,
		"passed": passed.duplicate(),
		"released": released.duplicate(),
		"cancel_left_s": cancel_left_s,
		"overlap_left_s": overlap_left_s,
		"overlap_timer_running": overlap_timer_running,
	}


func from_dict(data: Dictionary) -> void:
	state = int(data.get("state", Const.RouteState.IDLE)) as Const.RouteState
	passed.assign(data.get("passed", []))
	released.assign(data.get("released", []))
	cancel_left_s = float(data.get("cancel_left_s", 0.0))
	overlap_left_s = float(data.get("overlap_left_s", 0.0))
	overlap_timer_running = bool(data.get("overlap_timer_running", false))
