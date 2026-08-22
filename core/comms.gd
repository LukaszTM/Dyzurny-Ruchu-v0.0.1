class_name Comms
extends RefCounted
## Łączność zapowiadawcza: rejestr telefonogramów i wzory formuł
## (docs/systemy/18 §1–§2, parafrazy wg Ir-1 Dodatek 2).

## Typy formuł (docs/systemy/18 §2, poz. 1–5).
const TYPES: Array[StringName] = [
	&"zadanie_pozwolenia",
	&"danie_pozwolenia",
	&"stoj",
	&"oznajmienie_odjazdu",
	&"potwierdzenie_przyjazdu",
]

const TYPE_LABELS: Dictionary = {
	&"zadanie_pozwolenia": "Żądanie pozwolenia",
	&"danie_pozwolenia": "Danie pozwolenia (droga wolna)",
	&"stoj": "Stój — zatrzymajcie pociąg",
	&"oznajmienie_odjazdu": "Oznajmienie odjazdu",
	&"potwierdzenie_przyjazdu": "Potwierdzenie przyjazdu",
}


## Jeden zapisany telefonogram.
class Message:
	extends RefCounted
	var time_s: float = 0.0
	var from_name: String = ""
	var text: String = ""
	## true = od sąsiada do gracza (dzwonek).
	var incoming: bool = false

var log: Array[Message] = []
## Liczba nieodebranych telefonogramów (dzwonek na pulpicie).
var unread: int = 0


## Treść formuły wg wzorów z docs/systemy/18 §2.
## TODO(weryfikacja): brzmienie porównać z Dodatkiem 2 Ir-1 przed 1.0.
static func format_message(type: StringName, train_nr: String, time_s: float) -> String:
	var hhmm := format_time(time_s)
	match type:
		&"zadanie_pozwolenia":
			return "Czy droga dla pociągu nr %s wolna?" % train_nr
		&"danie_pozwolenia":
			return "Droga dla pociągu nr %s wolna." % train_nr
		&"stoj":
			return "Stój. Zatrzymajcie pociąg nr %s." % train_nr
		&"oznajmienie_odjazdu":
			return "Pociąg nr %s odjedzie o %s." % [train_nr, hhmm]
		&"potwierdzenie_przyjazdu":
			return "Pociąg nr %s przyjechał o %s." % [train_nr, hhmm]
	return ""


static func format_time(time_s: float) -> String:
	var total := int(time_s) % 86400
	@warning_ignore("integer_division")
	var h := total / 3600
	@warning_ignore("integer_division")
	var m := (total % 3600) / 60
	return "%02d:%02d" % [h, m]


func add(from_name: String, text: String, time_s: float, incoming: bool) -> Message:
	var message := Message.new()
	message.from_name = from_name
	message.text = text
	message.time_s = time_s
	message.incoming = incoming
	log.append(message)
	if incoming:
		unread += 1
	return message


func mark_read() -> void:
	unread = 0


func to_dict() -> Dictionary:
	var list: Array = []
	for message: Message in log:
		list.append({"time_s": message.time_s, "from": message.from_name,
			"text": message.text, "incoming": message.incoming})
	return {"log": list, "unread": unread}


func from_dict(data: Dictionary) -> void:
	log.clear()
	for item: Variant in (data.get("log", []) as Array):
		var def: Dictionary = item
		var message := Message.new()
		message.time_s = float(def["time_s"])
		message.from_name = String(def["from"])
		message.text = String(def["text"])
		message.incoming = bool(def["incoming"])
		log.append(message)
	unread = int(data.get("unread", 0))
