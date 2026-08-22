class_name BlockLine
extends RefCounted
## Blokada liniowa jednego toru szlaku (docs/systemy/15).
## Półsamoczynna/elektromechaniczna (§1/§3): pola Po/Ko/Poz obsługiwane
## ręcznie. Samoczynna (§2): odstępy z semaforami odstępowymi sterowanymi
## wyłącznie zajętością (ślepe na przebiegi), wyprawianie za pociągiem.

## Po której stronie szlaku jest pozwolenie wyprawiania.
enum BlockSide { PLAYER, NEIGHBOUR }

var id: StringName = &""
var neighbour_name: String = ""
var entry_signal: StringName = &""
var exit_signals: Array[StringName] = []
## Sekcja zbliżania szlaku po stronie gracza (do detekcji wjazdu/wyjazdu).
var approach_section: StringName = &""
## Blokada samoczynna (docs/systemy/15 §2): true dla typów samoczynna_*.
var automatic: bool = false
## Liczba staw (3 lub 4) — dobór obrazów semaforów odstępowych.
var staw: int = 3
## Odstępy w kolejności jazdy (id sekcji).
var odstepy: Array[StringName] = []
## Semafory osłaniające kolejne odstępy ("" = osłania semafor stacyjny).
var odstep_signals: Array[StringName] = []

var permission_at: BlockSide = BlockSide.PLAYER
## Awaria blokady (docs/systemy/15 §1, 18 §6): pola nieczynne, ruch
## prowadzony na telefoniczne zapowiadanie, wyjazdy na Sz lub rozkaz.
var failed: bool = false
## Odstęp (szlak) zajęty przez pociąg.
var occupied: bool = false
## Pole początkowe zablokowane (gracz wyprawił i zablokował Po).
var po_locked: bool = false
## Nr pociągu na odstępie (jadącego do gracza lub od gracza).
var train_nr: String = ""
## Pociąg przyjechał do gracza w całości — wolno obsłużyć Ko.
var arrival_pending: bool = false
## Pociąg wyprawiony przez gracza jest na odstępie — wolno obsłużyć Po.
var po_pending: bool = false


static func from_def(def: Dictionary, p_approach: StringName) -> BlockLine:
	var block := BlockLine.new()
	block.id = StringName(String(def.get("id", "")))
	block.neighbour_name = String(def.get("neighbour", ""))
	block.entry_signal = StringName(String(def.get("entry_signal", "")))
	for signal_id: Variant in (def.get("exit_signals", []) as Array):
		block.exit_signals.append(StringName(String(signal_id)))
	block.approach_section = p_approach
	var type := String(def.get("type", "polsamoczynna"))
	block.automatic = type.begins_with("samoczynna")
	block.staw = 4 if type.contains("4staw") else 3
	for section_id: Variant in (def.get("odstepy", []) as Array):
		block.odstepy.append(StringName(String(section_id)))
	for signal_id: Variant in (def.get("signals", []) as Array):
		block.odstep_signals.append(StringName(String(signal_id)))
	if block.automatic and not block.odstepy.is_empty() and p_approach == &"":
		# Zbliżanie/wyjście dla sbl = odstęp przylegający do stacji.
		block.approach_section = block.odstepy[0] \
			if not block.exit_signals.is_empty() else block.odstepy[block.odstepy.size() - 1]
	return block


## Czy blokada pozwala wyprawić pociąg (warunek 6 checklisty docs/04 §3):
## pozwolenie u gracza i odstęp wolny.
func can_dispatch() -> CommandResult:
	if failed:
		return CommandResult.failure(
			"blokada %s uszkodzona — telefoniczne zapowiadanie, jazda na Sz lub rozkaz „S”" % id
		)
	if automatic:
		# Wyprawianie za pociągiem: wystarczy wolny pierwszy odstęp (§2).
		if occupied:
			return CommandResult.failure("blokada %s: pierwszy odstęp zajęty" % id)
		return CommandResult.success()
	if permission_at != BlockSide.PLAYER:
		return CommandResult.failure(
			"blokada %s: pozwolenie jest u sąsiada (%s)" % [id, neighbour_name]
		)
	if occupied:
		return CommandResult.failure("blokada %s: odstęp zajęty" % id)
	return CommandResult.success()


## Czy sąsiad może wyprawić pociąg do gracza (pozwolenie u niego,
## odstęp wolny).
func can_dispatch_from_neighbour() -> bool:
	return permission_at == BlockSide.NEIGHBOUR and not occupied


## Obsługa pola przez gracza (przyciski Po/Ko/Poz na pulpicie).
func press(field: String) -> CommandResult:
	if automatic:
		return CommandResult.failure(
			"blokada %s samoczynna — pola Po/Ko/Poz nie występują" % id
		)
	if failed:
		return CommandResult.failure("blokada %s uszkodzona — pola nieczynne" % id)
	match field:
		"Po":
			if not po_pending or po_locked:
				return CommandResult.failure(
					"pole Po blokady %s: brak podstaw do zablokowania" % id
				)
			po_locked = true
			po_pending = false
			return CommandResult.success()
		"Ko":
			if not arrival_pending:
				return CommandResult.failure(
					"pole Ko blokady %s: brak pociągu do potwierdzenia" % id
				)
			arrival_pending = false
			occupied = false
			train_nr = ""
			return CommandResult.success()
		"Poz":
			if permission_at != BlockSide.PLAYER:
				return CommandResult.failure("pozwolenie blokady %s jest u sąsiada" % id)
			if occupied:
				return CommandResult.failure(
					"blokada %s: odstęp zajęty — nie można przekazać pozwolenia" % id
				)
			permission_at = BlockSide.NEIGHBOUR
			return CommandResult.success()
	return CommandResult.failure("nieznane pole blokady: %s" % field)


## Sąsiad (AI) przekazuje pozwolenie graczowi.
func give_permission_to_player() -> bool:
	if permission_at == BlockSide.NEIGHBOUR and not occupied:
		permission_at = BlockSide.PLAYER
		return true
	return false


## Pociąg od sąsiada wjechał na odstęp (po oznajmieniu odjazdu).
func train_entered_from_neighbour(nr: String) -> void:
	occupied = true
	train_nr = nr
	arrival_pending = false


## Pociąg od sąsiada przyjechał do gracza w całości → Ko dozwolone.
func train_arrived_at_player() -> void:
	if occupied:
		arrival_pending = true


## Pociąg gracza wyjechał na odstęp → Po dozwolone, odstęp zajęty.
func train_dispatched_by_player(nr: String) -> void:
	occupied = true
	train_nr = nr
	po_pending = true


## Sąsiad potwierdził przyjazd u siebie (jego Ko) → odstęp wolny.
func released_by_neighbour() -> void:
	if automatic:
		return
	occupied = false
	po_locked = false
	po_pending = false
	train_nr = ""


## Krok blokady samoczynnej (docs/systemy/15 §2): zajętość odstępów
## z sekcji, obrazy semaforów odstępowych wg liczby wolnych odstępów
## przed nimi (3-stawna: S1←S5←S2; 4-stawna: S1←S5←S3←S2).
func update_automatic(graph: TrackGraph) -> void:
	if not automatic or odstepy.is_empty():
		return
	var occupied_flags: Array[bool] = []
	for section_id: StringName in odstepy:
		var section := graph.get_section(section_id)
		occupied_flags.append(section != null and section.occupied)
	occupied = occupied_flags[0]
	for i: int in odstep_signals.size():
		if odstep_signals[i] == &"" or i >= occupied_flags.size():
			continue
		var signal_device := graph.get_signal(odstep_signals[i])
		if signal_device == null:
			continue
		var free_count := 0
		for j: int in range(i, occupied_flags.size()):
			if occupied_flags[j]:
				break
			free_count += 1
		signal_device.set_aspect(_automatic_aspect(free_count))


func _automatic_aspect(free_count: int) -> StringName:
	if failed:
		# Awaria sbl: semafory odstępowe ciemne = „stój" (docs/systemy/15 §2).
		return &"S1"
	if free_count <= 0:
		return &"S1"
	if free_count == 1:
		return &"S5"
	if staw == 4 and free_count == 2:
		return &"S3"
	return &"S2"


## Obraz pierwszego semafora za stacyjnym wyjazdowym (do next_info
## semafora wyjazdowego przy sbl — docs/04 §6).
func first_line_signal() -> StringName:
	for signal_id: StringName in odstep_signals:
		if signal_id != &"":
			return signal_id
	return &""


func to_dict() -> Dictionary:
	return {
		"permission_at": permission_at,
		"failed": failed,
		"occupied": occupied,
		"po_locked": po_locked,
		"train_nr": train_nr,
		"arrival_pending": arrival_pending,
		"po_pending": po_pending,
	}


func from_dict(data: Dictionary) -> void:
	permission_at = int(data.get("permission_at", BlockSide.PLAYER)) as BlockLine.BlockSide
	failed = bool(data.get("failed", false))
	occupied = bool(data.get("occupied", false))
	po_locked = bool(data.get("po_locked", false))
	train_nr = String(data.get("train_nr", ""))
	arrival_pending = bool(data.get("arrival_pending", false))
	po_pending = bool(data.get("po_pending", false))
