class_name Turnout
extends RefCounted
## Zwrotnica: stany, przestawianie, rozprucie (docs/04-logika-zaleznosci.md §2,
## format danych: docs/03-model-danych.md §1).
## Warunki zewnętrzne przestawienia (wolność i nieutwierdzenie sekcji
## zwrotnicowej) sprawdza TrackGraph.throw_turnout(); tu tylko stan własny.

var id: StringName = &""
var node_id: StringName = &""
var edge_root: StringName = &""
var edge_plus: StringName = &""
var edge_minus: StringName = &""
var throw_time_s: float = 5.0
## Prędkość jazdy na kierunek zwrotny (docs/03 §1: 40/60/100).
var v_minus_kmh: int = 40

## Tolerancja błędu zmiennoprzecinkowego odliczania czasu ruchu — suma
## wielu ticków po 0,1 s nie trafia dokładnie w zero (por. SimClock).
const MOVE_EPSILON: float = 1e-6

var state: Const.TurnoutState = Const.TurnoutState.PLUS
## Położenie docelowe w czasie przestawiania (MOVING).
var target_pos: Const.TurnoutPos = Const.TurnoutPos.PLUS
## Pozostały czas przestawiania w sekundach (tylko w stanie MOVING).
var move_left_s: float = 0.0

## Zamknięcie indywidualne (docs/04 §4) — zwrotnica wyłączona z nastawiania.
var closed_individually: bool = false
## Utwierdzenie w przebiegu (docs/04 §2) — id przebiegu, &"" = wolna.
var locked_by: StringName = &""


## Czy urządzenia mają kontrolę położenia (lampka świeci ciągle).
func has_control() -> bool:
	return state == Const.TurnoutState.PLUS or state == Const.TurnoutState.MINUS


func is_plus() -> bool:
	return state == Const.TurnoutState.PLUS


func is_minus() -> bool:
	return state == Const.TurnoutState.MINUS


## Warunki własne przestawienia (docs/04 §2: „sprawna AND nieutwierdzona
## AND niezamknięta"); wolność sekcji sprawdza TrackGraph.
func can_throw() -> CommandResult:
	match state:
		Const.TurnoutState.MOVING:
			return CommandResult.failure("zwrotnica %s jest w trakcie przestawiania" % id)
		Const.TurnoutState.NO_CONTROL:
			return CommandResult.failure("zwrotnica %s bez kontroli położenia (usterka)" % id)
		Const.TurnoutState.TRAILED:
			return CommandResult.failure("zwrotnica %s rozpruta — wymaga oględzin" % id)
	if closed_individually:
		return CommandResult.failure("zwrotnica %s zamknięta indywidualnie" % id)
	if locked_by != &"":
		return CommandResult.failure("zwrotnica %s utwierdzona w przebiegu %s" % [id, locked_by])
	return CommandResult.success()


## Rozpoczyna przestawianie do położenia przeciwnego. W czasie przestawiania
## brak kontroli położenia (stan MOVING).
func start_throw() -> CommandResult:
	var check := can_throw()
	if not check.ok:
		return check
	target_pos = Const.TurnoutPos.MINUS if is_plus() else Const.TurnoutPos.PLUS
	state = Const.TurnoutState.MOVING
	move_left_s = throw_time_s
	return CommandResult.success()


## Krok symulacji; zwraca true dokładnie w ticku zakończenia przestawiania.
func tick(dt: float) -> bool:
	if state != Const.TurnoutState.MOVING:
		return false
	move_left_s -= dt
	if move_left_s > MOVE_EPSILON:
		return false
	move_left_s = 0.0
	state = (
		Const.TurnoutState.PLUS
		if target_pos == Const.TurnoutPos.PLUS
		else Const.TurnoutState.MINUS
	)
	return true


## Rozprucie: najechanie „na ostrze" przy złym położeniu (docs/04 §2).
## Powrót do ruchu wymaga procedury (oględziny — zdarzenie w F4+).
func trail() -> void:
	state = Const.TurnoutState.TRAILED
	move_left_s = 0.0


## Usterka: utrata kontroli położenia (docs/04 §8, turnout_no_control).
func set_no_control() -> void:
	state = Const.TurnoutState.NO_CONTROL
	move_left_s = 0.0


## Snapshot stanu dynamicznego (konfiguracja pochodzi z pliku stacji).
func to_dict() -> Dictionary:
	return {
		"state": state,
		"target_pos": target_pos,
		"move_left_s": move_left_s,
		"closed_individually": closed_individually,
		"locked_by": String(locked_by),
	}


func from_dict(data: Dictionary) -> void:
	state = int(data.get("state", Const.TurnoutState.PLUS)) as Const.TurnoutState
	target_pos = int(data.get("target_pos", Const.TurnoutPos.PLUS)) as Const.TurnoutPos
	move_left_s = float(data.get("move_left_s", 0.0))
	closed_individually = bool(data.get("closed_individually", false))
	locked_by = StringName(String(data.get("locked_by", "")))
