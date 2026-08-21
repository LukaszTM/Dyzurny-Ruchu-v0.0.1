class_name NeighbourAI
extends RefCounted
## AI dyżurnego sąsiedniego posterunku (docs/05 §4): inicjuje telefonogramy
## zgodnie z rozkładem, odpowiada na telefonogramy gracza w poprawnych
## formułach z małym opóźnieniem, obsługuje swoją stronę blokady.
## Wejście pociągu do świata jest sprzężone z zapowiedzią (docs/05 §3).

## Sąsiad zaczyna zabiegać o drogę tyle sekund przed planowym przyjazdem.
const REQUEST_LEAD_S: float = 240.0
## Oznajmienie odjazdu (i wjazd na odstęp) — tyle sekund przed przyjazdem.
const ANNOUNCE_LEAD_S: float = 120.0
## Opóźnienie odpowiedzi AI na telefonogram gracza.
const RESPONSE_DELAY_S: float = 6.0
## Ponaglenie żądania pozwolenia, gdy gracz nie reaguje.
const REMIND_EVERY_S: float = 120.0
## Czas jazdy wyprawionego pociągu do sąsiada (do jego Ko) — uproszczenie.
const NEIGHBOUR_RUN_S: float = 100.0

var neighbour_name: String = ""
var block: BlockLine = null
## Pociągi jadące od tego sąsiada do gracza.
var incoming: Array[Timetable.Entry] = []

## Zaplanowane działania AI: {at_s, kind, ...}.
var _pending: Array[Dictionary] = []
## nr pociągu -> czas ostatniego żądania pozwolenia.
var _last_request: Dictionary = {}
## nr pociągu -> true, gdy odjazd oznajmiony (spawn zaplanowany).
var _announced: Dictionary = {}
## Wstrzymane pociągi (gracz nadał „Stój").
var _held: Dictionary = {}


func _init(p_name: String, p_block: BlockLine, timetable: Timetable) -> void:
	neighbour_name = p_name
	block = p_block
	if timetable != null:
		for entry: Timetable.Entry in timetable.entries:
			if entry.from_station == neighbour_name:
				incoming.append(entry)


## Krok AI; zwraca zdarzenia dla świata:
## {kind: "phone", type, nr} | {kind: "spawn", nr} | {kind: "permission_given"}
## | {kind: "released", nr} (Ko sąsiada po przyjeździe u niego).
func tick(now_s: float) -> Array[Dictionary]:
	var events: Array[Dictionary] = []
	_run_pending(now_s, events)
	for entry: Timetable.Entry in incoming:
		if entry.spawned or _announced.has(entry.nr) or _held.has(entry.nr):
			continue
		if now_s < float(entry.arr_s) - REQUEST_LEAD_S:
			continue
		if block.permission_at != BlockLine.BlockSide.NEIGHBOUR:
			# Pozwolenie u gracza — żądaj (i ponaglaj) telefonicznie.
			var last := float(_last_request.get(entry.nr, -INF))
			if now_s - last >= REMIND_EVERY_S:
				_last_request[entry.nr] = now_s
				events.append({
					"kind": "phone", "type": &"zadanie_pozwolenia", "nr": entry.nr,
				})
		elif block.can_dispatch_from_neighbour():
			if now_s >= float(entry.arr_s) - ANNOUNCE_LEAD_S:
				_announced[entry.nr] = true
				events.append({
					"kind": "phone", "type": &"oznajmienie_odjazdu", "nr": entry.nr,
				})
				# Pociąg rusza od sąsiada chwilę po oznajmieniu.
				_pending.append({"at_s": now_s + 15.0, "kind": "spawn", "nr": entry.nr})
	return events


## Reakcja na telefonogram gracza (docs/05 §4: poprawne formuły,
## małe opóźnienie odpowiedzi).
func on_player_phone(type: StringName, nr: String, now_s: float) -> void:
	match type:
		&"zadanie_pozwolenia":
			# Gracz żąda drogi dla wyprawianego pociągu.
			_pending.append({"at_s": now_s + RESPONSE_DELAY_S,
				"kind": "answer_permission", "nr": nr})
		&"danie_pozwolenia":
			# Uprzejme potwierdzenie; fizycznie pozwolenie przekazuje Poz.
			_pending.append({"at_s": now_s + RESPONSE_DELAY_S,
				"kind": "ack", "nr": nr})
			_held.erase(nr)
		&"stoj":
			_held[nr] = true
			_pending.append({"at_s": now_s + RESPONSE_DELAY_S, "kind": "ack", "nr": nr})
		&"oznajmienie_odjazdu", &"potwierdzenie_przyjazdu":
			_pending.append({"at_s": now_s + RESPONSE_DELAY_S, "kind": "ack", "nr": nr})


## Pociąg gracza zniknął za stacją w stronę tego sąsiada: po czasie jazdy
## sąsiad potwierdza przyjazd (jego Ko zwalnia odstęp) — docs/systemy/15 §1.
func on_player_train_left(nr: String, now_s: float) -> void:
	_pending.append({"at_s": now_s + NEIGHBOUR_RUN_S, "kind": "confirm_arrival", "nr": nr})


func _run_pending(now_s: float, events: Array[Dictionary]) -> void:
	var still: Array[Dictionary] = []
	for action: Dictionary in _pending:
		if now_s < float(action["at_s"]):
			still.append(action)
			continue
		var nr := String(action["nr"])
		match String(action["kind"]):
			"spawn":
				events.append({"kind": "spawn", "nr": nr})
			"answer_permission":
				if block.give_permission_to_player():
					events.append({"kind": "phone", "type": &"danie_pozwolenia", "nr": nr})
					events.append({"kind": "permission_given", "nr": nr})
				else:
					events.append({"kind": "phone", "type": &"stoj", "nr": nr})
			"confirm_arrival":
				block.released_by_neighbour()
				events.append({"kind": "phone", "type": &"potwierdzenie_przyjazdu", "nr": nr})
				events.append({"kind": "released", "nr": nr})
			"ack":
				events.append({"kind": "ack", "nr": nr})
	_pending = still
