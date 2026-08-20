class_name CommandResult
extends RefCounted
## Wynik polecenia gracza/rdzenia: {ok, reason} (docs/02-architektura.md,
## „Polecenia gracza"). Odrzucenie z powodem to normalna sytuacja.

var ok: bool = false
## Powód odmowy po polsku (pusty przy powodzeniu) — UI może go pokazać
## w trybie szkolenia.
var reason: String = ""


static func success() -> CommandResult:
	var result := CommandResult.new()
	result.ok = true
	return result


static func failure(reason_text: String) -> CommandResult:
	var result := CommandResult.new()
	result.ok = false
	result.reason = reason_text
	return result
