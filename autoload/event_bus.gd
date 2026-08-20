extends Node
## Globalna szyna zdarzeń: polecenia UI → rdzeń oraz zdarzenia rdzenia → UI.
## Architektura wg docs/02-architektura.md — UI nigdy nie zmienia stanu rdzenia
## bezpośrednio; rdzeń nie zna węzłów sceny.

## Zdarzenie rdzenia (SimEvent {type, payload}), np. &"section_occupied",
## &"signal_aspect_changed", &"phone_ring", &"dsat_alarm".
signal sim_event(type: StringName, payload: Dictionary)

## Wynik wykonania polecenia gracza. Odrzucenie z powodem to normalna sytuacja
## (np. "zwrotnica utwierdzona w przebiegu").
signal command_result(command: StringName, ok: bool, reason: String)


## Publikuje zdarzenie rdzenia do wszystkich zainteresowanych widoków.
func emit_sim_event(type: StringName, payload: Dictionary = {}) -> void:
	sim_event.emit(type, payload)


## Publikuje wynik polecenia gracza (CommandResult {ok, reason}).
func emit_command_result(command: StringName, ok: bool, reason: String = "") -> void:
	command_result.emit(command, ok, reason)
