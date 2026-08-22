class_name LevelCrossing
extends RefCounted
## Przejazd kolejowo-drogowy (docs/systemy/16): kat. A (rogatki obsługiwane
## poleceniami gracza) albo ssp kat. B/C (samoczynna sygnalizacja uruchamiana
## najazdem na sekcje). Stan FAILURE ustawia EventDirector.

enum State { OPEN, CLOSING, CLOSED, OPENING, FAILURE }

const STATE_NAMES: Array[String] = ["OTWARTY", "ZAMYKANIE", "ZAMKNIĘTY", "OTWIERANIE", "AWARIA"]

var id: StringName = &""
## "kat_A_rogatki" | "ssp_B" | "ssp_C" (docs/03 §4, systemy/16 §1).
var type: String = "kat_A_rogatki"
var state: State = State.OPEN
var close_time_s: float = 25.0
## Sekcje osłaniane/najazdowe (docs/03 §4: on_sections).
var on_sections: Array[StringName] = []
var _move_left_s: float = 0.0
## Stan sprzed awarii (do przywrócenia po naprawie).
var _state_before_failure: State = State.OPEN


static func from_def(def: Dictionary) -> LevelCrossing:
	var crossing := LevelCrossing.new()
	crossing.id = StringName(String(def.get("id", "")))
	crossing.type = String(def.get("type", "kat_A_rogatki"))
	crossing.close_time_s = float(def.get("close_time_s", 25.0))
	for section_id: Variant in (def.get("on_sections", []) as Array):
		crossing.on_sections.append(StringName(String(section_id)))
	return crossing


func is_automatic() -> bool:
	return type != "kat_A_rogatki"


func is_closed() -> bool:
	return state == State.CLOSED


## Czy pociąg przed tym przejazdem musi zwolnić do 20 km/h (docs/16 §4:
## awaria ssp lub otwarte rogatki kat. A).
## TODO(weryfikacja): reżim prędkości przy niesprawnym przejeździe.
func requires_caution() -> bool:
	if state == State.FAILURE:
		return true
	return not is_automatic() and state != State.CLOSED


## Polecenie gracza: zamknięcie rogatek (kat. A).
func command_close() -> CommandResult:
	if is_automatic():
		return CommandResult.failure("przejazd %s jest samoczynny (ssp)" % id)
	if state == State.FAILURE:
		return CommandResult.failure("przejazd %s w awarii" % id)
	if state == State.CLOSED or state == State.CLOSING:
		return CommandResult.failure("rogatki %s już zamknięte/zamykane" % id)
	state = State.CLOSING
	_move_left_s = close_time_s
	return CommandResult.success()


## Polecenie gracza: otwarcie rogatek (kat. A).
func command_open() -> CommandResult:
	if is_automatic():
		return CommandResult.failure("przejazd %s jest samoczynny (ssp)" % id)
	if state == State.FAILURE:
		return CommandResult.failure("przejazd %s w awarii" % id)
	if state == State.OPEN or state == State.OPENING:
		return CommandResult.failure("rogatki %s już otwarte/otwierane" % id)
	state = State.OPENING
	_move_left_s = close_time_s * 0.6
	return CommandResult.success()


func set_failure(failed: bool) -> void:
	if failed and state != State.FAILURE:
		_state_before_failure = state
		state = State.FAILURE
	elif not failed and state == State.FAILURE:
		state = _state_before_failure


## Krok symulacji: napędy rogatek + automat ssp od zajętości sekcji
## najazdowych (docs/systemy/16 §3).
func tick(dt: float, graph: TrackGraph) -> void:
	match state:
		State.CLOSING:
			_move_left_s -= dt
			if _move_left_s <= 0.0:
				state = State.CLOSED
		State.OPENING:
			_move_left_s -= dt
			if _move_left_s <= 0.0:
				state = State.OPEN
		State.FAILURE:
			return
		_:
			pass
	if not is_automatic():
		return
	var approaching := false
	for section_id: StringName in on_sections:
		var section := graph.get_section(section_id)
		if section != null and section.occupied:
			approaching = true
			break
	if approaching and state == State.OPEN:
		state = State.CLOSING
		_move_left_s = close_time_s
	elif not approaching and state == State.CLOSED:
		state = State.OPENING
		_move_left_s = close_time_s * 0.6


func to_dict() -> Dictionary:
	return {"state": state, "move_left_s": _move_left_s}


func from_dict(data: Dictionary) -> void:
	state = int(data.get("state", State.OPEN)) as LevelCrossing.State
	_move_left_s = float(data.get("move_left_s", 0.0))
