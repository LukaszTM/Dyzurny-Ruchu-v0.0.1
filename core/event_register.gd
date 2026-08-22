class_name EventRegister
extends RefCounted
## Rejestr zdarzeń urządzeń komputerowych (docs/systemy/14 §4): każda
## operacja dyżurnego i zdarzenie systemowe z czasem `hh:mm:ss | źródło |
## treść`. Prowadzony dla każdej stacji (przydaje się też na pulpicie —
## raport zmiany korzysta z tych samych danych).

## Maksymalna liczba wpisów — najstarsze wypadają (rejestr przewijalny).
const MAX_ENTRIES: int = 1000

## Wpisy: {"t": float (sekundy doby), "source": String, "text": String}.
var entries: Array[Dictionary] = []


## Dopisuje wpis. Źródła: "DYŻ" (polecenia gracza), "SYS" (rdzeń),
## "AI" (sąsiedzi/drużyny).
func add(time_of_day_s: float, source: String, text: String) -> void:
	entries.append({"t": time_of_day_s, "source": source, "text": text})
	if entries.size() > MAX_ENTRIES:
		entries = entries.slice(entries.size() - MAX_ENTRIES)


## Ostatnie `count` wpisów (najnowszy na końcu).
func last(count: int) -> Array[Dictionary]:
	if entries.size() <= count:
		return entries.duplicate()
	var result: Array[Dictionary] = []
	result.assign(entries.slice(entries.size() - count))
	return result


## Wpis jako linia rejestru "hh:mm:ss | źródło | treść".
static func format_line(entry: Dictionary) -> String:
	var total: int = int(float(entry["t"])) % 86400
	@warning_ignore("integer_division")
	var h: int = total / 3600
	@warning_ignore("integer_division")
	var m: int = (total % 3600) / 60
	var s: int = total % 60
	return "%02d:%02d:%02d | %s | %s" % [h, m, s, String(entry["source"]), String(entry["text"])]


func to_dict() -> Dictionary:
	return {"entries": entries.duplicate(true)}


func from_dict(data: Dictionary) -> void:
	entries.clear()
	for entry_variant: Variant in (data.get("entries", []) as Array):
		var entry: Dictionary = entry_variant
		entries.append({
			"t": float(entry.get("t", 0.0)),
			"source": String(entry.get("source", "SYS")),
			"text": String(entry.get("text", "")),
		})
